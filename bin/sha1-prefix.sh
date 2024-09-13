#!/bin/env bash

if [[ -z "$1" ]]; then
  echo "usage: $(basename $0) FILE.."
  exit 1
fi
no_act=0
[[ $1 == -n ]] && no_act=1 && shift

for f in "$@"; do
  if [[ ! -f "$f" ]]; then
    echo "> WARNING: File not found [$f], skipping..." >&2
    continue
  fi
  if [[ "$f" =~ ^[0-9a-z]{40}_ ]]; then
    echo "> WARNING: File already processed[$f] (presumably), skipping..." >&2
    continue
  fi
  # strip leading dashes and spaces, add sha1sum prefix
  d=$(dirname "$f")
  b=$(basename "$f")
  b_clean="$(echo "$b" | sed -r 's/^[- _]*//g')"
  status=$?
  if [[ $status -ne 0 ]]; then
    echo "> WARNING: Failed to sanitize file name [$f], skipping..."
    continue
  fi
  b_hash="$(sha1sum -- "$f")"
  status=$?
  if [[ $status -ne 0 ]]; then
    echo "> WARNING: Failed to generating sha1sum for [$f], skipping..."
    continue
  fi
  b_hash="$(echo "$b_hash" | cut -f 1 -d' ' --)"
  target="$d/${b_hash}_${b_clean}"
  if [[ $no_act -eq 0 ]]; then
    echo "> Renaming [$f] to [$target]"
    mv "$f" "$target"
  else
    echo "> Would rename [$f] to [$target]"
  fi
done

#echo "to strip sha1 checksum in middle of file names,"
#echo "in case it was added multiple times, use:"
#echo rename 's/_[0-9a-z]{40}//g'
