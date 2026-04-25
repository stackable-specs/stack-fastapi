---
id: python
layer: language
extends: []
---

# Python

## Purpose

Python's flexibility — dynamic typing, loose scoping, multiple working idioms for the same operation — rewards discipline with readable code and punishes its absence with files that drift subtly between contributors. PEP 8, type hints, `pyproject.toml` packaging, and modern idioms (`pathlib`, f-strings, dataclasses, `async` / `await`) are now universally supported; older patterns still work but fragment the codebase and defeat the tooling (mypy, ruff) that catches real defects. This spec pins the modern Python subset, the packaging model, and the type-check / lint / format toolchain so a reader of any file in the repo can rely on consistent semantics and so CI is a reliable gate rather than advisory noise.

## References

- **external** `https://www.python.org/` — Python language home
- **external** `https://docs.python.org/3/` — Python 3 documentation
- **external** `https://peps.python.org/pep-0008/` — PEP 8: Style Guide for Python Code
- **external** `https://peps.python.org/pep-0484/` — PEP 484: Type Hints
- **external** `https://peps.python.org/pep-0621/` — PEP 621: Storing project metadata in `pyproject.toml`
- **external** `https://docs.astral.sh/ruff/` — Ruff linter and formatter
- **external** `https://google.github.io/styleguide/pyguide.html` — Google Python Style Guide

## Rules

1. Declare the supported Python version range in `pyproject.toml`'s `requires-python`, and keep the minimum at one of the two most recent releases still under the upstream support policy.
2. Manage project metadata and dependencies in `pyproject.toml` (PEP 621); do not use a bare `requirements.txt` as the source of truth for application dependencies.
3. Use a single dependency resolver per project (uv, Poetry, or pip-tools) and commit its lockfile (`uv.lock`, `poetry.lock`, or a pinned `requirements.txt`).
4. Run every Python process inside a project-local virtual environment; do not `pip install` into the system Python.
5. Format every `.py` file with Ruff format (or Black) using a single committed config; CI must fail on unformatted files.
6. Lint every `.py` file with Ruff, enabling at minimum the `E`, `F`, `I`, `UP`, `B`, and `SIM` rule sets.
7. Sort imports with Ruff's `I` rules (or isort using the `black` profile); CI must fail on unsorted imports.
8. Name functions, variables, methods, and modules in `snake_case`; name classes in `PascalCase`; name module-level constants in `UPPER_SNAKE_CASE`. (refs: https://peps.python.org/pep-0008/)
9. Use f-strings for string interpolation; do not use `%` formatting or `str.format` in new code.
10. Annotate every public function and method signature with type hints; rely on inference only for private helpers and local variables.
11. Use built-in generic syntax (`list[int]`, `dict[str, X]`, `X | None`) from PEP 585 / PEP 604; do not import `List`, `Dict`, or `Optional` from `typing` in code targeting Python 3.10+.
12. Type-check in CI with mypy (`--strict`) or pyright in strict mode; treat any diagnostic as a build failure.
13. Represent filesystem paths with `pathlib.Path`; do not build paths with string concatenation or `os.path.join` in new code.
14. Acquire files, locks, connections, and other resources with `with` statements (context managers); do not rely on `__del__` or manual `close()` calls for cleanup.
15. Catch specific exception classes; do not catch bare `Exception` or `BaseException` except at program boundaries that must not crash.
16. Do not use bare `except:` clauses.
17. Raise built-in or domain-specific exception subclasses with a message argument; do not raise strings or bare values.
18. Emit operational output through the `logging` module with a module-level `logger = logging.getLogger(__name__)`; do not use `print()` for operational messages in library or service code.
19. Pass data between layers through types that carry a schema (`dataclasses.dataclass`, `pydantic.BaseModel`, `typing.TypedDict`); do not pass bare `dict` where the caller cannot statically tell what keys exist.
20. Use `async` / `await` syntax for asynchronous code; do not chain `asyncio.Future.add_done_callback` in new code.
21. Run tests with `pytest`; do not add `unittest`-based suites as a parallel framework.
22. Place tests under a top-level `tests/` directory (or alongside modules as `_test.py` files per a single repo convention) and write them as function-based tests with `pytest` fixtures.
