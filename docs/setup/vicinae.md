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

## Gotcha: launcher opens but gets no keyboard input

Symptom: `$mod+space` shows the prompt, but typed keys go to the previously
focused window (VS Code, a browser, a terminal). Only on an empty workspace, or
after hovering the prompt with the mouse, does it receive input.

Cause: `"close_on_focus_loss": true` makes Vicinae request *on-demand*
layer-shell keyboard focus (`set_keyboard_interactivity(2)` in a
`WAYLAND_DEBUG=client` trace; its default config comment says that option has no
effect with the default *exclusive* mode). With on-demand, sway sends
`keyboard.enter` to the launcher and then gives focus back to the focused
toplevel within milliseconds (`keyboard.leave`), so toggling again just
re-opens the window.

Fix: `"close_on_focus_loss": false` (exclusive focus). Esc closes
(`escape_key_behavior: close_window`), `$mod+space` toggles. Not the cause, tried
and ruled out: `focus_follows_mouse`, a `--release` binding with a delay,
and the layer. Possibly related upstream bug for other launchers:
[sway#8655](https://github.com/swaywm/sway/issues/8655) (unconfirmed for this
setup).

`"layer_shell": {"layer": "overlay"}` is kept on purpose: it did not change the
focus bug, but it keeps the launcher above fullscreen windows (`top` does not).
With the pointer over another window, that window briefly flashes focus before
the launcher takes it back; cosmetic.

**Revert candidate:** if the launcher pops up over a fullscreen game after an
accidental key press and steals its focus, delete the `layer_shell` block from
`settings.json` (or set `"layer": "top"`) and restart with
`systemctl --user restart vicinae`. No comment lives in `settings.json` itself
on purpose: Vicinae drops comments whenever it rewrites the file from the GUI.

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
