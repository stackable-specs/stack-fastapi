"""RFC 9457 Problem Details error model and handlers.

FastAPI rule 11 requires ``4xx``/``5xx`` responses to use a typed error model
referenced from ``responses=``. This module defines that model and registers
the handlers that map :class:`fastapi.HTTPException` and validation errors
into the same shape (FastAPI rule 12).
"""

from __future__ import annotations

from typing import Any

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

__all__ = ["ProblemDetails", "register_error_handlers"]

_PROBLEM_CONTENT_TYPE = "application/problem+json"


class ProblemDetails(BaseModel):
    """RFC 9457 Problem Details for HTTP APIs.

    Attributes:
        type: URI reference identifying the problem type.
        title: Short, human-readable summary of the problem type.
        status: HTTP status code.
        detail: Human-readable explanation specific to this occurrence.
        instance: URI reference identifying the specific occurrence.
        errors: Optional structured field-level error list.
    """

    type: str = Field(default="about:blank")
    title: str
    status: int
    detail: str | None = None
    instance: str | None = None
    errors: list[dict[str, Any]] | None = None


def _problem_response(problem: ProblemDetails) -> JSONResponse:
    return JSONResponse(
        status_code=problem.status,
        content=problem.model_dump(exclude_none=True),
        media_type=_PROBLEM_CONTENT_TYPE,
    )


def register_error_handlers(app: FastAPI) -> None:
    """Register RFC 9457 error handlers on ``app``.

    Args:
        app: The FastAPI application to attach handlers to.
    """

    @app.exception_handler(HTTPException)
    async def _http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
        return _problem_response(
            ProblemDetails(
                title=exc.detail if isinstance(exc.detail, str) else "Request failed",
                status=exc.status_code,
                detail=exc.detail if isinstance(exc.detail, str) else None,
                instance=str(request.url),
            )
        )

    @app.exception_handler(RequestValidationError)
    async def _validation_exception_handler(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        return _problem_response(
            ProblemDetails(
                title="Request validation failed",
                status=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="One or more request fields failed validation.",
                instance=str(request.url),
                errors=list(exc.errors()),
            )
        )
