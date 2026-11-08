---
title: Hardware constraints — saito (LAN server)
hosts: [saito]
status: resolved
tags: [hardware, raid, storage]
updated: 2026-11-07
---

# saito — hardware constraints

LAN server / NAS. Old, modest, and deliberately so: its job is storage, not
compute. Connected to motoko over a direct 2.5 GbE link.

This note holds only the reasoning that outlives the parts list. The inventory
(models, serials, firmware, purchase dates) is private and lives in
`~/notes/systems/saito/hardware.md`.

## Why it stays lean

An i3-3240 with little RAM is the reason `setup/packages/server.list` is short,
and why [`docs/setup/unattended-upgrades.md`](../setup/unattended-upgrades.md)
matters more here than on the desktop: this box has long uptimes and little
headroom.

## RAID 5 risk

Storage is two mdadm RAID 5 arrays of three disks each. RAID 5 on 3 disks
tolerates exactly **one** disk failure, and a rebuild on 14 TB drives takes a long
time under full read load, during which a second failure loses the array. The
external backup disk is not redundancy theatre; it is the actual safety net.

Check array health with:

```bash
cat /proc/mdstat
sudo mdadm --detail /dev/md0
```

A hand-maintained inventory drifts: a second external disk once turned up in
`hwinfo --short` that no note listed. Reconcile after any hardware change.

## See also

- [hardware-motoko.md](hardware-motoko.md) — the desktop
