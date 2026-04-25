# ADR-008: Adopt the Red-Green-Refactor TDD Cycle

## Status

Accepted

## Context and Problem Statement

Tests written after the implementation tend to mirror what the code already does, lock in implementation details, and leave gaps the author did not anticipate. The team needs a workflow that produces tests with regression-safety, design-pressure, and executable-specification value rather than tests that document a finished implementation.

## Decision Drivers

- Verifiable from commits and behavior, not just claims.
- Compatible with the unit/integration/property testing tiers (ADR-009/010/011).
- Small enough cycle to fit normal developer cadence.

## Considered Options

- Red-Green-Refactor TDD per `specs/practices/tdd.md`.
- Test-after — implementation first, tests as a backfill.
- BDD-only — Given/When/Then scenarios at the feature level, no inner cycle.
- No prescribed workflow.

## Decision Outcome

We will adopt the red-green-refactor TDD cycle, governed by `specs/practices/tdd.md`. Write a failing test, make it pass with minimum code, refactor under green. Reviewers can check the cycle was followed via commits and the tests' shape.

## Consequences

- Positive: tests act as design pressure — testable code stays modular.
- Positive: refactors run under a green suite, lowering regression risk.
- Negative: requires discipline; "TDD" claimed but not practiced reverts to test-after.
- Negative: initial velocity feels slower for contributors new to the cycle.
