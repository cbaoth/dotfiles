---
title: Hard crash while gaming — Xid 79, GPU falls off the PCIe bus (motoko)
hosts: [motoko]
status: open
revisit: after the next gaming session with the 250 W cap active
tags: [nvidia, gpu, xid, power, pcie, bios, crash]
updated: 2026-07-12
automated_by: system-scripts/nvidia-power-limit/
---

# Xid 79 — "GPU has fallen off the bus"

**Status: under test.** BIOS updated, PCIe forced to Gen4, and the 250 W power
cap is now persistent. Next data point comes from the next gaming session.

## Symptom

While gaming (PoE2, Witcher 3; Steam + sway/gamescope, sometimes Lutris/gamemode)
the machine hard-crashes:

- GPU fans ramp to 100 % and stay there
- Monitor powers down
- Whole system wedges — **must unplug, wait, then boot**, and it sometimes takes
  more than one boot to come back fully

## The log is unambiguous

```
NVRM: Xid (PCI:0000:01:00): 79, GPU has fallen off the bus.
NVRM: GPU 0000:01:00.0: GPU has fallen off the bus.
NVRM: Xid (PCI:0000:01:00): 154, GPU recovery action changed from 0x0 (None) to 0x2 (OS Reboot)
```

```bash
journalctl -b -1 --no-pager | grep -iE "Xid|fallen off"
```

**Xid 79** = the GPU stopped responding on the PCIe bus entirely; the driver can
no longer talk to the card. That explains every symptom: fans fail safe to 100 %
when the fan controller loses its curve, the display engine is simply gone, and
the driver itself told the kernel the only recovery is `OS Reboot` (Xid 154).

This is a **power / PCIe-signal / hardware-stability** fault.

## The VRAM theory was wrong (and worth recording *why*)

The original hypothesis was a VRAM leak — watching PoE2's in-game GPU meter climb
from 6 to 7.x GB before a crash, on a 12 GB card, with lots of other things open.
Plausible, and completely wrong. Keeping it here because the reasoning is the
reusable part:

- **VRAM exhaustion has a different signature.** It produces **Xid 31 (MMU fault)**
  or `NV_ERR_NO_MEMORY`, and it kills *the application* or causes stutter. It does
  not knock a card off the PCIe bus and freeze the OS.
- 7.x GB on a 12 GB card is nowhere near full. System RAM was 91 GB with 16 GB
  swap; `systemd-oomd` never fired.
- Temps were fine right up to the crash. **The fan ramp is a symptom of the
  fall-off, not overheating.**

The Witcher 3 ray-tracing crashes and the ComfyUI/SageAttention crashes *are*
genuine VRAM/allocation bugs — which is exactly what trained the wrong instinct
here. Different failure, same feeling.

**Rule of thumb: read the Xid before theorising.** It names the fault class.

| Xid | Means | Chase |
| --- | ----- | ----- |
| 79 | GPU fell off the bus | power / PCIe / hardware (this note) |
| 31 | MMU fault | app / driver / VRAM |
| 13, 43 | Graphics exception | app / driver |

## Why this hardware is a textbook case

RTX 4070 Ti (285 W default, 340 W max) on a then-new MSI MPG X870E Carbon with an
AMD 9950X3D. **Ada 40-series cards produce microsecond transient power spikes far
above their rated draw** — enough to trip PSU over-current protection and drop the
card off the bus. Pair that with a fresh AM5 board on early BIOS and aggressive
PCIe Gen 5 auto-negotiation, and this is the classic Xid 79 profile.

PSU is a be quiet! Pure Power, 700–750 W: adequate on paper, mid-tier Gold. The
problem is not total wattage; it is **transient spike handling and OCP
sensitivity**.

## What has been done

| # | Change | Status |
| - | ------ | ------ |
| 1 | **Power cap 285 → 250 W** | ✅ now persistent — `system-scripts/nvidia-power-limit/` |
| 2 | Reseat 12VHPWR/PCIe connectors at *both* ends + reseat card | ⬜ do at next physical access |
| 3 | **BIOS: PCIe slot Auto → Gen4** | ✅ done (`pcie.link.gen.max` = 4) |
| 4 | Kernel `pcie_aspm=off` | ⬜ only if 1+3 fail |
| 5 | **BIOS update** (1.A64 → 1.AA3) | ✅ done |
| 6 | PSU replacement / separate PCIe cables | ⬜ last resort |

