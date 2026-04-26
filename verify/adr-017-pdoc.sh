#!/usr/bin/env bash
# Verify ADR-017 — Adopt pdoc for API Reference Documentation.
# shellcheck source=./lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$STACK_ROOT" || exit

state="$(pep508_pin_state pyproject.toml pdoc)"
case "$state" in
exact:*) check_pass "pdoc pinned exactly" "${state#exact:}" ;;
range:*) check_fail "pdoc pinned exactly" "loose: ${state#range:}" ;;
*) check_fail "pdoc pinned exactly" "not declared" ;;
esac

for tgt in docs docs-check; do
	if grep -Eq "^\.PHONY:[[:space:]]+$tgt|^$tgt:" Makefile 2>/dev/null; then
		check_pass "Makefile $tgt target present"
	else
		check_fail "Makefile $tgt target present" "missing"
	fi
done

if grep -Eq '^__all__[[:space:]]*=' src/app/__init__.py 2>/dev/null; then
	check_pass "__all__ declared in src/app/__init__.py"
else
	check_fail "__all__ declared in src/app/__init__.py" \
		"no __all__ — public surface is implicit (pdoc rule on declared surface)"
fi

if grep -q 'pdoc' .github/workflows/ci.yml 2>/dev/null; then
	check_pass "CI builds API docs as a gate"
else
	check_fail "CI builds API docs as a gate" "no pdoc step in .github/workflows/ci.yml"
fi

# Docstring convention pinned in ruff config so D-rules align with pdoc render.
conv="$(toml_get pyproject.toml tool.ruff.lint.pydocstyle.convention)"
if [ "$conv" = "google" ] || [ "$conv" = "numpy" ]; then
	check_pass "ruff pydocstyle convention pinned" "$conv"
else
	check_fail "ruff pydocstyle convention pinned" "actual: ${conv:-<missing>}"
fi

report_and_exit "ADR-017 — pdoc"
