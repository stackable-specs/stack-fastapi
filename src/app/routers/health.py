"""Liveness and readiness probes (FastAPI rule 19)."""

from __future__ import annotations

from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app.errors import ProblemDetails
from app.settings import Settings, get_settings

__all__ = ["router", "HealthStatus", "ReadinessStatus"]

router = APIRouter(prefix="", tags=["health"])


class HealthStatus(BaseModel):
    """Liveness probe response."""

    status: Literal["ok"] = Field(default="ok")


class ReadinessStatus(BaseModel):
    """Readiness probe response."""

    status: Literal["ready", "not_ready"] = Field(default="ready")
    dependencies: dict[str, Literal["ok", "down"]] = Field(default_factory=dict)


@router.get(
    "/health",
    operation_id="get-health",
    response_model=HealthStatus,
    status_code=status.HTTP_200_OK,
    summary="Liveness probe",
)
async def get_health() -> HealthStatus:
    """Return ``200`` while the process is up."""
    return HealthStatus()


@router.get(
    "/ready",
    operation_id="get-ready",
    response_model=ReadinessStatus,
    status_code=status.HTTP_200_OK,
    summary="Readiness probe",
    responses={
        status.HTTP_503_SERVICE_UNAVAILABLE: {
            "model": ProblemDetails,
            "description": "At least one downstream dependency is unavailable.",
        },
    },
)
async def get_ready(
    settings: Annotated[Settings, Depends(get_settings)],
) -> ReadinessStatus:
    """Exercise downstream dependencies and report readiness.

    Args:
        settings: Resolved application settings.

    Raises:
        HTTPException: If any required dependency is unreachable.

    Returns:
        :class:`ReadinessStatus` with per-dependency health.
    """
    dependencies = await _check_dependencies(settings)
    if any(state == "down" for state in dependencies.values()):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Service is not ready",
        )
    return ReadinessStatus(status="ready", dependencies=dependencies)


async def _check_dependencies(settings: Settings) -> dict[str, Literal["ok", "down"]]:
    # The reference implementation does not yet open a real DB connection; an
    # extension PR should plug in the project's chosen async driver and verify
    # the connection here (FastAPI rule 19: readiness must touch real deps).
    del settings
    return {"database": "ok"}
