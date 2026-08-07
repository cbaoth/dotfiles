#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash
#
# Move files/directories from $HOME into the repo (flat-sync dirs like bin/ and
# lib/, else dotfiles/) and relink via tools/link.sh, sanitizing names on the way.

set -u

# constants
declare SCRIPT_NAME SCRIPT_FILE TOOLS_DIR REPO_ROOT DOTFILES_DIR LINK_SCRIPT LINK_CONFIG
SCRIPT_NAME="$(basename "$0")"
SCRIPT_FILE="$(realpath "$0")"
TOOLS_DIR="$(dirname "$SCRIPT_FILE")"
REPO_ROOT="$(dirname "$TOOLS_DIR")"
DOTFILES_DIR="${REPO_ROOT}/dotfiles"
LINK_SCRIPT="${TOOLS_DIR}/link.sh"
LINK_CONFIG="${TOOLS_DIR}/link-config.conf"
declare -r SCRIPT_NAME SCRIPT_FILE TOOLS_DIR REPO_ROOT DOTFILES_DIR LINK_SCRIPT LINK_CONFIG

# SYNC_DIRS (flat-sync repo→home pairs, e.g. bin/ and lib/). Sourced at top
# level so `declare -A` inside link-config.conf stays global (a `source` inside
# a function would make it a function-local and lose it).
declare -A SYNC_DIRS=()
if [[ -f "${LINK_CONFIG}" ]]; then
  # shellcheck source=/dev/null
  source "${LINK_CONFIG}" || {
    echo "error: failed to source link config: ${LINK_CONFIG}" >&2
    exit 1
  }
fi

# variables
declare DRY_RUN=false
declare SANITIZE=true
declare -i VERBOSE=0
declare -a WARNINGS=()
declare -a ERRORS=()
declare -a SOURCES=()
declare -a MOVED=()

usage() {
  cat >&2 <<EOF
Usage: $SCRIPT_NAME [--dry-run|-n] [--no-sanitize] [-v|-vv|--verbose[=N]] <path> [<path> ...]

Move each source path (must be inside \$HOME) into the repository, then run
tools/link.sh to create symlinks back. Direct children of a flat-sync home dir
(e.g. ~/bin, ~/lib) land in the matching repo dir (bin/, lib/); everything else
mirrors under dotfiles/ at the same relative location.

By default the destination name is sanitized to match repo conventions (e.g. a
.sh/.bash extension is stripped from executables adopted into bin/). Pass
--no-sanitize to keep the original name verbatim.

Options:
  -n, --dry-run        print changes; move and link nothing
      --no-sanitize    keep the original filename/location verbatim
  -v, -vv, --verbose[=N]
                       increase verbosity (0=quiet, 1=info, 2=debug)
  -h, --help           show this help and exit

Examples:
  $SCRIPT_NAME ~/.config/mimeapps.list
  $SCRIPT_NAME ~/bin/watch-reaction.sh          # → repo bin/watch-reaction
  $SCRIPT_NAME --no-sanitize ~/bin/keep-name.sh # → repo bin/keep-name.sh
  $SCRIPT_NAME -n ~/.config/foo ~/.local/share/bar
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    --no-sanitize)
      SANITIZE=false
      shift
      ;;
    -vv)
      VERBOSE=$((VERBOSE + 2))
      shift
      ;;
    -v|--verbose)
      VERBOSE=$((VERBOSE + 1))
      shift
      ;;
    --verbose=*)
      val="${1#*=}"
      if [[ "$val" =~ ^[0-9]+$ ]]; then
        VERBOSE="$val"
      else
        VERBOSE=1
      fi
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        SOURCES+=("$1")
        shift
      done
      ;;
    -*)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
    *)
      SOURCES+=("$1")
      shift
      ;;
  esac
done

(( VERBOSE > 3 )) && VERBOSE=3

