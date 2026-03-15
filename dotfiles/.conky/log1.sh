#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash

printf "%s\n---\n%s\n---\n%s" \
    "$(egrep -v '^Personal' /proc/mdstat)" \
    "$(journalctl -l -n 50 -o short --no-pager | fold -w140 | tail -n 50)" \
    "$(tail -n 10 ~/i3.log | fold -w140 | tail -n 10)" \
    | sed -r 's/\$/$$/g;
              s/(error|exception|fail(ed)?|refused)/${color #ff6666}\0${color}/gi;
              s/(warn(ing)?)/${color #ff9933}\0${color}/gi;
              s/(\[[^]]*\]\s*\w+\s*=\s*[0-9,.]*\s*%)(.*)(finish\s*=.*)/${color #ff6666}\1${color}\2${color #ff9933}\3${color}/gi;
              s/\[[0-9]+\/[0-9]+\]\s*\[[_U]*_[_U]*\]/${color #ff6666}\0${color}/gi'
