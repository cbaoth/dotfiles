# -*- mode: sh; sh-shell: zsh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=zsh:et:ts=2:sts=2:sw=2
# code: language=zsh insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zshrc: interactive zsh configuration.
#
# interactive shell: .zshenv > .zshrc
# login shell: .zshenv > .zprofile > .zshrc > .zlogin (.zlogout on exit)
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

# TODO:
# look into https://github.com/clvv/fasd

# PROFILING (DEBUG)
#zmodload zsh/zprof
#echo "zprof start: $(date)"

# {{{ = ZSH OPTIONS ==========================================================
# Set zsh options, see `man zshoptions` for details and `setopt` to list
# current options.

# INTERACTIVE_COMMENTS (-k) <K> <S>
#   Allow comments even in interactive shells.
# https://devdocs.io/zsh/options#index-file-clobbering_002c-allowing
#
# This is very useful (e.g. copy/paste script snippets with comments)
setopt interactivecomments

# {{{ - EXPANSION & GLOBBING -------------------------------------------------
# https://devdocs.io/zsh/options
# https://zsh.sourceforge.net/Doc/Release/Options.html#Expansion-and-Globbing

# EXTENDED_GLOB
#   Treat the ‘#’, ‘~’ and ‘^’ characters as part of patterns for filename
#   generation, etc. (An initial unquoted ‘~’ always produces named
#   directory expansion.)
# https://devdocs.io/zsh/options#index-BAREGLOBQUAL
# https://gist.github.com/roblogic/63f70f13665c689adca099c8d6d73641
#
# Allow the use of some regex/advanced matching features, for example:
# - `rm *-[0-9]##.png` deletes ".*\d+\.png"
# - `rm ^*.(tar|bz2|gz) /tmp/` deletes non-archive files (^ negates pattern)
# - `rm my-service.<12-234>.log` deletes log files with number in given range
#
# THIS IS MANDATORY FOR SOME OF THE FUNCTIONS/ALIASES USED/SOURCED BELOW!
setopt extendedglob

# CORRECT_ALL (-O)
#   Try to correct the spelling of all arguments in a line.
#   The shell variable CORRECT_IGNORE_FILE may be set to a pattern to match
#   file names that will never be offered as corrections.
# https://devdocs.io/zsh/options#index-CLOBBER
#
#setopt correctall

# AUTO_CD (-J)
#   If a command is issued that can't be executed as a normal command, and the
#   command is the name of a directory, perform the cd command to that
#   directory. This option is only applicable if the option SHIN_STDIN (-s) is
#   set, i.e. if commands are being read from standard input. The option is
#   designed for interactive use; it is recommended that cd be used explicitly
#   in scripts to avoid ambiguity.
# https://devdocs.io/zsh/options#index-AUTO_005fCD
#
# Examples: `~` does `cd ~` and `/var/log` does `cd /var/log`
#setopt autocd

# NULL_GLOB (-G)
#   If a pattern for filename generation has no matches, delete the pattern
#   from the argument list instead of reporting an error. Overrides NOMATCH.
# https://devdocs.io/zsh/options#index-CASE_005fMATCH

# Remove non-matching globs from command instead of failing
#setopt -o nullglob

# CSH_NULL_GLOB (-C)
#   If a pattern for filename generation has no matches, delete the pattern
#   from the argument list; do not report an error unless all the patterns in
#   a command have no matches. Overrides NOMATCH.
# https://devdocs.io/zsh/options#index-BARE_005fGLOB_005fQUAL
#
# Similar to `nullglob`, but still fail if not at least one pattern matches
#setopt -o cshnullglob

# GLOB_DOTS (-4)
#   Do not require a leading `.` in a filename to be matched explicitly.
# DOT_GLOB
#   GLOB_DOTS (bash compatibility)
#
# Include hidden (dot) files in glob selections.
# WARNING: THIS CAN BE DANGEROUS, E.G. `rm ^.*` WILL DELETE ALL FILES, and
# not only non-dot files (which is the case without this option set).
#setopt globdots
# }}} = ZSH OPTIONS ==========================================================

