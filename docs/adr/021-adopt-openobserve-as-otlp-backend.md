# ADR-021: Adopt OpenObserve as the OTLP Backend

## Status

Accepted

## Context and Problem Statement

ADR-020 commits the stack to OpenTelemetry as the emission surface. That choice is only operational once the OTLP traffic has somewhere to land that can store it, query it, alert on it, and correlate logs / traces / metrics by trace ID. Without a chosen backend, we ship spans into the void — or worse, every developer points their local stack at a different store and the dashboards on staging don't match the dashboards on production.

## Decision Drivers

- Single OTLP-native store for logs, metrics, and traces queried together (no Loki + Tempo + Mimir + Grafana cocktail to operate).
- SQL queryable so the same engineers who write the application can query its telemetry.
- Self-hostable in the local Compose topology (ADR-016) so dev parity matches CI and production.
- Multi-tenant separation by org / stream so non-production telemetry can't be confused with production data (`specs/observability/openobserve.md` rule 18).
- Dashboards / alerts / pipelines defined as committed API payloads, not UI clicks (rule 12).

## Considered Options

- **OpenObserve (this ADR)**, governed by `specs/observability/openobserve.md`. Single binary, OTLP-native, SQL queryable, self-hostable.
- Grafana Cloud / Loki + Tempo + Mimir. Three-store architecture; correlation requires an extra UI layer; heavier ops.
- Datadog / New Relic / Honeycomb. Hosted, polished, expensive at the per-event volumes we expect; locks the stack to a vendor SDK without ADR-020.
- Self-hosted Jaeger + Prometheus + Loki. Three separate stores; no SQL across signal types; no shared retention story.
- OpenTelemetry Collector → file. Useful for local debug; not a queryable store.

## Decision Outcome

We will adopt OpenObserve as the OTLP backend for the python-uv stack, governed by `specs/observability/openobserve.md`. The local Compose topology (ADR-016) gains an `openobserve` service whose `5080` HTTP port is the OTLP HTTP endpoint the API service exports to via `OTEL_EXPORTER_OTLP_ENDPOINT=http://openobserve:5080/api/default`. OpenObserve credentials are injected via `OTEL_EXPORTER_OTLP_HEADERS` from the environment per ADR-016 (no inline secrets per docker-compose rule 12). Org and stream naming follow the convention documented in `docs/observability/README.md` so non-production telemetry stays segregated from production. Dashboards, alerts, and VRL pipelines are committed as API payloads under `observability/` and replayed via the OpenObserve REST API — never authored only in the web UI.

## Consequences

- Positive: developers can `make up` and immediately see the same telemetry shape they will see in production at `http://localhost:5080`.
- Positive: trace ↔ log ↔ metric correlation by trace ID works out of the box because all three signal types land in the same store.
- Positive: VRL pipelines do ingest-time enrichment server-side, keeping application code free of telemetry-shape concerns (rule 13).
- Negative: another container in the dev Compose topology — adds memory pressure and a dependency on OpenObserve's release cadence for security patches (handled by ADR-014).
- Negative: an OpenObserve outage drops new ingest. Per `opentelemetry` rule 17 and `openobserve` rule 16, the application must not crash; we accept silent telemetry loss bounded by the SDK's batch buffer until the store recovers.

## References

- [ADR-014](014-adopt-dependency-management-policy.md) — pin / scan policy for the OpenObserve image
- [ADR-016](016-adopt-docker-compose-for-local-and-single-host.md) — Compose service the OpenObserve container is added to
- [ADR-020](020-adopt-opentelemetry-for-instrumentation.md) — emission surface this backend consumes
- `docs/specs/observability/openobserve.md` — rules this ADR adopts
