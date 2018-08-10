#!/bin/bash

# TODO
# - Skip existing links that already point to the right destination

LINK_FILE=`realpath $0`
DOTFILES=`dirname $LINK_FILE`
BAKDIR=$HOME/dofile_bak_`date +%s`

cd "$DOTFILES"
# safety check before we create wrong links
[ ! -d ".git" ] \
  && echo "error: .git not found, this doesn't seem to be the right folder" \
  && exit 1

mkdir -p "$BAKDIR"
find "$DOTFILES" -regextype sed \
     -regex "$DOTFILES/\..\w.*" \
     ! -regex '.*/\(link.sh\|\.git\|\.gitignore\|\.vscode\)\(/.*\)\?' \
| while read f; do
  targetrel=`realpath --relative-to "$DOTFILES" $f`
  echo "$targetrel"
  target=$HOME/$targetrel
  echo "$target"
  #if [[ "$target" =~ "$DOTFILES" ]]; then
  #  echo "> ERROR: target location inside dotfiles git repository, skipping: $target" >&2
  #  continue
  #fi
  #rmExistingLink "$target"
  if [ -d "$f" ]; then # is dir?
    if [ -e "$target" ]; then # target exists?
      if [ ! -d "$target" ]; then
        targetbak="$BAKDIR/$targetrel"
        echo "> WARNING: target exists but is not a directory, moving to $targetbak" >&2
        mkdir -p "$BAKDIR/`dirname $targetrel`"
        mv "$target" "$BAKDIR/$targetrel"
      elif [ -L "$target" ]; then
        echo "> WARNING: target is a symlink (directory), please check if this is intended: $target"
      fi
    else
      echo "> creating missing directory: $target"
      mkdir -p "$target"
    fi
  else
    if [ -e "$target" ]; then # target exists?
      targetbak="$BAKDIR/$targetrel"
      echo "> WARNING: file '$target' exists, moving to '$targetbak'" >&2
      mkdir -p "$BAKDIR/`dirname $targetrel`"
      mv "$target" "$BAKDIR/$targetrel"
    fi
    echo "> creating link: '$f' -> '$target'"
    ln -s "$f" "$target"
  fi
done

rmdir --ignore-fail-on-non-empty "$BAKDIR"
