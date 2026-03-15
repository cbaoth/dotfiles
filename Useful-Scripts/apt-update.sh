#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash
#
# Update apt package indexes quietly and store the last update timestamp.

apt-get -q -y update >/dev/null && date +%s > /tmp/last_apt_update
