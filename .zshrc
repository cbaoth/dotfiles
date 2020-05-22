# ~/.zshrc: executed by zsh(1)
# interactive shell: .zshenv > .zshrc
# interactive shell: .zshenv > .zshrc
# login shell: .zshenv > .zprofile > .zshrc > zlogin / .zlogout

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zsh zshrc shell-script

# TODO:
# look into https://github.com/clvv/fasd

# {{{ = ENVIRONMENT (INTERACTIVE SHELL) ======================================
# For login shell / general variable like PATH see ~/.zshenv

# {{{ - CORE -----------------------------------------------------------------
export OS="${$(uname):l}"
export HOST="${$(hostname):l}"
export TERM="xterm-256color" # rxvt, xterm-color, xterm-256color
#export COLORTERM=xterm
#[ -n "$(echo $TERMCAP|grep -i screen)" ]] && TERM=screen

# globally raise (but never lower) the default debug level of cl::p_dbg
export DBG_LVL=0
# }}} - CORE -----------------------------------------------------------------

# {{{ - SECURITY & PRIVACY ---------------------------------------------------
# private session
#export HISTFILE="" # don't create shell history file
#export SAVEHIST=0 # set shell history file limit to zero
# shared session
export HISTSIZE=10000 # set in-memory history limit
export SAVEHIST=10000 # set history file limit
export HISTFILE="~/.history" # set history file

setopt INC_APPEND_HISTORY # write immediately (default: on exit only)
#setopt HIST_IGNORE_DUPS # don't add duplicates
setopt HIST_IGNORE_ALL_DUPS # delete old entry in favor of new one if duplicate
setopt SHARE_HISTORY # share history between sesions
#setopt EXTENDED_HISTORY # store in ":start:elapsed;command" format
setopt HIST_IGNORE_SPACE # don't record lines stating with a space (privacy)
#setopt HIST_REDUCE_BLANKS # remove unnecessary spaces
#setopt HIST_VERIFY # don't execute immediately after history expansion
setopt HIST_NO_STORE # don't store history / fc commands
setopt HIST_NO_FUNCTIONS # don't store function definitions
# }}} - SECURITY & PRIVACY ---------------------------------------------------

# {{{ - UMASK ----------------------------------------------------------------
# single user system (ubuntu default): go-w
umask 022
# multi user system umask: g-w, o-rwx
#umask 027
# multi user system umask: o-rwx
#umask 007
# }}} - UMASK ----------------------------------------------------------------

# {{{ - WINDOWS SUBSYSTEM LINUX ----------------------------------------------
# Are we in a Windows Subsystem Linux?
IS_WSL=false
if [[ $(uname -r) = *Microsoft* ]]; then
  IS_WSL=true
  # See https://github.com/Microsoft/BashOnWindows/issues/1887
  unsetopt BG_NICE
fi

# Is X available? Unreliable for ssh x-forwading., suffi. for local sessions.
IS_X=false
if [[ ! -t 0 ]] && xset b off; then
  IS_X=true
fi
# }}} - WINDOWS SUBSYSTEM LINUX ----------------------------------------------

# {{{ - DEV ------------------------------------------------------------------
export CLASSPATH=".:$HOME/.class${CLASSPATH+:$CLASSPATH}"
export PYTHONPATH="${PYTHONPATH+:$PYTHONPATH}:$HOME/lib/python/site-packages"
export SCALA_HOME="$HOME/scala"
command -v java 2>&1 >/dev/null \
  && export JAVA_HOME="${$(realpath $(command -v java))/bin\/java/}"
export ARCH="$(uname -m)"

# Check if we are in the 32bit chroot
#export INCHROOT=0
#if [[ -z "$(mount -l -t ext3 | grep 'on / type')" ]]; then
#if [[ ! -d "/usr/lib64/" ]]; then
#  export DISPLAY=":0"
#  export INCHROOT=1
#  export ARCH=i686
#  # Change prompt color if in chroot
#  export PS1="$(print '%{\e[0;37m%}(%~)%{\e[0m%}
#[%{\e[0;32m%}%n%{\e[0m%}@%m]%# ')"
#  # Mount Radeon Shared Memory TMPFS
#  #[ -z "$(mount|grep shm)" ]] && sudo mount /dev/shm/
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

