# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/lib/aliases-linux_desktop.sh: aliases for a Linux desktop session only.
#
# Sourced by both bash and zsh, but only when XDG_CURRENT_DESKTOP is set
# (i.e. an active graphical session, not a bare TTY or SSH login). Keep GUI-
# only tooling here so plain shells stay uncluttered.

# font discovery (fontconfig) — see ~/.config/sway/config.d/20-styles.conf
alias font-list="fc-list : family | sort -u"          # all installed families
alias font-search="fc-list | grep -i"                 # font-search fira
alias font-match="fc-match"                            # what a name resolves to

return 0
