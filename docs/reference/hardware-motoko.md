---
title: Hardware inventory — motoko (desktop)
hosts: [motoko]
status: resolved
tags: [hardware, inventory, pcie, psu]
updated: 2026-07-12
---

# motoko — hardware

Desktop workstation. Main rebuild **2025-10**; the GPU and PSU were carried over
from the previous build (see [PSU](#psu-the-weak-link) — this matters).

Kept as a doc because most of this is awkward to retrieve at runtime (needs
`sudo dmidecode`, or opening the case) and hardware changes rarely.

## Core

| Part | Model |
| ---- | ----- |
| **CPU** | AMD Ryzen 9 9950X3D — 16C/32T, AM5, dual-CCD with 3D V-Cache |
| **Cooler** | Noctua NH-D15 G2 (dual tower) |
| **RAM** | Corsair Vengeance DDR5 96 GB (2×48 GB) 6000 MT/s CL30-36-36-76 @1.40 V — `CMK96GX5M2B6000Z30`, EXPO |
| **GPU** | Gigabyte GeForce RTX 4070 Ti GAMING OC 12 GB *(carried over)* |
| **Board** | MSI MPG X870E Carbon WiFi (AM5, ATX) |
| **Case** | Fractal Design Define 7 Black Solid, Midi Tower |
| **PSU** | **be quiet! Straight Power 11, 750 W** — 80+ Gold, fully modular, **ATX 2.x** *(carried over; bought ~2019 as a replacement, fitted by a local shop)* |
| **Monitor** | LG 38GN950 (37.5" ultrawide, 3840×1600, 144 Hz) |

RAM runs at its rated 6000 MT/s with EXPO enabled (confirmed via
`dmidecode -t memory`). 2×48 GB @ 6000 CL30 is stable out of the box on AM5;
enable EXPO and leave everything else on Auto.

## Storage

**NVMe (M.2):**

| Drive | Model | Use |
| ----- | ----- | --- |
| 4 TB Samsung 990 PRO | `MZ-V9P4T0BW` | Windows 11 |
| 4 TB Samsung 990 PRO | `MZ-V9P4T0BW` | **Ubuntu (primary OS)** |
| 4 TB Crucial P3 Plus | `CT4000P3PSSD8` | `D:` — games/data (NTFS) |

> The **P3 Plus is deliberately not a boot drive.** It has no (or inadequate)
> DRAM cache, which caused severe system lag — booting and restoring Windows from
> hibernate took forever as apps and services auto-started. Replaced in that role
> by the two 990 PROs. Do not "reclaim" it as a system drive.

**SATA:** Crucial MX500 2 TB (`CT2000MX500SSD1`), Samsung 850 EVO 500 GB.

Live device map (`hwinfo --short`): `nvme0n1` + `nvme1n1` = the two Samsung 990 PROs,
`nvme2n1` = the Crucial P3 Plus, `sda` = MX500, `sdb` = 850 EVO.

## Network & peripherals

| Interface | Device | Use |
| --------- | ------ | --- |
| `enp6s0` | Realtek RTL8125 **2.5 GbE** | direct link to [saito](hardware-saito.md) |
| `enp7s0` | Realtek Gigabit | — |
| `wlp14s0` | Qualcomm | WiFi |
| `qtun` | — | NordVPN (NordLynx) |

Peripherals worth recording (they show up in `hwinfo` and occasionally in bug
hunts): Logitech Unifying receiver (keyboard + mouse), Logitech C922 Pro webcam,
3Dconnexion SpaceMouse Wireless, **Feitian U2F** security key (see
[../setup/security.md](../setup/security.md)), Sony WH-1000XM4 (Bluetooth),
MSI Mystic Light (RGB).

## Refreshing this doc

Most of the above comes straight from:

```bash
hwinfo --short
```

That is also how the second WD Elements on saito was spotted — a hand-maintained
inventory drifts. Re-run it after any hardware change and reconcile.

What `hwinfo` will *not* tell you: the **PSU** (no electrical bus to report on), RAM
part numbers (`sudo dmidecode -t memory`), and the exact board revision.

## PCIe lane sharing (X870E Carbon)

Worth knowing before adding any card or M.2 drive — the board silently halves GPU
bandwidth if you populate the wrong slot.

| Slot | Attached to | Shares with GPU? |
| ---- | ----------- | ---------------- |
| **PCI_E1** (GPU, Gen5 x16) | CPU | — |
| **PCI_E2** (Gen5 x4) | CPU | ⚠️ **yes** — populating it drops PCI_E1 to **x8** |
| **M.2_2** (Gen5 x4) | CPU | ⚠️ **yes** — populating it drops PCI_E1 to **x8** |
| M.2_1 (Gen5 x4) | CPU, separate link | no |
| M.2_3 / M.2_4 (Gen4 x4) | Chipset | no |
| PCI_E3 (Gen4 x4) | Chipset | no |
| USB4 ×2 (ASM4242) | CPU, dedicated x4 | no |

**Rule: keep `M.2_2` and `PCI_E2` empty** to hold the GPU at x16. Put NVMe drives
in `M.2_1`, `M.2_3`, `M.2_4`.

Current state is correct — verified, not assumed:

```bash
nvidia-smi --query-gpu=pcie.link.width.current,pcie.link.width.max --format=csv
# 16, 16
```

This **closes an open question** from the
[Xid 79 investigation](../troubleshooting/gpu-xid79-bus-fall-off.md): adding the
second 990 PRO for Linux was a real hardware delta, and the worry was that it had
stolen GPU lanes. It did not — the GPU is at full x16, so `M.2_2` is free.

(Dropping to x8 would be fairly harmless anyway — 0–2 % in games — but it would
have been a confounding variable in a crash investigation.)

Sources: [X870E Carbon manual (PDF)](https://download-2.msi.com/archive/mnu_exe/mb/MPGX870ECARBONWIFI_English.pdf),
[MSI: PCIe lane bifurcation on X870E](https://www.msi.com/blog/pcie-lane-bifurcation-and-bandwidth-sharing-on-msi-x870e-x870-motherboards)

## PSU — the weak link

**be quiet! Straight Power 11, 750 W.** Bought ~2019 as an emergency replacement
(the previous PSU failed; a local shop diagnosed and fitted it — no email invoice,
only a paper one). Identified 2026-07 from the original box in the basement, since
the unit is routed into a cable channel and its label is not visible in situ.

### It is a *good* PSU. That is not the point.

Straight Power 11 is be quiet!'s high-end line — 80+ Gold, fully modular, FSP-built.
The failure mode here has nothing to do with build quality:

> **It is ATX 2.x.** It predates the standard that was written to solve this exact
> problem.

ATX 3.0/3.1 mandates riding out **200 % transient excursions**. That requirement
exists *precisely because* good ATX 2.x units were tripping OCP on 30/40-series
spikes. A high-quality ATX 2.x PSU shutting down under Ada transients is the
**canonical documented failure mode**, not an edge case.

### The power budget

| Component | Draw |
| --------- | ---- |
| Ryzen 9 9950X3D (PPT) | ~200 W |
| RTX 4070 Ti | 285 W sustained, **~450–500 W transient** |
| Board, 3× NVMe, 2× SATA, fans, RGB, peripherals | ~80–100 W |
| **Sustained peak** | ~570–600 W |
| **Transient peak** | **can momentarily approach or exceed 750 W** |

On a 750 W rail that is right at the edge — which is where OCP fires and the GPU
drops off the bus. Add ~6–7 years of capacitor aging (transient response degrades)
and this is a strong suspect, not an afterthought. See
[Xid 79](../troubleshooting/gpu-xid79-bus-fall-off.md).

### GPU power delivery (checked 2026-07-12)

```
PSU ──8-pin──┐
             ├── Y-adapter ──16-pin 12VHPWR──> GPU (single socket)
PSU ──8-pin──┘
```

**Two dedicated cables from the modular PSU** into the Y-adapter that shipped with
the card — **not** daisy-chained/pigtailed, which is correct.

But this tells us the card uses a **12VHPWR (16-pin)** socket via the bundled
**2× 8-pin adapter** — and *that adapter is the single most notorious failure point
in modern GPUs*. A partially-seated 12VHPWR raises contact resistance under load, so
it works at idle and drops the card only during transients. That is a textbook
mechanism for [Xid 79](../troubleshooting/gpu-xid79-bus-fall-off.md), and it matches
the "only crashes in games" symptom exactly.

It also gives a **second, independent reason** to move to an ATX 3.1 PSU: a native
**12V-2x6** cable removes the adapter from the chain entirely, and 12V-2x6's shorter
sense pins fail safe on partial insertion.

### If replacing it

**The spec that matters is `ATX 3.1`, not the wattage** — a 1200 W ATX 2.x unit
could still trip on transients, while a 850 W ATX 3.1 unit is designed to ride them
out. "Just buy bigger" is the wrong frame.

To be future-proof rather than barely-sufficient:

- **1000 W**, **ATX 3.1**, **native 12V-2x6** connector, 80+ Gold or better, from a
  reputable OEM (Seasonic, Corsair RM/HX, be quiet! Dark Power / Straight Power 12,
  Super Flower).
- 1000 W is the sizing NVIDIA specifies for an **RTX 5090** (575 W TDP), so it covers
  a future GPU upgrade with headroom while fixing today's problem.
- **850 W would run a 5090 only marginally** — exactly the "barely sufficient" trap.
- Don't go past ~1000 W: that is beyond future-proofing into waste, and low-load
  efficiency gets worse.

**But do not buy on a guess** — the free 250 W power-cap test is what tells you
whether this is a power fault at all. See the troubleshooting note.

## See also

- [../troubleshooting/gpu-xid79-bus-fall-off.md](../troubleshooting/gpu-xid79-bus-fall-off.md) — the GPU crash investigation
- [hardware-saito.md](hardware-saito.md) — the LAN server
