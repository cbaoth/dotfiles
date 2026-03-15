# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zsh.d/zshrc-11001001_org.zsh: Org-specific zshrc settings.

# Set basic prompt theme if PowerLevel10K not available
if ${POWERLEVEL10K_ISACTIVE:-false}; then
  #export PS1="$(print '%{\e[0;37m%}(%~)%{\e[0m%}
  #[%{\e[0;34m%}%n%{\e[0m%}@%{\e[0;32m%}%m%{\e[0m%}]%# ')"
  #export RPS1="$(print '%{\e[2;37m%}[%T]%{\e[0m%}')"
  # load prompt theme from /usr/share/zsh/functions/Prompts/
  prompt fade 1
fi

return 0
