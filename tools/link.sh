#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash
#
# Symlink repository dotfiles into the home directory.

# TODO
# - Skip existing links that already point to the right destination
# - Provide more appropriate blacklist
# - Add override/custom structure, instead of (mandatory) deployment of custom (e.g. host specific) files

LINK_FILE=$(realpath "$0")
TOOLS_DIR=$(dirname "$LINK_FILE")
REPO_ROOT=$(dirname "$TOOLS_DIR")
DOTFILES="${REPO_ROOT}/dotfiles"
REPO_BIN_DIR="${REPO_ROOT}/bin"
HOME_BIN_DIR="$HOME/bin"
BACKUP_BASE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-link/backups"
BAKDIR="${BACKUP_BASE_DIR}/run-$(date +%Y%m%dT%H%M%S)"
KEEP_LAST_BAKS=10
BACKUP_DIR_READY=false
DRY_RUN=false
VERBOSE=0

# simple args parsing
usage() {
  echo "Usage: $(basename "$0") [--dry-run|-n] [-v|-vv|--verbose[=N]] [--help|-h]" >&2
  echo "  -v             Increase verbosity (info)" >&2
  echo "  -vv            Increase verbosity more (debug)" >&2
  echo "  --verbose=N    Set verbosity level explicitly (0=quiet,1=info,2=debug)" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -vv)
      VERBOSE=$((VERBOSE+2))
      shift
      ;;
    -v|--verbose)
      VERBOSE=$((VERBOSE+1))
      shift
      ;;
    --verbose=*)
      val="${1#*=}"
      if [[ "$val" =~ ^[0-9]+$ ]]; then
        VERBOSE=$val
      else
        VERBOSE=1
      fi
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

# cap verbosity at reasonable maximum
(( VERBOSE > 3 )) && VERBOSE=3

# logging helpers
vlog() { # usage: vlog <level> <message...>
  local lvl="$1"; shift
  (( VERBOSE >= lvl )) && echo -e "$@"
}
info() { vlog 1 "$@"; }
debug() { vlog 2 "$@"; }

# safety check before we create wrong links
[ ! -d "${REPO_ROOT}/.git" ] \
  && echo "error: .git not found in ${REPO_ROOT}, this doesn't seem to be the right folder" \
  && exit 1
[ ! -d "${DOTFILES}" ] \
  && echo "error: dotfiles directory not found: ${DOTFILES}" \
  && exit 1
[ ! -d "${REPO_BIN_DIR}" ] \
  && echo "error: repo bin directory not found: ${REPO_BIN_DIR}" \
  && exit 1

# format command arguments for display
format_cmd() {
  local output=""
  local arg

  for arg in "$@"; do
    printf -v output '%s%q ' "$output" "$arg"
  done
  printf "%s" "${output% }"
}

# create backup dir lazily (skipped in dry-run)
run_and_report() {
  if $DRY_RUN; then
    info "\e[34mDRY-RUN: would run: $(format_cmd "$@")\e[0m"
    return 0
  fi
  info "\e[34m$(format_cmd "$@")\e[0m"
  "$@"
  local rc=$?
  if [ $rc -ne 0 ]; then
    local msg
    msg="ERROR: Command failed with exit code $rc: $(format_cmd "$@")"
    ERRORS+=("$msg")
    echo -e "> \e[31m${msg}\e[0m" >&2
  fi
  return $rc
}

ensure_backup_dir() {
  if $BACKUP_DIR_READY; then
    return 0
  fi

  run_and_report mkdir -p -- "$BAKDIR" || return 1
  BACKUP_DIR_READY=true
  return 0
}

# Define the ignore file
IGNORE_FILE="${TOOLS_DIR}/.linkignore"

