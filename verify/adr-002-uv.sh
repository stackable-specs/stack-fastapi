#!/usr/bin/env bash
# Verify ADR-002 — Adopt uv as the Python Toolchain Manager.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

if [ -f uv.lock ]; then
	check_pass "uv.lock committed"
else
	check_fail "uv.lock committed" "missing"
fi

pkg="$(toml_get pyproject.toml tool.uv.package)"
if [ "$pkg" = "True" ]; then
	check_pass "[tool.uv].package = true"
else
	check_fail "[tool.uv].package = true" "actual: ${pkg:-<missing>}"
fi

# uv supersedes pip-tools / Poetry / Pipenv — none of their lockfile artifacts
# should remain alongside uv.lock (uv rule: "uv is the single project manager").
strays=""
for f in requirements.txt requirements-dev.txt Pipfile Pipfile.lock poetry.lock; do
	[ -f "$f" ] && strays="${strays:+$strays, }$f"
done
if [ -z "$strays" ]; then
	check_pass "no parallel lockfile / manifest from a superseded tool"
else
	check_fail "no parallel lockfile / manifest from a superseded tool" "found: $strays"
fi

if have_tools uv; then
	run_cmd LOCK_OUT LOCK_ERR LOCK_CODE -- uv lock --locked
	check "uv lock --locked exits 0 (lockfile is up to date)" "$LOCK_CODE" \
		"$(printf '%s\n%s' "$LOCK_OUT" "$LOCK_ERR" | tail -c 300 | tr '\n' ' ')"
else
	check_skip "uv lock --check" "uv not on PATH"
fi

report_and_exit "ADR-002 — uv"
