# Deployment Runbook — Co-op SOC-in-a-Box (single host)

First-draft, **validate-in-lab-first** runbook. No step touches a live control network. All
steps assume a single hardened Debian-based host in VLAN 3050 ("mgmt/monitor"), receiving a
read-only **SPAN/tap mirror** of the control VLAN (3000). No write path to control.

> Pre-requisites the co-op must be able to provide: a hardened Linux host (x64/ARM), a network
> SPAN/tap or a second NIC for mirroring, a UPS + redundant feed where available, one co-op
> pager/SMS endpoint for high-confidence alerts, and a dedicated mgmt link (or Tailscale free
> tier used *only* for mgmt devices, never for ICS telemetry).

---

## 0. Golden rules (read first)
1. **Passive only.** The appliance NEVER drives/actuates control traffic. The mirror interface
   receives only. There is **no** interface with a *write* path to VLAN 3000.
2. **Default-deny out.** Egress from the appliance is denied except to co-op-chosen alert
   endpoints and a pinned, time-boxed, local-mirrored rule-fetch channel. No internet by default.
3. **No PII / no call-home.** No `@out` external, no `remote_write`, no `http` destination,
   no cloud index server, no telemetry.
4. **Offline-detectable.** Rule sets mirrored on the box. Power/internet loss does not blind
   detection.
5. **Permissive-first.** Anything copyleft (Suricata/Wazuh/lib60870/libiec61850) runs as an
   **independent binary**, not linked into co-op code. See `legal-notes.md`.

---

## 1. Host hardening (Tier 0) & segmentation
1. Install a minimal hardened Debian. Disable network-on-boot autoconfig for the mgmt NIC.
   Enable `systemd` `no auto-update`; pin versions.
   ```
   # example: /etc/systemd/system/aps-soc-monitor.service  (per service)
   [Service]
   Restart=on-failure
   RestartSec=3
   TimeoutStartSec=90
   ProtectSystem=strict   ProtectHome=yes   PrivateTmp=yes
   ```
2. **VLAN topology** (on the co-op's physical switch + on the appliance's NICs):
   - VLAN 3000 = control PLANT/OT (READ-ONLY mirror only).
   - VLAN 3050 = `mgmt/monitor` (this appliance + co-op admin only).
   - **No VLAN interface on this appliance has a write path to 3000.**
   ```
   # ip link (on the appliance, illustrative)
   # eth0 = VLAN 3050 mgmt, eth1 = passive SPAN/tap mirror of VLAN 3000 (receives only)
   ip -d link show eth1   # should show a SPAN/monitor mode on the switch side, RX only
   ```
3. **nftables default-deny** on the appliance (illustrative, **test in lab first**):
   ```nft
   table ip coop_soc {
     chain input { ip saddr @trusted_admin allow  ;  ip saddr @local_mgmt allow ;  drop ; }
     chain output { ip saddr @alert_endpoint accept ;  drop ; }
     ip saddr @trusted_admin . . ip saddr @local_mgmt . . drop  # never to control VLAN
   }
   ```
4. **VyOS as the segmentation appliance** (`vyos/vyos-1x`, LGPL **verify the actual tree**):
   run VyOS as the co-op's L2/L3 router/firewall between mgmt, monitor, and control VLANs.
   Re-check license file before deploy. Default-deny inter-VLAN; permit only SPAN mirror RX on
   the monitor side.
5. **Tailscale** (free tier, `P`): **only** for co-op mgmt devices, on-prem relay where
   possible, **never** for ICS/OT telemetry. If a self-hosted coordinator is needed,
   `golang-headscale/headscale` (unverified this pass — see `remaining/`).
6. **Time sync**: local `chrony` to a trusted upstream or an on-prem NTP; minimize DNS out.

## 2. Bring up the sensors (Tier 1) — only the protocols the co-op actually runs
Pick **only** per co-op estate — do not run all:
- **DNP3** (typical for co-ops): `dnp3/opendnp3` (Apache-2.0, **ARCHIVED 2022**) → use the co-op
   **stewardship fork** `coop-arm-dnp3-steward` as the authoritative fork; pin + sign.
