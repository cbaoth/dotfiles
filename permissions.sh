#!/usr/bin/env bash
# permissions.sh: fix permissions of dotfiles repo
# code: language=bash insertSpaces=true tabSize=2
# keywords: zsh bash shell shell-script dotfiles-tools
# author: Andreas Weyer

# safety check before chaning mod bits for the wrong files
[ ! -d ".git" ] \
  && echo "error: .git not found, this doesn't seem to be the right folder" \
  && exit 1

find -type d -exec chmod 750 '{}' \;
find -type f -exec chmod 640 '{}' \;
find -type f \( -name "*.sh" -or -name "*.zsh" \) -exec chmod 750 '{}' \;
