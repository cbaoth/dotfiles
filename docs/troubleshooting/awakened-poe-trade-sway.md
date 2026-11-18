---
title: Awakened PoE Trade overlay on Sway (XWayland, Proton)
hosts: [motoko]
status: workaround
tags: [sway, xwayland, wlroots, electron, proton, clipboard, game, path-of-exile, colemak]
updated: 2026-11-18
---

# Awakened PoE Trade overlay on Sway (XWayland, Proton)

**Verdict (2026-11-18): working, with workarounds.** In trade mode the
overlay, price check (auto-hide and "open without auto-hide"), wiki links and
chat commands all work. Workarounds: an `LD_PRELOAD` shim for APT's simulated
keys, a 100 ms key delay, the clipboard bridge paused in trade mode, and APT
hotkeys only on keys that Colemak and QWERTY share. See **section 9** for the
working setup and its rules. Still open: typing into the in-game settings
fields (use the browser settings page, see 9), and the session freeze
(section 6), not seen again since the bridge pause. motoko: sway, Nvidia
proprietary driver, PoE through Proton Experimental 11.0, APT 3.30.101
AppImage.

Scripts: `bin/poe-awakened-trade` (launcher + shim build),
`bin/poe-trade-toggle` (`$hyper+g`, trade mode on/off), `bin/flameshot-hidpi`,
shim source `home/.local/share/poe-awakened-trade/xsend2xtest.c`.

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

## 7. Update 2026-11-18: clipboard confirmed as the blocker

- APT's on-screen key log (`logKeys`) shows every key: hotkey detection works.
  Keys are matched by **physical QWERTY position** (Colemak `s` shows as `D`,
  `d` as `G`), so a binding of `D` means the physical D key.
- The wiki hotkey (`z`) shows `[ClipboardPoller] No item text found`. That is
  the Proton 10+/11 failure from #1846.
- Bridge journal 17:12–17:28: only 31-byte copies, **no item text at all**.
  The 31 bytes are presumably APT's marker, written before it sends
  Ctrl+Alt+C. On 2026-11-17 the item texts did arrive, probably late: users in
  #1846 report Wine/Proton only publishes a copy once the game **loses focus**
  (e.g. a workspace switch), after APT's poller has given up. The
  maintainer's workaround (e735d39) is not enough here on 3.30.101.
- Users report fixes with Proton 10.0-4, GE-Proton 10-34 and Proton
  Experimental (11.0, 2026-07-24 build). Installed here: Proton Experimental
  `experimental-11.0-20261112`, newer and still 11.0, so no prefix downgrade.
  Next test: run PoE on Proton Experimental.
- APT's "game settings file not found" is `gameConfig: null`. Under Proton the
  file is in the prefix:
  `~/SteamLibrary/steamapps/compatdata/238960/pfx/drive_c/users/steamuser/Documents/My Games/Path of Exile/production_Config.ini`.
  The client log is `~/SteamLibrary/steamapps/common/Path of Exile/logs/Client.txt`.
- The toggle's first press left the game fullscreen; the second press made
  it windowed. That fits "no game window found" on the first press
  (unconfirmed). The toggle now logs every decision to
  `~/.local/state/poe-trade-toggle.log`.

## 8. Update 2026-11-18 evening: Proton Experimental does not help

- PoE switched to Proton Experimental (`experimental-11.0-20261112`); the
  running processes confirm it. The prefix version stays `11.0-100`, which is
  also Experimental's `CURRENT_PREFIX_VERSION`. Result unchanged: no item text.
- The state-aware toggle picked the right branch on every press (toggle log
  17:44–17:50).
- Clipboard owners identified: the first 31-byte owner is APT
  (`WM_NAME "Chromium clipboard"`). The second owner, about 15 ms later,
  with incrementing window IDs, is the game's Wine side: its ID range reset
  when the game restarted, and the client has no WM properties. Wine re-exports
  APT's marker; the game's own copy (Ctrl+Alt+C) never reaches X11.
