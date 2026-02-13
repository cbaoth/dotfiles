# ~/.zsh/zshrc-freebsd.zsh: Common zshrc for host [puppet]
# code: language=zsh insertSpaces=true tabSize=2
# keywords: zsh dotfile zshrc shell shell-script
# author: Andreas Weyer

# Set basic prompt theme if PowerLevel10K not available
if ! ${POWERLEVEL10K_ISACTIVE:-false}; then
  #export PS1="$(print '%{\e[0;37m%}(%~)%{\e[0m%}
  #[%{\e[0;34m%}%n%{\e[0m%}@%{\e[0;36m%}%m%{\e[0m%}]%# ')"
  #export RPS1="$(print '%{\e[2;37m%}[%T]%{\e[0m%}')"
  # load prompt theme from /usr/share/zsh/functions/Prompts/
  prompt fade 2
fi

return 0
