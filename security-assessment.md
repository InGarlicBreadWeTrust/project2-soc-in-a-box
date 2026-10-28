# Security, Privacy & Legal Assessment — Co-op SOC-in-a-Box

Companion to `README.md` and `components-manifest.md`. Scope: **defensive direction only**,
goal = "help the co-op not get sued / not get breached." No offensive capability anywhere in this
design; the appliance mirrors and *never* drives control traffic.

---

## 1. Threat model (what the co-op is actually exposed to)

### 1.1 Assets
- The co-op's **energy supply control network** (PLCs, RTUs, IEDs, SCADA/DER controllers) — the
  crown-jewel asset: a breach can **physically affect the grid** (over/under-voltage, lost load,
  DER fault), not just data.
- OT **operational telemetry** (breaker state, setpoints, DER output) — sensitive, not human PII,
  but legally/operationally significant.
- The **co-op mgmt segment** itself (the one box + admin access).

### 1.2 Adversaries & how they'd come (ranked by plausibility for a rural co-op)
1. **Externally exploited OT/SCADA** via the *mgmt segment* (most likely): a coop IT admin
   reuses a password, an unpatched mgmt service is exposed to the internet, or a supplier RDP
   path is abused. **Defense:** no internet on control net; mgmt on a separate segmented overlay;
   MFA + rotated keys; alertmanager-to-pager for any external mgmt access.
2. **Supply-chain / open-source compromise**: a co-op pulls an unmaintained or compromised
   ICS parser; a dependency gets a zero-day. **Defense:** pin + sign + offline-mirror every rule
   and binary; use the co-op **stewardship fork** for dead upstreams (`opendnp3`); only
   permissive-or-verified components.
3. **State-sponsored / nation-state** (low but non-zero against a grid): APT against the SCADA
   vendor channel. **Defense:** passive monitoring (you can't detect what you don't see), ICS
   signature coverage (DNP3/Modbus/IEC), anomaly detection on OT mirror, fast offline backup so
   you can recover and call the right responders.
4. **Insider / misconfig**: a co-op admin fat-fingers a VLAN config and leaks a write path into
   control. **Defense:** 802.1Q + nftables *default-deny* into control; test the block direction
   with a packet capture every deploy; no "write" ACLs to the control VLAN.
5. **Supply / physical**: physical access to the appliance, UPS failure, single-feed power loss.
   Defense: UPS + redundant feed, tamper-evident, local snapshot.
6. **Data exfil of OT telemetry**: an attacker in the mgmt segment scrapes logs/rules.
   Defense: no external exfil paths, egress ACLs deny, no `@out` destinations pointing off-box.

### 1.3 What this design does NOT defend against
- Real-time **active cyber-defense** (no active blocking of control traffic from the appliance —
  by design, to avoid destabilizing the grid).
