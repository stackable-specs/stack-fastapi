---
id: pdoc
layer: presentation
extends:
  - python
---

# pdoc

## Purpose

pdoc converts a Python package's public objects and docstrings into navigable HTML reference documentation — but only when the package treats its docstrings as a contract, declares its public surface explicitly, and runs the generator as a CI gate. Left to defaults, pdoc happily renders whatever docstrings happen to exist (and silently omits the symbols that have none), accepts unresolved `[link]` cross-references, exposes every helper that does not start with an underscore as "public" API, and emits a "latest" docs site that drifts past the version on PyPI. Without `__all__` declarations, every importer treats every top-level name as load-bearing surface, so a refactor of an internal helper becomes a breaking change by default. Without a single chosen docstring format, the same rendered page mixes Google sections, NumPy sections, and bare reST directives, and parameter lists stop rendering at the first malformed block. This spec pins the pdoc invocation, the docstring format, the public-surface declaration mechanism (`__all__` plus underscore-prefixing), the deprecation lifecycle, the lint and validation gates that turn the build into a CI check, and the publish flow that ties a docs URL to a released package version, so the generated reference is a reliable contract instead of a snapshot of whatever the source happens to look like today.

## References

- **spec** `python` — language-layer Python spec this refines
- **external** `https://pdoc.dev/` — pdoc home
- **external** `https://pdoc.dev/docs/pdoc.html` — pdoc CLI and configuration reference
- **external** `https://google.github.io/styleguide/pyguide.html#38-comments-and-docstrings` — Google-style docstring guide
- **external** `https://numpydoc.readthedocs.io/en/latest/format.html` — NumPy docstring format
- **external** `https://peps.python.org/pep-0257/` — PEP 257 docstring conventions
- **external** `https://www.pydocstyle.org/` — pydocstyle (docstring linter)
- **external** `https://docs.astral.sh/ruff/rules/#pydocstyle-d` — Ruff `D` rules (pydocstyle in Ruff)
- **external** `https://semver.org/` — Semantic Versioning 2.0.0 (deprecation lifecycle context)

## Rules

1. Use pdoc as the canonical API reference generator for every published Python package; do not hand-maintain a parallel API reference that duplicates source docstrings.
2. Pin the pdoc version as an exact entry in the dev dependency group (no `^`, `~`, or unbounded `>=`) and upgrade deliberately via a dedicated PR. (refs: python)
3. Invoke pdoc from a single committed entry point — a `Makefile` target, `tox` env, `nox` session, or `uv run` script — that other tooling and CI call; do not document the build by pasting CLI flags into a README.
4. Pass an explicit list of import paths (the package modules to document) to pdoc; do not invoke pdoc against a directory and rely on filesystem walking to determine the module set.
5. Write the generated output to a build directory listed in `.gitignore` (e.g. `docs-site/api/`); do not commit generated HTML to source control.
6. Choose exactly one docstring format per package and pass it explicitly with `--docformat` (`google`, `numpy`, `restructuredtext`, or `markdown`); do not mix docstring formats within a package.
7. Declare each module's public surface with an `__all__` list; do not rely on the underscore-prefix convention alone to keep helpers out of the rendered reference.
8. Prefix every module-level helper, class, and function not in `__all__` with a single underscore; do not export an unprefixed name that is not part of the public API.
9. Document every public function, method, and class with a docstring whose first line is an imperative one-line summary, followed by a blank line and an extended description when needed. (refs: https://peps.python.org/pep-0257/)
10. Document parameters, return values, and raised exceptions in the chosen format's section style (Google `Args:`/`Returns:`/`Raises:`, NumPy `Parameters`/`Returns`/`Raises`, or reST `:param:`/`:returns:`/`:raises:`); do not leave a public function's parameters or return value undescribed.
11. Provide at least one runnable example — as a fenced ` ```python ` block or a `>>>` doctest — on every public function, class, and standalone type a consumer would call directly.
12. Mark deprecated public symbols with `warnings.warn(..., DeprecationWarning, stacklevel=2)` AND a `.. deprecated:: <version>` (reST), `Deprecated:` section (Google), or equivalent block in the docstring for at least one minor-release cycle before removal; do not delete a public symbol without first shipping it as deprecated.
13. Cross-reference other symbols with pdoc's link syntax (`` `package.module.Symbol` `` or `[Symbol][package.module.Symbol]`) so pdoc can resolve them; do not use bare prose names for cross-references that should resolve to a doc page.
14. Annotate every public function and method with PEP 484 type hints; do not duplicate type information in the docstring when the annotation already carries it.
15. Lint docstrings with Ruff's `D` rules (or `pydocstyle`) configured to the chosen convention (`pydocstyle.convention = "google" | "numpy" | "pep257"`) and treat violations as errors in CI.
16. Run pdoc in CI on every PR (e.g. `pdoc --output-directory _docs-check <modules>` discarded after the run) and fail the build on pdoc warnings such as unresolved cross-references or import errors; do not let pdoc warnings accumulate silently.
17. Pin the pdoc theme, custom templates, logo, and favicon paths in the build entry point and commit them to the repo; do not let the upstream default template version change implicitly between builds.
18. Use pdoc's local server (`pdoc <modules>`) for development preview only; do not expose `pdoc`'s live server as a production documentation host.
19. Publish the generated HTML to a stable URL (GitHub Pages, Read the Docs, S3 + CloudFront, or equivalent) on every release tag, with the URL path including the released package version; do not maintain a single "latest" docs site that drifts from the version a consumer actually installed.
20. Render mathematical notation only when needed and enable it explicitly via `--math`; do not enable optional renderers (`--math`, `--mermaid`) unconditionally on packages that do not use them.