- Open question: does Ctrl+Alt+C reach the game at all (APT sends it with
  XTEST), or does Wine hold the copy back until the game loses focus (#1846)?
  Test: copy manually in game and watch
  `journalctl -t xwayland-clipboard-bridge -f`.

## 9. Root causes and the working setup (2026-11-18 night)

Found by injecting keys outside APT and logging clipboard owners and
focus changes with millisecond timestamps (scripts were throwaway; the method
is what matters: `journalctl -t xwayland-clipboard-bridge -f` plus
`swaymsg -t subscribe '["window","workspace"]'` side by side).

### 9.1 APT's simulated keys never reached the game

- A manual Ctrl+Alt+C in game copies **immediately** (Wine owner, 479 bytes
  0.3 s after the press). So Wine does not hold back copies here.
- APT's input library uiohook-napi (`resources/app.asar.unpacked/node_modules/
  uiohook-napi/prebuilds/linux-x64/uiohook-napi.node`) sends keys with
  **`XSendEvent`** to the focused window. It imports no `XTest*` symbols at all
  (`nm -D --undefined-only`).
- Same Ctrl+C via `XSendEvent` from a test script: nothing. Via **XTEST**: copy,
  even with zero delay between events. Proton 10+ Wine ignores synthetic
  `XSendEvent` key events.
- Side finding: XTEST Ctrl → Alt → C arrived as **Alt+C** (Ctrl dropped;
  Windows treats Ctrl+Alt as AltGr). Alt → Ctrl → C and plain Ctrl+C worked.
  Irrelevant for APT ≥ 3.29: it copies with Ctrl+C only (the game always copies
  the advanced format since PoE 3.29).
- Fix: `xsend2xtest.c`, an `LD_PRELOAD` shim that turns `XSendEvent`
  KeyPress/KeyRelease into `XTestFakeKeyEvent` and passes everything else
  through. The launcher builds it into `~/.cache/poe-awakened-trade/` on
  demand (needs `cc` + `libx11-dev`) and preloads it. In APT's main process
  the shim removes `LD_PRELOAD` from the environment, so browsers APT opens
  don't inherit it. `POE_APT_NO_SHIM=1` disables it, `XSEND2XTEST_DEBUG=1`
  logs every converted key.

### 9.2 Clipboard race (bridge, chat paste)

- APT writes a marker to the clipboard, then sends Ctrl+C. Wine imports the
  marker into the game within about 20 ms; a Ctrl+C landing during that is
  lost. `xwayland-clipboard-bridge` adds churn (it reads every change and
  re-publishes it via `wl-copy`). Result with the shim: about 1/9 copies with
  the bridge running, 5/5 with it stopped. **`poe-trade-toggle` now pauses
  the bridge in trade mode** and resumes it afterwards (only if it paused it).
- Chat commands (`/hideout` on F5) write the text to the clipboard and paste
  right away: failed with no delay, worked with `XSEND2XTEST_DELAY_MS=100`.
  The shim holds the first key of a burst server-side for that long (APT's
  thread keeps running). **The launcher defaults to 100 ms.** Item copies work
  at 0 and at 100 ms (100: 13/15 by a tired count; maybe noise).

### 9.3 Hotkeys on keys that Colemak moves never fire

The keymap has three groups (Extend, Colemak, QWERTY; `kbd-layout-toggle`).
Electron's X11 global shortcuts resolve the accelerator letter to the
**first** keycode carrying it in any group: `d` → keycode 40 (QWERTY group,
physical D). On a press, Electron translates that keycode with the **current**
group, under Colemak `s` ≠ `d`, and drops the event. Under QWERTY (Scroll
Lock) it works.

Rule: bind APT hotkeys only to keys that sit in the same place in both
layouts: `Q W A H Z X C V B M`, digits, F-keys (and modifiers). APT's settings
page records keys by **physical QWERTY position**, matching uiohook's key log.
Current bindings: price check `Ctrl+Z` (auto-hide) / `X` (open without
auto-hide), wiki `Z`, chat F5/F9.

Game-side caveat: APT's Ctrl+C with no item under the cursor arrives as the
game's own `c` binding (character panel here).

### 9.4 Price check only appeared in the browser

The settings page APT serves (tray menu → opens `http://localhost:<random
port>` in the default browser) is a full client of the overlay UI. While such
a tab was open, the price-check panel appeared **there** and never on the
in-game overlay (which was mapped over the game; a watcher on
`_NET_ACTIVE_WINDOW` and the overlay's map state showed that). After closing
every `localhost` tab and restarting APT, the panel shows in game.

Also: the port changes on every APT start, so an old tab is a **previous
session**: settings changed there do not apply and its debug log is stale.
The settings dialog has Save/Cancel; clicking next to it or Esc cancels.

Rules:
- Close the browser settings tab when done; never keep it open while playing.
- Settings that need typing (in-game fields take no keyboard input): use the
  browser page, Save, close the tab.

### 9.5 Overlay stuck visible on all workspaces

Once the overlay stayed mapped (override-redirect, so sway draws it on every
workspace) after the game lost focus, with the `logKeys` debug widget on.
A restart via the toggle cleared it. `logKeys` is off again
(`config.json.bak-20261118` holds the old config).

### 9.6 Toggle fixes

- Two presses within 2 s killed the new APT: the old delayed
  `pkill -KILL` by pattern hit it. Stop is now synchronous (TERM, wait max
  3 s, KILL the same PIDs).
- `pgrep -f` with APT's pattern also matches **an agent's shell** whose
  command line contains `awakened-poe-trade` (e.g. a config path): the toggle
  then believed APT was running and skipped the start. Keypresses are not
  affected; agents should not mention that string in a command that runs the
  toggle.
- Every press is logged to `~/.local/state/poe-trade-toggle.log`, APT's
  output to `~/.local/state/poe-awakened-trade.log` (previous run `.1`).

### 9.7 Not caused by APT

- The Chromium "zygote … Broken pipe" lines after APT opens a link come from
  Vivaldi itself (same with a plain `open https://…`).
- Vivaldi could not pass the Cloudflare check on the PoE trade site (endless
  loop); Firefox Nightly works and is now the default browser
  (`mimeapps.list` → `firefox-nightly.desktop`, not Firefox's generated
  `userapp-Nightly-<random>.desktop`).
