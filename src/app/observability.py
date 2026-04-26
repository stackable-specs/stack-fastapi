"""OpenTelemetry initialization (ADR-020).

`init_telemetry` is called exactly once at process start by `create_app`. It
registers global `TracerProvider` / `MeterProvider` / `LoggerProvider`
instances driven by batching processors that talk OTLP to the endpoint
configured via `OTEL_EXPORTER_OTLP_ENDPOINT` (opentelemetry rule 2).

Resource attributes (`service.name`, `service.version`,
`deployment.environment`) come from `OTEL_SERVICE_NAME` and
`OTEL_RESOURCE_ATTRIBUTES` env vars per opentelemetry rule 4 — single source
of truth, set by the deployment platform (Compose locally, secret manager in
production). Application code does not reach for OTel internals beyond the
public API.
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from pathlib import Path

from opentelemetry import metrics, trace
from opentelemetry._logs import set_logger_provider
from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.logging import LoggingInstrumentor
from opentelemetry.sdk._logs import LoggerProvider
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

from app.settings import Settings

__all__ = ["TelemetryProviders", "init_telemetry", "shutdown_telemetry"]

_OTLP_TOKEN_PATH = Path("/run/secrets/openobserve_token")


@dataclass
class TelemetryProviders:
    """Holds the providers so `shutdown_telemetry` can flush + dispose them."""

    tracer_provider: TracerProvider
    meter_provider: MeterProvider
    logger_provider: LoggerProvider


def _load_otlp_headers_from_secret() -> None:
    """Populate `OTEL_EXPORTER_OTLP_HEADERS` from a Compose secret if unset.

    Local-dev convention: `secrets/openobserve_token` is mounted at
    `/run/secrets/openobserve_token` and contains the full header line
    (e.g. `Authorization=Basic <base64>`). Production injects
    `OTEL_EXPORTER_OTLP_HEADERS` directly via the secret manager and this
    function is a no-op.
    """
    if os.environ.get("OTEL_EXPORTER_OTLP_HEADERS"):
        return
    if not _OTLP_TOKEN_PATH.is_file():
        return
    try:
        value = _OTLP_TOKEN_PATH.read_text().strip()
    except OSError:
        return
    if value:
        os.environ["OTEL_EXPORTER_OTLP_HEADERS"] = value


def init_telemetry(settings: Settings) -> TelemetryProviders | None:
    """Register global OTel providers.

    Returns `None` when telemetry is disabled (unit tests, ephemeral CLI runs);
    otherwise delegates to `_init_providers` which opens OTLP exporters. The
    side-effect path is exercised by the live Compose / smoke runs (ADR-019);
    the unit suite covers `otel_enabled=False` and the helper functions.
    """
    if not settings.otel_enabled:
        return None
    return _init_providers()


def _init_providers() -> TelemetryProviders:  # pragma: no cover
    """Real OTel provider construction. Excluded from unit coverage.

    Coverage of this body lives in the integration smoke run that brings the
    Compose topology up and queries OpenObserve back. Trying to unit-test it
    requires mocking out four OTel SDK entry points; the resulting tests prove
    only that mocks call mocks.
    """
    _load_otlp_headers_from_secret()
    # Resource.create({}) reads OTEL_SERVICE_NAME and OTEL_RESOURCE_ATTRIBUTES
    # from the environment (opentelemetry rule 4). Single source of truth.
    resource = Resource.create({})

    # Traces (opentelemetry rule 9 — batching span processor).
    tracer_provider = TracerProvider(resource=resource)
    tracer_provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(tracer_provider)

    # Metrics (opentelemetry rule 8 — single MeterProvider).
    meter_provider = MeterProvider(
        resource=resource,
        metric_readers=[PeriodicExportingMetricReader(OTLPMetricExporter())],
    )
    metrics.set_meter_provider(meter_provider)

    # Logs (opentelemetry rule 15 — bridge Python `logging` so records carry
    # the active trace_id and span_id AND get forwarded to OTLP).
    logger_provider = LoggerProvider(resource=resource)
    logger_provider.add_log_record_processor(BatchLogRecordProcessor(OTLPLogExporter()))
    set_logger_provider(logger_provider)
    LoggingInstrumentor().instrument(set_logging_format=True)
    # Attach an OTel handler to the root logger so records actually flow into
    # the LoggerProvider's OTLP pipeline (LoggingInstrumentor only injects
    # trace_id / span_id into the format string).
    from opentelemetry.sdk._logs import LoggingHandler  # noqa: PLC0415

    logging.getLogger().addHandler(
        LoggingHandler(level=logging.INFO, logger_provider=logger_provider)
    )

    # Auto-instrument psycopg when present (rule 7 — official instrumentation
    # libraries). The production image ships without psycopg by default; the
    # integration / test paths that import it pick up auto-instrumentation
    # transparently.
    try:
        from opentelemetry.instrumentation.psycopg import PsycopgInstrumentor  # noqa: PLC0415

        PsycopgInstrumentor().instrument()
    except ImportError:
        pass

    logging.getLogger(__name__).info("opentelemetry initialized")
    return TelemetryProviders(
        tracer_provider=tracer_provider,
        meter_provider=meter_provider,
        logger_provider=logger_provider,
    )


def shutdown_telemetry(providers: TelemetryProviders | None) -> None:
    """Flush + dispose providers (opentelemetry rule 18)."""
    if providers is None:
        return
    providers.tracer_provider.shutdown()  # type: ignore[no-untyped-call]
    providers.meter_provider.shutdown()
    providers.logger_provider.shutdown()  # type: ignore[no-untyped-call]
