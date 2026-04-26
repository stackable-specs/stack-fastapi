#!/usr/bin/env bash
# Verify ADR-009 — Adopt Unit Testing Discipline.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

if [ -d tests/unit ]; then
	check_pass "tests/unit/ present"
else
	check_fail "tests/unit/ present" "missing"
fi

count="$(find tests/unit -type f -name 'test_*.py' 2>/dev/null | wc -l | tr -d ' ')"
if [ "${count:-0}" -gt 0 ]; then
	check_pass "at least one unit test file" "found $count"
else
	check_fail "at least one unit test file" "none found"
fi

addopts="$(toml_get pyproject.toml tool.pytest.ini_options.addopts)"
if echo "$addopts" | grep -q -- '--strict-markers'; then
	check_pass "pytest --strict-markers enforced"
else
	check_fail "pytest --strict-markers enforced" "addopts: $addopts"
fi

fail_under="$(toml_get pyproject.toml tool.coverage.report.fail_under)"
if [ -n "$fail_under" ] && [ "$fail_under" -ge 80 ] 2>/dev/null; then
	check_pass "[tool.coverage.report].fail_under ≥ 80" "$fail_under"
else
	check_fail "[tool.coverage.report].fail_under ≥ 80" "actual: ${fail_under:-<missing>}"
fi

branch="$(toml_get pyproject.toml tool.coverage.run.branch)"
if [ "$branch" = "True" ]; then
	check_pass "[tool.coverage.run].branch = true"
else
	check_fail "[tool.coverage.run].branch = true" "actual: ${branch:-<missing>}"
fi

if have_tools uv; then
	run_cmd UT_OUT UT_ERR UT_CODE -- uv run pytest tests/unit tests/property --cov --cov-fail-under=80 -q
	check "uv run pytest unit+property --cov-fail-under=80 exits 0" "$UT_CODE" \
		"$(printf '%s\n%s' "$UT_OUT" "$UT_ERR" | tail -c 300 | tr '\n' ' ')"
else
	check_skip "uv run pytest with coverage" "uv not on PATH"
fi

report_and_exit "ADR-009 — Unit testing"
