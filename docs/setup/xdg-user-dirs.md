---
title: XDG user directories (Screenshots)
hosts: [motoko, puppet]
status: resolved
tags: [xdg, sway, screenshots, grim, grimshot]
updated: 2026-08-15
automated_by: setup/modules/15-xdg-dirs.sh
---

# XDG user directories

**Automated:** [`setup/modules/15-xdg-dirs.sh`](../../setup/modules/15-xdg-dirs.sh)
(`system-setup 15-xdg-dirs`).

`xdg-user-dirs-update` creates the standard set (`Pictures`, `Documents`,
`Downloads`, …) on first login and records them in `~/.config/user-dirs.dirs`.
Everything *outside* that standard set is our own convention, and nothing
creates it.

Currently that is exactly one directory:

| Variable | Value | Created by |
| -------- | ----- | ---------- |
| `XDG_PICTURES_DIR` | `~/Pictures` | `xdg-user-dirs-update` |
| `XDG_SCREENSHOTS_DIR` | `~/Pictures/Screenshots` | **nothing** → the module above |

`XDG_SCREENSHOTS_DIR` is exported by
[`dotfiles/.common_env`](../../dotfiles/.common_env) and is not part of the XDG
base-directory spec — it is a de-facto convention that grim, grimshot and
several other Wayland tools honour.

## Why this needs a module: "Error: Unable to invoke grim"

Symptom, on a freshly set-up machine (first hit on puppet, 2026-08-15): sway's
screenshot bindings pop up a notification reading

> Error: Unable to invoke grim

slurp still works — the area selection appears normally — and flameshot is
unaffected. The cause is nothing to do with grim being broken or missing:

- grimshot builds its target path as
  `${XDG_SCREENSHOTS_DIR:-${XDG_PICTURES_DIR:-$HOME}}/<timestamp>.png`
  and does **not** check that the directory exists.
- grim does not `mkdir -p` its output path; it fails with
  `Failed to open file '…' for writing: No such file or directory` and exits 1.
- grimshot turns any non-zero grim exit into that one generic message.

The confusing part is that testing `grim` by hand appears to work: grim's *own*
default-path logic falls back to `XDG_PICTURES_DIR` when
`XDG_SCREENSHOTS_DIR` is not usable, so a bare `grim` silently writes
`~/Pictures/<timestamp>_grim.png` instead. grimshot has no such fallback,
because it passes an explicit filename.

Reproduce and confirm in one line:

```bash
grim "${XDG_SCREENSHOTS_DIR}/test.png"   # exit 1 if the directory is missing
```

## Screenshot filenames

The sway bindings pass an explicit filename rather than accepting grimshot's
default, which is `date -Ins`
(`2026-08-15T14:55:41,457393075+02:00.png` — colons, a decimal comma and
nanoseconds). See [sway.md](sway.md#screenshots).
