# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zlogout: executed by zsh(1) when a login shell exits.

# interactive shell: .zshenv > .zshrc
# login shell: .zshenv > .zprofile > .zshrc > zlogin / .zlogout

# {{{ = FINAL CLEANUP ========================================================
# remove core dump files (if existing)
rm -f ~/*.core(N) ~/*.dump(N) &!

# when leaving the console clear the screen to increase privacy
if (($SHLVL == 1)); then
    [[ -x /usr/bin/clear_console ]] && /usr/bin/clear_console -q
fi
# }}} = FINAL CLEANUP ========================================================