- **Physical** tamper beyond a tamper-evident enclosure + tamper alerting.
- **Vendor backdoor** inside a *proprietary* PLC/IED firmware (out of scope; co-op can't inspect
  the vendor's device firmware).
- Anything requiring a **live ICS test bed** — this is a paper design; see `remaining/`.

---

## 2. Privacy assessment (no PII, no call-home, no telemetry)

**Requirement restated:** the co-op's ICS/OT data includes *no human PII* but is operationally
sensitive; the stack must have **no default call-home / telemetry to any third party.**

| Concern | Where it could hide | What we do |
|---|---|---|
| **Wazuh default cloud index-server + telemetry** | Wazuh agent has a default path sending index data to `wazuh` cloud + telemetry. | **Disable** `remote_index_server`/cloud, and set Wazuh `telemetry: disabled`. Run Wazuh standalone only. |
| **Tailscale relay/coordination** | Tailscale free tier routes through Tailscale cloud by default. | Use free tier **only for co-op mgmt devices**, **never mirror ICS telemetry over it**; prefer a dedicated mgmt link or self-host a coordinator (headscale — unverified, see `remaining/`). |
| **Loki/Grafana/Alertmanager** | Could forward to remote endpoints. | All local; no `@out`/remote-write to any external URL. Egress deny-by-default. |
| **Fluent Bit** | Could `@out` to a remote log store / S3 / Datadog. | Only local `@out loki`/`file`. No external. |
| **Prometheus / Alloy / OTel** | Could remote-write to a cloud. | No remote-write; all local. |
| **Suricata / Zeek** | Emerging Threats / rule **downloads**. | **Mirror rule sets offline** on the appliance; disable online rule-update by default; no external rule feeds. |
| **Sigma / ComplianceAsCode** | Rule/benchmark **fetches**. | Cache locally; offline mirror; no upstream fetch at detection time. |
| **Any component update / self-update** | A component that auto-updates or phones home on startup. | `systemd` `no auto-update`; pin versions; no `apt`/`pip` auto-update in production. |
| **DNS / NTP** | Leaks internal hostnames / time queries. | Local `chrony`/`ntpd` to a trusted upstream or a local NTP source; minimal DNS out (or no DNS for the appliance). |

**Net:** with the controls above, the co-op's data never leaves the appliance except to its own
pager/SMS/email alerting endpoints (chosen by the co-op). No PII is in scope; no telemetry by
default. **The single most important config check**: grep the appliance config for any outbound
URL, any S3/HTTP endpoint, any `remote_write`, any `@out http`, and disable it.

---

## 3. Legal / copyright assessment (the "help not get sued" core)

### 3.1 Co-op's actual legal posture
- **NERC CIP** likely **does not apply** to a small rural co-op **unless** it operates
  *bulk-electric-system*-class assets under NERC jurisdiction. **Verify locally.** The co-op
  should ask its state PUC/ISO/RTO about applicability; if CIP applies, this doc is a floor, not
  a ceiling (see `remaining/`).
- **State utility regulatory** rules (e.g., California, TX/ERCOT, PJM, MISO) may apply — co-op
  counsel should confirm.
- **No IEC 61850/60870 license obligation** for the co-op itself just by *parsing* the protocol.
  The protocol **parsers** (`lib60870`/`libiec61850`, GPL-3.0) impose **GPL obligations only on
  the co-op if the co-op *modifies and distributes* the parser binary.** Standalone binary parsing
  in the co-op's own segment does **not** obligate the co-op.
- **Modbus/OPC-UA/DNP3 protocols themselves** are not copyrighted; parsing them is fine.

### 3.2 Copyleft map and what it obligates the co-op
| Class | Components | Obligation | Risk to "not get sued" |
|---|---|---|---|
| **Fully permissive** (P): Apache/MIT/BSD/MPL/CC/DRL | Fluent Bit, Alloy, OTel, Prometheus, Alertmanager, Tailscale, open62541, libmodbus(L), Sigma(DRL), ICS-Security-Tools, RAPSN SETs(MPL) | **None** beyond attribution (DRL requires attribution + match-output notice — trivially met). | **Low.** Use freely, even link into co-op code. |
| **Weak copyleft** (L): LGPL-2.1 | libmodbus, VyOS(? verify), OpenSCAP | Call the library; **do not** redistribute a *modified* LGPL binary as proprietary. | **Low.** Fine for co-op. |
| **Strong copyleft** (G): GPL-2.0/3.0 | Suricata(GPL-2.0), Wazuh(GPL-3.0), lib60870/libiec61850(GPL-3.0) | Must be used as **independent binaries** in their own segment; **don't** link into co-op proprietary code, and if co-op *modifies & distributes* the binary, share source. | **Medium — avoid linking.** As standalone ICS-detection binaries, **risk = low.** As a *component of a co-op proprietary product*, risk = high. **Keep them independent.** |
| **AGPL-3.0** (A) | Loki, Grafana, grafana/alerting | Triggers if you **modify AND offer as a networked service to third parties.** Internal use = **no** trigger. | **Low for single-host internal use.** **Medium+ if the co-op ever offers a modified version to external users.** Don't do that. |

### 3.3 Copyleft "gotchas" to flag explicitly
- **Wazuh = GPL-3.0** (NOT permissive, NOT "open" in the permissive sense). Its `NOASSERTION`
  SPDX on GitHub is misleading; the project license is GPL-3.0. Keep it standalone.
- **lib60870 / libiec61850 = GPL-3.0.** Same author (`mz-automation`), actively maintained.
- **open62541** SPDX field shows **MPL-2.0** at the repo but the project docs say core C is
  BSD-3-Clause — **verify the actual LICENSE file**; either way permissive-compatible.
- **VyOS** SPDX is detected as LGPL-2.1 but VyOS historically ships GPL-3.0 firmware —
  **verify before relying on the license field.**

### 3.4 Suggested licenses for the co-op's *own* work
- **Co-op glue code/config / stewardship forks:** **Apache-2.0** (permissive, has explicit patent
  grant — important for a grid asset), with a "no warranty" disclaimer. CC-BY-4.0 is an OK
  alternative for documentation.
- **This project's `README.md`/scaffold:** CC-BY-4.0.

### 3.5 What's in `verify/reverify.sh`
- No secrets, no tokens, no credentials, no call-home. One GitHub API fetch per repo with a
  custom UA, tight timeouts, and a raw JSON snapshot under `verify/`. The snapshot is data, not
  code, no secrets. The only environment variable is `GITHUB_TOKEN` if unauthenticated quotas
  need boosting — it is *read* by the shell, not written to disk or committed.

---

## 4. NERC CIP / regulatory applicability — how to decide
1. Is the co-op a **Bulk Electric System** operator or under a FERC jurisdiction for bulk power?
   If **no**, NERC CIP likely **does not apply** but **state** utility rules may.
2. Is the co-op a member of an **RTO/ISO** (PJM, MISO, SPP, ERCOT, CAISO, etc.) and does that
   ISO impose CIP-like rules on its generators/load? **Check the ISO's market rules.**
3. If in doubt → **treat as CIP-level.** Cost of over-hardening a co-op is far below the cost of
   a breach or a regulatory finding. This doc is intentionally **defensive-floor**, not a
   compliance cert.

## 5. Residual risks / what's left (`remaining/`)
- The scaffold is **paper-first**: no lab ICS test bed, no performance tuning, no live
  penetration test. **Validate in an isolated OT lab (VLAN 3050) before production** and with the
  co-op's IT/counsel.
- Confirm each **per-repo license** (per §3.3) by reading the actual `LICENSE` file before
  relying on the SPDX field — the SPDX hint can be wrong (see VyOS, open62541, Wazuh, Zeek,
  ComplianceAsCode).
- Confirm correct repo names for `cisa/CSET`, `cisa/malcolm`, `golang-headscale/headscale`,
   `libnd`/`libnod` — all 404'd this pass.
- `opendnp3` is **archived (2022)** — depend on the co-op **stewardship fork** `coop-arm-dnp3-steward`
   and re-verify its activity.
- `Wazuh` and `Tailscale` **default cloud/telemetry paths** must be disabled in config before
  production (see §2). Document the disable step in the config and re-check after each upgrade.
