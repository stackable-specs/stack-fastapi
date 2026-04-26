#!/usr/bin/env bash
# Shared helpers for verify/*.sh. Source from other scripts; do not run directly.
#
# Platform-agnostic: only POSIX-portable invocations of grep / awk / sed.
# TOML parsing uses python3's stdlib tomllib (Python 3.11+); the stack already
# requires Python 3.12 (ADR-001).

# Resolve stack root: verify/lib.sh -> stack root is ..
if [ -z "${STACK_ROOT-}" ]; then
	STACK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
	export STACK_ROOT
fi

if [ -t 1 ]; then
	RED=$'\033[31m'
	GREEN=$'\033[32m'
	YELLOW=$'\033[33m'
	DIM=$'\033[2m'
	RESET=$'\033[0m'
else
	RED=""
	GREEN=""
	YELLOW=""
	DIM=""
	RESET=""
fi

CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_SKIPPED=0
CHECKS_RESULTS=()

require_tools() {
	local missing=""
	local t
	for t in "$@"; do
		if ! command -v "$t" >/dev/null 2>&1; then
			missing="${missing:+$missing, }$t"
		fi
	done
	if [ -n "$missing" ]; then
		echo "missing required tool(s): $missing" >&2
		exit 2
	fi
}

# Returns 0 if every named tool is on PATH, nonzero otherwise. Use to gate
# checks that require an optional dependency without aborting the script.
have_tools() {
	local t
	for t in "$@"; do
		command -v "$t" >/dev/null 2>&1 || return 1
	done
	return 0
}

_record() {
	local status="$1"
	local name="$2"
	local detail="${3-}"
	local mark
	case "$status" in
	pass)
		mark="${GREEN}PASS${RESET}"
		CHECKS_PASSED=$((CHECKS_PASSED + 1))
		;;
	fail)
		mark="${RED}FAIL${RESET}"
		CHECKS_FAILED=$((CHECKS_FAILED + 1))
		;;
	skip)
		mark="${YELLOW}SKIP${RESET}"
		CHECKS_SKIPPED=$((CHECKS_SKIPPED + 1))
		;;
	esac
	if [ -n "$detail" ]; then
		CHECKS_RESULTS[${#CHECKS_RESULTS[@]}]="${mark}  ${name} ${DIM}— ${detail}${RESET}"
	else
		CHECKS_RESULTS[${#CHECKS_RESULTS[@]}]="${mark}  ${name}"
	fi
}

check_pass() { _record "pass" "$1" "${2-}"; }
check_fail() { _record "fail" "$1" "${2-}"; }
check_skip() { _record "skip" "$1" "${2-}"; }

# check NAME STATUS [DETAIL] — STATUS 0 is pass, nonzero is fail.
check() {
	if [ "$2" -eq 0 ]; then
		_record "pass" "$1" "${3-}"
	else
		_record "fail" "$1" "${3-}"
	fi
}

report_and_exit() {
	local title="$1"
	echo
	echo "== ${title} =="
	local i=0
	local n=${#CHECKS_RESULTS[@]}
	while [ "$i" -lt "$n" ]; do
		echo "  ${CHECKS_RESULTS[$i]}"
		i=$((i + 1))
	done
	local total=$((CHECKS_PASSED + CHECKS_FAILED + CHECKS_SKIPPED))
	if [ "$CHECKS_FAILED" -eq 0 ]; then
		echo "${GREEN}${CHECKS_PASSED}/${total} passed${RESET}${CHECKS_SKIPPED:+ (${YELLOW}${CHECKS_SKIPPED} skipped${RESET})}"
		exit 0
	else
		echo "${RED}${CHECKS_FAILED} of ${total} checks failed${RESET}${CHECKS_SKIPPED:+ (${YELLOW}${CHECKS_SKIPPED} skipped${RESET})}"
		exit 1
	fi
}

# Capture output of a command and its exit code.
# Usage: run_cmd VAR_STDOUT VAR_STDERR VAR_CODE -- cmd args...
run_cmd() {
	local out_var="$1"
	local err_var="$2"
	local code_var="$3"
	shift 3
	[ "$1" = "--" ] && shift
	local tmp_out tmp_err code
	tmp_out="$(mktemp)"
	tmp_err="$(mktemp)"
	"$@" >"$tmp_out" 2>"$tmp_err"
	code=$?
	eval "$out_var=\$(cat \"\$tmp_out\")"
	eval "$err_var=\$(cat \"\$tmp_err\")"
	eval "$code_var=$code"
	rm -f "$tmp_out" "$tmp_err"
}

# Read a string value from a TOML file via a dotted path, e.g. "project.name"
# or "tool.coverage.report.fail_under". Prints the value or empty on miss.
toml_get() {
	local file="$1"
	local path="$2"
	python3 - "$file" "$path" <<'PY' 2>/dev/null
import sys, tomllib, json
path = sys.argv[2].split(".")
with open(sys.argv[1], "rb") as fh:
    data = tomllib.load(fh)
for part in path:
    if isinstance(data, dict) and part in data:
        data = data[part]
    else:
        sys.exit(0)
if isinstance(data, (str, int, float, bool)):
    print(data)
else:
    print(json.dumps(data))
PY
}

# Check an exact pin (==X.Y.Z) of a package within either [project.dependencies]
# or [dependency-groups.<group>]. Prints "exact:VERSION", "range:SPEC", or
# empty if missing.
pep508_pin_state() {
	local file="$1"
	local pkg="$2"
	python3 - "$file" "$pkg" <<'PY' 2>/dev/null
import sys, tomllib, re
with open(sys.argv[1], "rb") as fh:
    data = tomllib.load(fh)
pkg = sys.argv[2].lower()
groups = []
groups.append(data.get("project", {}).get("dependencies", []) or [])
for g, deps in (data.get("dependency-groups") or {}).items():
    groups.append(deps or [])
seen = None
for deps in groups:
    for spec in deps:
        m = re.match(r"^([A-Za-z0-9_.\-\[\]]+)\s*([=<>!~].*)?$", spec)
        if not m:
            continue
        name = m.group(1).split("[")[0].lower()
        if name == pkg:
            constraint = (m.group(2) or "").strip()
            seen = constraint
            break
    if seen is not None:
        break
if seen is None:
    sys.exit(0)
m = re.match(r"^==\s*([0-9A-Za-z.\-+]+)$", seen)
if m:
    print(f"exact:{m.group(1)}")
else:
    print(f"range:{seen}")
PY
}

# Read a top-level YAML scalar by dotted path. Returns first match only.
# Implementation: grep + awk; not a full YAML parser. Adequate for
# `version`, `info.version`, `cli.version` style lookups.
yaml_get_scalar() {
	local file="$1"
	local key="$2"
	awk -v key="$key" '
    BEGIN { split(key, parts, "."); depth = 1; want = parts[depth] }
    /^[[:space:]]*#/ { next }
    {
      line = $0
      sub(/[[:space:]]*#.*$/, "", line)
      if (line ~ "^[[:space:]]*" want "[[:space:]]*:[[:space:]]*[^[:space:]]") {
        sub("^[^:]*:[[:space:]]*", "", line)
        gsub(/^"|"$/, "", line)
        gsub(/^'\''|'\''$/, "", line)
        print line
        exit
      }
      if (line ~ "^[[:space:]]*" want "[[:space:]]*:[[:space:]]*$") {
        depth++
        if (depth in parts) want = parts[depth]
        else exit
      }
    }
  ' "$file" 2>/dev/null
}
