"""Application configuration.

All runtime configuration is loaded through a single :class:`Settings` instance
at process start (FastAPI rule 14: no ad-hoc ``os.getenv`` calls in handlers).
"""

from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict

__all__ = ["Settings", "get_settings"]


class Settings(BaseSettings):
    """Process-wide settings sourced from the environment.

    Attributes:
        environment: Deployment environment (``local``, ``staging``, ``production``).
        log_level: Root logger level for the process.
        database_url: Postgres DSN used by the readiness probe.
        cors_allow_origins: Explicit CORS origin allowlist (FastAPI rule 13).
        docs_enabled: Whether ``/docs`` and ``/redoc`` are served (FastAPI rule 18).
    """

    model_config = SettingsConfigDict(
        env_prefix="APP_",
        env_file=None,
        case_sensitive=False,
        extra="forbid",
    )

    environment: str = Field(default="local")
    log_level: str = Field(default="INFO")
    database_url: str = Field(default="postgresql://app:app@localhost:5432/app")
    cors_allow_origins: tuple[str, ...] = Field(default=())
    docs_enabled: bool = Field(default=False)
    # ADR-020: OpenTelemetry is opt-in. Tests run with the default `False`
    # so they don't open OTLP exporters or attach root-logger handlers.
    # Compose / production deployments set `APP_OTEL_ENABLED=true`. Resource
    # attributes (service.name, service.version, deployment.environment) come
    # from `OTEL_SERVICE_NAME` and `OTEL_RESOURCE_ATTRIBUTES` env vars — not
    # from this Settings object — to keep one source of truth (rule 4).
    otel_enabled: bool = Field(default=False)


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Return the process-wide :class:`Settings` instance.

    Cached so dependent code receives the same object on every call. Tests can
    override via FastAPI's ``app.dependency_overrides`` instead of mutating the
    cache directly.

    Returns:
        The cached :class:`Settings` for this process.
    """
    return Settings()
