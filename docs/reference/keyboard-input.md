---
title: Keyboard input debugging (evtest, wev) and special keys
hosts: [all]
status: resolved
tags: [keyboard, evtest, wev, evdev, sway, logitech, solaar, scancode]
updated: 2026-11-03
automated_by: setup/modules/38-solaar.sh
---

# Keyboard input debugging

## Which tool

| Question | Tool |
| -------- | ---- |
| Which devices have keys, is one grabbed? | `input-keyboards` |
| What does this key send, from which device? | `input-keyboards debug` |
| Which keysym does sway see (for `bindsym`)? | `wev` (focus its window, press the key) |
| Logitech key that sends nothing at all | `solaar show` |

- `input-keyboards debug` runs `evtest` on every physical device with keys at
  once and prints one line per event: device, key name, down/up, scan code
  (`MSC_SCAN`, what a udev hwdb remap needs). `debug event5` or
  `debug consumer` narrows it down. Keys still reach sway while it runs.
- Needs read access to `/dev/input` (group `input`), no sudo. `evtest` and
  `wev` come from `setup/packages/desktop.list`.
- Keys that sway itself binds never reach `wev`; read those from the sway
  config instead.

## One keyboard, several devices

A Logitech receiver shows up as several event devices, all named "Logitech
USB Receiver" whatever the receiver is (`lsusb` tells Bolt `046d:c548` from
Unifying `046d:c52b`; evtest prints the product id in its header):

- `… Receiver` (`ID_INPUT_KEYBOARD`): letters, modifiers, the Fn-row
  shortcuts.
- `… Consumer Control`: media keys (volume, play/pause, calculator, mail).
- `… System Control`: sleep, power.

## Grabbed devices

A process holding `EVIOCGRAB` gets the events exclusively; evtest then prints
"This device is grabbed by another process". `input-keyboards` marks such
devices. Vocalinux grabs every physical keyboard since v0.18 and re-emits it
as a virtual "… (vocalinux)" device; `input-keyboards debug` stops it while
watching and starts it again on exit. Details:
[vocalinux setup note](../setup/vocalinux.md).

## MX Mechanical Mini (motoko, Bolt receiver)

Fn-row keys, Fn held, observed 2026-10-15. The keyboard is set to
*Windows* (`solaar show`: MULTIPLATFORM), so the special keys send Windows
shortcuts:

| Key | Icon / Solaar name | Sends | In sway today |
| --- | ------------------ | ----- | ------------- |
| Fn+F4 / Fn+F5 | Backlight Down / Up | nothing (firmware) | diverted: voice-note toggle / hold-to-talk (below) |
| Fn+F6 | Dictation | Super+H | diverted: read aloud, `tts-speak toggle` (below) |
| Fn+F7 | Emoji | Super+Ctrl+Alt+Shift+Space | diverted: read aloud, clipboard first (below) |
| Fn+F8 | Screen Capture | Super+Shift+S | `$mod+Shift+s` = `layout stacking` |
| Fn+F9 | Mute Microphone | nothing on any device | diverted: mic mute toggle (below) |
| Fn+F10 | Search | `KEY_SEARCH` (scan `c0221`, Consumer Control) | unbound |
| Fn+F11… | Play/Pause, Mute, Volume | media keys on Consumer Control, e.g. `KEY_PLAYPAUSE` (scan `c00cd`) | `XF86Audio*` bindings |

- The keys that send nothing (Backlight, Mute Microphone) are handled in the
  keyboard firmware / over HID++.
- Backlight, Dictation, Emoji, Screen Capture, Mute Microphone and Search are
  *divertable* in Solaar: diverted, the key goes to Solaar instead (nothing
  reaches sway, so Fn+F6 no longer sends Super+H), and a Solaar rule can act
  on it. Solaar warns that its rules cannot see modifier state on Wayland;
  the rules below do not need it.

### Solaar rules on motoko (since 2026-11-03)

| Key | Action |
| --- | ------ |
| Fn+F9 | `mic-mute-toggle`: `wpctl` mute toggle of the default mic, plus an OSD |
| Fn+F4 | `voice-note toggle` |
| Fn+F5 | `voice-note start` on press, `voice-note stop` on release |
| Fn+F6 | `tts-speak toggle` (read the selection aloud; was AltGr-F9) |
| Fn+F7 | `tts-speak toggle --clipboard` (the same, clipboard first: "copy as markdown", chat "Copy" buttons) |

- `swayosd-client --input-volume mute-toggle` (swayosd 0.3.0) changed nothing
  for the default mic (bluetooth headset) while `wpctl set-mute` did, hence
  the small `bin/mic-mute-toggle`.
- The state is shown by the waybar `custom/mic` widget (`bin/audio-status in`).
- Rules: `home/.config/solaar/rules.yaml`, linked by `dotfiles-link`. Solaar's
  `Execute` takes an argv list, no shell, and `~/bin` is on its PATH.
- Diversion: `setup/modules/38-solaar.sh` (`solaar config … divert-keys`).
  It is a device setting kept in `~/.config/solaar/config.yaml`, which holds
  the serial and is rewritten by Solaar, so it is not a repo file. The module
  is motoko-only; without diversion the rules never fire.
- Diversion is HID++ state held by Solaar on this host, not stored in the
  keyboard, so the keyboard on another host (the Windows work laptop) still
  gets its stock Fn behaviour. Not verified on Windows yet.
- The two "Built-in rules" the GUI shows (Brightness Down/Up → XF86 keys) are
  Solaar's own defaults, for other keys than Backlight; nothing of ours.
- **Gotcha:** run the module with Solaar *quit* (`pkill solaar`, module,
  `solaar -w hide`). A CLI call next to a running tray instance cut
  `config.yaml` from 4160 to 354 bytes once (mouse settings and keyboard
  backlight config lost; restored by hand). The module refuses while Solaar
  runs. Cause (two writers) is unconfirmed.
- Saving rules from the Solaar GUI rewrites the file and will drop its
  comments (and may replace the symlink; untested). Edit the YAML directly.
- Keys of puppet's notebook keyboard are unrelated; vocalinux is not set up
  there.
