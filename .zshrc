# ~/.zshrc: executed by zsh(1)
# interactive shell: .zshenv > .zshrc
# login shell: .zshenv > .zprofile > .zshrc > zlogin / .zlogout
#
# https://manpages.ubuntu.com/manpages/bionic//man1/zsh.1.html
# 1. Commands are first read from /etc/zsh/zshenv; this cannot be overridden
# 2. Commands are then read from $ZDOTDIR/.zshenv.
# 3. If the shell is a login shell, commands are read from /etc/zsh/zprofile and then $ZDOTDIR/.zprofile.
# 4. Then, if the shell is interactive, commands are read from /etc/zsh/zshrc and then $ZDOTDIR/.zshrc.
# 5. Finally, if the shell is a login shell, /etc/zsh/zlogin and $ZDOTDIR/.zlogin are read.
#
# https://zsh.sourceforge.io/Intro/intro_3.html
# .zshrc is sourced in interactive shells.
# It should contain commands to set up aliases, functions, options, key bindings, etc.

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: zsh zshrc shell-script

# TODO:
# look into https://github.com/clvv/fasd

# PROFILING (DEBUG)
#zmodload zsh/zprof
#echo "zprof start: $(date)"

# {{{ = ENVIRONMENT (INTERACTIVE SHELL) ======================================
# For login shell / general variable like PATH see ~/.common_profile

# globally raise (but never lower) the default debug level of cl::p_dbg
# this is set in ~/.common_profile to be available for all shells, override
# here if needed
#export DEBUG_LVL=3

# {{{ - CORE OPTIONS & COMMONS -----------------------------------------------
# pre-requirements
setopt extendedglob
# allow # comments in shell
setopt interactivecomments

# include core functions, must simply be there (used everywhere)
source $HOME/lib/commons.sh
# }}} - CORE OPTIONS & COMMONS -----------------------------------------------

# {{{ - SECURITY & PRIVACY ---------------------------------------------------
# private session
#export HISTFILE="" # don't create shell history file
#export SAVEHIST=0 # set shell history file limit to zero
# shared session
export HISTSIZE=10000 # set in-memory history limit
export SAVEHIST=10000 # set history file limit
export HISTFILE="$ZDOTDIR/.zhistory" # set history file (default: ~/.zsh_history)

setopt INC_APPEND_HISTORY # write immediately (default: on exit only)
#setopt HIST_IGNORE_DUPS # don't add duplicates
setopt HIST_IGNORE_ALL_DUPS # delete old entry in favor of new one if duplicate
setopt SHARE_HISTORY # share history between sesions
#setopt EXTENDED_HISTORY # store in ":start:elapsed;command" format
setopt HIST_IGNORE_SPACE # don't record lines stating with a space (privacy)
#setopt HIST_REDUCE_BLANKS # remove unnecessary spaces
#setopt HIST_VERIFY # don't execute immediately after history expansion
#setopt HIST_NO_STORE # don't store history / fc commands
setopt HIST_NO_FUNCTIONS # don't store function definitions
# }}} - SECURITY & PRIVACY ---------------------------------------------------

# {{{ -- SYSTEM/ENV STATE ----------------------------------------------------
if $IS_PC; then
  if $IS_PC_NATIVE; then
    cl::p_dbg 0 1 "Native PC (x68 architecture) detected."
  else
    cl::p_msg "Non-native PC (x68 architecture) detected."
  fi
else
  cl::p_msg "Non-PC architecture detected ($ARCH != x68)."
  if $IS_ANDROID; then
    if $IS_TERMUX; then
      cl::p_msg "Android (TERMUX) envrionment detected."
    else
      cl::p_msg "Android envrionment detected."
    fi
  fi
fi

if $IS_WSL; then
 if ! $IS_WSL2; then
    cl::p_msg "WSL1 environment detected."
    #cl::p_msg "WSL1 environment detected. Additional features are disabled (only available in WSL2)."
  else
    cl::p_msg "WSL2 environment detected."
    #cl::p_msg "WSL2 environment detected. Enabling additional features ..."
