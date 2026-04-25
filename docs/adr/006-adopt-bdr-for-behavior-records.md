# ADR-006: Adopt BDR for Behavior Decision Records

## Status

Accepted

## Context and Problem Statement

ADRs (ADR-005) capture *how* the system is built — frameworks, schemas, configuration. They do not tell a reader, a tester, or an autonomous agent *what the system must do for users*. Without a separate record of externally observable contracts, intent is reconstructed by reading code and tests, conflating implementation with promise, letting behavioral scope creep silently, and making regressions invisible until users notice.

## Decision Drivers

- Separation of architectural concerns from behavioral promises.
- Acceptance criteria that a black-box observer can confirm.
- Given / When / Then scenarios usable directly by integration tests.
- Same PR-based review mechanism as ADRs.

## Considered Options

- BDR (Behavior Decision Records) per `specs/practices/bdr.md`.
- Capture behavior in test code only.
- Free-form Gherkin `.feature` files with no ADR-style record.
- No separate behavior record — fold everything into ADRs.

## Decision Outcome

We will adopt BDRs alongside ADRs, governed by `specs/practices/bdr.md`. Each BDR captures a single capability the system agrees to uphold, with acceptance criteria a black-box observer could confirm and Given / When / Then scenarios that drop into integration tests.

## Consequences

- Positive: behavioral contracts are first-class artifacts, reviewable independent of implementation.
- Positive: BDRs feed integration test scenarios directly (see ADR-010).
- Negative: contributors must learn the ADR / BDR split — *how vs. what for users*.
- Negative: two indices to maintain (`docs/adr/` and the BDR directory).
