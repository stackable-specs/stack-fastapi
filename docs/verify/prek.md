# Verification: prek

Rule-by-rule conformance report for `docs/specs/quality/prek.md` adopted via [ADR-018](../adr/018-adopt-prek-as-hook-runner.md).

| # | Rule | Status | Evidence |
| - | --- | --- | --- |
| 1 | Single `prek.toml` (or `.pre-commit-config.yaml`) at repo root | **Pass** | `prek.toml` at stack root; no parallel `.pre-commit-config.yaml`. |
| 2 | Pin the prek CLI version on dev machines and CI agents | **Pass** | CI: `.github/workflows/ci.yml` `prek` job runs `uv tool install prek==0.0.6`. `Makefile` `prek-install` target documents the local install path. |
| 3 | Pin every remote `rev:` to a tag or commit SHA (no branch names) | **Pass** | `prek.toml`: `pre-commit/pre-commit-hooks@v5.0.0`, `gitleaks@v8.21.2`. No branch refs. |
| 4 | Run `prek install` once per repo; documented in onboarding | **Pass** | `Makefile` `prek-install` target installs `pre-commit`, `commit-msg`, `pre-push` hook types. README quickstart step 4. |
| 5 | At least one formatter/linter hook per language present | **Pass** | Python: `ruff-check`, `ruff-format`, `mypy`. Other languages reach Trunk (yamllint, markdownlint, hadolint, shellcheck, prettier) via the `trunk-check` local hook. |
| 6 | Secret-detection hook configured | **Pass** | `prek.toml`: `gitleaks@v8.21.2` at `pre-commit`. Trunk's gitleaks/trufflehog also run via the `trunk-check` hook. |
| 7 | Baseline file-hygiene hooks from `pre-commit/pre-commit-hooks` | **Pass** | `prek.toml`: `trailing-whitespace`, `end-of-file-fixer`, `check-yaml`, `check-json`, `check-toml`, `check-merge-conflict`, `check-added-large-files`. Spec asks for the first six; `check-toml` is an additive extra; `check-added-large-files` adds the `--maxkb=512` cap. |
| 8 | Lockfile-pinned tools wired via `repo: local` (no double-pinning) | **Pass** | `prek.toml` `repo: local` runs `uv run ruff check`, `uv run ruff format --check`, `uv run mypy`; the versions live only in `pyproject.toml` `[dependency-groups].dev` / `uv.lock`. |
| 9 | Scope each hook with `files:` / `exclude:` patterns | **Pass** | Python-only hooks set `types = ["python"]`. File-hygiene hooks use the upstream-default scopes from `pre-commit/pre-commit-hooks`. Trunk's own scoping (in `.trunk/trunk.yaml` `lint.ignore`) governs the `trunk-check` invocation. |
| 10 | Set `stages:` explicitly on every hook | **Pass** | Every hook in `prek.toml` declares `stages = [...]` — `pre-commit` for fast checks, `pre-push` for `mypy` and `wheel-build`, `commit-msg` for `commitlint`. |
| 11 | Mirror the same config in CI; failure is a build failure | **Pass** | `.github/workflows/ci.yml` `prek` job runs `prek run --all-files --show-diff-on-failure`. Default GitHub Actions exit-code semantics treat a non-zero exit as a build failure. |
| 12 | Scheduled `prek auto-update --check` opens a PR | **Pass** | `.github/workflows/prek-autoupdate.yml` — weekly Mondays 06:00 UTC; opens a PR via `peter-evans/create-pull-request@v7`. `Makefile` `prek-update` target for ad-hoc local runs. |
| 13 | Cache prek hook envs in CI keyed on the config file | **Pass** | `.github/workflows/ci.yml` `prek` job uses `actions/cache@v4` keyed on `hashFiles('prek.toml')` over `~/.cache/prek`. |
| 14 | No `git commit --no-verify` to land work | **Pass** (policy) | README "Conventions for contributors" forbids `--no-verify` and points at `prek` rule 14 + `trunk-code-quality` rule 12. Enforcement is review-time, as the spec acknowledges. |
| 15 | Suppress findings inline at the violation site, not via broad excludes | **Pass** (policy) | `prek.toml` ships no broad `exclude:` patterns. `.trunk/trunk.yaml` `lint.ignore` contains only documented narrow exclusions. README convention covers the inline-suppression rule. |
| 16 | Single hook runner — choose prek/pre-commit/Trunk and remove the others | **Pass** | `.trunk/trunk.yaml` `actions.enabled` no longer lists `trunk-check-pre-push` or `trunk-fmt-pre-commit`; comment in the file cites ADR-018 + prek rule 16. Trunk now runs only as a tool invoked by prek's `trunk-check` / `trunk-fmt` local hooks. |
| 17 | Conventional Commits enforcement as a `commit-msg` prek hook (no parallel husky) | **Pass** | `prek.toml` `commitlint` hook at `stages = ["commit-msg"]` runs `npx --no -- commitlint --edit` against `.commitlintrc.yaml`. No husky/lefthook installation present. The CI `commitlint` job remains because prek's `commit-msg` stage doesn't replay PR commits in `--all-files` mode. |

## Open follow-ups

None as of this verification run. The spec is fully covered; ADR-018 status is `Accepted`.

## How this report was produced

- File-existence and content checks against the stack as of this commit.
- Cross-reference of every `prek.toml` / `Makefile` / CI workflow change against the numbered rules in `docs/specs/quality/prek.md`.
- Re-run on every change to `prek.toml`, `.trunk/trunk.yaml`, `.github/workflows/ci.yml`, `.github/workflows/prek-autoupdate.yml`, or the source spec.
