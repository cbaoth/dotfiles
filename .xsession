#!/usr/bin/env sh
# -*- mode: sh; sh-shell: sh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=sh:et:ts=2:sts=2:sw=2
# code: language=sh insertSpaces=true tabSize=2
# shellcheck shell=sh
#
# ~/.xsession: display-manager session entrypoint.

# /usr/share/xsessions/custom.desktop:
#[Desktop Entry]
#Name=Xsession
#Exec=/etc/X11/Xsession

# include profile (most likely missing when using display manager)
source ~/.profile

# include .xinitrc (includes custom .xsession.d and starts wm)
source ~/.xinitrc
