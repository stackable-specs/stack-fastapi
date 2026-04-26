# Single committed entry point for project tasks (uv rule 8, pdoc rule 3).
.DEFAULT_GOAL := help
SHELL := /bin/bash

PYTHON_MODULES := app
APP_MODULE := app.main:app
DOCS_OUTPUT := docs-site/api

.PHONY: help
help: ## Show this help.
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

.PHONY: install
install: ## Sync the project venv from uv.lock (all groups).
	uv sync --locked --all-groups

.PHONY: lock
lock: ## Re-resolve uv.lock from pyproject.toml.
	uv lock

.PHONY: dev
dev: ## Run the API locally with hot reload (development only — fastapi rule 2).
	uv run uvicorn $(APP_MODULE) --reload --host 127.0.0.1 --port 8000

.PHONY: lint
lint: ## Run the full prek gate across all files (ADR-018).
	prek run --all-files --show-diff-on-failure

.PHONY: fmt
fmt: ## Format all files via trunk (invoked through prek for hook runs).
	trunk fmt --all

.PHONY: prek-install
prek-install: ## Install prek git hooks for this repo (ADR-018, prek rule 4).
	prek install --install-hooks
	prek install --hook-type commit-msg
	prek install --hook-type pre-push

.PHONY: prek-update
prek-update: ## Check for hook upgrades; opens a PR-ready diff (prek rule 12).
	prek auto-update --check

.PHONY: typecheck
typecheck: ## Run mypy in strict mode.
	uv run mypy

.PHONY: test
test: ## Run unit + property tests.
	uv run pytest tests/unit tests/property --cov

.PHONY: test-integration
test-integration: ## Run integration tests (requires Docker).
	uv run pytest tests/integration -m integration

.PHONY: smoke
smoke: ## Run smoke tests against $SMOKE_BASE_URL (default http://localhost:8000) — ADR-019.
	uv run pytest tests/smoke -m smoke --timeout=300

.PHONY: check
check: lint typecheck test docs-check ## Run the full local PR-mirror gate.

.PHONY: openapi-export
openapi-export: ## Dump the live FastAPI OAD to openapi.generated.json for diffing.
	uv run python -c "import json; from app.main import create_app; print(json.dumps(create_app().openapi(), indent=2))" > openapi.generated.json

.PHONY: docs
docs: ## Build the API reference with pdoc (pdoc rule 3).
	uv run pdoc --docformat google --output-directory $(DOCS_OUTPUT) $(PYTHON_MODULES)

.PHONY: docs-check
docs-check: ## Run pdoc as a CI gate; build then discard output (pdoc rule 16).
	uv run pdoc --docformat google --output-directory _docs-check $(PYTHON_MODULES)
	rm -rf _docs-check

.PHONY: docs-serve
docs-serve: ## Serve docs locally on http://localhost:8080 (development only — pdoc rule 18).
	uv run pdoc --docformat google --port 8080 $(PYTHON_MODULES)

.PHONY: build
build: ## Build the wheel and sdist (uv rule 13).
	uv build

.PHONY: image
image: ## Build the production container image.
	docker buildx build --load -t python-uv-app:dev .

.PHONY: sbom
sbom: ## Generate a CycloneDX SBOM for the project (sbom rule 5).
	uv run cyclonedx-py environment --pyproject pyproject.toml --outfile sbom.cdx.json --of JSON

.PHONY: up
up: ## Start the local Compose topology (api + postgres).
	docker compose up --build --detach

.PHONY: down
down: ## Stop the local Compose topology.
	docker compose down --volumes

.PHONY: compose-validate
compose-validate: ## Validate compose.yaml + override (docker-compose rule 25).
	docker compose -f compose.yaml -f compose.override.yaml config --quiet

.PHONY: clean
clean: ## Remove build outputs and caches.
	rm -rf dist build _docs-check $(DOCS_OUTPUT) htmlcov coverage.xml .coverage .coverage.*
