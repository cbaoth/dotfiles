# ~/.zlogout: executed by zsh(1) when login shell exits.
# interactive shell: .zshenv > .zshrc
# login shell: .zshenv > .zprofile > .zshrc > zlogin / .zlogout

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zshrc zlogout shell-script

# {{{ = FINAL CLEANUP ========================================================
# remove core dump files (if existing)
rm -f ~/*.core(N) ~/*.dump(N) &!

# when leaving the console clear the screen to increase privacy
if (($SHLVL == 1)); then
    [[ -x /usr/bin/clear_console ]] && /usr/bin/clear_console -q
fi
# }}} = FINAL CLEANUP ========================================================
