#!/usr/bin/env bash
# Verify ADR-016 — Adopt Docker Compose for Local Dev and Single-Host.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

for f in compose.yaml compose.override.yaml .env.example; do
	if [ -f "$f" ]; then
		check_pass "$f present"
	else
		check_fail "$f present" "missing"
	fi
done

if grep -Eq '^version[[:space:]]*:' compose.yaml 2>/dev/null; then
	check_fail "no top-level 'version:' key (modern compose schema)" \
		"compose.yaml still declares 'version:'"
else
	check_pass "no top-level 'version:' key (modern compose schema)"
fi

if grep -q 'condition: service_healthy' compose.yaml 2>/dev/null; then
	check_pass "depends_on uses condition: service_healthy"
else
	check_fail "depends_on uses condition: service_healthy" \
		"missing in compose.yaml (compose rule on health-gated startup)"
fi

if grep -q 'healthcheck:' compose.yaml 2>/dev/null; then
	check_pass "at least one service declares healthcheck:"
else
	check_fail "at least one service declares healthcheck:" \
		"no healthcheck: in compose.yaml"
fi

# No inline plaintext secrets in compose.yaml — passwords / tokens should come
# from .env or the Compose secrets store (compose rule 12). The grep below
# intentionally uses single quotes; we want grep itself to filter literal
# `${` substitutions, not have the shell expand them.
# shellcheck disable=SC2016
secret_hits="$(grep -iE '(PASSWORD|TOKEN|SECRET|API_KEY)[[:space:]]*=' compose.yaml 2>/dev/null |
	grep -v '\${' || true)"
if [ -z "$secret_hits" ]; then
	check_pass "no inline plaintext secret in compose.yaml"
else
	check_fail "no inline plaintext secret in compose.yaml" \
		"$(echo "$secret_hits" | head -3 | tr '\n' ' | ')"
fi

if have_tools docker; then
	run_cmd VAL_OUT VAL_ERR VAL_CODE -- docker compose -f compose.yaml -f compose.override.yaml config --quiet
	check "docker compose config validates" "$VAL_CODE" \
		"$(printf '%s\n%s' "$VAL_OUT" "$VAL_ERR" | tail -c 300 | tr '\n' ' ')"
else
	check_skip "docker compose config validates" "docker not on PATH"
fi

report_and_exit "ADR-016 — Docker Compose"