**Do them one at a time.** Changing several at once means learning nothing about
which one mattered.

### 1 + 3 are the current test

These two resolve the large majority of 40-series Xid 79 cases. Both are now
active. The next gaming session is the experiment.

> **The persistence trap:** `nvidia-smi -pl 250` is a *runtime driver setting*.
> It is not written to hardware or BIOS and **does not survive a reboot**. Set the
> cap, then reboot into BIOS to change PCIe Gen, and you have silently wiped the
> cap — you would then be testing Gen4 alone while believing you tested both.
> This is precisely why the cap is a systemd unit and not a one-off command.
>
> (`Persistence-Mode: On` in `nvidia-smi` output is unrelated — it keeps the
> driver resident, it does not preserve the power cap.)

## Tuning the cap

`system-scripts/nvidia-power-limit/` re-applies the cap at every boot. Walk the
ladder by editing `/etc/nvidia-power-limit.conf` — no code changes:

```bash
sudo $EDITOR /etc/nvidia-power-limit.conf   # NVIDIA_POWER_LIMIT_W=250 → 240 → 220
sudo systemctl restart nvidia-power-limit
nvidia-power-limit.sh --show
```

If **220 W still crashes**, the cause is probably not transient spikes. Stop
lowering it and move to #2 / #4 / #6.

### Cost of the cap

Small, and partly a benefit. The GPU's efficiency curve is steeply diminishing at
the top — the last ~35 W buys very little clock.

- **Games:** ~1–2 %. Power is drawn in bursts; the cap is rarely hit.
- **AI / sustained compute:** ~2–4 %. Inference pegs the GPU continuously, so the
  cap bites more often — but it also improves thermals and stability on long runs.
  Many people running local AI power-cap deliberately for exactly this reason.

## Notes on the other BIOS settings

**PCIe Gen:** the RTX 4070 Ti is a **PCIe 4.0 card** — it cannot do Gen5 at all.
Setting the slot to Gen4 does not slow it down; it just forces a clean negotiation
and removes flaky Gen5 auto-training. If a *stronger* signal-integrity test is
ever needed, the meaningful downgrade is **Gen3** — but note that Gen3 x16
(~16 GB/s vs Gen4's ~32 GB/s) **does** hurt AI workflows that offload layers to
system RAM (ComfyUI CPU-offload, large models). Use Gen3 as a temporary diagnostic
only. The M.2 drives are unaffected — the slot Gen setting applies to the GPU slot.

**X3D Gaming Mode:** was enabled after the BIOS update, which **auto-disabled CCD1
*and* SMT** — turning a 16C/32T 9950X3D into an effective 8C/8T part (`nproc` was
8). Now turned back off (`nproc` = 32). This is **orthogonal to Xid 79** — CCD/SMT
config neither causes nor cures a bus fall-off — but it was a bad trade for this
machine: the headline ~20 % gaming gains are 1080p CPU-bound benchmarks with a
4090, whereas PoE2 on a 4070 Ti is GPU-bound and gains ~nothing, while AI and
multitasking lose half the cores permanently. If a specific game ever turns out to
be CPU-bound and hurt by cross-CCD scheduling, pin *that game* to the V-cache cores
(`taskset -c 0-7 %command%` in Steam launch options) rather than amputating a CCD
globally.

**`pcie_aspm=off`** (#4, not yet applied): essentially risk-free. Costs a few watts
at idle because the PCIe link no longer enters low-power states. No stability,
performance, or data-integrity downside.

## After the next crash (if any)

```bash
journalctl -b -1 --no-pager | grep -iE "Xid|fallen off"
```

- Still **Xid 79** → the cap did not fix it. Continue down the list: reseat (#2),
  `pcie_aspm=off` (#4), then PSU (#6).
- **Different Xid** (31 / 13 / 43) → the power problem is solved and something
  else is now surfacing. That is a different investigation.
- **No crash** → keep playing before declaring victory. This fault is
  load-dependent and intermittent; one good session is weak evidence.
