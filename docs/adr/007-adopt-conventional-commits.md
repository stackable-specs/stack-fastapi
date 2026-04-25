# ADR-007: Adopt Conventional Commits

## Status

Accepted

## Context and Problem Statement

Release-notes generators, SemVer-bumping bots, changelog renderers, scope-filtered CI, and `git bisect` all make better decisions when commit messages carry structured metadata. Free-form commits (`Fixed bug`, `wip`, `update`) leave those tools unable to distinguish a feature from a chore, a breaking change from a refactor, or a user-visible change from an internal one.

## Decision Drivers

- Machine-readable commit log that release tools can drive.
- Explicit signaling of breaking changes for SemVer.
- Low authoring overhead — a single-line prefix.
- CI-enforceable to prevent drift.

## Considered Options

- Conventional Commits (v1.0.0).
- Angular commit convention (predecessor; similar but stricter scope rules).
- Gitmoji — emoji prefix; less tooling support.
- Free-form commits — relies on humans re-reading diffs.

## Decision Outcome

We will adopt Conventional Commits, governed by `specs/practices/conventional-commits.md`. Every commit on the default branch must parse; `feat:` means user-visible behavior; breaking changes carry `!` and a `BREAKING CHANGE:` footer; CI rejects malformed messages.

## Consequences

- Positive: release-please (or equivalent) can compute SemVer bumps and changelogs without human input.
- Positive: `git log --grep=^feat` filters the user-visible slice of history.
- Negative: contributors must learn the type vocabulary and breaking-change conventions.
- Negative: a CI commit-lint gate adds a small failure mode at PR time.
