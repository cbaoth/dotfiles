---
description: 'Best practices and conventions for Python projects and standalone Python scripts (uv, Ruff, pyright, pytest)'
# applyTo: used by GitHub Copilot — single string, comma-separated globs
applyTo: "**/*.py,**/pyproject.toml"
# paths: used by Claude Code (loaded as path-scoped rule via .claude/rules/ symlink)
paths:
  - "**/*.py"
  - "**/pyproject.toml"
---

# Python Style Guide

Instructions for writing clean, modern, maintainable Python. Based on PEP 8 and current community best practices
(uv, Ruff, pyright, pytest). Applies to full projects and standalone `.py` scripts alike. Project-specific
configuration (`pyproject.toml`, `CLAUDE.md`, etc.) always takes precedence where it differs.

## Environment & Package Management

- **uv only** — never `pip`, `poetry`, `pipenv`, or `conda`:
  - Add dependency: `uv add package` (dev: `uv add --dev package`)
  - Upgrade: `uv add --dev package --upgrade-package package`
  - Sync environment: `uv sync` (with extras: `uv sync --all-extras`)
  - Run anything: `uv run tool` / `uv run python ...` — never rely on an activated venv or system Python
  - Install CLI tools globally: `uv tool install`
- **FORBIDDEN**: `uv pip install`, `@latest` syntax
- Commit `uv.lock`; keep all project metadata and tool config in `pyproject.toml`
  (no `setup.py`, `setup.cfg`, or `requirements.txt`)
- Target the Python version declared in `requires-python`; default to 3.10+ syntax and features

## Standalone Scripts

Single-file scripts use PEP 723 inline metadata so `uv run script.py` provisions the environment automatically:

```python
#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["requests", "rich"]
# ///
"""Brief description of what the script does."""
```

- Manage script dependencies with `uv add --script script.py package`
- All style, typing, and structure rules below apply to scripts as well
- Use an `if __name__ == "__main__":` guard that calls a `main()` function

## Project Layout

- Use the **src layout** (`src/<package>/`) for installable projects
- Tests live in `tests/`, mirroring the source structure

## Code Style

- PEP 8 naming: `snake_case` for functions/variables/modules, `PascalCase` for classes,
  `UPPER_SNAKE_CASE` for constants
- Line length: soft limit of 119 chars (exceptions allowed, e.g. long URLs);
  configure via `line-length = 119` under `[tool.ruff]`
- f-strings for formatting — never `%` or `.format()`
- `pathlib.Path` over `os.path`
- Use context managers (`with`) for all resource handling (files, locks, connections)
- Prefer comprehensions and generator expressions over `map`/`filter`/manual loops where they stay readable
- Dataclasses (or pydantic when validation is needed) for structured data instead of raw dicts/tuples
- Keep functions small and focused; use early returns to avoid nested conditions
- Mark known issues in code with `TODO:` / `FIXME:` prefixed comments

## Type Hints

- Mandatory throughout: all function signatures and public attributes
- Modern syntax (3.10+): `X | None` instead of `Optional[X]`; builtin generics (`list[str]`, `dict[str, int]`)
  instead of `typing.List` & co.
- Explicit `None` checks for optionals; narrow types before use
- Type check with pyright: `uv run pyright`

## Docstrings

- Required for all public APIs (modules, classes, functions)
- First line: concise imperative summary ending with a period
- Use **Google style** sections (`Args:`, `Returns:`, `Raises:`) to document non-obvious parameters,
  return values, and raised exceptions; omit sections that add nothing

## Linting & Formatting

- Ruff is the only linter and formatter (replaces black, isort, flake8):
  - Format: `uv run ruff format .`
  - Check: `uv run ruff check .` (autofix: `--fix`)
- Run format and check before every commit
- CI failure fix order: formatting → type errors → linting

## Testing

- Framework: pytest — `uv run pytest`
- Async tests: use anyio (`@pytest.mark.anyio`), not asyncio directly
- New features require tests; bug fixes require regression tests
- Test edge cases and error paths, not just the happy path
- Prefer plain `assert`, `@pytest.mark.parametrize` for variants, and fixtures over setup/teardown methods

## Error Handling

- Fail fast: validate inputs and preconditions early, fail with clear error messages
- Raise the most specific exception type; never use bare `except:` — catch specific exceptions
- Use `raise ... from err` to preserve exception chains
- Errors and diagnostics go to stderr; use `logging` in libraries and long-running code,
  plain stdout output for CLI results

## Design Principles

- Simplicity and readability over cleverness; less code = less debt
- DRY: every piece of knowledge has a single, authoritative representation
- Prefer functional, immutable style where it doesn't hurt clarity;
  keep core logic pure and push I/O and side effects to the edges
- Define composing (higher-level) functions before their components
- Build iteratively: minimal working functionality first, verify, then extend
- Minimal changes: only touch code related to the task at hand; follow existing project patterns
