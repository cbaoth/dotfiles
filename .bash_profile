# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.bash_profile: initialization for bash login shells.
#
# This file is only read and executed by bash in a non-interactive login shell,
# or in login shell invoked with option --login.
# It is not read by bash interactive shells (.bashrc is used for that).
#
# Load order:
# 1. /etc/profile (first existing, this will always be read)
# 2. The first file that is found and readable of the following:
#    ~/.bash_profile
#    ~/.bash_login
#    ~/.profile


# Source environment settings common to all my shells
[[ -f ~/.common_profile ]] && source ~/.common_profile
