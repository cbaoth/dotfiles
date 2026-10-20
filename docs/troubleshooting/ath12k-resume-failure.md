---
title: Wi-Fi (ath12k) dead after suspend until reboot
hosts: [motoko]
status: workaround
tags: [wifi, ath12k, qualcomm, suspend, resume, kernel]
updated: 2026-10-20
automated_by: setup/modules/57-wifi-resume.sh
revisit: 2026-12-01
---

# Wi-Fi (ath12k) dead after suspend until reboot

**Verdict: workaround, unconfirmed.** A system-sleep hook unloads the driver
before sleep and loads it after resume. Whether that stops the failure is only
known after weeks of normal use — it cannot be reproduced on demand.

## Symptom

2026-10-20: resume from a 26 s `s2idle` suspend (18:45:57 → 18:46:23) left the
interface present but unusable. `ip link set … up` and `networkctl` failed with
*Cannot send after transport endpoint shutdown*. Only a reboot helped.

Older, possibly the same fault: after irregular (sometimes regular) shutdowns
the card did not come up at all until power was removed completely, sometimes
needing 2–3 boots. See also `hibernate-nvidia.md` (same "Wi-Fi gone until
power-off" collateral). Whether the two are the same bug is unconfirmed.

## Evidence

Hardware: Qualcomm WCN785x Wi-Fi 7 (`17cb:1107`, Foxconn subsystem), driver
`ath12k_wifi7`, PCI `0e:00.0`, kernel 7.0.0-38. From `journalctl -b -1 -k`:

```
ath12k_wifi7_pci 0000:0e:00.0: failed to set mhi state INIT(0) in current mhi state (0x5)
ath12k_wifi7_pci 0000:0e:00.0: failed to power up hif during resume: -22
ath12k_wifi7_pci 0000:0e:00.0: PM: dpm_run_callback(): pci_pm_resume_early returns -22
ath12k_wifi7_pci 0000:0e:00.0: failed to resume core: -110
ath12k_wifi7_pci 0000:0e:00.0: failed to enable PMF QOS: -108   (repeats every ~10 s)
```

`-108` = ESHUTDOWN, the same text `ip`/`networkctl` showed: the firmware did
not come back and the driver kept talking to it. A resume-time MHI failure is a
known ath12k class of bug; not confirmed fixed in this kernel.

## Ruled out

- **Waking too fast:** the suspend lasted 26 s, long past entry.
- **Kernel flags:** the command line is only `mem_sleep_default=deep` and
  `crashkernel=…`; no `pcie_aspm`/autosuspend flags are set now (an earlier
  one, if any, is gone).
- **NetworkManager power save:** already disabled
  (`/etc/NetworkManager/conf.d/default-wifi-powersave-on.conf`: `wifi.powersave = 2`).

## Workaround

`/etc/systemd/system-sleep/50-ath12k-reload`: `pre` → `modprobe -r ath12k_wifi7
ath12k`, `post` → `modprobe ath12k_wifi7`. Cost: a second or two without
Wi-Fi after each resume. Deployed by `setup/modules/57-wifi-resume.sh`
(needs sudo, so staged via `ccrun`).

Manual recovery without the hook (or if it fails): `wifi-driver-reload`
(alias, motoko only, `lib/aliases-motoko.sh`).

## If it comes back

1. Check the hook ran: `journalctl -b -t ath12k-sleep` (only logs on failure) and
   `journalctl -b -k | grep ath12k` around the resume.
2. If the card dies even with a fresh load, try `pcie_aspm=off` on the kernel
   command line (untested here), then a newer kernel/`linux-firmware`.
3. Cold-boot failures (no Wi-Fi after power-up) are a different path; the hook
   does not touch them.
