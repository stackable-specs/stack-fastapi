# syntax=docker/dockerfile:1.10
#
# Multi-stage build per docker.md (ADR-015):
# - rule 2: base images referenced by digest, human-readable tag in trailing comment.
# - rule 3: builder stage isolated from runtime stage.
# - rule 4: runtime is distroless.
# - rule 5: runtime runs as a non-root user.
# - rule 6: every package install is pinned (uv handles application deps; the lockfile is enforced).
# - rule 11: no secrets in ARG/ENV — use BuildKit `--mount=type=secret` if needed.
# - rule 12: ENTRYPOINT in exec form.
# - rule 13: HEALTHCHECK declared.
# - rule 14: build with BuildKit (Docker 23+ does this by default).
#
# IMPORTANT: replace the placeholder `@sha256:...` digests below with real ones
# resolved at the time of the upgrade PR (e.g. `docker buildx imagetools inspect`).

ARG PYTHON_TAG=3.12-slim

# ---- Builder ---------------------------------------------------------------
FROM python:${PYTHON_TAG} AS builder
# TODO(release): pin builder by digest, e.g.
# FROM python@sha256:REPLACE_WITH_DIGEST  # python:3.12-slim

# WORKDIR matches the runtime path so the venv's editable-install entry for
# the project (`/app/src/app`) resolves identically in both stages.
WORKDIR /app

# Install uv at a pinned version (uv rule 1: do not curl|sh unpinned).
ARG UV_VERSION=0.11.7
ENV UV_LINK_MODE=copy \
    UV_NO_PROGRESS=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir "uv==${UV_VERSION}"

# Resolve dependencies from the committed lockfile (uv rule 9).
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev --no-install-project

COPY README.md ./
COPY src ./src
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev

# ---- Runtime ---------------------------------------------------------------
# Slim Debian 12 + Python 3.12 (docker rule 4 allows `*-slim`). Distroless
# `python3-debian12` would be more minimal but ships Python 3.11, which is
# ABI-incompatible with the 3.12 venv built above.
FROM python:${PYTHON_TAG} AS runtime
# TODO(release): pin runtime by digest, e.g.
# FROM python@sha256:REPLACE_WITH_DIGEST  # python:3.12-slim

# Create the non-root runtime account (docker rule 5). Pin uid:gid so other
# layers (Compose `user:`, K8s `runAsUser`) can reference it deterministically.
RUN groupadd --system --gid 65532 app \
    && useradd --system --uid 65532 --gid 65532 --home /app --shell /sbin/nologin app

WORKDIR /app
USER 65532:65532

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/app/.venv/bin:${PATH}"

COPY --from=builder --chown=65532:65532 /app/.venv /app/.venv
COPY --from=builder --chown=65532:65532 /app/src /app/src

EXPOSE 8000

# Hit the liveness probe defined in the FastAPI app (docker rule 13).
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD ["/app/.venv/bin/python", "-c", "import urllib.request, sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2).status == 200 else 1)"]

# Exec form per docker rule 12.
ENTRYPOINT ["/app/.venv/bin/python", "-m", "uvicorn", "app.main:app"]
CMD ["--host", "0.0.0.0", "--port", "8000", "--workers", "2", "--no-server-header"]
