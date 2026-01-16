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
  --cache-file <file>       Cache file location (default: ${XDG_CACHE_HOME:-$HOME/.cache}/exif-move-to-rating-dirs/cache.tsv)
  --no-cache                Disable cache lookups and writes (default: use cache to skip unchanged files)
  -d, --remove-empty-source-dir  Remove empty source directory after moving a file (single level only)
  --min-rating <n>          Minimum EXIF rating threshold; skip files with rating < n (default: 0, no filter)
  --no-summary              Disable summary and statistics output at the end (default: show summary)
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
FILE_TYPES=("jpg" "jpeg" "png" "tiff" "tif" "cr2" "dng" "orf")
TARGET_DIR=""
SOURCE_PATHS=()
CACHE_ENABLED="true"
CACHE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/exif-move-to-rating-dirs/cache.tsv"
declare -A CACHE_MAP=()
CACHE_INITIAL_RECORDS=0
CACHE_INITIAL_SIZE=0
CACHE_FINAL_RECORDS=0
CACHE_FINAL_SIZE=0
SHOW_SUMMARY="true"
INTERRUPTED="false"
REMOVE_EMPTY_SOURCE_DIR="false"
MIN_RATING=0
STATS_MOVED=0
STATS_COPIED=0
STATS_SKIPPED_CACHED=0
STATS_SKIPPED_LOCATION=0
STATS_SKIPPED_EXISTS=0
STATS_SKIPPED_MIN_RATING=0
STATS_FILES_UNREADABLE=0
LAST_EXIF_TAG_STATUS=0
while [[ $# -ge 1 ]]; do
  case $1 in
    -o|--output)
      [[ -n "${2:-}" ]] || {
        echo -e "\033[31mERROR\033[0m: --output requires a directory path"
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
    --cache-file)
      [[ -n "${2:-}" ]] || {
        echo -e "\033[31mERROR\033[0m: --cache-file requires a file path"
        exit 1
      }
      CACHE_FILE="$2"
      shift
      ;;
    --no-cache)
      CACHE_ENABLED="false"
      ;;
    -d|--remove-empty-source-dir)
      REMOVE_EMPTY_SOURCE_DIR="true"
      ;;
    --min-rating)
      [[ -n "${2:-}" ]] || {
        echo -e "\033[31mERROR\033[0m: --min-rating requires a numeric value"
        exit 1
      }
      if ! [[ "${2:-}" =~ ^[0-9]+$ ]]; then
        echo -e "\033[31mERROR\033[0m: --min-rating value must be a non-negative integer"
        exit 1
      fi
      MIN_RATING="$2"
      shift
      ;;
    --no-summary)
      SHOW_SUMMARY="false"
      ;;
    -t|--types)
      [[ -n "${2:-}" ]] || {
        echo -e "\033[31mERROR\033[0m: --types requires a comma-separated list of file extensions"
        exit 1
      }
      IFS=',' read -r -a FILE_TYPES <<< "$2"
      shift
      ;;
    -n|--no-act|--dry-run)
      NO_ACT="true"
      ;;
    -v|-vv|-vvv|-vvvv)
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