# {{{ = ENVIRONMENT (INTERACTIVE SHELL) ======================================
# {{{ - COMMON ENV VARIABLE --------------------------------------------------
# Common environment variables (e.g. PATH) are exported by ~/.common_env (sourced from .zshenv)
# Local overrides, if needed:

# globally raise (but never lower) the default debug level of cl::p_dbg -t
#export DEBUG_LVL=3
# }}} - COMMON ENV VARIABLE --------------------------------------------------

# {{{ - COMMON OPTIONS & COMMONS ---------------------------------------------
if [[ -f ~/lib/commons.sh ]]; then
  # shellcheck source=/dev/null
  source ~/lib/commons.sh
else
  echo "Warning: ~/lib/commons.sh not found, some potentially crucial environment settings or functionality may be missing!" >&2
fi
# }}} - COMMON OPTIONS & COMMONS ---------------------------------------------

# {{{ - COMMON RC ------------------------------------------------------------
if [[ -f ~/.common_rc ]]; then
  # shellcheck source=/dev/null
  source ~/.common_rc
else
  echo "Warning: ~/.common_rc not found, sourcing helpers unavailable!" >&2
fi
# }}} - COMMON RC ------------------------------------------------------------

# {{{ - SECURITY & PRIVACY RELATED -------------------------------------------
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
setopt EXTENDED_HISTORY # store in ":start:elapsed;command" format
# some plugins enable EXTENDED_HISTORY, enable to be indepent of plugin setup
setopt HIST_IGNORE_SPACE # don't record lines stating with a space (privacy)
#setopt HIST_REDUCE_BLANKS # remove unnecessary spaces
#setopt HIST_VERIFY # don't execute immediately after history expansion
#setopt HIST_NO_STORE # don't store history / fc commands
#setopt HIST_NO_FUNCTIONS # don't store function definitions
# }}} - SECURITY & PRIVACY RELATED -------------------------------------------

# {{{ -- SYSTEM/ENV STATE ----------------------------------------------------
if ${IS_PC:-true}; then
  if ${IS_PC_NATIVE:-true}; then
    cl::p_dbg -t 0 1 "Native PC (x68 architecture) detected."
  else
    cl::p_msg "Non-native PC (x68 architecture) detected."
  fi
else
  cl::p_msg "Non-PC architecture detected ($ARCH != x68)."
  if ${IS_ANDROID:-false}; then
    if ${IS_TERMUX:-false}; then
      cl::p_msg "Android (TERMUX) envrionment detected."
    else
      cl::p_msg "Android envrionment detected."
    fi
  fi
fi

if ${IS_WSL:-false}; then
  if ! ${IS_WSL2:-false}; then
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

if ${IS_DOCKER:-false}; then
  cl::p_msg "Docker environment detected."
fi
# }}} - SYSTEM/ENV STATE -----------------------------------------------------
# {{{ - MISC -----------------------------------------------------------------
#UAGENT="Mozilla/5.0 (X11; U; FreeBSD i386; en-US; rv:1.4b) Gecko/20030517"
#UAGENT+=" Mozilla Firebird/0.6"
UAGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko)"
UAGENT+=" Chrome/79.0.3945.88 Safari/537.36"
export UAGENT
# }}} - MISC -----------------------------------------------------------------
# }}} = ENVIRONMENT (INTERACTIVE SHELL) ======================================

# {{{ = CORE FUNCTIONS, SOURCING, ALIASES ====================================
# source_ifex and source_ifex_custom are defined in ~/.common_rc (sourced above)

# auto-rehash hook — must be sourced before alias files so they can register entries
source_ifex $HOME/.zsh.d/auto-rehash.zsh

# include common and zsh specific aliases
source_ifex $HOME/.aliases
source_ifex $HOME/.zsh.d/aliases.zsh

# shell-agnostic functions (bash + zsh)
source_ifex $HOME/lib/functions.sh

