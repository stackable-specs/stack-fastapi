#!/usr/bin/env bash
# Verify ADR-020 — Adopt OpenTelemetry for Application Instrumentation.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

# Required deps pinned in [project.dependencies].
for pkg in opentelemetry-api opentelemetry-sdk opentelemetry-exporter-otlp \
	opentelemetry-instrumentation-fastapi opentelemetry-instrumentation-logging \
	opentelemetry-instrumentation-psycopg; do
	state="$(pep508_pin_state pyproject.toml "$pkg")"
	case "$state" in
	exact:*) check_pass "$pkg pinned exactly" "${state#exact:}" ;;
	range:*) check_fail "$pkg pinned exactly" "loose: ${state#range:}" ;;
	*) check_fail "$pkg pinned exactly" "not declared" ;;
	esac
done

if [ -f src/app/observability.py ]; then
	check_pass "src/app/observability.py present"
else
	check_fail "src/app/observability.py present" "missing"
	report_and_exit "ADR-020 — OpenTelemetry"
fi

# Resource attributes (rule 4): single source of truth via env vars. The
# observability module must use Resource.create({}) (no inline dict) and
# Compose must set both OTEL_SERVICE_NAME and OTEL_RESOURCE_ATTRIBUTES with
# the three required keys.
if grep -Eq 'Resource\.create\(\{\s*\}\)' src/app/observability.py; then
	check_pass "Resource.create({}) reads attributes from env"
else
	check_fail "Resource.create({}) reads attributes from env" \
		"observability.py still passes attributes inline (rule 4: single source via OTEL_*)"
fi

if grep -Eq '^[[:space:]]+OTEL_SERVICE_NAME:' compose.yaml; then
	check_pass "compose.yaml sets OTEL_SERVICE_NAME"
else
	check_fail "compose.yaml sets OTEL_SERVICE_NAME"
fi

ora="$(grep -E '^[[:space:]]+OTEL_RESOURCE_ATTRIBUTES:' compose.yaml | head -1)"
for needle in 'service.version' 'deployment.environment'; do
	if echo "$ora" | grep -q "$needle"; then
		check_pass "OTEL_RESOURCE_ATTRIBUTES carries $needle"
	else
		check_fail "OTEL_RESOURCE_ATTRIBUTES carries $needle" "actual: ${ora:-<missing>}"
	fi
done

# Batching processors (rule 9).
if grep -q 'BatchSpanProcessor' src/app/observability.py; then
	check_pass "BatchSpanProcessor used"
else
	check_fail "BatchSpanProcessor used" "synchronous span export"
fi
if grep -q 'BatchLogRecordProcessor' src/app/observability.py; then
	check_pass "BatchLogRecordProcessor used"
else
	check_fail "BatchLogRecordProcessor used" "synchronous log export"
fi

# Single-init guard (rule 8): init_telemetry is called from create_app only.
if grep -q 'init_telemetry' src/app/main.py; then
	check_pass "create_app calls init_telemetry"
else
	check_fail "create_app calls init_telemetry"
fi

# Auto-instrumentation hookups (rule 7).
if grep -q 'FastAPIInstrumentor' src/app/main.py; then
	check_pass "FastAPIInstrumentor wired in main.py"
else
	check_fail "FastAPIInstrumentor wired in main.py"
fi
if grep -q 'PsycopgInstrumentor' src/app/observability.py; then
	check_pass "PsycopgInstrumentor wired in observability.py"
else
	check_fail "PsycopgInstrumentor wired in observability.py"
fi
if grep -q 'LoggingInstrumentor' src/app/observability.py; then
	check_pass "LoggingInstrumentor wired in observability.py"
else
	check_fail "LoggingInstrumentor wired in observability.py"
fi

# Shutdown handler (rule 18).
if grep -q 'shutdown_telemetry' src/app/main.py; then
	check_pass "shutdown_telemetry registered"
else
	check_fail "shutdown_telemetry registered"
fi

# Standard OTEL_* env vars surfaced via Compose + .env.example (rules 2, 3, 10).
for var in OTEL_EXPORTER_OTLP_ENDPOINT OTEL_EXPORTER_OTLP_PROTOCOL \
	OTEL_TRACES_SAMPLER OTEL_SERVICE_NAME; do
	if grep -q "$var" compose.yaml && grep -q "$var" .env.example; then
		check_pass "$var declared in compose.yaml + .env.example"
	else
		check_fail "$var declared in compose.yaml + .env.example"
	fi
done

# No hardcoded endpoint in source (rule 2).
hardcoded="$(grep -rEn 'OTLPSpanExporter\(.*endpoint=|OTLPLogExporter\(.*endpoint=|OTLPMetricExporter\(.*endpoint=' src 2>/dev/null || true)"
if [ -z "$hardcoded" ]; then
	check_pass "no hardcoded OTLP endpoints in src/"
else
	check_fail "no hardcoded OTLP endpoints in src/" "$hardcoded"
fi

if have_tools uv; then
	run_cmd MYPY_OUT MYPY_ERR MYPY_CODE -- uv run mypy
	check "uv run mypy exits 0 (typecheck observability module)" "$MYPY_CODE" \
		"$(printf '%s\n%s' "$MYPY_OUT" "$MYPY_ERR" | tail -c 300 | tr '\n' ' ')"
else
	check_skip "uv run mypy" "uv not on PATH"
fi

report_and_exit "ADR-020 — OpenTelemetry"
