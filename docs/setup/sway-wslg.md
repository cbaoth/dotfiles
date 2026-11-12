---
title: sway nested in WSLg
hosts: [wsl-work, motoko]
status: open
tags: [wsl, wslg, sway, wayland, windows, clipboard, keyboard]
updated: 2026-11-06
revisit: 2026-12
---

# sway nested in WSLg

Tiling on a Windows PC without a VM: WSLg (WSL2's built-in Wayland
compositor) shows sway as one Windows window; everything started inside is
tiled by sway. Manual setup, no `setup/` module yet (see *Open*).

```bash
sudo apt install sway foot wl-clipboard xwayland xclip   # wev: optional, key debugging
dotfiles-link                                      # links the files below
sway-wslg -s 2560x1400                             # detaches; log in ~/.local/state/sway-wslg/
```

| File | Role |
| ---- | ---- |
| `bin/sway-wslg` | Launcher: checks WSLg, sets env, starts sway with the WSLg config |
| `bin/sway-wslg-clipboard` | Clipboard bridge sway ⇄ WSLg (started by the config) |
| `home/.config/sway/wslg/config` | Standalone minimal config (not the desktop `config.d/`) |
| `home/.config/xkb/symbols/{custom,extend}` | Same Colemak/Extend/Hyper layouts as the desktop |

All of it is in the `work` link profile (`tools/profiles/work.list`). Nothing
in it is work-specific: the personal `wsl` / `full` profiles (e.g. motoko
booted into Windows) link it anyway.

## Verified (2026-11, Ubuntu 26.04, sway 1.11 / wlroots 0.19)

- `sway` started from a WSL shell picks the Wayland backend by itself
  (`WAYLAND_DISPLAY=wayland-0` from WSLg) and opens one window, output `WL-1`.
  Its own socket is `wayland-1`.
- Without `WLR_NO_HARDWARE_CURSORS=1` the pointer is invisible.
- Window size = output mode: `swaymsg -- output WL-1 mode --custom WxH` resizes
  the Windows window. Dragging its edge does nothing (no decorations).
- Xwayland is not a dependency of the `sway` package: install `xwayland`.
- WSLg mounts `/tmp/.X11-unix` read-only without the sticky bit (twice,
  stacked), so wlroots refuses to start Xwayland. Fix until the next WSL
  restart (keeps WSLg's own `:0` working); not automated yet:
  ```bash
  while mountpoint -q /tmp/.X11-unix; do sudo umount /tmp/.X11-unix || break; done
  sudo chmod 1777 /tmp/.X11-unix
  sudo ln -sf /mnt/wslg/.X11-unix/X0 /tmp/.X11-unix/X0
  ```
  sway then logs "Failed to bind … X0: Address already in use" and takes `X1`
  (Xwayland starts lazily on the first X11 client). Harmless.
- **Clipboard:** WSLg ⇄ Windows syncs (text). Nested sway ⇄ WSLg does **not**.
  WSLg has no data-control protocol, so `wl-paste --watch` only works on the
  sway side; the Windows → sway direction has to poll. Hence the bridge,
  tested both ways incl. multi-line text and Windows-side clear.
- **Focus stealing:** without data-control, every `wl-paste`/`wl-copy` on
  WSLg's `wayland-0` grabs keyboard focus for a moment
  ([microsoft/wslg#1512](https://github.com/microsoft/wslg/issues/1512)).
  The first bridge polled `wayland-0` twice a second: any WSLg window took
  focus back from Windows after a click elsewhere, and Alt+Tab collapsed.
  Not AutoHotkey (also with AHK closed) and not sway (a plain WSLg `foot`
  did it too, while the bridge ran). The bridge now talks to WSLg via its
  X11 display `:0` (`xclip`), which needs no focus.
- `wl-copy` without `--type` runs `xdg-mime` to guess the type; in WSL that
  hung and blocked the bridge. Always pass `--type`.
- **Keys:** WSLg forwards scancodes; sway applies its own xkb keymap, so the
  Windows layout is irrelevant for plain keys (Colemak works). But the
  wlroots Wayland backend does not track modifiers itself (`update_state =
  false` in `backend/wayland/seat.c`): the modifier state is whatever WSLg
  reports, i.e. Shift, Ctrl, Alt. So the ISO key (`<LSGT>`, Hyper_L) arrives
  as a key (`wev`: key 94) but **never as Mod3**, and the Win key does not
  arrive at all. Workaround in the config: ISO enters a binding mode (`wm`)
  and every binding there returns to default (one-shot). So ISO+1, ISO+2
  needs ISO released in between. Holding ISO cannot act as a real modifier:
  sway arms a `--release` binding on the press and drops it as soon as
  another key is pressed, so releasing ISO after ISO+key is invisible.
- CapsLock never reached sway (wev), so the xkb Extend layer cannot work
  nested. NumLock on the Windows side would arrive as locked Mod2, which the
  custom layout uses for Extend: keep NumLock off.

## AutoHotkey

The WSLg windows belong to `msrdc.exe`. The AHK hotkeys must be off there, or
they eat the keys before sway sees them:

```autohotkey
#HotIf !WinActive("ahk_exe msrdc.exe")
; ... hotkeys ...
#HotIf
```

The Win+drag move hotkey is still useful for the sway window as a whole.

## Open

- Clipboard bridge: tested standalone against a running sway, not yet from
  the WSLg config (`exec`) in a real session.
- Colemak works. Extend (CapsLock) cannot work in sway itself; option: let
  AutoHotkey's Extend layer stay active for `msrdc.exe` (it sends plain
  navigation keys). AltGr umlauts untested.
- Win key as `$mod`: impossible nested (see *Keys*); the ISO hold mode
  replaces it.
- sway's Windows window sometimes jumps to the foreground when switching to
  another Windows window: caused by the old bridge (see *Focus stealing*);
  recheck with the X11 bridge.
- Windows -> sway still polls `:0` (0.5 s). Event-driven via XFixes is
  possible (python3-xlib, like `bin/xwayland-clipboard-bridge`).
- Does sway survive closing the last WSL terminal? WSL may stop the distro
  once no `wsl.exe` session is left; `sway-wslg -f` from a Windows shortcut
  would keep one open.
- If this stays: a `setup/` module for the packages above (`wsl-work`).
