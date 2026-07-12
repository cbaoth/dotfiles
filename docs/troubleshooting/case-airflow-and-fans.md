---
title: Case airflow & fan control — Define 7 (motoko)
hosts: [motoko]
status: open
tags: [thermals, fans, pwm, hwmon, fractal, noctua, nct6775]
updated: 2026-07-13
---

# Case airflow & fan control

**Status: open — planned project, not yet started.** Findings and a plan; nothing
has been changed yet.

## ⚠️ Read this before spending any money: the room is 30 °C

**Ambient in this room runs 28.5–31.5 °C** during summer (insulated room, PC on all
day, little air circulation even with the balcony open).

**Every thermal benchmark, review, and "is 70 °C normal?" forum answer assumes
~21–22 °C ambient.** At 30 °C, *everything* reads ~8 °C hotter than the numbers
being quoted at you — while being completely fine.

> **The honest metric is delta-over-ambient, not the absolute number.**

| | Measured @30 °C | Normalised to 22 °C |
| --- | --- | --- |
| CCD idle | 49–52 °C | **~41–44 °C** |
| BIOS idle | >60 °C | ~52 °C |

~20 °C over ambient at idle on a 9950X3D is *good*. There may be **no thermal
problem here at all — just a hot room.**

`bin/hw-watch --ambient 30` does this normalisation automatically and prints a
verdict. **Measure under load with it before buying anything**, or you risk fixing a
room with case parts.

**And the real fix:** the preferred room temperature is 18–21 °C, and it currently
sits at ~30 °C. Whatever cools the *room* fixes the PC *and* the human. That is a
better investment than case fans, and it is the actual root cause.

## The measurement that matters

> **Opening the case drops CPU temperature.**

That is a direct measurement that **the case is a bottleneck, not the cooler**. An
NH-D15 G2 is a huge air cooler; if it is heat-soaking, it is recirculating warm air,
not undersized. No amount of fan-curve tuning fixes a case that cannot exchange air.

But note the delta was only "a few degrees" — so the case is *a* constraint, not
necessarily a *severe* one. Quantify it under load before acting.

### Don't panic on the BIOS number

BIOS reported >60 °C at idle — but **BIOS idle temps read high by nature**: no
C-states, no idle clocks, the CPU sits at fixed boost. Desktop idle:

```
Tctl:  62.1 °C     <- a CONTROL value, includes an offset. NOT the die temp.
Tccd1: 49.1 °C     <- actual die
Tccd2: 51.6 °C     <- actual die
```

**Quote `Tccd`, not `Tctl`.** Tctl is what fan curves consume; it is not what the
silicon is at.

## Blocker: Linux cannot see or control any fan

```bash
ls /sys/class/hwmon/hwmon*/fan*_input   # nothing
ls /sys/class/hwmon/hwmon*/pwm*         # nothing
```

**Zero fan RPM sensors, zero PWM controls.** The board's Nuvoton SuperIO chip is not
being driven — only `k10temp`, `nvme`, `drivetemp`, `spd5118` and the NIC sensors
show up.

This **blocks the "use software instead of BIOS fan curves" idea entirely.** Software
fan control is not currently possible; all control is BIOS-only.

