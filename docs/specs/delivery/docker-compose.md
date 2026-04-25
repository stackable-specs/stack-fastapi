---
id: docker-compose
layer: delivery
extends: []
---

# Docker Compose

## Purpose

A Compose file is the contract for how a set of containers stand up together — the images that run, the network they share, the volumes they mount, the secrets they read, the order they start in, and the conditions under which the next service is allowed to begin. Sloppy Compose files quietly invalidate every guarantee the underlying images provide: a missing `depends_on` condition lets the API boot before the database is accepting connections, a `version: "3"` key drags in legacy schema interpretation, an inline `environment:` list bakes credentials into committed YAML, a bind-mounted source tree in production overwrites the very binaries the image was built to ship, an unpinned `image: postgres` drifts the data tier between developer machines, and an `restart: always` on a crashing service hides the crash from operators. This spec pins how Compose files are named, structured, parameterized, layered for environments, and constrained so the same file produces the same topology on every developer laptop, in CI, and in any single-host production deployment that uses Compose as its runtime.

## References

- **spec** `docker` — sibling delivery-layer spec for the image format Compose orchestrates
- **external** `https://docs.docker.com/compose/` — Docker Compose documentation
- **external** `https://docs.docker.com/compose/compose-file/` — Compose file specification
- **external** `https://github.com/compose-spec/compose-spec` — Compose Specification (open spec)
- **external** `https://docs.docker.com/compose/how-tos/profiles/` — Compose profiles
- **external** `https://docs.docker.com/compose/how-tos/use-secrets/` — Compose secrets

## Rules

1. Name the canonical Compose file `compose.yaml` at the repo root; do not use the legacy `docker-compose.yml` filename for new projects.
2. Omit the top-level `version:` key; the Compose Specification is unversioned and the key is ignored by Compose v2.
3. Invoke Compose as `docker compose` (the v2 plugin); do not script against the deprecated `docker-compose` v1 binary.
4. Set an explicit project name via `name:` in the file or `COMPOSE_PROJECT_NAME` in CI; do not rely on the working-directory basename for project identity.
5. Give every service a stable, kebab-case name that matches its DNS hostname on the project network; do not rename services across environments.
6. Reference every `image:` by immutable digest (`<image>@sha256:<digest>`) for production-bound services with the human-readable tag in a trailing comment; do not deploy production from a mutable tag like `:latest` or `:main`. (refs: docker)
7. Place a `build:` block only on services whose image is built from this repo, and pin both `context:` and `dockerfile:` explicitly; do not mix `build:` and a registry `image:` reference without also setting an `image:` name for the build output so the resulting image is tagged.
8. Declare every named network, volume, secret, and config under the top-level `networks:`, `volumes:`, `secrets:`, and `configs:` keys; do not rely on Compose to auto-create anonymous resources for anything that holds state or carries traffic between services.
9. Use named volumes for persistent service state (databases, caches, queues); do not use bind mounts for production state.
10. Restrict bind mounts of source code into containers to development-only override files (e.g. `compose.override.yaml`); do not bind-mount source over image contents in the canonical `compose.yaml`.
11. Inject configuration through `environment:` keys backed by an interpolated `${VAR}` from a `.env` file or the shell; do not hard-code environment values inline in committed YAML.
12. Commit a `.env.example` documenting every variable Compose interpolates, and add `.env` to `.gitignore`; do not commit a populated `.env`.
13. Inject credentials through Compose `secrets:` (file- or external-sourced) mounted into the container filesystem; do not pass credentials through `environment:` or `env_file:`.
14. Declare service start ordering with `depends_on:` using the long form with `condition: service_healthy` (or `service_completed_successfully`) and pair it with a `healthcheck:` on the dependency; do not use the short-form `depends_on:` list, which only waits for container start, not readiness.
15. Define a `healthcheck:` for every long-running service that another service depends on; do not rely on `sleep` or retry loops in dependent services to wait for readiness.
16. Set `restart:` explicitly on every long-running service (`unless-stopped` or `on-failure` for production, `no` for one-shot tasks); do not omit the restart policy and inherit the default.
17. Set `deploy.resources.limits` (CPU and memory) on every service in production-bound files; do not run unbounded containers on a shared host.
18. Publish ports with the explicit `host:container` form bound to a specific interface (`"127.0.0.1:8080:8080"`) for any port that must not be reachable from outside the host; do not publish ports as a bare container port that binds to all interfaces.
19. Keep inter-service traffic on internal Compose networks and expose only edge services to the host; do not publish ports for services that are only consumed by other services in the same Compose project.
20. Gate optional services (debug UIs, seed jobs, profilers) behind `profiles:` and document the profile in the README; do not require operators to comment out service blocks to disable them.
21. Layer environment-specific configuration with `compose.override.yaml` (auto-loaded for development) and explicit `-f compose.yaml -f compose.prod.yaml` invocations for other environments; do not maintain divergent copies of `compose.yaml` per environment.
22. Run services as a non-root `user:` (numeric UID:GID) when the underlying image does not already drop privileges; do not run application services as root in Compose.
23. Set `read_only: true` on the container root filesystem for production services and declare writable paths as `tmpfs:` or named volumes; do not run production containers with a writable root filesystem.
24. Configure a bounded `logging:` driver with size and file-count limits (e.g. `json-file` with `max-size` and `max-file`, or a remote driver) on every service; do not ship production Compose stacks with unbounded local logs.
25. Validate every Compose file in CI with `docker compose config --quiet` (and a schema linter such as `compose-spec` validation) before merge; do not merge changes to a Compose file without confirming it parses.
26. Treat Compose as a single-host runtime; do not use Compose to manage multi-host production deployments — use a cluster orchestrator (Kubernetes, Nomad, ECS) instead.
