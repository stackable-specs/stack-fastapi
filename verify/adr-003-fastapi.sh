#!/usr/bin/env bash
# Verify ADR-003 — Adopt FastAPI as the HTTP Framework.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

state="$(pep508_pin_state pyproject.toml fastapi)"
case "$state" in
exact:*) check_pass "fastapi pinned exactly" "${state#exact:}" ;;
range:*) check_fail "fastapi pinned exactly" "loose constraint: ${state#range:}" ;;
*) check_fail "fastapi pinned exactly" "not declared in dependencies" ;;
esac

if [ -f src/app/main.py ]; then
	check_pass "src/app/main.py present"
else
	check_fail "src/app/main.py present" "file not found"
fi

if grep -Eq '^[[:space:]]*def[[:space:]]+create_app[[:space:]]*\(' src/app/main.py 2>/dev/null; then
	check_pass "create_app() factory defined in src/app/main.py"
else
	check_fail "create_app() factory defined in src/app/main.py" "factory not found"
fi

if grep -rEq '\bAPIRouter\s*\(' src/app 2>/dev/null; then
	check_pass "APIRouter used to group handlers"
else
	check_fail "APIRouter used to group handlers" "no APIRouter() usage in src/app"
fi

if grep -rEq '\bresponse_model[[:space:]]*=' src/app 2>/dev/null; then
	check_pass "at least one handler declares response_model"
else
	check_fail "at least one handler declares response_model" \
		"no response_model= found in src/app (fastapi rule on declared response shape)"
fi

report_and_exit "ADR-003 — FastAPI"
