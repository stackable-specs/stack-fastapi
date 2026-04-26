# python-uv stack

Reference implementation of the python-uv stack. Every artifact in this directory exists because of an Architectural Decision Record under [`docs/adr/`](docs/adr/README.md). See [`docs/specs/`](docs/specs/) for the layered specs the ADRs reference.

## ADR → artifact map

| ADR                                                                                 | Materialized as                                                                          |
| ----------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| [ADR-001](docs/adr/001-adopt-python-as-language.md) Python                          | `pyproject.toml` (`requires-python`), `.python-version`, `src/app/`                      |
| [ADR-002](docs/adr/002-adopt-uv-as-toolchain.md) uv                                 | `pyproject.toml` `[dependency-groups]`, `uv.lock` (generated), `Makefile` `uv run` calls |
| [ADR-003](docs/adr/003-adopt-fastapi-as-http-framework.md) FastAPI                  | `src/app/main.py`, `src/app/routers/`, `src/app/settings.py`, `src/app/errors.py`        |
| [ADR-004](docs/adr/004-adopt-openapi-as-api-contract.md) OpenAPI                    | `openapi.yaml`, `make openapi-export`, CI `oasdiff` step                                 |
| [ADR-005](docs/adr/005-adopt-madr-for-architectural-decisions.md) MADR              | `docs/adr/`                                                                              |
| [ADR-006](docs/adr/006-adopt-bdr-for-behavior-records.md) BDR                       | `docs/bdr/`                                                                              |
| [ADR-007](docs/adr/007-adopt-conventional-commits.md) Conventional Commits          | `.commitlintrc.yaml`, `.gitmessage`, CI commitlint job                                   |
| [ADR-008](docs/adr/008-adopt-tdd-cycle.md) TDD                                      | `tests/` layout — failing test first, commit at green                                    |
| [ADR-009](docs/adr/009-adopt-unit-testing-discipline.md) Unit testing               | `tests/unit/`                                                                            |
| [ADR-010](docs/adr/010-adopt-integration-testing-discipline.md) Integration testing | `tests/integration/` (testcontainers Postgres)                                           |
| [ADR-011](docs/adr/011-adopt-property-based-testing.md) Property-based testing      | `tests/property/` (Hypothesis)                                                           |
| [ADR-012](docs/adr/012-adopt-trunk-code-quality.md) Trunk Code Quality              | `.trunk/trunk.yaml`                                                                      |
| [ADR-013](docs/adr/013-adopt-sbom-for-released-artifacts.md) SBOM                   | CI `sbom` job (CycloneDX)                                                                |
| [ADR-014](docs/adr/014-adopt-dependency-management-policy.md) Dependency policy     | `renovate.json`, `.github/CODEOWNERS`                                                    |
| [ADR-015](docs/adr/015-adopt-docker-as-image-format.md) Docker                      | `Dockerfile`, `.dockerignore`                                                            |
| [ADR-016](docs/adr/016-adopt-docker-compose-for-local-and-single-host.md) Compose   | `compose.yaml`, `compose.override.yaml`, `.env.example`                                  |
| [ADR-017](docs/adr/017-adopt-pdoc-for-api-reference-docs.md) pdoc                   | `make docs`, CI `docs` job                                                               |
| [ADR-018](docs/adr/018-adopt-prek-as-hook-runner.md) prek                           | `prek.toml`, `make prek-install`, CI `prek` job, `.github/workflows/prek-autoupdate.yml` |
| [ADR-019](docs/adr/019-adopt-smoke-testing-as-pipeline-gate.md) Smoke testing       | `tests/smoke/`, `make smoke`, CI `smoke` job, `.github/workflows/smoke-postdeploy.yml`   |
| [ADR-020](docs/adr/020-adopt-opentelemetry-for-instrumentation.md) OpenTelemetry    | `src/app/observability.py`, `OTEL_*` env vars, `opentelemetry-*` deps                    |
| [ADR-021](docs/adr/021-adopt-openobserve-as-otlp-backend.md) OpenObserve            | `compose.yaml` `openobserve` service, `docs/observability/`                              |

## Quickstart

```bash
# 1. Install uv (pinned in CI, see docs/specs/platform/uv.md rule 1).
# 2. Sync the project environment from the lockfile.
uv sync --locked --all-groups

# 3. Pin Python interpreter (per .python-version).
uv python pin

# 4. Install git hooks (ADR-018; runs file hygiene, secret scan, ruff, trunk,
#    mypy, wheel build, commitlint at the right git stage).
make prek-install

# 5. Run the API locally (single worker, dev only — see fastapi rule 2 for prod).
make dev

# 6. Lint, type-check, test.
make check

# 7. Stand up local topology (API + Postgres) via Compose.
cp .env.example .env  # then fill in real values
make up
```

## Repository layout

```
.
├── .commitlintrc.yaml          # ADR-007
├── .dockerignore               # ADR-015
├── .env.example                # ADR-016
├── .github/
│   ├── CODEOWNERS              # ADR-014
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── workflows/ci.yml        # ADR-007/012/013/017
├── .gitignore
├── .gitmessage                 # ADR-007
├── .python-version             # ADR-001/002
├── .trunk/trunk.yaml           # ADR-012 (invoked from prek.toml per ADR-018)
├── prek.toml                   # ADR-018
├── Dockerfile                  # ADR-015
├── Makefile                    # entry points referenced by ADRs
├── compose.yaml                # ADR-016
├── compose.override.yaml       # ADR-016
├── docs/
│   ├── adr/                    # ADR-005
│   ├── bdr/                    # ADR-006
│   └── specs/                  # ADRs reference these specs
├── openapi.yaml                # ADR-004
├── pyproject.toml              # ADR-001/002
├── renovate.json               # ADR-014
├── src/app/                    # ADR-003
└── tests/                      # ADR-008..011
    ├── unit/
    ├── integration/
    └── property/
```

## Conventions for contributors

- Commits follow [Conventional Commits 1.0](docs/specs/practices/conventional-commits.md). Configure your editor with `git config commit.template .gitmessage`.
- Decisions live as ADRs in `docs/adr/`; behavior contracts live as BDRs in `docs/bdr/`. Open a PR with the new record before changing the system.
- `make check` is the local mirror of CI: format check, lint, type-check, unit + property tests, integration tests, OpenAPI lint, docs build.
- Never bypass the gate with `--no-verify` ([prek.md](docs/specs/quality/prek.md) rule 14, [trunk-code-quality.md](docs/specs/quality/trunk-code-quality.md) rule 12). If a finding is wrong, suppress it inline at the violation site with a citation.
