---
id: uv
layer: platform
extends:
  - python
---

# uv (Python Project and Toolchain Manager)

## Purpose

uv is an all-in-one Python toolchain: it replaces pip, pip-tools, pipx, Poetry, pyenv, virtualenv, and twine with a single Rust-implemented binary, and it owns the project's interpreter, virtual environment, lockfile, dependency resolution, tool execution, build, and publish workflow. Projects that adopt uv only realize its reproducibility and speed wins when they commit fully — mixing Poetry next to `uv add`, hand-editing `requirements.txt` while `uv.lock` exists, or letting developers run `python` directly against the project's `.venv` reintroduces exactly the drift uv exists to eliminate. This spec pins uv as the single project manager, names which uv subcommand owns each workflow, and forbids the legacy parallel tools so "managed by uv" is a real constraint and `uv sync --locked` is a trustworthy gate.

## References

- **spec** `python` — language-layer Python spec that this refines
- **external** `https://docs.astral.sh/uv/` — uv documentation
- **external** `https://docs.astral.sh/uv/concepts/projects/sync/` — `uv sync` and `uv lock` reference
- **external** `https://docs.astral.sh/uv/concepts/projects/dependencies/` — dependency groups and dev dependencies
- **external** `https://docs.astral.sh/uv/concepts/python-versions/` — Python version discovery and pinning
- **external** `https://docs.astral.sh/uv/guides/tools/` — `uv tool` and `uvx`
- **external** `https://docs.astral.sh/uv/guides/package/` — building and publishing with uv
- **external** `https://docs.astral.sh/uv/guides/integration/github/` — uv in GitHub Actions
- **external** `https://peps.python.org/pep-0735/` — PEP 735: Dependency Groups
- **external** `https://github.com/astral-sh/uv` — uv source repository
- **external** `https://github.com/astral-sh/setup-uv` — official setup-uv GitHub Action

## Rules

1. Pin the uv version used to install dependencies (e.g. `astral-sh/setup-uv` with an explicit `version:` on GitHub Actions, or a versioned install script); do not run an unpinned `curl | sh` or `pip install uv` in CI.
2. Manage project metadata and dependencies in `pyproject.toml`; do not maintain a hand-edited `requirements.txt` as the source of truth for a uv-managed project.
3. Add, upgrade, and remove dependencies with `uv add`, `uv lock --upgrade-package <name>`, and `uv remove`; do not edit `[project.dependencies]` by hand without running `uv lock` afterward.
4. Commit `uv.lock` to the repository alongside `pyproject.toml`; do not add it to `.gitignore`.
5. Declare development, lint, and test tooling under PEP 735 `[dependency-groups]` (added via `uv add --dev` or `uv add --group <name>`); do not declare them under `[project.optional-dependencies]` and do not use the legacy `[tool.uv.dev-dependencies]` field for new groups.
6. Pin the project's Python interpreter by committing a `.python-version` file generated with `uv python pin`.
7. Declare the supported Python range in `pyproject.toml` `requires-python` and ensure the value in `.python-version` satisfies it. (refs: python)
8. Run application code, scripts, and tests with `uv run <command>`; do not invoke `.venv/bin/python` or a system `python` directly against the project.
9. Install dependencies in CI with `uv sync --locked` (adding `--all-extras`, `--group <name>`, or `--dev` as needed) so the job fails when `uv.lock` does not match `pyproject.toml`; do not run `uv sync` without `--locked` on CI agents.
10. Run project-aware tools (e.g. `pytest`, `mypy`, `ruff` against the project) with `uv run` so they resolve against the project's environment; do not invoke them through `uvx` for project work.
11. Run user-wide CLI tools that do not depend on the current project with `uv tool install` (persistent) or `uvx` (ephemeral); do not `pip install` tools into the project's `.venv` or the system Python.
12. Do not add Poetry, Hatch (as a workflow tool), pipenv, pip-tools, pipx, pyenv, or `virtualenv` as parallel workflows in a uv-managed project; use the uv equivalent (`uv lock`, `uv build`, `uv tool`, `uv python`, `uv venv`).
13. Build distributable artifacts with `uv build` into the default `dist/` directory; do not invoke `python -m build`, `setup.py sdist`, or `flit build` against a uv-managed project.
14. Run `uv build --no-sources` before publishing so the package is verified to build without `[tool.uv.sources]` overrides.
15. Publish packages with `uv publish` from CI using PyPI Trusted Publishers (OIDC); do not publish from a developer laptop and do not commit long-lived registry tokens to the repository.
16. Cache uv's download cache in CI keyed on `uv.lock` (e.g. `astral-sh/setup-uv` with `enable-cache: true`) and run `uv cache prune --ci` before the cache is persisted; do not reinstall from an empty cache on every CI job.
17. Do not commit the project's `.venv/` directory.
