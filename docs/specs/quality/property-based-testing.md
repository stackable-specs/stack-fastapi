---
id: property-based-testing
layer: quality
extends: []
---

# Property-Based Testing

## Purpose

Example-based tests verify specific `(input, output)` pairs that a developer thought of; everything else stays untested. Property-based testing inverts that: the developer specifies an invariant or relationship that must hold across the input space, and the framework searches for a counterexample by generating inputs and (when one fails) shrinking it to a minimal reproducer. The discipline pays off only when the asserted properties are actually properties (predicates over a domain, not assertions about a specific input), the generators produce meaningfully diverse cases, the framework's shrinking is allowed to do its work, and discovered counterexamples become regression tests rather than vanishing once the bug is fixed. Without those practices, "property tests" degrade into a `for _ in range(100)` loop with a single assertion that mostly passes by luck — the exact opposite of what they were supposed to provide. This spec pins how property-based tests are framed, generated, run, and integrated into CI so the technique catches the edge cases example tests skip and so a PBT failure produces a small reproducible counterexample rather than a stack trace nobody can rerun.

## References

- **spec** `tdd` — sibling testing-discipline spec for the red-green-refactor cycle
- **external** `https://red.anthropic.com/2026/property-based-testing/` — Anthropic Red Team: agent-driven property-based testing
- **external** `https://hypothesis.readthedocs.io/` — Hypothesis (Python PBT framework)
- **external** `https://github.com/dubzzz/fast-check` — fast-check (JavaScript / TypeScript)
- **external** `https://jqwik.net/` — jqwik (Java)
- **external** `https://fsharpforfunandprofit.com/posts/property-based-testing-2/` — Scott Wlaschin: choosing properties for property-based testing

## Rules

1. Use a dedicated property-based testing framework (Hypothesis for Python, fast-check for JS / TS, jqwik for Java, Kotest property tests for Kotlin, gopter for Go, proptest for Rust, QuickCheck for Haskell or Erlang); do not roll your own random-input loops.
2. Express each property as a predicate over the input space, not an assertion about a specific input; an example-based test reframed as `for x in [...]: assert prop(x)` is not a property test.
3. Identify the property pattern for every test (round-trip, oracle, invariant, idempotence, commutativity, metamorphic, model-based, format compliance) in the test's name or docstring.
4. Use round-trip properties for codecs and serializers: `decode(encode(x)) == x` over every value in the domain.
5. Use oracle properties when a simpler reference implementation exists: the unit under test must agree with the reference for every generated input.
6. Use invariant properties for transformations: state a relation that must hold of the output (sortedness, length, membership, format compliance) regardless of input.
7. Use stateful / model-based PBT (Hypothesis's `RuleBasedStateMachine`, fast-check `commands`, jqwik action-based) for systems whose behavior depends on prior calls; do not test stateful APIs only with single-call property tests.
8. Generate inputs with the framework's strategies / arbitraries; do not pull from `random.random()` or other unregistered sources inside a property body.
9. Define a custom generator when only a subset of the type's domain is valid for the property; use `assume()` / `pre()` filters only for cheap rejection cases.
10. Ground properties in the unit's documented contract (function name, docstring, type signature, caller usage); do not invent properties unrelated to the unit's stated behavior. (refs: https://red.anthropic.com/2026/property-based-testing/)
11. Do not wrap property bodies in `try` / `except` blocks that swallow exceptions; an unhandled exception is a property-test failure and must be allowed to propagate so the framework can shrink it. (refs: https://red.anthropic.com/2026/property-based-testing/)
12. Let the framework shrink failing inputs to a minimal counterexample; do not disable shrinking or transform inputs in ways that defeat it.
13. Configure a deterministic seed (or framework-managed example database) so failures reproduce on the next run, and surface the seed in failure output.
14. Configure an explicit `max_examples` (or framework equivalent) per property — at least 100 for fast properties, more for slow or wide-domain ones — and tune it when coverage is thin; do not silently rely on the framework's smallest default.
15. Persist discovered counterexamples as explicit regression cases (`@example` in Hypothesis, `examples` in fast-check, or framework equivalent) in the same change that fixes the underlying bug.
16. When a property reveals a bug, also add a minimal example-based test capturing the shrunken counterexample; do not rely on PBT alone to re-find a regression with a known input.
17. Cover known-tricky values explicitly (NaN, `±0.0`, empty collections, `int` min / max, Unicode boundary code points, leap-day timestamps, time-zone-edge dates) via `@example` cases or extended generators; do not rely on random sampling to surface them.
18. Track generator diversity with coverage labels (Hypothesis `event()`, fast-check `statistics`, jqwik `Statistics.collect`) when a property fails rarely or never; verify the generator actually produces the intended distribution.
19. Decompose multi-aspect assertions into separate properties; do not assert several unrelated invariants inside a single property body.
20. Run property-based tests in CI with the same framework configuration as local, and treat property failures as build failures.
21. Apply property-based testing to pure functions, codecs, parsers, math, and data-structure operations; use example-based tests for code dominated by I/O, network calls, or framework wiring where input generation is impractical.
