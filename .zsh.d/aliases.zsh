# ~/.zsh/aliases: Common ZSH specific aliases

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zsh zshrc aliases

# The following aliases are intended for ZSH use only (e.g. global aliases)

# {{{ - GENERAL --------------------------------------------------------------
alias /='cd /'
alias h='history'
alias hs='history | grep -Ei'

alias reload-functions='. $HOME/.zsh.d/functions.zsh;
  source_ifex_custom $HOME/.zsh.d/functions'
alias reload-aliases='. $HOME/.zsh.d/aliases.zsh;
  source_ifex_custom $HOME/.zsh.d/aliases'
# }}} - GENERAL --------------------------------------------------------------

# {{{ - SUFFIX ALIASES -------------------------------------------------------
# e.g. 'alias -s txt=vim', now 'foo.txt' will open foo.txt in vim
#alias -s {txt,ini,conf,html,htm,xml}='vim -N'
#alias -s {com,net,org,de,in}='links2'
# }}} - SUFFIX ALIASES -------------------------------------------------------

# {{{ - GLOBAL ALIASES -------------------------------------------------------
# no spelling correction (if correct / correctall is active)
# can result in issues when used with sudo
#alias -g rm='nocorrect rm'
#alias -g cp='nocorrect cp'
#alias -g mv='nocorrect mv'
#alias -g zmv='nocorrect zmv'
#alias -g mkdir='nocorrect mkdir'

alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'

alias -g @N='> /dev/null 2>&1'
alias -g @eN='2> /dev/null'

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

#alias -g @Sk="*~(*.bz2|*.gz|*.tgz|*.zip|*.z)"
# }}} - GLOBAL ALIASES -------------------------------------------------------
