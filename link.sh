#!/bin/bash
DOTFILES="$HOME"/git/dotfiles

[ ! -d "$DOTFILES" ] && echo ERROR: dotfile folder not found in "$DOTFILES" && exit 1

for f in "$DOTFILES/".[a-z]*; do
  [ "$f" == ".git" ] && continue
  target="$HOME/`basename $f`"
  [ -L "$target" ] && echo WARNING: link "$target" exists, unlinking ... && rm "$target"
  [ -f "$target" ] && echo WARNING: file "$target" exists, renaming to "$target".bak && mv "$target" "$target".bak
  echo -- creating link "$f" \-\> "$target"
  ln -s "$f" "$target"
done
