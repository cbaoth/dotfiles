#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash
#
# .conky/hddtemp.sh: Conky script to get hddtemp output.

sudo hddtemp "$@" 2>/dev/null || echo -1
