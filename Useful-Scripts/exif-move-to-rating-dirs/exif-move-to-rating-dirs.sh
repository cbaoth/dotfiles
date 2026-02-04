#!/bin/bash

# Moves image files to the following directory structure based on EXIP rating and label (if present):
# <source-path>/<rating>/<label>/<source-filename>

# {{{ = COMMONS ==============================================================
# -e: exit on error
# -u: treat unset variables as an error
# -o pipefail: return exit code of the last command in the pipeline that failed
set -euo pipefail

# MANUAL DEV DEBUGING ONLY:
# debug whole script (even before parsing arguments)
# -v: print shell input lines as they are read
# -x: print commands and their arguments as they are executed
#set -vx

# -e: exit on error
# -u: treat unset variables as an error
# -o pipefail: return exit code of the last command in the pipeline that failed
set -euo pipefail  # Fail if any command in a pipeline fails

# Logging function with timestamp and colored levels
__log() {
  local level="$1"; shift
  local msg="$*"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local timestamp_log
  [[ -n "$LOGFILE" ]] && timestamp_log=$(date -Ins)

  case "$level" in
    E|ERR|ERROR)
      echo -e "$timestamp [\033[31mERROR\033[0m] $msg" >&2
      [[ -n "$LOGFILE" ]] && echo "$timestamp_log ERROR: $msg" >> "$LOGFILE" 2>/dev/null || true
      ;;
    W|WAR|WARN)
      echo -e "$timestamp [\033[33mWARN\033[0m]  $msg" >&2
      [[ -n "$LOGFILE" ]] && echo "$timestamp_log WARN : $msg" >> "$LOGFILE" 2>/dev/null || true
      ;;
    I|INF|INFO)
      [[ "$VERBOSITY" -lt 1 ]] && return 0  # Skip info messages if verbosity < 1
      echo -e "$timestamp [\033[32mINFO\033[0m]  $msg" >&2
      [[ -n "$LOGFILE" ]] && echo "$timestamp_log INFO : $msg" >> "$LOGFILE" 2>/dev/null || true
      ;;
    D|DEB|DEBUG)
      [[ "$VERBOSITY" -lt 2 ]] && return 0  # Skip debug messages if verbosity < 2
      echo -e "$timestamp [\033[34mDEBUG\033[0m] $msg" >&2
      [[ -n "$LOGFILE" ]] && echo "$timestamp_log DEBUG: $msg" >> "$LOGFILE" 2>/dev/null || true
      ;;
    *)
      echo -e "$timestamp [*]     $msg"
      [[ -n "$LOGFILE" ]] && echo "$timestamp_log *    : $msg" >> "$LOGFILE" 2>/dev/null || true
      ;;
  esac
}
# Convenience wrappers
_log()       { __log "" "$*"; }      # Always shown (no level)
_log_error() { __log "ERROR" "$*"; } # Always shown
_log_warn()  { __log "WARN"  "$*"; } # Always shown
_log_info()  { __log "INFO"  "$*"; } # Shown if VERBOSITY >= 1
_log_debug() { __log "DEBUG" "$*"; } # Shown if VERBOSITY >= 2

# Usage
_usage() {
  echo "Usage: $(basename "$0") [options] <source-path> [<source-path> ...]"
}

# Help
_help() {
  _usage
  cat <<EOF

Organizes image files in the specified source directory/directories into
subdirectories based on their EXIF rating and label metadata.

Output directory structure: <source-path>/<rating>/<label>/<source-filename>

Arguments:
  source-path    Path(s) to the directory/directories containing image files to be organized

Options:
  -t, --types <ext1,ext2,...>  Comma-separated list of file extensions to process (default: jpg,jpeg,png,tiff,tif,cr2,dng)
  -o, --output <dir>        Common target directory for all files (default: derive from each source path)
  -f, --force               Force overwrite existing files in target directory (default: skip files that already exist)
  -c, --copy                Copy files instead of moving them (default: move)
  --mapping-file <file>     Path to mapping file for directory remapping (space-separated, optional quotes for spaces)
  -d, --remove-empty-source-dir  Remove empty source directory after moving a file (single level only)
  --min-rating <n>          Minimum EXIF rating threshold; skip files with rating < n (default: 0, no filter)

  --cache-file <file>       Cache file location (default: ${XDG_CACHE_HOME:-$HOME/.cache}/exif-move-to-rating-dirs/cache.tsv.gz)
  --cache-strategy <strategy>  Cache lookup strategy (default: multi)
                            Options: path (absolute path only), hash (content hash), relpath (relative path), multi (all strategies)
  --cache-relpath-levels <n>  Number of directory levels for relpath strategy (default: 2, range: 1-10)
  --no-cache                Disable cache lookups and writes
  --skip-cached             Skip files found in cache based on chosen strategy without verifying file changes
                            Faster but may miss updated files; use with caution

  --no-summary              Disable summary and statistics output at the end (default: show summary)
  -n, --no-act, --dry-run   Show what would be done without making any changes
  -v, --verbose             Increase verbosity level (can be used multiple times)
  -h, --help                Show this help message and exit

Caching:
  Enabled by default to speed up repeated runs.
  Caches file hash, mtime, EXIF Rating, Label, and relative path.
  Cache file is always compressed with gzip (.gz extension).
  Cache is saved on normal exit and on interruption (Ctrl-C).

  Cache Strategies:
    path     - Lookup by absolute file path (fastest when most file locations/names unchanged, works after file content changes)
    hash     - Lookup by content hash (slower but works after moves/renames, no caching used after file content changes)
    relpath  - Lookup by relative path (similar to path but risk of collisions if filenames are not unique, configurable depth, good for reorganized directories)
    multi    - Try all strategies in order: path -> hash -> relpath (default, recommended, best flexibility)

  Use --skip-cached to skip files already in cache without verifying changes.
  This is faster but risky: files edited in-place won't be detected.
  Use --no-cache to disable caching entirely.

Mapping File Format:
  Space-separated pattern and target directory (one per line).
  Patterns can use regex (e.g., 5/(Purple|Blue)) or literal strings (e.g., 5/Purple).
  Optional quotes (single or double) for values containing spaces.
  Comments start with #; blank lines are ignored.
  Patterns are evaluated top-to-bottom; first match wins.
  Place specific patterns before general catch-all patterns.
  Supports regex group substitution: use \$1, \$2, etc. in target for captured groups.
  Example:
    5/Purple 5
    5/(Blue|Purple) 5
    5/(.*) keep-\$1          # 5/Purple -> keep-Purple
    ([0-5])/.* rating-\$1    # 3/Blue -> rating-3
    5/.* 4                  # Catch-all for other 5/* labels

Verbosity Levels:
  0: Only essential output
  1: Detailed operation steps
  2: Debug information
  3: Debug information with set -v enabled (shell input lines)
  4: Debug information with set -v and -x enabled (full command tracing)
EOF
}
# {{{ = COMMONS ==============================================================

