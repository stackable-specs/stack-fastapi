"""Smoke-test fixtures (ADR-019, smoke-testing rules 6, 11).

Smoke tests exercise the *deployed* system via a base URL — never an
in-process app instance. The base URL comes from `SMOKE_BASE_URL` and
defaults to the locally-running Compose service.
"""

from __future__ import annotations

import os
from collections.abc import Iterator

import httpx
import pytest


@pytest.fixture(scope="session")
def smoke_base_url() -> str:
    """Resolve the URL the smoke suite probes (rule 5: documented per-env)."""
    return os.environ.get("SMOKE_BASE_URL", "http://localhost:8000").rstrip("/")


@pytest.fixture(scope="session")
def smoke_client(smoke_base_url: str) -> Iterator[httpx.Client]:
    """HTTP client with a per-test timeout (rule 11)."""
    with httpx.Client(base_url=smoke_base_url, timeout=httpx.Timeout(5.0)) as client:
        yield client
