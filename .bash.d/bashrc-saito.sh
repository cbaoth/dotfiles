# ~/.bashrc.motoko: Local bash startup file (executed by ~/.bashrc)

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: bashrc shell-script

# == VARIABLES ===============================================================
# -- PROMPT ------------------------------------------------------------------
export PS1="\[\e[0;37m\](\w)\[\\033[0;37m\]
[\[\\033[0;34m\]\u\[\\033[0;37m\]@\[\\033[4;32m\]\h\[\\033[0;37m\]]\$ "

# -- SYSTEM ------------------------------------------------------------------
#export LIBGL_DEBUG="verbose"

# == MOTD ====================================================================
# print welcome message
if [[ $SHLVL -eq 1 ]]; then
   #echo
   print -P "\e[1;32mUptime:\e[1;34muptime\e[1;32m"
fi