# Read the ignore file and create a regex pattern
IGNORE_ENTRIES=$(grep -vE "^\s*#|^\s*$" "$IGNORE_FILE" | sed ':a;N;$!ba;s/\n/\\|/g')
if [[ -n "${IGNORE_ENTRIES}" ]]; then
  IGNORE_PATTERN=".*/\(${IGNORE_ENTRIES}\)\(/.*\)\?"
else
  IGNORE_PATTERN=""
fi
debug "Global Ignore Pattern (${IGNORE_FILE}): ${IGNORE_PATTERN}"

typeset -a WARNINGS
typeset -a ERRORS

backup_existing() {
  local target="$1"
  local relpath="$2"
  local type="${3:-}"
  local reason="${4:-}"
  local targetbak="$BAKDIR/$relpath"
  local targetbak_dir
  targetbak_dir="$(dirname -- "$targetbak")"
  local msg="Target${type} '$target' exists${reason}, moving to backup '$targetbak'"
  WARNINGS+=("$msg")
  echo -e "\e[33mWARNING: ${msg}\e[0m" >&2

  ensure_backup_dir || return 1
  run_and_report mkdir -p -- "$targetbak_dir" || return 1
  run_and_report mv -- "$target" "$targetbak" || return 1
  return 0
}

# Use the pattern in the find command; avoid subshell so arrays persist
while IFS= read -r -d '' f; do
  # get relative target/source file location
  relpath=$(realpath --relative-to "$DOTFILES" "$f")
  target=$HOME/$relpath
  info ""
  info "Processing: $relpath -> $HOME/$relpath ..."
  info "SRC: $relpath"
  info "TAR: $target"
  #if [[ "$target" =~ "$DOTFILES" ]]; then
  #  echo "ERROR: target location inside dotfiles git repository, skipping: $target" >&2
  #  continue
  #fi
  #rmExistingLink "$target"
  if [ -d "$f" ]; then # is dir?
    [ "$relpath" = "." ] && continue
    if [ -e "$target" ]; then # target exists?
        if [ ! -d "$target" ]; then
          backup_existing "$target" "$relpath" " directory" " but is not a directory" || continue
        elif [ -L "$target" ]; then
          backup_existing "$target" "$relpath" " directory" " but is a symlink" || continue
      else
        info "\e[32mOK: Correct directory already exists, skipping (nothing to do): $target\e[0m"
        continue
      fi
    fi
    info "Creating directory: '$target'"
      run_and_report mkdir -p -- "$target"
  else
    if [ -e "$target" ]; then # target exists?
      # is a link pointing to the desired target?
        if [[ -L "$target" && "$(readlink "$target")" -ef "$f" ]]; then
        info "\e[32mOK: Correct symlink already exists (nothing to do), skipping ..\e[0m"
        continue
      fi
      if [[ -L "$target" ]]; then
          backup_existing "$target" "$relpath" " symlink" " but points to '$(readlink "$target")'" || continue
      elif [[ -f "$target" ]]; then
          backup_existing "$target" "$relpath" " file" " but is a regular file instead of symlink" || continue
      fi
    fi
    info "Creating new SymLink: '$f' -> '$target'"
      run_and_report ln -sf -- "$f" "$target"
  fi
done < <(find "$DOTFILES" -regextype sed ${IGNORE_PATTERN:+! -regex "$IGNORE_PATTERN"} -print0)

# synchronize top-level repo bin/ -> ~/bin symlinks
info ""
info "Syncing repo bin scripts: ${REPO_BIN_DIR} -> ${HOME_BIN_DIR} ..."
run_and_report mkdir -p -- "$HOME_BIN_DIR"

typeset -A BIN_BASENAMES
while IFS= read -r -d '' src_file; do
  base_name="$(basename "$src_file")"
  BIN_BASENAMES["$base_name"]=1

  target_link="${HOME_BIN_DIR}/${base_name}"
  if [[ -e "$target_link" || -L "$target_link" ]]; then
    if [[ -L "$target_link" && "$(readlink "$target_link")" -ef "$src_file" ]]; then
      debug "bin sync: correct symlink already exists: $target_link"
      continue
    fi
    backup_existing "$target_link" "bin/${base_name}" " symlink" " but points to '$(readlink "$target_link" 2>/dev/null || printf "%s" "non-symlink")'" || continue
  fi

  info "Creating new SymLink: '$src_file' -> '$target_link'"
  run_and_report ln -sf -- "$src_file" "$target_link"
