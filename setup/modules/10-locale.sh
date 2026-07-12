# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 10-locale: en_US UI language with en_DK regional formats (ISO dates).
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Locales: en_US language, en_DK formats (ISO 8601 dates)"
MODULE_PROFILES=(desktop server wsl)
MODULE_DOC="docs/setup/locale.md"

# en_DK is the trick here: it is the only widely-available locale that gives
# ISO-8601 dates (2026-07-12) and 24h time while keeping everything else sane.
declare -r LOCALE_LANG="en_US.UTF-8"
declare -r LOCALE_FORMATS="en_DK.UTF-8"

declare -ra LOCALE_GEN=("${LOCALE_LANG}" "${LOCALE_FORMATS}")

declare -ra LOCALE_FORMAT_VARS=(
  LC_NUMERIC LC_TIME LC_MONETARY LC_PAPER LC_NAME
  LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT LC_IDENTIFICATION
)

module_run() {
  st::apt_install locales

  # {{{ - Generate locales ----------------------------------------------------
  local loc
  local -a to_generate=()
  for loc in "${LOCALE_GEN[@]}"; do
    if locale -a 2>/dev/null | st::grep_q -iE "^${loc/.UTF-8/\.?utf8}$"; then
      st::noop "locale already generated: ${loc}"
    else
      to_generate+=("${loc}")
    fi
  done

  if (( ${#to_generate[@]} > 0 )); then
    for loc in "${to_generate[@]}"; do
      # uncomment the locale in /etc/locale.gen
      st::run "enable ${loc} in /etc/locale.gen" -- \
        sudo sed -i -E "s|^# *(${loc} UTF-8)$|\1|" /etc/locale.gen
    done
    st::run "generate ${#to_generate[@]} locale(s)" -- sudo locale-gen
  fi
  # }}} - Generate locales ----------------------------------------------------

  # {{{ - Set system defaults -------------------------------------------------
  # Build the desired update-locale argument list, then only call it if the
  # current /etc/default/locale does not already say the same thing.
  local -a locale_args=("LANG=${LOCALE_LANG}")
  local var
  for var in "${LOCALE_FORMAT_VARS[@]}"; do
    locale_args+=("${var}=${LOCALE_FORMATS}")
  done

  local -i needs_update=0
  local arg
  for arg in "${locale_args[@]}"; do
    if ! grep -qxF "${arg}" /etc/default/locale 2>/dev/null; then
      needs_update=1
      break
    fi
  done

  if (( needs_update )); then
    st::run "set system locale (LANG=${LOCALE_LANG}, formats=${LOCALE_FORMATS})" -- \
      sudo update-locale "${locale_args[@]}"
    st::war "log out and back in for the new locale to take effect"
  else
    st::noop "system locale already set (LANG=${LOCALE_LANG}, formats=${LOCALE_FORMATS})"
  fi
  # }}} - Set system defaults -------------------------------------------------
}
