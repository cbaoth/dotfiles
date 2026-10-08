# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 31-github-copilot: GitHub Copilot CLI via GitHub's official installer.
#
# Same reasoning as 28-claude-code, which this mirrors: the installer drops one
# self-contained binary into $HOME/.local/bin, so it works on hosts without
# root, without Node, on WSL and in containers alike. The alternatives were
# npm (@github/copilot, drags in nvm/Node on every host) and the VS Code
# `copilot` shim (needs a VS Code install, which a WSL box with only
# vscode-server does not have).
#
# The installer downloads the release tarball and SHA256SUMS.txt from
# github.com/github/copilot-cli and aborts on a checksum mismatch. Present
# means done here; `copilot update` checks for and applies a newer release.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="GitHub Copilot CLI (official installer, ~/.local/bin/copilot)"
MODULE_PROFILES=(desktop server wsl)
MODULE_DOC="docs/setup/github-copilot.md"

declare -r COPILOT_CLI_INSTALL_URL="https://gh.io/copilot-install"

# latest | an exact version (e.g. 1.0.0) | prerelease. Passed as VERSION.
declare -r COPILOT_CLI_VERSION="latest"

# Checked directly rather than via `command -v`: system-setup may run with a
# PATH that lacks ~/.local/bin (sudo -i, cron), which would reinstall on every
# run and break the zero-changes re-run contract.
declare -r COPILOT_CLI_BIN="${HOME}/.local/bin/copilot"

module_run() {
  if ! st::have_cmd curl; then
    st::war "curl not found — skipping (run '00-apt-base' first, or install curl)"
    return 0
  fi

  if [[ -x "${COPILOT_CLI_BIN}" ]]; then
    st::noop "Copilot CLI already installed: ${COPILOT_CLI_BIN}"
    return 0
  fi

  # A `copilot` elsewhere (npm global, hand-placed) is not ours; installing
  # beside it would leave two on PATH with PATH order picking the winner.
  if st::have_cmd copilot; then
    st::war "a 'copilot' is on PATH at $(command -v copilot) but not at ${COPILOT_CLI_BIN}"
    st::war "leaving it alone — see docs/setup/github-copilot.md"
    return 0
  fi

  # pipefail: without it a failed curl feeds bash an empty script, bash exits 0
  # and the module reports a successful install of nothing. Never under sudo —
  # as root the installer targets /usr/local/bin instead of $HOME.
  st::run_sh "install Copilot CLI (${COPILOT_CLI_VERSION})" \
    "set -o pipefail; curl -fsSL '${COPILOT_CLI_INSTALL_URL}' | VERSION='${COPILOT_CLI_VERSION}' bash"

  if ! (( ST_DRY_RUN )) && [[ -x "${COPILOT_CLI_BIN}" ]] && ! st::have_cmd copilot; then
    st::war "installed, but ~/.local/bin is not on PATH — run dotfiles-link, then a new shell"
  fi
}
