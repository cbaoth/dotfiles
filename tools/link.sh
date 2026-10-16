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
HOME_SRC="${REPO_ROOT}/home"
PROFILES_DIR="${TOOLS_DIR}/profiles"

# Root guard, checked before anything from the repo is sourced: root must only
# ever link (and later source) files no other user can modify. A repo owned by,
# or writable by, a regular user would hand that user root on the next login.
if (( EUID == 0 )); then
  _root_home="$(getent passwd 0 | cut -d: -f6)"
  if [[ "${HOME}" != "${_root_home}" ]]; then
    echo "error: running as root but HOME='${HOME}' is not root's home '${_root_home}'" \
         "(use 'sudo -i', not 'sudo' / 'sudo -E')" >&2
    exit 1
  fi
  # the repo itself, everything in it (incl. .git: hooks run on 'git pull'),
  # and every parent directory (a writable parent allows swapping the repo)
  _unsafe="$(find "${REPO_ROOT}" ! -type l \( ! -user 0 -o -perm /022 \) -print -quit)"
  _dir="${REPO_ROOT}"
  while [[ -z "${_unsafe}" && "${_dir}" != / ]]; do
    _dir="$(dirname -- "${_dir}")"
    _unsafe="$(find "${_dir}" -maxdepth 0 \( ! -user 0 -o -perm /022 \) -print)"
  done
  if [[ -n "${_unsafe}" ]]; then
    echo "error: running as root, but '${_unsafe}' is not owned by root or is" \
         "group/world writable. Root needs its own root-owned clone, e.g.:" >&2
    echo "  git clone https://github.com/cbaoth/dotfiles.git /root/dotfiles" >&2
    exit 1
  fi
  unset _root_home _unsafe _dir
fi

# Source linking configuration (repo_dir:home_dir sync pairs)
# shellcheck source=/dev/null
source "${TOOLS_DIR}/link-config.conf" || {
  echo "error: failed to source link-config.conf from ${TOOLS_DIR}" >&2
  exit 1
}
BACKUP_BASE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-link/backups"
BAKDIR="${BACKUP_BASE_DIR}/run-$(date +%Y%m%dT%H%M%S)"
KEEP_LAST_BAKS=10
BACKUP_DIR_READY=false
DRY_RUN=false
VERBOSE=0
PROFILE=""
UNLINK=false

# simple args parsing
usage() {
  echo "Usage: $(basename "$0") [--dry-run|-n] [-p|--profile NAME] [-u|--unlink] [-v|-vv|--verbose[=N]] [--help|-h]" >&2
  echo "  -n, --dry-run       Print changes, change nothing" >&2
  echo "  -u, --unlink        Link nothing; remove every symlink that points into this repo" >&2
  echo "                      (incl. systemd enable links, i.e. disables those units)" >&2
  echo "  -p, --profile NAME  Link only what tools/profiles/NAME.list allows" >&2
  echo "                      (default: 'root' when run as root, else everything)" >&2
  echo "  -v                  Increase verbosity (info)" >&2
  echo "  -vv                 Increase verbosity more (debug)" >&2
  echo "  --verbose=N         Set verbosity level explicitly (0=quiet,1=info,2=debug)" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -u|--unlink)
      UNLINK=true
      shift
      ;;
    -p|--profile)
      [[ -n "${2:-}" ]] || { echo "error: $1 requires a profile name" >&2; usage; exit 2; }
      PROFILE="$2"
      shift 2
      ;;
    --profile=*)
      PROFILE="${1#*=}"
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

# safety check before we create wrong links (-e: .git is a file in a worktree)
[ ! -e "${REPO_ROOT}/.git" ] \
  && echo "error: .git not found in ${REPO_ROOT}, this doesn't seem to be the right folder" \
  && exit 1
[ ! -d "${HOME_SRC}" ] \
  && echo "error: home/ directory not found: ${HOME_SRC}" \
  && exit 1