# {{{ - IRC ------------------------------------------------------------------
export IRCNICK="cbaoth"
export IRCNAME="Jorus C'Baoth"
#export IRCUSER="cbaoth"
# }}} - IRC ------------------------------------------------------------------

# {{{ - ZSH ------------------------------------------------------------------
# Default apps
$IS_X && export EDITOR=code || export EDITOR='vim -N'
$IS_X && export BROWSER=google-chrome || export BROWSER=links
$IS_X && export IMGVIEWER=xnview || export IMGVIEWER=catimg
$IS_X && export MPLAYER=mpv || export MPLAYER=mpv
# }}} - ZSH ------------------------------------------------------------------

# {{{ - MISC -----------------------------------------------------------------
#UAGENT="Mozilla/5.0 (X11; U; FreeBSD i386; en-US; rv:1.4b) Gecko/20030517"
#UAGENT+=" Mozilla Firebird/0.6"
UAGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko)"
UAGENT+=" Chrome/79.0.3945.88 Safari/537.36"
export UAGENT
# }}} - MISC -----------------------------------------------------------------
# }}} = ENVIRONMENT (INTERACTIVE SHELL) ======================================

# {{{ = CORE FUNCTIONS & ALIASES =============================================
# include core functions, must simply be there (used everywhere)
source $HOME/lib/commons.sh

# include given source file(s) if they exist,
source_ifex () {
  [[ -z "${1-}" ]] && cl::p_usg "$0 source-file.." && return 1
  while [[ -n "$1" ]]; do
    cl::p_dbg 0 2 "potential source: $1"
    [[ -r "$1" ]] && { cl::p_dbg 0 1 "loading source: $1"; source "$1" }
    shift
  done
  return 0
}

# include all matching os/host specific source files having the given
# [source-file-prefix] file name prefix(s)
source_ifex_custom () {
  [[ -z "${1-}" ]] && printf "usage: %s" "$0 source-file-prefix.." && return 1
  local host="${${HOST:l}//./_}"
  local os="${OS:l}"
  while [[ -n "${1-}" ]]; do
    local base_file="$1"
    source_ifex \
      "${base_file}-${os}.zsh" \
      $($IS_WSL && print "${base_file}-${os}_wsl.zsh") \
      "${base_file}-${host}.zsh" \
      "${base_file}-${host}-${os}.zsh" \
      $($IS_WSL && print "${base_file}-${host}-${os}_wsl.zsh")
    shift
  done
  return 0
}

# include common and zsh specific aliases
source_ifex $HOME/.aliases
source_ifex $HOME/.zsh.d/aliases.zsh

# include common and zsh specific aliases
source_ifex $HOME/.zsh.d/functions.zsh

is_me() { [[ $USER:l =~ ^(cbaoth|(a\.)?weyer)$ ]]; }
# }}} = CORE FUNCTIONS & ALIASES =============================================

# {{{ = ZPLUG PREPARE ========================================================
# apt: zplug - https://github.com/zplug/zplug
alias zplug_cmd=zplug
#if [[ -f "/usr/share/zplug/init.zsh" ]]; then
#  cl::p_dbg 0 2 'zplug found in /usr/share/zplug, loading ...'
#  source /usr/share/zplug/init.zsh
# TODO clean this up, much too complicate (separate functions or don't cover all unlikely cases)
if [[ -f "$HOME/.zplug/init.zsh" ]]; then
  cl::p_dbg 0 2 'zplug found in ~/.zplug, loading ...'
  source "$HOME/.zplug/init.zsh"
