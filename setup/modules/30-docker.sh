# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 30-docker: Docker engine + buildx, and group membership for the current user.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Docker engine, buildx, and docker group membership"
MODULE_PROFILES=(desktop server)
MODULE_DOC="docs/setup/docker.md"

module_run() {
  st::apt_install docker.io docker-buildx

  # Membership in 'docker' is effectively root on the host — deliberate, and
  # the reason this module is not in the wsl profile (Docker Desktop owns that).
  if id -nG "${USER}" | st::grep_q -w docker; then
    st::noop "${USER} is already in the docker group"
  else
    st::run "add ${USER} to the docker group" -- \
      sudo usermod -aG docker "${USER}"
    st::war "log out and back in before the docker group takes effect"
  fi
}