if [[ ${#SOURCES[@]} -eq 0 ]]; then
  usage
  exit 2
fi

vlog() {
  local level="$1"
  shift
  (( VERBOSE >= level )) && echo "$*"
}
info() { vlog 1 "$@"; }
debug() { vlog 2 "$@"; }

format_cmd() {
  local output=""
  local arg

  for arg in "$@"; do
    printf -v output '%s%q ' "$output" "$arg"
  done
  printf "%s" "${output% }"
}

run_and_report() {
  if $DRY_RUN; then
    info "DRY-RUN: would run: $(format_cmd "$@")"
    return 0
  fi

  info "$(format_cmd "$@")"
  "$@"
  local rc=$?
  if (( rc != 0 )); then
    local msg
    msg="ERROR: command failed (exit ${rc}): $(format_cmd "$@")"
    ERRORS+=("$msg")
    echo "$msg" >&2
  fi
  return $rc
}

is_inside_home() {
  local abs_path="$1"
  [[ "$abs_path" == "$HOME" || "$abs_path" == "$HOME"/* ]]
}

is_inside_repo_root() {
  local abs_path="$1"
  [[ "$abs_path" == "$REPO_ROOT" || "$abs_path" == "$REPO_ROOT"/* ]]
}

validate_basics() {
  [[ -d "${REPO_ROOT}/.git" ]] || {
    echo "error: .git not found in ${REPO_ROOT}" >&2
    return 1
  }
  [[ -d "${DOTFILES_DIR}" ]] || {
    echo "error: dotfiles directory not found: ${DOTFILES_DIR}" >&2
    return 1
  }
  [[ -x "${LINK_SCRIPT}" ]] || {
    echo "error: link script not executable: ${LINK_SCRIPT}" >&2
    return 1
  }
  [[ -f "${LINK_CONFIG}" ]] || {
    echo "error: link config not found: ${LINK_CONFIG}" >&2
    return 1
  }
  [[ ${#SYNC_DIRS[@]} -gt 0 ]] || {
    echo "error: SYNC_DIRS not populated (link config sourcing failed)" >&2
    return 1
  }
  return 0
}

# Echo the repo flat-sync dir a source path maps to, or nothing. A source maps
# only when it is a direct child of a configured home dir (~/bin, ~/lib), since
# link.sh flat-syncs those non-recursively; nested paths fall through to the
# dotfiles/ mirror.
sync_dir_for() {
  local abs_path="$1"
  local src_dir repo_dir
  src_dir="$(dirname -- "$abs_path")"
  for repo_dir in "${!SYNC_DIRS[@]}"; do
    if [[ "$src_dir" == "${SYNC_DIRS[$repo_dir]}" ]]; then
      printf '%s' "$repo_dir"
      return 0
    fi
  done
  return 0
}

# Sanitize a destination basename to match repo conventions. Currently strips a
# .sh/.bash extension from executables adopted into bin/ (scripts there carry no
# extension by convention). Add future rules here. A no-op under --no-sanitize.
sanitize_name() {
  local repo_dir="$1"
  local name="$2"

  if $SANITIZE && [[ "$(basename -- "$repo_dir")" == "bin" ]]; then
    case "$name" in
      *.sh)   name="${name%.sh}" ;;
      *.bash) name="${name%.bash}" ;;
    esac
  fi

  printf '%s' "$name"
}

adopt_one() {
  local src_input="$1"
  local src_abs
  local rel_path
  local dst_abs
  local dst_dir

  if [[ ! -e "$src_input" && ! -L "$src_input" ]]; then
    ERRORS+=("ERROR: source does not exist: ${src_input}")
    return 1
  fi

  src_abs="$(realpath -s -- "$src_input")"

  if ! is_inside_home "$src_abs"; then
    ERRORS+=("ERROR: source must be inside HOME (${HOME}): ${src_abs}")
    return 1
  fi

  if is_inside_repo_root "$src_abs"; then
    ERRORS+=("ERROR: source is already inside repo (${REPO_ROOT}), refusing to adopt: ${src_abs}")
    return 1
  fi

  if [[ "$src_abs" == "$HOME" ]]; then
    ERRORS+=("ERROR: refusing to adopt HOME root")
    return 1
  fi

  local base_name sync_repo_dir dst_name
  base_name="$(basename -- "$src_abs")"
  sync_repo_dir="$(sync_dir_for "$src_abs")"

  if [[ -n "$sync_repo_dir" ]]; then
    # Flat-sync dir (bin/, lib/): route into the repo dir, sanitizing the name.
    dst_name="$(sanitize_name "$sync_repo_dir" "$base_name")"
    dst_abs="${sync_repo_dir}/${dst_name}"
  else
    # Everything else mirrors under dotfiles/ at the same relative location.
    rel_path="${src_abs#"${HOME}"/}"
    dst_abs="${DOTFILES_DIR}/${rel_path}"
  fi
  dst_dir="$(dirname -- "$dst_abs")"

  debug "source: ${src_abs}"
  debug "dest:   ${dst_abs}"
  if [[ "$base_name" != "$(basename -- "$dst_abs")" ]]; then
    info "Sanitized name: ${base_name} -> $(basename -- "$dst_abs")"
  fi

  if [[ "$src_abs" == "$dst_abs" ]]; then
    WARNINGS+=("WARNING: source already inside repo path, skipping: ${src_abs}")
    return 0
  fi

  if [[ -e "$dst_abs" || -L "$dst_abs" ]]; then
    ERRORS+=("ERROR: destination already exists in repo: ${dst_abs}")
    return 1
  fi

  run_and_report mkdir -p -- "$dst_dir" || return 1
  run_and_report mv -- "$src_abs" "$dst_abs" || return 1

  MOVED+=("${dst_abs#"${REPO_ROOT}"/}")
  return 0
}

run_linker() {
  local -a link_args
  link_args+=("--verbose=${VERBOSE}")
  $DRY_RUN && link_args+=("--dry-run")
  run_and_report "$LINK_SCRIPT" "${link_args[@]}"
}

validate_basics || exit 1

for src in "${SOURCES[@]}"; do
  info "Adopting: ${src}"
  adopt_one "$src"
done

if (( ${#ERRORS[@]} > 0 )); then
  echo
  echo "Adoption failed with ${#ERRORS[@]} error(s):" >&2
  for e in "${ERRORS[@]}"; do
    echo "- ${e}" >&2
  done
  exit 1
fi

if (( ${#MOVED[@]} == 0 )); then
  echo "Nothing to adopt."
  exit 0
fi

info "Running linker to recreate symlinks in HOME ..."
run_linker || {
  echo "ERROR: linking step failed" >&2
  exit 1
}

if (( ${#WARNINGS[@]} > 0 )); then
  echo
  echo "Completed with ${#WARNINGS[@]} warning(s):" >&2
  for w in "${WARNINGS[@]}"; do
    echo "- ${w}" >&2
  done
fi

echo
if $DRY_RUN; then
  echo "Dry-run completed successfully."
else
  echo "Adoption + linking completed successfully."
fi
