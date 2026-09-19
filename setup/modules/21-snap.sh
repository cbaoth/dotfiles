# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 21-snap: Snap packages and their plug connections.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Snap packages + plug connections (only where snapd exists)"
MODULE_PROFILES=(desktop server wsl)
MODULE_DOC="docs/reference/package-managers.md"

module_run() {
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
