# Components Manifest — Co-op SOC-in-a-Box

Each line: `component (role) -> chosen OSS tool -> SPDX license (GitHub-verified) -> last-push /
aliveness -> permissiveness class -> why this one -> per-component risk`.

Verification source: GitHub REST API, `coop-soc-scout/1.0`, 2026-10-28 UTC. Raw JSON in
`verify/r*.json`, machine-readable flattened in `verify/manifest.csv`, reproducable via
`verify/reverify.sh`.

### Legit license-classes (co-op permissiveness lens)
- **P = fully permissive** (MIT / Apache-2.0 / BSD / MPL-2.0 / CC / Detection-Rule-Lic): no
  copyleft exposure. **Preferred.**
- **L = weak copyleft** (LGPL-2.1/3.0): safe to call as a shared library from co-op code; do not
  modify-and-redistribute the LGPL binary itself as proprietary.
- **G = strong copyleft** (GPL-2.0/3.0): use only as an **independent binary** in its own segment;
  **do not** link into co-op proprietary code.
- **A = AGPL-3.0**: fine internal; obligation only triggers if you **modify AND offer as a
  networked service to third parties**.
- **D = dead / archived / EOL**: high maintenance risk; prefer a co-op stewardship fork.

---

## TIER 0 — Platform & segmentation

| Component -> tool | License (verified) | Last-push / aliveness | Class | Why | Per-component risk |
|---|---|---|---|---|---|
| Segmentation/firewall appliance -> **VyOS** `vyos/vyos-1x` | LGPL-2.1 (GitHub-detected; VyOS project historically GPL-3.0 — **verify the actual tree**) | 2026-10-28, 1958★, not archived | L | Mature L2/L3 router + ACL firmware, ideal for a single-host OT segmentation appliance. | GitHub SPDX detection is LGPL but the real tree may differ; **confirm license file before use**. |
| Kernel firewall (fallback/appliance-internal) -> **nftables / iptables** (Linux `netfilter`) | License of the kernel: GNU GPL-2.0 (kernel) — used in-kernel, never distributed by co-op | in-tree, continuous | G (kernel) | No install step; the most reliable "block reverse direction" control. | Kernel-level; changes need a patch cycle. Default policy = deny must be re-asserted after upgrades. |
| 802.1Q VLAN + SPAN mirror config | n/a (host config) | — | P (config) | Passes mirrored control traffic to the monitor VLAN only. | Misconfig can leak a write path into control — test block-direction with a packet capture before production. |
| Out-of-band mgmt tunnel -> **Tailscale** `tailscale/tailscale` | BSD-3-Clause | 2026-10-27, 38211★, active | P | Easy encrypted mgmt overlay with device auth. | **PRIVACY:** Tailscale's default relay/coordination server routes through Tailscale cloud. For a no-call-home co-op use the free tier only for *co-op mgmt* devices, **never mirror ICS telemetry through it**, or self-host a coordinator (headscale was unverified this pass — see `remaining/`). Prefer a dedicated mgmt link. |
| Network monitoring engine — **Zeek** `zeek/zeek` | NOASSERTION on GitHub; Zeek is BSD-licensed (verify the current SPDX tag — historically BSD-3) | 2026-10-28, 3420★, active | P(L) | Best-in-class lightweight NSM; strong ICS scripts (DNP3/Modbus/IEC). | Confirm current SPDX tag; Zeek license historically BSD-3 but verify the LICENSE file. |

## TIER 1 — ICS protocol sensors (parse the mirrored OT traffic)

