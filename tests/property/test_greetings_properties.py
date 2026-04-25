"""Property-based tests for :func:`app.routers.greetings.build_greeting`.

The property pattern exercised is a *format invariant* (property-based-testing
rule 6): for any non-blank input, the rendered greeting must contain the
stripped name and follow the documented template.
"""

from __future__ import annotations

import pytest
from hypothesis import HealthCheck, given, settings
from hypothesis import strategies as st

from app.routers.greetings import build_greeting

_non_blank_text = st.text(min_size=1, max_size=100).filter(lambda s: s.strip() != "")


@settings(max_examples=200, suppress_health_check=[HealthCheck.too_slow])
@given(name=_non_blank_text)
def test_build_greeting_format_invariant(name: str) -> None:
    """Output must equal ``"Hello, <stripped-name>!"`` for any non-blank input."""
    result = build_greeting(name)

    assert result == f"Hello, {name.strip()}!"


@settings(max_examples=50)
@given(name=st.text(max_size=50).filter(lambda s: s.strip() == ""))
def test_build_greeting_rejects_blank_inputs(name: str) -> None:
    """All-blank inputs (after :py:meth:`str.strip`) must raise."""
    with pytest.raises(ValueError):
        build_greeting(name)
