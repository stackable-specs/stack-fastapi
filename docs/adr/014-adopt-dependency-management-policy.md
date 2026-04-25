# ADR-014: Adopt Dependency Management Policy

## Status

Accepted

## Context and Problem Statement

Every third-party dependency is code the team ships but did not write, run with the same privileges as first-party code. Without policy, "it built green" hides the failure modes that matter: floating ranges pull in malicious patches, missing lockfiles cause CI/prod drift, unpinned base images rebase onto vulnerable layers, `git`/URL deps point at force-pushable branches, typosquats land unreviewed, and abandoned transitive dependencies become permanent risk.

## Decision Drivers

- Reproducible dependency graph from dev to CI to production.
- Defense against dependency confusion and typosquatting.
- A review gate for adding direct dependencies.
- Recurring, automated updates with security-update SLAs.

## Considered Options

- Adopt the policy in `specs/security/dependency-management.md` — committed manifest + lockfile, exact pinning, registry allowlist, CODEOWNERS on dep changes, Renovate/Dependabot, license allowlist, abandoned-dep retirement.
- Looser: lockfile only, no review or update automation.
- Looser still: floating versions, install-from-public-registry at build time.

## Decision Outcome

We will adopt the dependency-management policy in `specs/security/dependency-management.md`, leaning on uv (ADR-002) as the source of truth for direct deps and the lockfile, on Renovate or Dependabot for automated updates, and on CODEOWNERS to gate dependency changes. Vulnerability scanning of the resulting graph is governed separately (forthcoming `vulnerability-scanning` spec).

## Consequences

- Positive: the dependency graph the team ships is intentional, reproducible, reviewable, and auditable.
- Positive: dependency confusion and unpinned base-image drift are closed by the registry allowlist and digest pinning.
- Negative: dependency updates become a steady stream of PRs that must pass full CI; ignoring them undoes the policy.
- Negative: CODEOWNERS and license allowlist add friction to adding a new direct dependency — by design.
