---
id: openobserve
layer: observability
extends: []
---

# OpenObserve

## Purpose

OpenObserve is an OTLP-native store for logs, metrics, and traces that are queried together with SQL and correlated by trace ID. That correlation only works when every service emits well-structured OpenTelemetry data with the standard resource attributes and consistent stream naming — the moment a service writes bespoke HTTP payloads, hardcodes credentials, drops `service.name`, or lets metric cardinality explode, dashboards break, alerts go silent, and multi-tenant separation leaks. This spec pins how applications produce telemetry and how OpenObserve state (streams, retention, dashboards, alerts) is managed so the store remains a single coherent query surface instead of a pile of differently-shaped event streams per service.

## References

- **external** `https://github.com/openobserve/openobserve` — OpenObserve source repository
- **external** `https://openobserve.ai/docs` — OpenObserve documentation
- **external** `https://opentelemetry.io/docs/specs/otlp/` — OTLP protocol specification
- **external** `https://opentelemetry.io/docs/specs/semconv/` — OpenTelemetry Semantic Conventions
- **external** `https://opentelemetry.io/docs/specs/otel/` — OpenTelemetry specification

## Rules

1. Emit telemetry in OTLP format via an OpenTelemetry SDK; do not POST bespoke JSON payloads to OpenObserve HTTP endpoints from application code.
2. Configure the OTLP endpoint via the standard `OTEL_EXPORTER_OTLP_ENDPOINT` environment variable; do not hardcode the URL in source.
3. Pass OpenObserve credentials through `OTEL_EXPORTER_OTLP_HEADERS` (or an equivalent secret-injected env var); do not embed tokens, Basic-auth strings, or API keys in source or config files committed to the repo.
4. Declare `service.name`, `service.version`, and `deployment.environment` as OpenTelemetry resource attributes on every service; do not leave them unset or use placeholder values like `"unknown"`.
5. Use the OpenTelemetry Semantic Conventions for span and log attribute names (`http.*`, `db.*`, `rpc.*`, etc.); do not invent parallel attribute names for concepts the semconv already covers.
6. Emit logs as structured records with typed fields; do not concatenate variables into a single free-text `message` field that can only be parsed by regex at query time.
7. Attach the active trace ID and span ID to every log record emitted inside a traced operation.
8. Record exceptions as span events via the OpenTelemetry instrumentation (`span.recordException` / `record_exception`); do not only emit a log line when a span is active.
9. Do not use high-cardinality values (user IDs, request IDs, full URLs, email addresses) as metric label values; route that detail to span attributes or log fields instead.
10. Name OpenObserve organizations to separate tenants or major environments, and name streams to separate signal types within an organization; document the org/stream naming convention in a repo-level README.
11. Set an explicit retention policy on every stream in OpenObserve; do not rely on defaults that may vary across deployments.
12. Define dashboards, alerts, saved searches, and VRL pipelines as OpenObserve API payloads committed to version control; do not maintain them only in the web UI.
13. Perform ingest-time enrichment and reshaping with OpenObserve VRL pipelines, not with application-side reformatting done solely to satisfy query patterns.
14. Query and filter data with OpenObserve SQL (or PromQL for metrics) server-side; do not pull bulk data client-side and filter in the consumer.
15. Do not include secrets, credentials, full payloads containing credentials, or unmasked PII in log bodies, span attributes, or metric labels.
16. Handle telemetry-export failures without crashing the application: buffer, drop with a counter, or warn-log; do not propagate OTLP export errors into request handlers.
17. Surface a clear log line at process startup if the configured OpenObserve ingest endpoint is unreachable; do not fail silently.
18. Tag sample, debug, and non-production data with a clearly distinct organization or stream prefix so it cannot be confused with production telemetry at query time.
