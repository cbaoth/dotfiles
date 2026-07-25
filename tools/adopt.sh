#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash
#
# Move files/directories from $HOME into repo dotfiles/ and relink via tools/link.sh.

set -u

# constants
declare SCRIPT_NAME SCRIPT_FILE TOOLS_DIR REPO_ROOT DOTFILES_DIR LINK_SCRIPT
SCRIPT_NAME="$(basename "$0")"
SCRIPT_FILE="$(realpath "$0")"
TOOLS_DIR="$(dirname "$SCRIPT_FILE")"
REPO_ROOT="$(dirname "$TOOLS_DIR")"
DOTFILES_DIR="${REPO_ROOT}/dotfiles"
LINK_SCRIPT="${TOOLS_DIR}/link.sh"
declare -r SCRIPT_NAME SCRIPT_FILE TOOLS_DIR REPO_ROOT DOTFILES_DIR LINK_SCRIPT

# variables
declare DRY_RUN=false
declare -i VERBOSE=0
declare -a WARNINGS=()
declare -a ERRORS=()
declare -a SOURCES=()
declare -a MOVED=()

usage() {
  cat >&2 <<EOF
Usage: $SCRIPT_NAME [--dry-run|-n] [-v|-vv|--verbose[=N]] <path> [<path> ...]

Move each source path (must be inside \$HOME) into repo dotfiles/ at the same
relative location, then run tools/link.sh to create symlinks back.

Examples:
  $SCRIPT_NAME ~/.config/mimeapps.list
  $SCRIPT_NAME -n ~/.config/foo ~/.local/share/bar
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=true
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
  return 0
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

  rel_path="${src_abs#"${HOME}"/}"
  dst_abs="${DOTFILES_DIR}/${rel_path}"
  dst_dir="$(dirname -- "$dst_abs")"

  debug "source: ${src_abs}"
  debug "dest:   ${dst_abs}"

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

  MOVED+=("${rel_path}")
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
