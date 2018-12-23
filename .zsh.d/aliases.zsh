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
alias -g WG=wget # already an alias
#alias -g AX=axel # already an alias
alias -g A2=aria2c # already an alias
alias -g TRL="tr '[A-Z]' '[a-z]'"
alias -g TRU="tr '[a-z]' '[A-Z]'"
alias -g mp3gain='mp3gain -k -d 93.5 -r'
alias -g mp3gain-album='mp3gain -k -d 93.5 -a'
alias -g urlclean="sed 's/%3a/:/gi; s/%2f/\//gi; s/[?&].*//g; s/%26/&/gi;
                        s/%3d/:/gi; s/%3f/?/gi'"
alias -g urlclean2="sed 's/%3a/:/gi; s/%2f/\//gi; s/%26/&/gi; s/%3d/:/gi;
                         s/%3f/?/gi'"

# no spelling correction (if correct / correctall is active)
# can result in issues when used with sudo
#alias -g rm='nocorrect rm'
#alias -g cp='nocorrect cp'
#alias -g mv='nocorrect mv'
#alias -g zmv='nocorrect zmv'
#alias -g mkdir='nocorrect mkdir'

# http://grml.org/zsh/zsh-lovers.html
alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
#alias -g CA="2>&1 | cat -A"
#alias -g C='| wc -l'
#alias -g D="DISPLAY=:0.0"
#alias -g DN=/dev/null
#alias -g ED="export DISPLAY=:0.0"
alias -g EG='|& egrep'
alias -g EH='|& head'
alias -g EL='|& less'
#alias -g ELS='|& less -S'
#alias -g ETL='|& tail -20'
alias -g ET='|& tail'
#alias -g F=' | fmt -'
alias -g G='| egrep'
alias -g H='| head'
#alias -g HL='|& head -20'
#alias -g Sk="*~(*.bz2|*.gz|*.tgz|*.zip|*.z)"
#alias -g LL="2>&1 | less"
alias -g L="| less"
#alias -g LS='| less -S'
#alias -g MM='| most'
#alias -g M='| more'
#alias -g NE="2> /dev/null"
#alias -g NS='| sort -n'
alias -g NUL="> /dev/null 2>&1"
#alias -g PIPE='|'
#alias -g R=' > /c/aaa/tee.txt '
#alias -g RNS='| sort -nr'
alias -g S='| sort'
#alias -g TL='| tail -20'
alias -g T='| tail'
alias -g TF='| tail -f'
#alias -g US='| sort -u'
#alias -g VM=/var/log/messages
#alias -g X0G='| xargs -0 egrep'
alias -g X0='| xargs -0'
#alias -g XG='| xargs egrep'
alias -g X='| xargs'
alias -g SUM="|awk '{s+=\$1} END {print s}'"
# }}} - GLOBAL ALIASES -------------------------------------------------------
