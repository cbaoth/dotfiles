# ~/.zshrc: executed by zsh(1)
# interactive shell: .zshenv > .zshrc | login shell: .zshenv > .zprofile > zlogin / .zlogout

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zshrc shell-script

# == VARIABLES (INTERACTIVE SHELL) ===========================================
# For login shell / general variable like PATH see ~/.zshenv

# -- PROMPT ------------------------------------------------------------------
#export PS1="$(print '%{\e[0;37m%}(%~)%{\e[0m%}
#[%{\e[0;34m%}%n%{\e[0m%}@%{\e[0;38m%}%m%{\e[0m%}]%# ')"
#export RPS1="$(print '%{\e[2;37m%}[%T]%{\e[0m%}')"
export RPS1=""
# prompt theme loaded in THEME section below ...

# -- LOCALE ------------------------------------------------------------------
#export LANG=C
export LANG="en_US.UTF-8"
export LC_ALL="en_US.utf8"
export LC="en_US.utf8"
export LESSCHARSET="utf-8"
#export BREAK_CHARS="\"#'(),;\`\\|\!?[]{}"

# -- SHELL -------------------------------------------------------------------
export TERM=xterm-color # rxvt, xterm-color
export COLORTERM=xterm
[ -n "`echo $TERMCAP|grep -i screen`" ] && TERM=screen

# -- IRC ---------------------------------------------------------------------
export IRCNICK="cbaoth"
export IRCNAME="Jorus C'Baoth"
#export IRCUSER="cbaoth"

# -- ORACLE ------------------------------------------------------------------
#export ORACLE_SID=XE
#export ORACLE_HOME="/usr/lib/oracle/xe/app/oracle/product/10.2.0/server"
#export PATH="$PATH:$ORACLE_HOME/bin"

# -- MISC --------------------------------------------------------------------
#export UAGENT="Mozilla/5.0 (X11; U; FreeBSD i386; en-US; rv:1.4b) Gecko/20030517 Mozilla Firebird/0.6"
export UAGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.104 Safari/537.36"

# == ZSH SPECIFICS ===========================================================
# -- PROMPT THEME ------------------------------------------------------------
# load prompt theme from /usr/share/zsh/functions/Prompts/
autoload -U promptinit
promptinit
#prompt yasuo 0 >/dev/null || prompt fade 0
prompt fade 0

# -- MODULES -----------------------------------------------------------------
# load zmv extension (http://zshwiki.org/home/builtin/functions/zmv)
autoload zmv
#zmodload zsh/mathfunc

# -- OPTIONS -----------------------------------------------------------------
# SEE: http://zsh.sourceforge.net/Doc/Release/Options.html#Expansion-and-Globbing
# enable auto correctin (e.g. 'cat /etc/paswd' => 'cat /etc/passwd')
#setopt correctall
# change directory withoud cd (e.g. '/etc/' instead of 'cd /etc')
#setopt autocd

# allow regex in glob (e.g. 'cp ^*.(tar|bz2|gz) /tmp/')
setopt extendedglob
# remove non-matching globs from command instead of failing
#setopt -o nullglob 
# same as nullglob but still fails if none of the globs has a match
#setopt -o cshnullglob

# include hidden (dot-files) in glob selections (note: also inverse selection!)
#setopt dotglob
# enable new style completion system
autoload -U compinit
compinit

# -- COMPLETION --------------------------------------------------------------
# menu
zstyle ':completion:*' menu select=1

# cache completion (to improve performance e.g. with apt/dpkg package lists)
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache/$HOST

# colorize completion menus
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'

# prevent cvs files/derictories from being completed
#zstyle ':completion:*:(all-|)files' ignored-patterns '(|*/)CVS'
#zstyle ':completion:*:cd:*' ignored-patterns '(*/)#CVS'

# fuzzy matching for completion
#zstyle ':completion:*' completer _complete _match _approximate
#zstyle ':completion:*' completer _expand _complete _match _approximate _ignored