`nct6775` and `nct6683` are available but not loaded (`nct6687` — the one usually
needed for recent MSI boards — is not packaged and would need the out-of-tree
[nct6687d](https://github.com/Fred78290/nct6687d) DKMS module).

**First step, and it is free:** try to get the SuperIO chip recognised.

```bash
sudo modprobe nct6775 force_id=0xd428     # try; the right force_id varies by board
sensors-detect                            # will ask about SuperIO probing
sensors                                   # look for fan RPMs appearing
```

Until this works, everything below is BIOS-only.

## Why the fans are invisible: they are not PWM

The **Fractal Define 7 stock fans are Dynamic X2 GP-14 — 3-pin DC, not 4-pin PWM.**
That is why they never appeared as PWM fans in BIOS. The observation was correct and
the conclusion follows: **they have to be replaced** for real fan control.

They are also routed through the case's built-in **Nexus+ fan hub** (the little
multi-fan pin board with a single cable to the motherboard), which further hides
individual fans from the board.

## The elephant: it is a *silence* case with a *solid* top

The **Define 7 Black Solid** is a sound-dampened case. It deliberately trades airflow
for quiet: solid top panel, dense dust filters, foam lining.

That is a fine trade for an office box, and a questionable one for a 9950X3D + RTX
4070 Ti dumping 400–500 W into it.

**A mesh top panel may already be in the box** — the Define 7 ships with a swappable
top (the mesh one is nominally for top-mounted radiators, but it vents a *lot* better
than the solid plate). **Check the accessory box before buying anything.** Free, if
so.

Hot air rises, so a vented top plus top exhaust is the orthodox layout. (One
dissenting view online argues for pushing air *down* through the top; it is a small
minority and not worth chasing.)

The front is less of a worry than it looks: the Define 7's front intake draws through
**broad side slits**, and with front fans pushing, that is more effective than the
solid façade suggests. The likely best additions are a **bottom intake blowing past
the GPU** and **top exhaust** — the single 120 mm rear fan is doing very little on its
own.

## Plan

Ordered by value-per-euro. **Measure under load first** — do not buy on a hunch.

| # | Action | Cost |
| - | ------ | ---- |
| 0 | **Measure under load**: `hw-watch --ambient <room C>` during a game and an AI run | free |
| 1 | **Remove the Noctua Low-Noise Adapter** from the CPU fans (see below) | free |
| 2 | Get `nct6775`/`nct6687d` working → fan RPM + PWM visible to Linux | free |
| 3 | **Cool the room** — the actual root cause; see [Room cooling](#room-cooling-the-real-fix) | €€–€€€ |
| 4 | **Mesh top panel** (already owned? check the bundle) | free–€ |
| 5 | Replace the 3 stock 3-pin fans with **PWM** fans | €€ |
| 6 | Bottom intake past the GPU + top exhaust | € |

Step 0 gates everything below it. If `hw-watch` says *"[THERMAL] Fine. Nothing is
close to throttling"* under a real gaming and AI load, then **the correct action is
to buy nothing** and accept slightly higher fan noise.

### 1. Remove the Low-Noise Adapter — free, do it first

The NH-D15 G2 ships with a **Y-splitter** (for its two fans) and **Low-Noise
Adapters** (LNA — an in-line resistor that caps maximum RPM).

- **The Y-splitter is correct and intended.** Noctua supplies it precisely so both
  cooler fans run from `CPU_FAN`. The board reads RPM from one fan only, which is
  normal. Keep it.
- **The LNA is not.** It is a *permanent cap on your cooling headroom*, traded for
  quiet — and you wear a noise-cancelling headset. If an LNA is fitted, **remove
  it.** Free performance, zero downside in this specific case.

### 4. Fan choice — one correction to the plan

> *"pwm and never pressure (unless specifically required, which it shouldn't in my
> case)"*

The instinct is right in general — high-static-pressure fans are for radiators — but
**it is wrong for a Define 7 specifically.** A solid front panel plus thick dust
filters *is* a restriction. You are pushing air through resistance, so static
pressure matters here more than it would in a mesh case.

**Noctua NF-A14 PWM** (140 mm) is the right default: a genuine airflow/pressure
all-rounder, not a specialist at either end. `NF-A12x25 PWM` for any 120 mm slots.
The `chromax.black` variants are identical mechanically if the beige is offensive.

Avoid `industrialPPC` — it is a high-pressure fan and it is loud.

### PWM splitters

Fine for **identical case fans** run from one header — that is exactly what they are
for, and it is what the case's Nexus+ hub already does. Keep total fan current within
the header's rating (usually 1 A).

The advice you saw about "don't use a splitter for the CPU cooler" is over-cautious:
Noctua's own bundled Y-cable is a splitter, and it is the intended configuration.

### Layout

Positive pressure (slightly more intake than exhaust) keeps dust out of a filtered
case. Roughly: **front intake ×2–3 (140 mm), rear exhaust ×1, top exhaust.**

## Room cooling — the real fix

Everything above moves heat from the CPU into *the room*. **None of it removes heat
from the room.** At ~30 °C ambient in a room that should be 18–21 °C, the case is
downstream of the actual problem — and the room is also where the human sits.

Worth being blunt about the load: this PC dumps **400–500 W** into the room under
gaming/AI load, the work notebook adds more during home office, and the room is
insulated with poor air exchange even with the balcony open. That is a small
electric radiator running all day.

*(Minor but real: the 250 W GPU cap is also a ~35 W reduction in room heating.
Undervolting/capping is a cooling measure as well as a stability one.)*

### Options

| Option | Verdict |
| ------ | ------- |
| **Dual-hose portable AC** (Monoblock, 2 Schläuche) | **The pragmatic choice.** No installation, no landlord permission, movable. Buy this if buying portable. |
| **Single-hose portable AC** | ❌ **The common purchase and the worst value.** It exhausts *room* air outdoors, creating negative pressure that pulls hot air in through every gap in the flat. Effective capacity is roughly halved. Cheap, popular, and a trap. |
| **Split AC** (indoor + outdoor unit) | Best efficiency and by far the quietest — the compressor is outside. But it needs installation, an outdoor unit, and **landlord permission** in a rented flat. |
| **Monoblock with wall cores** (no outdoor unit) | Middle ground: fixed install, two small wall penetrations, no outdoor unit. Still needs permission, but far less visually intrusive than a split. |
| **Evaporative cooler / "air cooler"** | ❌ Adds humidity and does very little in humid European summers. Not a real option. |
| Free measures | Night purge (cross-ventilate when it is cooler outside), blackout the window during the day, and *do not* run heavy AI workloads at peak heat. |

### If buying portable

- **Dual-hose, not single-hose.** This is the single most important choice.
- A proper **window seal** (Fensterabdichtung) is essential — without it the hot
  exhaust air just comes straight back in.
- **They are loud.** The compressor is in the room with you. Less of an issue behind
  a noise-cancelling headset, but it is not a quiet-PC-friendly device.
- Size it for the room's volume *plus* the ~500 W of PC. Standard room-size
  calculators assume no space heater in the corner.

## Reference

- [Fractal Define 7 airflow guide (hardware-helden.de, DE)](https://hardware-helden.de/fractal-define-7-airflow-guide-das-optimale-lueftersetup/)
- [r/FractalDesign discussion](https://www.reddit.com/r/FractalDesign/comments/11pz9h4/advice_for_optimal_fan_configuration_for/)

## Not the cause of the GPU crashes

Thermals are **not** implicated in
[Xid 79](gpu-xid79-bus-fall-off.md) — temps were fine right up to each crash, and the
fan ramp to 100 % is a *symptom* of the card falling off the bus (the fan controller
loses its curve and fails safe), not a cause. Separate project, do not conflate.

Worth noting anyway: the 2.5 GbE NIC idles at ~51 °C against a 55 °C high threshold —
another quiet sign that case airflow is marginal.
