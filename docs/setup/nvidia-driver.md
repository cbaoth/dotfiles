---
title: NVIDIA driver and CUDA toolkit — where each comes from (motoko)
hosts: [motoko]
status: resolved
tags: [nvidia, cuda, apt, pinning, kernel, steam]
updated: 2026-10-26
---

# NVIDIA driver and CUDA toolkit

Steady state since 2026-10-26 (Ubuntu 26.10). Why it is set up this way:
[../troubleshooting/nvidia-dkms-kernel-7.3-panic.md](../troubleshooting/nvidia-dkms-kernel-7.3-panic.md).

## The split

| Part | Source | Packages |
| ---- | ------ | -------- |
| Driver + kernel modules | **Ubuntu archive** (`restricted`) | `nvidia-driver-615-open`, `linux-modules-nvidia-615-open-generic-hwe-26.04`, `libnvidia-gl-615:i386` |
| CUDA toolkit | **NVIDIA** `https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2604/x86_64/` | `cuda-toolkit-13-4` (+ 12.9, 13.2 still installed) |
| Container toolkit | NVIDIA `nvidia.github.io/libnvidia-container` | `nvidia-container-toolkit` |

- **Driver from Ubuntu**: prebuilt, Canonical-signed modules per kernel —
  no DKMS build that can break a kernel update. The `-generic-hwe-26.04`
  meta package pulls the matching module package for each new kernel.
- **Toolkit from NVIDIA**: newer CUDA than Ubuntu packages. The toolkit only
  needs a driver of the right series at runtime (`nvidia-smi` shows the max
  CUDA version the driver supports); it does not depend on NVIDIA's driver
  packages.
- **32-bit GL** (`libnvidia-gl-615:i386`) is what Steam / Proton need; it has
  to match the driver version exactly, which is easiest when both come from
  the same archive.

## The pin that keeps it that way

NVIDIA's `cuda-keyring` installs `/etc/apt/preferences.d/cuda-repository-pin-600`,
which pins **everything** labelled "NVIDIA CUDA" at 600 — driver included. So
on top of it:

```text
# /etc/apt/preferences.d/cuda-no-driver
# Driver comes from Ubuntu (prebuilt signed modules); CUDA repo only for toolkit.
Package: cuda-drivers* nvidia-* libnvidia-* libxnvctrl* xserver-xorg-video-nvidia* dkms dh-dkms
Pin: origin developer.download.nvidia.com
Pin-Priority: -1
```

The file name matters: apt reads `preferences.d` alphabetically and
`cuda-no-driver` sorts before `cuda-repository-pin-600`. Package-specific
pins beat the `Package: *` one either way, but keep it ordered so it never
depends on that subtlety.

Check:

```bash
apt-cache policy nvidia-open cuda-drivers   # every NVIDIA version at -1, Candidate: (none)
```

**Do not** run `apt install cuda` or `apt install cuda-drivers` — both are
NVIDIA's meta packages that would drag the DKMS driver back. Install a
specific toolkit instead: `apt install cuda-toolkit-13-N`.

## Upgrading the driver series

Ubuntu packages each series as `nvidia-driver-NNN-open` with matching
`linux-modules-nvidia-NNN-open-*`. Moving to a new series is an explicit
install of both (apt replaces the old series); check first that the module
package exists for the running and the newest installed kernel:

```bash
apt-cache search --names-only "^linux-modules-nvidia-.*-open-$(uname -r)$"
```

`ubuntu-drivers list` shows what Ubuntu recommends for the GPU.

## Known leftovers

- `nvidia-settings` and `libxnvctrl0` are NVIDIA-repo 615.71.10 (Ubuntu has
  no `libxnvctrl0`; `conky-all`, `libhwloc-plugins` need it). Frozen by the pin.
- Older kernels (7.0.x) have no NVIDIA module — nouveau only.
- CUDA toolkits 12.9 and 13.2 are still installed; remove with
  `apt purge 'cuda-*-12-9' 'cuda-*-13-2'` once nothing needs them.
