#!/bin/sh
# ~/.xinitrc: executed by xinit (startx)
# usually linked by or included in .xsession

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: dotfile xorg

# include common session
. $HOME/.xsession.d/common

# include custom host session or fallback to default session if none found
[ -f "$HOME/.xsession.d/$(hostname)" ] \
  && . $HOME/.xsession.d/$(hostname) \
  || . $HOME/.xsession.d/default

