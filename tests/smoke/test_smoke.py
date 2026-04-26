"""Smoke tests (ADR-019, docs/specs/practices/smoke-testing.md).

One test per business-critical path (rule 2). Assertions are limited to
externally observable HTTP behavior (rule 7). Suite hard cap ≤ 5 minutes
(rule 3). Any failure stops the line (rule 8).
"""

from __future__ import annotations

import httpx
import pytest

pytestmark = pytest.mark.smoke


def test_health_endpoint_returns_ok(smoke_client: httpx.Client) -> None:
    """`/health` returns 200 and reports a known shape (rule 2: critical path)."""
    response = smoke_client.get("/health")
    assert response.status_code == 200
    payload = response.json()
    assert payload.get("status") == "ok"


def test_greetings_endpoint_responds(smoke_client: httpx.Client) -> None:
    """Primary API responds to a representative request (rule 2: critical path)."""
    response = smoke_client.get("/greetings/world")
    assert response.status_code == 200
    assert "message" in response.json()


def test_openapi_document_is_served(smoke_client: httpx.Client) -> None:
    """`/openapi.json` is reachable — confirms the app started past framework init."""
    response = smoke_client.get("/openapi.json")
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("application/json")