#    if [[ ! -f "${HOME}/home/wincrypt-wsl.sock" ]]; then
#      cat <<EOL
#WARNING: ${HOME}/home/wincrypt-wsl.sock not found, if you want to use pageant in wsl:
#
#  # See https://github.com/buptczq/WinCryptSSHAgent for details
#  # Run this in in an elevated windows cmd.exe:
#  > choco install wincrypt-sshagent
#EOL
#    else
#      export SSH_AUTH_SOCK=${HOME}/home/wincrypt-wsl.sock
#    fi
# TODO check if this works, if so then check if it is already running (currently started repetedly resulting in error)
#    if [[ -e "${HOME}/bin/wsl-ssh-pageant.exe" ]]; then
#      export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
#      if ! ss -a | grep -q "$SSH_AUTH_SOCK"; then
#        rm -f "$SSH_AUTH_SOCK"
#        echo "Starting 'wsl-ssh-pageant.exe -force -systray -wsl \"$SSH_AUTH_SOCK\"' ..."
#        wsl-ssh-pageant.exe -force -systray -wsl "$SSH_AUTH_SOCK" &
#      fi
#    else
#      cat <<EOL
#WARNING: ${HOME}/bin/wsl-ssh-pageant-amd64-gui.exe not found, if you want to use pageant in wsl:
#
#wget -O ~/bin/wsl-ssh-pageant.exe "https://github.com/benpye/wsl-ssh-pageant/releases/latest/download/wsl-ssh-pageant-amd64-gui.exe"
#chmod +x ~/bin/wsl-ssh-pageant.exe
#EOL
#    fi
  fi
fi

if $IS_DOCKER; then
  cl::p_msg "Docker environment detected."
fi
# }}} - SYSTEM/ENV STATE -----------------------------------------------------


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

# {{{ = CORE FUNCTIONS, SOURCING, ALIASES ====================================
# include given source file(s) if they exist,
source_ifex () {
  [[ -z "${1-}" ]] && cl::p_usg "$0 source-file.." && return 1
  while [[ -n "$1" ]]; do
    cl::p_dbg 0 2 "Checking for optional source file '$1' ..."
    if [[ -r "$1" ]]; then
      cl::p_dbg 0 1 "Loading optional source file '$1' (file found) ..."
      source "$1" && cl::p_dbg 0 1 "... done (file successfully loaded)." \
        || cl::p_err "Command 'source $1' returned non-OK exit code!"
    else
      cl::p_dbg 0 2 "... not found, skipped (OK since optional)."
    fi
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
      $($IS_ANDROID && print "${base_file}-${os}_android.zsh") \
      "${base_file}-${host}.zsh" \
      "${base_file}-${host}-${os}.zsh" \
      $($IS_WSL && print "${base_file}-${host}-${os}_wsl.zsh") \
      $($IS_ANDROID && print "${base_file}-${host}-${os}_android.zsh")
    shift
  done
  return 0
}

# include common and zsh specific aliases
source_ifex $HOME/.aliases
source_ifex $HOME/.zsh.d/aliases.zsh

# include common and zsh specific aliases
source_ifex $HOME/.zsh.d/functions/functions.zsh

# hash some common directories for easy access existing (if they exist)
# TODO consider moving this to commons.sh and use in host specific files as well
_hash_mountpoints() {
  # define directories to hash
  # suffixes "_*" are ignored for hash names. they can be used define more than one path per hash (first one found is used)
  typeset -A _hashdirs=(
    [c]="/mnt/c"
    [d]="/mnt/d"
    [e]="/mnt/e"
    [f]="/mnt/f"
    [c_GVFS]="/media/$USERNAME/Windows"
    [d_GVFS]="/media/$USERNAME/Games"
    [e_GVFS]="/media/$USERNAME/Data"
    [f_GVFS]="/media/$USERNAME/Temp"
    [l]="/mnt/data"
    [s]="/mnt/stash"
    [l_GVFS]="/run/user/1000/gvfs/smb-share:server=saito,share=data"
    [s_GVFS]="/run/user/1000/gvfs/smb-share:server=saito,share=stash"
  )
  local key dir
  for key in ${(k)_hashdirs}; do
    dir=${_hashdirs[${key}]}
    [[ -d "$dir" ]] || continue
    key=${key%%_*}  # remove suffix
    # duplicate alternative directories (or otherwise already existing) on this host?
    local existing_hash=$(hash -d 2>/dev/null | grep -E "^${key}=.*")
    if [[ -n "$existing_hash" ]]; then
      cl::p_war "hash -d ${key}=${dir} skipped, conflict with existing hash: ${existing_hash}"
      continue
    fi
    cl::p_dbg 0 1 "hash -d ${key}=${dir}"
    hash -d "${key}=${dir}"
  done
}
_hash_mountpoints

