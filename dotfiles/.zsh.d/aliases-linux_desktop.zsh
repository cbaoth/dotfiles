# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zsh.d/aliases-linux_desktop.zsh: Host-specific aliases for Linux desktop environments.

# {{{ - FLATPAK APPS ---------------------------------------------------------
# best effort auto-generate functions for all flatpak apps
# no aliases but functions and compdef _files to enable file argument completion for flatpak apps
# pattern:
# - to lowercase
# - all characters apart from alphanumeric and underscores replaced with dashes
# - adds suffix 'f' to avoid conflicts with native apps (if existing)
__add_flatpak_app_functions() {
  local name application alias_name function_name
  local -A alias_map

  # Manual alias overrides for long/awkward app names.
  # Key: normalized app name (lowercase, spaces -> dashes), Value: desired command.
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

    # Optional short-name override (extend alias_map as needed).
    alias_name="${alias_map[${alias_name}]:-${alias_name}}"

    function_name="${alias_name}"
    while command -v -- "${function_name}" >/dev/null 2>&1; do
      function_name="f${function_name}"
    done

    # Use eval with quoted app ID so each generated function keeps its own target.
    eval "${function_name}() { flatpak run ${(q)application} \"\$@\"; }"
    compdef _files "${function_name}"
  done < <(flatpak list --app --columns=name,application 2>/dev/null | tail -n +2)
}

__add_flatpak_app_functions
unfunction __add_flatpak_app_functions 2>/dev/null
# }}} - FLATPAK APPS ---------------------------------------------------------
