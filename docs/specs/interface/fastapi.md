---
id: fastapi
layer: interface
extends:
  - python
---

# FastAPI

## Purpose

FastAPI's headline feature is that the Python type hints on a handler *are* the request schema, the response schema, the OpenAPI Description, the validation, and the auto-generated docs — but only when the team writes the type hints, declares response models, names operations explicitly, raises `HTTPException` instead of returning ad-hoc JSON, and treats the generated `/openapi.json` as a contract committed to source control. Left to defaults, FastAPI silently auto-derives unstable `operation_id`s from function names that change every refactor, accepts handlers annotated with bare `dict`, lets `4xx`/`5xx` responses ship as untyped default schemas, runs `fastapi dev` in production with one worker, exposes `/docs` to the public internet, leaves wildcard CORS open, accesses settings via scattered `os.getenv` calls, blocks the event loop with synchronous I/O inside `async def` handlers, and uses `BackgroundTasks` for work that should be on a queue. This spec pins the framework's pieces — Pydantic-typed boundaries, declared `response_model` and `operation_id`, `Depends`-based auth and dependency injection, `APIRouter` grouping with explicit tags, RFC 9457 error responses, the ASGI deployment shape, configuration via `pydantic-settings`, the OpenAPI artifact pipeline, and the test surface — so a FastAPI service produces a stable contract a client team can build against and a runtime a deploy team can operate.

## References

- **spec** `python` — language-layer Python spec this refines
- **spec** `openapi` — interface-layer OpenAPI spec for the artifact FastAPI generates
- **spec** `kubernetes` — platform-layer probe expectations for `/health` and `/ready`
- **external** `https://fastapi.tiangolo.com/` — FastAPI documentation
- **external** `https://docs.pydantic.dev/latest/` — Pydantic
- **external** `https://docs.pydantic.dev/latest/concepts/pydantic_settings/` — `pydantic-settings`
- **external** `https://www.uvicorn.org/` — Uvicorn ASGI server
- **external** `https://www.starlette.io/middleware/#corsmiddleware` — Starlette `CORSMiddleware`
- **external** `https://datatracker.ietf.org/doc/html/rfc9457` — RFC 9457: Problem Details for HTTP APIs
- **external** `https://www.python-httpx.org/async/` — `httpx.AsyncClient` for handler tests

## Rules

1. Pin the FastAPI version as an exact `dependency` in `pyproject.toml` (no `^` or `~`) and upgrade deliberately via a dedicated PR. (refs: python)
2. Run FastAPI under an ASGI server (Uvicorn, Hypercorn, Granian) with multiple workers behind a process supervisor in production; do not run `fastapi dev` or `uvicorn --reload` in production.
3. Define every request body and response payload as a Pydantic model; do not annotate handlers with bare `dict`, untyped `Body(...)`, or `Any`.
4. Declare `response_model=<Model>` on every operation that returns data; do not return a Pydantic model without `response_model` (so FastAPI can filter, validate, and document the response).
5. Type every path, query, header, and cookie parameter with `Path()`, `Query()`, `Header()`, or `Cookie()` and a Python type annotation; do not pull values from `request.query_params[...]` on the raw `Request` object.
6. Inject dependencies (DB sessions, current user, settings, HTTP clients) via `Depends(...)`; do not access shared state through module-level singletons from inside handler bodies.
7. Express authentication and authorization as `Depends` dependencies on each protected route (or via `dependencies=[Depends(auth)]` at the router level); do not rely on middleware as the sole authorization gate.
8. Mount routers via `APIRouter` grouped by domain with explicit `prefix=`, `tags=` (matching the team's tag taxonomy), and shared `dependencies=`; do not register routes directly on the `FastAPI` app instance for non-trivial services.
9. Use `async def` handlers for I/O-bound work and plain `def` (FastAPI runs them in a thread pool) for CPU-bound or blocking work; do not call blocking I/O from an `async def` handler without `fastapi.concurrency.run_in_threadpool`.
10. Set an explicit, stable `operation_id=` on every route (kebab- or camel-case per a single project convention); do not let FastAPI auto-derive `operation_id` from the function name. (refs: openapi)
11. Document non-2xx responses with the `responses=` parameter referencing typed error models (RFC 9457 Problem Details preferred); do not let `4xx` / `5xx` responses appear in the OpenAPI spec as untyped defaults.
12. Raise `HTTPException` (or a custom subclass mapped via `@app.exception_handler`) for expected errors; do not return ad-hoc `JSONResponse({"error": ...}, status_code=4xx)` from handler bodies.
13. Configure CORS via `CORSMiddleware` with an explicit `allow_origins` list, an explicit method allowlist, and an explicit header allowlist; do not enable wildcard CORS (`allow_origins=["*"]`) on credentialed endpoints in production.
14. Load configuration from a single `pydantic-settings.BaseSettings` class with environment-variable bindings; do not call `os.getenv(...)` ad-hoc inside handlers or modules.
15. Rely on Pydantic for request validation at the framework boundary; do not duplicate schema checks (type, range, required) inside handler bodies that the Pydantic model would already catch.
16. Use `BackgroundTasks` only for short, idempotent work tied to a single request; offload long-running, retryable, or scheduled work to a task queue (Celery, Arq, Dramatiq, RQ).
17. Commit the generated OpenAPI Description (`/openapi.json` written to a tracked file) to source control and lint / diff it in CI per the team's OpenAPI rules; do not rely on the live `/openapi.json` endpoint as the only source of truth. (refs: openapi)
18. Disable the interactive docs (`docs_url=None`, `redoc_url=None`) in environments where the API is not publicly documented, or protect them behind authentication; do not expose `/docs` and `/redoc` on a public production endpoint by accident.
19. Implement `/health` (liveness) and `/ready` (readiness) endpoints; the readiness check must exercise the real downstream dependencies the service needs to serve traffic, not return a static `200`. (refs: kubernetes)
20. Test handlers via `httpx.AsyncClient` (or `fastapi.testclient.TestClient`) against the actual app instance with `pytest`; do not test handlers by calling the function directly when route plumbing, dependencies, or middleware matter.
