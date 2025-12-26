# ~/.zsh/zshrc-freebsd.zsh: Common zshrc for host [motoko]

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zsh zshrc shell-script

#export LIBGL_DEBUG="verbose"

# Set basic prompt theme if PowerLevel10K not available
if ! ${POWERLEVEL10K_ISACTIVE:-false}; then
  #export PS1="$(print '%{\e[0;37m%}(%~)%{\e[0m%}
  #[%{\e[0;34m%}%n%{\e[0m%}@%{\e[0;33m%}%m%{\e[0m%}]%# ')"
  #export RPS1="$(print '%{\e[2;37m%}[%T]%{\e[0m%}')"
  # load prompt theme from /usr/share/zsh/functions/Prompts/
  prompt fade 4
fi

return 0
