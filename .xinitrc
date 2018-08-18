#!/bin/sh
# ~/.xinitrc: executed by xinit (startx)
# usually linked by or included in .xsession

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: dotfile xorg

# include common session
. ~/.xsession.d/common

# include custom host session or fallback to default session if none found
[ -f "~/.xsession.d/$(hostname)" ] \
  && . ~/.xsession.d/$(hostname) \
  || . ~/.xsession.d/default

