"""Integration tests against a real Postgres container."""

from __future__ import annotations

import psycopg
import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.settings import Settings


@pytest.mark.integration
def test_postgres_container_accepts_connections(integration_settings: Settings) -> None:
    with psycopg.connect(integration_settings.database_url) as conn, conn.cursor() as cur:
        cur.execute("SELECT 1")
        row = cur.fetchone()

    assert row == (1,)


@pytest.mark.integration
def test_readiness_probe_against_real_settings(integration_settings: Settings) -> None:
    app = create_app(settings=integration_settings)

    with TestClient(app) as client:
        response = client.get("/ready")

    assert response.status_code == 200
    assert response.json()["status"] == "ready"
