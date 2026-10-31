---
title: uv (Python package and project manager)
hosts: [all]
status: resolved
tags: [uv, python, venv, conda, devcontainer]
updated: 2026-10-31
automated_by: setup/modules/34-uv.sh
---

# uv (Python package and project manager)

**Automated:** `system-setup 34-uv` (desktop, server, wsl, container). Update
with `UV_UPDATE=1 system-setup 34-uv`, `uv self update`, or `uv-setup`
(aliases `uv-update`, `uv-install`).

## Why uv, why this way

- apt has no current uv; the upstream installer
  (`https://astral.sh/uv/install.sh`) drops a standalone binary into
  `~/.local/bin`, which `home/.common_env` already puts on PATH. No root.
- **Always `UV_NO_MODIFY_PATH=1`.** Without it the installer appends an
  `env` line to `.profile`/`.bashrc`/`.zshrc`, which are symlinks into this
  repo. Its own "already on PATH?" check never matches here (it compares an
  unnormalized path), so it would append every time.
- Present means done: a re-run needs no network and reports zero changes.
- Completions: `cb_devtools_completions` in `home/.common_rc` (uv and uvx).

## No conda, no global venv

The devcontainers used to ship Miniconda with a shared `dev` env. Its jobs
are covered like this now:

| Was | Now |
| --- | --- |
| a project's environment | `.venv` in the project, from `uv sync` (lockfile: `uv.lock`). In a devcontainer: `postCreateCommand` |
| CLI tools (ruff, httpie, …) | `uv tool install NAME`: own venv each, binary in `~/.local/bin` |
| a Python version | `uv python install 3.13`, or the project's `.python-version` |
| a scratch interpreter | `uv run --with requests python` (throwaway env, cached) |

Project aliases: `uvs`, `uvr`, `uva`, `uvt`, … (*PYTHON / UV* in
`home/.aliases`).

The `HAS_CONDA` check and the conda aliases in `home/.aliases` stay for
hosts that still have a conda install; nothing installs conda anymore.
