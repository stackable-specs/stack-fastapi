#!/usr/bin/env bash
# Verify ADR-007 — Adopt Conventional Commits.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

for f in .commitlintrc.yaml .gitmessage; do
	if [ -f "$f" ]; then
		check_pass "$f present"
	else
		check_fail "$f present" "missing"
	fi
done

if grep -q 'config-conventional' .commitlintrc.yaml 2>/dev/null; then
	check_pass ".commitlintrc.yaml extends @commitlint/config-conventional"
else
	check_fail ".commitlintrc.yaml extends @commitlint/config-conventional"
fi

if grep -Eq 'commitlint' .github/workflows/ci.yml 2>/dev/null; then
	check_pass "CI runs commitlint"
else
	check_fail "CI runs commitlint" "no commitlint job in .github/workflows/ci.yml"
fi

# The most recent N commits should parse as Conventional Commits when in a git repo.
if [ -d .git ] && have_tools git; then
	bad=""
	count=0
	while IFS= read -r line; do
		[ -z "$line" ] && continue
		count=$((count + 1))
		if ! echo "$line" | grep -Eq '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([^)]+\))?!?:[[:space:]]+.+'; then
			bad="${bad:+$bad | }$line"
		fi
	done <<EOF
$(git log -n 20 --pretty=%s 2>/dev/null)
EOF
	if [ "$count" -eq 0 ]; then
		check_skip "recent commits parse as Conventional Commits" "no git history"
	elif [ -z "$bad" ]; then
		check_pass "last $count commits parse as Conventional Commits"
	else
		check_fail "last $count commits parse as Conventional Commits" "$bad"
	fi
else
	check_skip "recent commits parse as Conventional Commits" "not a git repo"
fi

report_and_exit "ADR-007 — Conventional Commits"
