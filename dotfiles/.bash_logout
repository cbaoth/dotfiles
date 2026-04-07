# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.bash_logout: executed by bash(1) when a login shell exits.
#
# interactive non-login shell: .bashrc
# login shell: .bash_profile (or .bash_login or .profile, first found) > .bash_logout
#

# {{{ = FINAL CLEANUP ========================================================
# when leaving the console clear the screen to increase privacy
if (( SHLVL == 1 )); then
  if [[ -x /usr/bin/clear_console ]]; then
    /usr/bin/clear_console -q
  fi
fi
# }}} = FINAL CLEANUP ========================================================
