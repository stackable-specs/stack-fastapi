# ADR-012: Adopt Trunk Code Quality as the Lint Runner

## Status

Accepted

## Context and Problem Statement

A repo accumulates a different config format, installed version, and invocation style for every linter, formatter, and scanner. "Lint the repo" then resolves differently on each developer's machine, in each CI job, and between contributors — turning lint passes into noise. The stack needs a single, version-pinned, multi-language runner that gives `lint passing` a coherent meaning.

## Decision Drivers

- One CLI for every linter, formatter, and scanner the repo uses.
- Pinned tool versions resolved identically locally and in CI.
- Multi-language coverage (Python today, anything else the stack picks up later).
- A single CI gate (`trunk check`) that can be required for merge.

## Considered Options

- Trunk Code Quality (`trunk.yaml`, `trunk check`) per `specs/quality/trunk-code-quality.md`.
- pre-commit (`.pre-commit-config.yaml`) — strong for hooks, weaker for multi-language and version unification.
- MegaLinter — broad coverage, heavier container-based runs.
- Per-tool configs invoked individually (`ruff check`, `mypy`, …) — fragments versions and configs.

## Decision Outcome

We will adopt Trunk Code Quality as the unified lint/format runner, governed by `specs/quality/trunk-code-quality.md`. `trunk.yaml` pins tool versions; `trunk check` is the gate; bypasses (`--no-verify`, ad-hoc suppressions) are treated as defects.

## Consequences

- Positive: every contributor and CI runner resolves the same tool versions.
- Positive: adding a new language or tool is a `trunk.yaml` edit, not a CI rewrite.
- Negative: introduces a vendor dependency on Trunk's distribution and CLI.
- Negative: contributors used to invoking tools directly must adopt `trunk` as the entry point.