else
  cl::p_war 'init.zsh not found in ~/.zplug'
  if [[ -d "$HOME/.zplug" ]]; then
    cl::q_yesno "zplug not found but $HOME/.zplug exist, should I delete it?" \
      && rm -rf ~/.zplug
  fi

  if command -v wget >& /dev/null; then
    _url_cmd=(wget -qO -)
  elif command -v curl >& /dev/null; then
    _url_cmd=(curl l -sL --proot-rdir -all,https)
  else
    _url_cmd=false
  fi
  "${_url_cmd[@]}" https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
  unset _url_cmd

  if (($? == 0)); then
    if [[ -f "$HOME/.zplug/init.zsh" ]]; then
      source "$HOME/.zplug/init.zsh"
    else
      cl::p_err "$(cl::tputs 'setaf 1')zplug $(cl::tputs 'setaf 3')installation seem to have faild, $HOME/.zplug not found."
    fi
  else
    cl::p_err "$(cl::tputs 'setaf 1')zplug $(cl::tputs 'setaf 3')download failed."
    # temporary dummy zplug alias so all commannds below will exit gracefully
    alias zplug_cmd=false
  fi
fi

# self-manage zplug (zplug update will upldate zplug itself)
zplug 'zplug/zplug', hook-build:'zplug --self-manage'
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
# }}} - BASIC ----------------------------------------------------------------

# {{{ - PL9K -----------------------------------------------------------------
#https://github.com/bhilburn/powerlevel9k/wiki/About-Fonts
#POWERLEVEL9K_MODE=awesome-fontconfig
#POWERLEVEL9K_MODE=nerdfont-complete
# fonts: fira code, deb: fonts-powerline fonts-inconsolata
# sudo fc-cache -vf ~/.local/share/fonts
ZSH_THEME="powerlevel9k/powerlevel9k"

# load pewerlevel9k (if availlable)
# apt: zsh-theme-powerlevel9k - https://github.com/bhilburn/powerlevel9k
#source_ifex /usr/share/powerlevel9k/powerlevel9k.zsh-theme
zplug_cmd "bhilburn/powerlevel9k", use:powerlevel9k.zsh-theme \
  && POWERLEVEL9K_ISACTIVE=true || POWERLEVEL9K_ISACTIVE=false

# {{{ - - General ------------------------------------------------------------
POWERLEVEL9K_DISABLE_RPROMPT=false
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(host dir dir_writable vcs) # disk_usage
# POWERLEVEL9K_LEFT_PROMPT_ELEMENTS+=(newline context) # root_indicator
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time \
                                    background_jobs docker_machine)
#[[ "$HOST:l" =~ ^(puppet|weyera).*$ ]]
$IS_WSL || POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS+=(battery)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS+=(time)

#export DEFAULT_USER="$USER" # not an options, lambda should always be shown
#POWERLEVEL9K_CONTEXT_TEMPLATE="$(is_me || print -P '%n ')\u03bb"
#POWERLEVEL9K_USER_TEMPLATE="%n"
POWERLEVEL9K_HOST_TEMPLATE="$(cl::is_ssh && print -P %2m | tr 'a-z' 'A-Z' || print -P "%m")"
POWERLEVEL9K_HOST_ICON="" # \ufa01 \ufcbe
POWERLEVEL9K_SSH_ICON="\u260D " # \uf9c0 \uf996 \uf96a \u21cc \u21f5
#POWERLEVEL9K_RAM_ELEMENTS=(ram_free)
POWERLEVEL9K_SHORTEN_DIR_LENGTH=3
POWERLEVEL9K_SHORTEN_STRATEGY="truncate_middle"
POWERLEVEL9K_PROMPT_ON_NEWLINE=true
POWERLEVEL9K_RPROMPT_ON_NEWLINE=false
POWERLEVEL9K_TIME_FORMAT="%D{%H:%M}"
#POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX="\u256D"
POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX=""
#POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX="\u2570[$USER]\u03bb"
cl::is_sudo && _PROMPT_SUDO_ICON="▲" || _PROMPT_SUDO_ICON=""
_PROMPT_USER_NAME="$(is_me || print -P '%n ')"
if (cl::is_su); then
  POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX="%B%K{red}%F{white}$_PROMPT_SUDO_ICON"
  POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX+=" $_PROMT_USER_NAME\u03bb %f%k%b%F{red}\uE0B0%f "
