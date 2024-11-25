#!/usr/bin/env bash
# links.sh: symlink dotfiles from git repo to home directory

# Author:   Andreas Weyer <dev@cbaoth.de>
# Keywords: bash shell-script

# TODO
# - Skip existing links that already point to the right destination
# - Provide more appropriate blacklist

LINK_FILE=$(realpath $0)
DOTFILES=$(dirname $LINK_FILE)
BAKDIR=$HOME/dotfiles_bak_$(date +%s)

COPY_FILES=false
if [[ "$1" == "-c" ]]; then
  COPY_FILES=true
  shift
fi

cd "$DOTFILES"
# safety check before we create wrong links
[ ! -d ".git" ] \
  && echo "error: .git not found, this doesn't seem to be the right folder" \
  && exit 1

# create backup dir
mkdir -p "$BAKDIR"

# Define the ignore file
IGNORE_FILE=".linkignore"

# Read the ignore file and create a regex pattern
IGNORE_PATTERN=$(grep -vE "^\s*#" "$IGNORE_FILE" | sed ':a;N;$!ba;s/\n/\\|/g')
IGNORE_PATTERN=".*/\($(basename $0)\|\.linkignore\|${IGNORE_PATTERN}\)\(/.*\)\?"
echo "Ignoring ($IGNORE_FILE): $IGNORE_PATTERN"

# Use the pattern in the find command
find "$DOTFILES" -regextype sed ! -regex "$IGNORE_PATTERN" \
| while read -r f; do
  # get relative target/source file location
  relpath=$(realpath --relative-to "$DOTFILES" "$f")
  echo "> SRC: $relpath"
  target=$HOME/$relpath
  echo "> TAR: $target"
  #if [[ "$target" =~ "$DOTFILES" ]]; then
  #  echo "> ERROR: target location inside dotfiles git repository, skipping: $target" >&2
  #  continue
  #fi
  #rmExistingLink "$target"
  if [ -d "$f" ]; then # is dir?
    [ "$relpath" = "." ] && continue
    if [ -e "$target" ]; then # target exists?
      if [ ! -d "$target" ]; then
        targetbak="$BAKDIR/$relpath"
        echo "> WARNING: target exists but is not a directory, moving to $targetbak" >&2
        mkdir -p "$BAKDIR/`dirname $relpath`"
        mv "$target" "$BAKDIR/$relpath"
      elif [ -L "$target" ]; then
        echo "> WARNING: target is a symlink (directory), please check if this is intended: $target"
      else
	echo "> skipping, directory exists: $target"
      fi
    else
      echo "> creating missing directory: $target"
      mkdir -p "$target"
    fi
  else
    if [ -e "$target" ]; then # target exists?
      # is a link pointing to the desired target?
      if [[ -L "$target" && "$(readlink $target)" -ef "$f" && ! $COPY_FILES ]]; then
        echo "> INFO: correct link alreardy exists, skipping .."
        continue
      fi
      targetbak="$BAKDIR/$relpath"
      echo "> WARNING: file '$target' exists, moving to '$targetbak'" >&2
      mkdir -p "$BAKDIR/`dirname $relpath`"
      mv "$target" "$BAKDIR/$relpath"
    fi
    if $COPY_FILES; then
      echo "> creating copy: '$f' -> '$target'"
      cp "$f" "$target"
    else
      echo "> creating link: '$f' -> '$target'"
      ln -sf "$f" "$target"
    fi
  fi
done

rmdir --ignore-fail-on-non-empty "$BAKDIR"

