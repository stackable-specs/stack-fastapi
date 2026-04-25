<!--
Conventional Commits (ADR-007): the squash-merge subject must parse as
`<type>[(scope)][!]: <description>`. Examples: `feat(api): add greetings endpoint`,
`fix(health)!: change readiness contract`.
-->

## Summary

<!-- 1–3 bullets: what changed and why. -->

## Which BDR does this verify?

<!-- Cite `BDR-NNN` here when the change implements or extends a behavior record (ADR-006 / bdr rule 19). Use "n/a" for pure-refactor or tooling changes. -->

## Which ADR does this implement?

<!-- Cite `ADR-NNN`. New decisions need a new ADR before the implementing PR (ADR-005). -->

## Test plan

- [ ] `make check` (unit + property + lint + type-check) passes locally
- [ ] Integration suite (`make test-integration`) passes locally if dependencies changed
- [ ] OpenAPI updated (`make openapi-export`) and `oasdiff` shows no unintended breaking changes
- [ ] Docs build (`make docs`) succeeds when public API changed

## Dependency change checklist (only if pyproject.toml / uv.lock / Dockerfile changed)

- [ ] Reviewed package owner, license, maintenance signal (dependency-management rule 10)
- [ ] License is on the allowlist
- [ ] CODEOWNERS reviewer from `dependency-policy` is requested
