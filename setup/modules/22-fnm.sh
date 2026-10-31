# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 22-fnm: fnm (Fast Node Manager) plus the current Node LTS, into $HOME.
#
# Like 28-claude-code this installs into $HOME (no root, works on every host
# these dotfiles land on) and uses the upstream installer, because fnm has no
# apt package. The installer is run with --skip-shell: it would otherwise
# append an fnm block to ~/.zshrc / ~/.bashrc / ~/.profile (symlinks into this
# repo, so that dirties tracked files). Shell integration is already done by
# home/.common_env (PATH + `fnm env`) and cb_devtools_completions in
# home/.common_rc, whether or not fnm is installed yet.
#
# The install dir (~/.local/share/fnm) is the installer's default and is what
# .common_env checks for. The installer prefers an existing ~/.fnm over it, so
# the dir is passed explicitly to keep both in agreement.
#
# Claude Code is unaffected by fnm/Node: it ships as a native binary and the
# native installer (28-claude-code) does not use Node at all. Only a global
# npm install of @anthropic-ai/claude-code depends on npm, which is why
# replacing such an install's npm breaks it (docs/setup/claude.md).
#
# "Present and runnable" means done, so a re-run reports zero changes and
# needs no network. Update with FNM_UPDATE=1 (the installer overwrites the
# binary; also available as the `fnm-setup` shell function).
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="fnm NodeJS version manager + Node LTS + npm globals (upstream installer, ~/.local/share/fnm)"
MODULE_PROFILES=(desktop server wsl container)
MODULE_DOC="docs/setup/fnm.md"

declare -r FNM_INSTALL_URL="https://fnm.vercel.app/install"
declare -r FNM_DIR="${HOME}/.local/share/fnm"
declare -r FNM_BIN="${FNM_DIR}/fnm"

module_run() {
  if ! st::have_cmd curl; then
    st::war "curl not found — skipping (run '00-apt-base' first, or install curl)"
    return 0
  fi

  # The installer unpacks a zip.
  st::have_cmd unzip \
    || st::war "unzip not found — the fnm installer needs it (run '00-apt-base' first)"

  if [[ -x "${FNM_BIN}" && -z "${FNM_UPDATE:-}" ]]; then
    st::noop "fnm already installed: ${FNM_BIN} (FNM_UPDATE=1 to update)"
  else
    # pipefail: a failed curl must not look like a successful install.
    st::run_sh "install fnm into ${FNM_DIR} (upstream installer, --skip-shell)" \
      "set -o pipefail; curl -fsSL '${FNM_INSTALL_URL}' | bash -s -- --skip-shell --install-dir '${FNM_DIR}'"
  fi

  # Node: install the LTS only when fnm has no version at all, so a deliberate
  # choice of versions is never touched. Skipped in dry-run before the first
  # install, since the binary does not exist yet.
  if [[ ! -x "${FNM_BIN}" ]]; then
    (( ST_DRY_RUN )) && st::msg "would then install Node LTS and make it the default"
    return 0
  fi

  if "${FNM_BIN}" list 2>/dev/null | st::grep_q -E 'v[0-9]'; then
    st::noop "a Node version is already installed (fnm list)"
  else
    st::run_sh "install Node LTS and set it as default" \
      "'${FNM_BIN}' install --lts && '${FNM_BIN}' default lts-latest"
  fi

  _fnm_npm_globals
}

# Global npm packages from setup/packages/npm-global.list, into fnm's default
# Node. Globals live inside one Node version, so installing a new version
# silently drops them all; this is what puts them back (re-run the module
# after `fnm default <new>`). Not in containers: the list holds host tools
# (the devcontainer CLI), and a container would only carry them as dead weight.
_fnm_npm_globals() {
  if [[ "$(st::profile)" == "container" ]]; then
    st::noop "npm globals skipped in profile container"
    return 0
  fi
  if (( ST_DRY_RUN )) && ! "${FNM_BIN}" list 2>/dev/null | st::grep_q -E 'v[0-9]'; then
    st::msg "would then install the npm globals from npm-global.list"
    return 0
  fi

  local -a pkgs=() missing=()
  st::read_list npm-global pkgs || return 1
  local pkg
  for pkg in "${pkgs[@]}"; do
    if "${FNM_BIN}" exec --using=default -- npm ls -g --depth=0 "${pkg}" >/dev/null 2>&1; then
      (( ST_SKIPPED++ ))
    else
      missing+=("${pkg}")
    fi
  done

  if (( ${#missing[@]} == 0 )); then
    st::skip "all ${#pkgs[@]} npm global(s) already installed"
    return 0
  fi
  st::run "install ${#missing[@]} npm global(s): ${missing[*]}" -- \
    "${FNM_BIN}" exec --using=default -- npm install -g "${missing[@]}"
}
