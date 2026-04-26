#!/usr/bin/env bash
# Verify ADR-012 — Adopt Trunk Code Quality as the Lint Runner.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

if [ -f .trunk/trunk.yaml ]; then
	check_pass ".trunk/trunk.yaml present"
else
	check_fail ".trunk/trunk.yaml present" "missing"
	report_and_exit "ADR-012 — Trunk Code Quality"
fi

cli_v="$(yaml_get_scalar .trunk/trunk.yaml cli.version)"
if echo "$cli_v" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
	check_pass "trunk cli.version pinned" "$cli_v"
else
	check_fail "trunk cli.version pinned" "actual: ${cli_v:-<missing>}"
fi

# Every plugin source ref must be a tagged release (vX.Y.Z), not a branch.
bad_refs="$(awk '
  /^[[:space:]]+ref:/ {
    sub(/^[[:space:]]+ref:[[:space:]]*/, "")
    gsub(/^"|"$|^'\''|'\''$/, "")
    if ($0 !~ /^v?[0-9]+\.[0-9]+\.[0-9]+$/) print
  }
' .trunk/trunk.yaml)"
if [ -z "$bad_refs" ]; then
	check_pass "every plugins.sources ref pinned to a tag"
else
	check_fail "every plugins.sources ref pinned to a tag" "$bad_refs"
fi

# Every lint.enabled entry must include @version pinning. Only inspect items
# under `lint.enabled:` — the `lint.ignore:` block uses `linters: [ALL]`-style
# entries that legitimately have no `@version`.
bad_lint="$(awk '
  /^lint:/                   { in_lint = 1; in_enabled = 0; next }
  /^[a-z]/                   { in_lint = 0; in_enabled = 0 }
  in_lint && /^[[:space:]]+enabled:/ { in_enabled = 1; next }
  in_lint && /^[[:space:]]+[a-z]+:/  { in_enabled = 0 }
  in_enabled && /^[[:space:]]+- / {
    line = $0
    sub(/^[[:space:]]+-[[:space:]]+/, "", line)
    if (line !~ /@/) print line
  }
' .trunk/trunk.yaml)"
if [ -z "$bad_lint" ]; then
	check_pass "every lint.enabled tool has @version"
else
	check_fail "every lint.enabled tool has @version" "$bad_lint"
fi

if have_tools trunk; then
	# Don't run the full lint here — that's prek's job. Just confirm the CLI
	# parses the config (a parse error is exit ≥2; lint findings are exit 1).
	run_cmd TR_OUT TR_ERR TR_CODE -- trunk config print
	if [ "$TR_CODE" -eq 0 ]; then
		check_pass "trunk parses .trunk/trunk.yaml"
	else
		check_fail "trunk parses .trunk/trunk.yaml" \
			"$(printf '%s\n%s' "$TR_OUT" "$TR_ERR" | tail -c 300 | tr '\n' ' ')"
	fi
else
	check_skip "trunk parses .trunk/trunk.yaml" "trunk CLI not on PATH"
fi

report_and_exit "ADR-012 — Trunk Code Quality"
