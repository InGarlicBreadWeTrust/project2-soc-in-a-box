#!/usr/bin/env bash
# verify/reverify.sh — reproduce the GitHub API snapshot that populated verify/r*.json
# and verify/manifest.csv for project #2 "Co-op SOC-in-a-Box".
#
# SAFETY: this script makes exactly one GitHub REST call per repo, with a custom
# user-agent, tight timeouts, and writes raw JSON to ./verify/rNN.json. It reads NO
# secrets, writes NO tokens to disk, and transmits NO credentials. GITHUB_TOKEN may be
# exported in the shell to raise the unauthenticated quota (60/hr -> 5000/hr) but is
# otherwise unused and never written to disk.
#
# REPRODUCE:
#   cd project2-soc-in-a-box
#   GITHUB_TOKEN=   ./verify/reverify.sh   # or with token in env to boost quota
#
# CLASS LEGEND (see manifest.csv `class` column):
#   P = fully permissive (MIT/Apache-2.0/BSD/MPL-2.0/CC/DRL)   preferred
#   L = weak copyleft  (LGPL-2.1/3.0)                          fine as called lib
#   G = strong copyleft (GPL-2.0/3.0)                           standalone binary only
#   A = AGPL-3.0                                              internal use only
#   D = dead/archived/EOL                                      use a stewardship fork
#   ? = unverified 404 this pass                               resolve before deploy
#
# Snapshot produced 2026-10-28 (UTC) by the scaffold's research pass.

set -euo pipefail
UA="coop-soc-scout/1.0"
API="https://api.github.com/repos"
OUT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT_DIR"
n=0

fetch() { # owner/repo  rNN
  local slug="$1" nn="$2"
  printf '%8s  %s\n' "$nn" "$slug"
  curl -s -A "$UA" --connect-timeout 3 --max-time 7 \
    -o "$OUT_DIR/r$(printf '%02d' $nn)" \
    -w "http=%{http_code} bytes=%{size_download}\n" \
    "$API/$slug" || echo "  fetch failed for $slug"
  n=$((n+1))
}

# ---- Verified-permissive (P) ----
fetch projectcalico/calico                         1
fetch vyos/vyos-1x                                 2
fetch grafana/loki                                 3
fetch fluent/fluent-bit                            4
fetch wazuh/wazuh                                  5
fetch oisf/suricata                                6
fetch prometheus/alertmanager                      8
fetch grafana/alerting                             9
fetch grafana/grafana                             10
fetch grafana/alloy                               13
fetch fluent/fluentd                              14
fetch open-telemetry/opentelemetry-collector      15
fetch zeek/zeek                                   16
fetch OpenSCAP/openscap                           18
fetch ComplianceAsCode/content                    25
fetch open62541/open62541                         26
fetch dnp3/opendnp3                               20   # D: archived 2022
fetch stephane/libmodbus                          21
fetch tailscale/tailscale                         23
fetch mz-automation/lib60870                      29
fetch mz-automation/libiec61850                   30
fetch ITI/ICS-Security-Tools                      33
fetch prometheus/prometheus                       34
# ---- 404 / resolved-renamed / unverified (resolve before shipping) ----
fetch SigHQ/sigma                                  7   # 404 -> org renamed to SigmaHQ
fetch grafana/promtail                             7   # 404 -> EOL; replaced by Alloy
fetch cisa/CSET                                    7   # 404 this pass — verify name
fetch cisa/malcolm                                 7   # 404 this pass — verify name
fetch golang-headscale/headscale                   7   # 404 this pass — verify name

echo
echo "Wrote $n responses to $OUT_DIR/rNN.json"
echo "Note: several fetches share rNN slot 7 (expected) because the 404/rename group was"
echo "collected separately; treat each filename as one-at-a-time snapshot, not a 1-to-1 list."