is_me() { [[ $USER:l =~ ^(cbaoth|(a\.)?weyer)$ ]]; }
# }}} = CORE FUNCTIONS, SOURCING, ALIASES ====================================

# {{{ = ZPLUG PREPARE ========================================================
# disable oh-my-zsh auto update, we'll do it below via zplug
export DISABLE_AUTO_UPDATE=true
#export DISABLE_UPDATE_PROMPT=true
#export UPDATE_ZSH_DAYS=30

# custom ZPLUG modes (full: load all, mini: load less, skip: load none)
ZPLUG_MODE_DEFAULT="full"
# optionally set deviating ZPLUG mode depending on the environment
ZPLUG_MODE_WSL="full"       # load all zplugs when in WSL
ZPLUG_MODE_DOCKER="mini"    # load all zplugs when inside a Ddocker containers
ZPLUG_MODE_ANDROID="skip"   # skip zplug when on Android (maybe much too slow or even crash the terminal)

ZPLUG_MODE=$ZPLUG_MODE_DEFAULT
$IS_ANDROID && ZPLUG_MODE=${ZPLUG_MODE_ANDROID:=${ZPLUG_MODE_DEFAULT}} \
  && [[ $ZPLUG_MODE != $ZPLUG_DEFAULT_MODE ]] \
  && cl::p_msg "Switching to non-default zplug mode '$ZPLUG_MODE' for Android as per \$ZPLUG_MODE_ANDROID=$ZPLUG_MODE_ANDROID."
$IS_WSL     && ZPLUG_MODE=${ZPLUG_MODE_WSL:-$ZPLUG_MODE_DEFAULT} \
  && [[ $ZPLUG_MODE != $ZPLUG_DEFAULT_MODE ]] \
  && cl::p_msg "Switching to non-default zplug mode '$ZPLUG_MODE' for WSL as per \$ZPLUG_MODE_WSL=$ZPLUG_MODE_WSL."
$IS_DOCKER  && ZPLUG_MODE=${ZPLUG_MODE_DOCKER:-$ZPLUG_MODE_DEFAULT} \
  && [[ $ZPLUG_MODE != $ZPLUG_DEFAULT_MODE ]] \
  && cl::p_msg "Switching to non-default zplug mode '$ZPLUG_MODE' for Docker as pere \$ZPLUG_MODE_DOCKER=$ZPLUG_MODE_DOCKER."
ZPLUG_MODE_IS_SKIP=$([[ $ZPLUG_MODE = 'skip' ]] && 'true' || print 'false')
ZPLUG_MODE_IS_MINI=$([[ $ZPLUG_MODE = 'mini' ]] && 'true' || print 'false')
ZPLUG_MODE_IS_FULL=$([[ $ZPLUG_MODE = 'full' ]] && 'true' || print 'false')

IS_ZPLUG=false
ZPLUG_CMD=:
ZPLUG_SKIP_INSTALL_PROMPT=$([[ -f $HOME/.zplug-skip-install-prompt ]] && print true || print false)
ZPLUG_IS_NEW_INSTALL=false
ZPLUG_IS_NEW_INSTALL_FORCED=false
if [[ -f "$HOME/.zplug-force-install" ]]; then
  rm -f "$HOME/.zplug-force-install"
  ZPLUG_IS_NEW_INSTALL_FORCED=true