- **Modbus-TCP**: `stephane/libmodbus` (LGPL-2.1, active 2026-07) — single-maintainer, fine as a
   called lib.
- **IEC 61850** (substation/GOOSE/SV): `mz-automation/libiec61850` (GPL-3.0, active) —
   **standalone binary only**; don't link into co-op code.
- **IEC 60870-5-101/104** (SCADA): `mz-automation/lib60870` (GPL-3.0, active) — same.
- **OPC-UA / DER visibility**: `open62541/open62541` (**MPL-2.0 at repo / per docs core BSD-3** —
   verify LICENSE). Permissive-compatible.
Each parser: `systemd` `Restart=on-failure`, write to a local file/socket, no external output.

## 3. Network inspection (Tier 2)
- **Zeek** (`zeek/zeek`, verify current SPDX — historically BSD-3): run with ICS scripts
   (DNP3/Modbus/IEC). Output to `fluent-bit` (local) + local log files. No `@out` external.
- **Suricata** (`oisf/suricata`, GPL-2.0, standalone): IDS mode, app-layer `modbus`/`dnp3`
   enabled. Alert via eve-json to `fluent-bit`. **Signature source:** `ITI/ICS-Security-Tools`
   (CC-BY-4.0) as the co-op's ICS-rules starting point (covers Digital Bond **Quickdraw**,
   RAPSN **SETs** MPL-2.0, Talos, ARMORE). Emerging Threats optional, **not** for the OT mirror.
- **Offline rule mirror**: download rule sets into `$RULES/`, sign the tarball, mount read-only.
   Detection must work with zero internet.

## 4. Log / telemetry (Tier 3)
- **Fluent Bit** (`fluent/fluent-bit`, Apache-2.0, active): primary collector. `@out` local
   `loki` (and/or local file). **No** external `@out`.
- **Loki** (`grafana/loki`, AGPL-3.0): log store, internal single-host, no remote-write.
- **Grafana Alloy** (`grafana/alloy`, Apache-2.0, active): replaces the **EOL** `grafana/promtail`;
   use Alloy, never Promtail.
- **OpenTelemetry Collector** (`open-telemetry/opentelemetry-collector`, Apache-2.0) and
   **Prometheus** (`prometheus/prometheus`, Apache-2.0): optional, all local, no remote-write.
- **Fluentd** (`fluent/fluentd`, Apache-2.0): optional, heavy (Ruby) — prefer Fluent Bit for
   co-op scale.

## 5. Detection rules (Tier 4)
- **Sigma** (`SigmaHQ/sigma` — the org was `SigHQ`, which is why earlier fetches 404'd;
   license = **Detection-Rule-License 1.1**, permissive — attribution in match output required).
   Validator: `SigmaHQ/sigma-rules-validator` (Apache-2.0).
- Pair Sigma rules into Zeek/Suricata or a small local rule-adapter. No external rule feed at
   detection time.

## 6. Alerting — "SOC in a box" (Tier 5)
- **Alertmanager** (`prometheus/alertmanager`, Apache-2.0): route high-confidence alerts to a
   co-op pager/SMS/email. Dedup + rate-limit + escalation. This is the "SOC-in-a-box": a small
   team, a human-readable runbook per alert, no 24x7 analyst required.
- **Grafana** (`grafana/grafana`, AGPL-3.0, internal): dashboards for OT telemetry + alert
   timeline. No remote destinations.
- **Optional Wazuh** (`wazuh/wazuh`, **GPL-3.0** — `NOASSERTION` on GitHub is misleading):
   **if** included, run **standalone**, and **disable** the default cloud index-server + telemetry
   (`remote_index_server`, `telemetry: disabled` in `ossec.conf`). Recheck after every upgrade.

## 7. Hardening baseline (Tier 6)
- **OpenSCAP** (`OpenSCAP/openscap`, LGPL-2.1, active): run a CISA/NIST/OSAP profile against the
   appliance on every reboot / nightly.
