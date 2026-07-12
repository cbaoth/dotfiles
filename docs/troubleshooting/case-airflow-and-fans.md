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

## The measurement that matters

> **Opening the case drops CPU temperature.**

That is a direct measurement that **the case is the bottleneck, not the cooler**.
An NH-D15 G2 is a huge air cooler; if it is heat-soaking, it is because it is
recirculating warm air rather than because it is undersized. No amount of fan-curve
tuning fixes a case that cannot exchange air.

### Don't panic on the BIOS number

BIOS reported >60 °C at idle — but **BIOS idle temps read high by nature**: no
C-states, no idle clocks, the CPU sits at fixed boost.

On the desktop the honest numbers are:

```
Tctl:  62.1 °C     <- a CONTROL value, includes an offset. Not the die temp.
Tccd1: 49.1 °C     <- actual die
Tccd2: 51.6 °C     <- actual die
```

~50 °C idle on the CCDs of a 9950X3D is warm but not alarming. **The load numbers
are what matter**, and they have not been measured yet. Do that before buying
anything.

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

## The elephant: it is a *silence* case with a *solid* front

The **Define 7 Black Solid** is a sound-dampened case. It deliberately trades airflow
for quiet: solid front panel, dense dust filters, foam lining.

That is a fine trade for an office box. It is a **bad trade for a 9950X3D + RTX 4070
Ti**, which together dump 400–500 W into that sealed box under load.

**Check whether a mesh front panel is available for the Define 7.** Swapping the
front is likely to be the single biggest thermal win available, and it is cheaper
than a set of fans.

## Plan

Ordered by value-per-euro. **Measure under load first** — do not buy on a hunch.

| # | Action | Cost |
| - | ------ | ---- |
| 0 | **Measure under load** (game + AI run): `gpu-watch` for the GPU, `watch -n2 sensors` for CPU/CCD | free |
| 1 | **Remove the Noctua Low-Noise Adapter** from the CPU fans (see below) | free |
| 2 | Get `nct6775`/`nct6687d` working → fan RPM + PWM visible to Linux | free |
| 3 | **Mesh front panel** (if available for the Define 7) | € |
| 4 | Replace the 3 stock 3-pin fans with **PWM** fans | €€ |
| 5 | Add top exhaust / bottom intake | € |

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
