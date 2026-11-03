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
MODULE_PROFILES=(desktop server wsl-work)
MODULE_DOC="docs/setup/docker.md"

module_run() {
  # Docker's own apt repo (docker-ce) may already provide the engine. Ubuntu's
  # docker.io conflicts with it (apt would remove docker-ce, containerd.io), and
  # Ubuntu's docker-buildx / docker-compose-v2 overwrite files of Docker's
  # *-plugin packages, which fails mid-dpkg and leaves docker.io half-installed.
  # So an existing engine or plugin is left alone (work WSL, 2026-11).
  local -a pkgs=()
  if st::apt_installed docker-ce; then
    st::noop "docker-ce (Docker's own repo) is installed, leaving the engine alone"
  else
    pkgs+=(docker.io)
    # docker-compose-v2 is listed explicitly: docker.io does NOT pull it in, so
    # `docker compose` silently does not exist, which reads like a broken Docker
    # rather than a missing package. Cost real time during the 2026-07 rebuild.
    st::apt_installed docker-buildx-plugin || pkgs+=(docker-buildx)
    st::apt_installed docker-compose-plugin || pkgs+=(docker-compose-v2)
  fi
  if (( ${#pkgs[@]} > 0 )); then
    st::apt_install "${pkgs[@]}"
  fi

  # Membership in 'docker' is effectively root on the host — deliberate.
  # Docker Engine (Ubuntu's docker.io) is Apache-2.0; only Docker Desktop is
  # paid for companies, and this module never installs it.
  if id -nG "${USER}" | st::grep_q -w docker; then
    st::noop "${USER} is already in the docker group"
  else
    st::run "add ${USER} to the docker group" -- \
      sudo usermod -aG docker "${USER}"
    st::war "log out and back in before the docker group takes effect"
  fi

  if st::is_wsl && [[ "$(ps -p 1 -o comm= 2>/dev/null)" != "systemd" ]]; then
    st::war "WSL without systemd: dockerd will not start. Set [boot] systemd=true in /etc/wsl.conf, then run 'wsl --shutdown' from Windows"
  fi
}
