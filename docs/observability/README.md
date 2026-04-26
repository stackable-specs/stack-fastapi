# Observability conventions (ADR-020 / ADR-021)

This stack emits telemetry per [`docs/specs/observability/opentelemetry.md`](../specs/observability/opentelemetry.md) and stores it in OpenObserve per [`docs/specs/observability/openobserve.md`](../specs/observability/openobserve.md).

## OpenObserve organization & stream naming

Per `openobserve` rule 10, organizations separate tenants / major environments and streams separate signal types. The convention this stack uses:

| Layer               | Convention                              | Example                                |
| ------------------- | --------------------------------------- | -------------------------------------- |
| Org                 | `<environment>`                         | `production`, `staging`, `local`, `ci` |
| Trace stream        | `default` (the OTLP default for traces) | `production / default`                 |
| Log stream          | `<service-name>-logs`                   | `production / python-uv-app-logs`      |
| Metric stream       | `<service-name>-metrics`                | `production / python-uv-app-metrics`   |
| Sample / debug data | `<environment>-debug` org prefix        | `local-debug`                          |

Per `openobserve` rule 18, **sample / debug / load-test traffic must land in an org whose name carries the `*-debug` suffix** so it is impossible to confuse with production telemetry at query time.

## Stream retention

`openobserve` rule 11 requires an explicit retention per stream — never the default. The defaults this stack uses are:

| Signal  | Org                 | Retention | Rationale                                                    |
| ------- | ------------------- | --------- | ------------------------------------------------------------ |
| traces  | `production`        | 7 days    | sufficient for live debugging; long-term diagnosis uses logs |
| logs    | `production`        | 30 days   | meets the typical security / audit lookback window           |
| metrics | `production`        | 90 days   | preserves quarter-over-quarter trending                      |
| any     | `staging` / `local` | 7 days    | cheap to regenerate                                          |
| any     | `*-debug`           | 24 hours  | aggressive aging so debug never accumulates                  |

## Resource attributes

Every emitted signal carries the resource attributes mandated by `opentelemetry` rule 4:

| Attribute                | Source                                                | Required |
| ------------------------ | ----------------------------------------------------- | -------- |
| `service.name`           | `OTEL_SERVICE_NAME` env var                           | yes      |
| `service.version`        | `OTEL_RESOURCE_ATTRIBUTES=service.version=...`        | yes      |
| `deployment.environment` | `OTEL_RESOURCE_ATTRIBUTES=deployment.environment=...` | yes      |

The Compose service in `compose.yaml` sets all three for local dev. CI / production deployments inject them via the same `OTEL_*` env-var path.

## Authoring dashboards / alerts / pipelines

Per `openobserve` rule 12, dashboards / alerts / saved searches / VRL pipelines live as committed API payloads — never only in the web UI. Convention:

```
observability/
  dashboards/<name>.json
  alerts/<name>.json
  pipelines/<name>.vrl
```

Each file is replayed against the OpenObserve REST API as part of the deployment workflow. Authoring a new dashboard means: build it in the UI to validate, export as JSON, commit the file, the next deploy provisions it.

## High-cardinality discipline

Per both `opentelemetry` rule 12 and `openobserve` rule 9, the following must NEVER appear as metric label values:

- user IDs / customer IDs
- request IDs / correlation IDs
- email addresses / phone numbers
- full URLs with query strings
- file paths

Put that detail on **span attributes** or **log fields** instead — both can carry high cardinality without causing storage explosions.
