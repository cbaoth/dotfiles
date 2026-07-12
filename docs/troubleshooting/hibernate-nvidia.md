---
title: Hibernate does not work with the NVIDIA driver (motoko)
hosts: [motoko]
status: abandoned
revisit: 2026-12
tags: [nvidia, power, hibernate, kernel, grub]
updated: 2026-07-12
---

# Hibernate does not work with the NVIDIA driver

**Verdict: abandoned.** Everything below was rolled back on motoko. The swap file
is back to 16 GB, the GRUB `resume=` parameters are gone, and the NVIDIA sleep
services are disabled. Do not re-run these experiments before the conditions in
[Before trying again](#before-trying-again) are met.

The short version: the proprietary NVIDIA driver refuses to freeze, and even the
official workaround (`NVreg_PreserveVideoMemoryAllocations`) did not fix it on
this hardware. Along the way, hibernate attempts also knocked out WiFi in a way
that needed multiple power-off reboots to recover — so the failure mode is worse
than "it just doesn't hibernate".

## What was tried, in order

### 1. Enabling hibernation at all

```shell
sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

With the swap file on an encrypted (LUKS + LVM) root, the kernel also needs to be
told where to resume from — both the partition UUID and the offset of the swap
file within it:

```shell
# find the LUKS partition UUID
lsblk -o NAME,UUID,FSTYPE,MOUNTPOINT | grep -E "crypto|crypt|swap|/"

# find the swap file's physical offset (first physical_offset value)
sudo filefrag -v /swap.img | head -5
```

Then `resume=UUID=<luks-partition-uuid> resume_offset=<offset>` in
`GRUB_CMDLINE_LINUX_DEFAULT`, plus `/etc/initramfs-tools/conf.d/resume`, plus
`update-grub` and `update-initramfs -u -k all`.

> Real UUIDs and offsets are deliberately not recorded here — this repo is
> public. They are machine-specific and change whenever the swap file is
> recreated; re-derive them with the commands above.

### 2. Failure: "Sleep verb 'hibernate' is not configured"

```
Call to Hibernate failed: Sleep verb 'hibernate' is not configured or
configuration is not supported by kernel
```

```shell
sudo dmesg | grep hibernation
#   Lockdown: systemd-logind: hibernation is restricted; see man kernel_lockdown.7
mokutil --sb-state
#   SecureBoot enabled
```

**Cause: Secure Boot.** Kernel lockdown mode blocks hibernation.
**Fix:** disable Secure Boot in the BIOS.

Implications of disabling it — negligible for a personal workstation, but note
that Windows 11 will complain: BitLocker (if used) will ask for the recovery key
on reboot, Windows Hello needs resetting, and you get to re-login to the
Microsoft account once.

### 3. Failure: "Specified resume device is missing"

```
Call to Hibernate failed: Specified resume device is missing or is not an
active swap device
```

Check the kernel actually sees the resume device — these three must agree:

```shell
cat /sys/power/resume
cat /sys/power/resume_offset
grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=.*resume_offset' /etc/default/grub \
  | sed -r 's/.*resume_offset=([0-9]+).*/\1/'
```

**Swap file fragmentation was a red herring.** With LVM the swap file is
essentially always fragmented (`filefrag` reports dozens of extents) and it does
not matter. Do not go down this path; recreating the swap file with `fallocate`
to "fix" fragmentation wastes an evening.

### 4. The actual blocker: the NVIDIA driver refuses to freeze

```shell
sudo dmesg | grep -A2 -B2 "hibernation"
```

```log
nvidia 0000:01:00.0: PM: pci_pm_freeze(): nv_pmops_freeze [nvidia] returns -5
nvidia 0000:01:00.0: PM: failed to freeze async: error -5
```

`-5` is `EIO`. The driver aborts the hibernation. This is a well-known,
long-standing issue with the closed-source driver.

The documented fix is to enable NVIDIA's own power-management services, which
ship with the driver but are **not** enabled by default:

```shell
sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service
echo "options nvidia NVreg_PreserveVideoMemoryAllocations=1" \
  | sudo tee /etc/modprobe.d/nvidia-power.conf
sudo update-initramfs -u -k all
sudo reboot
```

**It did not work.** Nor did forcing logind and sleep config:

```shell
# /etc/systemd/logind.conf.d/hibernate.conf → AllowSuspend=yes, AllowHibernation=yes
# /etc/systemd/sleep.conf.d/hibernate.conf  → AllowHibernation=yes, HibernateMode=shutdown
busctl call org.freedesktop.login1 /org/freedesktop/login1 \
  org.freedesktop.login1.Manager CanHibernate
#   still "na"
```

Note that `systemctl restart systemd-logind` kills the Wayland session and may
land you at the login screen.

Confusingly, the driver *claims* to support it:

```shell
cat /proc/driver/nvidia/suspend
#   suspend hibernate resume
```

### 5. Do not do this

```shell
sudo /usr/bin/nvidia-sleep.sh hibernate       # ← ran this alone. Don't.
sudo sh -c 'echo shutdown > /sys/power/disk && echo disk > /sys/power/state'
```

Running only the first line shut the GPU down (black screen) and required
several power-off reboots to get WiFi back. The two commands are not independent
steps; the first one is a preparation that leaves the machine in a broken state
if the second never runs.

## Rollback (what the machine looks like now)

1. Removed `resume=UUID=...` and `resume_offset=...` from
   `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`; ran `update-grub`.
2. Deleted `/etc/initramfs-tools/conf.d/resume`,
   `/etc/modprobe.d/nvidia-power.conf`,
   `/etc/systemd/sleep.conf.d/hibernate.conf`,
   `/etc/systemd/logind.conf.d/hibernate.conf`.
3. `sudo systemctl disable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service`
4. Shrank the swap file from 100 GB back to 16 GB (it had been sized to hold all
   96 GB of RAM, which is only needed for hibernate).
5. `sudo update-initramfs -u -k all && sudo reboot`

## Before trying again

Do not retry until all three are plausibly true — otherwise this is just
re-running a known failure:

- **systemd** with improved LVM+LUKS swap validation (or a known workaround).
- **A more stable NVIDIA driver** where `NVreg_PreserveVideoMemoryAllocations`
  actually holds on this hardware.
- **More stable WiFi/power-management** for this board — the collateral WiFi
  damage is what makes the failure expensive rather than merely disappointing.

The hardware was very new at the time of writing; the working assumption is that
kernel and driver updates fix this rather than any configuration change.

## See also

- [../setup/power-management.md](../setup/power-management.md) — the sleep/power
  configuration that *is* in place (inhibitors, lazy unmount on sleep).
