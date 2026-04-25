# ADR-001: Adopt Python as the Stack Language

## Status

Accepted

## Context and Problem Statement

The stack needs a primary implementation language for application code, scripts, and tooling. The choice constrains library availability, hiring, runtime performance, packaging, and the toolchain the rest of the stack must integrate with. Without an explicit decision, contributors reach for whichever language they happen to know, the codebase fragments across runtimes, and tooling investments are duplicated.

## Decision Drivers

- Breadth of library ecosystem for data, ML, web, and integration work.
- Maturity of static-analysis tooling (typing, linting, formatting).
- Hiring surface and onboarding cost.
- Compatibility with the team's existing operational footprint.

## Considered Options

- Python (3.12+).
- TypeScript on Node or Bun.
- Go.
- Rust.

## Decision Outcome

We will adopt Python as the primary language for the stack and constrain it to the modern subset (PEP 8, type hints, `pyproject.toml` packaging, modern idioms) defined in `specs/language/python.md`. Python wins on ecosystem breadth and team velocity; the modern subset and a strict toolchain (mypy, ruff) close the gaps Python's flexibility otherwise leaves open.

## Consequences

- Positive: rich ecosystem, fast onboarding, single linguistic surface across services and scripts.
- Positive: type checking and lint tooling can serve as a real CI gate when the modern subset is enforced.
- Negative: weaker baseline runtime performance than Go or Rust; CPU-bound paths may need native extensions or a sidecar.
- Negative: dynamic typing requires sustained discipline (type hints, mypy in CI) to stay reliable.