# {{{ = ARGUMENT PARSING =====================================================
# Ensure at least one argument is provided
[[ -n "${1:-}" ]] || { _usage; exit 1; }

# Global variables with default values
VERBOSITY=0
LOGFILE=""
NO_ACT="false"
# TODO remove this? this seems inappropriate, especially with mapping files
#INCLUDE_PROCESSED="false"
FORCE_OVERWRITE="false"
OPERATION="move"
FILE_TYPES=("jpg" "jpeg" "png" "tiff" "tif" "cr2" "dng" "orf")
TARGET_DIR=""
SOURCE_PATHS=()
CACHE_ENABLED="true"
SKIP_CACHED_COMPLETELY="false"
CACHE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/exif-move-to-rating-dirs/cache.tsv"
CACHE_STRATEGY="multi"  # Options: path, hash, relpath, multi
CACHE_RELPATH_LEVELS=2  # Number of directory levels for relpath strategy
declare -A CACHE_MAP=()  # Primary index: absolute path -> cache value
declare -A CACHE_MAP_HASH=()  # Secondary index: hash -> cache value
declare -A CACHE_MAP_RELPATH=()  # Secondary index: relpath -> cache value
CACHE_INITIAL_RECORDS=0
CACHE_INITIAL_SIZE=0
CACHE_FINAL_RECORDS=0
CACHE_FINAL_SIZE=0
SHOW_SUMMARY="true"
INTERRUPTED="false"
REMOVE_EMPTY_SOURCE_DIR="false"
MIN_RATING=0
MAPPING_FILE=""
declare -a MAPPING_PATTERNS=()
declare -a MAPPING_TARGETS=()
STATS_MOVED=0
STATS_COPIED=0
STATS_SKIPPED_CACHED=0
STATS_SKIPPED_LOCATION=0
STATS_SKIPPED_EXISTS=0
STATS_SKIPPED_MIN_RATING=0
STATS_FILES_UNREADABLE=0
STATS_CACHE_HIT_PATH=0
STATS_CACHE_HIT_HASH=0
STATS_CACHE_HIT_RELPATH=0
STATS_CACHE_MISS=0
STATS_COLLISIONS_HASH=0
STATS_COLLISIONS_RELPATH=0
LAST_EXIF_TAG_STATUS=0
# Cache for current file's hash to avoid redundant computations
CURRENT_FILE_PATH=""
CURRENT_FILE_HASH=""

# Parse cli arguments
while [[ $# -ge 1 ]]; do
  case $1 in
    -o|--output)
      [[ -n "${2:-}" ]] || {
        _log_error "--output requires a directory path"
        exit 1
      }
      TARGET_DIR="$2"
      shift
      ;;
    # TODO remove this? this seems inappropriate, especially with mapping files
    # -i|--include-processed)
    #   INCLUDE_PROCESSED="true"
    #   ;;
    -f|--force)
      FORCE_OVERWRITE="true"
      ;;
    -c|--copy)
      OPERATION="copy"
      ;;
    --cache-file)
      [[ -n "${2:-}" ]] || {
        _log_error "--cache-file requires a file path"
        exit 1
      }
      CACHE_FILE="$2"
      shift
      ;;
    --cache-strategy)
      [[ -n "${2:-}" ]] || {
        _log_error "--cache-strategy requires a strategy (path, hash, relpath, or multi)"
        exit 1
      }
      case "${2,,}" in
        path|hash|relpath|multi)
          CACHE_STRATEGY="${2,,}"
          ;;
        *)
          _log_error "Invalid cache strategy: $2. Valid options: path, hash, relpath, multi"
          exit 1
          ;;
      esac
      shift
      ;;
    --cache-relpath-levels)
      [[ -n "${2:-}" ]] || {
        _log_error "--cache-relpath-levels requires a numeric value"
        exit 1
      }
      if ! [[ "${2:-}" =~ ^[0-9]+$ ]]; then
        _log_error "--cache-relpath-levels value must be a positive integer"
        exit 1
      fi
      if [[ "$2" -lt 1 || "$2" -gt 10 ]]; then
        _log_error "--cache-relpath-levels must be between 1 and 10"
        exit 1
      fi
      CACHE_RELPATH_LEVELS="$2"
      shift
      ;;
    --no-cache)
      CACHE_ENABLED="false"
      ;;
    --skip-cached)
      SKIP_CACHED_COMPLETELY="true"
      ;;
    -d|--remove-empty-source-dir)
      REMOVE_EMPTY_SOURCE_DIR="true"
      ;;
    --min-rating)
      [[ -n "${2:-}" ]] || {
        _log_error "--min-rating requires a numeric value"
        exit 1
      }
      if ! [[ "${2:-}" =~ ^[0-9]+$ ]]; then
        _log_error "--min-rating value must be a non-negative integer"
        exit 1
      fi
      MIN_RATING="$2"
      shift
      ;;
    --mapping-file)
      [[ -n "${2:-}" ]] || {
        _log_error "--mapping-file requires a file path"
        exit 1
      }
      MAPPING_FILE="$2"
      shift
      ;;
    --no-summary)
      SHOW_SUMMARY="false"
      ;;
    -t|--types)
      [[ -n "${2:-}" ]] || {
        _log_error "--types requires a comma-separated list of file extensions"
        exit 1
      }
      IFS=',' read -r -a FILE_TYPES <<< "$2"
      shift
      ;;
    -l|--logfile)
      [[ -z "$2" ]] && _log_error "--logfile requires a file path" && exit 1
      LOGFILE="$2"; shift
    ;;
    -n|--no-act|--dry-run)
      NO_ACT="true"
      ;;
    -v|-vv|-vvv|-vvvv)
      VERBOSITY=$((VERBOSITY + ${#1} - 1))
      ;;
    -h|--help)
      _help
      exit 0
      ;;
    -*)
      _log_error "Unknown option: $1"
      exit 1
      ;;
    *)
      SOURCE_PATHS+=("$1")
  esac
  shift
