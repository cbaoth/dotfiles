# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 26-vicinae: Vicinae launcher via the upstream install script.
#
# There is no apt package, so the upstream installer is the supported channel
# (https://docs.vicinae.com/install/linux). It unpacks the release AppImage into
# /usr/local/lib/vicinae, links /usr/local/bin/vicinae, and drops a systemd user
# unit, themes, icon and a modules-load snippet next to it. The script is
# downloaded to a temp file and run as root, rather than piped, so it never
# prompts: its own sudo re-exec (and the [y/N] question that goes with it) only
# happens when it lacks write permission.
#
# Known upstream defect, repaired here: the extracted tree comes out with
# usr/ (and usr/bin, ...) at mode 0700 root-only, so the binary is unreachable
# for every normal user ("permission denied: vicinae"). Cause unconfirmed —
# the AppImage's squashfs modes or the extraction umask. Either way
# `chmod -R go+rX` fixes it and is harmless once upstream is fixed.
#
# "Present and runnable by the user" means done, like 28-claude-code: a re-run
# must report zero changes and must not need the network. To update, run the
# module with VICINAE_UPDATE=1 (the installer compares versions itself and only
# replaces what is older).
#
# Config is NOT handled here: ~/.config/vicinae is a whole-directory link into
# the repo (LINK_DIRS in tools/link-config.conf), because Vicinae saves
# settings.json by rename, which would replace a per-file symlink.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Vicinae launcher (upstream installer into /usr/local, systemd user service)"
MODULE_PROFILES=(desktop)
MODULE_DOC="docs/setup/vicinae.md"

declare -r VIC_INSTALL_URL="https://vicinae.com/install"
declare -r VIC_PREFIX="/usr/local"
declare -r VIC_DIR="${VIC_PREFIX}/lib/vicinae"
declare -r VIC_BIN="${VIC_PREFIX}/bin/vicinae"

# {{{ = Helpers =============================================================

# True if the current user can run the binary — tests the whole symlink chain
# and every directory on it, which is exactly what breaks upstream.
vic_runnable() {
  [[ -x "${VIC_BIN}" ]]
}

vic_install() {
  # Temp file, not a pipe: pipefail cannot be forgotten and the script is
  # inspectable if the install ever misbehaves. Run under sudo so the script
  # sees write access to the prefix and skips its interactive escalation.
  st::run_sh "install Vicinae into ${VIC_PREFIX} (upstream installer)" \
    "set -euo pipefail
     tmp=\$(mktemp)
     trap 'rm -f \"\$tmp\"' EXIT
     curl -fsSL '${VIC_INSTALL_URL}' -o \"\$tmp\"
     sudo bash \"\$tmp\""
}

vic_fix_perms() {
  st::run "make ${VIC_DIR} readable (upstream extracts it root-only)" -- \
    sudo chmod -R go+rX "${VIC_DIR}"
}

# The unit ships in /usr/local/lib/systemd/user. Enabling needs a user bus, so
# a bare tty or ssh session (no XDG_RUNTIME_DIR) only gets a hint.
vic_enable_service() {
  if ! systemctl --user show-environment >/dev/null 2>&1; then
    st::war "no systemd user session here — later run: systemctl --user enable --now vicinae"
    return 0
  fi
  if systemctl --user is-enabled vicinae.service >/dev/null 2>&1; then
    st::noop "vicinae.service already enabled"
  else
    st::run "enable vicinae.service (user)" -- systemctl --user enable --now vicinae.service
  fi
}

# }}} = Helpers =============================================================

module_run() {
  if ! st::have_cmd curl; then
    st::war "curl not found — skipping (run '00-apt-base' first, or install curl)"
    return 0
  fi

  if [[ -d "${VIC_DIR}" ]] && ! vic_runnable && [[ -e "${VIC_BIN}" || -L "${VIC_BIN}" ]]; then
    # installed, but root-only: repair instead of reinstalling
    vic_fix_perms
  elif vic_runnable && [[ -z "${VICINAE_UPDATE:-}" ]]; then
    st::noop "Vicinae already installed: ${VIC_BIN} (VICINAE_UPDATE=1 to update)"
  else
    vic_install
    # a dry run installs nothing, so there is nothing to repair
    if ! (( ST_DRY_RUN )); then
      vic_runnable || vic_fix_perms
    fi
  fi

  vic_enable_service
}
