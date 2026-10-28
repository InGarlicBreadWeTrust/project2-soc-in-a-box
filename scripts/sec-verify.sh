#!/usr/bin/env bash
# scripts/sec-verify.sh — PROVE the co-op SOC-in-a-box security invariants without a live test bed.
#
# This is the single most important tool in the project: it makes the "help the co-op not
# get sued / no call-home / no telemetry / passive-only / no secrets" claims *checkable*
# rather than just asserted in prose. Run it against the config/ + systemd/ + sigma/ trees and
# it prints PASS / WARN / FAIL per invariant and exits non-zero on any FAIL.
#
# It is intentionally STATIC: it greps the committed config for the failure modes the co-op
# must never ship, so it works with zero internet and no privileged bits.
#
# SAFETY: reads NO secrets, writes nothing, transmits nothing. Pure local static analysis.
#
# Usage:  scripts/sec-verify.sh            (scan the whole repo from its top dir)
# Env overrides (all optional, safe defaults):
#   COOP_ROOT        repo top dir      (default: parent of this script's dir)
#   COOP_ALLOW_HOSTS  space-separated hosts an ALERT endpoint may legitimately reach
#                     (default: empty -> only loopback / co-op-owned local is allowed)
#   CONTROL_VLAN      the passive control VLAN id (default: 3000)
#   ICS_PORTS         "dport values that are ICS control write ports" (default 502 102 104 10061 10062 20000)
#
# Exit: 0 = all PASS/WARN (no FAIL), 1 = at least one FAIL.

set -uo pipefail

COOP_ROOT="${COOP_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
COOP_ALLOW_HOSTS="${COOP_ALLOW_HOSTS:-}"
CONTROL_VLAN="${CONTROL_VLAN:-3000}"
ICS_PORTS="${ICS_PORTS:-502 102 104 10061 10062 20000}"

FAIL=0 ; WARN=0 ; pss=0
ok()    { printf "   \033[32mPASS\033[0m   %s\n" "$1"; pss=$((pss+1)); }
warn() { printf "  \033[33mWARN\033[0m  %s\n" "$1"; WARN=$((WARN+1)); }
bad()  { printf "  \033[31mFAIL\033[0m  %s\n" "$1"; FAIL=$((FAIL+1)); }
info() { printf "  %s\n" "$1"; }
scan()  { grep -rInE --exclude-dir=.git -e "$1" "$COOP_ROOT"/config "$COOP_ROOT"/systemd "$COOP_ROOT"/sigma 2>/dev/null; }

echo "======================================================================"
echo " Co-op SOC-in-a-Box  ::  security-invariant static check"
echo " root: $COOP_ROOT"
echo " control VLAN=$CONTROL_VLAN  ICS control write ports = $ICS_PORTS"
echo " allowed alert hosts = '${COOP_ALLOW_HOSTS:-<none — loopback/co-op-owned only>}'"
echo "======================================================================"

# ---- CHECK A: no external exfil / no call-home / no telemetry -----------------------
# The single most important check (security-assessment §2): every outbound destination
# must be a co-op-owned or loopback host. Flag any URL/endpoint that is not loopback.
echo
echo "[A] No external exfil / call-home / telemetry"
EXFIL_HITS=$(
  scan 'remote_index_server|remote_write|remote_endpoint|remote_url|remote_read|\
@s3|@http|@s3a|@splunk|@datadog|@kafka|@http_callback|http_api|cloud\s*:\s*true|telemetry\s*:\s*enabled' \
| grep -vE '^\s*[0-9]+:\s*#' ) || true
if [ -n "$EXFIL_HITS" ]; then
  bad "found apparent exfil / call-home / telemetry directives:"; echo "$EXFIL_HITS" | sed 's/^/      /'
else
  ok "no exfil / call-home / telemetry directives (no remote_write, @s3/@http/@datadog/@kafka, no telemetry:enabled)"