done

[[ ${#SOURCE_PATHS[@]} -gt 0 ]] || { _log_error "At least one source path is required"; exit 1; }

# Validate all source paths
for source_path in "${SOURCE_PATHS[@]}"; do
  [[ -d "$source_path" ]] || { _log_error "Source path \"$source_path\" is not a directory"; exit 1; }
done

# Validate target directory if provided
if [[ -n "$TARGET_DIR" ]]; then
  # Create target directory if it doesn't exist (in non-dry-run mode)
  if [[ "$NO_ACT" != "true" ]]; then
    mkdir -p "$TARGET_DIR"
  fi
  [[ -d "$TARGET_DIR" ]] || { _log_error "Target directory \"$TARGET_DIR\" is not a directory"; exit 1; }
fi
[[ $VERBOSITY -ge 3 ]] && set -v
[[ $VERBOSITY -ge 4 ]] && set -x
# }}} = ARGUMENT PARSING =====================================================

# {{{ = FUNCTION DEFINITIONS =================================================
# Signal handler for clean interruption (Ctrl-C)
_handle_sigint() {
  INTERRUPTED="true"
  _log_warn "Interrupted by user. Saving cache before exit..."
  _save_cache || _log_warn "Unable to write cache file to \"$CACHE_FILE\""
  _log "Cache saved. Exiting."
  exit 130
}
trap _handle_sigint SIGINT

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
  if [[ $VERBOSITY -ge 1 ]] && [[ -s "$tmp_err" ]]; then
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
# Caches the hash for the current file to avoid redundant computations.
_compute_file_hash() {
  local file=$1
  local canonical
  canonical=$(realpath "$file")

  # Check if we already computed hash for this file
  if [[ "$canonical" == "$CURRENT_FILE_PATH" ]] && [[ -n "$CURRENT_FILE_HASH" ]]; then
    _log_debug "Reusing cached hash for \"$canonical\""
    echo "$CURRENT_FILE_HASH"
    return 0
  fi

  # Compute hash and cache it
  _log_debug "Computing hash for \"$canonical\""
  local hash
  hash=$(sha256sum "$file" | awk '{print $1}')
  CURRENT_FILE_PATH="$canonical"
  CURRENT_FILE_HASH="$hash"
  echo "$hash"
}

# mtime in epoch seconds for quick comparisons.
_get_file_mtime() {
  local file=$1
  stat -c %Y "$file"
}

# Compute relative path for cache lookup (last N directory levels + filename)
# Example: _compute_relpath "/path/to/2024/Summer/IMG_1234.jpg" 2 -> "Summer/IMG_1234.jpg"
_compute_relpath() {
  local file=$1
  local levels=${2:-$CACHE_RELPATH_LEVELS}
  local canonical
  canonical=$(realpath "$file")

  # Split path into components
  local path_without_filename
  path_without_filename=$(dirname "$canonical")
  local filename
  filename=$(basename "$canonical")

  # Extract last N directory levels
  local relpath=""
  local remaining_path="$path_without_filename"
  local i

  for ((i=0; i<levels; i++)); do
    local dir_component
    dir_component=$(basename "$remaining_path")

    # Stop if we've reached the root
    if [[ "$dir_component" == "/" ]] || [[ -z "$dir_component" ]]; then
      break
    fi

    if [[ -z "$relpath" ]]; then
      relpath="$dir_component"
    else
      relpath="$dir_component/$relpath"
    fi

    remaining_path=$(dirname "$remaining_path")

    # Stop if we've reached the root
    if [[ "$remaining_path" == "/" ]]; then
      break
    fi
  done

  # Append filename
  if [[ -z "$relpath" ]]; then
    echo "$filename"
  else
    echo "$relpath/$filename"
  fi
}

# Lookup cache entry using configured strategy with fallback chain
# Returns cache value (hash|mtime|rating|label|relpath) or empty string
# Sets global variable LAST_CACHE_LOOKUP_STRATEGY to indicate which strategy succeeded
_lookup_cache_entry() {
  local file=$1
  local canonical
  canonical=$(realpath "$file")

  # Try primary lookup: absolute path (always fastest)
  if [[ -n "${CACHE_MAP[$canonical]:-}" ]]; then
    LAST_CACHE_LOOKUP_STRATEGY="path"
    STATS_CACHE_HIT_PATH=$((STATS_CACHE_HIT_PATH + 1))
    echo "${CACHE_MAP[$canonical]}"
    return 0
  fi

  # If strategy is 'path' only, stop here
  [[ "$CACHE_STRATEGY" == "path" ]] && {
    LAST_CACHE_LOOKUP_STRATEGY=""
    STATS_CACHE_MISS=$((STATS_CACHE_MISS + 1))
    return 1
  }

  # Try secondary lookups based on strategy
  case "$CACHE_STRATEGY" in
    hash|multi)
      # Hash-based lookup (expensive: requires hash computation)
      local hash
      hash=$(_compute_file_hash "$canonical")
      if [[ -n "${CACHE_MAP_HASH[$hash]:-}" ]]; then
        LAST_CACHE_LOOKUP_STRATEGY="hash"
        STATS_CACHE_HIT_HASH=$((STATS_CACHE_HIT_HASH + 1))
        echo "${CACHE_MAP_HASH[$hash]}"
        return 0
      fi

      # If strategy is 'hash' only, stop here
      [[ "$CACHE_STRATEGY" == "hash" ]] && {
        LAST_CACHE_LOOKUP_STRATEGY=""
        STATS_CACHE_MISS=$((STATS_CACHE_MISS + 1))
        return 1
      }
      ;;&  # Fall through to next case if multi

    relpath|multi)
      # Relpath-based lookup
      local relpath
      relpath=$(_compute_relpath "$canonical" "$CACHE_RELPATH_LEVELS")
      if [[ -n "${CACHE_MAP_RELPATH[$relpath]:-}" ]]; then
        LAST_CACHE_LOOKUP_STRATEGY="relpath"
        STATS_CACHE_HIT_RELPATH=$((STATS_CACHE_HIT_RELPATH + 1))
        echo "${CACHE_MAP_RELPATH[$relpath]}"
        return 0
      fi
      ;;
  esac

  # No match found
  LAST_CACHE_LOOKUP_STRATEGY=""
  STATS_CACHE_MISS=$((STATS_CACHE_MISS + 1))
  return 1
}

# Size in bytes (0 when cache file is absent).
# Always checks for compressed .gz version.
_get_cache_size_bytes() {
  if [[ -f "${CACHE_FILE}.gz" ]]; then
    stat -c %s "${CACHE_FILE}.gz"
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

# Load persisted cache into memory.
# Always expects compressed .gz format. Builds secondary indices based on cache strategy.
_load_cache() {
  [[ "$CACHE_ENABLED" == "true" ]] || return 0

  local cache_to_read="${CACHE_FILE}.gz"

  # Check if cache file exists
  if [[ ! -f "$cache_to_read" ]]; then
    _log_debug "No cache file found at \"$cache_to_read\""
    return 0
  fi

  # Check if gzip is available
  if ! command -v gunzip >/dev/null 2>&1; then
    _log_warn "gunzip not found, cannot read cache. Cache disabled for this run."
    CACHE_ENABLED="false"
    return 0
  fi

  # Check cache size and warn if very large (>50MB compressed)
  local cache_size
  cache_size=$(stat -c %s "$cache_to_read")
  local size_threshold=$((50 * 1024 * 1024))  # 50MB

  if [[ $cache_size -gt $size_threshold ]]; then
    _log_warn "Cache file is very large ($(_human_size $cache_size) compressed). Loading may take some time."
  fi

  _log_debug "Loading cache from \"$cache_to_read\" ..."

  # Read cache file and build indices
  local line_count=0
  while IFS=$'\t' read -r path hash mtime rating label relpath; do
    ((++line_count))

    # Skip empty lines and comments
    [[ -z "$path" || "$path" =~ ^# ]] && continue

    # Validate mandatory fields
    if [[ -z "$hash" || -z "$mtime" ]]; then
      _log_warn "Corrupt cache entry at line $line_count for path \"$path\" (hash and/or mtime missing), skipping ..."
      continue
    fi

    # Old cache format (5 fields) - missing relpath, compute it
    if [[ -z "$relpath" ]]; then
      if [[ -f "$path" ]]; then
        relpath=$(_compute_relpath "$path" "$CACHE_RELPATH_LEVELS")
        _log_debug "Old cache format detected, computed relpath for \"$path\": \"$relpath\""
      else
        _log_debug "Old cache format detected, but file \"$path\" not found, skipping relpath index"
        relpath=""
      fi
    fi

    # Build cache value
    local cache_value="$hash|$mtime|${rating}|${label}|${relpath}"

    # Primary index: absolute path
    CACHE_MAP["$path"]="$cache_value"

    # Secondary indices based on strategy
    case "$CACHE_STRATEGY" in
      hash|multi)
        # Hash index
        if [[ -n "${CACHE_MAP_HASH[$hash]:-}" ]]; then
          STATS_COLLISIONS_HASH=$((STATS_COLLISIONS_HASH + 1))
          _log_debug "Hash collision detected: $hash (keeping first entry)"
        else
          CACHE_MAP_HASH["$hash"]="$cache_value"
        fi
        ;;&  # Fall through if multi

      relpath|multi)
        # Relpath index (only if relpath is present)
        if [[ -n "$relpath" ]]; then
          if [[ -n "${CACHE_MAP_RELPATH[$relpath]:-}" ]]; then
            STATS_COLLISIONS_RELPATH=$((STATS_COLLISIONS_RELPATH + 1))
            _log_debug "Relpath collision detected: $relpath (keeping first entry)"
          else
            CACHE_MAP_RELPATH["$relpath"]="$cache_value"
          fi
        fi
        ;;
    esac
  done < <(gunzip -c "$cache_to_read")

  _log_debug "Loaded ${#CACHE_MAP[@]} cache entries"
  [[ "$CACHE_STRATEGY" =~ hash|multi ]] && _log_debug "Hash index: ${#CACHE_MAP_HASH[@]} entries"
  [[ "$CACHE_STRATEGY" =~ relpath|multi ]] && _log_debug "Relpath index: ${#CACHE_MAP_RELPATH[@]} entries"
  [[ $STATS_COLLISIONS_HASH -gt 0 ]] && _log_debug "Hash collisions: $STATS_COLLISIONS_HASH"
  [[ $STATS_COLLISIONS_RELPATH -gt 0 ]] && _log_debug "Relpath collisions: $STATS_COLLISIONS_RELPATH"

  return 0
}

# Write cache back to disk (sorted for stability) unless dry-run.
# Always compresses with gzip.
_save_cache() {
  [[ "$CACHE_ENABLED" == "true" ]] || return 0
  [[ "$NO_ACT" == "true" ]] && return 0

  # Check if gzip is available
  if ! command -v gzip >/dev/null 2>&1; then
    _log_warn "gzip not found, cannot save cache."
    return 1
  fi

  local cache_dir
  cache_dir=$(dirname "$CACHE_FILE")
  mkdir -p "$cache_dir" || return 1

  local tmp
  tmp=$(mktemp)

  # Write all cache entries to temp file
  {
    for key in "${!CACHE_MAP[@]}"; do
      IFS='|' read -r hash mtime rating label relpath <<<"${CACHE_MAP[$key]}"
      printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$key" "$hash" "$mtime" "${rating:-}" "${label:-}" "${relpath:-}"
    done
  } | LC_ALL=C sort >"$tmp"

  # Compress and save
  local tmp_size
  tmp_size=$(stat -c %s "$tmp")

  if ! gzip -c "$tmp" > "${CACHE_FILE}.gz.tmp"; then
    rm -f "$tmp" "${CACHE_FILE}.gz.tmp"
    return 1
  fi

  if ! mv "${CACHE_FILE}.gz.tmp" "${CACHE_FILE}.gz"; then
    rm -f "$tmp" "${CACHE_FILE}.gz.tmp"
    return 1
  fi

  local compressed_size
  compressed_size=$(stat -c %s "${CACHE_FILE}.gz")

  _log_debug "Cache saved: $(_human_size $tmp_size) -> $(_human_size $compressed_size) (compressed)"

  rm -f "$tmp"
  return 0
}

# Decide whether a file can be skipped based on cache.
# Returns 0 (true) if the file should be skipped, 1 (false) otherwise.
_should_skip_cached() {
  [[ "$CACHE_ENABLED" == "true" ]] || return 1

  local file=$1
  local cache_value

  # Try to find cache entry using configured strategy
  if ! cache_value=$(_lookup_cache_entry "$file"); then
    _log_debug "No cache entry found for \"$file\""
    return 1
  fi

  # Extract cached data
  local cached_hash cached_mtime
  IFS='|' read -r cached_hash cached_mtime _ _ _ <<<"$cache_value"

  # If --skip-cached is enabled, skip immediately without verification
  if [[ "$SKIP_CACHED_COMPLETELY" == "true" ]]; then
    _log_debug "Skipping \"$file\" based on cache (--skip-cached enabled, strategy: $LAST_CACHE_LOOKUP_STRATEGY, no verification)"
    return 0
  fi

  # Otherwise, verify that file hasn't changed
  local canonical
  canonical=$(realpath "$file")

  # Check mtime first (fast)
  local current_mtime
  current_mtime=$(_get_file_mtime "$canonical")
  if [[ "$current_mtime" != "$cached_mtime" ]]; then
    _log_debug "No cache match for \"$file\" (mtime changed: cached=$cached_mtime, current=$current_mtime)"
    return 1
  fi

  # Check hash (slow)
  local current_hash
  current_hash=$(_compute_file_hash "$canonical")
  if [[ "$current_hash" != "$cached_hash" ]]; then
    _log_debug "No cache match for \"$file\" (hash changed: cached=$cached_hash, current=$current_hash)"
    return 1
  fi

  # Skip: file is unchanged
  _log_debug "Skipping \"$file\" based on cache (strategy: $LAST_CACHE_LOOKUP_STRATEGY, mtime and hash match)"
  return 0
}

# Get cached EXIF data (rating and label) for an unchanged file.
# Outputs "rating|label" if file is cached and unchanged, empty string otherwise.
_get_cached_exif() {
  local file=$1
  [[ "$CACHE_ENABLED" == "true" ]] || return 1

  local cache_value

  # Try to find cache entry using configured strategy
  if ! cache_value=$(_lookup_cache_entry "$file"); then
    return 1
  fi

  # Extract cached data
  local cached_hash cached_mtime cached_rating cached_label
  IFS='|' read -r cached_hash cached_mtime cached_rating cached_label _ <<<"$cache_value"

  # If no cached rating/label, file was cached in old format - need to read EXIF
  [[ -z "$cached_rating" ]] && return 1

  # Optimization: check mtime first (fast), only compute hash (slow) if mtime matches
  local canonical
  canonical=$(realpath "$file")

  local current_mtime
  current_mtime=$(_get_file_mtime "$canonical")
  if [[ "$current_mtime" != "$cached_mtime" ]]; then
    _log_debug "Cache mtime mismatch for \"$file\" (strategy: $LAST_CACHE_LOOKUP_STRATEGY)"
    return 1
  fi

  # Mtime matches, now verify hash
  local current_hash
  current_hash=$(_compute_file_hash "$canonical")
  if [[ "$current_hash" == "$cached_hash" ]]; then
    _log_debug "Cache hit for \"$file\" (strategy: $LAST_CACHE_LOOKUP_STRATEGY, rating=$cached_rating, label=$cached_label)"
    echo "${cached_rating}|${cached_label}"
    return 0
  fi

  _log_debug "Cache hash mismatch for \"$file\" (strategy: $LAST_CACHE_LOOKUP_STRATEGY)"
  return 1
}

# Remember a successfully processed file in the cache.
_remember_processed_file() {
  local file=$1
  local rating=${2:-}
  local label=${3:-}
  [[ "$CACHE_ENABLED" == "true" ]] || return 0
  [[ "$NO_ACT" == "true" ]] && return 0

  local canonical
  canonical=$(realpath "$file")

  local mtime hash relpath
  mtime=$(_get_file_mtime "$canonical")
  hash=$(_compute_file_hash "$canonical")
  relpath=$(_compute_relpath "$canonical" "$CACHE_RELPATH_LEVELS")

  if [[ -n "$hash" ]]; then
    CACHE_MAP["$canonical"]="$hash|$mtime|${rating:-}|${label:-}|${relpath:-}"
  fi

  return 0
}

# Load and parse the mapping file (space-separated format with optional quotes)
# Populates MAPPING_PATTERNS and MAPPING_TARGETS arrays
_load_mapping_file() {
  local mapping_file="$1"

  # Check if file exists
  if [[ ! -f "$mapping_file" ]]; then
    _log_warn "Mapping file not found: \"$mapping_file\""
    return 1
  fi

  _log_info "Loading mapping file: \"$mapping_file\""

  local line_no=0

  while IFS= read -r line; do
    ((++line_no))

    # Skip empty lines and comments
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    # Remove leading/trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    # Parse using regex to handle both quoted and unquoted values
    local pattern target

    # Check if line starts with a quote
    if [[ "$line" =~ ^[\"\'](.+?)[\"\'][[:space:]]+(.*) ]]; then
      # Quoted pattern: "pattern" target (or 'pattern' target)
      pattern="${BASH_REMATCH[1]}"
      target="${BASH_REMATCH[2]}"
      # Remove quotes from target if present
      if [[ "$target" =~ ^[\"\'](.+?)[\"\']$ ]]; then
        target="${BASH_REMATCH[1]}"
      else
        # Target might be unquoted; trim any whitespace
        target="${target#"${target%%[![:space:]]*}"}"
      fi
    elif [[ "$line" =~ ^([^[:space:]]+)[[:space:]]+(.*) ]]; then
      # Unquoted pattern: split on first whitespace
      pattern="${BASH_REMATCH[1]}"
      target="${BASH_REMATCH[2]}"
      # If target is quoted, remove the quotes
      if [[ "$target" =~ ^[\"\'](.+?)[\"\']$ ]]; then
        target="${BASH_REMATCH[1]}"
      fi
    else
      # No space found - invalid line
      pattern=""
      target=""
    fi

    # Validate we have both pattern and target
    if [[ -z "$pattern" ]] || [[ -z "$target" ]]; then
      _log_warn "Mapping file line $line_no: expected pattern and target (skipped)"
      continue
    fi

    MAPPING_PATTERNS+=("$pattern")
    MAPPING_TARGETS+=("$target")

    _log_debug "Loaded mapping: \"$pattern\" -> \"$target\""
  done <"$mapping_file"

  if [[ ${#MAPPING_PATTERNS[@]} -eq 0 ]]; then
    _log_warn "No valid mappings found in file: \"$mapping_file\""
    return 1
  fi

  _log_info "Loaded ${#MAPPING_PATTERNS[@]} mapping rule(s)"
  return 0
}

# Apply directory mapping: find first matching pattern and return mapped target
# Supports regex group substitution ($1, $2, etc.)
# Returns the mapped target on match, or the original source_pattern on no match
_apply_mapping() {
  local source_pattern="$1"  # e.g., "5/Purple"
  local i

  # If no mappings loaded, return original unchanged
  [[ ${#MAPPING_PATTERNS[@]} -eq 0 ]] && {
    echo "$source_pattern"
    return 0;
  }

  # Try matching each pattern (first match wins)
  for ((i=0; i<${#MAPPING_PATTERNS[@]}; i++)); do
    if [[ "$source_pattern" =~ ^${MAPPING_PATTERNS[$i]}$ ]]; then
      local target="${MAPPING_TARGETS[$i]}"

      # Save captured groups immediately after regex match (before BASH_REMATCH gets overwritten)
      local -a captured_groups=("${BASH_REMATCH[@]}")

      # Perform substitution if target contains $1, $2, etc.
      if [[ "$target" =~ \$[0-9] ]]; then
        # Replace $1, $2, ... with captured groups
        local j
        for ((j=1; j<${#captured_groups[@]}; j++)); do
          target="${target//\$$j/${captured_groups[$j]}}"
        done
      fi
      _log_debug "Mapping \"$source_pattern\" -> \"$target\" (rule: ${MAPPING_PATTERNS[$i]})"
      echo "$target"
      return 0
    fi
  done

  # No match: return original unchanged
  echo "$source_pattern"
  return 0
}

# Process each source path
_process_source_paths() {
  [[ ${IS_FIRST_SOURCE:-1} -eq 1 ]] && IS_FIRST_SOURCE=0
  for source_path in "${SOURCE_PATHS[@]}"; do
    # Strip trailing slashes from source path
    source_path="${source_path%/}"

    [[ ${IS_FIRST_SOURCE:-1} -eq 0 ]] && _log "----"
    _log "Processing source directory: \"$source_path\" ..."

    # Determine base target directory for this source
    if [[ -n "$TARGET_DIR" ]]; then
      base_target_dir="${TARGET_DIR%/}"
    else
      base_target_dir="$source_path"
    fi

    # Build find command arguments
    find_args=("$source_path" "-type" "f" "!" "-path" "*/.*")

    # TODO remove this? this seems inappropriate, especially with mapping files
    # # Skip already-processed rating directories unless --include-processed is set
    # if [[ "$INCLUDE_PROCESSED" == "false" ]]; then
    #   _log_debug "Excluding already-processed rating directories from search ..."
    #   # Exclude paths matching: [0-5]/[A-Za-z0-9].../* (rating folders with typical labels)
    #   find_args+=("!" "-regex" ".*/[0-5]/[a-zA-Z0-9].*/[^/]*")
    # fi

    # Add file type filters
    find_args+=("${FILE_TYPES_ARGS[@]}")

    # Iterate over known image files in source path
    found_any="false"
    dir_files_scanned=0
    while IFS= read -r f; do
      # Stop immediately if interrupted
      if [[ "$INTERRUPTED" == "true" ]]; then
        break
      fi
      found_any="true"
      ((++dir_files_scanned))
      if _should_skip_cached "$f"; then
        ((++STATS_SKIPPED_CACHED))
        continue
      fi

      # Try to get EXIF data from cache first (if not using --skip-cached)
      rating=""
      label=""
      rating_status=0
      label_status=0
      cached_exif=""
      if cached_exif=$(_get_cached_exif "$f"); then
        _log_debug "Using cached EXIF data for \"$f\" (cache hit)"
        IFS='|' read -r rating label <<<"$cached_exif"
        rating_status=0
        label_status=0
        ((++STATS_SKIPPED_CACHED))
      else
        # Get EXIF rating and label from file
        _log_debug "Reading EXIF data for \"$f\" ..."
        rating=$(_get_exif_tag Rating 0 "$f")
        rating_status=$LAST_EXIF_TAG_STATUS
        label=$(_get_exif_tag Label None "$f")
        label_status=$LAST_EXIF_TAG_STATUS
      fi

      # Check if both exiftool calls failed for this file
      if [[ $rating_status -ne 0 ]] && [[ $label_status -ne 0 ]]; then
        _log_warn "Unable to read EXIF data for \"$f\" (exiftool failed for both Rating and Label)"
        ((++STATS_FILES_UNREADABLE))
        continue
      fi

      # Check if rating is below minimum threshold
      if [[ $rating -lt $MIN_RATING ]]; then
        _log_info "Skipping \"$f\": rating ($rating) is below minimum threshold ($MIN_RATING)"
        ((++STATS_SKIPPED_MIN_RATING))
        continue
      fi

      # Construct rating/label path and apply mapping if available
      rating_label_path="$rating/$label"
      if [[ ${#MAPPING_PATTERNS[@]} -gt 0 ]]; then
        rating_label_path=$(_apply_mapping "$rating_label_path")
      fi
      target_dir="$base_target_dir/$rating_label_path"
      target_dir="${target_dir%/}"
      target_file="$target_dir/$(basename "$f")"
      # Check if source and target file are the same, skip if so (no need to move/copy file)
      if [[ "$(realpath "$f")" == "$(realpath -m "$target_file")" ]]; then
        _log_info "Skipping \"$f\": already in target location \"$target_dir\" (nothing to do)"
        ((++STATS_SKIPPED_LOCATION))
        # Even though we are skipping, we should still remember it in the cache in case it is processed again later
        _remember_processed_file "$f" "$rating" "$label"   # target_file and f are the same here
        continue
      fi
      # Check if another file with same name exists in target directory, skip if so (unless --force)
      if [[ "$FORCE_OVERWRITE" == "false" ]] && [[ -e "$target_file" ]]; then
        _log_warn "Skipping \"$f\": target file \"$target_file\" already exists (use --force to overwrite)"
        ((++STATS_SKIPPED_EXISTS))
        continue
      fi
      # Determine operation command and action description
      local command="mv"
      local action="Moving"
      if [[ "$OPERATION" == "copy" ]]; then
        command="cp"
        action="Copying"
      fi
      # Create target directory and move/copy file
      _log "$action \"$f\" to \"$target_dir/\" ..."
      if [[ "$NO_ACT" == "true" ]]; then
        _log "[DRY RUN] mkdir -p \"$target_dir\""
        _log "[DRY RUN] $command \"$f\" \"$target_dir/\""
        # Optionally indicate removal of empty source directory (single level) after move
        if [[ "$REMOVE_EMPTY_SOURCE_DIR" == "true" ]] && [[ "$OPERATION" == "move" ]]; then
          src_dir=$(dirname "$f")
          # check if dir is empty, if so then log
          if [[ -d "$src_dir" && -z "$(ls -A "$src_dir" | head -n 1)" ]]; then
            _log "[DRY RUN] Would remove empty source directory: \"$src_dir\" (single level)"
          fi
        fi
        if [[ "$OPERATION" == "copy" ]]; then
          ((++STATS_COPIED))
        else
          ((++STATS_MOVED))
        fi
      else
        _log_debug "> mkdir -p \"$target_dir\""
        mkdir -p "$target_dir"
        _log_debug "> $command \"$f\" \"$target_dir/\""
        $command "$f" "$target_dir/"
        # Optionally remove empty source directory (single level) after move
        if [[ "$REMOVE_EMPTY_SOURCE_DIR" == "true" ]] && [[ "$OPERATION" == "move" ]]; then
          src_dir=$(dirname "$f")
          if [[ -d "$src_dir" ]]; then
            # Only attempt removal when directory is empty
            if [[ -z "$(ls -A "$src_dir" )" ]]; then
              _log_info "Removing empty source directory \"$src_dir\" ..."
              rmdir "$src_dir" || _log_warn "Failed to remove empty source directory \"$src_dir\""
            fi
          fi
        fi
        _remember_processed_file "$target_file" "$rating" "$label"
        if [[ "$OPERATION" == "copy" ]]; then
          ((++STATS_COPIED))
        else
          ((++STATS_MOVED))
        fi
      fi
    done < <(find "${find_args[@]}")

    # If interrupted, stop processing further source directories
    if [[ "$INTERRUPTED" == "true" ]]; then
      _log "Interrupted; stopping further directories."
      break
    fi

    if [[ "$found_any" == "false" ]]; then
      FILE_TYPES_PRETTY=$(IFS=,; echo "${FILE_TYPES_LIST[*]}")
      _log_warn "no matching files found in \"$source_path\" for extensions: ${FILE_TYPES_PRETTY}" >&2
    fi

    # Print per-directory scan summary only when multiple source paths are provided
    if [[ ${#SOURCE_PATHS[@]} -gt 1 ]]; then
      _log "Scanned ${dir_files_scanned} file(s) in \"$source_path\" (count only; no action implied)"
    fi

    # Persist cache after each directory to avoid losing progress if interrupted
    _save_cache || _log_warn "Unable to write cache file to \"$CACHE_FILE\" after processing \"$source_path\""
  done
}

# Show summary statistics
_show_summary() {
  _log ""
  _log "=== Summary ==="
  _log "Files moved:                       $STATS_MOVED"
  _log "Files copied:                      $STATS_COPIED"
  _log "Files skipped / cache hit:         $STATS_SKIPPED_CACHED"
  _log "Files skipped / already at target: $STATS_SKIPPED_LOCATION"
  _log "Files skipped / below min rating:  $STATS_SKIPPED_MIN_RATING"
  _log "Files skipped / target exists:     $STATS_SKIPPED_EXISTS $([[ $STATS_SKIPPED_EXISTS -gt 0 ]] && echo -e "\033[33mWARNING(S)\033[0m")"
  [[ $STATS_FILES_UNREADABLE -gt 0 ]] && _log "Files skipped / unable to read EXIF:    $STATS_FILES_UNREADABLE $([[ $STATS_FILES_UNREADABLE -gt 0 ]] && echo -e "\033[33mWARNING(S)\033[0m")"

  if [[ "$CACHE_ENABLED" == "true" ]]; then
    _log ""
    _log "=== Cache Statistics ==="

    # Cache file info
    local actual_cache_file="${CACHE_FILE}.gz"
    _log "Cache file:     $actual_cache_file"
    _log "Cache strategy: $CACHE_STRATEGY"
    [[ "$CACHE_STRATEGY" =~ relpath|multi ]] && _log "Relpath levels: $CACHE_RELPATH_LEVELS"

    # Record counts
    size_delta=$((CACHE_FINAL_SIZE - CACHE_INITIAL_SIZE))
    records_delta=$((CACHE_FINAL_RECORDS - CACHE_INITIAL_RECORDS))
    size_delta_abs=${size_delta#-}
    records_delta_abs=${records_delta#-}
    [[ $records_delta -ge 0 ]] && records_delta_str="+${records_delta}" || records_delta_str="-${records_delta_abs}"
    [[ $size_delta -ge 0 ]] && size_delta_str="+" || size_delta_str="-"
    human_initial_size=$(_human_size "$CACHE_INITIAL_SIZE")
    human_final_size=$(_human_size "$CACHE_FINAL_SIZE")
    human_delta_size=$(_human_size "$size_delta_abs")

    _log "Records:        ${CACHE_INITIAL_RECORDS} -> ${CACHE_FINAL_RECORDS} (${records_delta_str})"
    _log "Size:           ${human_initial_size} -> ${human_final_size} (${size_delta_str}${human_delta_size})"

    # Cache hit breakdown
    local total_lookups=$((STATS_CACHE_HIT_PATH + STATS_CACHE_HIT_HASH + STATS_CACHE_HIT_RELPATH + STATS_CACHE_MISS))
    if [[ $total_lookups -gt 0 ]]; then
      _log ""
      _log "Cache lookups:  $total_lookups total"
      [[ $STATS_CACHE_HIT_PATH -gt 0 ]] && _log "  - Path hits:    $STATS_CACHE_HIT_PATH"
      [[ $STATS_CACHE_HIT_HASH -gt 0 ]] && _log "  - Hash hits:    $STATS_CACHE_HIT_HASH"
      [[ $STATS_CACHE_HIT_RELPATH -gt 0 ]] && _log "  - Relpath hits: $STATS_CACHE_HIT_RELPATH"
      [[ $STATS_CACHE_MISS -gt 0 ]] && _log "  - Misses:       $STATS_CACHE_MISS"
    fi

    # Collision info (debug only)
    if [[ $VERBOSITY -ge 2 ]] && [[ $((STATS_COLLISIONS_HASH + STATS_COLLISIONS_RELPATH)) -gt 0 ]]; then
      _log ""
      _log "Cache collisions (debug):"
      [[ $STATS_COLLISIONS_HASH -gt 0 ]] && _log "  - Hash:    $STATS_COLLISIONS_HASH"
      [[ $STATS_COLLISIONS_RELPATH -gt 0 ]] && _log "  - Relpath: $STATS_COLLISIONS_RELPATH"
    fi
  fi
}

#
_main() {
  _load_cache
  _record_cache_baseline

  # Load mapping file if provided
  if [[ -n "$MAPPING_FILE" ]]; then
    if ! _load_mapping_file "$MAPPING_FILE"; then
      _log_error "Failed to load mapping file: \"$MAPPING_FILE\""
      exit 1
    fi
  fi

  # Prepare file type find arguments
  FILE_TYPES_LIST=(${FILE_TYPES[@]})
  FILE_TYPES_ARGS=()
  for ext in "${FILE_TYPES_LIST[@]}"; do
    FILE_TYPES_ARGS+=("-iname" "*.${ext}")
    FILE_TYPES_ARGS+=("-o")
  done
  # Remove trailing -o
  unset 'FILE_TYPES_ARGS[${#FILE_TYPES_ARGS[@]}-1]'

  # Process source paths
  _process_source_paths

  # Save cache back to disk
  _save_cache || _log_warn "Unable to write cache file to \"$CACHE_FILE\""
  _record_cache_final

  # Show summary
  [[ "$SHOW_SUMMARY" == "true" ]] && _show_summary
}

# }}} = FUNCTION DEFINITIONS =================================================

# Run main logic
_main

exit 0
