# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.bash_profile: login-shell profile for the de4012101 override.
#
# interactive non-login shell: .bashrc
# login shell: .bash_profile (or .bash_login or .profile, first found) > .bash_logout

# Source bashrc if it exists (for interactive non-login shell settings)
if [[ -f ~/.bashrc ]]; then
  # shellcheck source=/dev/null
  source ~/.bashrc
else
  echo "Warning: ~/.bashrc not found, some potentially crucial environment settings or functionality may be missing!" >&2
fi

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
export HISTFILE="$HOME/.bash_history" # don't create shell history file
export HISTFILESIZE=10000 # set shell history file limit to zero
export HISTSIZE=10000 # set (in memory) history limit
# }}} - SECURITY & PRIVACY ---------------------------------------------------

# {{{ - BASH -----------------------------------------------------------------
# if running bash
if [[ -n "${BASH_VERSION-}" ]]; then
  # include .bashrc if it exists
  if [[ -f "$HOME/.bashrc" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.bashrc"
  fi
fi
# }}} - BASH -----------------------------------------------------------------
