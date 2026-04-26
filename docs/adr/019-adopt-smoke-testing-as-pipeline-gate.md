# ADR-019: Adopt Smoke Testing as a Pipeline Gate

## Status

Accepted

## Context and Problem Statement

The python-uv stack already gates merges on unit (ADR-009), integration (ADR-010), and property tests (ADR-011), and builds an image with SBOM and vulnerability scan (ADR-013, ADR-015). Those tiers prove that the *code* and the *artifact* meet quality bars in isolation. None of them prove that the built image, when actually started with its real configuration, comes up far enough to serve a request — schema mismatch with the running database, broken entrypoint script, missing env var, the `/health` endpoint regressed to 500, the wrong wheel got copied into the image. Without a smoke gate, those failures land on the first user (or the first `make up`) instead of the build.

## Decision Drivers

- One narrow, fast suite that proves the deployed image actually runs.
- Distinct from unit / integration / property tiers — none of those start the image and call into it (`specs/practices/smoke-testing.md` rules 1, 6).
- Fast enough not to slow the pipeline (target ≤ 2 min, hard ceiling ≤ 5 min — rule 3).
- Stop-the-line semantics — a smoke failure blocks the next pipeline stage (rule 8).
- Real wired system (the built container against a real Postgres), not mocks (rule 6).

## Considered Options

- **Smoke suite via `pytest -m smoke` against the built image started under Compose (this ADR)**, governed by `specs/practices/smoke-testing.md`. One test per critical path, gates the deploy stage.
- Skip smoke testing — rely on integration tests at the code level. Misses image-construction defects entirely.
- Reuse integration tests as smoke tests. Violates rules 1 and 3 (smoke must be narrow, fast, and a separate suite).
- Use a third-party synthetic-monitoring service for post-deploy only. Doesn't gate the build pipeline; only catches failures after they ship.

## Decision Outcome

We will adopt smoke testing as a pipeline gate, governed by `specs/practices/smoke-testing.md`. A separate `tests/smoke/` target tagged `@pytest.mark.smoke` runs against the built image started under Compose, exercises the business-critical paths (health endpoint returns ok, primary API endpoint returns 2xx), and is wired as a CI job that depends on `build-image` and blocks any subsequent deploy stage. The same target reruns post-deploy via a manually triggerable workflow that points at any environment URL via `SMOKE_BASE_URL`. The suite is held to a ≤ 5 minute hard cap; flaky tests are quarantined the same business day.

## Consequences

- Positive: image-construction and start-up defects are caught in the same PR that introduces them, not by a user.
- Positive: the post-deploy smoke run gives a documented signal that a deploy is healthy, distinct from "the build was green."
- Positive: the suite is deliberately small — adding a smoke test requires justifying the wall-clock cost, which keeps it from drifting into a regression suite.
- Negative: requires a Compose-capable CI runner (already a dependency of `integration` and `build-image` jobs).
- Negative: real environment URLs and credentials for the post-deploy run must come from the secret manager (per the `dependency-management` and `docker-compose` secrets rules); a mis-scoped token would let CI hit the wrong environment.

## References

- [ADR-009](009-adopt-unit-testing-discipline.md) — distinct deeper tier
- [ADR-010](010-adopt-integration-testing-discipline.md) — distinct deeper tier
- [ADR-013](013-adopt-sbom-for-released-artifacts.md) — runs after build, before smoke
- [ADR-015](015-adopt-docker-as-image-format.md) — image the smoke suite exercises
- [ADR-016](016-adopt-docker-compose-for-local-and-single-host.md) — orchestration the local smoke run uses
- `docs/specs/practices/smoke-testing.md` — rules this ADR adopts
