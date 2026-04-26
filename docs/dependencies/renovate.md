# Renovate operating model (ADR-022)

This document covers _how_ Renovate runs against this repository — the deployment shape, ownership, and on-call path. Per `docs/specs/security/renovate.md` rule 18, Renovate must not run as orphaned automation.

## Deployment

| Question               | Answer                                                                                                                                                                                                                                              |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cloud or self-hosted?  | **Mend Cloud** (the default GitHub App at `https://github.com/apps/renovate`).                                                                                                                                                                      |
| Runner version pinning | Mend Cloud is auto-updated by Mend; runner-pin requirement (rule 15) is satisfied by Mend's published release cadence. If we move to self-hosted, pin the Docker image by digest in CI.                                                             |
| Configuration file     | `renovate.json` at the repo root (rule 1).                                                                                                                                                                                                          |
| Schema validation      | `renovate-config-validator` runs in CI on every PR that touches `renovate.json` (rule 3).                                                                                                                                                           |
| Dashboard              | Single tracking issue on GitHub titled "Renovate dependency dashboard" (rule 7).                                                                                                                                                                    |
| Allowlisted registries | The Python ecosystem registry (`pypi.org`) and the container registries already enumerated by `docs/specs/security/dependency-management.md` (rule 16). Renovate inherits these via `pep621` and `docker` managers — no additional config required. |

## Schedule and PR caps

| Knob                  | Value                                    | Source                 |
| --------------------- | ---------------------------------------- | ---------------------- |
| `timezone`            | `UTC`                                    | rule 5                 |
| Routine `schedule`    | `after 8am and before 6pm every weekday` | rule 5 — workdays only |
| Python deps batch     | `after 8am and before 6pm on monday`     | rule 8                 |
| `prConcurrentLimit`   | `10`                                     | rule 6                 |
| `prHourlyLimit`       | `2`                                      | rule 6                 |
| `lockFileMaintenance` | enabled, `before 5am on monday`          | rule 12                |

## Security PRs

| Knob                             | Value                    | Source                        |
| -------------------------------- | ------------------------ | ----------------------------- |
| `vulnerabilityAlerts.enabled`    | `true`                   | rule 9                        |
| `vulnerabilityAlerts.schedule`   | `at any time`            | rule 9 — unbatched, always-on |
| `vulnerabilityAlerts.prCreation` | `immediate`              | rule 10 — priority signal     |
| `vulnerabilityAlerts.automerge`  | `false`                  | rule 14                       |
| `osvVulnerabilityAlerts`         | `true`                   | rule 9 — OSV feed             |
| Labels                           | `security, dependencies` | rule 10 — priority signal     |

`prPriority` is intentionally **not** set inside `vulnerabilityAlerts` — Renovate's strict validator rejects it there (the field is only valid inside `packageRules`). Priority is conveyed instead by (a) `prCreation: immediate` so security PRs jump the queue, (b) the always-on `at any time` schedule that bypasses the routine workday window, and (c) the dedicated `security` label that routes notifications to the security-on-call channel.

The CISA-KEV / EPSS escalation requested by `vulnerability-scanning.md` rule 11 is **not yet wired** at the Renovate layer — Renovate's `osvVulnerabilityAlerts` surfaces OSV-published CVEs but does not consume the KEV/EPSS feeds. The `vulnerability-scanning` SLA (7 days for KEV / critical) is currently enforced manually by the on-call when triaging the dashboard. Tracked as a follow-up in the verify report.

## Automerge policy (rules 13, 14)

Renovate is configured to auto-merge **only**:

- patch / pin / digest updates of `devDependencies`
- `lockFileMaintenance` runs

It is configured to **never** auto-merge:

- security updates (`vulnerabilityAlerts.automerge: false`)
- major-version bumps
- runtime dependency changes (anything not in `devDependencies`)

`platformAutomerge: true` lets GitHub merge once required checks pass; merge happens server-side without a Renovate retry loop.

## Ownership and on-call

| Concern                        | Owner                                                                                                              |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------ |
| `renovate.json` config changes | the team listed in `.github/CODEOWNERS` for `*.json` (today: stack maintainers)                                    |
| Adding / removing presets      | requires a CODEOWNERS review                                                                                       |
| Failed Renovate runs           | surfaced in the dependency dashboard issue; the issue owner is paged via the team's standard issue-triage rotation |
| Dependency-dashboard triage    | weekly during the team's dependency review                                                                         |

When Renovate fails (a PR fails CI, the dashboard reports a config error, or a security PR misses its SLA): open or reuse the dashboard issue, post a brief diagnosis in-thread, and assign to the CODEOWNERS reviewer. Do not close the issue without resolving.

## Tokens and credentials (rule 17)

Mend Cloud manages its own GitHub App credentials — none live in the repo. If we move to self-hosted, the `RENOVATE_TOKEN` (GitHub App private key) and any registry credentials would be sourced from the team's secret manager and injected into the runner's environment, never committed.
