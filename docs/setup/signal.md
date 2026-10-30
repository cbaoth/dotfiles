---
title: Signal Desktop (apt repo, not flatpak)
hosts: [motoko, puppet]
status: resolved
tags: [signal, apt, desktop]
updated: 2026-10-30
automated_by: setup/modules/37-signal.sh
---

# Signal Desktop

**Automated:** `system-setup 37-signal` (desktop profile, amd64 only).

## Why apt and not the flatpak

- The flatpak (`org.signal.Signal`) is not listed on Signal's download page,
  so it is likely third-party maintained; the apt repo is Signal's own.
- apt gets unattended and routine updates; flatpaks here are only updated
  manually and rarely. Signal expires old clients, so staying current matters.

The flatpak was uninstalled (`flatpak uninstall --delete-data
org.signal.Signal`) and its line removed from
`setup/packages/flatpak-desktop.list`.

Not the cause of the original "cannot link" problem: that was scanning the
wrong QR code in the phone app (Add contact instead of Link new device). In
Signal on the phone: Settings > Linked devices > Link new device.

Source: <https://signal.org/download/> ("Download for Linux (Ubuntu and
Debian-based)").

## What the module enforces

- Signing key, dearmored: `/usr/share/keyrings/signal-desktop-keyring.gpg`
  (from `https://updates.signal.org/desktop/apt/keys.asc`)
- `/etc/apt/sources.list.d/signal-desktop.sources` (deb822; content inlined
  from Signal's `signal-desktop.sources`, so re-runs need no network)
- `apt install signal-desktop`

## Fallback: AppImage

Signal also ships a self-updating AppImage with a detached GPG signature
(<https://signal.org/download/>, button "Download Linux AppImage"). Not used:
apt is simpler to keep updated alongside everything else. Only needed on a
non-Debian host.

## Manual

Linking the desktop client to the phone is interactive (QR code scan) and
stays manual.
