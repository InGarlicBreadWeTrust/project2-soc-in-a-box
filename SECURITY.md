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

## Contact

- Open a new **draft issue** in this repo and label it `security` — GitHub
  notifies the owner (`@InGarlicBreadWeTrust`) immediately.
- Or contact the owner directly via the GitHub Contact-owner interface at
  `https://github.com/InGarlicBreadWeTrust` (also in the "About" sidebar).
- **PGP public key**: `PGP-KEY.asc` in this repo (RSA 4096, expires 2029-10-28).
  - Identity: `InGarlicBreadWeTrust <80548374+InGarlicBreadWeTrust@users.noreply.github.com>`
  - Fingerprint: `BC48:60A3:23AC:CA43:FE78:72FE:A0FD:52A2:0971`
  - Key ID (short): `0x52A20971`
  - For encrypted contact: import the public key with
    `gpg --import PGP-KEY.asc`, then encrypt your report with it.
