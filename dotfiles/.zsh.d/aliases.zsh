# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zsh.d/aliases.zsh: Zsh-specific aliases.
#
# Shell-agnostic aliases live in ~/.aliases (sourced earlier in .zshrc).
# This file contains only zsh-specific additions: global aliases, suffix
# aliases, and zsh-only convenience aliases.

# {{{ - GENERAL (ZSH ONLY) ---------------------------------------------------
# run-help is a zsh builtin; h and hs are in ~/.aliases
alias /='cd /'  # invalid alias name in bash; zsh only
alias help='run-help'

# Reload shell-agnostic + zsh-specific functions
alias reload-functions='. $HOME/lib/functions.sh; . $HOME/.zsh.d/functions/functions.zsh'
# Reload all alias layers: auto-rehash -> common -> zsh-specific -> os/host
alias reload-aliases='. $HOME/.zsh.d/auto-rehash.zsh; . $HOME/.aliases; . $HOME/.zsh.d/aliases.zsh;
  source_ifex_custom $HOME/lib/aliases;
  source_ifex_custom -e .zsh $HOME/.zsh.d/aliases'

alias zsh-history-fix='mv $HOME/.zsh_history $HOME/.zsh_history_corrupt && strings $HOME/.zsh_history_corrupt > $HOME/.zsh_history && fc -R $HOME/.zsh_history && rm $HOME/.zsh_history_corrupt'
# }}} - GENERAL (ZSH ONLY) ---------------------------------------------------

# {{{ - SUFFIX ALIASES -------------------------------------------------------
# e.g. 'alias -s txt=vim' makes 'foo.txt' open in vim
#alias -s {txt,ini,conf,html,htm,xml}='vim -N'
#alias -s {com,net,org,de,in}='links2'
# }}} - SUFFIX ALIASES -------------------------------------------------------

# {{{ - GLOBAL ALIASES -------------------------------------------------------
# Global aliases are expanded anywhere on the command line (zsh only).
# Naming convention: @PREFIX to avoid conflicts with normal commands.

alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'

alias -g @N='> /dev/null 2>&1'
alias -g @eN='2> /dev/null'

alias -g @@='|'
alias -g @G='| egrep'
alias -g @eG='|& egrep'
alias -g @Gi='| egrep -i'
alias -g @eGi='|& egrep -i'
alias -g @H='| head'
alias -g @eH='|& head'
alias -g @T='| tail'
alias -g @eT='|& tail'
alias -g @Tf='| tail -f'
alias -g @eTf='|& tail -f'

if command -v most >/dev/null; then
  alias -g @L="| most"
  alias -g @eL='|& most'
else
  alias -g @L="| less"
  alias -g @eL='|& less'
fi

alias -g @S='| sort'
alias -g @Su='| sort -u'
alias -g @X='| xargs'
alias -g @X0='| xargs -0'
alias -g @Xl='| tr '\n' '\0' | xargs -0 -n 10000'
alias -g @Cl='| wc -l'

alias -g @MPV="| tr '\n' '\0' | xargs -0 -n 10000 mpv --no-resume-playback"

alias -g @to_lower="| tr '[A-Z]' '[a-z]'"
alias -g @to_upper="| tr '[a-z]' '[A-Z]'"
alias -g @url_clean="| sed 's/%3a/:/gi; s/%2f/\//gi; s/[?&].*//g; s/%26/&/gi;
                            s/%3d/:/gi; s/%3f/?/gi'"
alias -g @url_clean2="| sed 's/%3a/:/gi; s/%2f/\//gi; s/%26/&/gi; s/%3d/:/gi;
                             s/%3f/?/gi'"
alias -g @sum="| awk '{s+=\$1} END {print s}'"

# }}} - GLOBAL ALIASES -------------------------------------------------------

return 0
