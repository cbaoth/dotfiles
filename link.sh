#!/usr/bin/env bash
# links.sh: symlink dotfiles from git repo to home directory

# Author:   Andreas Weyer <dev@cbaoth.de>
# Keywords: bash shell-script

# TODO
# - Skip existing links that already point to the right destination
# - Provide more appropriate blacklist
# - Add override/custom structure, instead of (mandatory) deployment of custom (e.g. host specific) files

LINK_FILE=$(realpath $0)
DOTFILES=$(dirname $LINK_FILE)
BAKDIR=$HOME/dotfiles_bak_$(date +%s)
KEEP_LAST_BAKS=1
DEBUG=false
#DEBUG=true
DRY_RUN=false

# simple args parsing
usage() {
  echo "Usage: $(basename "$0") [--dry-run|-n] [--help|-h]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)
      DRY_RUN=true
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

cd "$DOTFILES"
# safety check before we create wrong links
[ ! -d ".git" ] \
  && echo "error: .git not found, this doesn't seem to be the right folder" \
  && exit 1

# create backup dir (skipped in dry-run)
run_and_report() {
  local cmd="$1"
  if $DRY_RUN; then
    echo -e "\e[34mDRY-RUN: would run: $cmd\e[0m"
    return 0
  fi
  echo -e "\e[34m$cmd\e[0m"
  eval "$cmd"
  local rc=$?
  if [ $rc -ne 0 ]; then
    local msg="ERROR: Command failed with exit code $rc: $cmd"
    ERRORS+=("$msg")
    echo -e "> \e[31m${msg}\e[0m" >&2
  fi
  return $rc
}

run_and_report "mkdir -p \"$BAKDIR\""

# Define the ignore file
IGNORE_FILE=".linkignore"

# Read the ignore file and create a regex pattern
IGNORE_PATTERN=$(grep -vE "^\s*#" "$IGNORE_FILE" | sed ':a;N;$!ba;s/\n/\\|/g')
IGNORE_PATTERN=".*/\($(basename $0)\|\.linkignore\|${IGNORE_PATTERN}\)\(/.*\)\?"
$DEBUG && echo "Global Ignore Pattern ($IGNORE_FILE): $IGNORE_PATTERN"

typeset -a WARNINGS
typeset -a ERRORS

backup_existing() {
  local target="$1"
  local relpath="$2"
  local type="${3:-}"
  local reason="${4:-}"
  local targetbak="$BAKDIR/$relpath"
  local msg="Target${type} '$target' exists${reason}, moving to backup '$targetbak'"
  WARNINGS+=("$msg")
  echo -e "\e[33mWARNING: ${msg}\e[0m" >&2
  run_and_report "mkdir -p \"$BAKDIR/\`dirname $relpath\`\""
  run_and_report "mv \"$target\" \"$targetbak\""
}

# Use the pattern in the find command; avoid subshell so arrays persist
while IFS= read -r -d '' f; do
  # get relative target/source file location
  relpath=$(realpath --relative-to "$DOTFILES" "$f")
  target=$HOME/$relpath
  echo
  echo "Processing: $relpath -> $HOME/$relpath ..."
  $DEBUG && echo "SRC: $relpath"
  $DEBUG && echo "TAR: $target"
  #if [[ "$target" =~ "$DOTFILES" ]]; then
  #  echo "ERROR: target location inside dotfiles git repository, skipping: $target" >&2
  #  continue
  #fi
  #rmExistingLink "$target"
  if [ -d "$f" ]; then # is dir?
    [ "$relpath" = "." ] && continue
    if [ -e "$target" ]; then # target exists?
      if [ ! -d "$target" ]; then
        backup_existing "$target" "$relpath" " directory" " but is not a directory"
      elif [ -L "$target" ]; then
        backup_existing "$target" "$relpath" " directory" " but is a symlink"
      else
        echo -e "\e[32mOK: Correct directory already exists, skipping (nothing to do): $target\e[0m"
        continue
      fi
    fi
    $DEBUG && echo "Creating directory: '$target'"
    run_and_report "mkdir -p \"$target\""
  else
    if [ -e "$target" ]; then # target exists?
      # is a link pointing to the desired target?
      if [[ -L "$target" && "$(readlink $target)" -ef "$f" ]]; then
        echo -e "\e[32mOK: Correct symlink already exists (nothing to do), skipping ..\e[0m"
        continue
      fi
      if [[ -L "$target" ]]; then
        backup_existing "$target" "$relpath" " symlink" " but points to '$(readlink $target)'"
      elif [[ -f "$target" ]]; then
        backup_existing "$target" "$relpath" " file" " but is a regular file instead of symlink"
      fi
    fi
    $DEBUG && echo "Creating new SymLink: '$f' -> '$target'"
    run_and_report "ln -sf \"$f\" \"$target\""
  fi
done < <(find "$DOTFILES" -regextype sed ! -regex "$IGNORE_PATTERN" -print0)

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
run_and_report "rmdir --ignore-fail-on-non-empty \"$BAKDIR\""

# Delete all but the latest dofiles backup $HOME/dotfiles_bak_$(date +%s)
typeset -a EXISTING_BAKS
EXISTING_BAKS=$(find $HOME -maxdepth 1 -type d -name "dotfiles_bak_*" | sort -r | tail -n +$((KEEP_LAST_BAKS + 1)))
if [ -z "$EXISTING_BAKS" ]; then
  $DEBUG && echo "Cleanup: No outdated backup directories found (always keeping last $KEEP_LAST_BAKS), skipping cleanup."
else
  echo "Cleanup: Removing ${#EXISTING_BAKS[@]} outdated backup directories (\$KEEP_LAST_BAKS=$KEEP_LAST_BAKS) ..."
  for d in $EXISTING_BAKS; do
    $DEBUG && echo "Cleanup: Removing outdated backup directory: $d"
    run_and_report "rm -rf \"$d\""
  done
  echo "Cleanup: Done."
fi

exit 0
