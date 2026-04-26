#!/usr/bin/env bash
# Verify ADR-004 — Adopt OpenAPI as the HTTP API Contract.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

if [ -f openapi.yaml ]; then
	check_pass "openapi.yaml committed at stack root"
else
	check_fail "openapi.yaml committed at stack root" "file not found"
	report_and_exit "ADR-004 — OpenAPI"
fi

oas_version="$(grep -E '^openapi:' openapi.yaml | head -1 | awk -F: '{print $2}' | tr -d ' "'\''')"
case "$oas_version" in
3.1.*) check_pass "openapi: 3.1.x" "$oas_version" ;;
3.0.*) check_fail "openapi: 3.1.x" "found 3.0.x — openapi rule 2 prefers 3.1" ;;
*) check_fail "openapi: 3.1.x" "actual: ${oas_version:-<missing>}" ;;
esac

info_version="$(yaml_get_scalar openapi.yaml info.version)"
if echo "$info_version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.]+)?$'; then
	check_pass "info.version is SemVer" "$info_version"
else
	check_fail "info.version is SemVer" "actual: ${info_version:-<missing>}"
fi

if [ -n "$(yaml_get_scalar openapi.yaml info.title)" ]; then
	check_pass "info.title present"
else
	check_fail "info.title present" "missing"
fi

if grep -Eq '^[[:space:]]*operationId:' openapi.yaml; then
	check_pass "at least one operationId declared"
else
	check_fail "at least one operationId declared" \
		"no operationId in openapi.yaml (openapi rule 10)"
fi

if grep -Eq '^[[:space:]]*tags:' openapi.yaml; then
	check_pass "tags declared on operations"
else
	check_fail "tags declared on operations" "no tags: in openapi.yaml (openapi rule 11)"
fi

if have_tools npx; then
	# Prefer a project ruleset if present; otherwise fall back to spectral's
	# built-in OpenAPI ruleset.
	ruleset_args=""
	for r in .spectral.yaml .spectral.yml .spectral.json spectral.yaml spectral.yml spectral.json; do
		if [ -f "$r" ]; then
			ruleset_args="--ruleset $r"
			break
		fi
	done
	if [ -z "$ruleset_args" ]; then
		# Built-in: ships with the CLI; one of "spectral:oas" or "spectral:asyncapi".
		ruleset_args="--ruleset $(printf 'extends: ["spectral:oas"]' | python3 -c "import sys,tempfile; f=tempfile.NamedTemporaryFile(mode='w',suffix='.yaml',delete=False); f.write(sys.stdin.read()); f.close(); print(f.name)")"
	fi
	# shellcheck disable=SC2086
	run_cmd SP_OUT SP_ERR SP_CODE -- npx --yes -- @stoplight/spectral-cli@6.15.0 lint openapi.yaml $ruleset_args --fail-severity=error
	check "spectral lint exits 0" "$SP_CODE" \
		"$(printf '%s\n%s' "$SP_OUT" "$SP_ERR" | tail -c 300 | tr '\n' ' ')"
else
	check_skip "spectral lint" "npx not on PATH"
fi

report_and_exit "ADR-004 — OpenAPI"
