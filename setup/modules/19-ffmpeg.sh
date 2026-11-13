# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 19-ffmpeg: static FFmpeg (BtbN GPL build) into $HOME, via bin/ffmpeg-install.
#
# The apt build is older and less complete (no rubberband, among others), and
# it only moves on a dist upgrade. The static build is installed per user
# (~/.local/bin symlinks, no root) and updated on request. It wins on PATH over
# the apt one, which stays installed where other packages depend on it (mpv).
#
# Not part of the container profile: containers that need it name it
# explicitly (it overrides the profile filter), like 24-yt-dlp:
#   system-setup --yes 19-ffmpeg
#
# Skipped on the vserver (11001001.org): same reasoning as 24-yt-dlp, no media
# tooling on the one internet-facing host.
#
# Present means done: update with FFMPEG_UPDATE=1 system-setup 19-ffmpeg (or
# run `ffmpeg-install update`).
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="static FFmpeg (BtbN GPL build, ~/.local/bin) via bin/ffmpeg-install"
MODULE_PROFILES=(desktop server)
MODULE_DOC="docs/setup/ubuntu-base.md"

declare -r FFMPEG_LINK="${HOME}/.local/bin/ffmpeg"
declare -r FFMPEG_SKIP_HOST="11001001"

module_run() {
  if [[ "$(hostname -s)" == "${FFMPEG_SKIP_HOST}" ]]; then
    st::noop "skipping ffmpeg on ${FFMPEG_SKIP_HOST} (internet-facing; see module header)"
    return 0
  fi

  local installer="${ST_SETUP_DIR}/../bin/ffmpeg-install"
  if [[ ! -x "${installer}" ]]; then
    st::war "bin/ffmpeg-install not found or not executable: ${installer}"
    return 0
  fi

  if ! st::have_cmd curl && ! st::have_cmd wget; then
    st::war "neither curl nor wget found — skipping (run '00-apt-base' first)"
    return 0
  fi
  if ! st::have_cmd xz; then
    st::war "xz not found — skipping (the build ships as .tar.xz; install xz-utils)"
    return 0
  fi

  # Installed = the link exists and points into the managed builds directory.
  if [[ -L "${FFMPEG_LINK}" && "$(readlink -f "${FFMPEG_LINK}")" == *"/ffmpeg-builds/"* ]]; then
    if [[ -n "${FFMPEG_UPDATE:-}" ]]; then
      st::run "update static ffmpeg (ffmpeg-install update)" -- "${installer}" --yes update
    else
      st::noop "static ffmpeg already installed: ${FFMPEG_LINK} (FFMPEG_UPDATE=1 to update)"
    fi
  else
    st::run "install static ffmpeg (ffmpeg-install install)" -- "${installer}" --yes install
    if ! (( ST_DRY_RUN )) && ! st::have_cmd ffmpeg; then
      st::war "installed, but ~/.local/bin is not on PATH — run dotfiles-link, then a new shell"
    fi
  fi
}
