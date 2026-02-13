#!/bin/sh
# ~/.xsession: executed by display manager ("custom" mode)
# code: language=bash insertSpaces=true tabSize=2
# keywords: bash zsh dotfile xsession x11 shell shell-script
# author: Andreas Weyer

# /usr/share/xsessions/custom.desktop:
#[Desktop Entry]
#Name=Xsession
#Exec=/etc/X11/Xsession

# include profile (most likely missing when using display manager)
source ~/.profile

# include .xinitrc (includes custom .xsession.d and starts wm)
source ~/.xinitrc
