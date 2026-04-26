"""Unit tests for `app.observability` (ADR-020).

Focused on the parts that don't require an OTLP collector: the `otel_enabled`
short-circuit and the `_load_otlp_headers_from_secret` helper.
"""

from __future__ import annotations

import os
from pathlib import Path

import pytest

from app.observability import _load_otlp_headers_from_secret, init_telemetry
from app.settings import Settings


def test_init_telemetry_returns_none_when_disabled() -> None:
    settings = Settings(otel_enabled=False)
    assert init_telemetry(settings) is None


def test_load_otlp_headers_keeps_existing_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("OTEL_EXPORTER_OTLP_HEADERS", "Authorization=Basic preset")
    _load_otlp_headers_from_secret()
    assert os.environ["OTEL_EXPORTER_OTLP_HEADERS"] == "Authorization=Basic preset"


def test_load_otlp_headers_reads_from_secret_file(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.delenv("OTEL_EXPORTER_OTLP_HEADERS", raising=False)
    secret = tmp_path / "openobserve_token"
    secret.write_text("Authorization=Basic from-file\n")
    monkeypatch.setattr("app.observability._OTLP_TOKEN_PATH", secret)
    _load_otlp_headers_from_secret()
    assert os.environ["OTEL_EXPORTER_OTLP_HEADERS"] == "Authorization=Basic from-file"


def test_load_otlp_headers_no_op_when_secret_missing(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.delenv("OTEL_EXPORTER_OTLP_HEADERS", raising=False)
    monkeypatch.setattr("app.observability._OTLP_TOKEN_PATH", tmp_path / "nonexistent")
    _load_otlp_headers_from_secret()
    assert "OTEL_EXPORTER_OTLP_HEADERS" not in os.environ


def test_load_otlp_headers_skips_empty_secret_file(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.delenv("OTEL_EXPORTER_OTLP_HEADERS", raising=False)
    secret = tmp_path / "empty"
    secret.write_text("   \n")
    monkeypatch.setattr("app.observability._OTLP_TOKEN_PATH", secret)
    _load_otlp_headers_from_secret()
    assert "OTEL_EXPORTER_OTLP_HEADERS" not in os.environ
