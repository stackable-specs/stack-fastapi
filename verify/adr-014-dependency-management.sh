#!/usr/bin/env bash
# Verify ADR-014 — Adopt Dependency Management Policy.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

for f in renovate.json .github/CODEOWNERS uv.lock; do
	if [ -f "$f" ]; then
		check_pass "$f present"
	else
		check_fail "$f present" "missing"
	fi
done

# Every dep in [project.dependencies] and every entry in [dependency-groups]
# should be exact-pinned (==X.Y.Z), per dependency-management rule 4 and the
# stack's chosen pin-strategy for an application.
loose="$(
	python3 - pyproject.toml <<'PY' 2>/dev/null
import sys, tomllib, re
with open(sys.argv[1], "rb") as fh:
    data = tomllib.load(fh)
loose = []
def check(group, deps):
    for spec in deps or []:
        m = re.match(r"^([A-Za-z0-9_.\-\[\]]+)\s*([=<>!~].*)?$", spec)
        if not m:
            continue
        constraint = (m.group(2) or "").strip()
        if not constraint.startswith("=="):
            loose.append(f"{group}:{spec}")
check("project.dependencies", data.get("project", {}).get("dependencies"))
for g, deps in (data.get("dependency-groups") or {}).items():
    check(f"dependency-groups.{g}", deps)
print("\n".join(loose))
PY
)"
if [ -z "$loose" ]; then
	check_pass "every direct dep exact-pinned (==X.Y.Z)"
else
	check_fail "every direct dep exact-pinned (==X.Y.Z)" "$(echo "$loose" | head -3 | tr '\n' ' | ')"
fi

if have_tools jq; then
	if jq -e '.extends or .packageRules' renovate.json >/dev/null 2>&1; then
		check_pass "renovate.json has extends/packageRules block"
	else
		check_fail "renovate.json has extends/packageRules block"
	fi
else
	if grep -q '"extends"' renovate.json 2>/dev/null; then
		check_pass "renovate.json has extends block"
	else
		check_fail "renovate.json has extends block" 'no "extends" key'
	fi
fi

if [ -s .github/CODEOWNERS ]; then
	check_pass ".github/CODEOWNERS non-empty"
else
	check_fail ".github/CODEOWNERS non-empty" "empty file"
fi

report_and_exit "ADR-014 — Dependency management"
