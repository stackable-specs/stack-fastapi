# Standard Operating Procedures — python-uv stack

Numbered, executable runbooks for recurring stack-level operations. Each SOP names the trigger that should cause it to run, the exact commands, the expected output, and the known failure modes with fixes.

## Index

| SOP | Title | When to run |
| --- | --- | --- |
| [SOP-001](001-verify-stack.md) | Verify the stack end-to-end | After scaffolding, tooling upgrades, major dep bumps, before a release |

## Authoring

Copy an existing SOP, assign the next monotonic number, and open a PR. Keep each SOP imperative — every step a reviewer can run verbatim.
