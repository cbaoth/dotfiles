#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash
#
# rename-ext-by-type.sh: Identify file types by content and rename to correct extension.

declare SCRIPT_FILE; SCRIPT_FILE="$(basename "$0")"
declare -r SCRIPT_FILE

# {{{ = CONSTANTS =============================================================

declare -r C_RED='\033[0;31m'
declare -r C_YELLOW='\033[0;33m'
declare -r C_GREEN='\033[0;32m'
declare -r C_CYAN='\033[0;36m'
declare -r C_NC='\033[0m'

declare -r DEFAULT_HASH_LENGTH=12
declare -r HASH_TAG="_cx_"

# }}} = CONSTANTS =============================================================

# {{{ = FUNCTIONS =============================================================

usage() {
  cat <<EOF
Usage: ${SCRIPT_FILE} [OPTIONS] <file>...

Identify the actual file type of each given file and rename it to use the
correct extension if the current extension doesn't match. Uses 'file' for
MIME detection, with ImageMagick 'identify' as a supplement for image files.

Collision handling (when the target filename already exists):
  Default: append a numeric suffix, e.g. photo-1.jpg, photo-2.jpg, ...
  --skip-existing: warn and skip (old behavior)
  --add-hash: for image files, append a content hash suffix instead,
              e.g. photo${HASH_TAG}a3f8c12e4b7d.jpg — same hash means same
              content, so a collision is silently skipped. Non-image files
              that collide still fall back to numeric suffix.

Options:
  -n, --dry-run        Preview changes without renaming
  -i, --interactive    Prompt for confirmation before each rename
  -v, --verbose        Show skipped/unchanged files too
      --skip-existing  Warn and skip on filename collision (disables numeric suffix)
  -H, --add-hash       Always append a pixel-content hash to image filenames
                       (uses ImageMagick identify; requires ImageMagick)
  -l, --hash-length N  Hash length in hex chars (default: ${DEFAULT_HASH_LENGTH}, range: 4-64)
  -h, --help           Show this help message and exit

Examples:
  ${SCRIPT_FILE} *.bin
  ${SCRIPT_FILE} -n ~/Downloads/*.dat
  ${SCRIPT_FILE} -i photo1 photo2 photo3
  ${SCRIPT_FILE} -H *.bin                 # rename + append hash in one pass
  ${SCRIPT_FILE} -H -l 8 ~/scans/*.bin   # shorter hash
  ${SCRIPT_FILE} --skip-existing *.bin   # old behavior: skip on collision
EOF
}

# Map MIME type to canonical extension.
#
# Arguments:
#   $1 - MIME type string (e.g. "image/jpeg")
# Outputs:
#   Writes canonical extension to stdout (empty if unknown)
mime_to_ext() {
  case "$1" in
    # Images
    image/png)                              echo "png" ;;
    image/jpeg)                             echo "jpg" ;;
    image/gif)                              echo "gif" ;;
    image/webp)                             echo "webp" ;;
    image/bmp)                              echo "bmp" ;;
    image/tiff)                             echo "tiff" ;;
    image/svg+xml)                          echo "svg" ;;
    image/x-icon|image/vnd.microsoft.icon) echo "ico" ;;
    image/avif)                             echo "avif" ;;
    image/heic|image/heif)                  echo "heic" ;;
    image/x-xcf)                            echo "xcf" ;;
    image/x-portable-pixmap)               echo "ppm" ;;
    image/x-portable-bitmap)               echo "pbm" ;;
    image/x-portable-graymap)              echo "pgm" ;;
    # Video
    video/mp4)                             echo "mp4" ;;
    video/x-msvideo)                       echo "avi" ;;
    video/x-matroska)                      echo "mkv" ;;
    video/webm)                            echo "webm" ;;
    video/quicktime)                       echo "mov" ;;
    video/x-flv)                           echo "flv" ;;
    video/mpeg)                            echo "mpg" ;;
    video/ogg)                             echo "ogv" ;;
    video/3gpp)                            echo "3gp" ;;
    # Audio
    audio/mpeg)                            echo "mp3" ;;
    audio/ogg)                             echo "ogg" ;;
    audio/flac)                            echo "flac" ;;
    audio/x-wav|audio/wav)                 echo "wav" ;;
    audio/mp4)                             echo "m4a" ;;
    audio/x-aiff|audio/aiff)              echo "aiff" ;;
    audio/x-ms-wma)                        echo "wma" ;;
    audio/opus)                            echo "opus" ;;
    # Documents / text
    application/pdf)                       echo "pdf" ;;
    text/plain)                            echo "txt" ;;
    text/html)                             echo "html" ;;
    text/xml|application/xml)             echo "xml" ;;
    application/json)                      echo "json" ;;
    text/csv)                              echo "csv" ;;
    # Archives
    application/zip)                       echo "zip" ;;
    application/x-tar)                     echo "tar" ;;
    application/gzip|application/x-gzip)  echo "gz" ;;
    application/x-bzip2)                   echo "bz2" ;;
    application/x-xz)                      echo "xz" ;;
    application/x-zstd)                    echo "zst" ;;
    application/x-7z-compressed)          echo "7z" ;;
    application/x-rar-compressed|application/vnd.rar) echo "rar" ;;
    application/x-iso9660-image)           echo "iso" ;;
    # Executables / binaries
    application/x-executable|application/x-elf) echo "elf" ;;
    application/x-sharedlib)              echo "so" ;;
    application/x-msdos-program|application/x-msdownload) echo "exe" ;;
    # Other
    application/x-sqlite3)                echo "sqlite" ;;
    application/x-shockwave-flash)        echo "swf" ;;
    *) echo "" ;;
  esac
}

# Map ImageMagick format string to canonical extension.
# Used as a supplement for image/* MIME types to catch raw/specialized formats.
#
# Arguments:
#   $1 - ImageMagick format string (e.g. "JPEG", "PNG")
# Outputs:
#   Writes canonical extension to stdout (empty if unknown)
magick_fmt_to_ext() {
  case "${1^^}" in
    JPEG|JPG)  echo "jpg" ;;
    PNG)       echo "png" ;;
    GIF)       echo "gif" ;;
    WEBP)      echo "webp" ;;
    BMP)       echo "bmp" ;;
    TIFF|TIF)  echo "tiff" ;;
    SVG|SVGZ)  echo "svg" ;;
    ICO)       echo "ico" ;;
    AVIF)      echo "avif" ;;
    HEIC|HEIF) echo "heic" ;;
    XCF)       echo "xcf" ;;
    PPM)       echo "ppm" ;;
    PBM)       echo "pbm" ;;
    PGM)       echo "pgm" ;;
    PSD)       echo "psd" ;;
    CR2|CR3)   echo "${1,,}" ;;
    NEF|ARW|RAF|DNG|ORF|RW2) echo "${1,,}" ;;
    *) echo "" ;;
  esac
}

# Detect the canonical extension for a file using 'file' (MIME) and optionally
# ImageMagick 'identify' for image types.
#
# Arguments:
#   $1 - path to the file
# Outputs:
#   Writes detected extension to stdout (empty if unknown)
# Returns:
#   0 on success, 1 on detection failure
detect_ext() {
  local -r filepath="$1"
  local mime new_ext magick_fmt magick_ext

  mime=$(file --mime-type -b "${filepath}" 2>/dev/null) || return 1
  new_ext=$(mime_to_ext "${mime}")

  # For image/* types, try ImageMagick identify for more precise format info
  if [[ "${mime}" == image/* ]] && command -v identify > /dev/null 2>&1; then
    magick_fmt=$(identify -format "%m" "${filepath}" 2>/dev/null | head -1) || true
    if [[ -n "${magick_fmt}" ]]; then
      magick_ext=$(magick_fmt_to_ext "${magick_fmt}")
      [[ -n "${magick_ext}" ]] && new_ext="${magick_ext}"
    fi
  fi

  echo "${new_ext}"
}

# Compute an ImageMagick pixel-data signature hash (SHA-256 of pixel values,
# metadata-independent). Returns the first hash_length hex characters.
# Uses the same method as image-hash-rename.
#
# Arguments:
#   $1 - image file path
#   $2 - hash length (number of hex chars)
# Outputs:
#   Writes hash string to stdout
# Returns:
#   0 on success, 1 on failure (ImageMagick error or unreadable file)
compute_image_hash() {
  local -r filepath="$1"
  local -r length="$2"
  local full_hash
  if command -v identify > /dev/null 2>&1; then
    full_hash="$(identify -format "%#\n" "${filepath}" 2>/dev/null | head -1)"
  else
    full_hash="$(magick identify -format "%#\n" "${filepath}" 2>/dev/null | head -1)"
  fi
  [[ -z "${full_hash}" ]] && return 1
  printf "%s" "${full_hash:0:${length}}"
}

# Find a safe target path that does not collide with an existing file.
# Implements the configured collision strategy.
#
# Prints the resolved target path (guaranteed non-colliding), or prints nothing
# and returns 1 if the file should be skipped (--skip-existing or hash collision).
#
# Arguments:
#   $1 - source file path (original)
#   $2 - target directory
#   $3 - desired stem (basename without extension, possibly with hash suffix)
#   $4 - target extension
#   $5 - hash_applied ("true"/"false"): whether a hash suffix was embedded in stem
# Globals read:
#   skip_existing, verbose
resolve_target_path() {
  local -r src="$1"
  local -r dir="$2"
  local -r stem="$3"
  local -r ext="$4"
  local -r hash_applied="$5"
  local target="${dir}/${stem}.${ext}"

  # No collision (or same file being renamed in-place)
  if [[ ! -e "${target}" || "${target}" == "${src}" ]]; then
    printf '%s' "${target}"
    return 0
  fi

  # Collision: stem contains a content hash → same content already at target; skip
  if "${hash_applied}"; then
    "${verbose}" && printf '%bSkip (hash match):%b %q -> %q already exists.\n' \
      "${C_CYAN}" "${C_NC}" "${src}" "${target}"
    return 1
  fi

  # Collision: --skip-existing
  if "${skip_existing}"; then
    printf '%bWarning:%b %q already exists, skipping %q.\n' \
      "${C_YELLOW}" "${C_NC}" "${target}" "${src}" >&2
    return 1
  fi

  # Default: numeric suffix (-1, -2, ...)
  local -i i=1
  while [[ -e "${dir}/${stem}-${i}.${ext}" ]]; do
    (( i++ )) || true
  done
  printf '%s' "${dir}/${stem}-${i}.${ext}"
}

parse_args() {
  dry_run=false
  interactive=false
  verbose=false
  skip_existing=false
  add_hash=false
  hash_length="${DEFAULT_HASH_LENGTH}"

  while (( $# > 0 )); do
    case "$1" in
      -n|--dry-run)      dry_run=true ;;
      -i|--interactive)  interactive=true ;;
      -v|--verbose)      verbose=true ;;
      --skip-existing)   skip_existing=true ;;
      -H|--add-hash)     add_hash=true ;;
      -l|--hash-length)
        shift
        if ! [[ "$1" =~ ^[0-9]+$ ]] || (( $1 < 4 || $1 > 64 )); then
          printf '%bError:%b --hash-length must be an integer between 4 and 64.\n' \
            "${C_RED}" "${C_NC}" >&2
          exit 1
        fi
        hash_length="$1"
        ;;
      -h|--help)  usage; exit 0 ;;
      --)         shift; break ;;
      -*)
        printf "Unknown option: %s\n" "$1" >&2
        usage >&2
        exit 1
        ;;
      *) break ;;
    esac
    shift
  done

  if (( $# == 0 )); then
    printf '%bError:%b No files specified.\n' "${C_RED}" "${C_NC}" >&2
    usage >&2
    exit 1
  fi

  if "${skip_existing}" && "${add_hash}"; then
    printf '%bError:%b --skip-existing and --add-hash are mutually exclusive.\n' \
      "${C_RED}" "${C_NC}" >&2
    exit 1
  fi

  files=("$@")
}

process_files() {
  local -i renamed=0 skipped=0 failed=0
  local file new_ext mime mime_info dir base name_noext cur_ext
  local stem new_path is_image hash hash_applied confirm

  for file in "${files[@]}"; do
    if [[ ! -f "${file}" ]]; then
      printf '%bWarning:%b Not a file, skipping: %q\n' "${C_YELLOW}" "${C_NC}" "${file}" >&2
      (( failed++ )) || true
      continue
    fi

    new_ext=$(detect_ext "${file}") || {
      printf '%bWarning:%b Could not determine type of %q, skipping.\n' "${C_YELLOW}" "${C_NC}" "${file}" >&2
      (( failed++ )) || true
      continue
    }

    if [[ -z "${new_ext}" ]]; then
      mime_info=$(file --mime-type -b "${file}" 2>/dev/null || echo "unknown")
      printf '%bUnknown:%b %q (mime: %s) — no extension mapping, skipping.\n' \
        "${C_YELLOW}" "${C_NC}" "${file}" "${mime_info}"
      (( skipped++ )) || true
      continue
    fi

    dir="$(dirname "${file}")"
    base="$(basename "${file}")"
    name_noext="${base%%.*}"
    cur_ext="${base#"${name_noext}"}"
    cur_ext="${cur_ext#.}"

    if [[ "${cur_ext,,}" == "${new_ext}" ]] && ! "${add_hash}"; then
      "${verbose}" && printf '%bOK:%b      %q (already .%s)\n' "${C_CYAN}" "${C_NC}" "${file}" "${new_ext}"
      (( skipped++ )) || true
      continue
    fi

    # Determine if this is an image (for --add-hash logic)
    mime=$(file --mime-type -b "${file}" 2>/dev/null || true)
    is_image=false
    [[ "${mime}" == image/* ]] && is_image=true

    # Build target stem: optionally append content hash for images
    stem="${name_noext}"
    hash_applied=false
    if "${add_hash}" && "${is_image}"; then
      if hash=$(compute_image_hash "${file}" "${hash_length}"); then
        stem="${name_noext}${HASH_TAG}${hash}"
        hash_applied=true
      else
        printf '%bWarning:%b Could not compute hash for %q, using plain name.\n' \
          "${C_YELLOW}" "${C_NC}" "${file}" >&2
      fi
    fi

    # Also skip if extension already matches AND stem is unchanged (add_hash case)
    if [[ "${cur_ext,,}" == "${new_ext}" && "${stem}" == "${name_noext}" ]]; then
      "${verbose}" && printf '%bOK:%b      %q (already .%s)\n' "${C_CYAN}" "${C_NC}" "${file}" "${new_ext}"
      (( skipped++ )) || true
      continue
    fi

    new_path=$(resolve_target_path "${file}" "${dir}" "${stem}" "${new_ext}" "${hash_applied}") || {
      (( failed++ )) || true
      continue
    }

    local new_name
    new_name="$(basename "${new_path}")"

    if "${dry_run}"; then
      printf '%bWould rename:%b %q -> %q\n' "${C_CYAN}" "${C_NC}" "${file}" "${new_name}"
      (( renamed++ )) || true
      continue
    fi

    if "${interactive}"; then
      printf "Rename %q -> %q? [y/N]: " "${file}" "${new_name}"
      read -r -n1 confirm
      printf '\n'
      if [[ ! "${confirm}" =~ ^[yY]$ ]]; then
        printf 'Skipped: %q\n' "${file}"
        (( skipped++ )) || true
        continue
      fi
    fi

    mv -- "${file}" "${new_path}"
    printf '%bRenamed:%b %q -> %q\n' "${C_GREEN}" "${C_NC}" "${file}" "${new_name}"
    (( renamed++ )) || true
  done

  printf '\n'
  if "${dry_run}"; then
    printf 'Dry-run complete: %d would be renamed, %d unchanged, %d errors.\n' \
      "${renamed}" "${skipped}" "${failed}"
  else
    printf 'Done: %d renamed, %d unchanged, %d errors.\n' \
      "${renamed}" "${skipped}" "${failed}"
  fi
}

# }}} = FUNCTIONS =============================================================

# {{{ = MAIN ==================================================================

main() {
  if ! command -v file > /dev/null 2>&1; then
    printf '%bError:%b '"'"'file'"'"' command not found (apt install file).\n' "${C_RED}" "${C_NC}" >&2
    exit 1
  fi

  declare -a files
  declare dry_run interactive verbose skip_existing add_hash hash_length
  parse_args "$@"
  process_files
}

main "$@"

# }}} = MAIN ==================================================================
