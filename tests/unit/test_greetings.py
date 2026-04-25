"""Unit tests for :mod:`app.routers.greetings`.

Each test follows Arrange / Act / Assert and asserts on observable behavior
(unit-testing rules 4 and 5).
"""

from __future__ import annotations

import pytest

from app.routers.greetings import build_greeting


def test_build_greeting_returns_hello_with_name() -> None:
    result = build_greeting("Ada")

    assert result == "Hello, Ada!"


def test_build_greeting_strips_surrounding_whitespace() -> None:
    result = build_greeting("   Grace   ")

    assert result == "Hello, Grace!"


def test_build_greeting_raises_for_empty_name() -> None:
    with pytest.raises(ValueError, match="must not be empty"):
        build_greeting("   ")