# insert all expansions for expand completer
#zstyle ':completion:*:expand:*' tag-order all-expansions
zstyle ':completion:*:match:*' original only
#zstyle ':completion:*:approximate:*' max-errors 1 numeric

# increase number of errors allowed (fuzzy matching) depending on lenght
#zstyle -e ':completion:*:approximate:*' \
#        max-errors 'reply=($((($#PREFIX+$#SUFFIX)/3))numeric)'

# ignore completion for non existing commands
#zstyle ':completion:*:functions' ignored-patterns '_*'

# helper functions
#xdvi() { command xdvi ${*:-*.dvi(om[1])} }
#zstyle ':completion:*:*:xdvi:*' menu yes select
#zstyle ':completion:*:*:xdvi:*' file-sort time

# kill: complete process ids with menu selection
zstyle ':completion:*:*:kill:*' menu yes select
zstyle ':completion:*:kill:*'   force-list always

# kill: specific menu
zstyle ':completion:*:processes' command 'ps -U $(whoami) | sed "/ps/d"'
#zstyle ':completion:*:processes' command 'ps ax -o pid,user,psr,pcpu,nlwp,pmem,comm --sort user,comm | sed "/ps/d"'
zstyle ':completion:*:processes' insert-ids menu yes select

# remove trailing slash in directory arguments
zstyle ':completion:*' squeeze-slashes true

# prevent selection of parent directory
# e.g. 'cd ../<TAB>' will not suggest pwd
zstyle ':completion:*:cd:*' ignore-parents parent pwd

# match uppercase from lowercase
#zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# case insesitivity, partial matchin, substitution
zstyle ':completion:*' matcher-list 'm:{A-Z}={a-z}' 'm:{a-z}={A-Z}' 'r:|[._-]=** r:|=**' 'l:|=* r:|=*'
# offer indexes before parameters in subscripts
#zstyle ':completion:*:*:-subscript-:*' tag-order indexes parameters

# ignore completion functions (until the _ignored completer)
#zstyle ':completion:*:functions' ignored-patterns '_*'

# change completion description and warning text
zstyle ':completion:*' verbose yes
zstyle ':completion:*:descriptions' format '%U%B%d%b%u'
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*:warnings' format '%Bno matches for: %d%b'
zstyle ':completion:*:corrections' format '%B%d (errors: %e)%b'
zstyle ':completion:*' group-name ''

# complete only specific hosts (big host file)
#zstyle '*' hosts `hostname` motoko.intra puppet.intra bateau.intra togusa.intra yav.in

# command file type detection
#compctl -g '*.ebuild' ebuild
#compctl -g '*.tex' + -g '*(-/)' latex
#compctl -g '*.dvi' + -g '*(-/)' dvipdf dvipdfm
#compctl -g '*.java' + -g '*(-/)' javac
#compctl -g '*.tar.bz2 *.tar.gz *.bz2 *.gz *.jar *.rar *.tar *.tbz2 *.tgz *.zip *.Z' + -g '*(-/)' extract
#compctl -g '*.mp3 *.ogg *.mod *.wav *.avi *.mpg *.mpeg *.wmv' + -g '*(-/)' mplayer
#compctl -g '*.py' python
#compctl -g '*(-/D)' cd
#compctl -g '*(-/)' mkdir

# -- MISC --------------------------------------------------------------------
# emacs key bindings
bindkey -e

# lookup spaces
bindkey ' ' magic-space

# cd ... completes cd ../../../ etc.
#rationalise-dot() {
#  if [[ $LBUFFER = *.. ]]; then
#    LBUFFER+=/..
#  else
#    LBUFFER+=.
#  fi
#}
#zle -N rationalise-dot
#bindkey . rationalise-dot

# avoid globbing on special commands
#for com in alias expr find mattrib mcopy mdir mdel which;
#alias $com="noglob $com"

# -- COMPLETION --------------------------------------------------------------
# user name auto completion
function userlist {
  [ -r /etc/passwd ] && reply=(`cat /etc/passwd | cut -d : -f 1`)
}
compctl -K userlist ps -fU
compctl -K userlist finger
set COMPLETE_ALIASES

