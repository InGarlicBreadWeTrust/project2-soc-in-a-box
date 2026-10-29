# Legal Notes — Licensing & Posture Checklist

Companion to `security-assessment.md`. This doc is the **plain-language legal posture** for a
rural co-op adopting an open-source ICS/OT SOC-in-a-box. **Not legal advice**; confirm with
co-op counsel. Snapshot: 2026-10-28.

---

## 1. Does NERC CIP apply to *your* co-op?
- **Mostly NO** for a small rural co-op that is **not** a Bulk Electric System (BES) operator.
   **But**: state PUC rules, ISO/RTO market rules, and federal/state utility-cyber rules
   *may* impose CIP-like obligations.
- **Decision tree:**
  1. Are you a BES operator under FERC / a CIP-listed entity? → If yes, NERC CIP applies; this
     doc is a floor, not a cert; engage a CIP compliance consultant.
  2. Are you an ISO/RTO member with a market rule that imposes cyber requirements? (PJM,
     MISO, SPP, ERCOT, CAISO, etc.) → likely yes, read that ISO's market rules.
  3. Does your state PUC have a utility-cyber rule? (Several do.) → ask your PUC or counsel.
  4. If in any doubt → **treat as CIP-level.** The cost of over-hardening a co-op is far below the
     cost of a breach or a regulatory finding.

## 2. Copyleft map (what you can/can't do)
| Class | Components (verified SPDX or project license) | What you can do | Risk |
|---|---|---|---|
| **P** fully permissive | `fluent/fluent-bit`(Apache-2.0), `grafana/alloy`(Apache-2.0), `open-telemetry/opentelemetry-collector`(Apache-2.0), `prometheus/prometheus`(Apache-2.0), `prometheus/alertmanager`(Apache-2.0), `tailscale/tailscale`(BSD-3), `open62541/open62541`(MPL-2.0 repo / core BSD-3 per docs), `stephane/libmodbus`(LGPL-2.1), `SigmaHQ/sigma`(DRL-1.1 permissive), `ITI/ICS-Security-Tools`(CC-BY-4.0), RAPSN SETs(MPL-2.0) | Use/moddistribute/link freely; DRL/CC-BY need *attribution* (trivially met). | **Low.** |
| **L** weak copyleft | `libmodbus`(LGPL-2.1), `vyos/vyos-1x`(LGPL-2.1 detected, **verify actual tree**), `OpenSCAP/openscap`(LGPL-2.1) | Call as a library; don't redistribute a modified LGPL binary as proprietary. | **Low.** |
| **G** strong copyleft | `oisf/suricata`(GPL-2.0), `wazuh/wazuh`(GPL-3.0; GitHub SPDX = NOASSERTION — misleading), `mz-automation/lib60870`(GPL-3.0), `mz-automation/libiec61850`(GPL-3.0) | Run as **independent binaries** in their own network segment; **do not** link into co-op proprietary code; if you *modify & distribute* the binary, share source. | **Low if standalone; Medium+ if linked into co-op proprietary code. Keep them independent.** |
| **A** AGPL-3.0 | `grafana/loki`, `grafana/grafana`, `grafana/alerting` | Use **internally** (single-host co-op use = no trigger). Trigger only if you *modify & offer as a networked service to third parties.* | **Low internal; Medium+ if you offer a modified service publicly. Don't offer a modified version publicly.** |

## 3. Privacy checklist (no PII, no call-home, no telemetry)
- [ ] `fluent-bit` `@out` is `loki`/local-file only — **no** external `http`/`s3`/`datadog`.
- [ ] `loki`/`prometheus`/`alloy`/`otel` have **no** `remote_write`/external endpoint.
- [ ] `wazuh` (if used): **`remote_index_server`/cloud disabled, telemetry disabled.**
- [ ] `tailscale` free tier mgmt-only; **no ICS/OT telemetry** traverses it.
- [ ] `zeek`/`suricata` rule sets **mirrored offline** ($RULES/), **no** online rule feed at
      detection time.
