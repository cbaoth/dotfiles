# ~/.bashrc: Bash startup file

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: bashrc shell-script

# To view this file correctly use fold-mode for emacs and add the following
# line to your .emacs:
#   (folding-add-to-marks-list 'shell-script-mode "# {{{ " "# }}}" nil t)

# {{{ = ENVIRONMENT (INTERACTIVE SHELL) ======================================
# For login shell / general variable like PATH see ~/.zshenv

# {{{ - PATH -----------------------------------------------------------------
PATH="$HOME/bin:/opt/bin:/sbin:/usr/sbin:/usr/local/sbin:/bin:/usr/bin"
PATH+=":/usr/local/bin:/usr/bin/X11:/usr/X11R6/bin:/usr/games:$PATH"
export PATH
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/lib"
# }}} - PATH -----------------------------------------------------------------

# {{{ - LOCALE ---------------------------------------------------------------
#export LANG=C
export LANG="en_US.UTF-8"
export LC_ALL="en_US.utf8"
export LC="en_US.utf8"
export LESSCHARSET="utf-8"
#export BREAK_CHARS="\"#'(),;\`\\|\!?[]{}"
# }}} - LOCALE ---------------------------------------------------------------

# {{{ - SECURITY -------------------------------------------------------------
export HISTFILE="" # don't create shell history file
export HISTFILESIZE=0 # set shell history to zero
# }}} - SECURITY -------------------------------------------------------------

# {{{ - CORE -----------------------------------------------------------------
export OS=$(uname | tr '[A-Z]' '[a-z]')
[[ -z "${HOST-}" ]] && export HOST=$HOSTNAME

export TERM="xterm-256color" # rxvt, xterm-color, xterm-256color
export COLORTERM=xterm
#[[ -n "$(echo $TERMCAP|grep -i screen)" ]] && TERM=screen

# globally raise (but never lower) the default debug level of p_dbg
export DBG_LVL=0
# }}} - CORE -----------------------------------------------------------------
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

# {{{ - MISC -----------------------------------------------------------------
#UAGENT="Mozilla/5.0 (X11; U; FreeBSD i386; en-US; rv:1.4b) Gecko/20030517"
#UAGENT+=" Mozilla Firebird/0.6"
UAGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko)"
UAGENT+=" Chrome/59.0.3071.104 Safari/537.36"
export UAGENT
# }}} - MISC -----------------------------------------------------------------
# }}} = ENVIRONMENT (INTERACTIVE SHELL) ======================================

# {{{ = PROMPT ===============================================================
export LANG=C
export PS1="\[\e[0;37m\](\w)\[\\033[0;39m\]
[\[\\033[0;34m\]\u\[\\033[0;39m\]@\[\\033[4;38m\]\h\[\\033[0;39m\]]\$ "
# }}} = PROMPT ===============================================================

# {{{ = INCLUDES =============================================================
include_ifex () {
  while [[ -n "$1" ]]; do
    [[ -f "$1" ]] && source "$1"
    shift
  done
}
# FIXME currently not fully bash compatible
#include_ifex $HOME/.zsh.d/functions.zsh
include_ifex $HOME/.zsh.d/aliases.zsh

# load aliases
#include_ifex \
#  $HOME/.zsh.d/aliases.zsh \
#  $HOME/.zsh.d/aliases.$OS.zsh \
#  $HOME/.zsh.d/aliases.$HOST.zsh \
#  $HOME/.zsh.d/aliases.$HOST.$OS.zsh \
#  $HOME/.bash/aliases-bash.sh
#  $(cat .aliases | grep -Ev '^\s*#' | sed 's/^alias/alias -g/')

# load functions
#include_ifex \
#  $HOME/.zsh.d/functions.zsh \
#  $HOME/.zsh.d/functions.$OS.zsh \
#  $HOME/.zsh.d/functions.$HOST.zsh \
#  $HOME/.zsh.d/functions.$HOST.$OS.zsh

# load system/host specific config file (eg: ~/.bashrc.freebsd)
#include_ifex \
#  $HOME/.bash.d/bashrc.$OS.sh \
#  $HOME/.bash.d/bashrc.$HOST.sh \
#  $HOME/.bash.d/bashrc.$HOST.$OS.sh
# }}} = INCLUDES =============================================================

# {{{ = FINAL EXECUTIONS =====================================================
# {{{ - X STUFF --------------------------------------------------------------
# this should normally not be here, but ... this way its always executed when
# opening a term

# no perfect check since we could e.g. be in an ssh session without
# working / running x, so we start everything in the background
# stupid messages but better timeouts in bg thatn in fg (delay at login)

# TODO: FIND A BETTER SOLUTION< MOVE TO INPUTRC / XINITRC
if [[ -n "${DISPLAY-}" ]]; then
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
# {{{ - MOTD -----------------------------------------------------------------
# print welcome message (if top-level shell)
if (($SHLVL == 1)); then
   print -P "%B%F{white}Welcome to %F{green}%m %F{white}running %F{green}$(uname -srm)%F{white}"
   # on %F{green}#%l%f%b"
   print -P "%B%F{white}Uptime:%b%F{green}$(uptime)\e%f"
fi
# }}} - MOTD -----------------------------------------------------------------
# }}} = FINAL EXECUTIONS =====================================================