fi

_zplug_source() {
  cl::p_dbg 0 1 "Sourcing ~/.zplug/init.sh ..."
  time source "$HOME/.zplug/init.zsh" \
    && IS_ZPLUG=true && ZPLUG_CMD=zplug
}

_zplug_install() {
  cl::p_msg "Removing previous/corrupted ~/.zplug ..."
  rm -rf "$HOME/.zplug" >& /dev/null
  cl::p_msg "Downloading and installing zplug ..."
  if wget -q -O - https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh; then
    ZPLUG_IS_NEW_INSTALL=true
    cl::p_dbg 0 1 "Waiting 1 sec post-install for parallel steps to finish ..."
    sleep 1
    _zplug_source
  else
    cl::p_err "Error installing/init zplug, not all features may be available!"
  fi
}

_zplug_init() {
  if $IS_WSL && [[ ${ZPLUG_MODE_WSL:-${ZPLUG_MODE_DEFAULT:-full}} = 'skip' ]]; then
      cl::p_dbg 0 1 "zplug init skipped as per \$ZPLUG_MODE_WSL=$ZPLUG_MODE_WSL (with \$ZPLUG_MODE_DEFAULT=$ZPLUG_MODE_DEFAULT > 'full' as fallback strategy)."
    return 0
  elif $IS_ANDROID && [[ ${ZPLUG_MODE_ANDROID:-${ZPLUG_MODE_DEFAULT:-full}} = 'skip' ]]; then
    cl::p_dbg 0 1 "zplug init skipped as per \$ZPLUG_MODE_ANDROID=$ZPLUG_MODE_ANDROID (with \$ZPLUG_MODE_DEFAULT=$ZPLUG_MODE_DEFAULT > 'full' as fallback)."
    return 0
  elif $IS_DOCKER && [[ ${ZPLUG_MODE_DOCKER:-${ZPLUG_MODE_DEFAULT:-full}} = 'skip' ]]; then
    cl::p_dbg 0 1 "zplug init skipped as per \$ZPLUG_MODE_DOCKER=$ZPLUG_MODE_DOCKER (with \$ZPLUG_MODE_DEFAULT=$ZPLUG_MODE_DEFAULT > 'full' as fallback strategy)."
    return 0
  elif $ZPLUG_MODE_IS_SKIP; then
    cl::p_dbg 0 1 "zplug init skipped as per \$ZPLUG_MODE=$ZPLUG_MODE (with \$ZPLUG_MODE_DEFAULT=$ZPLUG_MODE_DEFAULT > 'full' as fallback strategy)."
    return 0
  fi
  if ${ZPLUG_IS_NEW_INSTALL_FORCED:-false}; then
    cl::p_msg "Forcing new zplug installation (~/.zplug-force-install found) ..."
    _zplug_install
    return 0
  fi
  if [[ -f "$HOME/.zplug/init.zsh" ]]; then
    cl::p_dbg 0 1 "zplug found (~/.zplug/init.zsh)"
    ${IS_WSL-false} && cl::p_dbg 0 1 "To disable zplug in WSL set ZPLUG_IS_WSL_SKIP=true"
    ${IS_ANDROID:-false} && cl::p_dbg 0 1 "To disable zplug on Android set ZPLUG_IS_ANDROID_SKIP=true"
    _zplug_source
    return 0
  fi
  if ${ZPLUG_SKIP_INSTALL_PROMPT:-false}; then
    cl::p_dbg 0 1 "zplug install prompt skipped since ~/.zplug-skip-install-prompt exists"
    return 0
  fi
  if cl::q_yesno "Install zplug now (or never ask again)?"; then
    _zplug_install
  else
    if [[ -d "$HOME/.zplug" ]]; then
      cl::p_war "zplug installation incomplete/corrupted since ~/.zplug exists but ~/.zplug/init.zsh does not."
      cl::p_msg "Try removing the folder and restart zsh:"
      echo "  rm -rf ~/.zplug"
    fi
    cl::p_msg "To manually install and setup zplug, run the following commands:"
    echo "  wget -q -O - https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh"
    echo "  sleep 1; source ~/.zplug/init.zsh"
    echo "  zplug install"
    cl::p_msg "Creating file ~/.zplug-skip-install-prompt to not ask again (delete file to r-enable)."
    touch ~/.zplug-skip-install-prompt
  fi
}

