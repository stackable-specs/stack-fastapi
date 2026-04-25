# ADR-002: Adopt uv as the Python Toolchain Manager

## Status

Accepted

## Context and Problem Statement

A Python project needs an interpreter manager, a virtual-environment manager, a dependency resolver, a lockfile, a tool runner, and a build/publish path. The legacy answer is a stack of separate tools (`pyenv` + `virtualenv` + `pip` + `pip-tools` + `pipx` + `Poetry` + `twine`), each with its own config, cache, and failure modes. Mixing them causes drift between developers, between CI and production, and between manifest and lockfile.

## Decision Drivers

- Reproducibility across machines and CI.
- Speed of dependency resolution and environment creation.
- Single source of truth for lockfile and environment.
- Operational simplicity (one binary to install, one cache to manage).

## Considered Options

- uv (Astral) — single Rust binary covering interpreters, venvs, deps, tools, build, publish.
- Poetry — manifest + lockfile + venv, but no interpreter management.
- pip + pip-tools + virtualenv + pyenv — composable but fragmented.
- PDM — PEP 582 / 621 manager with overlapping scope.
- Conda — environments and cross-language packages, heavier and slower.

## Decision Outcome

We will adopt uv as the single Python toolchain manager and forbid parallel use of the legacy tools it replaces, per `specs/platform/uv.md`. uv consolidates the workflow into one binary, produces a deterministic `uv.lock`, and resolves orders of magnitude faster than the alternatives.

## Consequences

- Positive: `uv sync --locked` is a trustworthy gate for reproducible environments.
- Positive: one cache, one config (`pyproject.toml`), one CLI to learn.
- Positive: fast cold installs make CI and local onboarding cheap.
- Negative: uv is younger than Poetry/pip; some niche packaging edge cases may still surface.
- Negative: contributors arriving from Poetry/pyenv must unlearn parallel tools.
