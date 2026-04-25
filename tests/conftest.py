"""Shared pytest fixtures for the test suite."""

from __future__ import annotations

from collections.abc import Iterator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.main import create_app
from app.settings import Settings


@pytest.fixture()
def settings() -> Settings:
    return Settings(
        environment="test",
        log_level="WARNING",
        database_url="postgresql://test:test@localhost:5432/test",
        cors_allow_origins=(),
        docs_enabled=False,
    )


@pytest.fixture()
def app(settings: Settings) -> FastAPI:
    return create_app(settings=settings)


@pytest.fixture()
def client(app: FastAPI) -> Iterator[TestClient]:
    with TestClient(app) as test_client:
        yield test_client
