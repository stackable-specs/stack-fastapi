# ADR verifiers

Platform-agnostic bash scripts that check whether the python-uv stack actually conforms to each ADR under `docs/adr/`.

## Layout

- `lib.sh` — shared helpers (color output, pass/fail/skip recording, TOML/YAML reading via `python3` stdlib + grep/awk). Source it from each ADR script; do not run directly.
- `adr-NNN-<topic>.sh` — one script per ADR (001..019). Each script exits `0` if every assertion passes, `1` if any fails, `2` if a required tool is missing.
- `verify-all.sh` — runs every ADR verifier in order; exits nonzero if any fail.

## Usage

```bash
# Run a single verifier
bash verify/adr-018-prek.sh

# Run everything
bash verify/verify-all.sh
```

## Conventions

- Pure POSIX-portable shell. Tested with `bash` on macOS and Linux.
- Heavy use of `python3 -c 'import tomllib'` for TOML reads (Python 3.11+ stdlib; the stack already requires Python ≥ 3.12 per ADR-001).
- Optional tooling (uv, prek, trunk, docker, npx) is checked with `have_tools`. Missing optional tools surface as `SKIP`, not `FAIL` — so the script remains useful in a minimal sandbox.
- Static checks first, runtime checks (e.g. `uv run mypy`, `prek run --all-files`) only when the supporting tool is on `PATH`.

## Output

Each script ends with a summary block:

```
== ADR-018 — prek ==
  PASS  prek.toml present
  PASS  Trunk hook actions disabled
  PASS  prek.toml references 'commitlint'
  ...
  10/12 passed (2 skipped)
```

Exit code matches the gate intent: `0` clean, `1` failure, `2` missing required tool.
