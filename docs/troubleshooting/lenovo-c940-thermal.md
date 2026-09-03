---
title: Overheating on battery & the search for fan control — Yoga C940 (puppet)
hosts: [puppet]
status: resolved
tags: [thermals, fans, power-profiles, dytc, ideapad, lenovo, acpi]
updated: 2026-09-03
automated_by: bin/power-profile-guard
---

# Overheating on battery & the search for fan control

**Status: resolved.** The overheating had a boring cause (the charger was
unplugged). The interesting content is everything that turned out *not* to be
available: this machine exposes **no fan control to Linux whatsoever**, and two
plausible-looking knobs are dead ends. Don't re-run those experiments.

## Symptom

Laptop very hot to the touch, no audible fan, `performance` profile selected via
the waybar power-profiles widget. Suspicion was that the widget had been built
without considering cooling.

## Measured state at the time

On battery, load average ~0.9 (browser + a couple of apps — *not* a heavy job):

```
pkg temp      94-98 °C sustained
throttling    +9,300 events in 50 s (~186/s, continuous)
SEN2          72 -> 76 °C, climbing across the sample
power         Mains online=0   <-- the actual cause
PL1           200 W (uncapped by the performance profile)
PL2           51 W
```

Package temperature pinned at the ceiling with the throttle counter climbing
continuously is the signature. For comparison, on AC afterwards: **77-93 °C with
the throttle counter essentially static** (2,597 events in 14 min of uptime).

## Root cause

A USB-C charger that had come unplugged unnoticed, plus:

- `performance` lifts PL1 to **200 W** — effectively uncapped on a 15 W-class
  i7-1065G7.
- On battery the EC runs a **conservative fan curve** regardless of the profile.

Uncapped power against a quiet fan curve = the CPU turbos into a thermal wall
and stays there. Note the counterintuitive consequence:

> **On battery, `performance` makes the machine slower.** It spends all its time
> in thermal throttle instead of at a sustainable clock. It is not a
> "performance, but hot" trade — it is worse on both axes.

The 96 °C was not dangerous in itself; the throttling *is* the CPU protecting
itself. `TCC`/`crit` are both 100 °C.

## Dead end 1: `fan_mode` is inert

`ideapad_laptop` exposes `/sys/bus/platform/devices/VPC2004:00/fan_mode`, and the
kernel ABI documents `0 = Super Silent, 1 = Standard, 2 = Dust Cleaning,
4 = Efficient Thermal Dissipation`. It looks exactly like the missing knob. It is
not.

```console
$ sudo sh -c 'echo 3 > .../fan_mode'   # documented-invalid value
sh: echo: I/O error                    # -> rejected, so the write path is live
$ sudo sh -c 'echo 4 > .../fan_mode'   # documented-valid value
$ cat .../fan_mode
0                                      # -> accepted, value never changes
```

The decisive evidence is not the write, though — it is that **`fan_mode` read `0`
in two completely different physical states**: barely-turning fan at 96 °C on
battery, *and* audibly running fan at 85 °C on AC. A register that never changes
across those two is not reporting the fan.

Thermal control on the C940 is **DYTC**, which is what `platform_profile` /
power-profiles-daemon already drives. The legacy `fan_mode` attribute is created
for every `VPC2004` device whether or not the EC implements the old VPC fan
command.

Loose end, recorded for honesty: writing the invalid value returned `EIO`
("I/O error"), not the `EINVAL` a simple driver-side range check would give. So
the EC may be seeing these commands and merely refusing to report state back —
meaning `4` *might* do something invisible. Distinguishing that needs a thermal
A/B under sustained load (steady-state temp with `fan_mode=0` vs `4`), because
the readback is worthless. Not considered worth the effort once the charger was
found.

## Dead end 2: `think_lmi` has no thermal attributes

`think_lmi` is loaded and exposes Lenovo BIOS settings at
`/sys/class/firmware-attributes/thinklmi/attributes/`. All 26 attributes were
checked: `AlwaysOnUSB`, `BIOSBackFlash`, `Bluetooth`, `ChargeInBatteryMode`,
`EFI-BootOrder`, `HotkeyMode`, `SecureBoot`, `USBBoot`, hyper-threading,
virtualisation, and assorted device enable/disable toggles. **Nothing thermal,
nothing fan-related.** No BIOS-level fan knob is reachable from Linux.

## There is no fan interface at all

Worth stating plainly, because it is the thing that makes all of the above
inevitable:

```console
$ find /sys -name 'fan*_input'   # nothing
$ find /sys -name 'pwm[0-9]'     # nothing
$ ls /sys/bus/acpi/devices/ | grep -E 'INT3404|PNP0C0B'   # nothing
```

`lm-sensors` does not help either — installing it was harmless but it reports
only `coretemp`, `acpitz`, `nvme`, `BAT1` and `iwlwifi`. **There is no fan RPM
reading on this machine**, so "is the fan running?" can only ever be answered
acoustically or inferred from whether temperature is being carried away.

The EC owns the fan completely. `platform_profile` is the only lever, and it
works indirectly: you get a quiet fan by capping power so the EC never needs to
spin up, not by commanding the fan.

## What was actually changed

Nothing about the fan — there was nothing to change. The gap was that
`performance` + unplugged charger produced no warning at all:

- **`bin/power-profile-guard`** (`watch`) — demotes `performance` -> `balanced`
  when the charger is unplugged and restores it on replug, with a desktop
  notification. Acts on the **AC transition**, so deliberately selecting
  `performance` while already on battery is left alone. Restores only if the
  profile is still `balanced`, so a manual choice made on battery is never
  overridden. State lives in `$XDG_RUNTIME_DIR` and is cleared on logout.
- **`power-profile-guard.service`** (systemd user unit) — started from the sway
  config rather than `enable`d, so it inherits the session bus for
  notifications.
- **`custom/power-warn`** waybar module — a standing amber warning for
  `performance`-on-battery, hidden entirely otherwise. Covers the case the guard
  deliberately does not touch.

## Sleep/resume: ruled out, not proven innocent

The initial hypothesis was that suspend/resume had left the fan stopped. Set
aside: the battery fan curve explains every symptom on its own, so there is no
residual behaviour for a resume bug to account for. It was never properly
isolated, though — the reboot and the replug happened at roughly the same time,
so the two variables are confounded.

If it ever recurs **on AC**: suspend/resume, load the CPU, and watch
`/sys/devices/system/cpu/cpu0/thermal_throttle/package_throttle_count`. If it
stays near-static, resume is fine.

## Useful one-liners

```bash
power-profile-guard status      # profile, charger, whether the guard demoted
powerprofilesctl get            # current profile
cat /sys/class/power_supply/ADP1/online                     # 1 = on AC
cat /sys/devices/system/cpu/cpu0/thermal_throttle/package_throttle_count
for z in /sys/class/thermal/thermal_zone*; do \
  printf '%-22s %s\n' "$(cat "$z/type")" "$(( $(cat "$z/temp") / 1000 ))"; done
```

The throttle counter is the honest health metric — a high absolute temperature
with a static counter is fine; a climbing counter is not.
