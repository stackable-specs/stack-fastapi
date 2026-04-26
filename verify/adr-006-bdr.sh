#!/usr/bin/env bash
# Verify ADR-006 — Adopt BDR for Behavior Decision Records.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

if [ -d docs/bdr ]; then
	check_pass "docs/bdr/ exists"
else
	check_fail "docs/bdr/ exists" "directory not found"
fi

# BDR follows MADR-style numbering — file naming check is the structural gate;
# content is freeform until the team writes one.
if [ -d docs/bdr ]; then
	bad=""
	for f in docs/bdr/*.md; do
		[ -e "$f" ] || break
		base="$(basename "$f")"
		[ "$base" = "README.md" ] && continue
		case "$base" in
		[0-9][0-9][0-9]-*.md) ;;
		*) bad="${bad:+$bad, }$base" ;;
		esac
	done
	if [ -z "$bad" ]; then
		check_pass "BDR filenames match NNN-<kebab>.md (or none yet)"
	else
		check_fail "BDR filenames match NNN-<kebab>.md" "violations: $bad"
	fi
fi

report_and_exit "ADR-006 — BDR"
