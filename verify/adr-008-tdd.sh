#!/usr/bin/env bash
# Verify ADR-008 — Adopt the Red-Green-Refactor TDD Cycle.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

if [ -d tests ]; then
	check_pass "tests/ directory present"
else
	check_fail "tests/ directory present" "missing"
	report_and_exit "ADR-008 — TDD"
fi

count="$(find tests -type f -name 'test_*.py' 2>/dev/null | wc -l | tr -d ' ')"
if [ "${count:-0}" -gt 0 ]; then
	check_pass "at least one test_*.py file under tests/" "found $count"
else
	check_fail "at least one test_*.py file under tests/" "none found"
fi

# Skipped / xfail tests should reference an issue / TODO so they are not stealth-disabled.
skip_hits="$(grep -rEn --include='*.py' 'pytest\.mark\.(skip|xfail)' tests 2>/dev/null || true)"
unannotated=""
while IFS= read -r hit; do
	[ -z "$hit" ] && continue
	file="$(echo "$hit" | awk -F: '{print $1}')"
	line="$(echo "$hit" | awk -F: '{print $2}')"
	ctx="$(awk -v L="$line" 'NR>=L-3 && NR<=L+1 {print}' "$file")"
	if ! echo "$ctx" | grep -Eiq 'TODO|FIXME|issue[ :/#-]|https?://|reason='; then
		unannotated="${unannotated:+$unannotated | }$file:$line"
	fi
done <<EOF
$skip_hits
EOF
if [ -z "$unannotated" ]; then
	check_pass "every skip/xfail references an issue or has reason="
else
	check_fail "every skip/xfail references an issue or has reason=" "$unannotated"
fi

if have_tools uv; then
	run_cmd PT_OUT PT_ERR PT_CODE -- uv run pytest tests/unit tests/property -q
	check "uv run pytest (unit + property) exits 0" "$PT_CODE" \
		"$(printf '%s\n%s' "$PT_OUT" "$PT_ERR" | tail -c 300 | tr '\n' ' ')"
else
	check_skip "uv run pytest" "uv not on PATH"
fi

report_and_exit "ADR-008 — TDD"
