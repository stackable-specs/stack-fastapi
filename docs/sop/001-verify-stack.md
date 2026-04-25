# SOP-001: Verify a stack end-to-end

## What this SOP is

A layered-specs stack is a set of decisions and rules across nine layers. Verifying the stack means proving — on a clean checkout — that every layer's tooling resolves, every spec's gate runs, and the artifacts the stack ships actually start, accept traffic, and meet the contracts the BDRs and OAD declare.

The procedure below is layer-shaped, not tool-shaped. Each gate is named after the layer question it answers; the concrete command for *this* stack is shown as an example. Run the same gates against any other stack by substituting the stack's chosen tools.

## When to run this SOP

- After scaffolding a stack from its ADRs (initial materialization).
- After upgrading any pinned tool: the lockfile-aware resolver, the language runtime, the framework, the container base image, the lint runner, the docs generator.
- After an automated dependency-update batch lands on `main`.
- Before cutting a release tag.
- Whenever someone reports "the local setup is broken."

The goal is to confirm every ADR-materialized artifact still works — not to debug a specific failure. If a step fails, follow *Known failure modes* to diagnose, then re-run from the failing step.

## Prerequisites

Read the stack's [`docs/adr/README.md`](../adr/README.md) and the layered specs it cites; the prerequisite tools fall out of the language, platform, delivery, and quality layers.

For *this* stack (python-uv):

| Tool | Version | Layer / spec |
| --- | --- | --- |
| uv | ≥ 0.4.27 | platform/uv (PEP 735 `[dependency-groups]` support; older uv silently drops them) |
| Python | matches `.python-version` | language/python |
| Docker | 23+ (BuildKit) | delivery/docker, delivery/docker-compose, quality/integration-testing |
| Trunk CLI | as pinned in `.trunk/trunk.yaml` | quality/trunk-code-quality |
| Node | matches CI | practices/conventional-commits (commitlint), interface/openapi (Spectral) |

Run from the stack root.

## Procedure

Each gate names *what it verifies* (which layer-spec rule), then shows the concrete command for this stack. Stop on first failure; do not skip ahead.

### 1. Lockfile resolves (platform layer)

**Verifies:** the dependency graph the stack declares actually resolves and matches the lockfile (uv rule 9; in other stacks: `pnpm-lock.yaml`, `Cargo.lock`, `go.sum`).

```bash
uv lock
```

**Pass:** `Resolved <N> packages` matches the expected count for runtime + every dev / test / docs / release group declared in the manifest. A suspiciously low N usually means the resolver silently dropped a group — check resolver version.

### 2. Reproducible environment from lockfile (platform layer)

**Verifies:** a clean checkout produces the same environment CI and production use.

```bash
uv sync --locked --all-groups
```

**Pass:** environment installed; the `--locked` flag fails if manifest and lockfile disagree.

### 3. Style + import order pass (language layer)

**Verifies:** the language-layer formatting and lint rules (in this stack: ruff format + ruff E/F/I/UP/B/SIM rules per language/python rules 5–7).

```bash
uv run ruff check .
uv run ruff format --check .
```

**Pass:** lint clean; formatter reports no diffs.

### 4. Strict type check passes (language layer)

**Verifies:** every public function carries type hints and the strict checker has no diagnostics (language/python rule 12).

```bash
uv run mypy
```

**Pass:** `Success: no issues found`.

### 5. Unit + property tests pass with coverage (quality layer)

**Verifies:** unit-testing rules 5/12 (assertions on observable behavior, full suite on every PR) and property-based-testing rule 20 (PBT runs in CI).

```bash
uv run pytest tests/unit tests/property --cov --cov-fail-under=80
```

**Pass:** all tests pass; coverage ≥ the per-stack floor (this stack: 80%).

### 6. Orchestration config validates (delivery layer)

**Verifies:** the multi-container or deployment config the stack ships parses (docker-compose rule 25; in K8s stacks: `kubeconform`, `kustomize build | kubectl apply --dry-run=client`).

```bash
docker compose -f compose.yaml -f compose.override.yaml config --quiet
```

**Pass:** exit 0. Warnings about unset interpolation variables are expected when `.env` is absent.

### 7. API reference docs build clean (presentation layer)

