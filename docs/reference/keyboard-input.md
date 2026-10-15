---
title: Keyboard input debugging (evtest, wev) and special keys
hosts: [all]
status: resolved
tags: [keyboard, evtest, wev, evdev, sway, logitech, solaar, scancode]
updated: 2026-10-15
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
| Fn+F4 / Fn+F5 | Backlight Down / Up | nothing (firmware) | — |
| Fn+F6 | Dictation | Super+H | `$mod+h` = `layout splith` |
| Fn+F7 | Emoji | Super+Ctrl+Alt+Shift+Space | unbound |
| Fn+F8 | Screen Capture | Super+Shift+S | `$mod+Shift+s` = `layout stacking` |
| Fn+F9 | Mute Microphone | nothing on any device | — |
| Fn+F10 | Search | `KEY_SEARCH` (scan `c0221`, Consumer Control) | unbound |
| Fn+F11… | Play/Pause, Mute, Volume | media keys on Consumer Control, e.g. `KEY_PLAYPAUSE` (scan `c00cd`) | `XF86Audio*` bindings |

- The keys that send nothing (Backlight, Mute Microphone) are handled in the
  keyboard firmware / over HID++.
- Backlight, Dictation, Emoji, Screen Capture, Mute Microphone and Search are
  *divertable* in Solaar: diverted, the key goes to Solaar instead, and a
  Solaar rule can act on it, e.g. type an unused key through Solaar's own
  virtual keyboard. Not tried. Solaar warns that its rules cannot see
  modifier state on Wayland.
