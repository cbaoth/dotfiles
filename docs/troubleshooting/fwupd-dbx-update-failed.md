---
title: fwupd "UEFI dbx" update keeps failing (motoko)
hosts: [motoko]
status: open
revisit: after the next reboot (check the dbx version)
tags: [fwupd, uefi, dbx, secure-boot, firmware, lvfs]
updated: 2026-11-18
---

# fwupd "UEFI dbx" update keeps failing

**Verdict: open.** The update installed from `sudo fwupdmgr update` on
2026-11-18 and now waits for a reboot. Whether the firmware accepts it is only
known afterwards (see *Verify*). Low urgency: Secure Boot is **off** on motoko
(`mokutil --sb-state`; fwupd flags it since 2025-12-12), so the dbx
revocations are not enforced either way.

## Symptom

- Desktop notifications for about a week: firmware update available, device
  `UEFI dbx`, `20250902` → `20260707` (Microsoft, signed by the 2023 KEK).
- Failed from the GUI firmware app:
  - 2026-09-15: started, later reported as failed. `fwupdmgr get-history`
    keeps it: `failed to run update on reboot: expected 20260707 and got (null)`,
    state `Failed`. The firmware did not apply the staged update at reboot.
  - Later: an error dialog with a stack trace appeared almost instantly after
    confirming. Its text was not captured.
- `fwupdmgr get-updates` lists `UEFI dbx (… → 20260707)` under "Devices that
  were not updated correctly" for as long as the failed history entry exists.

## Ruled out

- **Key chain:** the KEK database holds `Microsoft Corporation KEK 2K CA 2023`
  (needed for the 20260707 release) next to the 2011 KEK; the `db` has the 2023
  CAs; the platform key is valid and Setup Mode is 0 (user mode).
- **Windows hibernate / NTFS `remove_hiberfile`:** touches `C:`
  (`nvme0n1p3`). The ESP is on the Linux drive; unrelated.
- **Kernel/BIOS settings:** `/sys/firmware/efi/efivars` is mounted `rw`.

## What worked

Running the update from a root shell with logging:

```bash
sudo fwupdmgr update -v 2>&1 | tee /tmp/fwupd-dbx.log
```

Output ended in `Successfully installed firmware`; the device then showed
`Update State: Needs reboot`, current version still `20250902`. The
installed release is `20260707` (Release ID 150556).
Nothing differed except the entry point (root CLI instead of the GUI app).
That the GUI path was the problem is **unconfirmed**; also possible: it was
timing around the BIOS update (2026-09-02), after which the dbx reads
`20250902` again.

## Verify (after the next reboot)

```bash
fwupdmgr get-devices | grep -A6 "UEFI dbx"      # Current version: 20260707
fwupdmgr get-history | grep -A6 "UEFI dbx"      # Update State: Success
```

## If it fails again

1. Run the update as above and keep the log: the first error line is what is
   missing from the GUI case. Also `journalctl -u fwupd -b`.
2. `Needs reboot` but the version stays `20250902` after the reboot (the
   `expected … got (null)` signature): the firmware ignored the staged
   update. Check `fwupdmgr security` and that the KEK still lists the 2023 key
   (`mokutil --kek | grep Subject`). A BIOS update can reset the key
   databases to factory content. Resetting the Secure Boot keys in the BIOS
   to factory defaults is a **possible** next step, untested here.
3. If it keeps failing and Secure Boot stays off, ignoring it is fine: hide
   the notification and revisit when enabling Secure Boot.
4. Do not install the older 20260402 release; it is superseded.
