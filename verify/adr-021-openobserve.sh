#!/usr/bin/env bash
# Verify ADR-021 — Adopt OpenObserve as the OTLP Backend.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

# Top-level (2-space-indented) service header for openobserve.
if grep -Eq '^  openobserve:[[:space:]]*$' compose.yaml; then
	check_pass "compose.yaml declares openobserve service"
else
	check_fail "compose.yaml declares openobserve service" "missing"
fi

# Helper: extract the body of a 2-indented service block from compose.yaml.
# Stops at the next 2-indented service header or a 0-indented top-level key.
service_body() {
	awk -v svc="$1" '
    $0 ~ "^  " svc ":[[:space:]]*$" { in_svc = 1; next }
    in_svc && /^  [a-z][a-z0-9_-]*:[[:space:]]*$/ { exit }
    in_svc && /^[a-z]/ { exit }
    in_svc { print }
  ' compose.yaml
}

oo_image="$(service_body openobserve | awk '/^[[:space:]]+image:/ { sub(/^[[:space:]]+image:[[:space:]]*/, ""); print; exit }')"
case "$oo_image" in
*@sha256:* | *:v[0-9]*) check_pass "openobserve image pinned" "$oo_image" ;;
*:latest | *:) check_fail "openobserve image pinned" "floating: $oo_image" ;;
*) check_fail "openobserve image pinned" "actual: ${oo_image:-<missing>}" ;;
esac

# Healthcheck is required only when the api waits on service_healthy; if the
# api uses service_started (allowed when the image is distroless), the
# healthcheck is optional.
api_dep_condition="$(service_body api |
	awk '/openobserve:/{found=1; next} found && /condition:/{
		sub(/^[^:]*:[[:space:]]*/, ""); print; exit
	}')"
if [ "$api_dep_condition" = "service_healthy" ]; then
	if service_body openobserve | grep -Eq '^[[:space:]]+healthcheck:'; then
		check_pass "openobserve service declares healthcheck"
	else
		check_fail "openobserve service declares healthcheck (required when api waits on service_healthy)"
	fi
else
	check_pass "openobserve healthcheck optional (api waits on $api_dep_condition)"
fi

# api waits for openobserve before starting (service_started is acceptable
# when the image is distroless and cannot host an in-container healthcheck;
# the OTel SDK absorbs initial export retries per opentelemetry rule 17).
if service_body api |
	awk '/openobserve:/{found=1; next} found && /condition: service_(healthy|started)/{ok=1; exit} END{exit !ok}'; then
	check_pass "api service waits for openobserve (healthy or started)"
else
	check_fail "api service waits for openobserve (healthy or started)"
fi

# OTLP endpoint default points at openobserve in .env.example (rule 2).
if grep -q 'OTEL_EXPORTER_OTLP_ENDPOINT=.*openobserve' .env.example; then
	check_pass ".env.example default endpoint targets openobserve"
else
	check_fail ".env.example default endpoint targets openobserve"
fi

# No inline OpenObserve credentials in compose / .env.example beyond the documented
# dev defaults (rule 3, 15). Skip comment lines in either file.
# shellcheck disable=SC2016
secret_hits="$(grep -hE '^[[:space:]]*OTEL_EXPORTER_OTLP_HEADERS[=:][^$]+' .env.example compose.yaml 2>/dev/null |
	grep -v '\${' || true)"
if [ -z "$secret_hits" ]; then
	check_pass "no inline OTLP headers / credentials in compose or .env.example"
else
	check_fail "no inline OTLP headers / credentials" "$(echo "$secret_hits" | head -3 | tr '\n' ' | ')"
fi

# Org / stream naming convention documented (rule 10).
if [ -f docs/observability/README.md ]; then
	check_pass "docs/observability/README.md present"
else
	check_fail "docs/observability/README.md present" "missing"
fi

if grep -q 'org' docs/observability/README.md 2>/dev/null &&
	grep -q 'stream' docs/observability/README.md 2>/dev/null; then
	check_pass "naming convention documents org + stream layout"
else
	check_fail "naming convention documents org + stream layout"
fi

# Retention policy documented (rule 11).
if grep -Eqi 'retention' docs/observability/README.md 2>/dev/null; then
	check_pass "stream retention policy documented"
else
	check_fail "stream retention policy documented"
fi

# Sample / debug data prefix convention (rule 18).
if grep -q 'debug' docs/observability/README.md 2>/dev/null; then
	check_pass "sample / debug org-prefix convention documented"
else
	check_fail "sample / debug org-prefix convention documented"
fi

if have_tools docker; then
	run_cmd CFG_OUT CFG_ERR CFG_CODE -- docker compose -f compose.yaml -f compose.override.yaml config --quiet
	check "docker compose config still validates after openobserve service" "$CFG_CODE" \
		"$(printf '%s\n%s' "$CFG_OUT" "$CFG_ERR" | tail -c 300 | tr '\n' ' ')"
else
	check_skip "docker compose config" "docker not on PATH"
fi

report_and_exit "ADR-021 — OpenObserve"
