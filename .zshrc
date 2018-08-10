# ~/.zshrc: executed by zsh(1)
# interactive shell: .zshenv > .zshrc
# login shell: .zshenv > .zprofile > zlogin / .zlogout

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zshrc shell-script

# {{{ = ENVIRONMENT (INTERACTIVE SHELL) ======================================
# For login shell / general variable like PATH see ~/.zshenv

# {{{ - BASICS ---------------------------------------------------------------
export OS=`uname | tr '[A-Z]' '[a-z]'`
[ ! $HOST ] && export HOST=$HOSTNAME

export TERM="xterm-256color" # rxvt, xterm-color, xterm-256color
export COLORTERM=xterm
#[ -n "`echo $TERMCAP|grep -i screen`" ] && TERM=screen

# single user system (ubuntu default): go-w
umask 022
# multi user system umask: g-w, o-rwx
#umask 027
# multi user system umask: o-rwx
#umask 007
# }}} - BASICS ---------------------------------------------------------------

# {{{ - WINDOWS SUBSYSTEM LINUX ----------------------------------------------
export IS_WSL=false
if [[ $(uname -r) = *Microsoft* ]]; then
  IS_WSL=true
  # See https://github.com/Microsoft/BashOnWindows/issues/1887
  unsetopt BG_NICE
fi
# }}} - WINDOWS SUBSYSTEM LINUX ----------------------------------------------

# {{{ - IRC ------------------------------------------------------------------
export IRCNICK="cbaoth"
export IRCNAME="Jorus C'Baoth"
#export IRCUSER="cbaoth"
# }}} - IRC ------------------------------------------------------------------

# {{{ - DEV ------------------------------------------------------------------
export CLASSPATH=".:$HOME/.class:$CLASSPATH"
export PYTHONPATH="$PYTHONPATH:$HOME/lib/python/site-packages"
export SCALA_HOME="$HOME/scala"
command -v java && export JAVA_HOME=${$(realpath $(command -v java))/bin\/java/}
export ARCH=$(uname -m)

# Check if we are in the 32bit chroot
#export INCHROOT=0
#if [ -z "`mount -l -t ext3 | grep 'on / type'`" ]; then
#if [ ! -d "/usr/lib64/" ]; then
#  export DISPLAY=":0"
#  export INCHROOT=1
#  export ARCH=i686
#  # Change prompt color if in chroot
#  export PS1="$(print '%{\e[0;37m%}(%~)%{\e[0m%}
#[%{\e[0;32m%}%n%{\e[0m%}@%m]%# ')"
#  # Mount Radeon Shared Memory TMPFS
#  #[ -z "`mount|grep shm`" ] && sudo mount /dev/shm/
#  alias cb="cd ~/; su cbaoth"
#fi

# GCC/G++ Optimization Flags
#case $ARCH in
#  x86_64)
#    export CHOST="x86_64-pc-linux-gnu"
#    # amd: k8, opteron, athlon64, athlon-fx
#    # intel: core2 (gcc 4.3+), nocona
#    export CFLAGS="-march=core2 -pipe -O2" # -m64
#    ;;
#  i686)
#    export CHOST="i686-pc-linux-gnu"
#    # amd: athlon, athlon-tbird, athlon-4, athlon-xp, athlon-mp
#    # intel: prescott, pentium4
#    export CFLAGS="-march=prescott -pipe -O2 -fomit-frame-pointer"
#    ;;
#esac
#export CXXFLAGS="${CFLAGS}"
#export MAKEFLAGS="-j5" # -j2 + extra cores (job count)
# }}} - DEV ------------------------------------------------------------------

# {{{ - DBMS -----------------------------------------------------------------
#export ORACLE_SID=XE
#export ORACLE_HOME="/usr/lib/oracle/xe/app/oracle/product/10.2.0/server"
#export PATH="$PATH:$ORACLE_HOME/bin"
# }}} - DBMS -----------------------------------------------------------------

# {{{ - MISC -----------------------------------------------------------------
#UAGENT="Mozilla/5.0 (X11; U; FreeBSD i386; en-US; rv:1.4b) Gecko/20030517"
#UAGENT+=" Mozilla Firebird/0.6"
UAGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko)"
UAGENT+=" Chrome/59.0.3071.104 Safari/537.36"
export UAGENT

