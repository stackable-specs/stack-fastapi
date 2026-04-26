#!/usr/bin/env bash
# Run every ADR verifier under verify/. Exit nonzero if any verifier fails.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCRIPTS="
adr-001-python.sh
adr-002-uv.sh
adr-003-fastapi.sh
adr-004-openapi.sh
adr-005-madr.sh
adr-006-bdr.sh
adr-007-conventional-commits.sh
adr-008-tdd.sh
adr-009-unit-testing.sh
adr-010-integration-testing.sh
adr-011-property-based-testing.sh
adr-012-trunk.sh
adr-013-sbom.sh
adr-014-dependency-management.sh
adr-015-docker.sh
adr-016-docker-compose.sh
adr-017-pdoc.sh
adr-018-prek.sh
adr-019-smoke-testing.sh
adr-020-opentelemetry.sh
adr-021-openobserve.sh
"

failed=0
total=0
for s in $SCRIPTS; do
	total=$((total + 1))
	bash "$SCRIPT_DIR/$s" || failed=$((failed + 1))
done

echo
if [ "$failed" -eq 0 ]; then
	echo "all $total ADR verifiers passed"
	exit 0
else
	echo "$failed of $total ADR verifiers failed"
	exit 1
fi
