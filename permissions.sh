#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash
#
# Normalize file and directory permissions in this dotfiles repository.

# safety check before chaning mod bits for the wrong files
[ ! -d ".git" ] \
  && echo "error: .git not found, this doesn't seem to be the right folder" \
  && exit 1

find -type d -exec chmod 750 '{}' \;
find -type f -exec chmod 640 '{}' \;
find -type f \( -name "*.sh" -or -name "*.zsh" \) -exec chmod 750 '{}' \;
