---
id: openapi
layer: interface
extends: []
---

# OpenAPI

## Purpose

OpenAPI is the contract that lets a server team, a client team, an SDK generator, an API gateway, a rate-limiter, a security scanner, and a docs site all talk about the same API without reading each other's code — but only if the description is the single source of truth, kept in version control, linted, and diff-gated for breaking changes. When teams treat OpenAPI as documentation generated *from* code annotations as an afterthought, the description drifts: required fields silently become optional, an enum loses a value mid-release, an operation is renamed without bumping `info.version`, error responses are undocumented, and every consumer discovers the change by way of a 500. When teams skip examples, omit `operationId`, leave `responses` covering only `200`, and inline schemas instead of `$ref`-ing components, generated SDKs are unusable and reviewers cannot tell which changes are breaking. This spec pins the OpenAPI version, the design-first workflow, the version-control and CI gates (lint + breaking-change diff), the structural conventions (`operationId`, tags, components, `$ref`, naming), the response and security shape (RFC 9457 errors, declared security schemes, required request bodies), and the SDK generation flow — so the OAD is a contract two unrelated teams can build against, not a stale picture of last sprint's API.

## References

- **external** `https://www.openapis.org/` — OpenAPI Initiative
- **external** `https://spec.openapis.org/oas/latest.html` — OpenAPI Specification (latest)
- **external** `https://learn.openapis.org/best-practices.html` — OpenAPI best practices
- **external** `https://json-schema.org/specification.html` — JSON Schema (referenced by OpenAPI 3.1)
- **external** `https://datatracker.ietf.org/doc/html/rfc9457` — RFC 9457: Problem Details for HTTP APIs
- **external** `https://github.com/stoplightio/spectral` — Spectral OpenAPI linter
- **external** `https://github.com/Tufin/oasdiff` — `oasdiff` OpenAPI breaking-change diff
- **external** `https://openapi-generator.tech/` — OpenAPI Generator (server stubs and client SDKs)

## Rules

1. Author and version-control an OpenAPI Description (`.yaml` or `.json`) for every HTTP API the team owns; the OAD is the single source of truth, not code annotations, wikis, or generated HTML.
2. Use OpenAPI 3.1 for new APIs (full JSON Schema 2020-12 alignment); accept 3.0.x only when a required downstream tool does not yet support 3.1.
3. Adopt a design-first workflow — change the OpenAPI Description first, then generate or update server stubs and clients; do not let server code annotations be the de facto source from which a "current" spec is regenerated.
4. Commit the OpenAPI Description to source control alongside the implementation that serves it; do not host the spec only as a Confluence page or a generated HTML artifact.
5. Lint the OpenAPI Description in CI with Spectral (or equivalent) using a committed ruleset; treat lint errors as build failures.
6. Run an OpenAPI breaking-change diff (`oasdiff`, `openapi-diff`) in CI against the previously released spec; treat any breaking change as a build failure unless the major version is bumped in the same change.
7. Set `info.version` to a SemVer string (`MAJOR.MINOR.PATCH`) and bump it in the same commit that changes the API surface; do not edit the spec without bumping `info.version`.
8. Bump `info.version`'s major component for every breaking change (removed or renamed operation, changed required field, narrowed type, removed enum value); do not slip a breaking change into a minor or patch bump.
9. Express path templating with explicit, named path parameters (e.g. `/users/{userId}`) and document each parameter under `parameters` with `description`, `schema`, and `required: true`; do not use ad-hoc query-string positional encoding.
10. Assign every operation a unique, stable `operationId` (camelCase or kebab-case per a single project convention) that is used as the identifier in generated SDKs; do not rename `operationId`s on cosmetic changes.
11. Tag every operation with at least one `tags` entry that maps to a documented tag in the top-level `tags` array; do not leave operations untagged.
12. Provide a `summary` (short verb phrase, e.g. "Create user", "List orders") and a `description` (long, Markdown) on every operation; the `summary` must fit in a navigation tree.
13. Define reusable schemas, parameters, responses, headers, request bodies, security schemes, and examples under `components/*` and reference them with `$ref`; do not inline a schema that is used by more than one operation.
14. Name component schemas in `PascalCase`, parameters in `camelCase`, headers in `Train-Case`, and tags in human-readable Title Case.
15. Declare a `responses` entry for every operation including at least one `2xx`, the relevant `4xx`s, and `5xx` with a referenced error schema (RFC 9457 Problem Details preferred); do not document only the happy path.
16. Include a `requestBody` `content` schema for every `POST`, `PUT`, and `PATCH` operation; do not ship a write operation whose `requestBody` is `content: { 'application/json': {} }` with no schema.
17. Mark fields and parameters explicitly as `required` when the server requires them; do not rely on JSON-Schema's "all properties optional by default" to communicate "all fields required."
18. Provide at least one `example` (or `examples`) on every request body, every response, and every parameter whose meaning is not self-evident from its schema; do not ship a spec whose only example is the auto-generated empty object.
19. Declare every authentication mechanism under `components.securitySchemes` and apply it via top-level `security` (or per-operation overrides); do not document authentication in prose only.
20. Declare a single pagination shape (e.g. cursor-based with `cursor` query parameter and a `next` link or header) once under `components` and reference it from every list-returning endpoint; do not invent a different pagination format per endpoint.
21. Generate server stubs and client SDKs from the OpenAPI Description in CI for every consumer language the team supports; do not hand-maintain a parallel "should match the spec" client.
