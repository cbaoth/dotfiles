---
title: Wi-Fi (ath12k) gone after suspend or after a crash (motoko)
hosts: [motoko]
status: workaround
tags: [wifi, ath12k, qualcomm, suspend, resume, cold-boot, pcie, kernel]
updated: 2026-11-18
automated_by: setup/modules/57-wifi-resume.sh
revisit: 2026-12-01
---

# Wi-Fi (ath12k) gone after suspend or after a crash

Two failure modes, probably one weakness: the Qualcomm card (or its firmware)
sometimes ends up in a state that only a full power drain clears.
The filename keeps the original (resume) scope because the setup module,
`lib/aliases-motoko.sh` and the notes repo link to it.

| Mode | Symptom | Covered by |
| ---- | ------- | ---------- |
| **A. After suspend** | Interface exists but is unusable (`-108`) | sleep hook (workaround, unconfirmed) |
| **B. After a hard crash** | Card absent from the PCIe bus on every boot | power drain only (below) |

## Mode B: card missing after a crash (2026-11-18)

**Verdict: driver and kernel ruled out; cause of the lockup unknown.** A real
power drain fixed it on the first try (see Recovery).

Trigger: the machine hard-locked (gaming, sway) on 2026-11-17 22:26 and was
powered off by hand. Boot -3's journal simply stops at 22:26:51: no panic, no
oops, no Xid, no MCE, so the lockup itself is unexplained (not the Xid 79 case
in `gpu-xid79-bus-fall-off.md`, nothing was logged).

Evidence from the next three boots (`7.3.0-10`; the crash boot ran `7.3.0-9`):

- `lspci -nn` shows no `17cb:1107`; `/sys/bus/pci/devices` has no `0e:*`.
- Bridge `0000:0b:06.0` is configured for bus `0e` (`sec=0e`) with nothing
  behind it. A manual `echo 1 > /sys/bus/pci/rescan` did not bring it back.
- Nothing from `ath12k` in `journalctl -k`, since the driver never probes.
  `networkctl up wlp14s0` fails with *No such device*; `vnstatd` only logs
  the stale interface name.
- Bluetooth on the same Foxconn module (USB `0489:e10a`) is present and
  unblocked, so the module has power and only its PCIe function is dead.
- Before the crash the card was fine on `7.3.0-9` for 18 days.

A plain `reboot` did not help. The "complete power-offs" tried before the fix
never cut power: the smartplug was switched via Alexa under an outdated device
name, and `halt` left the power LED on. So they say nothing about how long a
drain needs. Older episodes
(sometimes needing 2-3 boots, or a 1-3 minute delay before 5 GHz showed up)
fit the same pattern. The same collateral damage is recorded in
`hibernate-nvidia.md`.

**Recovery (cold boot):**

1. Shut down fully (not `reboot`).
2. Cut standby power: smartplug off, or PSU rocker off.
3. With the power off, hold the case power button for ~10 s to drain the board.
4. Wait at least 60 s, power on, then `lspci -nn | grep -i 17cb`.

**Fixed 2026-11-18:** PSU rocker switch off (plus power-button drain), then
boot on the same `7.3.0-10`: `0e:00.0` enumerated at boot, ath12k loaded
firmware `WLAN.HMT.1.1.c7-00108`, Wi-Fi connected. This clears the kernel
upgrade; the card was stuck in a state only lost standby power clears.

**Check before blaming the card:** the smartplug really is off (power LED
dark). Renaming an Alexa device silently breaks the voice command.

**Open questions:** what the lockup was, and how short a drain still works
(the exact duration was not recorded). If it recurs: note the off time and
whether `lspci` shows `0e:00.0` right after the cold boot. If it keeps happening
without a crash: reseat the module in its M.2 E-key slot, try BIOS Fast Boot
off, and look for a BIOS newer than 1.AA7.

## Mode A: after suspend (2026-10-20)

**Verdict: workaround, unconfirmed.** A system-sleep hook unloads the driver
before sleep and loads it after resume. Whether that stops the failure is only
known after weeks of normal use — it cannot be reproduced on demand.

### Symptom

2026-10-20: resume from a 26 s `s2idle` suspend (18:45:57 → 18:46:23) left the
interface present but unusable. `ip link set … up` and `networkctl` failed with
*Cannot send after transport endpoint shutdown*. Only a reboot helped.

Cold-boot failures after crashes are covered under Mode B; whether the two
are the same bug is unconfirmed.

### Evidence

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

### Ruled out

- **Waking too fast:** the suspend lasted 26 s, long past entry.
- **Kernel flags:** the command line is only `mem_sleep_default=deep` and
  `crashkernel=…`; no `pcie_aspm`/autosuspend flags are set now (an earlier
  one, if any, is gone).
- **NetworkManager power save:** already disabled
  (`/etc/NetworkManager/conf.d/default-wifi-powersave-on.conf`: `wifi.powersave = 2`).

### Workaround

`/etc/systemd/system-sleep/50-ath12k-reload`: `pre` → `modprobe -r ath12k_wifi7
ath12k`, `post` → `modprobe ath12k_wifi7`. Cost: a second or two without
Wi-Fi after each resume. Deployed by `setup/modules/57-wifi-resume.sh`
(needs sudo, so staged via `ccrun`).

Manual recovery without the hook (or if it fails): `wifi-driver-reload`
(alias, motoko only, `lib/aliases-motoko.sh`).

### If it comes back

1. Check the hook ran: `journalctl -b -t ath12k-sleep` (only logs on failure) and
   `journalctl -b -k | grep ath12k` around the resume.
2. If the card dies even with a fresh load, try `pcie_aspm=off` on the kernel
   command line (untested here), then a newer kernel/`linux-firmware`.
3. Cold-boot failures (no Wi-Fi after power-up) are Mode B; the hook does not
   touch them.
