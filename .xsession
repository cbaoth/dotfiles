#!/bin/sh
# ~/.xsession: executed by display manager ("custom" mode)

# Author:   cbaoth <dev@cbaoth.de>
# Keywords: dotfile xorg

# /usr/share/xsessions/custom.desktop:
#[Desktop Entry]
#Name=Xsession
#Exec=/etc/X11/Xsession

# include profile (most likely missing when using display manager)
. ~/.profile

# include .xinitrc (includes custom .xsession.d and starts wm)
. ~/.xinitrc

