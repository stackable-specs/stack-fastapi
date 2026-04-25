# ADR-010: Adopt Integration Testing Discipline

## Status

Accepted

## Context and Problem Statement

Unit tests (ADR-009) verify a function in isolation. They do not catch schema drift, broken migrations, contract mismatches between services, transaction isolation issues, or broker reconnection edge cases. Without a real-dependency tier, those bugs reach production. With a tier that "integration-tests" by stitching mocks together, they still reach production.

## Decision Drivers

- Real dependencies (real Postgres, real broker) at the integration boundary.
- State isolation between test runs without flakiness.
- Reasonable runtime — integration tests must gate PRs, not be skipped as "too slow."
- Compatible with BDR scenarios (ADR-006) as test inputs.

## Considered Options

- Real dependencies via `testcontainers` (Postgres, NATS, etc.) per `specs/quality/integration-testing.md`.
- All-mocks "integration" — fast but blind to the failure modes that motivate the tier.
- A shared, long-lived staging environment — prone to cross-test pollution and ordering bugs.
- Skip integration tests on PRs, run nightly — defects land before they're caught.

## Decision Outcome

We will adopt the integration-testing discipline pinned by `specs/quality/integration-testing.md`: real Postgres / brokers via containers, per-test state isolation, full execution on every PR, real serialization paths.

## Consequences

- Positive: the suite catches schema drift, migration bugs, and contract mismatches before merge.
- Positive: BDR Given/When/Then scenarios drop in directly as integration tests.
- Negative: CI requires Docker-capable runners and longer wall-clock budgets.
- Negative: writing integration tests is more work than writing unit tests; teams must internalize when each applies.
