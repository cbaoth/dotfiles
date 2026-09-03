---
title: GRUB intermittently drops to its console at boot — Yoga C940 (puppet)
hosts: [puppet]
status: workaround
tags: [grub, uefi, boot, efi, nvme, ubuntu]
updated: 2026-09-03
---

# GRUB intermittently drops to its console at boot

**Status: one concrete cause found and fixed; may not be the whole story** — see
*Is this actually the original problem?* below.

## Symptom

At boot, GRUB flashes an error for a fraction of a second and drops straight to
the GRUB console. Rebooting again sometimes works; sometimes it takes **10-20
attempts** before the menu appears and boots normally. The error is on screen too
briefly to read.

The practical consequence is worse than the bug: it made rebooting something to
avoid, so the machine was left suspended for days at a time — which is exactly
what triggers the fan-wedge in [lenovo-c940-thermal.md](lenovo-c940-thermal.md).
Two unrelated problems feeding each other.

## Cause found

The first file GRUB reads from the ESP, `/boot/efi/EFI/ubuntu/grub.cfg`, was:

```
set root=(hd0,gpt2)
set prefix=($root)/grub
configfile $prefix/grub.cfg
```

`(hd0,gpt2)` is **firmware enumeration order**, not identity. If `hd0` is not the
internal NVMe at that instant — a USB stick present, a slow or reordered
enumeration — `root` points at the wrong device, `configfile` fails, and GRUB
drops to the console. Retry until the enumeration happens to come out right and
it boots. That is the intermittency exactly.

Sitting right next to it was `grub.cfg.bak`, the standard Ubuntu form:

```
search.fs_uuid <BOOT_UUID> root
set prefix=($root)'/grub'
configfile $prefix/grub.cfg
```

`search.fs_uuid` **scans for the partition by UUID**, so enumeration order cannot
matter. (Real UUID kept out of this repo — it is public. Read it with
`findmnt -no UUID /boot`.)

## Which file was the original?

Timestamps, both from 2026-02-22:

| File | mtime | Content |
| ---- | ----- | ------- |
| `grub.cfg.bak` | 10:38:48 | `search.fs_uuid` (robust) |
| `grub.cfg`     | 10:39:12 | `set root=(hd0,gpt2)` (fragile) |

Tools back up the existing file and *then* write the new one, so `.bak` is the
**older** file. The robust version came first and the fragile one replaced it,
24 seconds later.

The likely story: `grub-install` run from a live USB or a chroot, where UUID
detection was unavailable, so it fell back to a hardcoded disk. That matches the
recollection of having booted the Ubuntu installer from USB to repair an earlier
boot failure. **The repair introduced this failure mode.**

## Fix

Restore the UUID form — deployed by step 2 of `c940-fixes.sh`:

```bash
sudo cp -a /boot/efi/EFI/ubuntu/grub.cfg /boot/efi/EFI/ubuntu/grub.cfg.hardcoded-bak
printf 'search.fs_uuid %s root\nset prefix=($root)'"'"'/grub'"'"'\nconfigfile $prefix/grub.cfg\n' \
  "$(findmnt -no UUID /boot)" | sudo tee /boot/efi/EFI/ubuntu/grub.cfg
```

**Deliberately kept dumb.** An `if`/fallback or a `sleep` retry was considered and
rejected: this file is read *before* `$prefix` is known, so GRUB cannot load
modules from disk yet, and `test` or `sleep` would depend on whatever happens to
be baked into `grubx64.efi`. `search` is known-safe here — the pre-February
config used it for years.

## Is this actually the original problem?

**Unclear, and worth staying honest about.** The hardcoded config dates from
2026-02-22, but the boot trouble is what prompted the USB rescue *before* that.
So either the same symptom had a different earlier cause, or the earlier failure
was something transient that the rescue attempt then made permanent.

If it still recurs after the fix, capture the error rather than guessing:

- At the `grub>` prompt, `set` shows `prefix` and `root`, and `ls` lists what
  GRUB can actually see. If `ls` shows no `(hd0,gpt2)`-like partitions, the disk
  genuinely was not ready and the theory is timing, not ordering.
- These three lines boot the system by hand from that prompt:

  ```
  search.fs_uuid <BOOT_UUID> root
  set prefix=($root)/grub
  configfile $prefix/grub.cfg
  ```

  Worth writing on paper and keeping in the laptop bag. Repeated rebooting also
  eventually works — booting from a USB stick has never actually been necessary.

## Unrelated but adjacent: unreadable fonts

The panel is 3840x2160. GRUB had no `GRUB_GFXMODE`, so it rendered at native 4K
with a ~16 px font — 240 columns. The console was worse: `console-setup` shipped
`FONTFACE="Fixed"` / `FONTSIZE="8x16"`, i.e. **480 columns by 135 rows**.

- `GRUB_GFXMODE=1920x1080` in `/etc/default/grub`, then `update-grub`. Use
  `1280x720` for larger still.
- `FONTFACE="TerminusBold"` / `FONTSIZE="16x32"` in `/etc/default/console-setup`,
  then `setupcon --save-only` and `update-initramfs -u` so the LUKS passphrase
  prompt gets it too. 16x32 is the largest Terminus available.

Note the filenames are `Terminus32x16` (height x width) while `FONTSIZE` is
width x height — easy to get backwards.
