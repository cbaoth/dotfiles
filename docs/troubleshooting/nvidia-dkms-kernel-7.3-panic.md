---
title: Kernel 7.3 panic after the 26.10 upgrade — NVIDIA DKMS build fails (motoko)
hosts: [motoko]
status: resolved
tags: [nvidia, cuda, dkms, kernel, release-upgrade, apt, grub, initramfs]
updated: 2026-10-26
---

# Kernel 7.3 panic after the 26.04 → 26.10 upgrade

**Resolved** by moving the NVIDIA driver off NVIDIA's CUDA repo (DKMS) onto
Ubuntu's prebuilt, signed kernel modules. Steady state:
[../setup/nvidia-driver.md](../setup/nvidia-driver.md).

## Symptom

First boot after `do-release-upgrade` 26.04 (resolute) → 26.10 (stonking):
kernel panic on the new default kernel `7.3.0-9-generic`. The old `7.0.0-38`
kernel (GRUB *Advanced options*) booted fine.

Re-running `sudo dpkg --configure -a` from 7.0 failed every time:

```text
Autoinstall of module nvidia/615.71.10 for kernel 7.3.0-9-generic (x86_64)
Building module(s)......(bad exit status: 2)
run-parts: /etc/kernel/postinst.d/dkms exited with return code 1
dpkg: error processing package linux-image-7.3.0-9-generic (--configure)
```

## Cause

The driver came from **NVIDIA's CUDA repo** (`nvidia-open` 615.71.10, built
locally with DKMS), not from Ubuntu. Its source does not compile against 7.3:

```text
nvidia/os-interface.c:3031:48: error: passing argument 1 of
'dmem_cgroup_register_region' makes pointer from integer without a cast
```

The failed DKMS hook aborts the kernel's postinst, so `linux-image-7.3.0-9`
and `linux-headers-7.3.0-9` stay half-configured (`iF`) and **no
`/boot/initrd.img-7.3.0-9-generic` is ever generated** — but
`vmlinuz-7.3.0-9-generic` is already in `/boot` and `GRUB_DEFAULT=0` boots it.
A kernel without its initramfs: the panic.

> **Check before rebooting after any kernel update:**
> `ls /boot/initrd.img-$(dpkg -l 'linux-image-[0-9]*' | awk '/^ii/{print $2}' | sort -V | tail -1 | sed 's/linux-image-//')`
> and `dpkg -l | awk '$1 ~ /^i[UF]$/'` (must be empty). A failed DKMS build is
> only visible in the apt output, which is easy to miss in a release upgrade.

## Why the archive driver fixes it

Ubuntu's archive carries `linux-modules-nvidia-615-open-7.3.0-9-generic`:
the same driver series (615.71.**09**), patched by Canonical, **prebuilt and
signed** for exactly this kernel. No DKMS build runs, so this failure mode is
gone for future kernel updates too (the `-generic-hwe-26.04` meta package
follows each new kernel). Secure Boot needs no MOK for these modules.

NVIDIA's repo only had 615.71.10 for both its `ubuntu2404` and `ubuntu2604`
trees — switching CUDA repos alone would not have helped.

## What it took (and what went wrong on the way)

1. **Pin first**, so NVIDIA's repo can never pull its driver back in:
   `/etc/apt/preferences.d/cuda-no-driver` (see the setup note).
2. **CUDA repo `ubuntu2404` → `ubuntu2604`** (old one was broken anyway, see
   below), installing `cuda-keyring_1.1-1_all.deb` from the `ubuntu2604` tree.
