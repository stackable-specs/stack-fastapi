# ADR-013: Produce an SBOM for Every Released Artifact

## Status

Accepted

## Context and Problem Statement

When a CVE is disclosed in a deep transitive dependency, the team needs to answer "which of our artifacts are exposed?" in seconds, not in a frantic cross-repo hunt. Without a Software Bill of Materials, the answer is approximate at best; with one, it is a query.

## Decision Drivers

- Machine-readable component inventory per artifact.
- Coverage of transitive components, not just direct dependencies.
- Compatibility with vulnerability scanners (ADR-014's downstream consumer) and license tooling.
- Generated from the actual build, not from a re-resolved manifest.

## Considered Options

- CycloneDX or SPDX in JSON, generated during build, signed via in-toto / SLSA, per `specs/security/sbom.md`.
- Internal CSV or wiki list — not machine-readable, drifts immediately.
- Skip SBOMs — depend on after-the-fact `pip freeze` style introspection.

## Decision Outcome

We will produce an SBOM (CycloneDX or SPDX) for every released artifact, generated during the build, signed inside an in-toto / SLSA attestation, distributed alongside the artifact (OCI referrer, release asset, registry attachment), governed by `specs/security/sbom.md`.

## Consequences

- Positive: vulnerability triage on a disclosed CVE collapses to a query against the SBOM corpus.
- Positive: license compliance and supply-chain attestation become tractable.
- Negative: build pipelines must integrate an SBOM generator and a signer.
- Negative: SBOMs must be retained for as long as the artifact is supported, growing the artifact-storage footprint.
