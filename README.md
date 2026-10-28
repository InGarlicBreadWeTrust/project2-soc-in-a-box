# Project #2 — Co-op SOC-in-a-Box
### Single-host ICS/OT security stack for rural co-operatives with no dedicated SOC

**Status:** First-draft scaffold (research + verified component manifest). Not yet deployed.
**Audience:** rural power/utility co-operatives and small independent operators that must run *some* ICS/OT monitoring but cannot staff a 24x7 SOC and cannot afford commercial Nozomi/Claroty/Armis/ExodusGuard subscriptions.
**Direction/charter:** defensive hardening & grid resilience. **Goal: "help not get sued."** Only permissive-licensed OSS is preferred; everything flagged in this doc is flagged for a reason.
**License of *this* document/scaffold:** CC-BY-4.0 (our own work product). Suggested license for the co-op's own glue code/config: **Apache-2.0** (see `legal-notes.md`).

> No secrets, no credentials, no telemetry, no call-home anywhere in this tree.
> The `verify/` subdirectory holds **raw GitHub API metadata snapshots** for reproducibility — only SPDX/pushed_at/archived/stars, never code or secrets.

---

## 1. What this is

A bill of materials, threat model, security/privacy/legal assessment, and deployment
runbook for running a *single hardened appliance* that does enough ICS/OT security to let a
small co-op **detect, alert, and harden** without a team. It is intentionally a "reference
appliance" — one x64/ARM Linux host in a demilitarized segment that sits *beside* (never
inside) the control network, mirroring OT traffic for detection.

It is deliberately **opinionated**: for an 8-person co-op, more components than the co-op can
operate is *worse* than fewer. The "recommended minimal set" (§4) is what you actually stand up.
Everything else is a documented alternative.

---

## 2. Design principles (non-negotiable)

1. **Permissive-first licensing.** Apache-2.0 / MIT / BSD / MPL-2.0 / CC-BY / Detection Rule
   License are **preferred**. Strong copyleft (GPL) and AGPL are *allowed but flagged* and are
   deployed only as independent binaries in a network segment, never linked into co-op code.
   See `legal-notes.md` for the full "won't get sued" analysis.
2. **No PII, no call-home, no telemetry.** ICS/OT telemetry is *operational* data (breaker
   state, DER output, setpoints) — not human PII but legally/operationally sensitive. Nothing
   in this stack phones home by default. Every component with a default cloud path
   (Tailscale relay, Wazuh cloud index) is called out and turned off.
3. **Offline-detectable.** Detection must keep working with *no* internet connection. Rule sets
   are mirrored on the appliance; a power/internet outage does not blind the co-op.
4. **Single host, but not a single point of failure** for the co-op itself. Power (UPS +
   redundant feed where available), local snapshot backups, auto-restart, and air-gapped rule
   caches mitigate the one-box SPOF.
5. **Passive first, active only on the management side.** OT traffic is mirrored (SPAN/tap).
   No active scanning or active control of PLCs/RTUs from the appliance. The co-op never
   remotely "flips" anything over an untrusted path.
6. **Segmented by default.** The appliance cannot talk *to* the control network; it only sees
   mirrored copies. Reverse direction is hard-blocked at L2/L3 (VyOS + nftables + 802.1Q VLAN).
7. **Operable by a small team.** High-confidence alert routing to a pager/SMS, a human-readable
   runbook, no 24x7 analyst required, tuned down from false-positive-heavy ICS IDS noise.

---

## 3. Architecture (single host, OT-adjacent)