else
  _PROMPT_BG_COLOR="$(cl::is_sudo_cached && print "yellow" || print "white")"
  POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX="%K{$_PROMPT_BG_COLOR}%F{black}$_PROMPT_SUDO_ICON"
  POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX+=" $_PROMPT_USER_NAME\u03bb %f%k%F{$_PROMPT_BG_COLOR}\uE0B0%f "
fi
unset _PROMPT_SUDO_ICON _PROMPT_BG_COLOR _PROMPT_USER_NAME
POWERLEVEL9K_STATUS_VERBOSE=false
#POWERLEVEL9K_BACKGROUND_JOBS_VERBOSE=false # default: true
#POWERLEVEL9K_BACKGROUND_JOBS_VERBOSE_ALWAYS=true # default: false
#POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=0 # default: 3
POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION=0 # default: 2
POWERLEVEL9K_DISK_USAGE_ONLY_WARNING=true
# hide user/context if current user
#POWERLEVEL9K_VCS_GIT_HOOKS=(vcs-detect-changes git-untracked git-aheadbehind \
#  git-stash git-remotebranch git-tagname)
# }}} - - General ------------------------------------------------------------
# {{{ - - Colors -------------------------------------------------------------
#POWERLEVEL9K_USER_DEFAULT_BACKGROUND="black"
#POWERLEVEL9K_USER_DEFAULT_FOREGROUND="249"
#POWERLEVEL9K_USER_SUDO_BACKGROUND="black"
#POWERLEVEL9K_USER_SUDO_FOREGROUND="yellow"
#POWERLEVEL9K_USER_ROOT_BACKGROUND="black"
#POWERLEVEL9K_USER_ROOT_FOREGROUND="red"

POWERLEVEL9K_HOST_LOCAL_BACKGROUND="249"
POWERLEVEL9K_HOST_LOCAL_FOREGROUND="black"
POWERLEVEL9K_HOST_REMOTE_BACKGROUND="yellow"
POWERLEVEL9K_HOST_REMOTE_FOREGROUND="black"

POWERLEVEL9K_CONTEXT_DEFAULT_BACKGROUND="white"
POWERLEVEL9K_CONTEXT_DEFAULT_FOREGROUND="black"
POWERLEVEL9K_CONTEXT_REMOTE_BACKGROUND="white"
POWERLEVEL9K_CONTEXT_REMOTE_FOREGROUND="black"
POWERLEVEL9K_CONTEXT_SUDO_BACKGROUND="yellow"
POWERLEVEL9K_CONTEXT_SUDO_FOREGROUND="black"
POWERLEVEL9K_CONTEXT_REMOTE_SUDO_BACKGROUND="yellow"
POWERLEVEL9K_CONTEXT_REMOTE_SUDO_FOREGROUND="black"
POWERLEVEL9K_CONTEXT_ROOT_FOREGROUND="white"
POWERLEVEL9K_CONTEXT_ROOT_BACKGROUND="red"

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

#POWERLEVEL9K_ROOT_INDICATOR_BACKGROUND="red"
#POWERLEVEL9K_ROOT_INDICATOR_FOREGROUND="white"

POWERLEVEL9K_TIME_BACKGROUND="clear"
POWERLEVEL9K_TIME_FOREGROUND="249"

POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND="white"

#POWERLEVEL9K_CUSTOM_PROMPT="printf '%s\u03bb' '%($(issu)-%B%F{red}-%F{white})%F'"
#POWERLEVEL9K_CUSTOM_PROMPT_FOREGROUND="black"
#POWERLEVEL9K_CUSTOM_PROMPT_BACKGROUND="249"

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

# {{{ = ZPLUG PLUGINS ========================================================
#https://github.com/zsh-users/zsh-autosuggestions
zplug_cmd "zsh-users/zsh-autosuggestions"
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=25

# https://github.com/zsh-users/zaw
zplug_cmd "zsh-users/zaw"

# {{{ - OH MY ZSH ------------------------------------------------------------
# https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins

