# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zsh.d/aliases-linux.zsh: Linux-specific zsh-only additions.
#
# Shell-agnostic aliases live in ~/lib/aliases-linux.sh (sourced first).
# This file contains only zsh-specific additions.

# {{{ = ZSH SPECIFIC =========================================================

# {{{ - Flatpak app functions -------------------------------------------------
# Auto-generate shell functions for all installed flatpak apps.
# Zsh-specific: uses ${(q)}, whence -p, compdef, unfunction.
# Shell-agnostic flatpak package management aliases are in lib/aliases-linux.sh.
__add_flatpak_app_functions() {
  if ! command -v flatpak >/dev/null 2>&1; then
    return 0
  fi
  local name application alias_name function_name
  local -A alias_map

  # Manual alias overrides for long/awkward app names.
  alias_map=(
    [gnu-image-manipulation-program]=gimp
  )

  while IFS=$'\t' read -r name application; do
    alias_name="$(printf '%s' "${name}" \
      | tr -cs '[:alnum:]_-' '-' \
      | tr '[:upper:]' '[:lower:]')"
    alias_name="${alias_name##-}"
    alias_name="${alias_name%%-}"
    [[ -z "${alias_name}" ]] && continue

    alias_name="${alias_map[${alias_name}]:-${alias_name}}"

    function_name="${alias_name}"
    while whence -p -- "${function_name}" >/dev/null 2>&1; do
      function_name="f${function_name}"
    done

    eval "${function_name}() { flatpak run ${(q)application} \"\$@\"; }"
    compdef _files "${function_name}"

    case "${alias_name}" in
      protontricks)
        eval "${function_name}-launch() { flatpak run --command=protontricks-launch ${(q)application} \"\$@\"; }"
        compdef _files "${function_name}-launch"
      ;;
    esac
  done < <(flatpak list --app --columns=name,application 2>/dev/null)
}
__add_flatpak_app_functions
unfunction __add_flatpak_app_functions
# }}} - Flatpak app functions -------------------------------------------------

# }}} = ZSH SPECIFIC =========================================================

return 0
