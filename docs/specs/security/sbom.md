---
id: sbom
layer: security
extends: []
---

# Software Bill of Materials (SBOM)

## Purpose

A Software Bill of Materials is the inventory of every component — direct and transitive — that ships inside a built artifact. Without one, a newly disclosed vulnerability in a deep transitive dependency triggers a frantic, error-prone hunt across repos and registries to find which artifacts are exposed; with one, the same question is a query. The value collapses the moment SBOMs are generated inconsistently, omit transitive components, drift from what was actually built, use ad-hoc formats no scanner understands, or live in a wiki page disconnected from the artifact they describe. This spec pins SBOM format, scope, generation point, distribution, and retention so every released artifact carries a machine-readable, complete, current, and verifiable component inventory that supports vulnerability triage, license compliance, and supply-chain attestation.

## References

- **external** `https://www.cisa.gov/sbom` — CISA SBOM resource hub
- **external** `https://www.ntia.gov/sites/default/files/publications/sbom_minimum_elements_report_0.pdf` — NTIA minimum elements for an SBOM
- **external** `https://spdx.dev/` — SPDX specification
- **external** `https://cyclonedx.org/specification/overview/` — CycloneDX specification
- **external** `https://slsa.dev/` — SLSA supply-chain integrity framework
- **external** `https://github.com/in-toto/attestation` — in-toto attestation format

## Rules

1. Produce an SBOM for every released artifact (container image, binary, package, firmware image); do not release an artifact without one.
2. Emit the SBOM in either SPDX or CycloneDX in a machine-readable serialization (JSON, Protobuf, or tag-value); do not invent a custom SBOM format or ship only a human-readable list.
3. Include every NTIA minimum data field for each component: supplier name, component name, version, unique identifier (PURL, CPE, or SWID), dependency relationship, SBOM author, and SBOM timestamp.
4. Include transitive dependencies, not only direct ones; do not stop at the top-level manifest.
5. Generate the SBOM during the build that produces the artifact, from the same dependency graph the build resolves; do not generate SBOMs after the fact by re-resolving manifests outside the build.
6. Record a content hash (SHA-256 or stronger) for every component the build can hash; do not list components by name and version alone when a hash is available.
7. Sign the SBOM, or include it inside a signed in-toto / SLSA attestation; do not distribute an unsigned SBOM as the source of truth.
8. Distribute the SBOM alongside the artifact it describes — as an OCI referrer for container images, a release asset for source releases, or an attached file in the package registry; do not store SBOMs only in a separate wiki, ticket, or shared drive.
9. Regenerate the SBOM on every build; do not reuse a prior build's SBOM for a new artifact even if the dependency manifest is unchanged.
10. Include the SBOM author, build tool, and build tool version in the document metadata; do not ship an SBOM with no provenance fields.
11. Retain SBOMs for at least as long as the corresponding artifact is supported in any environment, including artifacts that have been superseded but remain deployed.
12. Feed SBOMs into a vulnerability-scanning workflow on a recurring schedule, not only at release time; do not rely on a one-shot pre-release scan to surface CVEs disclosed after release.
13. Record license identifiers using SPDX license expressions for every component where the license is known; do not use freeform strings like "MIT-style" or leave the field blank when the license is determinable.
14. Mark components with unknown or unresolved fields explicitly (e.g. `NOASSERTION`); do not omit the field or substitute a guess.
15. Do not include secrets, internal-only URLs, build-machine paths, or developer email addresses in SBOM fields.
16. Validate the generated SBOM against its format schema in CI; do not publish an SBOM that fails schema validation.