**Verifies:** docstrings exist on the declared public surface and cross-references resolve (pdoc rule 16; in TS stacks: TypeDoc with `treatValidationWarningsAsErrors`).

```bash
uv run pdoc --docformat google --output-directory _docs-check app
rm -rf _docs-check
```

**Pass:** exit 0 with no warnings.

### 8. Interface contract export matches the committed OAD (interface layer)

**Verifies:** the implementation produces the OpenAPI Description committed to the repo (openapi rule 4; in gRPC stacks: regenerate `.pb` from `.proto` and confirm no diff; in GraphQL: `graphql-inspector diff`).

```bash
uv run python -c "import json; from app.main import create_app; print(json.dumps(create_app().openapi(), indent=2))" > openapi.generated.json
```

**Pass:** the generated artifact contains every operation ID listed in the hand-authored OAD. Diff with the OAD's breaking-change tool (`oasdiff` for OpenAPI) when in doubt.

### 9. Integration tests pass against real dependencies (quality layer)

**Verifies:** integration-testing rules 1–11 (real out-of-process collaborators via testcontainers, full suite on every PR).

```bash
docker info >/dev/null    # confirm daemon is up
uv run pytest tests/integration -m integration
```

**Pass:** all tests pass; the test framework brings up and tears down real containers.

### 10. Production artifact builds and the local topology starts (delivery layer)

**Verifies:** docker rules 1–14 (multi-stage Dockerfile, BuildKit, non-root, healthcheck) and docker-compose rules 1–25 (Compose stands the topology up the same way locally and in CI).

```bash
echo "changeme" > secrets/postgres_password && chmod 600 secrets/postgres_password
cp .env.example .env
docker compose up --build --detach
until [ "$(docker inspect python-uv-api-1 --format '{{.State.Health.Status}}')" = "healthy" ]; do sleep 2; done
docker compose ps
```

**Pass:** every long-running service reports `(healthy)`. In other stacks, substitute the orchestrator's readiness probe (`kubectl wait --for=condition=Ready`).

### 11. Smoke-test the documented public surface (interface + practices layer)

**Verifies:** every BDR's acceptance scenarios pass against the running artifact (bdr rule 9: Given/When/Then scenarios drop directly into smoke tests).

For each BDR in `docs/bdr/`, exercise its scenarios. For *this* stack, BDR-001 covers `POST /v1/greetings`:

```bash
curl -s http://127.0.0.1:8000/health
curl -s -X POST http://127.0.0.1:8000/v1/greetings \
  -H "Content-Type: application/json" -d '{"name":"Ada"}'
curl -s -X POST http://127.0.0.1:8000/v1/greetings \
  -H "Content-Type: application/json" -d '{"name":""}' \
  -w "\nstatus=%{http_code} ct=%{content_type}\n"
```

**Pass:** every documented scenario produces the response its BDR specifies — including unhappy paths, with the error contract the interface spec requires (RFC 9457 Problem Details, here).

### 12. Tear down + clean local secrets (security layer)

**Verifies:** no real or placeholder secret remains on disk after the run.

```bash
docker compose down --volumes
rm -f .env secrets/postgres_password openapi.generated.json
rm -rf _docs-check
```

**Pass:** containers, volumes, and locally-generated secret material are gone; only committed scaffolding remains in `secrets/`.

### 13. Unified lint runner passes (quality layer)

**Verifies:** trunk-code-quality rule 10 — every linter the stack enables runs to completion against the same versions CI uses. In other stacks substitute the unified runner (megalinter, pre-commit-managed hooks, etc.).

```bash
trunk check --all --no-progress
```

**Pass:** `✔ No issues`.

## Sign-off checklist

All thirteen gates green:

- [ ] Lockfile resolves all groups
- [ ] Environment syncs from lockfile (`--locked` / `--frozen`)
- [ ] Style + import order clean
- [ ] Strict type check clean
- [ ] Unit + property tests pass at ≥ coverage floor
- [ ] Orchestration config parses
- [ ] Reference docs build with no warnings
- [ ] Interface contract export matches the committed contract
- [ ] Integration tests pass against real containers
- [ ] Production artifact builds; local topology reports healthy
- [ ] Every BDR's smoke scenarios produce the contracted response
- [ ] Local secret material removed after the run
- [ ] Unified lint runner clean

