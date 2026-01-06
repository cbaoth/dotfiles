#!/bin/bash

# Moves image files to the following directory structure based on EXIP rating and label (if present):
# <source-path>/<rating>/<label>/<source-filename>

# -e: exit on error
# -u: treat unset variables as an error
# -o pipefail: return exit code of the last command in the pipeline that failed
set -euo pipefail


# MANUAL DEV DEBUGING ONLY:
# debug whole script (even before parsing arguments)
# -v: print shell input lines as they are read
# -x: print commands and their arguments as they are executed
#set -vx

# Usage
_usage() {
  cat <<EOF
Usage: $(basename "$0") [options] <source-path> [<source-path> ...]

Organizes image files in the specified source directory/directories into
subdirectories based on their EXIF rating and label metadata.

Output directory structure: <source-path>/<rating>/<label>/<source-filename>

Arguments:
  source-path    Path(s) to the directory/directories containing image files to be organized

Options:
  -o, --output <dir>        Common target directory for all files (default: derive from each source path)
  -t, --types <ext1,ext2,...>  Comma-separated list of file extensions to process (default: jpg,jpeg,png,tiff,tif,cr2,dng)
  -i, --include-processed   Include files that are most likely already in rating output directories (default: skip them, simple regex-based detection: [0-5]/[A-Za-z0-9].../*)
  -f, --force               Force overwrite existing files in target directory (default: skip files that already exist)
  -c, --copy                Copy files instead of moving them (default: move)
  -n, --no-act, --dry-run   Show what would be done without making any changes
  -v, --verbose             Increase verbosity level (can be used multiple times)
  -h, --help                Show this help message and exit

Verbosity Levels:
  0: Only essential output
  1: Detailed operation steps
  2: Debug information
  3: Debug information with set -v enabled (shell input lines)
  4: Debug information with set -v and -x enabled (full command tracing)
EOF
}

# Parse arguments
[[ -n "${1:-}" ]] || { _usage; exit 1; }

VERBOSITY_LEVEL=0
NO_ACT="false"
INCLUDE_PROCESSED="false"
FORCE_OVERWRITE="false"
OPERATION="move"
FILE_TYPES=("jpg" "jpeg" "png" "tiff" "tif" "cr2" "dng")
TARGET_DIR=""
SOURCE_PATHS=()
while [[ $# -ge 1 ]]; do
  case $1 in
    -o|--output)
      [[ -n "${2:-}" ]] || {
        echo "Error: --output requires a directory path"
        exit 1
      }
      TARGET_DIR="$2"
      shift
      ;;
    -i|--include-processed)
      INCLUDE_PROCESSED="true"
      ;;
    -f|--force)
      FORCE_OVERWRITE="true"
      ;;
    -c|--copy)
      OPERATION="copy"
      ;;
    -t|--types)
      [[ -n "${2:-}" ]] || {
        echo "Error: --types requires a comma-separated list of file extensions"
        exit 1
      }
      IFS=',' read -r -a FILE_TYPES <<< "$2"
      shift
      ;;
    -n|--no-act|--dry-run)
      NO_ACT="true"
      ;;
    -v|-vv|-vvv)
      VERBOSITY_LEVEL=$((VERBOSITY_LEVEL + ${#1} - 1))
      ;;
    -h|--help)
      _usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1"
      exit 1
      ;;
    *)
      SOURCE_PATHS+=("$1")
  esac
  shift
done

[[ ${#SOURCE_PATHS[@]} -gt 0 ]] || { echo "Error: At least one source path is required"; exit 1; }

# Validate all source paths
for source_path in "${SOURCE_PATHS[@]}"; do
  [[ -d "$source_path" ]] || { echo "Error: Source path \"$source_path\" is not a directory"; exit 1; }
done

# Validate target directory if provided
if [[ -n "$TARGET_DIR" ]]; then
  # Create target directory if it doesn't exist (in non-dry-run mode)
  if [[ "$NO_ACT" != "true" ]]; then
    mkdir -p "$TARGET_DIR"
  fi
  [[ -d "$TARGET_DIR" ]] || { echo "Error: Target directory \"$TARGET_DIR\" is not a directory"; exit 1; }
fi
[[ $VERBOSITY_LEVEL -ge 3 ]] && set -v
[[ $VERBOSITY_LEVEL -ge 4 ]] && set -x

# Functions
_echo_verbose() {
  local level=$1
  shift
  if [[ $VERBOSITY_LEVEL -ge $level ]]; then
    echo -e "$@"
  fi
}

_get_exif_tag() {
  local tag=$1
  local default_value=$2
  local file=$3
  local tmp_err
  tmp_err=$(mktemp)
  local raw=""
  local status=0
  if ! raw=$(exiftool -s "-${tag}" "$file" 2>"$tmp_err"); then
    status=$?
  fi
  if [[ $VERBOSITY_LEVEL -ge 2 ]] && [[ -s "$tmp_err" ]]; then
    cat "$tmp_err" >&2
  fi
  rm -f "$tmp_err"
  local value=$(awk -F': ' '{print $2}' <<<"$raw")
  if [[ $status -ne 0 ]] || [[ -z "$value" ]]; then
    value="$default_value"
  fi
  printf '%s\n' "$value"
}

# Prepare file type find arguments
FILE_TYPES_LIST=(${FILE_TYPES[@]})
FILE_TYPES_ARGS=()
for ext in "${FILE_TYPES_LIST[@]}"; do
  FILE_TYPES_ARGS+=("-iname" "*.${ext}")
  FILE_TYPES_ARGS+=("-o")
done
# Remove trailing -o
unset 'FILE_TYPES_ARGS[${#FILE_TYPES_ARGS[@]}-1]'

# Process each source path
for SOURCE_PATH in "${SOURCE_PATHS[@]}"; do
  # Strip trailing slashes from source path
  SOURCE_PATH="${SOURCE_PATH%/}"

  _echo_verbose 0 "\nProcessing source directory: \"$SOURCE_PATH\" ..."

  # Determine base target directory for this source
  if [[ -n "$TARGET_DIR" ]]; then
    BASE_TARGET_DIR="${TARGET_DIR%/}"
  else
    BASE_TARGET_DIR="$SOURCE_PATH"
  fi

  # Build find command arguments
  FIND_ARGS=("$SOURCE_PATH" "-type" "f" "!" "-path" "*/.*")

  # Skip already-processed rating directories unless --include-processed is set
  if [[ "$INCLUDE_PROCESSED" == "false" ]]; then
    _echo_verbose 2 "Excluding already-processed rating directories from search ..."
    # Exclude paths matching: [0-5]/[A-Za-z0-9].../* (rating folders with typical labels)
    FIND_ARGS+=("!" "-regex" ".*/[0-5]/[a-zA-Z0-9].*/[^/]*")
  fi

  # Add file type filters
  FIND_ARGS+=("${FILE_TYPES_ARGS[@]}")

  # Iterate over known image files in source path
  found_any="false"
  while IFS= read -r f; do
    found_any="true"
    # Get EXIF rating and label
    _echo_verbose 2 "Reading EXIF data for \"$f\" ..."
    rating=$(_get_exif_tag Rating 0 "$f")
    label=$(_get_exif_tag Label None "$f")
    target_dir="$BASE_TARGET_DIR/$rating/$label"
    target_file="$target_dir/$(basename "$f")"
    # Check if source and target file are the same, skip if so (no need to move/copy file)
    if [[ "$(realpath "$f")" == "$(realpath -m "$target_file")" ]]; then
      _echo_verbose 1 "Skipping \"$f\": already in target location \"$target_file\" (nothing to do)"
      continue
    fi
    # Check if another file with same name exists in target directory, skip if so (unless --force)
    if [[ "$FORCE_OVERWRITE" == "false" ]] && [[ -e "$target_file" ]]; then
      _echo_verbose 0 "WARNING: Skipping \"$f\": target file \"$target_file\" already exists (use --force to overwrite)"
      continue
    fi
    # Determine operation command and action description
    if [[ "$OPERATION" == "copy" ]]; then
      COMMAND="cp"
      ACTION="Copying"
    else
      COMMAND="mv"
      ACTION="Moving"
    fi
    # Create target directory and move/copy file
    _echo_verbose 0 "$ACTION \"$f\" to \"$target_dir/\" ..."
    if [[ "$NO_ACT" == "true" ]]; then
      _echo_verbose 0 "[DRY RUN] mkdir -p \"$target_dir\""
      _echo_verbose 0 "[DRY RUN] $COMMAND \"$f\" \"$target_dir/\""
    else
      _echo_verbose 2 "> mkdir -p \"$target_dir\""
      mkdir -p "$target_dir"
      _echo_verbose 2 "> $COMMAND \"$f\" \"$target_dir/\""
      $COMMAND "$f" "$target_dir/"
    fi
  done < <(find "${FIND_ARGS[@]}")

  if [[ "$found_any" == "false" ]]; then
    FILE_TYPES_PRETTY=$(IFS=,; echo "${FILE_TYPES_LIST[*]}")
    echo "Warning: no matching files found in \"$SOURCE_PATH\" for extensions: ${FILE_TYPES_PRETTY}" >&2
  fi
done
