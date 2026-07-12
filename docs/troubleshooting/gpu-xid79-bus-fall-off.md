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

### The PSU: identified, and it is not a quality problem

**be quiet! Straight Power 11, 750 W** (identified 2026-07 from the box in the
basement — the unit sits in a cable channel and its label is not readable in situ).

This is a **good** PSU: be quiet!'s high-end line, 80+ Gold, fully modular,
FSP-built. So the naive "cheap PSU" theory is dead. The real issue is narrower and
much more specific:

> **It is ATX 2.x** (launched ~2018–19). It predates the standard written to solve
> this exact problem.

ATX 3.0/3.1 mandates riding out **200 % transient excursions** — a requirement that
exists *precisely because* good ATX 2.x units were tripping OCP on 30/40-series
spikes. **A high-quality ATX 2.x PSU shutting down under Ada transients is the
canonical documented failure mode**, not an edge case. Add ~6–7 years of capacitor
aging, and:

| | Draw |
| --- | --- |
| 9950X3D (PPT) | ~200 W |
| RTX 4070 Ti | 285 W sustained, **~450–500 W transient** |
| Rest of system | ~80–100 W |
| **Transient peak** | **can momentarily approach or exceed 750 W** |

Right at the rail's limit — which is where OCP fires and the GPU falls off the bus.
Sizing and the ATX 3.1 requirement:
[../reference/hardware-motoko.md](../reference/hardware-motoko.md#psu--the-weak-link).

It is also the **only component not refreshed** in the 2025-10 rebuild (the case was
bought *ohne Netzteil*; the GPU was carried over too).

### #2 — the 12VHPWR adapter (top free suspect)

**Cabling topology confirmed OK** (checked 2026-07-12): the GPU has a **single**
power socket, fed by a **Y-adapter** (shipped with the card) which is in turn fed by
**two dedicated cables** from the modular PSU. Not daisy-chained. That suspect is
cleared.

But the topology *identifies the card's connector*: a single socket fed by two
8-pins via a Y-adapter means this is a **16-pin 12VHPWR** socket with the bundled
**2× 8-pin → 12VHPWR adapter**. Which is a much better suspect than cable routing
ever was.

**Why it fits Xid 79 better than anything else on this list:**

Xid 79 is not a slow degradation — it is the GPU *momentarily losing contact and
dropping off the bus*. A **partially-seated 12VHPWR connector** produces exactly
that, and the failure is nasty in three specific ways:

- **It takes real force to click home.** A large fraction of people who believe
  theirs is seated have it a millimetre proud. There is no visual difference.
- **Contact resistance rises under load** — so it works fine at idle and on the
  desktop, and fails only when the card pulls a 450–500 W transient. *That is
  precisely the "only crashes in games" symptom profile.*
- **It leaves no trace.** Unlike the famous melted connectors, an intermittent one
  simply drops the card.

**Action (free):**

1. Reseat the 12VHPWR at the **GPU end** — push until it *audibly clicks*, with no
   visible gap at the shroud.
2. Reseat both 8-pins at the **adapter end** and the **PSU end**.
3. **Inspect the pins for browning/discoloration.** That is direct evidence of
   high-resistance contact and would essentially confirm the diagnosis.

**PSU-end port check (low probability, 30 seconds):** on a fully modular PSU the
PCIe/VGA ports share a rail and are interchangeable, so identical plugs in numbered
ports deliver the same thing. The one mistake that *is* possible is plugging a PCIe
cable into a **CPU/EPS** port — both are 8-pin and look similar, but the pinouts
differ. Straight Power 11 labels them separately. Worth a glance, not worth worrying
about.

**This is also an argument for the ATX 3.1 PSU (#6):** a native **12V-2x6** cable
removes the adapter from the chain entirely, and 12V-2x6's *shorter sense pins* are
designed to fail safe on partial insertion (the card refuses to power up rather than
running at high resistance). That is a second, independent reason to replace the
PSU — separate from the transient-excursion argument.

### Ruled out: PCIe lane loss

The second 990 PRO added for Linux was a real hardware delta, and on this board
`M.2_2` / `PCI_E2` **share the CPU Gen5 x16 pool with the GPU slot** — populating
either drops the GPU to x8. So it was worth checking. It is fine:

```bash
nvidia-smi --query-gpu=pcie.link.width.current --format=csv   # 16
```

GPU is at full **x16** → those slots are empty. Not a factor. Lane map:
[../reference/hardware-motoko.md](../reference/hardware-motoko.md#pcie-lane-sharing-x870e-carbon).

## What has been done

| # | Change | Cost | Status |
| - | ------ | ---- | ------ |
| 1 | **Power cap 285 → 250 W** | free | ✅ persistent — `system-scripts/nvidia-power-limit/` (needs `install.sh`) |
| 2 | **Reseat the 12VHPWR adapter** (click!) + inspect pins for browning + reseat card | **free** | ⬜ **do at next physical access — top free suspect** |
| 3 | **BIOS: PCIe slot Auto → Gen4** | free | ✅ done (`pcie.link.gen.max` = 4) |
| 4 | Kernel `pcie_aspm=off` | free | ⬜ only if 1–3 fail |
| 5 | **BIOS update** (1.A64 → 1.AA3) | free | ✅ done |
| 6 | **PSU → 1000 W ATX 3.1** | €€ | ⬜ the likely real fix, but only after 1–4 |
| — | PCIe lane loss (2nd NVMe stealing GPU lanes) | — | ✅ **ruled out** — GPU at x16 |

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

## Later: scope the cap to games only (do NOT do this yet)

If the crash only ever happens in games, the cap only needs to be active in games —
reclaiming the 2–4 % cost on AI workloads.

The physics supports it: **transient spikes come from rapid load *changes*.** Games
swing GPU load frame-to-frame; sustained AI compute pegs the GPU at a steady high
draw with far fewer transients. So "games trigger Xid 79, AI does not" is plausible,
not just wishful.

But the evidence is weaker than it looks: the ComfyUI/SageAttention crashes were a
**different bug** (app-level VRAM). So there is no clean "AI never triggers Xid 79"
datapoint — only "AI crashed for another reason, which masked whether it also does
this."

**Sequence matters. Do not build this before the global cap is proven.** If the cap
is scoped to games and a crash still happens, there are two unknowns instead of one:
did the cap fail, or did the hook never fire? That is debugging your own plumbing
instead of the GPU.

When the time comes:

- **gamemode** (`~/.config/gamemode.ini`, currently absent — running on defaults):
  ```ini
  [custom]
  start=/usr/bin/sudo -n /opt/bin/nvidia-power-limit.sh --apply
  end=/usr/bin/sudo -n /opt/bin/nvidia-power-limit.sh --reset
  ```
  `[custom]` hooks run **as the user, not root**, and `nvidia-smi -pl` needs root —
  so this needs a narrow `NOPASSWD` entry for exactly those two fixed commands, same
  pattern as `/etc/sudoers.d/power-states` (see [../setup/power-management.md](../setup/power-management.md)).
  The script already has `--reset` for this.
- **Lutris** has per-game pre-launch/post-exit scripts as an alternative path.

### Also worth knowing: `[cpu] pin_cores`

gamemode 1.8 supports `pin_cores` / `park_cores`. **This is the right answer to the
X3D question** — pin a CPU-bound game to the V-cache cores per-game, rather than
globally disabling CCD1 in BIOS (which costs half the cores for AI and multitasking,
all the time). Gaming's best case without the permanent amputation.

### Lutris "Enable Feral GameMode" fails

Currently has to be disabled or games break (some i386-related lib error). **Not** a
missing 32-bit lib — `libgamemode0:i386` and `libgamemodeauto0:i386` are both
installed, and Lutris is apt (0.5.22), not a flatpak, so it is not sandboxing either.
Most likely the **Lutris runtime** shadowing the system libs. Reproduce with
`lutris -d` from a terminal and capture the actual error. Independent of the crash.

## The PSU / GPU-upgrade decision

A **PSU upgrade is a prerequisite for an RTX 5090** (575 W TDP; NVIDIA specifies
~1000 W). The current be quiet! Pure Power 700–750 W cannot run one.

This reframes the economics: buying a better PSU is **not "spending money to fix a
bug"** — it is a purchase already required for the planned upgrade, made earlier. And
a quality high-headroom unit plausibly fixes Xid 79 outright (transient response, OCP
headroom, native 12V-2x6), which means **no cap and no gamemode plumbing at all** —
strictly better than any scripted workaround.

**But do not buy on a guess.** The 250 W cap test is free and is precisely the
diagnostic that de-risks the purchase:

- **Cap fixes the crash** → confirmed transient/power fault → the PSU is the correct
  permanent fix, and it is known to work *before* spending.
- **Cap does not fix it** → not a power fault → a new PSU would be wasted money.

The cap test is not an alternative to the PSU. It is how to find out whether the PSU
is the answer.

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
