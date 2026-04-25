# ADR-005: Adopt MADR for Architectural Decision Records

## Status

Accepted

## Context and Problem Statement

Architectural decisions made in chat, meetings, or PR threads evaporate. New contributors cannot tell which choices were deliberate, which were expedient, or what forces drove them — so the team re-debates, re-decides, or drifts. The stack needs a durable, reviewable record format for "why the code is the way it is."

## Decision Drivers

- Readable in seconds without specialized tooling.
- Reviewable through the same PR mechanism as code.
- Compatible with `ADR-NNN` references used elsewhere in the stack's specs.
- Lightweight enough that contributors actually write them.

## Considered Options

- MADR (Markdown Any Decision Records) — fixed sections, numbered files, PR-reviewed.
- Nygard-style ADRs — original short-form template, less prescriptive.
- RFC documents — heavier process, longer authoring time.
- No formal record — rely on commit messages and tribal knowledge.

## Decision Outcome

We will adopt MADR as the architectural decision record format, governed by `specs/practices/madr.md`. ADRs live under `docs/adr/`, are numbered `NNN-short-title.md`, follow the fixed section layout (Status / Context and Problem Statement / Considered Options / Decision Outcome / Consequences), and are introduced via PR.

## Consequences

- Positive: the ADR log is a reliable explanation of the stack's architecture.
- Positive: `ADR-NNN` references in specs resolve to documents that exist and conform.
- Negative: requires sustained discipline — a decision without an ADR is invisible to future readers.
- Negative: the index file (`README.md`) must be maintained in lockstep with new ADRs.
