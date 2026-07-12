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
| **PSU** | be quiet! Pure Power, 700–750 W *(carried over — **exact model unconfirmed**)* |

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

**This is the most important open item on this machine.**

In the 2025-10 rebuild, the CPU, board, RAM, cooler, and case were all new. The
**GPU and the PSU were not** — the case was bought *ohne Netzteil*. So the PSU is
an older be quiet! Pure Power (700–750 W), and it is now:

- the **only** component not refreshed,
- feeding a substantially hungrier platform than it was originally sized for,
- absorbing an RTX 4070 Ti's **microsecond transient spikes** (Ada cards spike far
  above rated draw — ~450–500 W excursions on a 285 W card),
- and **aging** — capacitor transient response degrades over years.

That makes it a prime suspect for the
[Xid 79 crashes](../troubleshooting/gpu-xid79-bus-fall-off.md), not an afterthought.

### TODO: confirm the exact model

The model and wattage are not recorded anywhere. Check the label on the unit
itself, or the original order emails. Without it, the PSU discussion is guesswork.

### If replacing it

**The spec that matters is `ATX 3.1`, not the wattage.** ATX 3.1 / PCIe 5.1
mandates that a PSU ride out **200 % transient excursions** — that standard exists
*precisely* to solve the Ada/Blackwell spike problem that is the leading suspect
here. An older ATX 2.x unit is not designed for these excursions **no matter how
many watts it is rated for**, which is why "just buy bigger" is the wrong frame.

Recommended, to be future-proof rather than barely-sufficient:

- **1000 W**, **ATX 3.1**, **native 12V-2x6** connector, 80+ Gold or better, from a
  reputable OEM (Seasonic, Corsair RM/HX, be quiet! Dark Power / Straight Power,
  Super Flower).
- 1000 W is the sizing NVIDIA specifies for an **RTX 5090** (575 W TDP), so it
  covers a future GPU upgrade with headroom while fixing today's problem.
- **850 W would run a 5090 only marginally** — that is exactly the
  "barely sufficient" trap to avoid.
- Don't go past ~1000 W: beyond future-proofing into waste, and efficiency at
  typical (low) load gets worse.

**But do not buy on a guess** — the free 250 W power-cap test is what tells you
whether this is a power fault at all. See the troubleshooting note.

## See also

- [../troubleshooting/gpu-xid79-bus-fall-off.md](../troubleshooting/gpu-xid79-bus-fall-off.md) — the GPU crash investigation
- [hardware-saito.md](hardware-saito.md) — the LAN server