# Validate that config was sourced correctly
if [[ ${#SYNC_DIRS[@]} -eq 0 ]]; then
  echo "error: SYNC_DIRS not populated (config sourcing failed)" >&2
  exit 1
fi

for _sync_src in "${!SYNC_DIRS[@]}"; do
  [ ! -d "${_sync_src}" ] \
    && echo "error: repo sync source directory not found: ${_sync_src}" \
    && exit 1
done
unset _sync_src

# Profile: an allowlist of repo-relative globs (tools/profiles/NAME.list), one
# per line, '#' comments. Matched with [[ == ]], so '*' also crosses '/'. Root
# always gets a profile: default-deny, a new file reaches root only when listed.
(( EUID == 0 )) && [[ -z "${PROFILE}" ]] && PROFILE=root
typeset -a PROFILE_GLOBS=()
typeset -A PROFILE_HITS=()
if [[ -n "${PROFILE}" ]]; then
  _profile_file="${PROFILES_DIR}/${PROFILE}.list"
  [[ -f "${_profile_file}" ]] \
    || { echo "error: profile not found: ${_profile_file}" >&2; exit 1; }
  while IFS= read -r _glob; do
    _glob="${_glob%%#*}"
    _glob="${_glob%"${_glob##*[![:space:]]}"}"
    _glob="${_glob#"${_glob%%[![:space:]]*}"}"
    [[ -n "${_glob}" ]] && PROFILE_GLOBS+=("${_glob}")
  done < "${_profile_file}"
  (( ${#PROFILE_GLOBS[@]} > 0 )) \
    || { echo "error: profile is empty: ${_profile_file}" >&2; exit 1; }
  unset _profile_file _glob
fi

# predicate: is the repo-relative path allowed by the active profile (if any)?
in_profile() {
  local path="$1" glob
  [[ -z "${PROFILE}" ]] && return 0
  for glob in "${PROFILE_GLOBS[@]}"; do
    # shellcheck disable=SC2053  # unquoted on purpose: glob match
    if [[ "${path}" == ${glob} ]]; then
      PROFILE_HITS["${glob}"]=1
      return 0
    fi
  done
  return 1
}

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

# LINK_DIRS (link-config.conf): directories linked as a whole; exclude them
# (and their contents) from the per-file scan below
typeset -a LINK_DIRS_EXCLUDE=()
typeset -a LINK_DIRS_ACTIVE=()
for _ld in "${LINK_DIRS[@]}"; do
  LINK_DIRS_EXCLUDE+=(! -path "${HOME_SRC}/${_ld}" ! -path "${HOME_SRC}/${_ld}/*")
  in_profile "home/${_ld}" || continue
  [[ -d "${HOME_SRC}/${_ld}" ]] \
    || { echo "error: LINK_DIRS entry not a directory in home/: ${_ld}" >&2; exit 1; }
  LINK_DIRS_ACTIVE+=("${_ld}")
done
unset _ld

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

# Collect every symlink pointing into this repo, valid or dangling, into
# REPO_LINKS (link -> normalized target). Candidates: the direct children of
# every directory mirrored from home/ (any depth), of the SYNC_DIRS home dirs
# and of the systemd user *.wants/*.requires dirs, plus $HOME down to
# PRUNE_SCAN_DEPTH for directories no longer in the repo. The repo itself and
# the backups are skipped.
typeset -A REPO_LINKS=()
collect_repo_links() {
  local -A candidates=()
  local -a dirs=()
  local dir rel link link_target

  while IFS= read -r -d '' dir; do
    rel="$(realpath -s --relative-to "$HOME_SRC" "$dir")"
    if [[ "$rel" == "." ]]; then dirs+=("$HOME"); else dirs+=("${HOME}/${rel}"); fi
  done < <(find "$HOME_SRC" -type d "${LINK_DIRS_EXCLUDE[@]}" -print0)
  dirs+=("${SYNC_DIRS[@]}")
  for dir in "${HOME}/.config/systemd/user/"*.wants "${HOME}/.config/systemd/user/"*.requires; do
    dirs+=("$dir")
  done

  for dir in "${dirs[@]}"; do
    [[ -d "$dir" && ! -L "$dir" ]] || continue
    while IFS= read -r -d '' link; do
      candidates["$link"]=1
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -type l -print0)
  done
  while IFS= read -r -d '' link; do
    candidates["$link"]=1
  done < <(find "$HOME" -xdev -maxdepth "${PRUNE_SCAN_DEPTH:-3}" \
             \( -path "$REPO_ROOT" -o -path "$BACKUP_BASE_DIR" \) -prune \
             -o -type l -print0)

  REPO_LINKS=()
  for link in "${!candidates[@]}"; do
    link_target="$(readlink -- "$link")" || continue
    [[ "$link_target" == /* ]] || link_target="$(dirname -- "$link")/${link_target}"
    link_target="$(realpath -ms -- "$link_target")"
    [[ "$link_target" == "${REPO_ROOT}/"* ]] && REPO_LINKS["$link"]="$link_target"
  done
}

# predicate: is this a systemd enable link? `systemctl --user enable` on a unit
# file that is itself a symlink into the repo points the link it creates (in
# a *.wants/*.requires dir, or an alias/instance name like sb-sync@x.timer ->
# sb-sync@.timer) straight at the repo file, so it dangles after a repo move.
is_unit_enable_link() {
  local link="$1" link_target="$2" parent
  [[ "$link" == "${HOME}/.config/systemd/"* ]] || return 1
  parent="$(dirname -- "$link")"
  [[ "$parent" == *.wants || "$parent" == *.requires ]] && return 0
  [[ "$(basename -- "$link")" != "$(basename -- "$link_target")" ]]
}

# Remove a symlink, announcing it (also in a dry run).
# Arguments: $1=link $2=description, e.g. "stale symlink (dangling)"
remove_link() {
  if $DRY_RUN; then
    echo "Would remove $2: $1"
  else
    echo "Removing $2: $1"
  fi
  run_and_report rm -f -- "$1"
}

# --unlink: remove every symlink pointing into this repo (the HOME_SRC tree,
# bin/, lib/, LINK_DIRS, systemd enable links) plus the HOME_LINKS aliases.
# Nothing is restored from backups; empty directories are left in place.
unlink_repo_links() {
  local link relpath
  local -A units=()

  collect_repo_links
  for link in "${!REPO_LINKS[@]}"; do
    is_unit_enable_link "$link" "${REPO_LINKS[$link]}" && units["$(basename -- "$link")"]=1
    remove_link "$link" "repo symlink"
  done
  for relpath in "${!HOME_LINKS[@]}"; do
    link="${HOME}/${relpath}"
    [[ -L "$link" && "$(readlink -- "$link")" == "${HOME}/${HOME_LINKS[$relpath]}" ]] || continue
    remove_link "$link" "home link"
  done
  echo "Repo symlinks: ${#REPO_LINKS[@]}. Backups (not restored): ${BACKUP_BASE_DIR}"

  (( ${#units[@]} > 0 )) || return 0
  local msg="Removed systemd enable links, now disabled: ${!units[*]} (still"
  msg+=" running until: systemctl --user daemon-reload && systemctl --user stop ...)"
  WARNINGS+=("${msg}")
  echo -e "\e[33mWARNING: ${msg}\e[0m" >&2
}

# Report warnings/errors, drop an empty backup dir, rotate old backups, exit.
# Arguments: $1=verb for the summary ("Linking" | "Unlinking")
report_and_exit() {
  local verb="$1"
  if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo -e "\n\e[33m=== WARNINGS ===\e[0m" >&2
    echo -e "\e[33m${#WARNINGS[@]} warning(s)\e[0m occured while ${verb,,}, please check:" >&2
    for w in "${WARNINGS[@]}"; do
      echo -e "- \e[33m${w}\e[0m" >&2
    done
    echo -e "\e[33m================\e[0m" >&2
  fi
  if [ ${#ERRORS[@]} -gt 0 ]; then
    echo -e "\e[31m=== ERRORS ===\e[0m" >&2
    echo -e "\e[33m${#ERRORS[@]} error(s)\e[0m occured while ${verb,,}, please check:" >&2
    for e in "${ERRORS[@]}"; do
      echo -e "- \e[31m${e}\e[0m" >&2
    done
    echo -e "\e[31m==============\e[0m" >&2
    echo -e "\e[31m${verb} completed with errors!\e[0m" >&2
    echo -e "\e[31mPlease check the messages above. You may find backed up files in: $BAKDIR\e[0m" >&2
    echo -e "\e[31mExiting...\e[0m" >&2
    exit 1
  else
    if $DRY_RUN; then
      echo -e "\n\e[32mDry-run completed successfully. No changes were made.\e[0m"
    else
      echo -e "\n\e[32m${verb} completed successfully.\e[0m"
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
}

if $UNLINK; then
  unlink_repo_links
  report_and_exit "Unlinking"
fi

# $HOME links this run created or confirmed (home/ tree + LINK_DIRS); the prune
# step at the end removes repo links that are not in here
typeset -A EXPECTED_LINKS=()

# Use the pattern in the find command; avoid subshell so arrays persist
while IFS= read -r -d '' f; do
  # get relative target/source file location (-s: don't resolve symlinks, a
  # symlinked source must be linked at its logical location, not its target's)
  relpath=$(realpath -s --relative-to "$HOME_SRC" "$f")
  target=$HOME/$relpath
  # profile: files only; their parent dirs are created on demand below
  if [[ -n "${PROFILE}" ]]; then
    [[ -d "$f" ]] && continue
    in_profile "home/${relpath}" || { debug "Not in profile '${PROFILE}', skipping: $relpath"; continue; }
  fi
  [[ -d "$f" ]] || EXPECTED_LINKS["$target"]=1
  info ""
  info "Processing: $relpath -> $HOME/$relpath ..."
  info "SRC: $relpath"
  info "TAR: $target"
  #if [[ "$target" =~ "$HOME_SRC" ]]; then
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
    [[ -d "$(dirname -- "$target")" ]] || run_and_report mkdir -p -- "$(dirname -- "$target")"
    info "Creating new SymLink: '$f' -> '$target'"
      run_and_report ln -sf -- "$f" "$target"
  fi
done < <(find "$HOME_SRC" -regextype sed ${IGNORE_PATTERN:+! -regex "$IGNORE_PATTERN"} \
           "${LINK_DIRS_EXCLUDE[@]}" -print0)

# Link each LINK_DIRS directory as a single symlink. Runs after the per-file
# loop so the parent directory (e.g. ~/.config) already exists.
for relpath in "${LINK_DIRS_ACTIVE[@]}"; do
  src="${HOME_SRC}/${relpath}"
  target="${HOME}/${relpath}"
  EXPECTED_LINKS["$target"]=1
  info ""
  info "Processing directory link: $relpath -> $target ..."
  if [[ -L "$target" && "$(readlink "$target")" -ef "$src" ]]; then
    info "\e[32mOK: Correct directory symlink already exists (nothing to do), skipping ..\e[0m"
    continue
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    backup_existing "$target" "$relpath" " directory" " but is not the expected symlink" || continue
  fi
  run_and_report mkdir -p -- "$(dirname -- "$target")"
  info "Creating new directory SymLink: '$src' -> '$target'"
  run_and_report ln -sfn -- "$src" "$target"
done

# Link HOME_LINKS paths to other $HOME paths (e.g. ~/.emacs.d -> ~/.config/emacs).
# Runs after the loops above so the target directory already exists.
# Profile: only when the target itself (home/<target>) is listed, otherwise
# root would get a dangling link, or have a real ~/.emacs.d moved to backup.
for relpath in "${!HOME_LINKS[@]}"; do
  in_profile "home/${HOME_LINKS[$relpath]}" \
    || { debug "Not in profile '${PROFILE}', skipping home link: $relpath"; continue; }
  target="${HOME}/${relpath}"
  dest="${HOME}/${HOME_LINKS[$relpath]}"
  info ""
  info "Processing home link: $target -> $dest ..."
  if [[ -L "$target" && "$(readlink "$target")" -ef "$dest" ]]; then
    info "\e[32mOK: Correct home symlink already exists (nothing to do), skipping ..\e[0m"
    continue
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    backup_existing "$target" "$relpath" "" " but is not the expected symlink" || continue
  fi
  info "Creating new home SymLink: '$dest' -> '$target'"
  run_and_report ln -sfn -- "$dest" "$target"
done

# Sync flat files from a repo dir to a home dir: create symlinks for all files,
# remove stale links that pointed into the repo dir but no longer exist there.
# Arguments: $1=repo_dir $2=home_dir
sync_dir() {
  local repo_dir="$1"
  local home_dir="$2"
  local label
  label="$(basename "$repo_dir")"

  info ""
  info "Syncing repo ${label}/: ${repo_dir} -> ${home_dir} ..."
  run_and_report mkdir -p -- "$home_dir"

  typeset -A seen_names
  while IFS= read -r -d '' src_file; do
    # not in profile: skip, and leave it unseen so the stale-link cleanup
    # below removes an existing link (e.g. after switching profiles)
    if ! in_profile "${src_file#"${REPO_ROOT}/"}"; then
      debug "Not in profile '${PROFILE}', skipping: ${src_file#"${REPO_ROOT}/"}"
      continue
    fi
    local base_name
    base_name="$(basename "$src_file")"
    seen_names["$base_name"]=1

    local target_link="${home_dir}/${base_name}"
    if [[ -e "$target_link" || -L "$target_link" ]]; then
      if [[ -L "$target_link" && "$(readlink "$target_link")" -ef "$src_file" ]]; then
        debug "${label} sync: correct symlink already exists: $target_link"
        continue
      fi
      backup_existing "$target_link" "${label}/${base_name}" " symlink" \
        " but points to '$(readlink "$target_link" 2>/dev/null || printf "%s" "non-symlink")'" || continue
    fi

    info "Creating new SymLink: '$src_file' -> '$target_link'"
    run_and_report ln -sf -- "$src_file" "$target_link"
  done < <(find "$repo_dir" -mindepth 1 -maxdepth 1 -type f -print0)

  # remove stale links pointing into repo_dir that no longer exist there
  while IFS= read -r -d '' existing_link; do
    local link_target
    link_target="$(readlink "$existing_link" 2>/dev/null || true)"
    [[ -n "$link_target" ]] || continue

    if [[ "$link_target" != "${repo_dir}/"* ]]; then
      debug "${label} sync: preserving external/custom symlink: $existing_link -> $link_target"
      continue
    fi

    local base_name
    base_name="$(basename "$existing_link")"
    if [[ -z "${seen_names[$base_name]:-}" ]]; then
      info "Removing stale repo ${label} symlink: $existing_link"
      run_and_report rm -f -- "$existing_link"
    fi
  done < <(find "$home_dir" -mindepth 1 -maxdepth 1 -type l -print0)
}

for repo_dir in "${!SYNC_DIRS[@]}"; do
  sync_dir "$repo_dir" "${SYNC_DIRS[$repo_dir]}"
done

# Prune stale repo links (candidates: collect_repo_links). Only symlinks
# pointing into this repo are ever touched, and only when they are
# - dangling: the repo file was deleted, renamed or moved (incl. old repo
#   layouts, e.g. dotfiles/dotfiles/...), or
# - at their mirror location (~/X -> home/X) but not linked by this run: out
#   of profile, or now in .linkignore.
# Never systemd enable links (is_unit_enable_link): removing one silently
# disables its unit, so a dangling one is reported with the fix instead.
prune_tree_links() {
  local link link_target reason
  local -a stale_unit_links=()
  local -A stale_units=()

  collect_repo_links
  for link in "${!REPO_LINKS[@]}"; do
    [[ -n "${EXPECTED_LINKS[$link]:-}" ]] && continue
    link_target="${REPO_LINKS[$link]}"

    if [[ ! -e "$link" ]]; then
      if is_unit_enable_link "$link" "$link_target"; then
        stale_unit_links+=("$link")
        stale_units["$(basename -- "$link")"]=1
        continue
      fi
      reason="dangling"
    elif [[ "$link_target" == "${HOME_SRC}/"* \
            && "${link_target#"${HOME_SRC}/"}" == "${link#"${HOME}/"}" ]]; then
      reason="ignored"
      [[ -n "${PROFILE}" ]] && reason="not in profile ${PROFILE}, or ignored"
    else
      debug "Prune: keeping custom repo symlink: $link -> $link_target"
      continue
    fi
    remove_link "$link" "stale symlink (${reason})"
  done

  (( ${#stale_unit_links[@]} > 0 )) || return 0
  local msg="Dangling systemd enable link(s) into the repo, unit(s) will not start"
  msg+=" after the next reboot/daemon-reload: ${!stale_units[*]}"
  WARNINGS+=("${msg}")
  echo -e "\e[33mWARNING: ${msg}\e[0m" >&2
  echo -e "\e[33mFix (enable only; 'disable'/'reenable' would also delete the unit file link):\e[0m" >&2
  echo "  rm -- $(format_cmd "${stale_unit_links[@]}")" >&2
  echo "  systemctl --user daemon-reload" >&2
  echo "  systemctl --user enable $(format_cmd "${!stale_units[@]}")" >&2
}
prune_tree_links

# a profile glob that matched nothing is likely a renamed/deleted file
for _glob in "${PROFILE_GLOBS[@]}"; do
  if [[ -z "${PROFILE_HITS[${_glob}]:-}" ]]; then
    _msg="Profile '${PROFILE}': '${_glob}' matches no file (renamed or removed?)"
    WARNINGS+=("${_msg}")
    echo -e "\e[33mWARNING: ${_msg}\e[0m" >&2
  fi
done
unset _glob _msg

report_and_exit "Linking"