fi
# External host check: any http(s):// or :// host that is NOT loopback and NOT in COOP_ALLOW_HOSTS
HOST_HITS=$(scan 'https?://[^"'"'"' ]+|@[a-zA-Z0-9._-]+' \
  | grep -vE '127\.0\.0\.1|localhost|::1' \
  | grep -vE "$COOP_ALLOW_HOSTS" || true)
if [ -n "$HOST_HITS" ]; then
  # Distinguish example/comment lines (which are safe) from live config.
  bad "found host/endpoint references not matching loopback or COOP_ALLOW_HOSTS — verify each is comment/example, not live config:"
  echo "$HOST_HITS" | sed 's/^/      /'
  warn "review: the lines above should be comments or co-op-owned; live config must target loopback or COOP_ALLOW_HOSTS only"
else
  ok "no non-loopback host/endpoint references in config (all destinations are local/co-op-owned)"
fi

# ---- CHECK B: passive-only — no egress toward an ICS control write port ----------------
echo
echo "[B] Passive-only: no output/forward path to an ICS control write port"
# A co-op must have NO write path into control. For each ICS control write port, look for a rule
# that (a) lives in an output/forward/nat chain AND (b) accepts/forwards a dport equal to that
# port, in non-comment config. If any such line exists, it is a potential write path to control.
CONTROL_HITS=""
for p in $ICS_PORTS; do
   hits=$(grep -rInE --exclude-dir=.git -e "dport[[:space:]]+$p\b" \
          "$COOP_ROOT"/config/nftables 2>/dev/null \
         | grep -Ei 'output|forward|accept|allow' | grep -vE '^[^:]+:[0-9]+:\s*#' || true)
   if [ -n "$hits" ]; then CONTROL_HITS="${CONTROL_HITS}${hits}"$'\n'; fi
done
# also catch a generic 'accept to control netrange' via a co-op control netrange var
if [ -z "$CONTROL_HITS" ]; then
   control_net=$(grep -rInE --exclude-dir=.git -i 'control_?vlan|control_net|3000' \
          "$COOP_ROOT"/config/nftables 2>/dev/null | grep -Ei 'accept|allow|forward' | grep -vE '^[^:]+:[0-9]+:\s*#' || true)
   [ -n "$control_net" ] && CONTROL_HITS="$control_net"
fi
if [ -n "$CONTROL_HITS" ]; then
  bad "a rule appears to allow egress toward an ICS control port — verify it is not a write path to control:"
  echo "$CONTROL_HITS" | sed 's/^/      /'
else
  ok "no rule permits egress toward ICS control write ports ($ICS_PORTS) — no write path to control VLAN"
fi

# ---- CHECK C: no secrets / credentials anywhere in committed tree -----------------------
echo
echo "[C] No secrets / credentials in committed config"
SECRET_HITS=$(
  grep -rInE --exclude-dir=.git \
    -e 'gh(p|o|s|u)_[A-Za-z0-9]{20,}' \
    -e 'AKIA[0-9A-Z]{16}' \
    -e 'sk-[A-Za-z0-9]{20,}' \
    -e '-----BEGIN (RSA|OPENSSH|EC|DSA|PGP)? ?[A-Z ]*PRIVATE KEY-----' \
    -e '(password|passwd|api[_-]?key|token|secret)\s*[:=]\s*["'"'"']?[A-Za-z0-9@._-]{6,}' \
    "$COOP_ROOT"/config "$COOP_ROOT"/systemd "$COOP_ROOT"/sigma 2>/dev/null \
  | grep -vE '#|example|EXAMPLE|<|placeholder|\$\{|COOP_|\[\[|\{\{|:?\*+:\?|REPLACE|TODO' \
  || true)
if [ -n "$SECRET_HITS" ]; then
  bad "possible secret/credential in committed config:"; echo "$SECRET_HITS" | sed 's/^/      /'
else
  ok "no high-value secret patterns in committed config (pager numbers/SSH keys must stay offline & rotated)"
fi