case $ZPLUG_MODE in
  skip) ;;
  *)
    _zplug_init
esac

# self-manage zplug (zplug update will upldate zplug itself)
$ZPLUG_CMD 'zplug/zplug', hook-build:'zplug --self-manage'
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
#ZSH_THEME="powerlevel9k/powerlevel9k"
ZSH_THEME="powerlevel10k/powerlevel10k"

# load pewerlevel9k (if availlable)
# apt: zsh-theme-powerlevel9k - https://github.com/bhilburn/powerlevel9k
#source_ifex /usr/share/powerlevel9k/powerlevel9k.zsh-theme
POWERLEVEL9K_ISACTIVE=false  # for backward compatibility (deprecated)
POWERLEVEL10K_ISACTIVE=false
if $IS_ZPLUG; then
  #$ZPLUG_CMD "bhilburn/powerlevel9k", use:powerlevel9k.zsh-theme \
  #  && POWERLEVEL9K_ISACTIVE=true || POWERLEVEL9K_ISACTIVE=false
  $ZPLUG_CMD "romkatv/powerlevel10k", as:theme, depth:1 \
    && { POWERLEVEL9K_ISACTIVE=true; POWERLEVEL10K_ISACTIVE=true }
fi

# {{{ - - General ------------------------------------------------------------
# TODO review after switching to powerlevel10k
# The 9K parameters should be backward compatible but in it's current state it
# is not identical to the original 9k layout (parts are missing).
# The default seems fine though, so we'll keep it for now until i have more
# time to investigate/improve.

POWERLEVEL9K_DISABLE_RPROMPT=false
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(host dir dir_writable vcs) # disk_usage
# POWERLEVEL9K_LEFT_PROMPT_ELEMENTS+=(newline context) # root_indicator
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time \
                                    background_jobs docker_machine)
#[[ "$HOST:l" =~ ^(puppet|weyera).*$ ]]
$ZPLUG_MODE_FULL && POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS+=(battery)
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
$ZPLUG_CMD "zsh-users/zsh-autosuggestions"
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=25

# https://github.com/zsh-users/zaw
$ZPLUG_CMD "zsh-users/zaw"

# {{{ - OH MY ZSH ------------------------------------------------------------
# https://github.com/robbyrussell/oh-my-zsh/wiki/Plugins
# WSL: May be skipped (see above)

$ZPLUG_CMD "plugins/catimg", from:oh-my-zsh
#plugins/common-aliases
$ZPLUG_CMD "plugins/command-not-found", from:oh-my-zsh
#plugins/debian
$ZPLUG_CMD "plugins/dirhistory", from:oh-my-zsh
$ZPLUG_CMD "plugins/docker", from:oh-my-zsh # docker autocompletion
$ZPLUG_CMD "plugins/encode64", from:oh-my-zsh # encode64/decode64
#https://github.com/robbyrussell/oh-my-zsh/wiki/Plugin:git
if $IS_MODE_FULL; then
  $ZPLUG_CMD "plugins/git", from:oh-my-zsh
  $ZPLUG_CMD "plugins/git-extras", from:oh-my-zsh # completion for apt:git-extras
else
  $ZPLUG_CMD "plugins/git-fast", from:oh-my-zsh
