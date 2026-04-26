#!/usr/bin/env bash
# Verify ADR-010 — Adopt Integration Testing Discipline.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

if [ -d tests/integration ]; then
	check_pass "tests/integration/ present"
else
	check_fail "tests/integration/ present" "missing"
fi

count="$(find tests/integration -type f -name 'test_*.py' 2>/dev/null | wc -l | tr -d ' ')"
if [ "${count:-0}" -gt 0 ]; then
	check_pass "at least one integration test file" "found $count"
else
	check_fail "at least one integration test file" "none found"
fi

markers="$(toml_get pyproject.toml tool.pytest.ini_options.markers)"
if echo "$markers" | grep -q '"integration:'; then
	check_pass "integration pytest marker registered"
else
	check_fail "integration pytest marker registered" "no 'integration:' entry in markers"
fi

state="$(pep508_pin_state pyproject.toml testcontainers)"
if [ -n "$state" ]; then
	check_pass "testcontainers in dependency-groups" "$state"
else
	check_fail "testcontainers in dependency-groups" "not declared"
fi

if grep -Eq '^[[:space:]]+name:[[:space:]]*Integration' .github/workflows/ci.yml 2>/dev/null ||
	grep -q 'pytest tests/integration' .github/workflows/ci.yml 2>/dev/null; then
	check_pass "CI has an integration job"
else
	check_fail "CI has an integration job" "no integration job in .github/workflows/ci.yml"
fi

# Optionally run integration tests when both uv and Docker are available.
if have_tools uv docker; then
	if docker info >/dev/null 2>&1; then
		run_cmd IT_OUT IT_ERR IT_CODE -- uv run pytest tests/integration -m integration -q
		check "uv run pytest tests/integration exits 0" "$IT_CODE" \
			"$(printf '%s\n%s' "$IT_OUT" "$IT_ERR" | tail -c 300 | tr '\n' ' ')"
	else
		check_skip "integration tests" "docker daemon not reachable"
	fi
else
	check_skip "integration tests" "uv or docker not on PATH"
fi

report_and_exit "ADR-010 — Integration testing"