zplug_cmd "plugins/catimg", from:oh-my-zsh
#plugins/common-aliases
zplug_cmd "plugins/command-not-found", from:oh-my-zsh
#plugins/debian
zplug_cmd "plugins/dirhistory", from:oh-my-zsh
zplug_cmd "plugins/docker", from:oh-my-zsh # docker autocompletion
zplug_cmd "plugins/encode64", from:oh-my-zsh # encode64/decode64
#https://github.com/robbyrussell/oh-my-zsh/wiki/Plugin:git
zplug_cmd "plugins/git", from:oh-my-zsh
zplug_cmd "plugins/git-extras", from:oh-my-zsh # completion for apt:git-extras
zplug_cmd "plugins/httpie", from:oh-my-zsh # completion for apt:httpie (http)
zplug_cmd "plugins/jsontools", from:oh-my-zsh # *_json
zplug_cmd "plugins/mvn", from:oh-my-zsh # maven completion
zplug_cmd "plugins/sudo", from:oh-my-zsh # add sudo via 2xESC
zplug_cmd "plugins/systemd", from:oh-my-zsh # systemd sc-* aliases
zplug_cmd "plugins/tmux", from:oh-my-zsh
zplug_cmd "plugins/urltools", from:oh-my-zsh # urlencode/-decode
zplug_cmd "plugins/vagrant", from:oh-my-zsh
zplug_cmd "plugins/vscode", from:oh-my-zsh # vs* aliases
zplug_cmd "plugins/web-search", from:oh-my-zsh
zplug_cmd "plugins/wd", from:oh-my-zsh # wd (warp directory)
#zplug_cmd "zsh-users/zsh-history-substring-search"

# ssh agent: https://github.com/robbyrussell/oh-my-zsh/tree/master/plugins/ssh-agent
# but not on remote machines (use ssh -A agent forwarding if needed)
if ! cl::is_ssh; then
  zplug_cmd "plugins/ssh-agent", from:oh-my-zsh # auto run ssh-agent
fi
# }}} - OH MY ZSH ------------------------------------------------------------

