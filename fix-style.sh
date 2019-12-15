#!/usr/bin/env bash
# just tries to fix a few common bad practices (may mess up everything)

set -o errexit
set -o pipefail
set -o errtrace
set -o nounset
((${DEBUG_LVL-0} >= 5)) && set -o xtrace
IFS=$'\n\t\0' #$' \n\t\0' # zsh default

if [[ -z "${1-}" ]]; then
  printf "Usage: %s --preview SHELL_FILE" "$0"
  exit 1
fi

_preview=true
if [[ "$1" =~ ^(-i|--infile)$ ]]; then
  _preview=false
  shift
fi

_replace_in_file() {
  local file="${1}"
  shift
  local sub="${@}"
  if $_preview; then
    diff "$f" <(cat "$f" | sed -E "$sub")
  else
    sed -E -i "$sub" "$f" || return 1
  fi
  return 0
}

for f in $*; do
  printf "> Processing: %s\n" "$f"
  if [[ ! -f "$f" ]]; then
    printf "> WARNING: file not found [%s], skipping .." "$f" >&2
    continue
  fi
  #printf '> Replacing `cmd` with nestable $(cmd)\n'
  # TODO: find a way without rec. option groups / lookahead (sed limitation)
  printf '> Replacing basic [[?.. integer camparisons with more readable ((..\n'
  # TODO: currently ignoring AND/OR sequences and []&|
  # e.g. [[ $x -gt 1 && $x -lt 10 ]]
  _replace_in_file "$f" 's/\[\[?\s+([^]&|]+)\s+-eq\s+([^]&|]+)\s+\]?\]/((\1 == \2))/g;
                         s/\[\[?\s+([^]&|]+)\s+-lt\s+([^]&|]+)\s+\]?\]/((\1 < \2))/g;
                         s/\[\[?\s+([^]&|]+)\s+-gt\s+([^]&|]+)\s+\]?\]/((\1 > \2))/g;
                         s/\[\[?\s+([^]&|]+)\s+-le\s+([^]&|]+)\s+\]?\]/((\1 <= \2))/g;
                         s/\[\[?\s+([^]&|]+)\s+-ge\s+([^]&|]+)\s+\]?\]/((\1 >= \2))/g'
  printf '> Replacing [ with builtin [[ (built-in)\n'
  _replace_in_file "$f" 's/^\[ /[[ /g; s/ \]([ ;&])/ ]]\1/g;
                         s/([ ;&#])\[ /\1[[ /g; s/ \]([ ;&#])/ ]]\1/g'
  printf '> sed -r to POSIX sed -E\n'
  _replace_in_file "$f" 's/(sed +(-[\w]+ +)*)-r/\1-E/g'
  # TODO: [[ . == . ]] -> [[ . = . ]]
done

exit 0
