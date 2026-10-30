# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 37-signal: Signal Desktop from Signal's official apt repo (amd64 only).
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.
#
# Replaces the flatpak (org.signal.Signal): not on Signal's download page
# (likely third-party) and only manually updated, whereas apt is official and
# gets unattended updates. The sources file below is the content of
# https://updates.signal.org/static/desktop/apt/signal-desktop.sources, inlined
# so a re-run needs no network.

MODULE_DESC="Signal Desktop apt repo + signing key + package"
MODULE_PROFILES=(desktop)
MODULE_DOC="docs/setup/signal.md"

declare -r SIGNAL_KEY_URL="https://updates.signal.org/desktop/apt/keys.asc"
declare -r SIGNAL_KEYRING="/usr/share/keyrings/signal-desktop-keyring.gpg"
declare -r SIGNAL_SOURCES="/etc/apt/sources.list.d/signal-desktop.sources"
declare -r SIGNAL_SOURCES_CONTENT="Types: deb
URIs: https://updates.signal.org/desktop/apt
Suites: xenial
Components: main
Architectures: amd64
Signed-By: ${SIGNAL_KEYRING}"

module_run() {
  if [[ "$(dpkg --print-architecture)" != "amd64" ]]; then
    st::noop "signal-desktop apt repo is amd64-only"
    return 0
  fi

  if [[ -s "${SIGNAL_KEYRING}" ]] \
       && [[ -f "${SIGNAL_SOURCES}" ]] \
       && [[ "$(cat "${SIGNAL_SOURCES}" 2>/dev/null)" == "${SIGNAL_SOURCES_CONTENT}" ]]; then
    st::noop "signal apt repo already configured"
  else
    st::run_sh "fetch signal signing key" \
      "curl -fsSL ${SIGNAL_KEY_URL} | sudo gpg --yes --dearmor -o ${SIGNAL_KEYRING}"
    st::file_content "${SIGNAL_SOURCES}" "${SIGNAL_SOURCES_CONTENT}"
    st::apt_update --force
  fi

  st::apt_install signal-desktop
}
