# BDR-001: Greeting endpoint returns rendered message

## Status

Proposed

## Behavior

The service exposes a `POST /v1/greetings` endpoint that returns a rendered greeting message for a caller-supplied name.

## Context

The reference stack needs at least one example domain endpoint that exercises the FastAPI conventions (typed boundaries, declared `response_model`, RFC 9457 errors) so contributors can copy a known-good shape when adding new endpoints. A greeting is the smallest meaningful capability that touches request validation, the response model, and the error contract without introducing persistence concerns.

## Acceptance Criteria

- AC-1: A `POST /v1/greetings` request with body `{"name": "Ada"}` returns HTTP 201 and a JSON body whose `message` equals `"Hello, Ada!"`.
- AC-2: Surrounding whitespace in `name` does not appear in the returned `message` (e.g. `"  Ada  "` → `"Hello, Ada!"`).
- AC-3: A request with an empty or whitespace-only `name` returns HTTP 422 with `Content-Type: application/problem+json` and a `title` of `"Request validation failed"`.
- AC-4: A request with `name` longer than 100 characters returns HTTP 422 with the same Problem Details shape.

## Verification

### Scenario 1: Happy path

- **Given** the service is running
- **When** the client sends `POST /v1/greetings` with body `{"name": "Ada"}`
- **Then** the response status is `201`, the body is `{"message": "Hello, Ada!"}`, and `Content-Type` is `application/json`.

### Scenario 2: Whitespace normalization

- **Given** the service is running
- **When** the client sends `POST /v1/greetings` with body `{"name": "  Grace  "}`
- **Then** the response status is `201` and the body is `{"message": "Hello, Grace!"}`.

### Scenario 3: Invalid input

- **Given** the service is running
- **When** the client sends `POST /v1/greetings` with body `{"name": ""}`
- **Then** the response status is `422`, `Content-Type` is `application/problem+json`, and the body's `title` is `"Request validation failed"`.
