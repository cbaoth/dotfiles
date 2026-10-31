---
title: yt-dlp (standalone binary, all desktops + saito)
hosts: [motoko, puppet, saito]
status: resolved
tags: [yt-dlp, youtube, ffmpeg, deno, node, curl_cffi]
updated: 2026-10-30
automated_by: setup/modules/24-yt-dlp.sh
---

# yt-dlp (standalone binary, all desktops + saito)

**Automated:** `system-setup 24-yt-dlp` (desktop + server profiles, except the
vserver — see below). Update the binary with `YTDLP_UPDATE=1 system-setup
24-yt-dlp`, or directly: `yt-dlp -U`.

## Why this way

Before this module, motoko had **three** copies: the apt package (`2026.08.19-1`,
pulled in as mpv's `Recommends`, not a deliberate install —
`apt-mark showmanual yt-dlp` showed nothing), the standalone binary in
`~/.local/bin` (self-updated by hand, already at `2026.10.26`), and a
`pip show yt-dlp` hit from the same apt package's dist-packages install. Only
the standalone binary was actually being used (`PATH` order), but having apt's
stale copy sitting there is confusing and it is never the one you want: YouTube
breaks extraction every few weeks and apt only moves on a dist upgrade.

The module does **not** remove the apt package automatically — same stance as
`28-claude-code.sh`'s `claude_cli_warn_conflicts`: removing something the user
might have installed deliberately is a worse surprise than a warning. It warns
and names the exact command (`sudo apt remove yt-dlp`); `mpv` does not vendor
its own copy, it just shells out to whatever `yt-dlp` is first on `PATH`, so
removing the apt one does not affect mpv.

## curl_cffi (TLS/browser impersonation)

Some extractors warn `The extractor specified to use impersonation for this
download, but no impersonate target is available`. This is a **different**
anti-bot layer than the JS-challenge solving `--js-runtimes node` already
handles in `home/.config/yt-dlp/config`:

- **JS runtime (node/deno/bun)**: solves YouTube's signature-cipher /
  proof-of-origin JS challenges. Already required and configured.
- **curl_cffi**: makes the TLS ClientHello / HTTP-2 frame ordering of yt-dlp's
  requests look like a real browser (Chrome/Edge/Safari), for sites that
  fingerprint at the TLS layer rather than (or in addition to) the JS layer.
  Without it, those extractors still work, just with a warning and
  (presumably) a higher chance of throttling.

The standalone binary is the "Unix zipimport binary" release variant, which
the upstream README explicitly excludes from bundling curl_cffi (it is one of
only two variants that don't). It is plain `#!/usr/bin/env python3` over a zip
of pure `yt_dlp` source — no embedded venv — so it resolves optional deps like
curl_cffi from the *running interpreter's* normal `sys.path`, same as any other
Python import.

**Installing it hit PEP 668**: on this (Ubuntu 24.04+-era) Python, even
`pip install --user curl_cffi` is refused with `externally-managed-environment`
— `--user` alone is no longer enough to bypass the guard, contrary to older
expectations. The module uses `pip3 install --user --break-system-packages
curl_cffi`. This is **not** as scary as it sounds for this specific case:
`--user` scopes the install to `~/.local/lib/python*/site-packages`, which
dpkg/apt never touches, so there is nothing "system" to actually break; it is
the exact "I know this isn't apt-packaged" case pip's own error message is
written for. No venv needed, no per-host venv bookkeeping.

**Alternative not taken**: switching yt-dlp's install itself to `pipx` (which
manages an isolated venv per app and supports `pipx inject yt-dlp curl_cffi`
with zero `--break-system-packages` anywhere) would sidestep the PEP 668
question entirely. Rejected here only because it would mean changing the
already-working, already-self-updated install on motoko/saito (both already on
`2026.10.26` via the standalone binary) to accommodate one optional dependency.
Worth revisiting if PEP 668 restrictions tighten further, or if the
`--break-system-packages` flag itself stops working for `--user` installs.

To remove curl_cffi later: `pip3 uninstall curl_cffi`.

## The vserver (11001001.org) is deliberately skipped

Running a browser-impersonating downloader plus a JS engine on the one
internet-facing host is a deliberate no for now — larger attack surface for a
tool whose whole job is evading automated-traffic detection, on the one box
that is actually exposed. The module hard-codes the skip by `hostname -s ==
11001001`, independent of profile (saito is also `server` but is not skipped).

If ever actually needed there: `~/git/web-tools-container` (a devcontainer
already built for exactly this: wget/curl/aria2, yt-dlp, deno, ffmpeg,
openvpn3, isolated from the host, downloads bind-mounted to `~/wdc-share`).
Not wired into this module — it is a separate repo/workflow, not something
`system-setup` manages.

**Known drift in that container** (not fixed here, just noted for whoever
revisits it): its `yt-dlp` comes from `conda-forge`
(`.devcontainer/Dockerfile`), which — like apt — lags upstream and has no
`-U` self-update; and it has no curl_cffi either. If the container ever
becomes the actual day-to-day tool (not just a fallback), swapping that one
`conda install` line for the same standalone-binary approach as this module
would bring it in line.

## Hosts

- **motoko, saito**: already had the standalone binary installed by hand,
  both self-updated to `2026.10.26` as of 2026-10-30 (saito earlier that day,
  motoko via `yt-dlp -U` run manually during this investigation — the module
  itself was dry-run only, not applied, since installing curl_cffi via
  `--break-system-packages` was blocked by the permission classifier in the
  agent session that wrote this; run `system-setup 24-yt-dlp` by hand to
  actually apply the curl_cffi step).
- **puppet**: offline at time of writing, not yet checked/updated.
- **11001001 (vserver)**: not installed, and skipped by design (see above).
