---
title: Vicinae launcher
hosts: [puppet]
status: resolved
tags: [vicinae, launcher, sway, wayland, appimage, systemd, rofi]
updated: 2026-10-10
automated_by: setup/modules/26-vicinae.sh
---

# Vicinae launcher

**Automated:** `system-setup 26-vicinae` (desktop profile).

Native Qt launcher with built-in clipboard history, window switching and file
search, plus an extension API (and partial Raycast extension compatibility).
Replaces rofi (`-show combi`) on `$mod+space`; rofi stays installed as the
fallback in the binding (`40-keybindings.conf`).

## Install

No apt package exists, so the module runs the upstream installer
(<https://docs.vicinae.com/install/linux>), which puts the AppImage contents in
`/usr/local/lib/vicinae`, `/usr/local/bin/vicinae` (symlink), and a systemd user
unit in `/usr/local/lib/systemd/user`.

- The module runs the script as root from a temp file, so the interactive
  `Continue with sudo? [y/N]` prompt never appears.
- "Installed and runnable" counts as done (zero changes on re-run, no network).
  Update with `VICINAE_UPDATE=1 system-setup 26-vicinae`.
- The module then enables the user service: `systemctl --user enable --now vicinae`.
  Without a systemd user session it only warns.

## Gotcha: `permission denied: vicinae` after install

The upstream install leaves `usr/`, `usr/bin/` and friends under
`/usr/local/lib/vicinae` at mode `0700 root:root`, so the symlink in
`/usr/local/bin` resolves to a path the user cannot traverse. `which vicinae`
says "not found", running it says "permission denied".

Cause unconfirmed: either the AppImage's squashfs modes or the extraction
umask. The harmless `sudo: preserving the entire environment is not supported,
'-E' is ignored` line during install is unrelated.

Fix (done by the module): `sudo chmod -R go+rX /usr/local/lib/vicinae`.

## Config: whole-directory link

`~/.config/vicinae` is a symlink to `dotfiles/.config/vicinae/`, configured via
`LINK_DIRS` in `tools/link-config.conf`. Vicinae writes `settings.json` by
write-temp-then-rename, which replaced the old per-file symlink with a regular
file and left the repo copy orphaned. See *Whole-Directory Links* in
[linking-system.md](../linking-system.md).

The app rewrites the file in full (defaults included) and drops comments, so
diffs after changing a setting in the GUI are noisy.

## Open

- Browser tab switching is not covered by any launcher out of the box on sway;
  see the vicinae extension API if it becomes worth a custom extension.
