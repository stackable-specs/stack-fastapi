#!/usr/bin/env bash
# Verify ADR-001 — Adopt Python as the Stack Language.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

req="$(toml_get pyproject.toml project.requires-python)"
if echo "$req" | grep -Eq '^>=3\.(1[2-9]|[2-9][0-9])'; then
	check_pass "pyproject.requires-python ≥ 3.12" "$req"
else
	check_fail "pyproject.requires-python ≥ 3.12" "actual: ${req:-<missing>}"
fi

if [ -f .python-version ]; then
	v="$(cat .python-version 2>/dev/null)"
	check_pass ".python-version present" "$v"
else
	check_fail ".python-version present" "file not found"
fi

strict="$(toml_get pyproject.toml tool.mypy.strict)"
if [ "$strict" = "True" ]; then
	check_pass "[tool.mypy].strict = true"
else
	check_fail "[tool.mypy].strict = true" "actual: ${strict:-<missing>}"
fi

if [ -n "$(toml_get pyproject.toml tool.ruff.lint.select)" ]; then
	check_pass "[tool.ruff.lint].select configured"
else
	check_fail "[tool.ruff.lint].select configured" "missing"
fi

if have_tools uv; then
	run_cmd RUFF_OUT RUFF_ERR RUFF_CODE -- uv run ruff check
	check "uv run ruff check exits 0" "$RUFF_CODE" \
		"$(printf '%s\n%s' "$RUFF_OUT" "$RUFF_ERR" | head -c 300 | tr '\n' ' ')"

	run_cmd MYPY_OUT MYPY_ERR MYPY_CODE -- uv run mypy
	check "uv run mypy exits 0" "$MYPY_CODE" \
		"$(printf '%s\n%s' "$MYPY_OUT" "$MYPY_ERR" | tail -c 300 | tr '\n' ' ')"
else
	check_skip "uv run ruff/mypy" "uv not on PATH"
fi

report_and_exit "ADR-001 — Python"
