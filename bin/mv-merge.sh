#!/bin/env bash

# mv-merge.sh: A script to recursively merge directories with various modes.
# Usage: ./mv-merge.sh [options] source_dir target_dir

set -e  # Exit on errors

# Help function
usage() {
  cat <<EOF
Usage: $0 [options] source_dir target_dir
Options:
  -n    No action mode: Preview changes without moving files
  -i    Interactive mode: Prompt for confirmation before each move
  -c    Create target directory if it does not exist
  -k    Keep source directory after moving files
EOF
  exit 1
}

# Define color codes
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Parse options
no_act=false
interactive=false
create_target=false
keep_source=false
while getopts "nick" opt; do
  case $opt in
    n) no_act=true ;;
    i) interactive=true ;;
    c) create_target=true ;;
    k) keep_source=true ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

# Validate arguments
if [ "$#" -ne 2 ]; then
  usage
fi

source_dir="$1"
target_dir="$2"
created_target_dir=false

if [ ! -d "$source_dir" ]; then
  echo -e "${RED}Error:${NC} Source directory '$source_dir' does not exist or is not a directory."
  exit 1
fi

if [ ! -d "$target_dir" ]; then
  if $create_target && ! $no_act; then
    echo "Target directory '$target_dir' does not exist. Creating it."
    mkdir -p "$target_dir"
    created_target_dir=true
  else
    echo -e "${RED}Error:${NC} Target directory '$target_dir' does not exist."
    exit 1
  fi
fi

echo "Processing: '$(realpath "$source_dir")' -> '$(realpath "$target_dir")'..."

# Define find and mv command based on no_act
_find="find \"$source_dir\" -type f"

echo "Moving files from '$source_dir/**/*' to '$target_dir'..."
if $no_act; then
  echo "Preview mode (-n): Listing actions without executing."
  _find="$_find -exec bash -c 'printf \"Would move: \\\"%s\\\" to \\\"%s\\\"\\n\" \"{}\" \"$target_dir/\$(echo \"{}\" | sed \"s#^$source_dir/##\")\"' _ \;"
elif $interactive; then
  echo "Interactive mode (-i): Confirm each move."
  _find="$_find -exec bash -c 'source_rel=\"\$(echo \"{}\" | sed \"s#^$source_dir/##\")\"; \
    target_path=\"$target_dir/\$source_rel\"; \
    mkdir -p \"\$(dirname \"\$target_path\")\"; \
    printf \"Move \\\"%s\\\" to \\\"%s\\\"? [y/N]: \" \"{}\" \"\$target_path\"; \
    read -n1 confirm; echo; \
    if [[ \"\$confirm\" =~ ^[yY]$ ]]; then mv \"{}\" \"\$target_path\"; else echo \"Skipped: \\\"{}\\\"\"; fi' _ \;"
else
  _find="$_find -exec bash -c 'source_rel=\"\$(echo \"{}\" | sed \"s#^$source_dir/##\")\"; \
    target_path=\"$target_dir/\$source_rel\"; \
    mkdir -p \"\$(dirname \"\$target_path\")\"; \
    mv \"{}\" \"\$target_path\"' _ \;"
fi

# Execute find and mv
bash -c "$_find"

# Clean up empty directories in source_dir if not in preview mode
if ! $no_act; then
  find "$source_dir" -type d -empty -delete
fi

# Remove source directory if not in keep_source mode
if ! $keep_source && ! $no_act; then
  if ! rmdir "$source_dir" 2>/dev/null; then
    if [ -d "$source_dir" ]; then
      echo -e "${YELLOW}Warning:${NC} Could not delete source directory '$source_dir'. It may not be empty."
    fi
  fi
fi

# Remove target directory if it was created by the script and is empty
if $created_target_dir && ! $no_act; then
  rmdir --ignore-fail-on-non-empty "$target_dir"
fi