done < <(find "$REPO_BIN_DIR" -mindepth 1 -maxdepth 1 -type f -print0)

# remove stale ~/bin links that point into this repo's bin/ but no longer exist there
while IFS= read -r -d '' existing_link; do
  link_target="$(readlink "$existing_link" 2>/dev/null || true)"
  [[ -n "$link_target" ]] || continue

  # Only manage links that target this repository's bin directory.
  if [[ "$link_target" != "${REPO_BIN_DIR}/"* ]]; then
    debug "bin sync: preserving external/custom symlink: $existing_link -> $link_target"
    continue
  fi

  base_name="$(basename "$existing_link")"
  if [[ -z "${BIN_BASENAMES[$base_name]:-}" ]]; then
    info "Removing stale repo bin symlink: $existing_link"
    run_and_report rm -f -- "$existing_link"
  fi
done < <(find "$HOME_BIN_DIR" -mindepth 1 -maxdepth 1 -type l -print0)

# report all warnings and errors (if any)
if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo -e "\n\e[33m=== WARNINGS ===\e[0m" >&2
  echo -e "\e[33m${#WARNINGS[@]} warning(s)\e[0m occured while linking, please check:" >&2
  for w in "${WARNINGS[@]}"; do
    echo -e "- \e[33m${w}\e[0m" >&2
  done
  echo -e "\e[33m================\e[0m" >&2
fi
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo -e "\e[31m=== ERRORS ===\e[0m" >&2
  echo -e "\e[33m${#ERRORS[@]} error(s)\e[0m occured while linking, please check:" >&2
  for e in "${ERRORS[@]}"; do
    echo -e "- \e[31m${e}\e[0m" >&2
  done
  echo -e "\e[31m==============\e[0m" >&2
  echo -e "\e[31mLinking completed with errors!\e[0m" >&2
  echo -e "\e[31mPlease check the messages above. You may find backed up files in: $BAKDIR\e[0m" >&2
  echo -e "\e[31mExiting...\e[0m" >&2
  exit 1
else
  if $DRY_RUN; then
    echo -e "\n\e[32mDry-run completed successfully. No changes were made.\e[0m"
  else
    echo -e "\n\e[32mLinking completed successfully.\e[0m"
  fi
fi
echo

# Remove backup dir if empty (skipped in dry-run)
if $BACKUP_DIR_READY; then
  run_and_report rmdir --ignore-fail-on-non-empty "$BAKDIR"
fi

# Delete all but the latest backup directories in the state dir.
typeset -a EXISTING_BAKS=()
if [[ -d "$BACKUP_BASE_DIR" ]]; then
  while IFS= read -r d; do
    EXISTING_BAKS+=("$d")
  done < <(find "$BACKUP_BASE_DIR" -mindepth 1 -maxdepth 1 -type d -name 'run-*' | sort -r | tail -n +$((KEEP_LAST_BAKS + 1)))
fi

if (( ${#EXISTING_BAKS[@]} == 0 )); then
  debug "Cleanup: No outdated backup directories found (always keeping last $KEEP_LAST_BAKS), skipping cleanup."
else
  info "Cleanup: Removing ${#EXISTING_BAKS[@]} outdated backup directories (\$KEEP_LAST_BAKS=$KEEP_LAST_BAKS) ..."
  for d in "${EXISTING_BAKS[@]}"; do
    debug "Cleanup: Removing outdated backup directory: $d"
    run_and_report rm -rf -- "$d"
  done
  info "Cleanup: Done."
fi

exit 0
