#!/usr/bin/env bash
# Verify ADR-018 — Adopt prek as the Single Git-Hook Runner.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

if [ -f prek.toml ]; then
	check_pass "prek.toml present"
else
	check_fail "prek.toml present" "missing"
	report_and_exit "ADR-018 — prek"
fi

# Trunk's git-hook actions must be disabled (prek rule 16: single hook runner).
if grep -Eq '^[[:space:]]+- trunk-(check-pre-push|fmt-pre-commit)' .trunk/trunk.yaml 2>/dev/null; then
	check_fail "Trunk hook actions disabled" \
		"trunk-check-pre-push or trunk-fmt-pre-commit still enabled"
else
	check_pass "Trunk hook actions disabled"
fi

# Mandatory hooks per prek spec.
for needle in 'gitleaks' 'commitlint' 'trunk' 'commit-msg' 'pre-push'; do
	if grep -q "$needle" prek.toml; then
		check_pass "prek.toml references '$needle'"
	else
		check_fail "prek.toml references '$needle'" "not found"
	fi
done

# Every remote rev must be pinned to a tag/SHA, never a branch name.
bad="$(awk '
  /^[[:space:]]*rev[[:space:]]*=/ {
    line = $0
    sub(/^[^=]*=[[:space:]]*/, "", line)
    gsub(/^"|"$/, "", line)
    if (line == "main" || line == "master" || line == "HEAD" || line == "trunk") print line
  }
' prek.toml)"
if [ -z "$bad" ]; then
	check_pass "every remote rev pinned to a tag or SHA"
else
	check_fail "every remote rev pinned to a tag or SHA" "branch refs: $bad"
fi

if grep -Eq '^\.PHONY:[[:space:]]+prek-install|^prek-install:' Makefile 2>/dev/null; then
	check_pass "Makefile prek-install target present"
else
	check_fail "Makefile prek-install target present" "missing"
fi

if grep -Eq 'name:[[:space:]]*prek' .github/workflows/ci.yml 2>/dev/null; then
	check_pass "CI has a prek job"
else
	check_fail "CI has a prek job" "no prek job in .github/workflows/ci.yml"
fi

if [ -f .github/workflows/prek-autoupdate.yml ]; then
	check_pass "prek auto-update workflow present"
else
	check_fail "prek auto-update workflow present" "missing"
fi

if have_tools prek; then
	if [ -d .git ]; then
		run_cmd PK_OUT PK_ERR PK_CODE -- prek run --all-files
		check "prek run --all-files exits 0" "$PK_CODE" \
			"$(printf '%s\n%s' "$PK_OUT" "$PK_ERR" | tail -c 300 | tr '\n' ' ')"
	else
		check_skip "prek run --all-files" "not a git repo"
	fi
else
	check_skip "prek run --all-files" "prek not on PATH"
fi

report_and_exit "ADR-018 — prek"