# {{{ - MISC -----------------------------------------------------------------
# globally raise (but never lower) the default debug level of p_dbg
export DBG_LVL=0
# }}} - MISC -----------------------------------------------------------------

# }}} = ENVIRONMENT (INTERACTIVE SHELL) ======================================

# {{{ = INCLUDE FUNCTIONS ====================================================
# include core functions, must simply be there (used everywhere)
source $HOME/.zsh.d/functions.zsh

# include given file(s) if they exist,
source_ifex () {
  [ -z "$1" ] && printf "usage: %s" "$0 file.." && return 1
  while [ -n "$1" ]; do
    p_dbg 0 2 "potential source: $1"
    [ -r "$1" ] && { p_dbg 0 1 "loading source: $1"; source "$1" }
    shift
  done
  return 0
}

# include given base_file(s) and all matching os/host specific versions if
# they exist
source_ifex_custom () {
  [ -z "$1" ] && printf "usage: %s" "$0 base_file.." && return 1
  local host=${${HOST:l}//./_}
  local os=${OS:l}
  while [ -n "$1" ]; do
    local base_file=$1
    source_ifex \
      "${base_file}-${os}.zsh" \
      "${base_file}-${os}-wsl.zsh" \
      "${base_file}-${host}.zsh" \
      "${base_file}-${os}.zsh" \
      "${base_file}-${host}.${os}-wsl.zsh"
    shift
  done
  return 0
}

# include .functions and matching os/host specific versions of .functions
source_ifex_custom $HOME/.zsh.d/functions
# }}} = INCLUDE FUNCTIONS ====================================================

# {{{ = ZPLUG PREPARE ========================================================
# apt: zplug - https://github.com/zplug/zplug
if [ -r "/usr/share/zplug/init.zsh" ]; then
  p_dbg 0 2 zpug found, loading ...
  # init (load) zplug
  source /usr/share/zplug/init.zsh
  alias zplug_cmd=zplug
#elif
#  curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
else
  p_war "$(tputs 'setaf 1')zplug $(tputs 'setaf 3')not found, skipping ..."
  # create temporary dummy zplug alias so all commannds below will succeed
  alias zplug_cmd=:
fi

# https://github.com/robbyrussell/oh-my-zsh/tree/master/plugins
zplug_cmd "plugins/git", from:oh-my-zsh
# }}} = ZPLUG PREPARE ========================================================

# {{{ = PROMPT ===============================================================
# load colors, alternative: tput https://stackoverflow.com/a/20983251/7393995
autoload colors && colors

# {{{ - BASIC ----------------------------------------------------------------
# activate basic prompt (fallback if powerlevel9k is not availlable)

#export PS1="$(print '%{\e[0;37m%}(%~)%{\e[0m%}
#[%{\e[0;34m%}%n%{\e[0m%}@%{\e[0;38m%}%m%{\e[0m%}]%# ')"
#export RPS1="$(print '%{\e[2;37m%}[%T]%{\e[0m%}')"

# load prompt theme from /usr/share/zsh/functions/Prompts/
autoload -U promptinit
promptinit
#prompt yasuo 0 >/dev/null || prompt fade 0
prompt fade 0
# fonts: fira code, deb: fonts-powerline fonts-inconsolata
# sudo fc-cache -vf ~/.local/share/fonts
# }}} - BASIC ----------------------------------------------------------------
# {{{ - PL9K -----------------------------------------------------------------
# load pewerlevel9k (if availlable)
# apt: zsh-theme-powerlevel9k - https://github.com/bhilburn/powerlevel9k
#source_ifex /usr/share/powerlevel9k/powerlevel9k.zsh-theme
zplug_cmd "bhilburn/powerlevel9k", use:powerlevel9k.zsh-theme
# {{{ - - General ------------------------------------------------------------
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(host dir dir_writable)
#POWERLEVEL9K_LEFT_PROMPT_ELEMENTS+=(disk_usage)
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS+=(newline user custom_prompt)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status vcs background_jobs docker_machine)
[[ "$HOST:l" =~ ^(puppet|weyera).*$ ]] \
  && POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS+=(battery)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS+=(time)

