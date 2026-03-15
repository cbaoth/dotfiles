# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zlogin: executed by zsh(1) when a login shell starts.

# interactive shell: .zshenv > .zshrc
# login shell: .zshenv > .zprofile > .zshrc > zlogin / .zlogout


# {{{ = FINAL LOGIN EXECUTIONS ===============================================
# {{{ - MOTD -----------------------------------------------------------------
# print welcome message (if top-level shell)
if (( $SHLVL == 1 )); then
   print -P "%B%F{white}Welcome to %F{green}%m %F{white}running %F{green}$(uname -srm)%F{white}"
   # on %F{green}#%l%f%b"
   print -P "%B%F{white}Uptime:%b%F{green}$(uptime)%f"
fi
# }}} - MOTD -----------------------------------------------------------------
# }}} = FINAL LOGIN EXECUTIONS ===============================================
