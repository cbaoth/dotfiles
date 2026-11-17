---
title: gallery-dl (uv tool, desktops + saito + web-tools container)
hosts: [motoko, puppet, saito]
status: resolved
tags: [gallery-dl, yt-dlp, uv, downloader]
updated: 2026-11-17
automated_by: setup/modules/42-gallery-dl.sh
---

# gallery-dl (uv tool, desktops + saito + web-tools container)

**Automated:** `system-setup 42-gallery-dl` (desktop + server profiles, except
the vserver, same as [yt-dlp](yt-dlp.md)). The web-tools container names the
module explicitly. Update with `GALLERYDL_UPDATE=1 system-setup
42-gallery-dl`, or directly: `uv tool upgrade gallery-dl`.

## Why this way

[gallery-dl](https://github.com/mikf/gallery-dl) ships as apt package, pip
package and standalone binary. The module installs
`uv tool install 'gallery-dl[video]'`:

- **uv tool, not apt**: apt lags upstream, and site extractors break about as
  often as yt-dlp's. uv is already everywhere ([uv](uv.md)), and
  `uv tool` is how CLIs get installed here.
- **The `video` extra** is gallery-dl's own: yt-dlp as a Python library, for
  video posts. It lives inside gallery-dl's venv; uv links only the
  `gallery-dl` executable, so `yt-dlp` on PATH stays the standalone binary
  from `24-yt-dlp`.
- **Not the standalone binary**: it cannot import a separately installed
  yt-dlp, so video posts would depend on what the release bundles.
- Don't use `gallery-dl -U` for this install. It is meant for the standalone
  binary; use `uv tool upgrade gallery-dl` instead.

## Config

`~/.config/gallery-dl/config.json` is not managed yet. Cookies and site
credentials never go into this repo.
