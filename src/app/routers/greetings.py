"""Example domain router demonstrating the FastAPI conventions."""

from __future__ import annotations

from fastapi import APIRouter, status
from pydantic import BaseModel, Field

from app.errors import ProblemDetails

__all__ = ["router", "GreetingRequest", "GreetingResponse", "build_greeting"]

router = APIRouter(prefix="/v1/greetings", tags=["greetings"])


class GreetingRequest(BaseModel):
    """Request body for :func:`create_greeting`."""

    name: str = Field(min_length=1, max_length=100, examples=["Ada"])


class GreetingResponse(BaseModel):
    """Response payload for :func:`create_greeting`."""

    message: str = Field(examples=["Hello, Ada!"])


def build_greeting(name: str) -> str:
    """Return a greeting for ``name``.

    Pure function so unit tests (ADR-009) and property tests (ADR-011) can
    exercise it without booting FastAPI.

    Args:
        name: The recipient's name. Leading and trailing whitespace is stripped.

    Returns:
        ``"Hello, <name>!"`` with the name normalized.

    Raises:
        ValueError: If ``name`` is empty after stripping.

    Example:
        >>> build_greeting("Ada")
        'Hello, Ada!'
    """
    normalized = name.strip()
    if not normalized:
        raise ValueError("name must not be empty")
    return f"Hello, {normalized}!"


@router.post(
    "",
    operation_id="create-greeting",
    response_model=GreetingResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a greeting",
    responses={
        status.HTTP_422_UNPROCESSABLE_ENTITY: {"model": ProblemDetails},
    },
)
async def create_greeting(payload: GreetingRequest) -> GreetingResponse:
    """Build a greeting from the request body.

    Args:
        payload: Validated request body.

    Returns:
        :class:`GreetingResponse` containing the rendered greeting.
    """
    return GreetingResponse(message=build_greeting(payload.name))
