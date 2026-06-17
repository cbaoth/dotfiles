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

# {{{ - Gaming / Steam / Wine ------------------------------------------------

# Set Steam shader background processing thread count in steam_dev.cfg.
# Usage: steam-set-shader-threads [THREADS] [-t apt|snap|flatpak] [-p PATH] [-f]
#   THREADS       Number of threads (default: 8)
#   -t, --type    Steam installation type: apt (default), snap, flatpak
#   -p, --path    Custom path to steam_dev.cfg (overrides --type)
#   -f, --force   Overwrite existing values instead of skipping
steam-set-shader-threads() {
  local threads=8
  local force=false
  local install_type='apt'
  local custom_cfg=''
  local keys=('@ShaderBackgroundProcessingThreads' 'unShaderBackgroundProcessingThreads')

  while (( $# > 0 )); do
    case "$1" in
      -f|--force) force=true ;;
      -t|--type)
        shift
        case "$1" in
          apt|snap|flatpak) install_type="$1" ;;
          *)
            printf 'Invalid type: %s (expected: apt, snap, flatpak)\n' "$1" >&2
            return 1
            ;;
        esac
        ;;
      -p|--path)
        shift
        custom_cfg="$1"
        ;;
      -h|--help)
        cat <<EOF
Usage: steam-set-shader-threads [THREADS] [-t TYPE] [-p PATH] [-f]

Set shader background processing thread count in steam_dev.cfg.
Both @ShaderBackgroundProcessingThreads and unShaderBackgroundProcessingThreads
are written to cover all Steam internal variants.

Arguments:
  THREADS            Number of threads to use (default: 8)
  -t, --type TYPE    Steam installation type (default: apt):
                       apt      ~/.local/share/Steam/steam_dev.cfg
                       snap     ~/snap/steam/common/.steam/steam/steam_dev.cfg
                       flatpak  ~/.var/app/com.valvesoftware.Steam/data/Steam/steam_dev.cfg
  -p, --path PATH    Custom path to steam_dev.cfg (overrides --type)
  -f, --force        Overwrite existing values instead of skipping
  -h, --help         Show this help message
EOF
        return 0
        ;;
      -*)
        printf 'Unknown option: %s\n' "$1" >&2
        return 1
        ;;
      *)
        if [[ "$1" =~ ^[0-9]+$ ]]; then
          threads="$1"
        else
          printf 'Invalid thread count: %s\n' "$1" >&2
          return 1
        fi
        ;;
    esac
    shift
  done

  local cfg
  if [[ -n "${custom_cfg}" ]]; then
    cfg="${custom_cfg}"
  else
    case "${install_type}" in
      apt)     cfg="${HOME}/.local/share/Steam/steam_dev.cfg" ;;
      snap)    cfg="${HOME}/snap/steam/common/.steam/steam/steam_dev.cfg" ;;
      flatpak) cfg="${HOME}/.var/app/com.valvesoftware.Steam/data/Steam/steam_dev.cfg" ;;
    esac
  fi

  if [[ ! -f "${cfg}" ]]; then
    printf 'steam_dev.cfg not found: %s\n' "${cfg}" >&2
    printf 'Create it first or use -p to specify a custom path.\n' >&2
    return 1
  fi

  local key skipped=false
  for key in "${keys[@]}"; do
    if grep -qF "${key}" "${cfg}"; then
      if "${force}"; then
        sed -i "s|^${key} .*|${key} ${threads}|" "${cfg}"
        printf 'Updated: %s %s\n  -> %s\n' "${key}" "${threads}" "${cfg}"
      else
        printf 'WARNING: %s already set, skipping\n  -> %s\n' "${key}" "${cfg}" >&2
        skipped=true
      fi
    else
      printf '%s %s\n' "${key}" "${threads}" >> "${cfg}"
      printf 'Added: %s %s\n  -> %s\n' "${key}" "${threads}" "${cfg}"
    fi
  done

  "${skipped}" && printf 'Tip: run with -f to overwrite skipped entries.\n' >&2
  return 0
}

# }}} - Gaming / Steam / Wine ------------------------------------------------

# }}} = ZSH SPECIFIC =========================================================

return 0