# -- BINDINGS ----------------------------------------------------------------
if [ "$TERM" = "xterm" ] || [ "$TERM" = "xterm-color" ]; then
  #bindkey "\e[1~" beginning-of-line  # Home
  bindkey "\e[7~" beginning-of-line  # Home rxvt
  bindkey "\e[2~" overwrite-mode     # Ins
  bindkey "\e[3~" delete-char        # Delete
  bindkey "^?" backward-delete-char  # Backspace
  #bindkey "\e[4~" end-of-line        # End
  bindkey "\e[8~" end-of-line        # End rxvt
fi

# == INCLUDES ================================================================
OS=`uname | tr '[A-Z]' '[a-z]'`
[ ! $HOST ] && export HOST=$HOSTNAME

include_ifex () {
  while [ -n "$1" ]; do
    [ -f "$1" ] && . "$1"
    shift
  done
}

# load aliases
include_ifex \
  $HOME/.aliases \
  $HOME/.aliases.$OS \
  $HOME/.aliases.$HOST \
  $HOME/.aliases.$HOST.$OS \
  $HOME/.aliases.zsh
#  `cat .aliases | grep -Ev '^\s*#' | sed 's/^alias/alias -g/'`

# load functions
include_ifex \
  $HOME/.functions \
  $HOME/.functions.$OS \
  $HOME/.functions.$HOST \
  $HOME/.functions.$HOST.$OS

# load system/host specific config file (eg: ~/.zshrc.freebsd)
include_ifex \
  $HOME/.zshrc.$OS \
  $HOME/.zshrc.$HOST \
  $HOME/.zshrc.$HOST.$OS

# == EXECUTE =================================================================
# ubuntu default: go-w
umask 022
# multi user system umask: g-w, o-rwx
#umask 027
# multi user system umask: o-rwx
#umask 007

# remove core dump files
rm -f ~/*.core(N) ~/*.dump(N) &!

# -- DTAG --------------------------------------------------------------------
# enabale dtag (when available)
(which dtags-activate 2>&1 >/dev/null \
  && (command -v dtags-activate > /dev/null 2>&1 \
      && eval "`dtags-activate zsh`")
  #|| echo "WARNING: unable to activate dtags, dtags-activate not found"
) &!

# -- X STUFF -----------------------------------------------------------------
# this should normally not be here, but ... this way its always executed when
# opening a term

# no perfect check since we could e.g. be in an ssh session without
# working / running x, so we start everything in the background
# stupid messages but better timeouts in bg thatn in fg (delay at login)

# TODO: FIND A BETTER SOLUTION< MOVE TO INPUTRC / XINITRC
if [ "$DISPLAY" ]; then
  # repeat caps lock (colemak backspace)
  xset r 66 2>/dev/null &!
  # don't repeat tilde
  #xset -r 49 &
  # ubuntu hack: disable stupid ubuntu shift+backspace -> x terminate
  xmodmap -e 'keycode 0x16 = BackSpace BackSpace BackSpace BackSpace' 2>/dev/null &!
  # and add terminate via print button (seldom used) + shift + mod
  xmodmap -e 'keycode 0x6B = Print Sys_Req Print Terminate_Server Print Sys_Req' 2>/dev/null &!
fi

# == MOTD ====================================================================
# print welcome message
if [[ $SHLVL -eq 1 ]]; then
   #echo
   #print -P "\e[1;32m Welcome to: \e[1;34m%m"
   #print -P "\e[1;32m Running: \e[1;34m`uname -srm`\e[1;32m on \e[1;34m%l"
   #print -P "\e[1;32m It is:\e[1;34m %D{%r}\e[1;32m on \e[1;34m%D{%A %b %f %G}"
   print -P "\e[1;32mWelcome to \e[1;34m%m\e[1;32m running \e[1;34m`uname -srm`\e[1;32m on \e[1;34m%l"
fi
