# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 38-solaar: divert the MX Mechanical Mini Fn-row keys that rules.yaml acts on.
#
# The rules live in the repo (home/.config/solaar/rules.yaml, linked by
# dotfiles-link). The diversion is a per-device setting that Solaar keeps in
# ~/.config/solaar/config.yaml, which holds the serial and battery level and is
# rewritten by Solaar, so it cannot be a repo file. This module sets it through
# the `solaar config` CLI instead.
#
# motoko only: the other desktop (puppet) uses its notebook keyboard.
# A diverted key is a Solaar/HID++ state, not a keyboard setting stored in
# firmware, so the same keyboard on another host (e.g. Windows) is unaffected.
#
# Needs the keyboard awake and connected; if it is not, the module says so and
# changes nothing (re-run it with the keyboard on).
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Solaar: divert MX Mechanical Mini Fn keys used by rules.yaml (motoko only)"
MODULE_PROFILES=(desktop)
MODULE_DOC="docs/reference/keyboard-input.md"

declare -r SOLAAR_DEVICE="MX Mechanical Mini"
# Keys named in home/.config/solaar/rules.yaml.
declare -ra SOLAAR_DIVERT=("Mute Microphone" "Dictation" "Emoji" "Backlight Down" "Backlight Up")

module_run() {
  if [[ "$(hostname -s)" != "motoko" ]]; then
    st::noop "solaar key diversion is motoko-only"
    return 0
  fi
  if ! st::have_cmd solaar; then
    st::war "solaar not installed (setup/packages/desktop.list), skipping"
    return 0
  fi

  # A running tray instance and the CLI both write config.yaml; observed
  # 2026-11-03: a CLI call next to a running instance cut it from 4160 to 354
  # bytes (the mouse's settings and the keyboard's backlight config were gone).
  if pgrep -u "${UID}" -x solaar >/dev/null; then
    st::war "solaar is running; quit it first (pkill solaar), re-run, then start it again (solaar -w hide)"
    return 0
  fi

  local state
  if ! state="$(solaar config "${SOLAAR_DEVICE}" divert-keys 2>/dev/null)" \
       || [[ "${state}" != *"divert-keys"* ]]; then
    st::war "${SOLAAR_DEVICE} not reachable (off, asleep or not paired), skipping"
    return 0
  fi

  local key
  for key in "${SOLAAR_DIVERT[@]}"; do
    if [[ "${state}" == *"${key}:Diverted"* ]]; then
      st::noop "${key} already diverted"
    else
      st::run "divert ${key}" -- \
        solaar config "${SOLAAR_DEVICE}" divert-keys "${key}" Diverted
    fi
  done
}
