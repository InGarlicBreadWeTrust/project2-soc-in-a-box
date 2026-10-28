#!/usr/bin/env bash
# scripts/lab-validate.sh — offline lab validation for the co-op SOC-in-a-box.
#
# Run this in the ISOLATED lab VLAN (3050 monitor; 3000 control SPAN mirror) BEFORE ever
# touching production. No step touches a live control network. These checks operationalize
# deployment-runbook.md §9. Pure local checks; reads NO secrets; transmits NOTHING.
#
# Usage: scripts/lab-validate.sh
# Env:   MIRROR_IFACE  (default eth1, the passive SPAN/tap RX-only mirror)
#        MGMT_IFACE    (default eth0, the VLAN 3050 mgmt link)
#        COOP_ROOT     repo top dir

set -uo pipefail
MIRROR_IFACE="${MIRROR_IFACE:-eth1}"
MGMT_IFACE="${MGMT_IFACE:-eth0}"
COOP_ROOT="${COOP_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

echo "[1] Confirm the block direction (appliance RECEIVES only on the mirror; no write path to control)"
echo "     - Run:  ip -d link show $MIRROR_IFACE      # expect a SPAN/monitor mode, RX only"
echo "     - On the physical switch, confirm the port is a SPAN/monitor destination, not a member of"
echo "       the control VLAN with L2 forwarding enabled. Capture traffic on $MIRROR_IFACE and verify"
echo "       NO tcp/udp packet originates FROM the appliance TOWARD the control VLAN."
echo "     - nftables on $MGMT_IFACE: 'nft trace' a sensor egress packet — it must land locally or at a"
echo "       co-op-owned endpoint, never toward the control VLAN. (see scripts/sec-verify.sh check B)"

echo
echo "[2] No external exfil"
echo "     - grep the running config for any @out http / remote_write / s3 / cloud destination and"
echo "       confirm each is loopback or co-op-owned. Run:  scripts/sec-verify.sh   (check A must PASS)"

echo
echo "[3] Offline test (detection survives internet + single-sensor loss)"
echo "     - Disable the appliance's uplink, power-cycle one sensor, wait 5 min, restore. Confirm"
echo "       detection continues from the local log cache (Fluent Bit / Loki local) and the service"
echo "       auto-restarts (systemd Restart=on-failure). No rule fetch is required at detection time."
echo "     - Re-mirror the offline rule tarball ($RULES/ read-only) so detection works with zero internet."

echo
echo "[4] Rule coverage check (canary)"
echo "     - Feed known benign + malicious DNP3 / Modbus / IEC 61850 / IEC 60870 captures (the co-op's"
echo "       own canary set or the ICS-Security-Tools fixtures) into the Zeek/Suricata pipeline and"
echo "       confirm alerts fire for the ICS rules of interest, and that benign traffic does not alert."

echo
echo "[5] Re-disable any re-introduced cloud paths"
echo "     - After each config change/upgrade, re-confirm Wazuh index/telemetry disabled and Tailscale"
echo "       is mgmt-only (no ICS telemetry). Run scripts/sec-verify.sh check F."

echo
echo "[6] Pager test"
echo "     - Fire a synthetic alert from Alertmanager and confirm the co-op owner's pager/SMS/email"
echo "       receives it within the co-op's SLA, and that the alert carries a one-page runbook link"
echo "       ('if alert X, do Y'). Confirm an offline alert queue holds alerts if the pager is down."

echo
echo "[7] Sign the config artifact"
echo "     - Once checks 1-6 pass: sign & timestamp the config tree, store it in the co-op's repo"
echo "       (NO secrets — pager numbers + SSH keys live offline, rotated), and log the run."
echo "     - Reconfirm NERC-CIP / state-utility applicability with co-op counsel (legal-notes.md §1)."

echo
echo "Lab validation complete. Do NOT promote to production until every step above is PASS."
exit 0