3. **One apt transaction** installing `nvidia-driver-615-open`,
   `linux-modules-nvidia-615-open-generic-hwe-26.04`, `libnvidia-gl-615:i386`
   (32-bit GL for Steam — NVIDIA's repo never installed it) and removing the
   18 NVIDIA-repo driver packages (`nvidia-open`, `cuda-drivers`,
   `nvidia-dkms-open`, `libnvidia-*`, …) plus `libnvidia-egl-gbm1`
   (`libnvidia-gl-615` conflicts with it).

   **Failed halfway.** `apt-get -s` simulated it cleanly, but the real unpack
   of `libnvidia-gl-615` (amd64) hit:

   ```text
   trying to overwrite '/usr/lib/x86_64-linux-gnu/libnvidia-egl-wayland2.so.1.0.2',
   which is also in package libnvidia-egl-wayland21:amd64 (1.0.2-1ubuntu1)
   ```

   `libnvidia-gl-615` bundles the files of `libnvidia-egl-wayland21`,
   `libnvidia-egl-xcb1` and `libnvidia-egl-xlib1` but declares no
   `Replaces:` for them — a packaging bug. A simulation cannot see file
   conflicts; they surface only at unpack time. Left the system with the old
   driver removed and the new one partly unpacked: **do not reboot in that
   state**, no kernel has a working driver.
4. **Dead end:** adding the three egl packages as removals to the same
   `apt-get install` (`libnvidia-egl-wayland21-` …). apt still unpacks the
   new package *before* removing the old ones; same error.
5. **What worked:** two separate dpkg runs —
   `dpkg -r libnvidia-egl-wayland21 libnvidia-egl-xcb1 libnvidia-egl-xlib1`
   (nothing depends on them), then `dpkg -i` of the cached
   `libnvidia-gl-615_…_amd64.deb`. That `dpkg -i` exits 1 ("dependency
   problems — leaving unconfigured"), which is expected: the dependencies
   are unpacked but not configured yet. `dpkg --configure -a` +
   `apt-get install -f` then configured all 31 pending packages, including
   the 7.3 kernel, its initrd and GRUB.
6. Rebooted into 7.3: `nvidia-smi` shows 615.71.09 on the RTX 4070 Ti, CUDA
   UMD 13.4, and voxtral inference ran on the GPU as before.

## Side effects

- **The 7.0 kernels have no NVIDIA module any more** (removing
  `nvidia-dkms-open` removed their DKMS builds; 26.10 ships no prebuilt
  modules for them). They still boot on nouveau — rescue only, no CUDA.
- `nvidia-settings` and `libxnvctrl0` stay at NVIDIA's 615.71.10:
  `conky-all` and `libhwloc-plugins` depend on `libxnvctrl0`, which Ubuntu's
  archive does not carry. The pin freezes them; harmless within the 615 series.
- Leftover crash reports `/var/crash/nvidia-kernel-source-open.0.crash` (the
  first one also made apport fail with `Cannot create report: File exists`
  on every retry) and `libnvidia-gl-615.0.crash`.

## Same upgrade: three apt sources with key failures

Found with `apt-sources keys`; all are apt's crypto policy, not the repos
being down.

| Source | Failure | Resolution |
| ------ | ------- | ---------- |
| CUDA `ubuntu2404` | Key `EB693B30…` SHA1-bound; sqv rejects SHA1 since 2026-02-01; keyserver copy identical | Moved to `ubuntu2604` (new key `14BAFBC7…`) |
| graphics-drivers PPA | Key `2388FF3B…` SHA1-bound; no `stonking` suite yet (404) | Disabled — nothing installed came from it |
| OneDrive (OBS) | Key `63CE457B…` expired 2026-10-24 | Same fingerprint renewed (to 2028-12) in the vendor's `Release.key`; keyserver still had the expired copy |

`apt-sources keys` only re-fetches from keyserver.ubuntu.com, so it reported
"refreshing the key does not help" for the OBS key. The vendor's own
`Release.key` was the renewed one — always try that before giving up.

A fourth source turned up afterwards: the **local CUDA 13.2 installer repo**
(`cuda-repo-ubuntu2404-13-2-local`, 3.9 GB under `/var/`) still offered
NVIDIA's DKMS driver 595.58.03 at priority 600, past the new pin (which only
matches `developer.download.nvidia.com`). Purged, sources file and its
keyring archived in `/var/backups/nvidia-switch-2026-10-26/`.

## Not automated

The driver swap is a one-off judgement call (which driver source, which
packages to drop, when it is safe to reboot) and ran through a sequence of
staged, dry-run-first scripts. No `setup/` module. The pin file is the only
reusable piece; it is documented in the setup note.
