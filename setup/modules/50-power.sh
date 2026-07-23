# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 50-power: power button suspends instead of powering off.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Power key: short press suspends, long press powers off"
MODULE_PROFILES=(desktop)
MODULE_DOC="docs/setup/power-management.md"

# A logind drop-in, deliberately *not* an edit of /etc/systemd/logind.conf: the
# shipped file is package-managed and every setting in it is commented out, so a
# drop-in survives upgrades and stays greppable as "something we changed".
declare -r LOGIND_DROPIN="/etc/systemd/logind.conf.d/50-power-key.conf"

# The long-press escape hatch matters: with HandlePowerKey=suspend there would
# otherwise be no way to force a hard power-off from the button when the machine
# is wedged. Default for LongPress is "ignore", so this has to be set explicitly.
#
# Declared with its value in one statement, never `read`-into-a-var followed by a
# bare `declare -r`: bin/system-setup sources modules from inside a function, so
# a bare `declare -r` would create an empty *local* shadowing the global.
declare -r LOGIND_DROPIN_CONTENT="# Managed by dotfiles: setup/modules/50-power.sh
# Docs: docs/setup/power-management.md
#
# Short press suspends rather than powering off. Suspend goes through logind,
# which emits PrepareForSleep -> swayidle's before-sleep hook locks the screen
# and the secret stores (bin/lock-secrets). A direct poweroff would not.
#
# Long press (>~5s) still forces a power-off, as the escape hatch for a
# machine that is too wedged to suspend.
[Login]
HandlePowerKey=suspend
HandlePowerKeyLongPress=poweroff"

module_run() {
  # {{{ - logind drop-in ------------------------------------------------------
  local -r dropin_dir="${LOGIND_DROPIN%/*}"
  if [[ -d "${dropin_dir}" ]]; then
    st::noop "drop-in directory exists: ${dropin_dir}"
  else
    st::run "create ${dropin_dir}" -- sudo mkdir -p "${dropin_dir}"
  fi

  # st::file_content is a no-op when the content already matches, so the reload
  # below must only fire when it actually wrote something.
  local -i before="${ST_CHANGED:-0}"
  st::file_content "${LOGIND_DROPIN}" "${LOGIND_DROPIN_CONTENT}" 644

  if (( "${ST_CHANGED:-0}" > before )); then
    # reload, never restart: restarting systemd-logind tears down the session.
    st::run "reload systemd-logind" -- sudo systemctl reload systemd-logind
  else
    st::noop "power key policy already applied"
  fi
  # }}} - logind drop-in ------------------------------------------------------
}
