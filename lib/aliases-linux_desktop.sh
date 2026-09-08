# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/lib/aliases-linux_desktop.sh: aliases for a Linux desktop session only.
#
# Sourced by both bash and zsh, but only when XDG_CURRENT_DESKTOP is set
# (i.e. an active graphical session, not a bare TTY or SSH login). Keep GUI-
# only tooling here so plain shells stay uncluttered.

# font discovery (fontconfig) — see ~/.config/sway/config.d/20-styles.conf
alias font-list="fc-list : family | sort -u"          # all installed families
alias font-search="fc-list | grep -i"                 # font-search fira
alias font-match="fc-match"                            # what a name resolves to

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

return 0
