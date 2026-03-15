#!/usr/bin/env sh
# -*- mode: sh; sh-shell: sh; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=sh:et:ts=2:sts=2:sw=2
# code: language=sh insertSpaces=true tabSize=2
# shellcheck shell=sh
#
# ~/.xinitrc: X session startup for xinit/startx.
#
# Usually linked by or included in .xsession

# include common session
. $HOME/.xsession.d/common

# include custom host session or fallback to default session if none found
[[ -f "$HOME/.xsession.d/$(hostname)" ]] \
  && . $HOME/.xsession.d/$(hostname) \
  || . $HOME/.xsession.d/default
