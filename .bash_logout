# ~/.bash_logout: executed by bash(1) when login shell exits.
# code: language=bash insertSpaces=true tabSize=2
# keywords: bash dotfile bashrc bash_logout shell-script
# author: Andreas Weyer

# when leaving the console clear the screen to increase privacy

if (($SHLVL == 1)); then
    [[ -x /usr/bin/clear_console ]] && /usr/bin/clear_console -q
fi
