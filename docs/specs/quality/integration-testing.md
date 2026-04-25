---
id: integration-testing
layer: quality
extends: []
---

# Integration Testing

## Purpose

Unit tests verify that a function does what its author intended in isolation; integration tests verify that the function still does what was intended when it is wired to the real database, the real message broker, the real HTTP layer, and the real downstream services it will collide with in production. The discipline is only valuable when the integration boundary is *real* — a real Postgres in a container instead of a mocked repository, a real NATS instead of an in-memory stub, the real serialization path instead of a hand-built object passed across a method call. The moment teams "integration test" by stitching together more mocks, share a single mutable database across tests, accept flakiness as the cost of doing business, or skip integration tests on PRs because they're "too slow," the suite stops catching the bugs unit tests cannot — schema drift, broken migrations, contract mismatches between services, transaction isolation issues, broker reconnection edge cases, and the full set of real-world failure modes. This spec pins what counts as an integration test, what it must use as dependencies, how state is isolated between runs, where it lives, and how it gates merges so the suite is a load-bearing safety net rather than a slow, flaky CI job people learn to ignore.

## References

- **spec** `tdd` — sibling testing-discipline spec for the red-green-refactor cycle
- **spec** `property-based-testing` — sibling quality spec for property-based tests, which can drive integration scenarios
- **spec** `mutation-testing` — sibling quality spec for mutation testing, which works alongside both unit and integration suites
- **spec** `docker` — sibling delivery spec; integration tests use the same image runtime semantics
- **external** `https://en.wikipedia.org/wiki/Integration_testing` — Integration testing overview
- **external** `https://martinfowler.com/articles/practical-test-pyramid.html` — Martin Fowler: practical test pyramid
- **external** `https://martinfowler.com/articles/microservice-testing/` — Microservice testing strategies
- **external** `https://testcontainers.com/` — Testcontainers
- **external** `https://docs.pact.io/` — Pact contract testing

## Rules

1. Treat a test as an integration test only when it exercises the system-under-test against at least one real out-of-process collaborator (database, message broker, HTTP server, cache, file system on a real volume); a test that mocks every adjacent dependency is a unit test regardless of its directory.
2. Provision real out-of-process dependencies for integration tests via Testcontainers, Docker Compose, or an equivalent ephemeral-container framework; do not point integration tests at a shared development or staging environment.
3. Use the same container image and the same migration / schema setup as production for any integration-tested datastore; do not maintain a separate "test schema" that diverges from the production schema.
4. Run every database migration against the test database during setup; do not seed integration tests by inserting into hand-crafted fixture tables.
5. Mock only at the test's outer boundary — third-party HTTP APIs the team does not own, paid external services, or non-deterministic upstreams; do not mock the system-under-test's own adjacent components (its DB, its broker, its in-process modules).
6. Use a contract test (Pact, Spring Cloud Contract, or similar) for every consumer-provider pair across team boundaries; do not rely on hand-written stubs that diverge from the provider's real schema over time.
7. Isolate state per test: a fresh schema, a fresh tenant prefix, a transaction-rolled-back boundary, or a fresh container; do not share mutable state across tests in a single run.
8. Make every integration test deterministic — pin clocks, seed randomness, assert no network egress to systems not provisioned by the test harness; do not allow tests to depend on the current wall-clock date, host time zone, or external DNS.
9. Set explicit per-test and per-suite timeouts; do not let a hung integration test exhaust the CI job's overall budget.
10. Locate integration tests under a clearly separated directory (`tests/integration/`, `src/test/integration/`, `*_integration_test.go`, etc.) and tag them so the unit-test command excludes them; do not commingle unit and integration tests in the same target.
11. Run the full integration suite on every pull request as a required status check; do not gate integration tests behind a manual trigger or "nightly" job for code that is about to merge.
12. Run a smoke subset of integration tests against the deployed artifact post-deploy; do not assume CI integration runs cover the deployment substrate.
13. Capture logs, structured traces, and the exact container versions on every integration-test failure and attach them to the CI artifact; do not require a developer to re-run a failure locally to find out what happened.
14. Treat flaky integration tests as priority-one bugs — quarantine, file an issue, and fix within a defined SLO; do not configure the runner to silently retry failing tests indefinitely.
15. Do not seed integration tests with copied production data, customer PII, or real credentials; generate synthetic data inside the test or load anonymized fixtures committed to the repo.
16. Maintain the test-pyramid balance — keep the integration suite materially smaller than the unit suite and rely on it for cross-component contracts and real-IO behavior, not for branch-coverage of pure logic.
17. Drive HTTP integration tests through a real server bound to a port (or test client that round-trips the framework's full middleware stack); do not invoke route handlers directly and bypass routing, serialization, and middleware.
18. Drive message-broker integration tests through real publish and subscribe calls against the broker container; do not assert on internal handler functions invoked outside the broker's delivery path.
19. Run integration tests against the same artifact format that ships to production (the published container image, the built binary, the published package); do not build a separate "test build" that omits production-only configuration.
20. Cover the unhappy paths — broker disconnects, database failovers, slow downstream responses, partial writes — with explicit integration tests; do not test only the success path and rely on production to discover failure-mode bugs.
