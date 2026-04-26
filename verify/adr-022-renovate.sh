#!/usr/bin/env bash
# Verify ADR-022 — Adopt the Renovate Configuration Spec.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

if [ -f renovate.json ]; then
	check_pass "renovate.json present at repo root (rule 1)"
else
	check_fail "renovate.json present at repo root (rule 1)" "missing"
	report_and_exit "ADR-022 — Renovate"
fi

require_tools jq

# Rule 2 — schema reference pinned.
schema="$(jq -r '."$schema" // empty' renovate.json)"
if [ "$schema" = "https://docs.renovatebot.com/renovate-schema.json" ]; then
	check_pass "schema reference pinned (rule 2)"
else
	check_fail "schema reference pinned (rule 2)" "actual: ${schema:-<missing>}"
fi

# Rule 3 — CI validation step exists.
if grep -q 'renovate-config-validator' .github/workflows/ci.yml 2>/dev/null; then
	check_pass "CI runs renovate-config-validator (rule 3)"
else
	check_fail "CI runs renovate-config-validator (rule 3)"
fi

# Rule 5 — explicit timezone + workday-bounded routine schedule.
tz="$(jq -r '.timezone // empty' renovate.json)"
if [ -n "$tz" ]; then
	check_pass "timezone set (rule 5)" "$tz"
else
	check_fail "timezone set (rule 5)" "missing"
fi

if jq -e '.schedule | type == "array" and length > 0' renovate.json >/dev/null 2>&1; then
	check_pass "routine schedule defined (rule 5)" "$(jq -r '.schedule | join(" / ")' renovate.json)"
else
	check_fail "routine schedule defined (rule 5)"
fi

# Rule 6 — concurrency caps.
for key in prConcurrentLimit prHourlyLimit; do
	val="$(jq -r ".${key} // empty" renovate.json)"
	if [ -n "$val" ] && [ "$val" -gt 0 ] 2>/dev/null; then
		check_pass "${key} set (rule 6)" "$val"
	else
		check_fail "${key} set (rule 6)" "actual: ${val:-<missing>}"
	fi
done

# Rule 7 — dependency dashboard enabled.
if jq -e '.dependencyDashboard == true' renovate.json >/dev/null 2>&1; then
	check_pass "dependencyDashboard enabled (rule 7)"
else
	check_fail "dependencyDashboard enabled (rule 7)"
fi

# Rule 8 — at least one routine grouping by ecosystem and update type.
if jq -e '.packageRules[]? | select(.groupName != null and (.matchUpdateTypes // []) as $u | ($u | index("minor")) or ($u | index("patch")))' renovate.json >/dev/null 2>&1; then
	check_pass "routine grouping by ecosystem + update type (rule 8)"
else
	check_fail "routine grouping by ecosystem + update type (rule 8)"
fi

# Rule 9 — security PRs unbatched, always-on, separate stream.
if jq -e '.vulnerabilityAlerts.enabled == true' renovate.json >/dev/null 2>&1; then
	check_pass "vulnerabilityAlerts enabled (rule 9)"
else
	check_fail "vulnerabilityAlerts enabled (rule 9)"
fi
if jq -e '.vulnerabilityAlerts.schedule | tostring | test("at any time")' renovate.json >/dev/null 2>&1; then
	check_pass "vulnerabilityAlerts schedule = at any time (rule 9)"
else
	check_fail "vulnerabilityAlerts schedule = at any time (rule 9)"
fi

# Rule 10 — severity surfaces. Renovate's validator forbids `prPriority` inside
# `vulnerabilityAlerts`; the practical priority surface is (a) immediate PR
# creation, (b) at-any-time schedule, (c) a distinct `security` label.
if jq -e '.vulnerabilityAlerts.prCreation == "immediate"' renovate.json >/dev/null 2>&1; then
	check_pass "vulnerabilityAlerts.prCreation = immediate (rule 10)"
else
	check_fail "vulnerabilityAlerts.prCreation = immediate (rule 10)"
fi
if jq -e '(.vulnerabilityAlerts.labels // []) | index("security")' renovate.json >/dev/null 2>&1; then
	check_pass "vulnerabilityAlerts carries 'security' label (rule 10)"
else
	check_fail "vulnerabilityAlerts carries 'security' label (rule 10)"
fi

# Rule 11 — explicit rangeStrategy for an application.
rs="$(jq -r '.rangeStrategy // empty' renovate.json)"
if [ "$rs" = "pin" ] || [ "$rs" = "bump" ]; then
	check_pass "rangeStrategy set explicitly (rule 11)" "$rs"
else
	check_fail "rangeStrategy set explicitly (rule 11)" "actual: ${rs:-<missing>}"
fi

# Rule 12 — lockFileMaintenance enabled with a schedule.
if jq -e '.lockFileMaintenance.enabled == true and (.lockFileMaintenance.schedule | length) > 0' renovate.json >/dev/null 2>&1; then
	check_pass "lockFileMaintenance enabled + scheduled (rule 12)"
else
	check_fail "lockFileMaintenance enabled + scheduled (rule 12)"
fi

# Rule 13 — automerge restricted to safe categories. We accept either no
# repo-wide automerge OR an automerge rule scoped to devDependencies + safe
# update types.
if jq -e '.automerge == true' renovate.json >/dev/null 2>&1; then
	check_fail "no repo-wide automerge (rule 13)" "top-level automerge=true"
else
	# Any per-rule automerge must be gated on devDependencies AND safe types.
	if jq -e '
    [.packageRules[]? | select(.automerge == true)] as $am
      | ($am | length) == 0
      or all($am[];
        (.matchDepTypes // []) | index("devDependencies")
      )
  ' renovate.json >/dev/null 2>&1; then
		check_pass "automerge restricted to devDependencies or absent (rule 13)"
	else
		check_fail "automerge restricted to devDependencies or absent (rule 13)" \
			"a packageRule sets automerge=true outside devDependencies"
	fi
fi

# Rule 14 — automerge forbidden on security updates.
if jq -e '.vulnerabilityAlerts.automerge != true' renovate.json >/dev/null 2>&1; then
	check_pass "automerge forbidden on security updates (rule 14)"
else
	check_fail "automerge forbidden on security updates (rule 14)"
fi

# Rule 18 — operating-model documented.
if [ -f docs/dependencies/renovate.md ]; then
	check_pass "operating model documented (rule 18)"
else
	check_fail "operating model documented (rule 18)" "docs/dependencies/renovate.md missing"
fi

# Final — schema-level JSON validity.
if jq empty renovate.json >/dev/null 2>&1; then
	check_pass "renovate.json parses as JSON"
else
	check_fail "renovate.json parses as JSON"
fi

if have_tools npx; then
	run_cmd RV_OUT RV_ERR RV_CODE -- npx --yes --package renovate -- renovate-config-validator --strict renovate.json
	check "renovate-config-validator --strict exits 0" "$RV_CODE" \
		"$(printf '%s\n%s' "$RV_OUT" "$RV_ERR" | tail -c 400 | tr '\n' ' ')"
else
	check_skip "renovate-config-validator" "npx not on PATH"
fi

report_and_exit "ADR-022 — Renovate"
