"""Unit tests for HTTP handlers via FastAPI's :class:`TestClient`.

These exercise the full middleware and routing stack (FastAPI rule 20) but
without external dependencies — so they remain unit tests under
``unit-testing.md`` rule 1.
"""

from __future__ import annotations

from fastapi.testclient import TestClient


def test_health_returns_ok(client: TestClient) -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_create_greeting_returns_rendered_message(client: TestClient) -> None:
    response = client.post("/v1/greetings", json={"name": "Ada"})

    assert response.status_code == 201
    assert response.json() == {"message": "Hello, Ada!"}


def test_create_greeting_rejects_empty_name_with_problem_details(client: TestClient) -> None:
    response = client.post("/v1/greetings", json={"name": ""})

    assert response.status_code == 422
    assert response.headers["content-type"].startswith("application/problem+json")
    body = response.json()
    assert body["title"] == "Request validation failed"
    assert body["status"] == 422


def test_docs_disabled_in_default_settings(client: TestClient) -> None:
    response = client.get("/docs")

    assert response.status_code == 404
