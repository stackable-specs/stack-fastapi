"""Integration-test fixtures.

Real Postgres via Testcontainers (integration-testing rules 1, 2, 3) so the
suite catches schema drift, migration bugs, and driver issues that unit tests
cannot.
"""

from __future__ import annotations

from collections.abc import Iterator

import pytest
from testcontainers.postgres import PostgresContainer

from app.settings import Settings


@pytest.fixture(scope="session")
def postgres() -> Iterator[PostgresContainer]:
    # driver=None yields a plain `postgresql://` DSN that psycopg 3 accepts;
    # the testcontainers default is `psycopg2`, which psycopg 3 rejects.
    with PostgresContainer("postgres:17.2-alpine", driver=None) as container:
        yield container


@pytest.fixture()
def integration_settings(postgres: PostgresContainer) -> Settings:
    return Settings(
        environment="test",
        log_level="WARNING",
        database_url=postgres.get_connection_url(),
        cors_allow_origins=(),
        docs_enabled=False,
        otel_enabled=False,
    )
