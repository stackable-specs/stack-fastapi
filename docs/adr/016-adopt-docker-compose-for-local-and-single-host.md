# ADR-016: Adopt Docker Compose for Local Dev and Single-Host Topology

## Status

Accepted

## Context and Problem Statement

A python-uv service rarely runs alone — it talks to a database, a broker, sometimes a vector store or a fixture stub. Developers, CI integration tests (ADR-010), and small single-host deployments all need a way to stand up a coherent multi-container topology with the same images, network, and dependency wiring everywhere. Without a pinned format, each developer scripts container startup their own way, CI integration tests stand up dependencies through ad-hoc shell, and "works on my machine" becomes the dominant failure mode.

## Decision Drivers

- One file produces the same topology on every developer laptop, in CI, and in any single-host production deployment.
- Compatible with Docker images (ADR-015) as the only artifact format.
- Supports the integration testing discipline (ADR-010) via real dependencies in containers.
- Environment layering (`compose.override.yaml`, profile overrides) without forking the file per environment.

## Considered Options

- Docker Compose authored per `specs/delivery/docker-compose.md`.
- Kubernetes (kind, minikube, k3s) for local dev — heavier, slower iteration loop.
- Per-developer shell scripts orchestrating `docker run` — no shared topology contract.
- `testcontainers` only, with no Compose file — works for tests but leaves local dev unsupported.

## Decision Outcome

We will adopt Docker Compose as the multi-container orchestration format for local development, CI integration tests, and single-host deployments where applicable, governed by `specs/delivery/docker-compose.md`. Compose files use the modern `compose.yaml` schema (no `version:` key), pin every `image:` to a digest or specific tag, declare `depends_on` with `condition: service_healthy`, source secrets from a secret store rather than inline `environment:` blocks, and layer environments via override files rather than parallel forks.

## Consequences

- Positive: developers get a one-command local topology that matches CI integration tests and single-host deployments.
- Positive: integration tests (ADR-010) can target the same Compose file the developer used locally, reducing parity bugs.
- Positive: a Compose file is reviewable as configuration, not buried in shell scripts.
- Negative: Compose is not a substitute for an orchestrator — production at scale still needs Kubernetes or a managed platform; the spec is explicit that Compose is for local + small single-host.
- Negative: contributors must internalize the "don't bind-mount source in production / don't bake secrets in YAML" rules; the spec exists to keep those mistakes from landing.
