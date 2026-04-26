# ADR-022: Adopt the Renovate Configuration Spec

## Status

Accepted

## Context and Problem Statement

ADR-014 committed the stack to a dependency-management policy and named Renovate as the automation that operationalizes it. The repo already ships a `renovate.json` and a `prek-autoupdate.yml` workflow. What it lacks is a *spec* that pins the Renovate configuration shape itself: schedule and PR-concurrency caps, dependency-dashboard discipline, security-vs-routine PR separation, severity-to-`prPriority` mapping, automerge guardrails, runner pinning when self-hosted, and a documented operating model. Without those rules, the same engine that's supposed to enforce ADR-014 quietly turns into the loudest source of churn — a stale `extends: ["config:base"]` shifts behaviour upstream, an unbounded `prHourlyLimit` floods reviewers, security PRs get batched alongside routine ones and fail to meet the SLAs in `vulnerability-scanning.md`.

## Decision Drivers

- Tighten the existing `renovate.json` against the rules in `specs/security/renovate.md`.
- Surface a single source of truth for *how* Renovate should run on this repo, distinct from the *what* (which dependencies) covered by ADR-014.
- Wire a CI gate that validates the Renovate config against the published schema on every PR that touches it (rule 3).
- Map the `dependency-management` and `vulnerability-scanning` severity SLAs onto Renovate's `prPriority` and labels (rule 10).
- Document the operating model — cloud vs self-hosted, owner, on-call — so the automation does not become orphaned (rule 18).

## Considered Options

- **Adopt `specs/security/renovate.md` and harden `renovate.json` to match (this ADR).** Keeps the existing automation; closes the gaps the council review surfaced.
- Replace Renovate with Dependabot. Loses lockfile-maintenance, multi-manager coverage, and the package-rules expressiveness; would require rewriting the materialized config.
- Self-host Renovate in CI on a cron. More control over the runner, more operational surface; deferred until a concrete reason emerges.
- Leave the current `renovate.json` as-is. Council reviewers flagged missing concurrency caps, missing CI validation, missing severity mapping, missing operating-model doc.

## Decision Outcome

We will adopt `specs/security/renovate.md` for this stack, governed by ADR-014. The materialization plan:

1. **Tighten `renovate.json`** to honor every applicable rule: explicit `schedule` (workdays only), explicit `prConcurrentLimit` and `prHourlyLimit`, `dependencyDashboard: true`, `lockFileMaintenance` on a documented schedule (already present), `vulnerabilityAlerts` kept unbatched and always-on with elevated `prPriority`, conservative `automerge` only on lockfile-maintenance and dev-only patches, restated `rangeStrategy: "pin"` (this stack ships an application).
2. **Add CI validation** — a `renovate-config-validator` step in `.github/workflows/ci.yml` that runs whenever `renovate.json` (or any preset file) changes (rule 3).
3. **Document the operating model** in `docs/dependencies/renovate.md`: cloud vs self-hosted, who owns the config, the on-call path for failed runs, and the registry allowlist (rules 16, 18).
4. **Add a verifier** under `verify/adr-022-renovate.sh` that checks the committed shape against rules 1, 2, 5–12, 15.

## Consequences

- Positive: routine update noise is bounded by `prHourlyLimit` and a workday schedule; security PRs land outside that gate with elevated priority.
- Positive: misconfigurations land as failing CI runs (rule 3), not as silent drift.
- Positive: operating-model doc clarifies who is paged when Renovate fails.
- Negative: the config gains complexity. Preset version-pinning (rule 4) is currently sourced from `config:recommended` etc. — these are upstream GitHub-internal presets considered stable. Recorded as a carve-out: do not pin the renovate-managed presets unless we move to a self-hosted preset repo.
- Negative: severity-to-`prPriority` mapping (rule 10) requires the repo's CVSS / EPSS / KEV lookup to be wired into the package rules. Initial implementation uses static severity labels; a follow-up will plug in a Renovate manager extension or a preset that reads `osv.dev`.

## References

- [ADR-014](014-adopt-dependency-management-policy.md) — broader dependency-management policy this ADR refines
- `docs/specs/security/renovate.md` — rules this ADR adopts
- `docs/specs/security/dependency-management.md` — parent spec
- `docs/specs/security/vulnerability-scanning.md` — provides the SLA mapping for `prPriority`
