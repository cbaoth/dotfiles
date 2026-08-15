# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 15-xdg-dirs: XDG user directories that are exported but never created.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="XDG user dirs: create the ones nothing else creates (Screenshots)"
MODULE_PROFILES=(desktop)
MODULE_DOC="docs/setup/xdg-user-dirs.md"

# The defaults are repeated from dotfiles/.common_env rather than relied upon
# from the environment: system-setup runs on fresh machines where dotfiles-link
# has not run yet, so nothing has exported these variables.
declare -r XDG_PICTURES="${XDG_PICTURES_DIR:-${HOME}/Pictures}"

# xdg-user-dirs-update creates Pictures, Documents, Videos, ... but knows
# nothing about Screenshots — that one is our own convention, exported by
# .common_env and consumed by grimshot. grim does not mkdir its target either,
# it just fails, and grimshot reports that as "Error: Unable to invoke grim".
declare -ra XDG_USER_DIRS=(
  "${XDG_SCREENSHOTS_DIR:-${XDG_PICTURES}/Screenshots}"
)

module_run() {
  local dir
  for dir in "${XDG_USER_DIRS[@]}"; do
    if [[ -d "${dir}" ]]; then
      st::noop "directory exists: ${dir}"
    else
      st::run "create ${dir}" -- mkdir -p "${dir}"
    fi
  done
}
