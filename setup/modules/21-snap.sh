# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 21-snap: Snap packages and their plug connections.
#
# PRoot (DroidDeck): the opposite. snapd needs systemd and real root, its
# postinst fails there ("Invalid file 'setcap'"), and the half-configured
# package then breaks every later apt install. The vendor image ships it and
# KDE's updater upgrades it, so this removes it and pins it out
# (/etc/apt/preferences.d/no-snapd), like the vendor's own pins.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Snap packages + plug connections (only where snapd exists)"
MODULE_PROFILES=(desktop server wsl proot)
MODULE_DOC="docs/reference/package-managers.md"

declare -r SNAP_PROOT_PIN="/etc/apt/preferences.d/no-snapd"

# PRoot: keep snapd off (see header).
proot_no_snapd() {
  local pin status
  read -r -d '' pin <<'PIN' || true
# Written by setup/modules/21-snap.sh: snapd cannot work in a PRoot (no
# systemd, no real root); a half-configured snapd breaks every apt install.
Package: snapd
Pin: release *
Pin-Priority: -1
PIN
  st::file_content "${SNAP_PROOT_PIN}" "${pin}"

  # Not st::apt_remove: it only removes state "installed", and the broken
  # snapd is "half-configured".
  status="$(dpkg-query -W -f='${db:Status-Status}' snapd 2>/dev/null)" || status=""
  case "${status}" in
    ""|not-installed|config-files) st::noop "snapd not installed" ;;
    *) st::run "remove snapd (${status}; cannot work in a PRoot)" -- \
         sudo apt-get remove -y snapd ;;
  esac
}

module_run() {
  if st::is_proot; then
    proot_no_snapd
    return 0
  fi

  # Never installs snapd itself. Snap is the package manager of last resort
  # here, and pulling a daemon onto a host that does not ship one (Debian) for
  # the sake of a CLI tool is the opposite of that. Ubuntu ships snapd, so this
  # covers the Ubuntu hosts; elsewhere it is a no-op until snapd is added on
  # purpose.
  if ! st::snap_available; then
    st::noop "snapd not available here — skipping snap packages"
    return 0
  fi

  st::snap_install_list snap-base
}
