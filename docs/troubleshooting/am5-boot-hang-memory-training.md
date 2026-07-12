---
title: No boot after a BIOS change — POST 0d, CPU + DRAM LEDs (motoko)
hosts: [motoko]
status: resolved
tags: [am5, bios, memory, ddr5, expo, boot, msi]
updated: 2026-07-13
---

# AM5 boot hang after a BIOS change (POST 0d, CPU red + DRAM yellow)

**Resolved by a CMOS reset.** But it will happen again on the next BIOS change
unless **Memory Context Restore** is disabled — see below.

## Symptom

After disabling **X3D Gaming Mode / CCD1** in BIOS, the machine would not boot:

- No display, keyboard not recognised
- Survived multiple power cycles and unplugs
- Left running for *hours* with no change
- **EZ Debug LEDs: CPU red, DRAM yellow. VGA and BOOT off. POST code `0d`.**

CPU + DRAM LEDs lit, VGA/BOOT dark, means the board never got past **memory
training** — it never reached the GPU or boot device. This is a *memory training*
failure, not a dead CPU or GPU, however alarming the red CPU LED looks.

## Fix

1. Power off, cut power at the PSU.
2. **Press the Clear CMOS button** (rear I/O on the X870E Carbon).
3. Wait ~1 minute.
4. Power on — the board retrains memory from scratch and boots.
5. Re-apply BIOS settings (they are wiped).

## Cause: Memory Context Restore

**`Memory Context Restore: Enabled`** is the prime suspect and should be turned
**off**.

DDR5 memory training is slow — with **2×48 GB** it is *very* slow. MCR caches the
training results so subsequent boots can skip it. The failure mode: when a setting
changes that invalidates the cached training — **such as disabling a CCD** — the
board may try to reuse stale training data and hang.

"Changed a CPU/memory-adjacent setting → next boot hangs at DRAM training" is the
textbook MCR signature, and it is a well-known AM5 boot-loop cause.

**The trade is bad here.** MCR buys 10–20 seconds of boot time, at the cost of
periodically losing an evening to a CMOS reset and re-entering every BIOS setting.
This machine reboots rarely. **Disable it.**

## The mistake that probably made it worse

> *"i waited around 1 minute for the system to reboot, after which i unplugged it"*

**On AM5 with 96 GB of DDR5, first-boot memory training after a config change can
legitimately take several minutes** — sometimes 5+, with a black screen and no
keyboard response. It looks *exactly* like a hang.

Cutting power mid-training is how a slow boot becomes a corrupted one. It is
plausible the first boot would have completed on its own.

> **Rule: after any BIOS change on AM5, wait at least 5 minutes before concluding
> the machine is hung.** Watch the EZ Debug LEDs — a *lit* DRAM LED means it is
> working, not dead.

## Not related to the GPU crashes

This is a separate fault from
[Xid 79 / GPU falls off the bus](gpu-xid79-bus-fall-off.md). Memory training
failures do not cause bus fall-offs, and the Xid 79 crashes long predate this
incident. Do not conflate them.

The one thing worth noting: **EXPO is a memory overclock**, and this box now has a
demonstrated memory-training sensitivity. RAM instability produces a completely
different signature than Xid 79, so it is not a crash suspect — but if *other* odd
instability ever appears, EXPO is a variable to test.

## Verify after recovery

```bash
nproc                                              # 32 => CCDs + SMT all enabled
lscpu | grep -E "^CPU\(s\)|Model name"
sudo dmidecode -t memory | grep -i "configured memory speed"   # 6000 MT/s => EXPO stuck
```

Confirmed good after the reset: 32 threads, 6000 MT/s.
