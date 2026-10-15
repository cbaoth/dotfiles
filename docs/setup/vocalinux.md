---
title: Vocalinux voice dictation (and voice-note)
hosts: [motoko]
status: resolved
tags: [vocalinux, whisper, dictation, voice-note, sway, wayland, evdev, push-to-talk]
updated: 2026-10-15
automated_by: setup/modules/33-vocalinux.sh
---

# Vocalinux voice dictation

**Automated:** `system-setup 33-vocalinux` (desktop profile).

Vocalinux (<https://github.com/VocaHQ/vocalinux>) types dictated text into the
focused window. Here: whisper.cpp engine, `small` model, Vulkan on the RTX
4070 Ti, push-to-talk on **Right Ctrl** (hold to talk). The tray icon is red
while it records.

`bin/voice-note` is a separate tool that only borrows Vocalinux's whisper.cpp
binary (`pwcpp`) and model. It records with `pw-record` and appends the
transcript to the notes inbox. It does not use the Vocalinux app, which is why
the tray icon stays black during a voice note.

## Install and update

The upstream installer is the recommended channel. It installs per user into
`~/.local/share/vocalinux` (venv, models) and `~/.local/bin/vocalinux`, keeps
`~/.config/vocalinux/config.json` across reinstalls, and calls `sudo apt` itself
for missing dependencies. It refuses to run as root.

```bash
system-setup 33-vocalinux                         # install if missing (no-op otherwise)
VOCALINUX_UPDATE=1 system-setup 33-vocalinux      # update to the latest release
VOCALINUX_TAG=v0.18.2 system-setup 33-vocalinux   # pin / roll back to a release
```

- The module runs the installer from the release tag with `--auto`. The
  installer stops a running Vocalinux; the module restarts it through
  `swaymsg exec` so its log keeps going to `~/.local/state/sway/session.log`.
- Before an update it copies `config.json` to `config.json.bak-<old version>`.
- Autostart is the sway config, not the app's own option:
  `exec sway-run-after-waybar vocalinux` in `90-launch-apps.conf`.
- Since v0.18 the GUI process is `python .../venv/bin/vocalinux-gui`
  (process name `vocalinux-gui`), so `pgrep -x vocalinux` / `pkill -x
  vocalinux` find nothing. Match the venv path instead:
  `pkill -f /vocalinux/venv/bin/vocalinux`.

## Logs

Vocalinux has no log file of its own (`~/.local/share/vocalinux/logs/` stays
empty). Its stdout/stderr goes to the sway session log:

```bash
grep vocalinux ~/.local/state/sway/session.log | grep -v 'Using \|Audio recording'
```

Look for `Starting speech recognition` / `Stopping speech recognition` pairs. Two
`Starting` lines without a `Stopping` between them mean two parallel recordings.

## Settings worth knowing

- **Unload model when idle** (`model_keepalive` in `config.json`): unloads the
  model after the idle timeout and reloads it on the next press. Meant for
  hybrid-GPU laptops (frees VRAM). On motoko it buys nothing and widened the
  push-to-talk race in v0.17.0 (see the troubleshooting note), so it stays
  **off** here. Upstream default is off.
- Push-to-talk vs. toggle: the configured shortcut string is
  `right_ctrl+right_ctrl`. That is the double-tap gesture, but with
  `"mode": "push_to_talk"` the backend only watches hold/release of the
  modifier. There is no hidden toggle in push-to-talk mode.
- There is no maximum recording length. Upstream turned down an auto-stop
  timeout (issue #185) in favour of push-to-talk.
- **External activation (desktop shortcut)** (`shortcuts.disable_internal_hotkey`):
  Vocalinux stops reading `/dev/input` (no grab, no key logging) and is
  driven by `vocalinux --start|--stop|--toggle` from a compositor binding.
- **AltGr+F7** (sway, `40-keybindings.conf`) runs `vocalinux --toggle`, next
  to the internal Right Ctrl push-to-talk, to compare toggle against
  push-to-talk (2026-10-15). The D-Bus round trip takes about 60 ms. A
  D-Bus start uses the normal mode, not push-to-talk: per the source it
  transcribes at pauses (silence detection) instead of all at release. If the
  binding wins, enable external activation, which also ends the keyboard
  grab.

## Typing into terminals (foot)

Dictated text is pasted: clipboard, then a paste chord through wtype. For a
terminal it sends Ctrl+Shift+V, otherwise Ctrl+V (`paste_shortcut: auto`). It
finds the focused window via `swaymsg -t get_tree` (foot is matched by its
process name, even with the `swayfloat` app_id).

That needs `SWAYSOCK`. An instance started from a launcher runs under
`systemd --user`, which did not have it, so `swaymsg` failed, every window
counted as a non-terminal, and foot ignored the Ctrl+V (2026-10-15, after
the upgrade). Ctrl+Shift+V by hand still pasted the text from the clipboard.
Fix: `SWAYSOCK` is now in the `dbus-update-activation-environment --systemd`
line of `90-launch-apps.conf`. The autostarted instance (`swaymsg exec`) had
it all along.

## Since v0.18: the keyboard is grabbed

When `/dev/uinput` is writable (it is for this user), the evdev backend grabs
each keyboard (`EVIOCGRAB`) and re-emits its events through a uinput clone.
For a pure-modifier shortcut, every press of that modifier is consumed by
Vocalinux, but a press followed by another key is replayed, so Right Ctrl+C
still reaches the app as Ctrl+C. Consequences:

- sway sees the clone, not the physical keyboard. Only `input "type:keyboard"`
  rules are used here, so they still apply.
- If Vocalinux hangs (not crashes) while grabbing, keyboard input should stop
  (inferred from the grab mechanism, not observed). A crash releases the grab
  (the kernel drops it with the fd), a hang does not;
  `pkill -f /vocalinux/venv/bin/vocalinux` from another input path (ssh,
  mouse + terminal) recovers.
- Verified on v0.18.2 (2026-10-15): hold Right Ctrl records, release stops,
  Right Ctrl+C still copies.
- Every Right Ctrl press opens the microphone, also as part of Right Ctrl+C.
  With Bluetooth headphones that switches them to the headset profile, and
  the media player pauses and does not resume. Vocalinux has no media-pause
  feature: *Pause for listed apps* (`auto_pause`) only unloads the model
  while a listed process (e.g. steam) runs. So the pause most likely comes
  from the profile switch (not confirmed). Reason enough to consider a
  different push-to-talk key than a modifier in daily use.
- While dictating, the headphone output already drops to 0 % and comes back
  afterwards, without any Vocalinux setting (cause unconfirmed; the headset
  profile switch would fit). *Lower other audio while dictating*
  (`playback_duck`) on top of that left the volume far too low after
  dictation, so it stays **off** (the default). 0 % is the better behaviour
  anyway: no distraction on headphones, no feedback into the mic on speakers.
- `input-keyboards debug` (bin/) stops Vocalinux while it watches, because
  the grab hides the keyboard from evtest, and starts it again on exit.
- v0.18.x regressions upstream: #915, #946 (closed), #953 (open: keyboard
  nodes that also report pointer axes are skipped). The Logitech USB Receiver
  keyboard here has no pointer axes, so #953 does not apply.

## Lock and suspend

- **Suspend:** Vocalinux stops an active recognition itself on logind's
  `PrepareForSleep` (`suspend_handler.py`, present since at least v0.17.0).
- **Lock:** not handled by the app. Push-to-talk records only while the key is
  held, so nothing is needed once the race fix (v0.18.0) is in.
- **voice-note:** `bin/sway-lock` runs `voice-note stop` (detached) before
  swaylock. Every lock goes through `sway-lock` (keybindings, the 15 min
  swayidle timeout, and swayidle `before-sleep`), so a running voice-note
  toggle recording is saved and ended on any lock or suspend. Its own 10 min
  guard (`VOICE_NOTE_MAX_SECONDS`) also ends and saves a forgotten recording.

## CPU-only notebook

The same module works: the installer detects no usable GPU and builds
whisper.cpp for CPU. Choose a small model in Settings (`tiny` or `base`;
`small` is slow on an older CPU). `voice-note` defaults to
`ggml-small.bin`; on such a host point it at the model that exists, e.g.
`VOICE_NOTE_MODEL=~/.local/share/vocalinux/models/whispercpp/ggml-base.bin`.
Not tried yet.
