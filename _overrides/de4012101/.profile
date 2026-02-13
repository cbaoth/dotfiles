# ~/.profile: executed by the command interpreter for login shells.
# code: language=bash insertSpaces=true tabSize=2
# keywords: bash dotfile bashrc bash_profile shell shell-script
# author: Andreas Weyer
#
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists. This file is read in case some WMs are started.

# {{{ - PATH -----------------------------------------------------------------
PATH="$HOME/bin:/opt/bin:/opt/oracle/instantclient_21_4"
PATH+=":/sbin:/usr/sbin:/usr/local/sbin:/bin:/usr/bin"
PATH+=":/usr/local/bin:/usr/bin/X11:/usr/X11R6/bin:/usr/games:$PATH"
export PATH
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/oracle/instantclient_21_4:usr/local/lib"
# }}} - PATH -----------------------------------------------------------------

# {{{ - LOCALE ---------------------------------------------------------------
#export LANG=C
export LANG="en_US.UTF-8"
export LC_ALL="en_US.utf8"
export LC="en_US.utf8"
export LESSCHARSET="utf-8"
#export BREAK_CHARS="\"#'(),;\`\\|\!?[]{}"
# }}} - LOCALE ---------------------------------------------------------------

# {{{ - SECURITY & PRIVACY ---------------------------------------------------
# private session
#export HISTFILE="" # don't create shell history file
#export HISTFILESIZE=0 # set shell history file limit to zero
#export HISTSIZE=10000 # set (in memory) history limit
# persisted session
export HISTFILE="~/.bash_history" # don't create shell history file
export HISTFILESIZE=10000 # set shell history file limit to zero
export HISTSIZE=10000 # set (in memory) history limit
# }}} - SECURITY & PRIVACY ---------------------------------------------------

# {{{ - BASH -----------------------------------------------------------------
# if running bash
if [[ -n "${BASH_VERSION-}" ]]; then
    # include .bashrc if it exists
    if [[ -f "$HOME/.bashrc" ]]; then
	. "$HOME/.bashrc"
    fi
fi
# }}} - BASH -----------------------------------------------------------------
