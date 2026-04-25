# ADR-017: Adopt pdoc for API Reference Documentation

## Status

Accepted

## Context and Problem Statement

A Python package's public API needs reference documentation that consumers can read without spelunking the source. Without a chosen generator, docstring format, and CI gate, "the docs" become whatever a contributor last hand-edited in a wiki — drifting past the released version, mixing docstring styles, and treating every top-level name as public surface so internal refactors silently become breaking changes.

## Decision Drivers

- Generated directly from typed Python source and docstrings (single source of truth with the code).
- Lightweight — no heavy site-builder when a reference is what we actually need.
- Enforces a single docstring format and a declared public surface (`__all__`).
- Runs as a CI gate so the docs build is a real signal, not advisory output.
- Compatible with the python-uv toolchain (ADR-002) and Trunk lint runner (ADR-012).

## Considered Options

- pdoc per `specs/presentation/pdoc.md` — minimal, type-hint aware, single-binary CLI.
- Sphinx + autodoc — powerful and flexible, but heavier configuration surface and more authoring overhead.
- MkDocs + mkdocstrings — strong narrative-docs story; overkill when the goal is API reference.
- pydoctor — older, less actively maintained.
- No generator — hand-written docs that drift immediately.

## Decision Outcome

We will adopt pdoc as the API reference generator for python-uv packages, governed by `specs/presentation/pdoc.md`. Packages declare public surface via `__all__` and underscore-prefix internals, use a single project-wide docstring format (Google or NumPy), gate the pdoc build in CI, lint docstrings via Ruff `D` rules (Trunk, ADR-012), and tie the published docs URL to the released package version.

## Consequences

- Positive: API reference is generated from the same source that ships, so it cannot drift past the released code.
- Positive: `__all__` plus underscore-prefixing turns "public API" from accident into declaration — refactors of internals stop being accidental breaking changes.
- Positive: a docstring lint failure or a pdoc build failure is a CI signal, not a quiet warning.
- Negative: pdoc handles API reference well but is not a narrative-docs tool — long-form guides, tutorials, and architecture writeups still need a sibling format (e.g. plain markdown in `docs/`).
- Negative: contributors must learn the chosen docstring format and keep `__all__` accurate; the spec exists to keep that discipline visible.
