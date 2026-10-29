# Security Disclosure

This research scaffold (a co-op ICS/OT "SOC-in-a-box" bill of materials, threat
model, and deployment runbook) is **defensive only** — it mirrors and detects, it
never drives control traffic. Reports should treat it as a public reference
document, not as live security tooling.

## Responsible disclosure

1. **Do not disclose publicly** before a coordinated response is available.
2. Email a summary to the maintainers (see `CONTRIBUTING.md`) or open an issue
   labelled `security`.
3. We aim to acknowledge within 5 business days.

## In scope

- Errors in the component manifest (wrong license, dead link, mis-classified
  copyleft exposure, a component with a default telemetry/call-home path that was
  not flagged).
- Errors in the threat model or privacy assessment.
- A `verify/reverify.sh` or `verify/` snapshot that phones home or reads secrets.

## Out of scope

- The third-party components themselves (zeek, suricata, opendnp3, etc.) —
  report defects upstream.
- Any content used for offensive testing.

## By construction

`verify/` holds only GitHub REST metadata (SPDX / pushed_at / archived / stars).
No secrets, credentials, or telemetry are present — this is also a guarantee a
co-op can audit. Flag any path that violates that.

<!-- TODO(maintainer): fill in a real disclosure channel here. -->
