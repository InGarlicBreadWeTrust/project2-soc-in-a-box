# Contributing to Co-op SOC-in-a-Box

We want co-op operators and OT / ICS defenders to make this project stronger.
Please read this short guide before your first pull request. The goal is the same
one stated in the NOTICE: **to help a rural electric co-op build a safe, permissive,
secure-by-design, no-telemetry ICS/OT monitoring scaffold — not to create a liability
or a supply-chain problem.**

## 1. Fork & Branch
- Fork this repo and make branches from `main`.
- Branch names: `feat/…`, `fix/…`, `docs/…`, `chore/…`, `rules/…` (for new Sigma/detection rules).
- Open a PR against `main`. Keep PRs small and reviewable. Squash-merge on close.

## 2. Sign every commit — Developer Certificate of Origin
- Every human-authored commit must be `-s`-signed and end with a `Signed-off-by:` line:
```
git commit -a -s -m "fix: correct the nft egress policy comment"
```
The `Signed-off-by:` line is required. It certifies that you wrote the change,
followed the project's DCO / CLA, and have the right to contribute it.

- By checking the `Signed-off-by` box (or `-s`), you agree to the Developer
Certificate of Origin (see `cla/DCO.md`), equivalent to the Linux Kernel CLA.
- Corporate contributions: a maintainer may add a `Corporate-Signed-off-by:` line
on your behalf, or your org may sign a corporate CLA (`cla/DCO-CORP.md`, template).

## 3. License & patent safety (MUST)
- **No GPL/AGPL code linked into co-op glue.** Suricata (Apache-2.0), lib60870 /
  libiec61850 (GPL-2.0/3.0), Wazuh, and similar must run as **independent binaries
  in their own segmented VLANs**. Do not link GPL code into co-op-owned code.
- **No call-home / no telemetry / no cloud endpoint** in any config you add. Our
  `scripts/sec-verify.sh` FAILs any config that introduces an external destination
  (`@out http`, `remote_write`, `s3`, `datadog`, `kafka`, `telemetry: enabled`,
  any non-loopback host). Run it and confirm `RESULT: PASS` before you open a PR:
```
scripts/sec-verify.sh
```
- **No secrets in the repo.** Pager numbers, SSH keys, and gateway creds stay
  offline and rotated. Add a literal secret and `scripts/sec-verify.sh` check C fails.
- **Passive-only.** No change may add an egress/write path into an ICS control VLAN
  (`check B`). Sensors receive only.
- **Sigma / detection rules carry a license/attribution field** (DRL) on every rule.
  `check G` requires it; reuse of ICS-Security-Tools / ISC / marlinspike fixtures
  must keep their attribution.

## 4. Test your contribution
- Run `scripts/sec-verify.sh` in this repo and confirm it prints `RESULT: PASS`
  (0 failing invariants). This is the gate; a PR that makes it FAIL cannot merge.
- New detection rules: add to `sigma/ics/` with a DRL `license:` and `attribution`;
  run `sigma` LSP validation (`yamllint` + the sigma schema) — both rules must parse
  and pass the `yaml-schema: Sigma Detection Rule` check.
- New config: keep destinations loopback / co-op-owned. Add a `verify/` snapshot
  if you add a new component URL.

## 5. What NOT to contribute
- No offensive or "recreate a breach" tooling. We harden, detect, alert, and recover —
  never attack. (We are a defence project.)
- No change that weakens `sec-verify.sh` to let a violation pass.
- No GPL linkage into co-op code. No telemetry. No secrets. No active probing.

## 6. Questions?
Open an issue. We answer in the time we have. If a co-op has a specific need
("our DNP3 master is model X"), file an issue and we add a config sample under
`config/` — that's the whole point: make the co-op's job concrete.
