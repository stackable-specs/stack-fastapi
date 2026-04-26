#!/usr/bin/env bash
# Verify ADR-019 — Adopt Smoke Testing as a Pipeline Gate.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

if [ -d tests/smoke ]; then
	check_pass "tests/smoke/ present"
else
	check_fail "tests/smoke/ present" "missing"
	report_and_exit "ADR-019 — Smoke testing"
fi

count="$(find tests/smoke -type f -name 'test_*.py' 2>/dev/null | wc -l | tr -d ' ')"
if [ "${count:-0}" -gt 0 ]; then
	check_pass "at least one smoke test file" "found $count"
else
	check_fail "at least one smoke test file" "none found"
fi

markers="$(toml_get pyproject.toml tool.pytest.ini_options.markers)"
if echo "$markers" | grep -q '"smoke:'; then
	check_pass "smoke pytest marker registered"
else
	check_fail "smoke pytest marker registered" "no 'smoke:' entry in markers"
fi

if grep -Eq '^\.PHONY:[[:space:]]+smoke|^smoke:' Makefile 2>/dev/null; then
	check_pass "Makefile smoke target present"
else
	check_fail "Makefile smoke target present" "missing"
fi

# CI smoke job must depend on build-image (rule 4: post-build, pre-deploy).
# Inspect the smoke job's body specifically — start at the smoke job header,
# stop at the next 2-space-indented job header.
if awk '
  /^  smoke:[[:space:]]*$/        { in_smoke = 1; next }
  in_smoke && /^  [a-z][a-z0-9_-]*:[[:space:]]*$/ { exit }
  in_smoke                        { print }
' .github/workflows/ci.yml 2>/dev/null |
	grep -Eq 'needs:[[:space:]]*\[[^]]*build-image'; then
	check_pass "CI smoke job needs: [build-image, ...]"
else
	check_fail "CI smoke job needs: [build-image, ...]" \
		"no smoke job dependency on build-image (rule 4)"
fi

if grep -q 'SMOKE_BASE_URL' tests/smoke/conftest.py 2>/dev/null; then
	check_pass "smoke fixture reads SMOKE_BASE_URL"
else
	check_fail "smoke fixture reads SMOKE_BASE_URL" \
		"tests/smoke/conftest.py does not honor SMOKE_BASE_URL (rule 5: per-env URL)"
fi

if [ -f .github/workflows/smoke-postdeploy.yml ]; then
	check_pass "post-deploy smoke workflow scaffolded"
else
	check_fail "post-deploy smoke workflow scaffolded" \
		".github/workflows/smoke-postdeploy.yml missing"
fi

# pytest-timeout pinned to enforce per-test cap (rule 11).
state="$(pep508_pin_state pyproject.toml pytest-timeout)"
case "$state" in
exact:*) check_pass "pytest-timeout pinned" "${state#exact:}" ;;
range:*) check_fail "pytest-timeout pinned" "loose: ${state#range:}" ;;
*) check_fail "pytest-timeout pinned" "not declared" ;;
esac

report_and_exit "ADR-019 — Smoke testing"
