#!/usr/bin/env bash
# Verify ADR-005 — Adopt MADR for Architectural Decision Records.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

if [ -d docs/adr ]; then
	check_pass "docs/adr/ exists"
else
	check_fail "docs/adr/ exists" "directory not found"
	report_and_exit "ADR-005 — MADR"
fi

if [ -f docs/adr/README.md ]; then
	check_pass "docs/adr/README.md index present"
else
	check_fail "docs/adr/README.md index present" "missing"
fi

# Every NNN-*.md must conform: ASCII filename, three-digit number, kebab-case body.
bad_names=""
for f in docs/adr/*.md; do
	base="$(basename "$f")"
	[ "$base" = "README.md" ] && continue
	case "$base" in
	[0-9][0-9][0-9]-*.md) ;; # ok
	*) bad_names="${bad_names:+$bad_names, }$base" ;;
	esac
done
if [ -z "$bad_names" ]; then
	check_pass "ADR filenames match NNN-<kebab>.md"
else
	check_fail "ADR filenames match NNN-<kebab>.md" "violations: $bad_names"
fi

# Each ADR must open with `# ADR-NNN: ...` and contain `## Status`.
bad_struct=""
for f in docs/adr/*.md; do
	base="$(basename "$f")"
	[ "$base" = "README.md" ] && continue
	num="${base%%-*}"
	if ! grep -Eq "^# ADR-${num}: " "$f"; then
		bad_struct="${bad_struct:+$bad_struct, }$base(no-title)"
		continue
	fi
	if ! grep -Eq '^## Status' "$f"; then
		bad_struct="${bad_struct:+$bad_struct, }$base(no-status)"
	fi
done
if [ -z "$bad_struct" ]; then
	check_pass "every ADR has H1 + ## Status section"
else
	check_fail "every ADR has H1 + ## Status section" "$bad_struct"
fi

# Index must reference every ADR file.
missing_in_index=""
for f in docs/adr/*.md; do
	base="$(basename "$f")"
	[ "$base" = "README.md" ] && continue
	if ! grep -q "$base" docs/adr/README.md 2>/dev/null; then
		missing_in_index="${missing_in_index:+$missing_in_index, }$base"
	fi
done
if [ -z "$missing_in_index" ]; then
	check_pass "index references every ADR"
else
	check_fail "index references every ADR" "missing: $missing_in_index"
fi

# Numbering monotonic from 001 with no gaps.
nums="$(find docs/adr -maxdepth 1 -type f -name '[0-9][0-9][0-9]-*.md' 2>/dev/null |
	awk -F/ '{print $NF}' | awk -F- '{print $1}' | sort -u)"
expected=1
gaps=""
for n in $nums; do
	exp="$(printf '%03d' "$expected")"
	if [ "$n" != "$exp" ]; then
		gaps="${gaps:+$gaps, }expected $exp got $n"
		break
	fi
	expected=$((expected + 1))
done
if [ -z "$gaps" ]; then
	check_pass "ADR numbering monotonic from 001"
else
	check_fail "ADR numbering monotonic from 001" "$gaps"
fi

report_and_exit "ADR-005 — MADR"