#POWERLEVEL9K_RAM_ELEMENTS=(ram_free)
POWERLEVEL9K_SHORTEN_DIR_LENGTH=4
POWERLEVEL9K_SHORTEN_STRATEGY="truncate_middle"
POWERLEVEL9K_PROMPT_ON_NEWLINE=false
POWERLEVEL9K_RPROMPT_ON_NEWLINE=true
POWERLEVEL9K_TIME_FORMAT="%D{%H:%M}"
#POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX="\u256D"
#POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX="\u2570[$USER]\u03bb"
POWERLEVEL9K_STATUS_VERBOSE=false
POWERLEVEL9K_DISK_USAGE_ONLY_WARNING=true
# hide username if current user
export DEFAULT_USER="$USER"
# }}} - - General ------------------------------------------------------------
# {{{ - - Colors -------------------------------------------------------------
POWERLEVEL9K_USER_DEFAULT_BACKGROUND="black"
POWERLEVEL9K_USER_DEFAULT_FOREGROUND="249"
POWERLEVEL9K_USER_SUDO_FOREGROUND="yellow"
POWERLEVEL9K_USER_ROOT_FOREGROUND="red"
POWERLEVEL9K_HOST_LOCAL_BACKGROUND="249"
POWERLEVEL9K_HOST_LOCAL_FOREGROUND="black"
POWERLEVEL9K_HOST_REMOTE_BACKGROUND="yellow"
POWERLEVEL9K_HOST_REMOTE_FOREGROUND="black"

POWERLEVEL9K_DIR_DEFAULT_FOREGROUND="249"
POWERLEVEL9K_DIR_DEFAULT_BACKGROUND="blue"
POWERLEVEL9K_DIR_HOME_FOREGROUND="black"
POWERLEVEL9K_DIR_HOME_BACKGROUND="green"
POWERLEVEL9K_DIR_HOME_SUBFOLDER_FOREGROUND="black"
POWERLEVEL9K_DIR_HOME_SUBFOLDER_BACKGROUND="green"
POWERLEVEL9K_DIR_ETC_FOREGROUND="black"
POWERLEVEL9K_DIR_ETC_BACKGROUND="cyan"
POWERLEVEL9K_DIR_WRITABLE_FORBIDDEN_FOREGROUND="249"
POWERLEVEL9K_DIR_WRITABLE_FORBIDDEN_BACKGROUND="red"

POWERLEVEL9K_ROOT_INDICATOR_BACKGROUND="red"
POWERLEVEL9K_ROOT_INDICATOR_FOREGROUND="white"

POWERLEVEL9K_TIME_BACKGROUND="clear"
POWERLEVEL9K_TIME_FOREGROUND="249"

POWERLEVEL9K_CUSTOM_PROMPT="print '\u03bb'"
POWERLEVEL9K_CUSTOM_PROMPT_FOREGROUND="249"
POWERLEVEL9K_CUSTOM_PROMPT_BACKGROUND="black"

POWERLEVEL9K_BACKGROUND_JOBS_FOREGROUND="yellow"

POWERLEVEL9K_VCS_CLEAN_FOREGROUND='black'
POWERLEVEL9K_VCS_CLEAN_BACKGROUND='green'
POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND='249'
POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND='blue'
POWERLEVEL9K_VCS_MODIFIED_FOREGROUND='black'
POWERLEVEL9K_VCS_MODIFIED_BACKGROUND='yellow'
# }}} - - Colors -------------------------------------------------------------
# }}} - PL9K -----------------------------------------------------------------
# }}} = PROMPT ===============================================================

# {{{ = ZPLUG LOAD ===========================================================
zplug_cmd check --verbose \
  || { yesno_p "Install missing zplug packages" && zplug install }

# load local plugins
#zplug_cmd "~/.zsh.d", from:local

zplug_cmd load
# remove temporary alias
unalias zplug_cmd
# }}} = ZPLUG LOAD ===========================================================

# {{{ ZSH SETTINGS ===========================================================
# load zmv extension (http://zshwiki.org/home/builtin/functions/zmv)
autoload zmv
#zmodload zsh/mathfunc

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

