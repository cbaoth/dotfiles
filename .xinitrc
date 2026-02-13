#!/bin/sh
# ~/.xinitrc: executed by xinit (startx)
# code: language=bash insertSpaces=true tabSize=2
# keywords: bash zsh dotfile xinit xinitrc x11 shell shell-script
# author: Andreas Weyer
#
# Usually linked by or included in .xsession

# include common session
. $HOME/.xsession.d/common

# include custom host session or fallback to default session if none found
[[ -f "$HOME/.xsession.d/$(hostname)" ]] \
  && . $HOME/.xsession.d/$(hostname) \
  || . $HOME/.xsession.d/default
