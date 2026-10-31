# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 34-uv: uv (Python package and project manager) via the upstream installer.
#
# Same reasoning as 22-fnm: apt has no current uv, and the standalone binary
# lands in ~/.local/bin (already on PATH via home/.common_env) without root,
# on every host and in containers alike. UV_NO_MODIFY_PATH keeps the installer
# away from ~/.zshrc / ~/.bashrc / ~/.profile (symlinks into this repo).
#
# This replaces conda in the devcontainers. There is deliberately no global
# venv here: a project gets its own .venv from `uv sync`, CLIs come from
# `uv tool install`, and scratch work runs as `uv run --with PKG python`.
# See MODULE_DOC.
#
# "Present and runnable" means done, so a re-run reports zero changes and
# needs no network. Update with UV_UPDATE=1 (`uv self update`).
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="uv Python package/project manager (upstream installer, ~/.local/bin/uv)"
MODULE_PROFILES=(desktop server wsl container)
MODULE_DOC="docs/setup/uv.md"

declare -r UV_INSTALL_URL="https://astral.sh/uv/install.sh"
declare -r UV_BIN_DIR="${HOME}/.local/bin"
declare -r UV_BIN="${UV_BIN_DIR}/uv"

module_run() {
  if [[ -x "${UV_BIN}" ]]; then
    if [[ -n "${UV_UPDATE:-}" ]]; then
      st::run "update uv (uv self update)" -- "${UV_BIN}" self update
    else
      st::noop "uv already installed: ${UV_BIN} (UV_UPDATE=1 to update)"
    fi
    return 0
  fi

  if ! st::have_cmd curl; then
    st::war "curl not found — skipping (run '00-apt-base' first, or install curl)"
    return 0
  fi

  # pipefail: a failed curl must not look like a successful install.
  st::run_sh "install uv into ${UV_BIN_DIR} (upstream installer, no PATH edits)" \
    "set -o pipefail; curl -LsSf '${UV_INSTALL_URL}' | env UV_INSTALL_DIR='${UV_BIN_DIR}' UV_NO_MODIFY_PATH=1 sh"
}
