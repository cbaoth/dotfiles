# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 42-gallery-dl: gallery-dl (image/gallery downloader) as a uv tool.
#
# `uv tool install 'gallery-dl[video]'`: its own venv, only the gallery-dl
# executable in ~/.local/bin, no root. The `video` extra is gallery-dl's own
# (yt-dlp as a library, for video posts); yt-dlp's executable is not linked,
# so the standalone binary from 24-yt-dlp stays the `yt-dlp` on PATH. Not the
# standalone gallery-dl binary: it cannot import an extra yt-dlp. Not apt:
# lags upstream, and site extractors break as often as yt-dlp's.
#
# Numbered after 34-uv, which it needs. Skipped on the vserver for the same
# reason as 24-yt-dlp (see there). See MODULE_DOC.
#
# "Installed" means done, so a re-run needs no network and reports zero
# changes. Update with GALLERYDL_UPDATE=1 (`uv tool upgrade gallery-dl`).
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="gallery-dl (uv tool with the video extra, ~/.local/bin/gallery-dl)"
MODULE_PROFILES=(desktop server)
MODULE_DOC="docs/setup/gallery-dl.md"

declare -r GALLERYDL_SPEC="gallery-dl[video]"

# hostname -s of the internet-facing host; see 24-yt-dlp.
declare -r GALLERYDL_SKIP_HOST="11001001"

module_run() {
  if [[ "$(hostname -s)" == "${GALLERYDL_SKIP_HOST}" ]]; then
    st::noop "skipping gallery-dl on ${GALLERYDL_SKIP_HOST} (internet-facing; see 24-yt-dlp)"
    return 0
  fi

  # By path first: in an image build ~/.local/bin is not on PATH yet
  # (link.sh runs later), same as 24-yt-dlp's build-time warning.
  local uv="${HOME}/.local/bin/uv"
  if [[ ! -x "${uv}" ]]; then
    if st::have_cmd uv; then
      uv="$(command -v uv)"
    else
      st::war "uv not found — skipping (run '34-uv' first)"
      return 0
    fi
  fi

  if "${uv}" tool list 2>/dev/null | st::grep_q -E '^gallery-dl '; then
    if [[ -n "${GALLERYDL_UPDATE:-}" ]]; then
      st::run "update gallery-dl (uv tool upgrade gallery-dl)" -- \
        "${uv}" tool upgrade gallery-dl
    else
      st::noop "gallery-dl already installed (GALLERYDL_UPDATE=1 to update)"
    fi
    return 0
  fi

  st::run "install ${GALLERYDL_SPEC} (uv tool install)" -- \
    "${uv}" tool install "${GALLERYDL_SPEC}"
}
