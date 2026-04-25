# ADR-004: Adopt OpenAPI as the HTTP API Contract

## Status

Accepted

## Context and Problem Statement

Server teams, client teams, SDK generators, gateways, and security scanners all need a single machine-readable description of the HTTP APIs the stack ships. Without one, every consumer reverse-engineers the API from code or ad-hoc docs, breaking changes ship undetected, and SDKs drift from the implementation.

## Decision Drivers

- Single source of truth for the API surface.
- Tooling for SDK generation, lint, and breaking-change diff.
- Industry adoption — consumers expect OpenAPI.
- Compatibility with the chosen HTTP framework (ADR-003).

## Considered Options

- OpenAPI 3.1 — committed `.yaml`/`.json`, design-first, Spectral lint + `oasdiff` in CI.
- gRPC / Protobuf — strong typing and codegen, but mismatched with HTTP/JSON consumers.
- GraphQL — single endpoint, no need for path/operation contract, but rules out REST consumers.
- No formal contract — handler code is the contract.

## Decision Outcome

We will adopt OpenAPI 3.1 as the HTTP API contract, governed by `specs/interface/openapi.md`. The design-first workflow, version-controlled OAD, lint gate, and breaking-change diff make the OAD a reliable contract two unrelated teams can build against.

## Consequences

- Positive: SDK generation, lint, and breaking-change detection become CI-enforceable.
- Positive: pairs naturally with FastAPI, which emits OpenAPI from typed handlers.
- Negative: requires discipline — `info.version` bumps, examples on every operation, RFC 9457 error schema.
- Negative: design-first workflow adds a step before implementation; teams must internalize it.
