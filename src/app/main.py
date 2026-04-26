"""FastAPI application factory.

The application object is built by :func:`create_app` so tests, the CLI, and
the production ASGI server all start from the same construction path.
"""

from __future__ import annotations

import logging

from fastapi import FastAPI
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from starlette.middleware.cors import CORSMiddleware

from app.errors import register_error_handlers
from app.observability import init_telemetry, shutdown_telemetry
from app.routers import greetings_router, health_router
from app.settings import Settings, get_settings

__all__ = ["create_app"]

logger = logging.getLogger(__name__)


def create_app(settings: Settings | None = None) -> FastAPI:
    """Build and return a configured :class:`FastAPI` instance.

    Args:
        settings: Optional override; falls back to :func:`get_settings`.

    Returns:
        A configured FastAPI application ready to serve traffic.
    """
    resolved = settings or get_settings()
    logging.basicConfig(level=resolved.log_level)
    logger.info("starting app", extra={"environment": resolved.environment})

    # ADR-020: providers are created exactly once at process start
    # (opentelemetry rule 8) and shut down on FastAPI shutdown (rule 18).
    providers = init_telemetry(resolved)

    app = FastAPI(
        title="python-uv reference API",
        version="0.1.0",
        docs_url="/docs" if resolved.docs_enabled else None,
        redoc_url="/redoc" if resolved.docs_enabled else None,
    )

    if resolved.cors_allow_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=list(resolved.cors_allow_origins),
            allow_methods=["GET", "POST"],
            allow_headers=["Authorization", "Content-Type"],
            allow_credentials=True,
        )

    register_error_handlers(app)
    app.include_router(health_router)
    app.include_router(greetings_router)

    # ADR-020: official instrumentation library (opentelemetry rule 7).
    if resolved.otel_enabled:
        FastAPIInstrumentor.instrument_app(app)
        app.add_event_handler("shutdown", lambda: shutdown_telemetry(providers))

    return app


app = create_app()
