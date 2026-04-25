# ADR-018: Adopt prek as the Single Git-Hook Runner

## Status

Accepted

## Context and Problem Statement

The python-uv stack adopted Trunk Code Quality (ADR-012) and wired Trunk's own actions (`trunk-check-pre-push`, `trunk-fmt-pre-commit`) as the git-hook driver. That setup runs Trunk's tools well but leaves the rest of the gate (Conventional Commits via commitlint, secret scanning ownership, baseline file hygiene, the wheel build, language-native `uv run ruff` / `uv run mypy` from the project's own lockfile) split across separate mechanisms — and it surrenders hook ownership to a vendor-specific action set. The stack needs one orchestrator that owns the git-hook lifecycle, runs Trunk as one of its hooks, runs the things Trunk doesn't (`make build`, `commit-msg` linting, language-native tools pinned in `uv.lock`), and is itself pinned and reproducible across every developer machine and CI runner.

## Decision Drivers

- One orchestrator owning `pre-commit`, `pre-push`, and `commit-msg` git hooks (`specs/quality/prek.md` rule 16).
- Trunk Code Quality (ADR-012) remains the multi-tool lint wrapper but is invoked **as a hook**, not as the hook runner.
- Language-native tools pinned in `uv.lock` (ruff, mypy) are runnable through the hook framework without double-pinning (`prek` rule 8).
- Conventional Commits enforcement (ADR-007) collapses into a `commit-msg` hook rather than a parallel husky/lefthook install (`prek` rule 17).
- Stack tasks Trunk doesn't cover — the wheel build, the OpenAPI export — fit the `pre-push` and `manual` stages.
- Reproducibility: pinned `prek` CLI, pinned remote hook revs, mirrored in CI.

## Considered Options

- **prek (this ADR)** — Rust-implemented, drop-in pre-commit-compatible runner per `specs/quality/prek.md`. Owns hooks; Trunk runs as a `local` hook.
- **Keep Trunk's own actions as the hook driver** — status quo before this ADR; leaves commitlint, build, and uv-lockfile-pinned tools out of the hook lifecycle.
- **Adopt upstream `pre-commit`** — same compatible config, slower install, no compelling reason to prefer it now that prek is stable.
- **husky + lint-staged** — Node-centric, fragments configuration across `.husky/`, `package.json`, and the lint runner.
- **lefthook** — single-binary, capable, but smaller ecosystem and no built-in compatibility with the existing `.pre-commit-hooks.yaml` repo network.

## Decision Outcome

We will adopt prek as the single git-hook runner for the python-uv stack, governed by `specs/quality/prek.md`. prek owns `pre-commit`, `pre-push`, and `commit-msg` stages. Trunk Code Quality (ADR-012) is invoked as a `local` hook from prek (`trunk check`/`trunk fmt`), so the multi-tool lint surface still resolves through Trunk's pinned `trunk.yaml` while git-hook ownership consolidates under prek. Conventional Commits enforcement (ADR-007) becomes a `commit-msg` prek hook running the existing `.commitlintrc.yaml`. The wheel build (`make build`) runs as a `pre-push` hook so a malformed package can't be pushed. uv-lockfile-pinned `ruff` and `mypy` run via `uv run` in `repo: local` hooks so the lockfile stays the single source of truth for those tool versions (`prek` rule 8). Trunk's `trunk-check-pre-push` and `trunk-fmt-pre-commit` actions are removed from `.trunk/trunk.yaml` so two frameworks do not race for the same hooks (`prek` rule 16).

## Consequences

- Positive: one place to read the entire local gate (`prek.toml`); one command (`prek run --all-files`) reproduces it.
- Positive: `prek` rule 16's "single hook runner" is satisfied — Trunk is now a tool prek invokes, not a competing runner.
- Positive: Conventional Commits enforcement runs locally on every commit, not only in CI on PRs.
- Positive: language-native `ruff`/`mypy` no longer need a Trunk-shipped second copy at a different version — they run through `uv run` against `uv.lock`.
- Positive: `make build` running as a `pre-push` hook catches packaging breakage before it reaches CI.
- Negative: contributors must run `prek install` once after cloning; documented in the README quickstart.
- Negative: the CI `trunk` job is replaced by a `prek` job that transitively runs Trunk; reading CI logs requires understanding that Trunk now runs inside prek.
- Negative: prek is younger than upstream pre-commit; if a hook publisher ships an incompatible config, the temporary fall-back is `pre-commit run` against the same config file (the `prek` config is pre-commit-compatible).

## References

- [ADR-007](007-adopt-conventional-commits.md) — commit-msg hook this ADR formalizes
- [ADR-012](012-adopt-trunk-code-quality.md) — Trunk remains the lint runner; this ADR demotes Trunk's hook-driver role
- `docs/specs/quality/prek.md` — rules this ADR adopts
