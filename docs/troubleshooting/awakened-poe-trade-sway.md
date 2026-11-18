---
title: Awakened PoE Trade overlay on Sway (XWayland, Proton)
hosts: [motoko]
status: open
tags: [sway, xwayland, wlroots, electron, proton, clipboard, game, path-of-exile]
updated: 2026-11-18
---

# Awakened PoE Trade overlay on Sway (XWayland, Proton)

**Verdict: partly working, still open.** The overlay (`Shift+Space`) works in
trade mode, mouse included. Price check, chat commands, wiki lookup and typing
into the overlay's own settings do not. One session freeze happened while
testing hotkeys. motoko: sway, Nvidia proprietary driver, PoE through Proton
11.0-100 (Steam's global "Proton Hotfix" default), APT 3.30.101 AppImage.

Scripts: `bin/poe-awakened-trade` (launcher), `bin/poe-trade-toggle`
(`$hyper+g`, trade mode on/off), `bin/flameshot-hidpi`.

## 1. Launch: two workarounds (2026-08-27, solved)

- AppImageLauncher's binfmt handler routes every AppImage through a Qt GUI
  wrapper with no Wayland plugin; it SIGABRTs (exit 134).
  `APPIMAGELAUNCHER_DISABLE=1` skips it.
- APT ≥ 3.26 (Electron 39) runs as a native Wayland client when it detects
  Wayland, and the overlay then does not work. `--ozone-platform=x11` forces
  XWayland. Upstream: SnosMe/awakened-poe-trade#1647.

## 2. Old version kept running after an update (2026-11-17, solved)

The tray and the local settings page showed 3.29.108 although the updater
logged "Update has already been downloaded … 3.30.101".

- The launcher ran the first `Awakened-PoE-Trade*` match, always 3.29.108.
- electron-updater only downloads into
  `~/.cache/awakened-poe-trade-updater/pending/` and swaps the file on a
  graceful quit. The toggle stops APT with `pkill` (which also tears down the
  AppImage's FUSE mount), so the swap never happened.
- AppImageLauncher's "Integrate and run" dialog had also left hash-named
  copies (`awakened_poe_trade_<md5>.appimage`) plus desktop entries.

Fix (`ce1f51b`): the launcher installs a pending update after checking its
sha512 against `update-info.json`, runs the highest version (`sort -V`), and
deletes every other copy in `~/Applications`. `appimagelauncherd` removes the
matching desktop entries by itself once the files are gone.

## 3. Overlay visible but not clickable; game cursor freezes (2026-11-17, worked around)

Symptoms with the game **sway-fullscreen** (`fullscreen_mode: 1`):

- `Shift+Space` showed the overlay, but the mouse still went to the game, and
  the overlay could not be closed again.
- After switching away from the game's workspace for a second or two and
  back, the game's own cursor was gone or stuck. Input still reached the game
  ("clicking blind"). A very short switch away and back fixed it. Rarely,
  tapping Super in game triggered it too.
- Once, the normal Sway cursor appeared over the overlay; then the overlay
  took clicks and clicking its background closed it.

Cause: the overlay cannot take pointer input over a fullscreen XWayland
surface (#1647). The 2026-11-17 occurrence was simply APT started directly
from a terminal, so the game was still fullscreen.

Workaround: trade mode. `poe-trade-toggle` switches the game to a tiled
`fs=0` window (fills the area below waybar, no titlebar) and starts the
overlay; the next press stops the overlay and re-fullscreens the game.
Confirmed 2026-11-17: overlay clickable, background click closes it, and no
cursor freeze on workspace switches in either mode.

Observed, not a problem: an open overlay follows you to other workspaces
until closed (Esc or background click). A workspace switch can also hide it;
`Shift+Space` brings it back.

### Toggle state (2026-11-18)

The first toggle used "is APT running?" as the only state. When the game
was already windowed at the first press, or APT had exited while the game was
fullscreen, it flipped the game into the wrong state. Three options:
(a)/(c) only act while PoE is focused, (b) decide from the game window's
state. Chose (b): game fullscreen → trade mode on (start APT unless
running); game windowed → off (stop APT, fullscreen); no game window →
start/stop APT only. (a)/(c) would not cover a crashed APT or a game that
restarted in the other state.

## 4. Flameshot selection drops the game out of fullscreen (2026-11-17, solved)

`$hyper+Ctrl+p` (Flameshot `gui`) over the fullscreen game: after the capture
the game was floating at full height, overlapping waybar, with a black bar at
the bottom. `$mod+Alt+z` restored it. Cause: the capture window goes
fullscreen, and Sway allows one fullscreen window per workspace.
`flameshot-hidpi gui` now re-fullscreens those windows after the capture
window closes (`45c4e60`). Confirmed: fullscreen comes back immediately. The
trade toggle moved from `$hyper+Alt+p` to `$hyper+g` (`c4ba19a`) because it
sat next to the screenshot key.

## 5. Hotkeys do nothing except Shift+Space (2026-11-17/18, open)

Symptoms, in trade mode, hovering an item (a flask):

- Price check (Ctrl+D), `/hideout` (F5), `/exit` (F9), and a wiki hotkey set
  to F4 and later to 8 all did nothing. Tried both the Colemak and the QWERTY
  position of each key. No clash with PoE's own bindings.
- The overlay's settings in game take clicks but no keyboard input: fields
  look focused, typing does nothing. The same settings page in a browser
  (tray menu, random localhost port each start) takes keys and saves; the
  in-game copy then shows the change. The browser records keys by QWERTY
  position, which fits APT matching key codes, not characters (#1152).
- Once, an extra APT window flashed on another workspace (the browser's)
  after pressing hotkeys over an item, then vanished. Not reproduced.

Evidence (journal, boot ending 2026-11-17 22:26): during the tests,
`xwayland-clipboard-bridge` logged pairs like
`owner 0x9c00000: bridged …, 282 bytes` followed by a 31-byte copy, about
2-4 per second at peaks (164, 282, 376, 800 bytes). That pattern is APT's
price check: it sends Ctrl+Alt+C to the game, the game puts the item text on
the clipboard, APT reads it and restores the old clipboard. So **hotkey
detection and the synthetic copy key work**; what fails is reading the text
or showing the result.

Leads, not yet checked:

- Proton 11 clipboard breakage: price check silently fails, APT's debug log
  says `[ClipboardPoller] No item text found`. Upstream switched to Proton
  10.0-4 or GE-Proton 10-34 (#1846, #1849). PoE here runs Proton 11.0-100.
- The overlay gets no keyboard focus. That would explain the dead input fields
  in game, not the dead price check.
- The result window may be mapped somewhere it is not visible (the window that
  flashed on the browser's workspace). Compare
  `xwayland-window-mapped-but-not-shown.md`.

Diagnostics set up 2026-11-18: `logKeys: true` in
`~/.config/awakened-poe-trade/apt-data/config.json` (backup `.bak-20261118`)
and APT's output now goes to `~/.local/state/poe-awakened-trade.log` (previous
run `.log.1`), written by `poe-trade-toggle`.

## 6. Session freeze while holding a hotkey (2026-11-17 22:25, open)

Holding a wiki-lookup hotkey for a few seconds froze the display and input
completely; power-off was the only way out. Journal: the bridge's last line
is 22:25:37 (a 31-byte copy, then vicinae logs a 0-byte clipboard clear).
Nothing from sway, Xwayland or the kernel after that, but `timekprd` kept
logging every 3 s until power-off at 22:26:51. So **the kernel was alive; the
graphical session hung**. No Nvidia Xid, no OOM.

Hypothesis (unconfirmed): key repeat fired the copy cycle over and over, and
the clipboard churn between game, APT, wlroots' XWM relay, the bridge
(`xclip` + `wl-copy`) and vicinae deadlocked sway/Xwayland.

To confirm next time: keep an SSH session from another device open
(`journalctl -f`). If it freezes, run `pkill -f awakened-poe-trade` there and
see whether the session recovers. If not, stop the bridge
(`systemctl --user stop xwayland-clipboard-bridge`) to test whether it is
part of the loop.