| Component -> tool | License (verified) | Last-push / aliveness | Class | Why | Per-component risk |
|---|---|---|---|---|---|
| OPC-UA (Modbus/MMS bridge, DER, some IEDs) -> **open62541** `open62541/open62541` | **MPL-2.0** (repo); project docs say core C/BSD-3 — both permissive | 2026-10-28, 3261★, active | P | Leading open OPC-UA stack; clean for DER/smart-instrument visibility. | MPL-2.0 is file-level weak copyleft — fine; don't ship a modified open62541 *file* as proprietary without honoring MPL. |
| Modbus-TCP/RTU -> **libmodbus** `stephane/libmodbus` | LGPL-2.1 | 2026-07-02, 4278★, active | L | Reference Modbus lib for passive Modbus-TCP inspection. | **Single maintainer** (stephane) — bus-factor-1; acceptable as a shared lib call but monitor upstream. |
| IEC 60870-5-101/104 (SCADA) -> **lib60870** `mz-automation/lib60870` | **GPL-3.0** | 2026-08-31, 601★, active | G | De-facto C/CLI parser for 60870; standalone use only (don't link into co-op code). | GPL-3.0 — keep as independent binary; no static link into proprietary co-op tools. |
| IEC 61850 (substation/MMS, GOOSE, SV) -> **libiec61850** `mz-automation/libiec61850` | **GPL-3.0** | 2026-10-21, 1237★, active | G | Same author as lib60870; best open 61850 client/server for substation visibility. | Same GPL-3.0 constraint as lib60870. |
| DNP3 (utilities/co-ops) -> **OpenDNP3** `dnp3/opendnp3` + **co-op stewardship fork** | Apache-2.0 | **2022-05-18, 336★, ARCHIVED** | D | Correct protocol lib, but **dead upstream**. | **Maintenance risk = high.** Use the co-op's own `coop-arm-dnp3-steward` (sibling project) as the authoritative fork; vendor + sign Patches; do **not** depend on a dead repo for an ICS-critical path. |
| DNP3 parsing alt / libnod (ICS-CERT) `libnd/libnd`(nominal) | unverified — 404 this pass | unverified | D | ICS-CERT reference parsers exist; not confirmed this pass. | Resolve correct repo before deploy; treat as reference only. |

## TIER 2 — Network inspection & ICS signatures

| Component -> tool | License (verified) | Last-push / aliveness | Class | Why | Per-component risk |
|---|---|---|---|---|---|
| Network NIDS -> **Suricata** `oisf/suricata` | **GPL-2.0** | 2026-10-27, 17177★, active | G | Fast, mature, supports `modbus`/`dnp3` app-layer parsing and inline/IDS. | GPL-2.0 — standalone binary only. |
| ICS signature pack (aggregate source) -> **ITI/ICS-Security-Tools** `ITI/ICS-Security-Tools` | CC-BY-4.0 | 2025-04-15, 2074★, active (note: *not very recent* — last push ~18 months) | P | Curated pointers to Digital Bond **Quickdraw** (Modbus/DNP3/EtherNet/IP), **RAPSN SETs** (MPL-2.0), Talos community, ARMORE. **Best ICS-rules starting point.** | Content not updated very recently; validate each sub-pack's own license (MPL-2.0/CC-BY are permissive-good). |
| Emerging Threats community rules (non-ICS, defense depth) -> `isc-sig/...`/ET | mixed (ET is permissive community license) | active | P | Defense-in-depth for the mgmt segment. | Not ICS-specific; tune to avoid noise on OT mirror. |
| ARMORE (ICS NDR) `armore/armore` | reference-only (not verified this pass) | unverified | ? | Purpose-built open ICS NDR built on Zeek; good reference. | Verify license before use; reference only. |
| Fox-IT / detection-rule repos `fox-it/*` (e.g. `fox-it/cisco-ios-xe-implant-detection`) | per-repo, usually MIT-ish/permissive | active | P | High-quality, published detection rules incl. ICS/OT. | Per-repo license varies; check each. |

## TIER 3 — Log / telemetry

| Component -> tool | License (verified) | Last-push / aliveness | Class | Why | Per-component risk |
|---|---|---|---|---|---|
| **Primary** lightweight collector -> **Fluent Bit** `fluent/fluent-bit` | Apache-2.0 | 2026-10-28, 24422★, active | **P** | C, low memory, fast, permissive — ideal edge/OT collector. **Ship this first.** | None material; mind its `@out` destinations (no external by default). |
| Log store -> **Loki** `grafana/loki` | **AGPL-3.0** | 2026-10-28, 24359★, active | A | Great log store, pairs with Grafana. | AGPL-3.0 — fine internal; don't build a modified networked log-service offered to third parties. |
| Collector v2 replacing Promtail -> **Grafana Alloy** `grafana/alloy` | Apache-2.0 | 2026-10-28, 3650★, active | **P** | Replaces **Promtail** (EOL ~2026-03). Use Alloy, not Promtail. | Newer; watch maturity. Avoid Promtail (EOL). |
| Metrics collector -> **OpenTelemetry Collector** `open-telemetry/opentelemetry-collector` | Apache-2.0 | 2026-10-28, 30480★, active | P | Vendor-neutral OTel pipeline; permissive. | Larger footprint than Fluent Bit. |
| Metrics scrape -> **Prometheus** `prometheus/prometheus` | Apache-2.0 | 2026-10-28, 66826★, active | P | De-facto metrics; permissive. | Not ICS-specific; fine for host/appliance metrics. |
| Heavy collector (optional) -> **Fluentd** `fluent/fluentd` | Apache-2.0 | 2026-10-27, 11978★, active | P | If the co-op needs the rich plugin ecosystem. | Heavy (Ruby) for a co-op; prefer Fluent Bit. |
| ~~Promtail~~ `grafana/promtail` | AGPL-3.0 | **EOL** | D | **Do not deploy — superseded by Alloy.** | EOL — no updates/security fixes. |
| ~~Vector~~ `datadog/vector` | Apache-2.0 (expected) | 404 this pass | — | Replaced by Fluent Bit/Alloy/OTel in this design. | Not needed; not re-verified. |

## TIER 4 — Detection-rule layers

| Component -> tool | License (verified) | Last-push / aliveness | Class | Why | Per-component risk |
|---|---|---|---|---|---|
| Generic detection-rule format -> **Sigma** `SigmaHQ/sigma` (org was `SigHQ`, renamed — explains earlier 404) | **Detection-Rule-License 1.1** (MIT-based, permissive) | active | **P** | Vendor-neutral detection language; pairs to any SIEM. | DRL requires **attribution on rule reuse + in match output** — trivially met. |
| Sigma tooling -> `SigHQ/sigma-rules-validator` | Apache-2.0 | active | P | Rule-lint/validation. | None material. |

## TIER 5 — Alert / "SOC in a box"

| Component -> tool | License (verified) | Last-push / aliveness | Class | Why | Per-component risk |
|---|---|---|---|---|---|
| Alert routing -> **Alertmanager** `prometheus/alertmanager` | Apache-2.0 | 2026-10-28, 1605★, active | **P** | Routes/dedups/escalates -> pager/SMS/email. The "SOC-in-a-box" brain. | None material. Ensure alert destinations are co-op-owned endpoints only. |
| Dashboards -> **Grafana** `grafana/grafana` | AGPL-3.0 | 2026-10-28, 66014★, active | A | Alerting + dashboards; permissive for internal single-host use. | AGPL — internal-only use is fine; modified networked service to 3rd parties triggers AGPL. |
| Alerting (Grafana-native) -> **grafana/alerting** | AGPL-3.0 | 2026-10-28, 1928★, active | A | Native alerting; may prefer Alertmanager for routing control. | AGPL, same as Grafana. |
| Optional SIEM -> **Wazuh** `wazuh/wazuh` | **NOASSERTION on GitHub; project is GPL-3.0** | 2026-10-27, 25862★, active | G/L | Full OSS SIEM (HIDS/NIDS/file-integrity). | **Privacy risk:** Wazuh agent has a **default cloud index-server / telemetry path** to Wazuh — **must disable** `wazuh-indexer`/cloud & `telemetry` opt-outs for no-call-home. GPL-3.0: standalone only. |

## TIER 6 — Hardening / baseline

| Component -> tool | License (verified) | Last-push / aliveness | Class | Why | Per-component risk |
|---|---|---|---|---|---|
| SCAP benchmark enforcement -> **OpenSCAP** `OpenSCAP/openscap` | **LGPL-2.1** | 2026-10-27, 1042★, active | L | Run CISA/NIST/OSAP profiles against the appliance itself. | LGPL — fine as a called tool. |
| Benchmark content (incl. CISA/NIST/OSAP rules) -> **ComplianceAsCode/content** `ComplianceAsCode/content` (was `scap-security-guide/scap-security-guide`, renamed — earlier 404) | NOASSERTION (mixed, mostly AGPL/CC; **verify per-profile license**) | 2026-10-27, 2830★, active | varies | Single source for most published SCAP rulesets. | NOASSERTION — check each profile's license; most are AGPL/CC (permissive-good for reading, not for linking). |
| Policy source — **NIST SP 800-82 (r3 OT)** + **CISA Cybersecurity Best Practices for ICS** | U.S. public domain (federal docs) | current PDFs | P | The authoritative co-op/ICS hardening references. | PDFs only — operationalize via OpenSCAP/ComplianceAsCode content; no repo. CISA "ICS-NPP" name does **not** exist as a project — see `remaining/`. |

## TIER 7 — Resilience (not a tool, a design)
UPS + redundant feed where available, local snapshot/restore, OS auto-restart of sensor
services (`systemd` `restart=on-failure`), and an **air-gapped rule mirror** so detection survives
internet/power loss. Documented in `deployment-runbook.md`.

---

## Quick "permissive-only" subset (what a co-op ships with zero legal anxiety)
`nftables/VLAN` + `VyOS`(`L` verify) + `Zeek`(`P` verify) + `Fluent Bit`(P) + `Loki`(AGPL,internal)
+ `Alloy`(P) + `OpenTelemetry`(P) + `Prometheus`(P) + `Alertmanager`(P) + `Sigma`(P) +
`OpenSCAP`(`L`) + `libmodbus`(`L`) + `open62541`(`P`).
**Add, but flag & contain in its own binary/segment:** `Suricata`(G), `lib60870`/`libiec61850`(G),
`opendnp3`+stewardship-fork(G-allowed/Apache but **DEAD upstream**).
**Contain as network-only or disable default cloud path:** `Loki`/`Grafana`(AGPL internally fine),
`Wazuh`(GPL — **disable default cloud+telemetry**), `Tailscale`(free-tier mgmt only, keep ICS out).

## Verification caveats
1. GitHub SPDX detection is a *hint*; for `VyOS`(detected LGPL, tree may differ),
   `open62541`(repo MPL-2.0 vs documented BSD-3), `Wazuh`(NOASSERTION, project is GPL-3.0),
   `ComplianceAsCode`(NOASSERTION mixed), and `Zeek`(NOASSERTION, historically BSD-3) — **read the
   actual LICENSE file** before relying on the field.
2. `dnp3/opendnp3` is **archived (2022)** — an ICS-critical dependency on a dead upstream is the
   single biggest operational risk; the co-op stewardship fork is the mitigation.
3. `grafana/promtail` is **EOL** — replaced by Alloy; `datadog/vector` and
   `scap-security-guide`/`SigHQ` paths **404'd/renamed** this pass.
4. CISA "ICS-NPP" and `cisa/CSET`/`cisa/malcolm` were **not confirmed** as OSS repos this pass;
   treat as references to verify before use. Snapshot: 2026-10-28.
