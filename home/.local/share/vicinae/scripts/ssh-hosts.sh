#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash
#
# Vicinae script command: open the sway-ssh host picker from the launcher.
#
# @vicinae.schemaVersion 1
# @vicinae.title SSH
# @vicinae.description Connect to a host from ~/.ssh/config (bin/sway-ssh)
# @vicinae.mode silent
# @vicinae.icon 🖧
# @vicinae.keywords ["ssh", "remote", "connect", "host"]

# Detached: the picker is itself a vicinae dmenu view, which can only open
# once this command has returned and the launcher window has closed.
setsid -f sway-ssh pick >/dev/null 2>&1
