# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 39-ollama: Ollama (local LLM runtime) via the official installer, motoko only.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.
#
# Ollama is not in Ubuntu apt and ships no apt repo: the official install.sh
# downloads the release tarball into /usr/local, creates the `ollama` user and
# a systemd service. Nothing updates it afterwards, so this module compares the
# installed version with the latest GitHub release and re-runs the installer
# only when they differ (the installer is itself idempotent). It needs sudo,
# so run the module from a terminal.
#
# Only motoko has the GPU for it; other hosts are skipped. Models live in
# /usr/share/ollama/.ollama (service user) and are not touched here.

MODULE_DESC="Ollama local LLM runtime (motoko only; updates to latest release)"
MODULE_PROFILES=(desktop)
MODULE_DOC="docs/setup/ollama.md"

declare -r OLLAMA_HOST_ONLY="motoko"
declare -r OLLAMA_LATEST_URL="https://github.com/ollama/ollama/releases/latest"

module_run() {
  if [[ "$(hostname -s)" != "${OLLAMA_HOST_ONLY}" ]]; then
    st::noop "skipping ollama (only installed on ${OLLAMA_HOST_ONLY})"
    return 0
  fi

  if ! st::have_cmd curl; then
    st::war "curl not found — skipping (run '00-apt-base' first, or install curl)"
    return 0
  fi

  # Latest release = target of the /releases/latest redirect, e.g. .../tag/v0.40.16
  local latest
  latest="$(curl -fsSIL -o /dev/null -w '%{url_effective}' "${OLLAMA_LATEST_URL}" 2>/dev/null)" || true
  latest="${latest##*/v}"
  if [[ ! "${latest}" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
    latest=""
  fi

  local current=""
  if st::have_cmd ollama; then
    # "ollama version is 0.20.7" (a "Warning: could not connect" line may precede)
    current="$(ollama -v 2>/dev/null | sed -n 's/.*version is \([0-9][0-9.]*\).*/\1/p' | head -n1)"
  fi

  if [[ -n "${current}" && -z "${latest}" ]]; then
    st::war "cannot determine latest ollama release (offline?) — keeping ${current}"
  elif [[ -n "${current}" && "${current}" == "${latest}" ]]; then
    st::noop "ollama ${current} is the latest release"
  else
    local what="install"
    [[ -n "${current}" ]] && what="update ${current} -> ${latest:-latest}"
    st::run_sh "${what} ollama via official install.sh (needs sudo)" \
      'set -o pipefail; curl -fsSL https://ollama.com/install.sh | sh'
  fi

  if st::have_cmd systemctl; then
    if systemctl is-active --quiet ollama; then
      st::noop "ollama.service is active"
    else
      st::war "ollama.service is not active — check: systemctl status ollama"
    fi
  fi
}
