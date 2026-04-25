# ADR-009: Adopt Unit Testing Discipline

## Status

Accepted

## Context and Problem Statement

Unit tests are the cheapest, fastest place to catch regressions and the only tier developers run on every save. When the suite is slow, flaky, order-dependent, or asserts on internal call counts, contributors stop running it and the safety net evaporates. Without explicit constraints, "unit tests" degrade into integration tests in disguise, implementation-detail mocks, retry-masked flakes, or coverage-chasing assertion-free invocations.

## Decision Drivers

- Sub-second feedback for the inner TDD loop (ADR-008).
- Deterministic execution — no flaky retries, no shared state.
- Assertions on observable behavior, not implementation details.
- Standard, ecosystem-native framework.

## Considered Options

- pytest with a strict spec on layout, AAA shape, and isolation per `specs/quality/unit-testing.md`.
- Python `unittest` standard library — verbose, less ergonomic fixtures.
- nose / nose2 — abandoned / minimally maintained.
- No prescribed framework — let each service choose.

## Decision Outcome

We will adopt pytest as the unit-test framework with the discipline pinned by `specs/quality/unit-testing.md` — per-test in-memory substitutes, AAA shape, observable-behavior assertions, deterministic execution, CI gating.

## Consequences

- Positive: a passing unit suite is a real signal, not just an attestation that tests didn't crash.
- Positive: pytest fixtures and parametrization fit the AAA shape cleanly.
- Negative: must resist the drift toward "unit tests" that touch real I/O — those belong in integration (ADR-010).
- Negative: implementation-detail mocking is forbidden; refactoring habits must adapt.
