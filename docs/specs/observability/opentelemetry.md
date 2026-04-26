---
id: opentelemetry
layer: observability
extends: []
---

# OpenTelemetry

## Purpose

OpenTelemetry is the vendor-neutral standard for producing traces, metrics, and logs and shipping them over OTLP. Its value depends on every service emitting data the same way: standard SDKs, standard resource attributes, standard semantic conventions, and W3C trace context across process boundaries. The moment a service writes a custom exporter, hardcodes endpoints, invents its own attribute names, or drops trace context at an RPC boundary, the data stops correlating and the backend (any backend) becomes a pile of differently-shaped event streams. This spec pins how applications instrument themselves with OpenTelemetry so traces stitch together, metrics aggregate cleanly, and logs join back to the spans that produced them — independent of which OTLP-compatible backend receives the data.

## References

- **external** `https://opentelemetry.io/` — OpenTelemetry project home
- **external** `https://opentelemetry.io/docs/specs/otel/` — OpenTelemetry specification
- **external** `https://opentelemetry.io/docs/specs/semconv/` — OpenTelemetry Semantic Conventions
- **external** `https://opentelemetry.io/docs/specs/otlp/` — OTLP protocol specification
- **external** `https://www.w3.org/TR/trace-context/` — W3C Trace Context
- **spec** `openobserve` — backend-specific rules for the OpenObserve OTLP store

## Rules

1. Emit telemetry through the official OpenTelemetry SDK for the language; do not write a custom OTLP exporter or tracer implementation.
2. Configure the SDK via the standard `OTEL_*` environment variables (`OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_SERVICE_NAME`, `OTEL_RESOURCE_ATTRIBUTES`, `OTEL_EXPORTER_OTLP_HEADERS`); do not hardcode endpoints, service names, or credentials in source.
3. Set `OTEL_EXPORTER_OTLP_PROTOCOL` explicitly to `grpc` or `http/protobuf`; do not rely on the SDK default, which varies across languages.
4. Declare `service.name`, `service.version`, and `deployment.environment` as resource attributes on every service; do not leave them unset or use placeholders like `"unknown"`.
5. Use OpenTelemetry Semantic Conventions for span, metric, and log attribute names (`http.*`, `db.*`, `rpc.*`, `messaging.*`); do not invent parallel attribute names for concepts the semconv already covers.
6. Propagate trace context across process boundaries using the W3C Trace Context (`traceparent`, `tracestate`) headers; do not use vendor-specific propagators unless required for interop with a non-OTel system.
7. Instrument inbound and outbound RPCs (HTTP servers and clients, gRPC, database drivers, message brokers) using the official OpenTelemetry instrumentation libraries; do not write manual spans for what an instrumentation already covers.
8. Initialize the `TracerProvider`, `MeterProvider`, and `LoggerProvider` exactly once at process startup; do not create new providers per request, per handler, or per module.
9. Use the batching span processor and batching log record processor in production; do not export spans or log records synchronously per operation.
10. Configure a head sampler explicitly (typically `ParentBased(TraceIdRatioBased(...))`); do not ship code that hardcodes 100 % sampling in production paths.
11. Choose the metric instrument that matches the semantic — `Counter` for monotonic counts, `UpDownCounter` for additive gauges, `Histogram` for distributions, observable instruments for polled values; do not record latencies as counters or rates as gauges.
12. Do not use high-cardinality values (user IDs, request IDs, full URLs with query strings, email addresses) as metric attribute values; put that detail on span attributes or log records instead.
13. Record exceptions on the active span via `record_exception` / `recordException`; do not rely solely on a log line to capture an error inside a traced operation.
14. Set span status to `ERROR` on failed operations; do not leave a failed operation as a span with status `UNSET` or `OK`.
15. Emit application logs through the OpenTelemetry logs API or a logging bridge so each record carries the active `trace_id` and `span_id`; do not emit logs through a path that bypasses OTel context.
16. Do not record secrets, credentials, authorization headers, or unmasked PII as span attributes, log attributes, metric attributes, or resource attributes.
17. Handle exporter failures without crashing the application — buffer, drop with a dropped-records counter, or warn-log; do not propagate OTLP export errors into request handlers.
18. Shut down the tracer, meter, and logger providers on process termination so buffered telemetry is flushed before exit.
