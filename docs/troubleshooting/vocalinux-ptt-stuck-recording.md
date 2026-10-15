---
title: Vocalinux push-to-talk keeps recording after the key is released
hosts: [motoko]
status: workaround
revisit: 2026-11
tags: [vocalinux, push-to-talk, race-condition, evdev, whisper, sway, swaylock, bluetooth]
updated: 2026-10-15
automated_by: setup/modules/33-vocalinux.sh
---

# Vocalinux push-to-talk keeps recording after the key is released

**Verdict: workaround → fixed upstream.** A race in v0.17.0 between the
push-to-talk press and release handlers. Fixed upstream in v0.18.0 (PR #880).
Until the update is verified here, the workaround is turning off *Unload model
when idle*, which removes the slow path the race needs. Set `status: resolved`
once v0.18.x has run for a while without a stuck recording.

Setup and update: [docs/setup/vocalinux.md](../setup/vocalinux.md).

## Symptoms

- Push-to-talk on Right Ctrl (hold to talk, `"mode": "push_to_talk"`). Usually
  correct, even for rapid taps: the tray icon goes red/black with each press.
- Occasionally recording keeps going with the key up. Noticed over several
  days by the Bluetooth headphones: an open microphone switches them to the
  headset profile, which makes a faint constant noise until recording stops.
- 2026-10-14: after unlocking the screen the tray icon was red. It had been
  recording for about 4 hours.
- Could not be reproduced on demand with the model loaded.

## Evidence (2026-10-14)

Vocalinux logs to the sway session log (`~/.local/state/sway/session.log`), not
to `~/.local/share/vocalinux/logs/`.

```
13:33:19  Speech model unloaded after idle keep-alive timeout
15:55:49,745  Model was unloaded by keep-alive; reloading before dictation
15:55:49,947  Model was unloaded by keep-alive; reloading before dictation
15:55:50,141  Starting speech recognition
15:55:50,511  Starting speech recognition
16:18:09  Device disconnected: Logitech USB Receiver ...   (keyboard gone)
19:50:56  Added 5 hotplugged keyboard device(s)            (back)
19:51:25  Stopping speech recognition
19:51:25  Audio recording stopped
19:51:25  Audio recording stopped
```

- Two Right Ctrl presses 200 ms apart, each starting a model reload.
- Two `Starting` lines with no `Stopping` between them: two recordings ran in
  parallel. The two `Audio recording stopped` lines at 19:51 confirm it.
- No `System preparing to suspend` line: no suspend involved.
- A failed swaylock password attempt is logged at 15:58:23, so the lock screen
  was probably up around the time of the presses. Why Right Ctrl was pressed
  is **unconfirmed** — pressing Ctrl to wake the screen would fit. Vocalinux
  reads `/dev/input` directly, so it sees keys pressed at the lock screen.

## Cause (read from the v0.17.0 source)

- `evdev_backend.py`: every press and every release of the modifier starts a
  **new thread** for the press or release callback.
- `tray_indicator.py`, no lock anywhere:

  ```python
  def _start_recognition(self):
      if self.speech_engine.state == RecognitionState.IDLE:
          self.speech_engine.start_recognition(mode="push_to_talk")

  def _stop_recognition(self):
      if self.speech_engine.state != RecognitionState.IDLE:
          self.speech_engine.stop_recognition()
  ```

- `start_recognition()` reloads an unloaded model **before** it switches state
  to LISTENING (about 0.4 s here). A release in that window sees IDLE and does
  nothing. Then the start completes and recording runs with the key already
  up. A second press in the window passes the IDLE check too, giving two
  parallel recordings.
- `model_keepalive` (Settings: *Unload model when idle*, 10 min here) is what
  makes the window long. With the model loaded the start is milliseconds, which
  is why rapid-tap tests did not reproduce it.

**Reproduce on 0.17.0:** leave Vocalinux unused longer than the idle timeout
(log line `Speech model unloaded`), then tap Right Ctrl quickly.

## Upstream

- v0.18.0, PR #880 (`fix PTT races`): press and release run under one
  `RLock`, and press holds it through the whole start. The release now waits
  and finds the session. The docstring describes exactly this bug.
- Issue #185 (auto-stop after inactivity) was closed in favour of push-to-talk,
  so there is no max-duration setting and none is needed once the race is
  fixed.
- New in v0.18: `vocalinux --start|--stop|--toggle` control a running
  instance over D-Bus.
- Side effect of v0.18: keyboards are grabbed via uinput clones; see the setup
  note.

## Ruled out

- **The sway voice-note hotkeys** (AltGr-F5 hold, AltGr-F6 toggle): `voice-note`
  does not go through the Vocalinux app; the tray icon stays black during a
  voice note.
- **A hidden toggle in push-to-talk mode**: the shortcut string
  `right_ctrl+right_ctrl` reads like the double-tap gesture, but in
  `push_to_talk` mode the backend only acts on hold/release.

## Changes made

- Workaround: *Unload model when idle* off (`model_keepalive.enabled: false`).
- `setup/modules/33-vocalinux.sh`: install/update via the upstream installer
  (`VOCALINUX_UPDATE=1`), so the update to v0.18.x is one command.
- Related hardening of `bin/voice-note` (it can also be left recording,
  by its toggle):
  - `bin/sway-lock` runs `voice-note stop` before swaylock, so any lock or
    suspend ends and saves a running voice-note.
  - The 10 min auto-stop guard used to kill `pw-record` only. The WAV was then
    never transcribed and the next `start` deleted it. It now runs a full
    `voice-note stop`.

## Update 2026-10-15: upgraded to v0.18.2

- `VOCALINUX_UPDATE=1 system-setup 33-vocalinux` installed v0.18.2 (config
  kept, backup `config.json.bak-0.17.0`). *Unload model when idle* is off.
- Push-to-talk works: hold records, release stops. Right Ctrl+C still copies.
- The module did not restart Vocalinux: its running check was
  `pgrep -x vocalinux`, but v0.18 runs as `vocalinux-gui`. Fixed (matches the
  venv path now).
- Follow-ups found after the upgrade (foot paste, Bluetooth profile switch
  on every Right Ctrl press): [setup note](../setup/vocalinux.md).
- Still `workaround`: set `resolved` if no stuck recording shows up by the
  revisit date.
