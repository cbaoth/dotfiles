---
title: Sway mode overlay vanishing, resize timeout not resetting, waybar glyphs/states
hosts: [motoko]
status: resolved
tags: [sway, waybar, modes, osd, gtk, layer-shell, resize]
updated: 2026-10-17
---

# Sway mode overlay & resize timeout

Problems hit while building the mode overlay (`bin/sway-mode-osd`) and the
waybar restyle. Steady-state description:
[sway.md → Binding modes & overlay](../setup/sway.md#binding-modes--overlay).

## 1. Overlay shown nothing at all (first install)

`$mod+Escape` showed only the waybar label. The typelib was not installed
(`apt-cache policy gir1.2-gtk4layershell-1.0` → `Installed: (none)`), and the
daemon died with `Namespace Gtk4LayerShell not available` — invisible, because
`exec_always` sends stderr to the sway log nobody reads.

Note `libgtk4-layer-shell0` (the library) *was* installed, so
`ctypes.CDLL("libgtk4-layer-shell.so.0")` succeeded; only the GObject
introspection data (`gir1.2-*`) was missing.

Fix: install it; the daemon now raises a notification with the install command
when the namespace is missing.

## 2. Overlay vanished after a while (after `$mod+Escape c`)

Worked after install, then stopped showing — no process, no pidfile. Trigger:
a **sway reload**. `exec_always sway-mode-osd daemon --replace` starts a new
instance, which SIGTERMs the old one. Both were a `Gtk.Application` with the
same `application_id`: the new instance found the name still owned on D-Bus,
became a *remote* instance (just activates the primary) and exited; the old
one then quit on the SIGTERM. Nothing left.

Fix: `Gio.ApplicationFlags.NON_UNIQUE` (the pidfile does the singleton job),
plus `--replace` waits up to 2 s for the old pid to disappear. Also: any
exception in the `activate` handler now quits the app — before, a failing
`build()` left a process holding the app alive with no event source (seen
while testing with a stale `SWAYSOCK`).

Test that would have caught it: two `swaymsg exec 'sway-mode-osd daemon
--replace'` in a row must leave exactly one daemon whose pid matches
`$XDG_RUNTIME_DIR/sway-mode-osd.pid`.

## 3. Resize keys did not reset the mode timeout

Pressing `q`/`w` in `$mod+x` resized, but the countdown ran out anyway; keys
pressed after that went into the focused window as text.

Before this session the bindings also switched to `mode "$mode_resize"`, a
variable that was **never defined** (sway keeps the literal, the mode does not
exist). That was removed first; the timeout still did not reset.

What it was not: `sway-mode-timeout` killing the previous timer works (checked
with two `swaymsg exec 'sway-mode-timeout 60'` — the old bash pid is gone).

Cause: a sway command list **aborts at the first failing command**. A resize
that cannot happen (`"Cannot resize any further"` — size limit, or no
neighbour in that direction) returns `success: false` and the trailing
`; exec sway-mode-timeout …` never runs. Confirmed via
`swaymsg 'resize grow width 1 px; exec sway-mode-timeout 63'` on a window that
cannot resize: error, no timer started. (A `0 px` resize is rejected as a
parse error too, so it is useless as a harmless probe.) Not separately
confirmed: whether it also skipped after *successful* resizes — the window
focused during testing could not resize at all.

Fix: `exec sway-mode-timeout $mode_timeout_secs; resize …` — the reset first,
in all 16 resize bindings (letters *and* arrows, with and without Shift).

Side bug found on the way: every reset orphaned the previous timer's `sleep`
(killing a bash script does not kill its foreground child). With key repeat
that is dozens per second. Now `sleep & wait` with a TERM trap that kills it.

Not a bug: holding `q`, briefly pressing `w`, releasing `w` → `q` does not
resume repeating. Key repeat only ever applies to the most recently pressed
key; same in every application.

## 4. Waybar: missing glyphs, volume yellow at 30%

- Wifi, volume and scratchpad showed no glyph. The Font Awesome characters
  (BMP private use area, U+F000–F8FF) were simply **absent from
  `config.jsonc`** — lost at some earlier edit. Supplementary-plane Nerd Font
  glyphs (`U+F035B` …) were intact. Now written as `` JSON escapes,
  which survive any editor or tool.
- Volume at 30% was yellow with `"states": {"warning": 70, "critical": 90}`.
  `pulseaudio` calls `getState(volume, true)` — **"at or below"**
  semantics, the battery-style inversion — unlike `cpu`/`memory`. Thresholds
  are upper bounds there: `{"normal": 69, "warning": 89, "critical": 100}`.

## Testing gotcha: stale `SWAYSOCK`

An agent shell inherits `SWAYSOCK` from when it started; after sway is
restarted, every `swaymsg` fails with `Unable to connect`. The `ls` alias
appends `=` to socket names (`ls -F`), so `$(ls -t …sock | head -1)` also
yields a broken path — use `command ls`.