- **ComplianceAsCode/content** (`ComplianceAsCode/content` — renamed from
   `scap-security-guide/scap-security-guide`, which is why earlier fetches 404'd): source of
   SCAP benchmark content. `NOASSERTION` on GitHub — verify per-profile license.
- **Policy references** — **NIST SP 800-82 r3 (ICS)** and **CISA Cybersecurity Best Practices
   for ICS** as PDFs. No repo. Operationalize via OpenSCAP/ComplianceAsCode.
  CISA "ICS-NPP" name does **not** exist as a project (see `remaining/`); the authoritative
  artifacts are IR 800-82 / CISA ICS publications and `cisa/*` tools that need verification.

## 8. Resilience (Tier 7)
- **UPS + redundant feed where available.** No power = no detection.
- **Local snapshot/restore** of the appliance, scheduled + on-rule-change.
- `systemd` `Restart=on-failure` on every sensor/collector/alerting service.
- **Offline rule mirror** ($RULES/ read-only) so detection survives internet loss.
- **Pager failover**: if Alertmanager can't reach the pager, retry + local-disk alert queue.

## 9. Validation before production (do this in the lab VLAN 3050)
1. **Confirm the block direction.** Capture traffic on the SPAN mirror: verify the appliance
   **receives** only, and has **no** path to VLAN 3000. No `tcp`/`udp` packets originating from
   the appliance toward the control VLAN.
2. **No external exfil.** `nft` trace a packet from `fluent-bit`/`loki`/`zeek` — it must land
   locally or at a co-op-owned endpoint. No S3/HTTP/cloud destination.
3. **Offline test.** Cut internet + power-kill one sensor for 5 min. Detection continues from
   the local log cache and restarts on power return.
4. **Rule coverage check.** Feed known OT "canary" DNP3/Modbus/IEC test captures; confirm alerts
   for the ICS rules of interest.
5. **Recheck Wazuh/Tailscale default cloud** after each config change.
6. **Pager test.** Fire a synthetic alert; confirm it reaches the co-op owner within SLA.
7. **Document the config as a signed artifact** and store it in the co-op's repo (no secrets —
   pager numbers and SSH keys are stored separately, offline, rotated).

## 10. Operating the co-op (a minimal, defensible posture — not a 24x7 SOC)
- **High-confidence alert only** to pager. Noise is filtered at Alertmanager by severity +
   dedup.
- **Runbook** per alert: one page, "if alert X, do Y." A co-op admin can act in ~15 min.
- **Weekly** review of false positives; tune; re-mirror rules.
- **Monthly** `OpenSCAP` re-scan + rule-mirror refresh + snapshot.
- **Quarterly** lab re-validation + a "did a packet leak path change?" recheck.
- **Yearly** review NERC-CIP / ISO applicability + update the co-op's cyber policy; involve
   co-op counsel.

---

## 11. Pre-deploy checklist (one-pager, paste into the co-op's ticket)
- [ ] Host hardened (Debian + `no auto-update` + pin versions, `systemd` strict).
- [ ] VLAN 3050 monitor, VLAN 3000 control, SPAN RX only on the appliance.
- [ ] VyOS or nftables default-deny, no write path to control VLAN (packet capture verified).
- [ ] Tailscale free tier for mgmt devices only; ICS telemetry **never** on it.
- [ ] Sensors (per co-op estate only): `coop-arm-dnp3-steward` DNP3 / `libmodbus` /
      `lib60870`/`libiec61850`/`open62541`, each `Restart=on-failure`, no external out.
- [ ] Zeek + Suricata (GPL, standalone) → `fluent-bit` (Apache, no external `@out`) → Loki.
- [ ] `grafana/alloy` used (not `promtail` which is EOL); no remote_write anywhere.
- [ ] Sigma rules mirrored offline; `ITI/ICS-Security-Tools` packs signed and read-only.
- [ ] Alertmanager → co-op pager only (dedup + rate-limit + escalation).
- [ ] If Wazuh used: standalone + **cloud/telemetry disabled** (recheck after each upgrade).
- [ ] OpenSCAP + ComplianceAsCode nightly/weekly; NIST 800-82 + CISA ICS PDF as policy.
- [ ] UPS on, local snapshot, offline rule mirror, alert queue.
- [ ] Lab validation done (direction, no exfil, offline, canary, pager, signed artifact).
- [ ] No secrets in any config committed. Pager number + SSH keys stored offline separately.
- [ ] Co-op counsel reviewed NERC-CIP applicability.