```
                 +---------------------------------------------+
   CONTROL NET   |   OT control network (PLC/RTU/IED/SCADA)     |
   (segment D-CAP, VLAN 3000)   <-- passive SPAN/tap mirror --->
                 |   (the appliance NEVER writes back / never    |
                 |    actively drives control traffic)            |
                 +----------------------+------------------------+
                                        | passive mirror (read-only)
                                        v
   +---------------------------------------------------------------------+
   |  SINGLE HARDENED APPLIANCE  (VLAN 3050 "mgmt/monitor" on the same   |
   |  host; L2/L3 blocked from segment D-CAP except SPAN input)          |
   |                                                                     |
   |  TIER 0  Platform: hardened Debian/Calamares base; nftables + 802.1Q|
   |           + VyOS as the segmentation/firewall appliance (optional)   |
   |           + Tailscale mgmt overlay (on-prem relay, ICS kept OUT)    |
   |                                                                     |
   |  TIER 1  ICS PROTOCOL SENSORS (parse the mirror, emit structured)    |
   |           open62541 (MPL-2.0) | libmodbus (LGPL-2.1)                |
   |           libIEC61850 / lib60870 (GPL-3.0, standalone)             |
   |           opendnp3 (Apache-2.0, ARCHIVED) + co-op stewardship fork  |
   |                                                                     |
   |  TIER 2  NETWORK INSPECTION                                        |
   |           Zeek (NSM) + Suricata (GPL-2.0, standalone)              |
   |           + ICS signature packs (ITI/ICS-Security-Tools CC-BY-4.0,  |
   |             Fox-IT detection, ARMORE/Quickdraw, RAPSN MPL-2.0)      |
   |                                                                     |
   |  TIER 3  LOG / TELEMETRY                                           |
   |           Fluent Bit (Apache-2.0, primary) -> Loki (AGPL, internal) |
   |           Alloy (Apache-2.0, replaces EOL Promtail) + OTel (Apache) |
   |           Prometheus (Apache-2.0) for host metrics                  |
   |                                                                     |
   |  TIER 4  DETECTION RULES                                           |
   |           Sigma (DRL-1.1, permissive) + Suricata/Emerging Threats   |
   |                                                                     |
   |  TIER 5  ALERT / "SOC IN A BOX"                                    |
   |           Alertmanager (Apache-2.0) -> pager/SMS/email             |
   |           Grafana (AGPL) dashboards  [optional] Wazuh (GPL-3.0)     |
   |                                                                     |
   |  TIER 6  HARDENING / BASELINE                                       |
   |           OpenSCAP (LGPL-2.1) + ComplianceAsCode content            |
   |           (+ CISA/NIST ICS guides as PDF policy)                    |
   |                                                                     |
   |  TIER 7  RESILIENCE                                                 |
   |           UPS + offline rule mirror + local snapshot + auto-restart |
   +---------------------------------------------------------------------+
   |   ALERTING OUT: only to co-op mgmt pager/SMS — no external send     |
   |   DATA OUT OF THE BOX: none. No cloud, no telemetry, no call-home.  |
   +---------------------------------------------------------------------+
```

The appliance sits in a **monitor/segment VLAN**. It reads a SPAN/tap mirror of the *control*
segment and never talks back to it. This is the single most important decision: it keeps a
compromised appliance from being a path *into* the control network.

---

## 4. Recommended minimal set (what a co-op actually ships)

For "help not get sued" with minimal operation: `nftables/VLAN` + `Zeek` + `Suricata` +
`ITI/ICS-Security-Tools` signatures + `Fluent Bit -> Loki` + `Alertmanager -> pager` +
`OpenSCAP`, plus one ICS parser (`opendnp3` stewardship fork **if the co-op runs DNP3**,
`libmodbus` if Modbus-TCP, `libIEC61850`/`lib60870` if the co-op has those).

Everything in Tier 3/4/5 is optional beyond `Fluent Bit + Alertmanager`. Do not ship all of
them at once — ship the minimal set, operate it, then add.

See `components-manifest.md` for the full verified bill of materials with per-component license,
last-push date, permissiveness class, and per-component risks.

---

## 5. Documents in this repo

| File | Purpose |
|---|---|
| `README.md` | This PRD + architecture + headline assessments |
| `components-manifest.md` | Every candidate component → verified license + aliveness + permissiveness class + risk |
| `security-assessment.md` | Threat model, privacy assessment, legal/copyright/NERC-CIP analysis |
| `deployment-runbook.md` | Single-host provisioning, VLAN/SPAN, per-tier bring-up + validation |
| `legal-notes.md` | Copyleft/AGPL/"won't get sued" checklist + suggested licenses for co-op work |
| `verify/` | Raw GitHub API snapshots (`r*.json`), `manifest.csv`, `reverify.sh`, `README.md` |

---

## 6. Assumptions & out-of-scope

- The co-op **is not** a NERC CIP-covered bulk-electric operator (verify locally — if it *is*,
  you are out of our scope and under formal regulatory posture; see `security-assessment.md §4`).
- The co-op **can** provide a hardened Linux host, a network SPAN/tap, a UPS, and a pager/SMS
  endpoint for high-confidence alerts.
- Remote management is over a **separate** management network (Tailscale on-prem relay or a
  dedicated mgmt link). ICS/OT telemetry never traverses the public internet.
- This is a **first draft**. Components are research-verified (license + aliveness snapshot,
  2026-10-28) but *not* penetration-tested, not performance-tuned for a specific co-op, and not
  validated against a live (or lab) ICS estate. `remaining/` work is catalogued in the final
  report.

---

## 7. Verification methodology (reproducible)

Every component's license + last-push + archived flag was fetched live from the **GitHub REST API**
(`GET /repos/:owner/:repo`) with a custom user-agent `coop-soc-scout/1.0`, tight timeouts
(`--connect-timeout 3 --max-time 7`), and one request per repo to respect rate limits and stay
within unauthenticated quotas (60/hour). Raw responses are preserved under `verify/r*.json`;
`verify/manifest.csv` is the flattened machine-readable view; `verify/reverify.sh` reproduces the
fetch. See `verify/README.md`. Snapshot timestamp: **2026-10-28 (UTC)**.

No secrets or credentials were read, written, or transmitted. This scaffold is clean by
construction.
