---
title: GRUB intermittently drops to its console at boot — Yoga C940 (puppet)
hosts: [puppet]
status: open
tags: [grub, uefi, boot, efi, nvme, ubuntu]
updated: 2026-09-04
---

# GRUB intermittently drops to its console at boot

**Status: unresolved.** One concrete bug was found and fixed (a hardcoded disk
in the ESP config) but it was *not* this problem — the failure survives it at
roughly 1 success in 7 boots. Evidence from the GRUB prompt now narrows the
fault to `configfile` failing after `/boot` has been found and read
successfully. See *Is this actually the original problem?*.

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

## Is this actually the original problem? — **no, and now we know why**

The hardcoded `(hd0,gpt2)` was a real bug, but fixing it did not fix the boot.
The failure rate after the fix is still roughly **1 success in 7 attempts**.

On 2026-09-03 the `grub>` prompt was finally photographed legibly, and it settles
several things at once:

```
grub> ls
(memdisk) (proc) (hd0) (hd0,gpt3) (hd0,gpt2) (hd0,gpt1)
grub> set
...
fw_path='(hd0,gpt1)/EFI/ubuntu'
prefix='(hd0,gpt2)/grub'
root='hd0,gpt2'
error: command failed.
grub> search.fs_uuid <BOOT_UUID> root
grub> echo $root
hd0,gpt2
grub> ls (hd0,gpt2)
        Partition hd0,gpt2: Filesystem type ext* - Last modification time 2026-09-03
```

What each line rules out:

| Observation | Conclusion |
| ----------- | ---------- |
| `ls` lists `(hd0,gpt1..3)` | The NVMe **is** enumerated. Not a "disk not ready" race. |
| `prefix` and `root` are already correct | The ESP `grub.cfg` ran and `search.fs_uuid` **succeeded**. The February fix works. |
| `ls (hd0,gpt2)` reads the superblock | `/boot` is mountable and readable by GRUB at that moment. |
| It is `grub>`, not `grub rescue>` | The `normal` module loaded from `/boot/grub`. Module reads work too. |

So GRUB finds `/boot`, reads from it, loads modules from it — and then
`configfile $prefix/grub.cfg` **fails anyway**. The failure is entirely
downstream of everything the ESP fix addresses.

The flashing pre-prompt spam was finally read too: it is the same line repeated
roughly 10-15 times, `error: command failed.`, with one longer line somewhere in
the middle. That is the shape of a script whose statements each fail in
sequence, not of a single fatal error.

**Still open.** The next step is to make the failure reproducible at the prompt
rather than inferred — see below.

## Making the failure readable

`GRUB_GFXMODE` lives in `/boot/grub/grub.cfg`, which is exactly the file that
fails to load, so it can never affect this screen. But `$prefix` is valid by
then, which means the font *can* be loaded earlier — from the ESP config, before
`configfile` runs:

```
search.fs_uuid <BOOT_UUID> root
set prefix=($root)'/grub'
if loadfont ($root)/grub/fonts/unicode.pf2 ; then
  insmod all_video
  insmod gfxterm
  set gfxmode=1024x768,800x600,auto
  terminal_output gfxterm
fi
set pager=1
configfile $prefix/grub.cfg
```

Two deliberate choices:

- **The `if` guard.** If `search` ever does fail, `$root` is wrong, `loadfont`
  fails, and the block is skipped — leaving exactly today's behaviour rather than
  a black screen from a half-initialised `gfxterm`.
- **`set pager=1`.** This makes GRUB stop at every screenful. On a successful
  boot nothing prints before the menu, so it never triggers; on a failing boot it
  freezes the error spam instead of letting it scroll away. Safe here only
  because this machine prompts for a LUKS passphrase every boot — someone is
  always at the keyboard. Remove it if that ever stops being true.

This supersedes the earlier "kept deliberately dumb" reasoning: that was written
on the assumption that modules could not be loaded at this stage. The `set`
output above disproves it — `prefix` is live before `configfile` runs.

### Reproducing it by hand

At the `grub>` prompt the state is already correct, so the failure can be
triggered on demand and read at leisure:

```
set pager=1
configfile $prefix/grub.cfg
```

Also worth running there, to narrow it further:

```
ls (hd0,gpt2)/grub/            # does the directory list?
cat (hd0,gpt2)/grub/grub.cfg   # does the file read end-to-end?
lsmod                          # what actually loaded
```

If `cat` reads the whole config but `configfile` still fails, the fault is in
executing it (a failing `insmod`/`loadfont`/`save_env`), not in reading it.

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
