# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 36-plex: Plex Media Server apt repo, signing key, and package (saito only).
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Plex Media Server apt repo + signing key (saito only)"
MODULE_PROFILES=(server)
MODULE_DOC="docs/setup/plex.md"

declare -r PLEX_KEY_URL="https://downloads.plex.tv/plex-keys/PlexSign.v2.key"
declare -r PLEX_KEYRING="/usr/share/keyrings/plexmediaserver.v2.gpg"
declare -r PLEX_LIST="/etc/apt/sources.list.d/plex.list"
declare -r PLEX_LIST_CONTENT="deb [signed-by=${PLEX_KEYRING}] https://repo.plex.tv/deb/ public main"

module_run() {
  # vserver has no Plex instance — saito is the only media host.
  if [[ "$(hostname -s)" != "saito" ]]; then
    st::noop "plex apt repo is saito-only"
    return 0
  fi

  if [[ -f "${PLEX_LIST}" ]] \
       && [[ "$(cat "${PLEX_LIST}" 2>/dev/null)" == "${PLEX_LIST_CONTENT}" ]] \
       && [[ -s "${PLEX_KEYRING}" ]]; then
    st::noop "plex apt repo already configured"
  else
    # Plex migrated repos at PMS v1.43.0 (new key, new path); clear out any
    # stale plex* file first so an old entry can't shadow or conflict with it.
    local -a old_files=(/etc/apt/sources.list.d/plex*)
    [[ -e "${old_files[0]}" ]] && st::run "remove stale plex apt source file(s)" -- \
      sudo rm -f /etc/apt/sources.list.d/plex*

    st::run_sh "fetch plex signing key" \
      "curl -fsSL ${PLEX_KEY_URL} | sudo gpg --yes --dearmor -o ${PLEX_KEYRING}"
    st::file_content "${PLEX_LIST}" "${PLEX_LIST_CONTENT}"
    st::apt_update --force
  fi

  st::apt_install plexmediaserver
}
