#!/usr/bin/env bash
# Verify ADR-011 — Adopt Property-Based Testing for Invariants.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

if [ -d tests/property ]; then
	check_pass "tests/property/ present"
else
	check_fail "tests/property/ present" "missing"
fi

count="$(find tests/property -type f -name 'test_*.py' 2>/dev/null | wc -l | tr -d ' ')"
if [ "${count:-0}" -gt 0 ]; then
	check_pass "at least one property test file" "found $count"
else
	check_fail "at least one property test file" "none found"
fi

state="$(pep508_pin_state pyproject.toml hypothesis)"
case "$state" in
exact:*) check_pass "hypothesis pinned exactly" "${state#exact:}" ;;
range:*) check_fail "hypothesis pinned exactly" "loose: ${state#range:}" ;;
*) check_fail "hypothesis pinned exactly" "not declared" ;;
esac

if grep -rEq '@given|from hypothesis' tests/property 2>/dev/null; then
	check_pass "tests/property uses Hypothesis @given / imports"
else
	check_fail "tests/property uses Hypothesis @given / imports" "no Hypothesis usage detected"
fi

report_and_exit "ADR-011 — Property-based testing"
