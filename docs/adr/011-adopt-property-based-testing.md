# ADR-011: Adopt Property-Based Testing for Invariants

## Status

Accepted

## Context and Problem Statement

Example-based tests verify the `(input, output)` pairs the developer thought of; everything else stays untested. For functions with non-trivial input domains — parsers, serializers, math, state machines — the inputs that break in production are usually the ones nobody wrote a test for. The stack needs a way to assert invariants over an input space, not just over a handful of fixtures.

## Decision Drivers

- Counterexample search and shrinking, not "loop 100 times and hope."
- Failures must produce minimal, reproducible inputs.
- Discovered counterexamples must become regression tests.
- Compatible with the unit-testing framework (ADR-009).

## Considered Options

- Hypothesis (Python) per `specs/quality/property-based-testing.md`.
- Custom `for _ in range(N)` loops with random inputs — no shrinking, no reproducibility.
- Fuzzing tools (e.g. `atheris`) — overlap, but tuned for security/crash discovery rather than property assertions.
- Skip the discipline — example tests only.

## Decision Outcome

We will adopt Hypothesis for property-based testing on functions with non-trivial input domains, governed by `specs/quality/property-based-testing.md`. Properties are framed as invariants over a domain; counterexamples are pinned as regression tests; shrinking is allowed to do its work.

## Consequences

- Positive: edge cases example tests skip get exercised — boundary conditions, fuzz-like inputs, round-trip identities.
- Positive: a PBT failure produces a small, reproducible counterexample.
- Negative: writing genuine properties (predicates over a domain) is harder than writing example tests; misuse degrades the technique to a noisy random loop.
- Negative: PBT runs are non-deterministic by default; CI must seed and budget runs explicitly.
