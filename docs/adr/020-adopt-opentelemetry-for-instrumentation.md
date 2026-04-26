# ADR-020: Adopt OpenTelemetry for Application Instrumentation

## Status

Accepted

## Context and Problem Statement

The python-uv stack ships a FastAPI service backed by Postgres (ADR-003, ADR-016) and is meant to run in any environment where a deployment artifact (ADR-015) is delivered. Without a vendor-neutral instrumentation surface, traces / metrics / logs end up as ad-hoc `print` calls and per-vendor SDK code: a switch of backend, a new operator, or a second service all break the previous integration. We need a single instrumentation contract — span shape, attribute names, propagation — that any OTLP-compatible backend can consume.

## Decision Drivers

- One emission shape across services and languages so a backend swap is operational, not a code change.
- W3C Trace Context propagation across HTTP / gRPC / message-broker boundaries (`specs/observability/opentelemetry.md` rule 6).
- Standard `OTEL_*` env-var configuration so secrets and endpoints stay out of source (rule 2).
- Compatibility with the OpenObserve backend adopted in ADR-021.
- Auto-instrumentation for FastAPI, the logging bridge, and Postgres so the team writes business-domain spans, not framework boilerplate.

## Considered Options

- **OpenTelemetry SDK + auto-instrumentation libraries (this ADR)**, governed by `specs/observability/opentelemetry.md`.
- Vendor-specific SDK (Datadog, New Relic, Honeycomb, Sentry tracing). Locks the codebase to a single backend; switching means a global rewrite.
- Roll our own tracer over `logging` and structured JSON. Reinvents context propagation and semantic conventions; no auto-instrumentation; can't satisfy ADR-021.
- OpenTracing / OpenCensus. Both deprecated; OpenTelemetry is the explicit successor.

## Decision Outcome

We will adopt OpenTelemetry as the application instrumentation surface, governed by `specs/observability/opentelemetry.md`. A single `src/app/observability.py` module initializes the `TracerProvider`, `MeterProvider`, and `LoggerProvider` exactly once at process startup using a `Resource` keyed on `service.name`, `service.version`, and `deployment.environment`. FastAPI auto-instrumentation, the logging bridge, and the psycopg instrumentation are enabled at app construction time. The SDK is configured via the standard `OTEL_*` environment variables — `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_HEADERS`, `OTEL_EXPORTER_OTLP_PROTOCOL`, `OTEL_TRACES_SAMPLER`, `OTEL_SERVICE_NAME`, `OTEL_RESOURCE_ATTRIBUTES` — sourced from the environment per ADR-016. The W3C Trace Context propagator is the default. Providers are shut down on FastAPI's shutdown event so buffered telemetry flushes before exit.

## Consequences

- Positive: backend choice is a config change, not a code change; ADR-021 (OpenObserve) consumes this without further code edits.
- Positive: every HTTP request gets a span with `http.*` semantic-convention attributes for free via `FastAPIInstrumentor`.
- Positive: log records emitted through Python `logging` carry the active `trace_id` and `span_id` via the OTel logging bridge — log/trace correlation works without per-call code.
- Negative: adds a non-trivial dependency surface (`opentelemetry-api`, `-sdk`, `-exporter-otlp`, multiple `-instrumentation-*` packages) that must move in lockstep on upgrades.
- Negative: requires a running OTLP collector / backend in production; the spec rule "do not crash on exporter failure" means silent telemetry loss if the backend disappears — must be alerted on separately.

## References

- [ADR-003](003-adopt-fastapi-as-http-framework.md) — host framework auto-instrumented by `FastAPIInstrumentor`
- [ADR-014](014-adopt-dependency-management-policy.md) — pin policy that governs the new OTel deps
- [ADR-016](016-adopt-docker-compose-for-local-and-single-host.md) — env injection path for `OTEL_*` configuration
- [ADR-021](021-adopt-openobserve-as-otlp-backend.md) — OTLP backend that consumes the data this ADR emits
- `docs/specs/observability/opentelemetry.md` — rules this ADR adopts
