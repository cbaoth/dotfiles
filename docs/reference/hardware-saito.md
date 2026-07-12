---
title: Hardware inventory — saito (LAN server)
hosts: [saito]
status: resolved
tags: [hardware, inventory, raid, storage]
updated: 2026-07-12
---

# saito — hardware

LAN server / NAS. Old, modest, and deliberately so — its job is storage, not
compute. Connected to motoko over 2.5 GbE.

## Core

| Part | Model |
| ---- | ----- |
| **CPU** | Intel i3-3240 (Ivy Bridge, dual-core) |
| **iGPU** | Intel Xeon E3-1200 v2 / 3rd Gen Core integrated graphics |
| **Board** | ASRock (exact model not recorded), Intel H77 Express LPC |
| **Chipset** | Intel 7 Series / C216 |
| **RAM** | not recorded (`sudo dmidecode -t memory`) |

Storage controllers: Intel 7 Series/C210 6-port SATA + ASMedia ASM1062.

### Network

| Interface | Device | Use |
| --------- | ------ | --- |
| `enp1s0` | Realtek RTL8125 **2.5 GbE** | **direct link to [motoko](hardware-motoko.md)** |
| `eth0` | Realtek RTL8111/8168/8411 Gigabit | LAN (onboard) |
| `wlp2s0` | Intel Wi-Fi 6 AX200NGW (PCIe) | WiFi + Bluetooth |
| `nordlynx` | — | NordVPN |

Also runs Docker and Determinate Nix.

The i3-3240 is the reason `setup/packages/server.list` keeps things lean, and why
[`docs/setup/unattended-upgrades.md`](../setup/unattended-upgrades.md) matters more
here than on the desktop — this box has long uptimes and little headroom.

## Storage

**Boot:** `/dev/sda` — Samsung SSD 840, Ubuntu root.

**Software RAID 5** (mdadm), the actual point of this machine:

| Array | Mount | Size | Members |
| ----- | ----- | ---- | ------- |
| `/dev/md0` | `/media/data` (ext4) | 25.47 TiB | 3× Toshiba MG07ACA1 (12.73 TiB each) |
| `/dev/md1` | `/media/stash` (ext4) | 7.28 TiB | 3× WDC WD40EFRX-68W (3.64 TiB each) |

**External backup (USB3):** **two** WD Elements 25A3 — `/dev/sdh` (mounted at
`/backup`) and `/dev/sdi`.

> The second one (`sdi`) was **not** in the original hand-written inventory; it
> turned up in `hwinfo --short` on 2026-07-12. A hand-maintained inventory drifts —
> re-run `hwinfo` after hardware changes and reconcile. Worth checking what `sdi`
> is actually for and whether it is in the backup rotation.

Both arrays are exported over Samba and mounted on motoko at `/srv/saito/data` and
`/srv/saito/stash` — see [../setup/mounts.md](../setup/mounts.md).

RAID 5 on 3 disks tolerates exactly **one** disk failure, and a rebuild on 12 TiB
drives takes a long time under full read load — during which a second failure loses
the array. The external `/backup` disk is not redundancy theatre; it is the actual
safety net.

Check array health with:

```bash
cat /proc/mdstat
sudo mdadm --detail /dev/md0
```

## See also

- [hardware-motoko.md](hardware-motoko.md) — the desktop
- [../setup/mounts.md](../setup/mounts.md) — how motoko mounts saito's shares
