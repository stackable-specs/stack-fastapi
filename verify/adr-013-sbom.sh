#!/usr/bin/env bash
# Verify ADR-013 — Produce an SBOM for Every Released Artifact.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

state="$(pep508_pin_state pyproject.toml cyclonedx-bom)"
if [ -n "$state" ]; then
	check_pass "cyclonedx-bom in dependency-groups" "$state"
else
	check_fail "cyclonedx-bom in dependency-groups" "not declared"
fi

if grep -Eq '^\.PHONY: sbom|^sbom:' Makefile 2>/dev/null; then
	check_pass "Makefile sbom target present"
else
	check_fail "Makefile sbom target present" "missing"
fi

if grep -q 'anchore/sbom-action' .github/workflows/ci.yml 2>/dev/null ||
	grep -q 'cyclonedx' .github/workflows/ci.yml 2>/dev/null; then
	check_pass "CI emits an SBOM artifact"
else
	check_fail "CI emits an SBOM artifact" "no anchore/sbom-action or cyclonedx step"
fi

# sbom rule 5 (distribute SBOM alongside the artifact) is satisfied either
# by build-push-action's inline `sbom: true` OR by a dedicated SBOM step
# (anchore/sbom-action / cyclonedx). The inline form is incompatible with
# `load: true` because it forces a multi-arch manifest the local docker
# daemon can't import — when `load: true` is in use, the dedicated step
# is the right path.
if grep -q 'sbom: true' .github/workflows/ci.yml 2>/dev/null ||
	grep -q 'anchore/sbom-action' .github/workflows/ci.yml 2>/dev/null; then
	check_pass "SBOM attached to the build (inline or dedicated step)"
else
	check_fail "SBOM attached to the build (inline or dedicated step)" \
		"sbom rule 5 unmet"
fi

if grep -q 'upload-artifact' .github/workflows/ci.yml 2>/dev/null &&
	grep -q 'sbom' .github/workflows/ci.yml 2>/dev/null; then
	check_pass "SBOM uploaded as a CI artifact"
else
	check_fail "SBOM uploaded as a CI artifact"
fi

report_and_exit "ADR-013 — SBOM"
