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

# globally raise (but never lower) the default debug level of cl::p_dbg
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
source $HOME/.aliases
# }}} = INCLUDES =============================================================

# {{{ = FINAL EXECUTIONS =====================================================
# {{{ - X WINDOWS ------------------------------------------------------------
# are we in a x-windows session?
if [[ -n "${DESKTOP_SESSION-}" ]]; then
  # is gnome-keyring-daemon availlable? use it as ssh agent
  if command -v gnome-keyring-daemon 2>&1 > /dev/null; then
    export $(gnome-keyring-daemon --start)
    # SSH_AGENT_PID required to stop xinitrc-common from starting ssh-agent
    export SSH_AGENT_PID=${GNOME_KEYRING_PID:-gnome}
  fi
fi
# }}} - X WINDOWS ------------------------------------------------------------
# {{{ - MOTD -----------------------------------------------------------------
# print welcome message (if top-level shell)
if (($SHLVL == 1)); then
   print -P "%B%F{white}Welcome to %F{green}%m %F{white}running %F{green}$(uname -srm)%F{white}"
   # on %F{green}#%l%f%b"
   print -P "%B%F{white}Uptime:%b%F{green}$(uptime)\e%f"
fi
# }}} - MOTD -----------------------------------------------------------------
# }}} = FINAL EXECUTIONS =====================================================