fi
$ZPLUG_CMD "plugins/httpie", from:oh-my-zsh # completion for apt:httpie (http)
$ZPLUG_CMD "plugins/jsontools", from:oh-my-zsh # *_json
$ZPLUG_CMD "plugins/mvn", from:oh-my-zsh # maven completion
$ZPLUG_CMD "plugins/sudo", from:oh-my-zsh # add sudo via 2xESC
$ZPLUG_CMD "plugins/systemd", from:oh-my-zsh # systemd sc-* aliases
$ZPLUG_CMD "plugins/tmux", from:oh-my-zsh
$ZPLUG_CMD "plugins/urltools", from:oh-my-zsh # urlencode/-decode
$ZPLUG_CMD "plugins/vagrant", from:oh-my-zsh
$ZPLUG_CMD "plugins/vscode", from:oh-my-zsh # vs* aliases
$ZPLUG_CMD "plugins/web-search", from:oh-my-zsh
$ZPLUG_CMD "plugins/wd", from:oh-my-zsh # wd (warp directory)
#$ZPLUG_CMD "zsh-users/zsh-history-substring-search"

# ssh agent: https://github.com/robbyrussell/oh-my-zsh/tree/master/plugins/ssh-agent
# but not on remote machines and wsl/termxu (use ssh -A agent forwarding if needed)
if $ZPLUG_MODE_IS_FULL && ! cl::is_ssh; then
  $ZPLUG_CMD "plugins/ssh-agent", from:oh-my-zsh # auto run ssh-agent
fi
# }}} - OH MY ZSH ------------------------------------------------------------

