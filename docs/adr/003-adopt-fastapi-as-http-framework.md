# ADR-003: Adopt FastAPI as the HTTP Framework

## Status

Accepted

## Context and Problem Statement

The stack needs a Python HTTP framework for synchronous APIs. The framework choice determines the validation model, the OpenAPI generation story, the async runtime, and the deployment shape. Without a single answer, services pick different frameworks, fragment middleware, and ship divergent contract artifacts.

## Decision Drivers

- Type-driven request/response validation aligned with the language spec.
- First-class OpenAPI generation (see ADR-004).
- ASGI-native to support async I/O without retrofits.
- Active maintenance and community size.

## Considered Options

- FastAPI — Pydantic + Starlette + automatic OpenAPI.
- Flask — mature, synchronous, no built-in validation or OpenAPI.
- Django + Django REST Framework — heavyweight, ORM-coupled, less suited to small services.
- Litestar — modern, type-driven, smaller community.
- Starlette directly — minimal, but the team would re-implement what FastAPI already provides.

## Decision Outcome

We will adopt FastAPI as the HTTP framework, with the framework usage constrained by `specs/interface/fastapi.md` (typed boundaries, declared `response_model` and `operation_id`, `Depends`-based DI, RFC 9457 errors, ASGI deployment shape, `pydantic-settings` configuration). FastAPI's type-hint-as-schema model collapses validation, docs, and the OpenAPI artifact into a single source.

## Consequences

- Positive: handler signatures are the contract — fewer places for spec drift to hide.
- Positive: async-first runtime fits I/O-bound services.
- Negative: defaults are unsafe in production (`/docs` exposed, wildcard CORS, unstable `operation_id`s) and must be locked down by the spec.
- Negative: tight coupling to Pydantic — major Pydantic releases drive framework upgrades.
