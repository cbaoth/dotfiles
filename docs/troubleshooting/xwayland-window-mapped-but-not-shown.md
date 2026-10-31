---
title: XWayland window is mapped but never appears in sway (Double Commander Options)
hosts: [motoko]
status: workaround
tags: [sway, wlroots, xwayland, doublecmd, gtk2, window-rules]
updated: 2026-10-31
revisit: when swaywm/sway#9316 is fixed, retest without xwayland-remap.service
---

# XWayland window is mapped but never appears in sway

**Verdict: worked around by `bin/xwayland-remap`** (2026-10-31, motoko).
Clicking *Configuration > Options* in Double Commander (doublecmd-gtk, GTK2 via
XWayland) did nothing visible. The same goes for every other *Configuration*
entry, since they all open pages of that one Options window. *Help > About* and
the copy dialog kept working.

## Symptom

- The window exists and is mapped in X11: `xwininfo -root -tree` lists
  `"Options"`, `xwininfo -id <id>` says `Map State: IsViewable`, and the wlroots
  XWM has even set `WM_STATE: Normal` on it.
- Sway has **no node** for it: `swaymsg -t get_tree` lists only DC's main
  window, and a `swaymsg -t subscribe '["window"]'` recording shows no `new`
  event for the click at all.
- No error in the sway log at click time.
- Only the **first** click per DC instance creates the window. Later clicks
  re-show the same invisible window, so clicking again never helps.
- Survives a reboot, a fresh sway session and an **empty** DC config dir
  (`doublecmd --config-dir=<empty dir>`), so it's not DC configuration.

Versions: sway 1.12, wlroots 0.20.2, Xwayland 24.1.14 (all upgraded
2026-10-26), doublecmd-gtk 1.1.32. Upstream report with the same versions and
symptom: [swaywm/sway#9316](https://github.com/swaywm/sway/issues/9316)
(filed 2026-10-28, open, no replies). It reproduces it as a race when a window
is mapped right after another. That DC hits this exact trigger is unconfirmed.
It's timing-dependent, which fits the dialog opening fine earlier on the same
versions.

## Fix: map the window a second time

Unmapping and mapping the X11 window again makes sway create a normal
floating container for it, and the dialog works. `bin/xwayland-remap` does
that for every orphaned window: viewable, not override-redirect, carries
`WM_STATE`, and its id is the `window` of no node in sway's tree.

```bash
xwayland-remap             # fix the orphans that exist now
xwayland-remap --dry-run   # only list them
```

`xwayland-remap.service` (a user unit started from
`home/.config/sway/config.d/90-launch-apps.conf`) runs `--watch`. It listens
for MapNotify on the root window, checks each new map after 0.5 s, and remaps
the window if sway still has no container for it. At most two remaps per map,
reset when the client unmaps the window itself (DC hides Options on close and
re-shows the same window). Activity:
`journalctl --user -u xwayland-remap`.

Same pattern as `bin/xwayland-clipboard-bridge`: system Python with
`python3-xlib` (already in `setup/packages/desktop.list`). No setup module,
since there's nothing to install beyond the tracked unit and script.

## Red herrings ruled out

- **DC config** (`doublecmd.xml`, `colors.json`, `session.ini`): empty config
  behaves the same. `session.ini` stores the Options position at 1760,680,
  which is on-screen.
- **sway-float-geometry / sway-place**: they only act on windows sway already
  manages, by container id.
- **The `Doublecmd` popup rule** in `70-window-rules.conf`: its
  `for_window … failed: No matching node` errors fire when the **main** window
  maps, not the dialog. That rule was broken in its own way, see below.
- **GTK2 theme**: DC turned light around the same time (Yaru 26.10 dropped its
  GTK2 themes, see `docs/setup/dark-theme.md`). Switching to `Adwaita-dark`
  fixed the colors but not the dialog.

## Side finding: sway criteria are one bracket, not `[a][b]`

Several rules in `70-window-rules.conf` were written as
`for_window [class="X"][title="Y"] …` (or with the second bracket on a
continuation line). Sway takes **only the first bracket** as criteria. The rest
becomes part of the command:

- `[class=…] \` + newline + `[title=…] cmd`: on every map of a matching class,
  sway runs `[title=…] cmd` as a command with its own criteria against the
  **whole tree**. This mostly looked right, e.g. Firefox Picture-in-Picture
  floated, but it also re-applied to existing matching windows whenever any
  window of that class mapped, and logged `No matching node` otherwise.
- `[class=…][title=…] cmd` with no space: sway rejects `[title=…]` as an
  unknown command, yet the rest still ran for **every** window of the class:
  DC's main window came up floating and borderless (`$popctr`).

Correct form, criteria space-separated inside one bracket:

```text
for_window [class="(?i)^Doublecmd$" title="(?i)^(Options|File operations)$"] $popctr
```

Fixed for all six rules (Winetricks, Protontricks, Doublecmd, Ssvnc, Firefox
PiP, JDownloader). The commented-out GlobalSpeed rule still uses the old
two-bracket form, which may be why its FIXME says it never worked reliably.
Find same-line cases with the command below. A rule ending in `] \` is fine
when the next line is the command, but not when it starts with another `[`:

```bash
grep -rn -E '\]\s*\[' ~/.config/sway/config.d/ | grep for_window
```

## Journal

- 2026-10-30 evening: Options stops opening after a DC session of column
  edits. Reverting `doublecmd.xml` / `colors.json` from a backup changes
  nothing.
- 2026-10-30: X11 window present and viewable, absent from sway's tree, the
  same with an empty config. Restarting sway (reboot) doesn't help.
- 2026-10-31: a window-event recording shows no `new` event on a first
  click. Unmap + map (python-xlib) makes the dialog appear immediately, and
  also for the main DC instance. Found sway#9316. Built `xwayland-remap` and
  its watcher unit.
