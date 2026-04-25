# ADR-015: Adopt Docker as the Image Format

## Status

Accepted

## Context and Problem Statement

The stack needs a single, portable artifact format for shipping Python services to any runtime — local Docker, Compose hosts, Kubernetes, or a managed container platform. Without a pinned image format and authoring policy, contributors produce ad-hoc Dockerfiles whose builds drift between days, ship every workload as root, leak credentials in `ENV`, and bundle compilers and test frameworks into production.

## Decision Drivers

- Industry-standard, OCI-compliant artifact accepted by every container runtime.
- Reproducible builds — pinned base images, pinned package versions.
- Minimal, multi-stage images that exclude build-time tooling from the runtime layer.
- Compatibility with the SBOM (ADR-013), dependency management (ADR-014), and downstream Compose (ADR-016) workflows.

## Considered Options

- Docker (OCI) images authored per `specs/delivery/docker.md`.
- Buildpacks (Paketo, Heroku) — opinionated builders, less control over the final layer set.
- Nix-built OCI images — strong reproducibility, much steeper team onboarding.
- Ship Python services as bare wheels or zipped venvs — no isolation, no consistent runtime.

## Decision Outcome

We will adopt Docker (OCI) images as the unit of delivery for the python-uv stack, governed by `specs/delivery/docker.md`. Dockerfiles pin base images by digest, multi-stage builds keep build tooling out of runtime layers, secrets are injected via build secrets / runtime mounts (never `ENV`/`ARG`), images run as a non-root user, and publication is gated on vulnerability scan + SBOM (ADR-013).

## Consequences

- Positive: a single artifact format runs locally (Compose, ADR-016) and on any container platform without rebuild.
- Positive: digest-pinned bases plus uv's deterministic install (ADR-002) yield byte-reproducible images for a given commit.
- Positive: SBOM and vulnerability gates wire into CI naturally — image build is the natural attestation point.
- Negative: contributors must learn multi-stage Dockerfile authoring and the rules around secrets and non-root users.
- Negative: registry storage and image-lifecycle hygiene become operational responsibilities the stack inherits.