[[ ${#SOURCE_PATHS[@]} -gt 0 ]] || { echo -e "\033[31mERROR\033[0m: At least one source path is required"; exit 1; }

# Validate all source paths
for source_path in "${SOURCE_PATHS[@]}"; do
  [[ -d "$source_path" ]] || { echo -e "\033[31mERROR\033[0m: Source path \"$source_path\" is not a directory"; exit 1; }
done

# Validate target directory if provided
if [[ -n "$TARGET_DIR" ]]; then
  # Create target directory if it doesn't exist (in non-dry-run mode)
  if [[ "$NO_ACT" != "true" ]]; then
    mkdir -p "$TARGET_DIR"
  fi
  [[ -d "$TARGET_DIR" ]] || { echo -e "\033[31mERROR\033[0m: Target directory \"$TARGET_DIR\" is not a directory"; exit 1; }
fi
[[ $VERBOSITY_LEVEL -ge 3 ]] && set -v
[[ $VERBOSITY_LEVEL -ge 4 ]] && set -x


# Signal handler for clean interruption (Ctrl-C)
_handle_sigint() {
  INTERRUPTED="true"
  echo -e "\n\033[33mWARNING\033[0m: Interrupted by user. Saving cache before exit..."
  _save_cache || echo -e "\033[33mWARNING\033[0m: Unable to write cache file to \"$CACHE_FILE\""
  echo "Cache saved. Exiting."
  exit 130
}

trap _handle_sigint SIGINT

# Functions
_echo_verbose() {
  local level=$1
  shift
  if [[ $VERBOSITY_LEVEL -ge $level ]]; then
    echo -e "$@"
  fi
  return 0
}

# Read a single EXIF tag, falling back to a default value on error/empty.
# Sets LAST_EXIF_TAG_STATUS to the exiftool exit code (0 = success, non-zero = failure)
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
  LAST_EXIF_TAG_STATUS=$status
  if [[ $VERBOSITY_LEVEL -ge 1 ]] && [[ -s "$tmp_err" ]]; then
    while IFS= read -r __exiftool_err_line; do
      echo -e "\033[90mexiftool (stderr)\033[0m: ${__exiftool_err_line}" >&2
    done <"$tmp_err"
  fi
  rm -f "$tmp_err"
  local value=$(awk -F': ' '{print $2}' <<<"$raw" 2>/dev/null || echo "")
  if [[ $status -ne 0 ]] || [[ -z "$value" ]]; then
    value="$default_value"
  fi
  printf '%s\n' "$value"
}

# Stable hash for cache identity.
_compute_file_hash() {
  local file=$1
  sha256sum "$file" | awk '{print $1}'
}

# mtime in epoch seconds for quick comparisons.
_get_file_mtime() {
  local file=$1
  stat -c %Y "$file"
}

# Size in bytes (0 when cache file is absent).
# Checks both compressed (.gz) and uncompressed versions.
_get_cache_size_bytes() {
  if [[ -f "${CACHE_FILE}.gz" ]]; then
    stat -c %s "${CACHE_FILE}.gz"
  elif [[ -f "$CACHE_FILE" ]]; then
    stat -c %s "$CACHE_FILE"
  else
    echo 0
    return 0
  fi
}

# Human readable size; falls back to raw bytes.
_human_size() {
  local bytes=$1
  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec --format "%.1f" "$bytes"
  else
    echo "${bytes}B"
  fi
}

# Capture baseline cache stats after loading.
_record_cache_baseline() {
  CACHE_INITIAL_RECORDS=${#CACHE_MAP[@]}
  CACHE_INITIAL_SIZE=$(_get_cache_size_bytes)
}

# Capture final cache stats for summary output.
_record_cache_final() {
  CACHE_FINAL_RECORDS=${#CACHE_MAP[@]}
  CACHE_FINAL_SIZE=$(_get_cache_size_bytes)
}

# Load persisted cache into memory (path -> hash|mtime).
# Supports both compressed (.gz) and uncompressed cache files.
_load_cache() {
  [[ "$CACHE_ENABLED" == "true" ]] || return 0

  local cache_to_read=""
  local use_compression="false"

  # Check for compressed cache first, then uncompressed
  if [[ -f "${CACHE_FILE}.gz" ]]; then
    cache_to_read="${CACHE_FILE}.gz"
    use_compression="true"
  elif [[ -f "$CACHE_FILE" ]]; then
    cache_to_read="$CACHE_FILE"
  else
    return 0
  fi

  # Check cache size and warn if very large (>50MB uncompressed)
  local cache_size
  cache_size=$(stat -c %s "$cache_to_read")
  local size_threshold=$((50 * 1024 * 1024))  # 50MB

  # For compressed files, estimate uncompressed size (rough estimate: 10x compression)
  if [[ "$use_compression" == "true" ]]; then
    local estimated_uncompressed=$((cache_size * 10))
    if [[ $estimated_uncompressed -gt $size_threshold ]]; then
      _echo_verbose 0 "WARNING: Cache file is very large (~$(_human_size $estimated_uncompressed) uncompressed). Loading may take some time."
    fi
  elif [[ $cache_size -gt $size_threshold ]]; then
    _echo_verbose 0 "WARNING: Cache file is very large ($(_human_size $cache_size)). Loading may take some time."
  fi

  # Read cache file (decompressing if needed)
  if [[ "$use_compression" == "true" ]]; then
    if ! command -v gunzip >/dev/null 2>&1; then
      _echo_verbose 0 "WARNING: gunzip not found, cannot read compressed cache. Rebuilding cache."
      return 0
    fi
    while IFS=$'\t' read -r path hash mtime; do
      [[ -z "$path" ]] && continue
      [[ "$path" =~ ^# ]] && continue
      CACHE_MAP["$path"]="$hash|$mtime"
    done < <(gunzip -c "$cache_to_read")
  else
    while IFS=$'\t' read -r path hash mtime; do
      [[ -z "$path" ]] && continue
      [[ "$path" =~ ^# ]] && continue
      CACHE_MAP["$path"]="$hash|$mtime"
    done <"$cache_to_read"
  fi

  return 0
}

# Write cache back to disk (sorted for stability) unless dry-run.
# Automatically compresses cache with gzip if available and file is large enough.
_save_cache() {
  [[ "$CACHE_ENABLED" == "true" ]] || return 0
  [[ "$NO_ACT" == "true" ]] && return 0
  local cache_dir
  cache_dir=$(dirname "$CACHE_FILE")
  mkdir -p "$cache_dir" || return 1
  local tmp
  tmp=$(mktemp)
  {
    for key in "${!CACHE_MAP[@]}"; do
      IFS='|' read -r hash mtime <<<"${CACHE_MAP[$key]}"
      printf "%s\t%s\t%s\n" "$key" "$hash" "$mtime"
    done
  } | LC_ALL=C sort >"$tmp"

  # Check if we should compress (file > 1MB and gzip available)
  local tmp_size
  tmp_size=$(stat -c %s "$tmp")
  local compress_threshold=$((1 * 1024 * 1024))  # 1MB

  if [[ $tmp_size -gt $compress_threshold ]] && command -v gzip >/dev/null 2>&1; then
    # Compress the cache
    gzip -c "$tmp" > "${CACHE_FILE}.gz.tmp" || {
      rm -f "$tmp" "${CACHE_FILE}.gz.tmp"
      return 1
    }
    mv "${CACHE_FILE}.gz.tmp" "${CACHE_FILE}.gz" || {
      rm -f "$tmp" "${CACHE_FILE}.gz.tmp"
      return 1
    }
    # Remove old uncompressed cache if it exists
    rm -f "$CACHE_FILE"
    _echo_verbose 1 "Cache compressed: $(_human_size $tmp_size) -> $(_human_size $(stat -c %s "${CACHE_FILE}.gz"))"
  else
    # Save uncompressed
    mv "$tmp" "$CACHE_FILE" || {
      rm -f "$tmp"
      return 1
    }
    # Remove old compressed cache if it exists
    rm -f "${CACHE_FILE}.gz"
  fi

  rm -f "$tmp"
  return 0
}

# Decide whether a file can be skipped based on unchanged hash+mtime.
# Returns 0 (true) if the file should be skipped, 1 (false) otherwise.
_should_skip_cached() {
  local file=$1
  [[ "$CACHE_ENABLED" == "true" ]] || return 1
  local canonical
  canonical=$(realpath "$file")
  [[ -n "${CACHE_MAP[$canonical]:-}" ]] || return 1
  local cached_hash cached_mtime
  IFS='|' read -r cached_hash cached_mtime <<<"${CACHE_MAP[$canonical]}"
  local current_mtime current_hash
  current_mtime=$(_get_file_mtime "$canonical")
  if [[ "$current_mtime" != "$cached_mtime" ]]; then
    return 1
  fi
  current_hash=$(_compute_file_hash "$canonical")
  if [[ "$current_hash" == "$cached_hash" ]]; then
    _echo_verbose 1 "Skipping \"$canonical\": unchanged since last processed (cache hit)"
    return 0
  fi
  return 1
}

# Remember a successfully processed file in the cache.
_remember_processed_file() {
  local file=$1
  [[ "$CACHE_ENABLED" == "true" ]] || return 0
  [[ "$NO_ACT" == "true" ]] && return 0
  local canonical
  canonical=$(realpath "$file")
  local mtime hash
  mtime=$(_get_file_mtime "$canonical")
  hash=$(_compute_file_hash "$canonical")
  if [[ -n "$hash" ]]; then
    CACHE_MAP["$canonical"]="$hash|$mtime"
  fi
  return 0
}

_load_cache
_record_cache_baseline

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
  DIR_FILES_SCANNED=0
  while IFS= read -r f; do
    # Stop immediately if interrupted
    if [[ "$INTERRUPTED" == "true" ]]; then
      break
    fi
    found_any="true"
    ((++DIR_FILES_SCANNED))
    if _should_skip_cached "$f"; then
      ((++STATS_SKIPPED_CACHED))
      continue
    fi
    # Get EXIF rating and label
    _echo_verbose 2 "Reading EXIF data for \"$f\" ..."
    rating=$(_get_exif_tag Rating 0 "$f")
    rating_status=$LAST_EXIF_TAG_STATUS
    label=$(_get_exif_tag Label None "$f")
    label_status=$LAST_EXIF_TAG_STATUS

    # Check if both exiftool calls failed for this file
    if [[ $rating_status -ne 0 ]] && [[ $label_status -ne 0 ]]; then
      _echo_verbose 0 "\033[33mWARNING\033[0m: Unable to read EXIF data for \"$f\" (exiftool failed for both Rating and Label)"
      ((++STATS_FILES_UNREADABLE))
      continue
    fi

    # Check if rating is below minimum threshold
    if [[ $rating -lt $MIN_RATING ]]; then
      _echo_verbose 1 "Skipping \"$f\": rating ($rating) is below minimum threshold ($MIN_RATING)"
      ((++STATS_SKIPPED_MIN_RATING))
      continue
    fi

    target_dir="$BASE_TARGET_DIR/$rating/$label"
    target_file="$target_dir/$(basename "$f")"
    # Check if source and target file are the same, skip if so (no need to move/copy file)
    if [[ "$(realpath "$f")" == "$(realpath -m "$target_file")" ]]; then
      _echo_verbose 1 "Skipping \"$f\": already in target location \"$target_dir\" (nothing to do)"
      ((++STATS_SKIPPED_LOCATION))
      # Even though we are skipping, we should still remember it in the cache in case it is processed again later
      _remember_processed_file "$f"   # target_file and f are the same here
      continue
    fi
    # Check if another file with same name exists in target directory, skip if so (unless --force)
    if [[ "$FORCE_OVERWRITE" == "false" ]] && [[ -e "$target_file" ]]; then
      _echo_verbose 0 "\033[33mWARNING\033[0m: Skipping \"$f\": target file \"$target_file\" already exists (use --force to overwrite)"
      ((++STATS_SKIPPED_EXISTS))
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
      # Optionally indicate removal of empty source directory (single level) after move
      if [[ "$REMOVE_EMPTY_SOURCE_DIR" == "true" ]] && [[ "$OPERATION" == "move" ]]; then
        src_dir=$(dirname "$f")
        _echo_verbose 0 "[DRY RUN] Would remove empty source directory: \"$src_dir\" (single level)"
      fi
      if [[ "$OPERATION" == "copy" ]]; then
        ((++STATS_COPIED))
      else
        ((++STATS_MOVED))
      fi
    else
      _echo_verbose 2 "> mkdir -p \"$target_dir\""
      mkdir -p "$target_dir"
      _echo_verbose 2 "> $COMMAND \"$f\" \"$target_dir/\""
      $COMMAND "$f" "$target_dir/"
      # Optionally remove empty source directory (single level) after move
      if [[ "$REMOVE_EMPTY_SOURCE_DIR" == "true" ]] && [[ "$OPERATION" == "move" ]]; then
        src_dir=$(dirname "$f")
        if [[ -d "$src_dir" ]]; then
          # Only attempt removal when directory is empty
          if [[ -z "$(ls -A "$src_dir" )" ]]; then
            _echo_verbose 1 "Removing empty source directory \"$src_dir\" ..."
            rmdir "$src_dir" || _echo_verbose 0 "\033[33mWARNING\033[0m: Failed to remove empty source directory \"$src_dir\""
          fi
        fi
      fi
      _remember_processed_file "$target_file"
      if [[ "$OPERATION" == "copy" ]]; then
        ((++STATS_COPIED))
      else
        ((++STATS_MOVED))
      fi
    fi
  done < <(find "${FIND_ARGS[@]}")

  # If interrupted, stop processing further source directories
  if [[ "$INTERRUPTED" == "true" ]]; then
    _echo_verbose 0 "Interrupted; stopping further directories."
    break
  fi

  if [[ "$found_any" == "false" ]]; then
    FILE_TYPES_PRETTY=$(IFS=,; echo "${FILE_TYPES_LIST[*]}")
    echo -e "\033[33mWARNING\033[0m: no matching files found in \"$SOURCE_PATH\" for extensions: ${FILE_TYPES_PRETTY}" >&2
  fi

  # Print per-directory scan summary only when multiple source paths are provided
  if [[ ${#SOURCE_PATHS[@]} -gt 1 ]]; then
    _echo_verbose 0 "Scanned ${DIR_FILES_SCANNED} file(s) in \"$SOURCE_PATH\" (count only; no action implied)"
  fi

  # Persist cache after each directory to avoid losing progress if interrupted
  _save_cache || _echo_verbose 0 "\033[33mWARNING\033[0m: Unable to write cache file to \"$CACHE_FILE\" after processing \"$SOURCE_PATH\""
done

# Save cache back to disk
_save_cache || echo -e "\033[33mWARNING\033[0m: Unable to write cache file to \"$CACHE_FILE\""
_record_cache_final

if [[ "$SHOW_SUMMARY" == "true" ]]; then
  echo ""
  echo "=== Summary ==="
  echo "Files moved:                       $STATS_MOVED"
  echo "Files copied:                      $STATS_COPIED"
  echo "Files skipped / cache hit:         $STATS_SKIPPED_CACHED"
  echo "Files skipped / already at target: $STATS_SKIPPED_LOCATION"
  echo "Files skipped / below min rating:  $STATS_SKIPPED_MIN_RATING"
  echo -e "Files skipped / target exists:     $STATS_SKIPPED_EXISTS $([[ $STATS_SKIPPED_EXISTS -gt 0 ]] && echo -e "\033[33mWARNING(S)\033[0m")"
  [[ $STATS_FILES_UNREADABLE -gt 0 ]] && echo -e "Files skipped / unable to read EXIF:    $STATS_FILES_UNREADABLE $([[ $STATS_FILES_UNREADABLE -gt 0 ]] && echo -e "\033[33mWARNING(S)\033[0m")"

  if [[ "$CACHE_ENABLED" == "true" ]]; then
    echo ""
    echo "=== Cache Statistics ==="
    size_delta=$((CACHE_FINAL_SIZE - CACHE_INITIAL_SIZE))
    records_delta=$((CACHE_FINAL_RECORDS - CACHE_INITIAL_RECORDS))
    size_delta_abs=${size_delta#-}
    records_delta_abs=${records_delta#-}
    [[ $size_delta -ge 0 ]] && size_delta_str="+" || size_delta_str="-"
    [[ $records_delta -ge 0 ]] && records_delta_str="+${records_delta}" || records_delta_str="-${records_delta_abs}"
    human_initial_size=$(_human_size "$CACHE_INITIAL_SIZE")
    human_final_size=$(_human_size "$CACHE_FINAL_SIZE")
    human_delta_size=$(_human_size "$size_delta_abs")

    # Determine actual cache file name (compressed or not)
    actual_cache_file="$CACHE_FILE"
    compression_note=""
    if [[ -f "${CACHE_FILE}.gz" ]]; then
      actual_cache_file="${CACHE_FILE}.gz"
      compression_note=" (compressed)"
    fi

    echo "Cache file: ${actual_cache_file}${compression_note}"
    echo "Records:    ${CACHE_INITIAL_RECORDS} -> ${CACHE_FINAL_RECORDS} (${records_delta_str})"
    echo "Size:       ${human_initial_size} -> ${human_final_size} (${size_delta_str}${human_delta_size})"
  fi
fi

exit 0