# hash some common directories for easy access existing (if they exist)
# TODO consider moving this to commons.sh and use in host specific files as well
__hash_mountpoints() {
  # define directories to hash
  # suffixes "_*" are ignored for hash names. they can be used define more than one path per hash (first one found is used)
  local -Ar _hashdirs=(
    # common mount points
    [b]="/backup"  # more than one may exist, but first one found is used, add seperately if needed
    [b_mnt]="/mnt/backup"
    [b_media]="/media/backup"

    # saito server: local mount points
    [l_SAITO]="/media/data"
    [d_SAITO]="/media/data" # L: on windows systems
    [s_SAITO]="/media/stash"

    # saito clients: common client side mount points for saito network shares
    [d]="/srv/saito/data"
    [l]="/srv/saito/data"  # L: on windows systems
    [s]="/srv/saito/stash"
    [l_GVFS]="/run/user/1000/gvfs/smb-share:server=saito,share=data"
    [s_GVFS]="/run/user/1000/gvfs/smb-share:server=saito,share=stash"

    # hosts with windows partitions (dual boot or wsl), c-f should be sufficient for the most common setups
    [c]="/mnt/c"
    [d]="/mnt/d"
    [e]="/mnt/e"
    [f]="/mnt/f"

    # motoko: specific mount points on motoko (windows dual boot)
    [c_GVFS]="/media/$USERNAME/Windows"
    [d_GVFS]="/media/$USERNAME/Games"
    [e_GVFS]="/media/$USERNAME/Data"
    [f_GVFS]="/media/$USERNAME/Temp"
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
    cl::p_dbg -t 0 1 "hash -d ${key}=${dir}"
    # https://zsh.sourceforge.io/Doc/Release/Shell-Builtin-Commands.html
    ## run as background job to speed up shell startup e.g. in case a mount point is not (immediately) available
    ## disable notify and monitor temporarily to avoid messages when spawning background jobs (`hash ... &`)
    ##setopt local_options no_notify no_monitor
    hash -d "${key}=${dir}"
  done
}
__hash_mountpoints
unfunction __hash_mountpoints  # cleanup, not needed anymore

is_me() { [[ $USER:l =~ ^(cbaoth|(a\.)?weyer)$ ]]; }
# }}} = CORE FUNCTIONS, SOURCING, ALIASES ====================================

# {{{ = ZINIT PREPARE ========================================================
# Plugin manager: zinit (https://github.com/zdharma-continuum/zinit).
# zinit self-installs on first run and self-manages; there is deliberately no
# install/update logic on shell startup (updates are explicit, see `zplugup`).

# disable oh-my-zsh auto update (OMZ plugins are loaded as zinit OMZP:: snippets)
export DISABLE_AUTO_UPDATE=true

# custom plugin modes (full: load all, mini: load less, skip: load none)
_PLUGIN_MODE_DEFAULT="full"
# optionally deviate per environment
_PLUGIN_MODE_WSL="full"       # load all plugins in WSL
_PLUGIN_MODE_DOCKER="mini"    # load fewer plugins inside Docker containers
_PLUGIN_MODE_ANDROID="skip"   # skip plugins on Android (too slow / unstable)

PLUGIN_MODE=$_PLUGIN_MODE_DEFAULT
${IS_ANDROID:-false} && PLUGIN_MODE=${_PLUGIN_MODE_ANDROID:-$_PLUGIN_MODE_DEFAULT}
${IS_WSL:-false}     && PLUGIN_MODE=${_PLUGIN_MODE_WSL:-$_PLUGIN_MODE_DEFAULT}
${IS_DOCKER:-false}  && PLUGIN_MODE=${_PLUGIN_MODE_DOCKER:-$_PLUGIN_MODE_DEFAULT}
[[ $PLUGIN_MODE != $_PLUGIN_MODE_DEFAULT ]] \
  && cl::p_dbg -t 0 1 "Using non-default plugin mode '$PLUGIN_MODE' (default: $_PLUGIN_MODE_DEFAULT)."

MODE_IS_SKIP=$([[ $PLUGIN_MODE = 'skip' ]] && print true || print false)
MODE_IS_MINI=$([[ $PLUGIN_MODE = 'mini' ]] && print true || print false)
MODE_IS_FULL=$([[ $PLUGIN_MODE = 'full' ]] && print true || print false)

# Turbo (async) loading: the prompt appears instantly and plugins finish loading
# in the background — a big win on slow machines. An explicit ZINIT_TURBO in the
# environment always wins; otherwise default to turbo only for interactive shells.
# Set ZINIT_TURBO=false to force synchronous loading, e.g. `ZINIT_TURBO=false
# zsh -ic true` during a Docker build installs every plugin at build time
# (replaces the old .zplug-force-install dummy file).
if [[ -z "${ZINIT_TURBO:-}" ]]; then
  if [[ -o interactive ]]; then
    ZINIT_TURBO=true
  else
    ZINIT_TURBO=false
  fi
fi

IS_ZINIT=false
if ! $MODE_IS_SKIP; then
  declare ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
  if [[ ! -f "$ZINIT_HOME/zinit.zsh" ]]; then
    cl::p_msg "Installing zinit (one-time) ..."
    command mkdir -p "$(dirname "$ZINIT_HOME")"
    command git clone --depth=1 https://github.com/zdharma-continuum/zinit "$ZINIT_HOME" \
      && cl::p_msg "zinit installed."
  fi
  if [[ -f "$ZINIT_HOME/zinit.zsh" ]]; then
    source "$ZINIT_HOME/zinit.zsh"
    IS_ZINIT=true
  else
    cl::p_err "zinit not found and install failed, plugins unavailable!"
  fi
else
  cl::p_dbg -t 0 1 "zinit init skipped as per \$PLUGIN_MODE=$PLUGIN_MODE."
fi

# Apply the turbo ice (wait lucid) to the next plugin, but only when turbo is
# enabled. Extra ice modifiers may be passed through in either case.
#   zt [extra-ice ...]; zinit light|snippet <target>
zt() {
  if $ZINIT_TURBO; then
    zinit ice wait lucid "$@"
  elif (( $# > 0 )); then
    zinit ice "$@"
  fi
}
# }}} = ZINIT PREPARE ========================================================

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

export ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump"

# register custom completions before compinit
fpath=("$HOME/.zsh.d/completions" "${fpath[@]}")
[[ -d "$HOME/git/cb-voice-toolkit" ]] && fpath=("$HOME/git/cb-voice-toolkit/completions" "${fpath[@]}")

# enable new style completion system
autoload -Uz compinit && compinit
# check cache only once per day (can be slow when done more frequently)
# https://gist.github.com/ctechols/ca1035271ad134841284
#if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
#  compinit
#  #touch .zcompdump
#else
#  compinit -C
#fi

# enable zargs built-in
autoload -Uz zargs
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
if $IS_ZINIT; then
  # the prompt must load immediately (never turbo), else it isn't the prompt
  zinit ice depth=1
  zinit light romkatv/powerlevel10k
  POWERLEVEL9K_ISACTIVE=true
  POWERLEVEL10K_ISACTIVE=true
fi

# {{{ - - General ------------------------------------------------------------
# TODO review after switching to powerlevel10k. are all these variables  still used? consider migrating to powerlevel10k variables instead (where applicable).
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
$MODE_IS_FULL && POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS+=(battery)
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

# {{{ = ZINIT PLUGINS ========================================================
# TODO consider https://github.com/zsh-users/zsh-completions
#
# Loading strategy:
# - powerlevel10k (above) and the widget plugins below (autosuggestions, zaw)
#   load immediately, so their keybindings further down are always available.
# - everything else is turbo-loaded (async) via `zt` when $ZINIT_TURBO is set.
# - fast-syntax-highlighting is declared last so it highlights everything.
if $IS_ZINIT; then

# https://github.com/zsh-users/zsh-autosuggestions
# loaded immediately so its `^ ` accept binding (keybindings section) works
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=25
zinit light zsh-users/zsh-autosuggestions

# https://github.com/zsh-users/zaw
# loaded immediately so its zle widgets are bound in the keybindings section
zinit light zsh-users/zaw

# {{{ - OH MY ZSH ------------------------------------------------------------
# oh-my-zsh plugins as individual zinit snippets (no full OMZ framework).
# https://github.com/ohmyzsh/ohmyzsh/wiki/Plugins
zt; zinit snippet OMZP::catimg
#OMZP::common-aliases
zt; zinit snippet OMZP::command-not-found
#OMZP::debian
zt; zinit snippet OMZP::dirhistory
zt; zinit snippet OMZP::docker         # docker completion
zt; zinit snippet OMZP::encode64       # encode64/decode64
# https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git
if $MODE_IS_FULL; then
  zt; zinit snippet OMZP::git
  zt; zinit snippet OMZP::git-extras   # completion for apt:git-extras
fi
# httpie: OMZ ships only a completion file (_httpie), no *.plugin.zsh
zt as"completion"; zinit snippet OMZP::httpie/_httpie   # completion for https://httpie.io/ (apt/snap: httpie)
zt; zinit snippet OMZP::jsontools      # *_json
zt; zinit snippet OMZP::mvn            # maven completion
zt; zinit snippet OMZP::sudo           # add sudo via 2xESC
zt; zinit snippet OMZP::systemd        # systemd sc-* aliases
#zt; zinit snippet OMZP::tmux           # FIXME bugged, error when starting zsh in tmux: /home/cbaoth/.local/share/zinit/snippets/OMZP::tmux/tmux.extra.conf: No such file or directory
zt; zinit snippet OMZP::urltools       # urlencode/-decode
zt; zinit snippet OMZP::vagrant
zt; zinit snippet OMZP::vscode         # vs* aliases
zt; zinit snippet OMZP::web-search
# wd (warp directory): loaded from upstream, not OMZP::wd — the OMZ plugin is
# multi-file (wd.plugin.zsh sources wd.sh) and a single-file snippet breaks it.
zt; zinit light mfaerevaag/wd
#zt; zinit snippet OMZP::history-substring-search

# ssh-agent: https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/ssh-agent
# do not load if
# 1. we are in an ssh session, use `ssh -A` agent forwarding if needed
# 2. we are in wsl/termux, use other means if needed
# 3. SSH_AUTH_SOCK is already set (e.g. KeePassXC, Gnome Keyring, Pageant etc.)
#    Note that SSH_AUTH_SOCK may also be set in .common_env
# zstyles must be set before the snippet loads (see keybindings/completion below)
if $MODE_IS_FULL && ! cl::is_ssh && [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
  zstyle :omz:plugins:ssh-agent agent-forwarding on
  #zstyle :omz:plugins:ssh-agent identities id_rsa ...
  #zstyle :omz:plugins:ssh-agent lifetime 4h
  zt; zinit snippet OMZP::ssh-agent    # auto run ssh-agent
fi

if ${HAS_CONDA:-false}; then
  zt; zinit light esc/conda-zsh-completion
fi

# TODO review and consider potential key binding conflicts
# https://github.com/junegunn/fzf/blob/master/shell/key-bindings.zsh
#
# if command -v fzf >/dev/null 2>&1; then
#   zt; zinit snippet https://github.com/junegunn/fzf/blob/master/shell/key-bindings.zsh
# fi
# }}} - OH MY ZSH ------------------------------------------------------------

# {{{ - OTHER PLUGINS --------------------------------------------------------
# Reminds you of aliases you defined but forgot: https://github.com/djui/alias-tips
zt; zinit light djui/alias-tips

# Inline expansion of aliases/globs/history on space/enter:
# https://github.com/MenkeTechnologies/zsh-expand
# NOTE: takes over the SPACE key widget — it replaces the old `magic-space` bind
# (removed in the keybindings section). Disable by commenting this out.
zt nocompile; zinit load MenkeTechnologies/zsh-expand
# }}} - OTHER PLUGINS --------------------------------------------------------

# syntax highlighting: declared LAST so it highlights everything loaded before.
# https://github.com/zdharma-continuum/fast-syntax-highlighting
# (lighter alternative to zsh-users/zsh-syntax-highlighting)
#
# atinit runs once all earlier plugins are loaded (this is the last one), in both
# turbo and sync modes: rebuild the completion cache so plugin-provided
# completions (e.g. wd, http/https) register, then replay captured compdefs.
zt atinit'zicompinit; zicdreplay'
zinit light zdharma-continuum/fast-syntax-highlighting

fi  # $IS_ZINIT
# }}} = ZINIT PLUGINS ========================================================

# {{{ = PLUGIN SETTINGS ======================================================
# tmux (OMZP::tmux)
#ZSH_TMUX_AUTOSTART # default: false, auto start tmux on login
#ZSH_TMUX_AUTOSTART_ONCE # default: true, start for ever (nested) zsh session
#ZSH_TMUX_AUTOCONNECT # default: true, try connect to existing else new
#ZSH_TMUX_AUTOQUIT # default: ZSH_TMUX_AUTOSTART, close session if tmux exits
#ZSH_TMUX_FIXTERM # default: true, set TERM=screen(256color)
# }}} = PLUGIN SETTINGS ======================================================

# {{{ ZSH SETTINGS ===========================================================
# load zmv extension (http://zshwiki.org/home/builtin/functions/zmv)
autoload zmv
#zmodload zsh/mathfunc

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
# _expand: use only with tab -> complete-word, not with expand-or-complete (default)
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

# change completion description and warning text
zstyle ':completion:*' verbose yes
zstyle ':completion:*:descriptions' format '%U%B%d%b%u'
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*:warnings' format '%Bno matches for: %d%b'
zstyle ':completion:*:corrections' format '%B%d (errors: %e)%b'
zstyle ':completion:*' group-name ''

# complete only specific hosts (big host file)
#zstyle '*' hosts $HOST motoko.intra puppet.intra bateau.intra togusa.intra 11001001.org

# ssh-agent (OMZP::ssh-agent): its zstyles (agent-forwarding, identities,
# lifetime) must be set BEFORE the snippet loads — they now live in the ZINIT
# PLUGINS section, next to the `zinit snippet OMZP::ssh-agent` line.

# TODO compctl is a legacy feature which may be brittle with OMZ, review and useg compdef instead if needed
# file type command detecton
#compctl -g '*.ebuild' ebuild
#compctl -g '*.tex' + -g '*(-/)' latex
#compctl -g '*.dvi' + -g '*(-/)' dvipdf dvipdfm
#compctl -g '*.java' + -g '*(-/)' javac
#compctl -g '*.tar.bz2 *.tar.gz *.bz2 *.gz *.jar *.rar *.tar *.tbz2 *.tgz *.zip *.Z' \
#        + -g '*(-/)' extract
#compctl -g '*.mp3 *.ogg *.opus *.mod *.wav *.avi *.mpg *.mpeg *.wmv *.mkv *.webm *.mp4' \
#        + -g '*(-/)' mpv
#compctl -g '*.py' python
#compctl -g '*(-/D)' cd
#compctl -g '*(-/)' mkdir

## user name auto completion
#function _userlist {
#  [[ -r /etc/passwd ]] && reply=($(cat /etc/passwd | cut -d : -f 1))
#}
#compctl -K _userlist ps -fU
#compctl -K _userlist finger

# if set, aliases are treated as their own completion context, default: expand aliases before completion
# with this option: `alias ll=ls -all` -> `ll -<TAB>` completes `ll` options (if any, none per default)
# default behavior: `alias ll=ls -all` -> `ll -<TAB>` completes `ls -all` options)
# there should usually not be a need to set this. if aliases don't behave as expected, consider using a function with specific compcfg instead, e.g.
#   mpv() { flatpak run io.mpv.Mpv "$@" }
#   vlc() { flatpak org.videolan.VLC "$@" }
#   compdef _files mpv vlc
#setopt completealiases
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
# NOTE: the SPACE key is owned by zsh-expand (ZINIT PLUGINS section), which
# supersedes the old `bindkey ' ' magic-space` (!-history expansion on space).
# Re-enable magic-space here only if you disable the zsh-expand plugin.
#bindkey ' ' magic-space
#bindkey '^ ' globalias

#if $IS_ZINIT; then  # (enable OMZP::history-substring-search above first)
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
# register the edit-command-line widget before binding it, otherwise
# fast-syntax-highlighting warns "unhandled ZLE widget 'edit-command-line'"
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd '^v' edit-command-line

# search histor using / and ?
#bindkey -M vicmd '?' history-incremental-search-backward
#bindkey -M vicmd '/' history-incremental-search-forward
# }}} - VI MODE --------------------------------------------------------------
# {{{ - ZAW ------------------------------------------------------------------
# https://github.com/zsh-users/zaw (loaded immediately, so its widgets exist here)
if $IS_ZINIT; then
  bindkey '^[r' zaw # alt-r
  bindkey '^r' zaw-history # ctrl-r

  # git bindings
  bindkey '^[v^[l' zaw-git-log # alt-v, alt-l
  bindkey '^[v^[r' zaw-git-reflog # alt-v, alt-r
  bindkey '^[v^[s' zaw-git-status # alt-v, alt-s

  # filterlist bindings
  if $IS_ZINIT; then
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

# {{{ = SOURCE CUSTOM ALIASES AND FUNCTIONS ==================================
fpath=("$HOME/.zsh.d/functions" "${fpath[@]}")

# shell-agnostic os/host alias files (bash + zsh)
source_ifex_custom $HOME/lib/aliases
# zsh-specific os/host alias and rc files
source_ifex_custom -e .zsh $HOME/.zsh.d/aliases
source_ifex_custom -e .zsh $HOME/.zsh.d/zshrc
# }}} = SOURCE CUSTOM ALIASES AND FUNCTIONS ==================================

# {{{ = FINAL EXECUTIONS =====================================================
# {{{ - X WINDOWS ------------------------------------------------------------
# Ensure that Gnome Key Ring allows access to SSH keys
# Disabled e.g. in favor of KeePassXC (Secret Service Integration)
#
# are we in a x-windows session?
# if [[ -n "${DESKTOP_SESSION-}" ]]; then
#     # is gnome-keyring-daemon availlable? use it as ssh agent
#     if command -v gnome-keyring-daemon 2>&1 > /dev/null; then
#         # start unless already running
#         if [[ -n "${GNOME_KEYRING_PID-}" ]]; then
#             export "$(gnome-keyring-daemon --start --components=ssh)" #--components=pkcs11,secret,ssh)
#             # SSH_AGENT_PID required to stop xinitrc-common from starting ssh-agent
#             export SSH_AGENT_PID=${GNOME_KEYRING_PID:-gnome}
#         fi
#     fi
# fit
# }}} - X WINDOWS ------------------------------------------------------------
# {{{ - DTAG -----------------------------------------------------------------
# enabale dtag (when available)
#(command -v dtags-activate >& /dev/null \
#  && eval "$(dtags-activate zsh)" \
#  || cl::p_war "unable to activate dtags, dtags-activate not found" \
#) &!
# }}} - DTAG -----------------------------------------------------------------
# {{{ - FINAL PATH UPDATE ----------------------------------------------------
# let's ensure that ~/bin and ~/.local/bin are always on top of the PATH
# e.g. to ensure that local tool installations take precedence
PATH="\
${HOME}/bin:\
${HOME}/.local/bin:\
${PATH}"

# Sanitize PATH: remove empty entries (e.g. double colons) and duplicates (first occurrence wins)
PATH="$(printf '%s\n' "${PATH}" | tr ':' '\n' | awk 'NF && !seen[$0]++' | paste -sd ':')"
export PATH

LD_LIBRARY_PATH="$(printf '%s\n' "${LD_LIBRARY_PATH}" | tr ':' '\n' | awk 'NF && !seen[$0]++' | paste -sd ':')"
export LD_LIBRARY_PATH
# }}} - FINAL PATH UPDATE ----------------------------------------------------

# {{{ - MOTD -----------------------------------------------------------------
# Print MOTD messages only for top-level shells (no sub-shells, su, tmux, etc.)
if (( SHLVL == 1 )); then
  # Print welcome message for login shells (includes ssh sessions) or docker containers
  if [[ -o login ]] || [[ -n "${IS_DOCKER:-}" ]]; then
    printf "%s\n" "$(cl::fx b)$(cl::fx white)Welcome to $(cl::fx green)$(hostname) $(cl::fx white)running $(cl::fx green)$(uname -srm)$(cl::fx reset)"
  fi
  printf "%s\n" "$(cl::fx b)$(cl::fx white)Time: $(cl::fx green)$(date '+%a %Y-%m-%d %T')$(cl::fx white), Uptime: $(cl::fx green)$(uptime -p)$(cl::fx white) since $(cl::fx green)$(uptime -s)$(cl::fx white)$(cl::fx reset)"
fi
# }}} - MOTD -----------------------------------------------------------------

# PROFILING (DEBUG)
#echo "zprof result: $(date)"
#time zprof
# }}} = FINAL EXECUTIONS =====================================================