## Known failure modes

Each entry is a real failure observed during initial materialization. Apply the fix, re-run from the failing step.

### General — apply to any stack

#### Resolver silently produces a runtime-only lockfile

**Cause:** the lockfile resolver in use predates the manifest's dependency-group format (PEP 735 for Python, similar histories for other ecosystems).

**Fix:** upgrade the resolver to the version the stack pins. If the global install is managed by a package manager that does not support self-update, fetch the pinned standalone binary into a temp location and use it for the run rather than upgrading the global install:

```bash
# python-uv example
mkdir -p /tmp/uv-pinned
curl -fsSL "https://github.com/astral-sh/uv/releases/download/0.5.11/uv-aarch64-apple-darwin.tar.gz" \
  | tar -xz -C /tmp/uv-pinned --strip-components=1
/tmp/uv-pinned/uv --version
```

#### Type checker fails on a third-party module without stubs

**Cause:** the dependency does not ship a `py.typed` marker (or its language-level equivalent — `.d.ts`, `pyi` stubs).

**Fix:** add a scoped suppression in the type-checker config (mypy `[[tool.mypy.overrides]]`, TS `paths` / declaration shims). Do not lower the global strictness.

#### Container restart loops with `ModuleNotFoundError` for the project's own package

**Cause:** the dependency manager installed the project in editable mode pointing at the build-stage path; runtime stage uses a different path so the editable entry resolves to nowhere.

**Fix:** align `WORKDIR` between builder and runtime stages so the editable-install path resolves identically. Alternatively, build a wheel and install it non-editable in the runtime stage.

#### Container restart loops with "module not found" for runtime deps installed in a venv

**Cause:** the runtime image's interpreter does not match the version the venv was built against. Distroless and stripped runtime images often pin a specific interpreter version that diverges from the builder's.

**Fix:** match interpreter versions across stages, or accept a slightly larger `*-slim` runtime image (still allowed by docker rule 4). Document the choice in an ADR if the stack rejects distroless explicitly.

#### Build fails reading a metadata file the manifest references

**Cause:** the Dockerfile installs the project before copying every file the build backend needs (typically `README.md`, `LICENSE`).

**Fix:** copy the metadata files alongside `pyproject.toml` / `package.json` *before* the install step that resolves the local project.

#### Unified lint runner's bundled type checker fails on every file

**Cause:** the lint runner sandboxes each tool in its own runtime; the sandboxed type checker cannot see the project's venv, so every framework import fails.

**Fix:** disable the sandboxed type checker in the lint runner; gate type-checking through the project's own venv (`uv run mypy`, `pnpm tsc`, etc.). Document why in the runner config.

#### Unified lint runner's YAML linter fights the formatter

**Cause:** the formatter (prettier, dprint) emits inline arrays and longer lines than the YAML linter's default thresholds allow.

**Fix:** add a project YAML-linter config that matches the formatter's output (line length, brace spacing). Keep the two configs in sync as the formatter changes.

#### Unified lint runner's policy scanner flags the reference OAD

**Cause:** policy scanners (checkov, conftest, regula) ship default rules that assume every API has authentication and every array has `maxItems`. Reference scaffolds with no auth fail those rules trivially.

**Fix:** scope-ignore the policy scanner on the OAD file *and* add a follow-up BDR to introduce the missing surface (auth, pagination limits) before the stack ships a real service.

### python-uv specific

#### Integration test errors with `psycopg.ProgrammingError: missing "=" after "postgresql+psycopg2://..."`

**Cause:** testcontainers' `PostgresContainer` defaults `driver="psycopg2"`, producing a SQLAlchemy-style URL psycopg 3 rejects.

**Fix:** pass `driver=None` to `PostgresContainer` so the DSN is plain `postgresql://`. The fixture in `tests/integration/conftest.py` already does this.

## References

- [docs/adr/README.md](../adr/README.md) — every ADR materialized in this stack.
- [docs/specs/](../specs) — the layered specs the ADRs reference; each gate above cites the spec rule it verifies.
- [Makefile](../../Makefile) — `make check` runs the local-only gates; `make up` covers the topology gates.
- [.github/workflows/ci.yml](../../.github/workflows/ci.yml) — the CI mirror of this SOP.