# activate syntax highlighting, load last to affect everything loaded before
# apt: zsh-syntax-highlighting - https://github.com/zsh-users/zsh-syntax-highlighting
[[ -r "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] \
  && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  || zplug "zsh-users/zsh-syntax-highlighting"
# }}} = ZPLUG PLUGINS ========================================================

# {{{ = ZPLUG LOAD ===========================================================
zplug_cmd check --verbose \
  || { cl::q_yesno "Install missing zplug packages" && zplug install }

# load local plugins
#zplug_cmd "~/.zsh.d", from:local

zplug_cmd load
# remove temporary alias
unalias zplug_cmd
# }}} = ZPLUG LOAD ===========================================================

# {{{ = ZPLUG SETTINGS =======================================================
# tmux
#ZSH_TMUX_AUTOSTART # default: false, auto start tmux on login
#ZSH_TMUX_AUTOSTART_ONCE # default: true, start for ever (nested) zsh session
#ZSH_TMUX_AUTOCONNECT # default: true, try connect to existing else new
#ZSH_TMUX_AUTOQUIT # default: ZSH_TMUX_AUTOSTART, close session if tmux exits
#ZSH_TMUX_FIXTERM # default: true, set TERM=screen(256color)
# }}} = ZPLUG SETTINGS =======================================================

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
# http://zsh.sourceforge.net/Doc/Release/Completion-System.html
# http://zsh.sourceforge.net/Guide/zshguide06.html
zstyle ':completion:*' completer _complete _match _approximate
# _exand: use only with tab -> complete-word, not with expand-or-complete (default)
#zstyle ':completion:*' completer _expand _complete _match _approximate _ignored

# _match context: dont insert * at the end (when pressing tab)
#zstyle ':completion:*:match:*' original only

# _expand context: suggest original string too
#zstyle ':completion:*:expand:*' tag-order all-expansions

# _approximate context: allow X errors when using the approximate completer
#zstyle ':completion:*:approximate:*' max-errors 2 numeric
# increase number of errors allowed (fuzzy matching) depending on lenght
zstyle -e ':completion:*:approximate:*' \
        max-errors 'reply=($((($#PREFIX+$#SUFFIX)/3))numeric)'

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
#zstyle '*' hosts $HOST motoko.intra puppet.intra bateau.intra togusa.intra yav.in

# ssh agent: https://github.com/robbyrussell/oh-my-zsh/tree/master/plugins/ssh-agent
# but not on remote machines (use ssh -A agent forwarding if needed)
if ! cl::is_ssh; then
  # ssh-agent forwarding
  zstyle :omz:plugins:ssh-agent agent-forwarding on
  # ssh-agent identities
  #zstyle :omz:plugins:ssh-agent identities id_rsa ...
  # ssh-agent max identity lifetime
  #zstyle :omz:plugins:ssh-agent lifetime 4h
fi

# file type command detecton
#compctl -g '*.ebuild' ebuild
#compctl -g '*.tex' + -g '*(-/)' latex
#compctl -g '*.dvi' + -g '*(-/)' dvipdf dvipdfm
#compctl -g '*.java' + -g '*(-/)' javac
#compctl -g '*.tar.bz2 *.tar.gz *.bz2 *.gz *.jar *.rar *.tar *.tbz2 *.tgz *.zip *.Z' \
#        + -g '*(-/)' extract
compctl -g '*.mp3 *.ogg *.opus *.mod *.wav *.avi *.mpg *.mpeg *.wmv *.mkv *.webm *.mp4' \
        + -g '*(-/)' mpv
compctl -g '*.py' python
#compctl -g '*(-/D)' cd
#compctl -g '*(-/)' mkdir

# user name auto completion
function _userlist {
  [[ -r /etc/passwd ]] && reply=($(cat /etc/passwd | cut -d : -f 1))
}
compctl -K _userlist ps -fU
compctl -K _userlist finger

set COMPLETE_ALIASES
# }}} - COMPLETION -----------------------------------------------------------
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
# {{{ = ZSH KEYBINDINGS ======================================================
# zsh-autosuggestions
bindkey '^ ' autosuggest-accept

#http://zsh.sourceforge.net/Doc/Release/Zsh-Line-Editor.html#Standard-Widgets
# emacs key bindings
#bindkey -e
# vi key bindings
bindkey -v

bindkey '^x^x' execute-named-cmd # in addition to alt-x (if alt not working)
bindkey '^x^z' execute-last-named-cmd # in addition to alt-x (if alt not working)

# sudo
#bindkey "^[^[" sudo-command-line # esc, esc (if \e\e doesn't work)

# {{{ - COMPLETION -----------------------------------------------------------
# lookup spaces
bindkey ' ' magic-space
#bindkey '^ ' globalias

#if zplug check "zsh-users/zsh-history-substring-search"; then
#  bindkey '^[OA' history-substring-search-up # up (vs. up-line-or-history)
#  bindkey '^[OB' history-substring-search-down # down (vs. down-line-or-history)
#fi
#bindkey '^[[A' history-beginning-search-backward # up (vs. up-line-or-history)
#bindkey '^[OA' history-beginning-search-backward # up (vs. up-line-or-history)
#bindkey '^[[B' history-beginning-search-forward # down (vs. down-line-or-history)
#bindkey '^[OB' history-beginning-search-forward # down (vs. down-line-or-history)
# }}} - COMPLETION -----------------------------------------------------------
# {{{ - CURSOR NAVIGATION ----------------------------------------------------
#WORDCHARS="*?_-.[]~=/&;!#$%^(){}<>""

# input navigation using arrow keys (plus emacs: ctrl-a/e, alt-b/f)
bindkey '^[[1;5D' backward-word # ctrl-left
bindkey '^[[1;5C' forward-word # ctrl-right
bindkey '^[[1;5A' beginning-of-line # ctrl-up
bindkey '^[[1;5B' end-of-line # ctrl-down

# ctrl-w/a/s/d (w/a/r/s on colemak) arrow key navigation
#bindkey '^w' up-line-or-history # ctrl-w
#bindkey '^a' down-line-or-history # ctrl-r
#bindkey '^r' down-line-or-history # ctrl-r
#bindkey '^s' up-line-or-history # ctrl-w


if [[ "$TERM" = *xterm* ]]; then
  # end of line: emacs ctrl-a, vim
  #bindkey "${terminfo[khome]}" beginning-of-line
  bindkey "\e[1~" beginning-of-line # HOME
  bindkey '^[[7~' beginning-of-line  # HOME

  #bindkey "${terminfo[kend]}" end-of-line
  bindkey '\e[4~' end-of-line # END
  bindkey '^[[8~' end-of-line # END rxvt (also: ctrl-e)

  bindkey '^[[2~' overwrite-mode # INS (emacs: ctrl-x,ctrl-o)
  bindkey '^[[3~' delete-char # DEL (also: ctrl-d -> delete-char-or-list)
  bindkey '^?' backward-delete-char # BS (also: ctrl-h and ctrl-w -> word)
fi
# }}} - CURSOR NAVIGATON -----------------------------------------------------
# {{{ - VI MODE --------------------------------------------------------------
# vi mode
# open command line in vim
bindkey -M vicmd '^v' edit-command-line

# search histor using / and ?
#bindkey -M vicmd '?' history-incremental-search-backward
#bindkey -M vicmd '/' history-incremental-search-forward
# }}} - VI MODE --------------------------------------------------------------
# {{{ - ZAW ------------------------------------------------------------------
# https://github.com/zsh-users/zaw
if zplug check "zsh-users/zaw"; then
  bindkey '^[r' zaw # alt-r
  bindkey '^r' zaw-history # ctrl-r

  # git bindings
  bindkey '^[v^[l' zaw-git-log # alt-v, alt-l
  bindkey '^[v^[r' zaw-git-reflog # alt-v, alt-r
  bindkey '^[v^[s' zaw-git-status # alt-v, alt-s

  # filterlist bindings
  bindkey -M filterselect '^r' down-line-or-history
  bindkey -M filterselect '^w' up-line-or-history
  bindkey -M filterselect '^ ' accept-search
  bindkey -M filterselect '\e' send-break # esc
  bindkey -M filterselect '^[' send-break # esc

  # filterlist style
  zstyle ':filter-select:highlight' matched fg=green
  zstyle ':filter-select' max-lines 5
  zstyle ':filter-select' case-insensitive yes
  zstyle ':filter-select' extended-search yes
fi
# }}} - ZAW ------------------------------------------------------------------
# }}} = ZSH KEYBINDINGS ======================================================

# {{{ = INCLUDES =============================================================
# include os/host specific functon files
source_ifex_custom $HOME/.zsh.d/functions
# include os/host specific aliase files
source_ifex_custom $HOME/.zsh.d/aliases
# include os/host specific zshrc files
source_ifex_custom $HOME/.zsh.d/zshrc
# }}} = INCLUDES =============================================================

# {{{ = FINAL LOGIN EXECUTIONS ===============================================
# {{{ - X WINDOWS ------------------------------------------------------------
# are we in a x-windows session?
#if [[ -n "${DESKTOP_SESSION-}" ]]; then
#  # is gnome-keyring-daemon availlable? use it as ssh agent
#  if command -v gnome-keyring-daemon 2>&1 > /dev/null; then
#    export $(gnome-keyring-daemon --start)
#    # SSH_AGENT_PID required to stop xinitrc-common from starting ssh-agent
#    export SSH_AGENT_PID=${GNOME_KEYRING_PID:-gnome}
#  fi
#fi
# }}} - X WINDOWS ------------------------------------------------------------
# {{{ - DTAG -----------------------------------------------------------------
# enabale dtag (when available)
#(command -v dtags-activate >& /dev/null \
#  && eval "$(dtags-activate zsh)" \
#  || cl::p_war "unable to activate dtags, dtags-activate not found" \
#) &!
# }}} - DTAG -----------------------------------------------------------------
# {{{ - X STUFF --------------------------------------------------------------
#if [[ -n "$DESKTOP_SESSION" ]]; then
#fi
# }}} - X STUFF --------------------------------------------------------------
# }}} = FINAL LOGIN EXECUTIONS ===============================================
