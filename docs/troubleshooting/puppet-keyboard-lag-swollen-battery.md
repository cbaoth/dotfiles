---
title: puppet — laggy internal keyboard, swollen battery, USB-C charger interaction
hosts: [puppet]
status: open
tags: [keyboard, battery, hardware, usb-c, power, ec]
updated: 2026-11-08
revisit: after the battery replacement
---

# puppet: internal keyboard drops/repeats keys, swollen battery

**Open** until the battery is replaced. Journal of 2026-11-07, dead ends included.

## Symptom

After a reboot into a new kernel (7.3.0-10) the internal keyboard (PS/2 on the
i8042 controller) dropped, delayed and repeated keys. It also happened in the
TTY and at the LUKS password prompt before the system was up. A Bluetooth
keyboard, touchpad and mouse were fine.

## What was ruled out

- **Kernel regression:** the old kernel (7.3.0-9) behaved the same.
- **Software / sway / libinput:** TTY and the LUKS prompt are affected too.
- **Kernel messages:** no `atkbd` / `i8042` errors in the journal, no IRQ
  storm while idle, no thermal throttling. The only input noise
  (`i2c_hid ... incorrect report` for the Wacom touchscreen) also appears on
  older boots.

## Findings

- **Battery is swollen:** keyboard deck and bottom plate bulge; the bottom plate
  lifts about 10 cm along the side of the power port, leaving a 2–3 mm gap. No
  smell. Health ~75% (`energy_full` 44.9 Wh vs 60 Wh design), "Not charging"
  while on AC. The laptop had been on USB-C power for months to years, ran hot,
  and was often closed while still warm under blankets.
- **Charger interaction (reproducible):** the notebook was on one port of a
  multi-port USB / USB-C charger. Plugging a small **charging cradle (no
  device in it)** into another port of the same charger brought the keyboard
  problem back within seconds; unplugging it fixed it immediately. Confirmed
  several times. Likely cause (unverified): the charger renegotiates or
  shares output between ports, and the embedded controller (EC) that runs the
  keyboard matrix is sensitive to the power change. The swollen battery may
  make it worse.
- A full power-off with the power cable unplugged briefly cured the problem
  once (EC reset), then it returned.
- Switching the power profile from performance to balanced/power-saver and
  running unplugged made the keyboard usable as well (less heat and load).

## Actions

- Unplugged, backed up `$HOME` to the NFS share (19 GB, resumable rsync; the
  CIFS mount could not store symlinks, NFS does), shut down.
- Battery replacement planned. Do not charge the swollen battery in the
  meantime.

## To verify after the new battery

- Repeat the cradle test deliberately: if the keyboard problem returns with a
  healthy battery, the charger is the cause; stop sharing it with other
  devices (or use the original charger).
- Add a battery indicator (waybar, zsh): see `docs/TODO.md`.
