# ~/.zsh/zshrc-freebsd.zsh: Common zshrc for host [puppet]

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zsh zshrc shell-script

# set basic prompt theme if powerlevel9k not available
if [ ! $POWERLEVEL9K_ISACTIVE ]; then
  #export PS1="$(print '%{\e[0;37m%}(%~)%{\e[0m%}
  #[%{\e[0;34m%}%n%{\e[0m%}@%{\e[0;36m%}%m%{\e[0m%}]%# ')"
  #export RPS1="$(print '%{\e[2;37m%}[%T]%{\e[0m%}')"
  # load prompt theme from /usr/share/zsh/functions/Prompts/
  prompt fade 2
fi