# ---- CHECK D: sensor services are self-healing & sandboxed ----------------------------
echo
echo "[D] systemd sensor services are self-healing and sandboxed"
if [ -d "$COOP_ROOT/systemd" ]; then
  for u in "$COOP_ROOT"/systemd/*.service; do
    [ -e "$u" ] || continue
    b=$(basename "$u")
    if grep -q 'Restart=on-failure' "$u"; then ok "$b has Restart=on-failure"; else bad "$b missing Restart=on-failure"; fi
    if grep -qE 'ProtectSystem=strict|ProtectSystem=full|ProtectHome=yes' "$u"; then
      ok "$b has a sandbox (ProtectSystem/ProtectHome)"
    else
      warn "$b has no ProtectSystem/ProtectHome sandbox — add it"
    fi
  done
else
  info "no systemd/ dir yet — no units to check"
fi

# ---- CHECK E: copyleft components never LINKED (independent-binary guard) -------------
echo
echo "[E] Permissive-first: no co-op glue links GPL/AGPL code"
if grep -rInF --exclude-dir=.git -e 'link' -e 'LIBS' -e 'ldflags' "$COOP_ROOT"/systemd "$COOP_ROOT"/config 2>/dev/null \
    | grep -Ei 'suricata|lib60870|libiec61850|wazuh' \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' ; then
  warn "a co-op component references a GPL/AGPL binary — ensure it is an INDEPENDENT binary in its own segment, not linked into co-op code"
else
  ok "no co-op glue links GPL/AGPL binaries (Suricata/lib60870/libiec61850/Wazuh kept independent)"
fi

# ---- CHECK F: Wazuh / Tailscale default-cloud paths disabled (if present) --------------
echo
echo "[F] Wazuh / Tailscale default cloud/telemetry disabled (only if those files exist)"
for cfg in "$COOP_ROOT"/config/wazuh/* "$COOP_ROOT"/config/tailscale/*; do
  [ -e "$cfg" ] || continue
  b=$(basename "$cfg")
  case "$b" in
    *wazuh*|ossec*)
      if grep -qE 'remote_index_server.*disable|cloud\s*[:*]?\s*disable|indexer.*disable' "$cfg"; then
        ok "wazuh index/telemetry disabled in $b"; else warn "verify $b disables wazuh index/telemetry (default cloud path)"; fi ;;
    *tail*|headscale*)
      if grep -qE 'no-ssh|advertise|coord.*local|headscale' "$cfg" && ! grep -q 'coordination.*cloud' "$cfg"; then
        ok "tailscale/headscale mgmt-only in $b"; else warn "verify $b is mgmt-only, no ICS telemetry on the relay"; fi ;;
  esac
done
info "(F is N/A when wazuh/ or tailscale/ dirs are absent — the default design omits cloud deps)"

# ---- CHECK G: Sigma carry DRL attribution --------------------------------------------
echo
echo "[G] Sigma rules carry detection-rule-license attribution"
if [ -d "$COOP_ROOT/sigma" ]; then
  for r in $(find "$COOP_ROOT"/sigma -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sort); do
    [ -e "$r" ] || continue
    rel=${r#"$COOP_ROOT"/}
    if grep -qiE 'license:|attribution|Detection Rule License|DRL|CC-BY|MIT' "$r"; then
      ok "$rel has a license/attribution field"; else bad "$rel missing license/attribution (DRL requires attribution on reuse)"; fi
  done
else
  info "no sigma/ dir yet"
fi

# ---- CHECK H: license + notice present ------------------------------------------------
echo
echo "[H] LICENSE + NOTICE present at repo root"
[ -f "$COOP_ROOT/LICENSE" ] && ok "LICENSE present" || bad "LICENSE missing"
[ -f "$COOP_ROOT/NOTICE" ]  && ok "NOTICE present"  || bad "NOTICE missing"

# ---- summary ------------------------------------------------------------------------
echo
echo "======================================================================"
info "PASS/FAIL tally -> PASS=$pss, WARN=$WARN, FAIL=$FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "RESULT: FAIL  ($FAIL failing invariant(s)) — do NOT deploy until each is resolved."
  exit 1
else
  echo "RESULT: PASS  (0 failing invariants; $WARN advisory WARN to review before deploy)"
  exit 0
fi