# {{{ - COMPLETION -----------------------------------------------------------
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
zstyle ':completion:*' matcher-list 'm:{A-Z}={a-z}' 'm:{a-z}={A-Z}' \
       'r:|[._-]=** r:|=**' 'l:|=* r:|=*'
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

# file type command detecton
#compctl -g '*.ebuild' ebuild
#compctl -g '*.tex' + -g '*(-/)' latex
#compctl -g '*.dvi' + -g '*(-/)' dvipdf dvipdfm
#compctl -g '*.java' + -g '*(-/)' javac
#compctl -g '*.tar.bz2 *.tar.gz *.bz2 *.gz *.jar *.rar *.tar *.tbz2 *.tgz *.zip *.Z' \
#        + -g '*(-/)' extract
#compctl -g '*.mp3 *.ogg *.mod *.wav *.avi *.mpg *.mpeg *.wmv' + -g '*(-/)' mpv
#compctl -g '*.py' python
#compctl -g '*(-/D)' cd
#compctl -g '*(-/)' mkdir

# user name auto completion
function _userlist {
  [ -r /etc/passwd ] && reply=($(cat /etc/passwd | cut -d : -f 1))
}
compctl -K _userlist ps -fU
compctl -K _userlist finger

set COMPLETE_ALIASES
# }}} - COMPLETION -----------------------------------------------------------
# {{{ - KEY BINDINGS ---------------------------------------------------------
# emacs key bindings
bindkey -e

# lookup spaces
bindkey ' ' magic-space

if [[ "$TERM" = *xterm* ]]; then
  #bindkey "\e[1~" beginning-of-line  # Home
  bindkey "\e[7~" beginning-of-line  # Home rxvt
  bindkey "\e[2~" overwrite-mode     # Ins
  bindkey "\e[3~" delete-char        # Delete
  bindkey "^?" backward-delete-char  # Backspace
  #bindkey "\e[4~" end-of-line        # End
  bindkey "\e[8~" end-of-line        # End rxvt
fi
# }}} - KEY BINDINGS ---------------------------------------------------------
# {{{ - MISC -----------------------------------------------------------------
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
# }}} - MISC -----------------------------------------------------------------
# }}} = ZSH SETTINGS =========================================================

# {{{ = MISC =================================================================
# remove core dump files
rm -f ~/*.core(N) ~/*.dump(N) &!

# {{{ - DTAG -----------------------------------------------------------------
# enabale dtag (when available)
#(cmd_p dtags-activate \
#  && eval "$(dtags-activate zsh)" \
#  || p_war "unable to activate dtags, dtags-activate not found" \
#) &!
# }}} - DTAG -----------------------------------------------------------------
# {{{ - X STUFF --------------------------------------------------------------
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
# }}} - X STUFF --------------------------------------------------------------
# {{{ - INCLUDES -------------------------------------------------------------
# include comman aliases and os/host specific aliase files
source_ifex $HOME/.zsh.d/aliases
source_ifex_custom $HOME/.zsh.d/aliases

# include os/host specific zshrc files
source_ifex_custom $HOME/.zsh.d/zshrc
# }}} - INCLUDES -------------------------------------------------------------
# {{{ - MOTD -----------------------------------------------------------------
# print welcome message
if [[ $SHLVL -eq 1 ]]; then
   #echo
   #print -P "\e[1;32m Welcome to: \e[1;34m%m"
   #print -P "\e[1;32m Running: \e[1;34m`uname -srm`\e[1;32m on \e[1;34m%l"
   #print -P "\e[1;32m It is:\e[1;34m %D{%r}\e[1;32m on \e[1;34m%D{%A %b %f %G}"
   print -P "\e[1;32mWelcome to \e[1;34m%m\e[1;32m running \e[1;34m`uname -srm`\e[1;32m on \e[1;34m%l"
fi
# }}} - MOTD -----------------------------------------------------------------
# {{{ - FINAL STEPS ----------------------------------------------------------
# activate syntax highlighting, load last to affect everything loaded before
# apt: zsh-syntax-highlighting - https://github.com/zsh-users/zsh-syntax-highlighting
[ -r "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] \
  && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
zplug "zsh-users/zsh-syntax-highlighting"
# }}} - FINAL STEPS ----------------------------------------------------------
# }}} = MISC =================================================================
