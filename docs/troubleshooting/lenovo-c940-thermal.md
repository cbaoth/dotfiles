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
PL1           27 W  (performance; 11 W for balanced/power-saver)
PL2           44 W  (performance; 25 W otherwise)
```

Package temperature pinned at the ceiling with the throttle counter climbing
continuously is the signature. For comparison, on AC afterwards: **77-93 °C with
the throttle counter essentially static** (2,597 events in 14 min of uptime).

## Root cause

A USB-C charger that had come unplugged unnoticed, plus:

- `performance` more than doubles sustained power on a 15 W-class i7-1065G7:
  **PL1 27 W / PL2 44 W**, against 11 W / 25 W for balanced and power-saver.
- On battery the EC runs a **conservative fan curve** regardless of the profile.

> **Read those limits from `intel-rapl-mmio:0`, not `intel-rapl:0`.** The MSR
> domain reports a meaningless 200 W here and never changes with the profile;
> the MMIO domain is the one DYTC actually drives. This was originally recorded
> wrong in this note — corrected 2026-09-03. Note also its **~28 s PL1 averaging
> window**: a profile change takes that long to show as a temperature change,
> which is long enough to make you think the switch did nothing.

Raised power against a quiet fan curve = the CPU turbos into a thermal wall
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

## Second incident, 2026-09-03: sleep/resume confirmed

The first time round this was dismissed — the battery fan curve explained every
symptom, so no resume bug was needed. **That dismissal was wrong**, and the
retest above is what caught it. Second occurrence, this time unambiguous:

```
Sep 03 19:56:06  PM: suspend entry (s2idle)
Sep 03 21:52:07  PM: suspend exit          <-- heat starts here
```

**On AC**, charger connected, package pinned at 94-98 °C. The decisive test: cap
sustained power to 12 W (`balanced`) and wait.

```
22:30:27  pkg=94C  SEN2=77C  SEN4=80C
22:31:22  pkg=97C  SEN2=76C  SEN4=80C   throttle +17,896 in 90 s
```

**Sixty seconds at 12 W and not one degree of movement.** A 15 W-class chip
capped at 12 W that cannot get below 94 °C is not being cooled at all; the
chassis is the only heatsink left, which is why the palmrest reached 80 °C and
was painful to touch. There is still no RPM reading to confirm it directly, but
thermally this is not ambiguous.

So: an s2idle resume can leave the EC's fan control stopped, and no reboot means
it stays stopped. Only a reboot has ever recovered it.

### Mitigation while the fan is dead

The ArchWiki config in the next section is the *only* thing that helps without
rebooting: it cannot spin the fan, it just stops feeding the chip heat, holding
~80 °C instead of 95 °C. Slow but touchable beats fast and painful.

### Candidate fix at source: use S3 instead of s2idle

`cat /sys/power/mem_sleep` reports `[s2idle] deep` — S3 is supported and simply
not the default. `mem_sleep_default=deep` powers the EC down and back up
properly instead of the half-awake S0ix state that wedges it. **Untested as of
writing.** Test with nothing unsaved: S3 is occasionally flaky on machines
tuned for modern standby, and the failure mode is not resuming at all.

## The ArchWiki page for this model is worth reading

<https://wiki.archlinux.org/title/Lenovo_Yoga_C940> (direct fetching is blocked
by Anubis; paste the page source if an agent needs it). Independent confirmation
and one genuinely useful config:

> **"Manual fan control does not work at all."**

It carries a `thermal-conf.xml` written for `<ProductName>81Q9</ProductName>` —
this exact machine — setting **passive trip points at 80 °C** on `SEN2` and
`x86_pkg_temp`, plus a service change to drop `--adaptive` and add
`--ignore-default-control`. Deployed by the script referenced below.

One caveat found on deployment: the wiki's first trip point names `B0D4` as a
*cooling device*, but on kernel 6.17 B0D4 exists here only as a thermal *zone*
(the cooling devices are `Processor`, `intel_powerclamp`, `TCC Offset`,
`PCIe_Port_Link_Speed`), so it probably does not bind. The
`x86_pkg_temp -> Processor` point is the one doing the work. The wiki also
contradicts itself on the target temperature: the config says `80000`, the prose
says `64000`.

Other items from that page, for the record: battery `conservation_mode` caps
charging at 50 %; `intel_iommu=off` fixes shutdown hangs (not seen here); the
bass speakers need an unreleased beta BIOS and are explicitly broken on
**AUCN61WW**, which is what this machine runs — not pursued, the beta BIOS
carries a brick warning and this machine is used with Bluetooth headphones. Its
tablet-mode section is out of date: it recommends an AUR DKMS driver, but
mainline `lenovo_ymc` handles it.

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
