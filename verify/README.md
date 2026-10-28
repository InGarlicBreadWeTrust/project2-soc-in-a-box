# verify/ — reproducibility & raw API snapshots for project #2

Everything under `verify/` is **machine-generated** and **contains no secrets, no
credentials, and no telemetry**. It is the audit trail for the component manifest in
the top-level `README.md`, `components-manifest.md`, `security-assessment.md`,
`legal-notes.md`, and `deployment-runbook.md`.

## Contents
- `r1.json` … `r34.json` — one GitHub REST /repos/:owner/:repo snapshot per file, in
    the order the research pass fetched them. HTTP 200 = live metadata (license,
    last-push, active flag, stars); HTTP 404 = a stale path (renamed/EOL/unverified).
    The 404s are kept deliberately as a reproducible record and map 1:1 to the
    `ref-only` rows in `manifest.csv`.
- `manifest.csv` — flattened, human-readable view: 10 fields per row
    `repo, class, license_dcted, github_spdx, pushed_at, stars, archived, role,
     risk_note, ref_snapshot_json`. `ref_snapshot_json` tells you which `rNN.json`
     backs each row (where the row has one).
- `reverify.sh` — reproduces the snapshot with a **one-request-per-repo** strategy
   (custom UA `coop-soc-scout/1.0`, tight timeouts, raw JSON out), reading no
   secrets and writing no tokens to disk.
- `README.md` — this file.

## How to reproduce
```
cd project2-soc-in-a-box
chmod +x verify/reverify.sh
./verify/reverify.sh            # or with GITHUB_TOKEN in env to raise quota
```
`reverify.sh` will recreate `r*.json` (with some re-numbering collisions at slot 7 —
see its own footer). `manifest.csv` and the research notes do **not** need
regeneration — they encode the 2026-10-28 snapshot.

## What this is **not**
- **Not** a license-oracle. GitHub's `license.spdx_id` is a *heuristic* and is known
   to **mis-detect** for some of these repos:
   - `vyos/vyos-1x` — SPDX hint LGPL-2.1; VyOS historically ships GPL-3.0; **verify LICENSE**.
   - `open62541/open62541` — SPDX hint MPL-2.0 at repo level; project docs say core C
     is BSD-3-Clause; **verify LICENSE**.
   - `wazuh/wazuh` — SPDX hint `NOASSERTION`; project license is **GPL-3.0** — **verify**.
   - `zeek/zeek` — SPDX hint `NOASSERTION`; historically BSD-3 — **verify current tag**.
   - `ComplianceAsCode/content` — SPDX hint `NOASSERTION`, mixed content — **verify per-profile**.
- **Not** a deployment. No service in this scaffold is running; it is a paper design
   for a co-op to validate in an isolated OT lab (VLAN 3050) before production, per
    `deployment-runbook.md §9`.

## License classes used here
See `manifest.csv` `class` column + `legal-notes.md §2` for the full permissive/
copyleft/AGPL/dead map.

## 404 / rename / EOL resolutions (recorded for reproducibility)
| Stale path | Resolution |
|---|---|
| `SigHQ/sigma` | → `SigmaHQ/sigma` (org renamed; DRL-1.1, permissive) |
| `grafana/promtail` | → EOL ~2026-03; **replaced by `grafana/alloy`** (Apache-2.0) |
| `scap-security-guide` | → `ComplianceAsCode/content` (verified) |
| `datadog/vector` | Drop; replaced by `fluent/fluent-bit` + `grafana/alloy` + `open-telemetry/opentelemetry-collector` in this design |
| `libnd/libnd` / `dnp3-pcap / nidds ` | Unverified 404; resolve before deploy |
| `cisa/CSET` / `cisa/malcolm` / `golang-headscale/headscale` | Unverified 404 this pass; resolve before deploy |