# activate syntax highlighting, load last to affect everything loaded before
# apt: zsh-syntax-highlighting - https://github.com/zsh-users/zsh-syntax-highlighting
[[ -r "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] \
  && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  || $ZPLUG_CMD "zsh-users/zsh-syntax-highlighting"
# }}} = ZPLUG PLUGINS ========================================================

# {{{ = ZPLUG LOAD ===========================================================
# check for updates no more than every 14 days
_zplug_install_and_update() {
  if $ZPLUG_IS_NEW_INSTALL_FORCE || cl::q_yesno "Install missing zplug packages"; then
    if $ZPLUG_CMD check --verbose; then
      cl::p_war "Please be patient. This may take a while, without progress output ..."
      zplug install
    else
      cl::p_msg "No missing zplug packages found."
    fi
  fi
  cl::p_msg "Updating zplug packages ..."
  zplug update && touch ~/.zplug/lastcheck
  return 0
}

if $IS_ZPLUG; then
  if $ZPLUG_IS_NEW_INSTALL; then
    cl::p_msg "New zplug installation requested, checking ..."
    _zplug_install_and_update
  elif  [[ ! -f ~/.zplug/lastcheck ]]; then
    cl::p_msg "No info about last zplug install/update, checking ..."
    _zplug_install_and_update
  elif [[ -e ~/.zplug/lastcheck && $(($(date +%s) - $(stat -c %Y ~/.zplug/lastcheck))) -gt 1209600 ]]; then
    cl::p_msg "Last zplug install/update more than 14 days ago, checking ..."
    _zplug_install_and_update
  else
    cl::p_dbg 0 2 "Last successfull update less than 14 days ago ($((($(date +%s) - $(stat -c %Y ~/.zplug/lastcheck))/60/60/24)) days), skipping ..."
  fi
fi

# load local plugins
#$ZPLUG_CMD "~/.zsh.d", from:local

$ZPLUG_CMD load
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
export ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump"
# enable new style completion system
autoload -Uz compinit
# check cache only once per day (can be slow when done more frequently)
# https://gist.github.com/ctechols/ca1035271ad134841284
#if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
#  compinit
#  #touch .zcompdump
#else
#  compinit -C
#fi

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
#zstyle '*' hosts $HOST motoko.intra puppet.intra bateau.intra togusa.intra 11001001.org

# ssh agent: https://github.com/robbyrussell/oh-my-zsh/tree/master/plugins/ssh-agent
# but not on remote machines (use ssh -A agent forwarding if needed)
if $ZPLUG_MODE_IS_FULL && ! cl::is_ssh; then
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
bindkey -e
# vi key bindings
#bindkey -v

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
if $ZPLUG_CMD check "zsh-users/zaw"; then
  bindkey '^[r' zaw # alt-r
  bindkey '^r' zaw-history # ctrl-r

  # git bindings
  bindkey '^[v^[l' zaw-git-log # alt-v, alt-l
  bindkey '^[v^[r' zaw-git-reflog # alt-v, alt-r
  bindkey '^[v^[s' zaw-git-status # alt-v, alt-s

  # filterlist bindings
  if $IS_ZPLUG; then
    bindkey -M filterselect '^r' down-line-or-history
    bindkey -M filterselect '^w' up-line-or-history
    bindkey -M filterselect '^ ' accept-search
    bindkey -M filterselect '\e' send-break # esc
    bindkey -M filterselect '^[' send-break # esc
  fi

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
#source_ifex_custom $HOME/.zsh.d/functions
fpath=($HOME/.zsh.d/functions $HOME/.zfunc $fpath)
# include os/host specific aliase files
source_ifex_custom $HOME/.zsh.d/aliases
# include os/host specific zshrc files
source_ifex_custom $HOME/.zsh.d/zshrc
# }}} = INCLUDES =============================================================

# {{{ = FINAL LOGIN EXECUTIONS ===============================================
# {{{ - X WINDOWS ------------------------------------------------------------
# Ensure that Gnome Key Ring allows access to SSH keys
# Disabled e.g. in favor of KeePassXC (Secret Service Integration)
#
# are we in a x-windows session?
if [[ -n "${DESKTOP_SESSION-}" ]]; then
    # is gnome-keyring-daemon availlable? use it as ssh agent
    if command -v gnome-keyring-daemon 2>&1 > /dev/null; then
        # start unless already running
        if [[ -n "${GNOME_KEYRING_PID-}" ]]; then
            export $(gnome-keyring-daemon --start --components=ssh) #--components=pkcs11,secret,ssh)
            # SSH_AGENT_PID required to stop xinitrc-common from starting ssh-agent
            export SSH_AGENT_PID=${GNOME_KEYRING_PID:-gnome}
        fi
    fi
fi
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
#    ...
#fi
# }}} - X STUFF --------------------------------------------------------------
# {{{ - DEV ------------------------------------------------------------------
# https://github.com/nvm-sh/nvm?tab=readme-ov-file#installing-and-updating
if [[ -d "$HOME/.nvm" ]]; then
  export NVM_DIR="$HOME/.nvm"
  # load: nvm
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  # load: nvm bash_completion
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
fi

# anaconda3 / miniconda3
if [[ -f "$HOME/anaconda3/bin/conda" ]]; then
  _MY_CONDA="$HOME/anaconda3"
elif [[ -f  "$HOME/miniconda3/bin/conda" ]]; then
  _MY_CONDA="$HOME/miniconda3"
fi
if [[ -n "${_MY_CONDA:-}" ]]; then
  __conda_setup="$("$_MY_CONDA/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
  if [ $? -eq 0 ]; then
    eval "$__conda_setup"
  else
    if [ -f "$_MY_CONDA/etc/profile.d/conda.sh" ]; then
      . "$_MY_CONDA/etc/profile.d/conda.sh"
    else
      export PATH="/$_MY_CONDA/bin:$PATH"
    fi
  fi
  unset __conda_setup

  # # try to activate conda environment 'default' if it exists
  # # created via: conda create -n default python=3.14
  # # for versions see: https://devguide.python.org/versions/
  # # conda doc: https://docs.conda.io/projects/conda/en/latest/user-guide/tasks/manage-environments.html#
  # conda info --envs | grep -qE '^\s*default\s' \
  #   && conda activate default >& /dev/null \
  #   && cl::p_msg "Conda environment 'default' activated." \
  #   || cl::p_dbg 0 1 "conda env 'default' not found, skipping activation"
fi

# angular CLI autocompletion, if ng is avaiable
(command -v ng 2>&1 >/dev/null) \
  && source <(ng completion script)
# }}} - DEV ------------------------------------------------------------------

# PROFILING (DEBUG)
#echo "zprof result: $(date)"
#time zprof

# }}} = FINAL LOGIN EXECUTIONS ===============================================