- [ ] `sigma` rules offline-mirrored; `SIGMAHQ/sigma` license (DRL-1.1) attribution in match output.
- [ ] `chrony`/`ntpd` local or trusted-upstream; **no DNS leak** of internal hostnames.
- [ ] No component auto-updates or phones home on startup.
- [ ] Egress is `nft` default-deny except co-op-owned alert endpoints.

## 4. Legal posture — the co-op's 10 rules
1. **No PII, no call-home, no telemetry.** If you can name the URL a component reaches out
   to, **block it** or keep it co-op-owned.
2. **Segment control from monitor.** No appliance has a *write* path to the control VLAN.
3. **Don't link copyleft into co-op proprietary code.** Keep GPL/AGPL components **independent
   binaries** in their own segment.
4. **Don't offer a modified AGPL component as a service to third parties.**
5. **Sign + pin + offline-mirror** every rule and binary. Detection works with zero internet.
6. **Use a stewardship fork for ICS-critical dead upstreams** (e.g., `coop-arm-dnp3-steward`
   for `dnp3/opendnp3` which is **archived 2022**).
7. **Permissive license your own glue/config** (Apache-2.0; CC-BY-4.0 for docs).
8. **No secrets in any repo or config.** Pager number + SSH keys stored offline, rotated.
9. **Document the Wazuh/Tailscale cloud-disable step** and **recheck after every upgrade.**
10. **Get co-op counsel** to sign off on NERC-CIP applicability.

## 5. What to **verify by hand** before you ever ship (the SPDX hint can lie)
| Component | What GitHub API said | What to actually check |
|---|---|---|
| `vyos/vyos-1x` | SPDX `LGPL-2.1` | Read the actual `LICENSE` — VyOS historically GPL-3.0 firmware. |
| `open62541/open62541` | SPDX `MPL-2.0` at repo | Project docs say core C is BSD-3-Clause. Either way, **permissive-compatible**. |
| `wazuh/wazuh` | SPDX `NOASSERTION` | Project license is **GPL-3.0**. Standalone only. |
| `zeek/zeek` | SPDX `NOASSERTION` | Verify the current SPDX — historically BSD-3. |
| `ComplianceAsCode/content` | SPDX `NOASSERTION` | Mixed (mostly AGPL/CC). OK to *read* rules, not to link. |
| `SigHQ/sigma` (org was `SigHQ`) | 404'd on the old org | New org = **`SigmaHQ`**; license = DRL-1.1 (permissive, attribution only). |
| `scap-security-guide` | 404'd | Renamed to **`ComplianceAsCode/content`**; fetched OK. |
| `grafana/promtail` | EOL ~2026-03 | Replaced by **`grafana/alloy`** (Apache-2.0, active). |
| `cisa/CSET`, `cisa/malcolm`, `golang-headscale/headscale`, `libnd/libnd` | **404 this pass** | Verify the correct repo name before using. Not in the deploy path by default. |

## 6. Suggested licenses for the co-op's *own* work
- **Glue code / config / stewardship forks: `Apache-2.0`** (permissive + explicit patent
   grant — important for grid assets).
- **Documentation: `CC-BY-4.0`.**
- **This `README.md`/scaffold: `CC-BY-4.0`.**

## 7. What the co-op needs to **not** do
- **Never expose the co-op's mgmt service to the public internet** without alertmanager +
   MFA + rotate-rotation.
- **Never link** a co-op proprietary tool against GPL/AGPL code.
- **Never send** co-op ICS/OT telemetry to any external endpoint.
- **Never auto-update** a production ICS sensor. Pin it.
- **Never** run a co-op tool that requires its author's cloud service (Tailscale cloud relay for
   ICS telemetry, Wazuh cloud) — run standalone or on-prem.
- **Never put secrets in a repo.**
