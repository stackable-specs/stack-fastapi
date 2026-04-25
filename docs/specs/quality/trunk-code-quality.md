---
id: trunk-code-quality
layer: quality
extends: []
---

# Trunk Code Quality

## Purpose

Multi-language repos accumulate a different config format, installed version, and invocation style for every linter, formatter, and scanner — so "lint the repo" resolves differently on each machine, in each CI job, and between every contributor. Trunk unifies that surface: one CLI, one pinned version of each tool, one `trunk.yaml` that reconciles them, one command (`trunk check`) to run them all. The payoff only shows up when every contributor and CI runner resolves the same versions, every language present has a tool enabled, bypasses (`--no-verify`, ad-hoc suppressions) are treated as defects rather than shortcuts, and the `trunk check` gate actually runs before merge. This spec pins the Trunk setup so `trunk check` passing on a PR is a coherent, reproducible statement about the whole repo instead of an artifact of whichever toolchain happened to be installed.

## References

- **external** `https://docs.trunk.io/code-quality/overview/initialize-trunk` — Initialize Trunk Code Quality
- **external** `https://docs.trunk.io/code-quality` — Trunk Code Quality overview
- **external** `https://docs.trunk.io/cli` — Trunk CLI reference
- **external** `https://github.com/trunk-io/trunk-action` — Trunk GitHub Action for CI
- **external** `https://docs.trunk.io/code-quality/linters/supported` — Supported linters, formatters, and scanners

## Rules

1. Initialize Trunk with `trunk init` and commit the generated `.trunk/trunk.yaml` so every contributor and CI agent resolves the same tool versions.
2. Pin the Trunk CLI version in `.trunk/trunk.yaml` under `cli.version`; do not leave it unset or floating.
3. Pin every enabled linter, formatter, and scanner in `.trunk/trunk.yaml` with an explicit `<name>@<version>`; do not reference `latest` or other floating tags.
4. Upgrade pinned versions via `trunk upgrade`; do not hand-edit versions in `.trunk/trunk.yaml` outside that flow.
5. Enable at least one linter or formatter for every language present in the repository (`eslint`, `prettier`, `ruff`, `black`, `gofmt`, `golangci-lint`, `shellcheck`, `hadolint`, etc. — pick per language).
6. Enable a secret-detection scanner (`gitleaks` or `trufflehog`) so every commit is scanned for credentials.
7. Enable `markdownlint` and `yamllint` (or equivalents) so documentation and config files are covered by the same gate as source code.
8. Keep each linter's rule configuration in that linter's native config file (`.eslintrc`, `ruff.toml`, `.prettierrc`, `.golangci.yml`, etc.); use `.trunk/configs/` only when a tool has no standard config location.
9. Install Trunk's git hooks via `trunk git-hooks install`; configure the pre-push hook to run `trunk check`.
10. Run `trunk check --ci` (or its documented CI equivalent) on every PR and treat any finding as a build failure.
11. Run a format check (`trunk fmt --check --all` or equivalent) in CI and fail the build on any unformatted file.
12. Do not bypass Trunk hooks with `git commit --no-verify` or `git push --no-verify`; fix the underlying finding or update the config deliberately.
13. Add Trunk's local cache directory (typically `.trunk/out/`) to `.gitignore`; do not commit Trunk-generated state or logs.
14. Suppress individual findings inline at the violation site with a comment citing the linter and rule id and a short reason; do not add broad `ignore` rules in `.trunk/trunk.yaml` for problems that should be fixed.
15. Do not let `trunk check` auto-apply fixes in CI; reserve `--fix` / auto-format behavior for local invocations and pre-commit hooks.
16. Upgrade the pinned linter set at a documented cadence using `trunk upgrade` and review the resulting diff as a regular change.
17. Install the Trunk CLI through the launcher script or a pinned binary on every developer machine and CI agent; do not rely on ambient, unversioned Trunk installations.
