# ~/.zsh/zshrc-freebsd.zsh: Common zshrc for host [saito]

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zshrc shell-script

# == VARIABLES (INTERACTIVE SHELL) ===========================================
# -- PROMPT ------------------------------------------------------------------
#export PS1="$(print '%{\e[0;37m%}(%~)%{\e[0m%}
#[%{\e[0;34m%}%n%{\e[0m%}@%{\e[0;33m%}%m%{\e[0m%}]%# ')"
#export RPS1="$(print '%{\e[2;37m%}[%T]%{\e[0m%}')"
# prompt theme loaded in THEME section below ...

# -- SYSTEM ------------------------------------------------------------------
#export LIBGL_DEBUG="verbose"

# == ZSH SPECIFICS ===========================================================
# -- PROMPT THEME ------------------------------------------------------------
# load prompt theme from /usr/share/zsh/functions/Prompts/
prompt fade 3

# == MOTD ====================================================================
# print welcome message
if [[ $SHLVL -eq 1 ]]; then
   #echo
   print -P "\e[1;32mUptime:\e[1;34muptime\e[1;32m"
fi