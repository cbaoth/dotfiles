# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists. This file is read in case some WMs are stated.

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: profile bash shell-script

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

# {{{ - BASH -----------------------------------------------------------------
# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi
# }}} - BASH -----------------------------------------------------------------

# {{{ - X WINDOWS ------------------------------------------------------------
# if [ -n "$DESKTOP_SESSION" ]; then
#   # load default keyboard layout
#   setxkbmap us -variant colemak
#   # repeat caps lock (colemak backspace)
#   xset r 66 2>/dev/null &!
#   # don't repeat tilde
#   xset -r 49 2>/dev/null &!
#   # ubuntu hack: disable stupid ubuntu shift+backspace -> x terminate
#   xmodmap -e 'keycode 0x16 = BackSpace BackSpace BackSpace BackSpace' 2>/dev/null &!
#   # and add terminate via print button (seldom used) + shift + mod
#   xmodmap -e 'keycode 0x6B = Print Sys_Req Print Terminate_Server Print Sys_Req' 2>/dev/null &!

#   if command -v gnome-keyring-daemon 2>&1 > /dev/null; then
#     export $(gnome-keyring-daemon --start)
#     # SSH_AGENT_PID required to stop xinitrc-common from starting ssh-agent
#     export SSH_AGENT_PID=${GNOME_KEYRING_PID:-gnome}
#   fi
# fi
# }}} - X WINDOWS ------------------------------------------------------------
