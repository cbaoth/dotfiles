---
title: Mount points — NTFS and Samba/CIFS
hosts: [motoko]
status: resolved
tags: [fstab, ntfs, samba, cifs, systemd]
updated: 2026-07-12
---

# Mount points

**Not automated.** Every value here is machine-specific (partition UUIDs, share
names, credentials) and getting `/etc/fstab` wrong can leave a machine that will
not boot. Real UUIDs and passwords live in `_local/` (gitignored), never here —
this repo is public.

## Why `/mnt` and not `/media`

`/media` is for system-managed, dynamic, temporary mounts — GVFS/Nautilus owns
it. Putting static fstab mounts there invites conflicts. Use `/mnt` for local
disks and `/srv/<host>/` for network shares.

## fstab options, decoded

The option soup is doing real work. Worth understanding rather than copying:

| Option | Why |
| ------ | --- |
| `x-systemd.automount` | Do **not** mount at boot. Create a trigger; mount on first access. This is the single most useful one — it stops a dead NAS from hanging boot. |
| `noauto` | Belt and braces with the above: never mount at boot. |
| `nofail` | Boot continues even if the device is missing. |
| `_netdev` | Needs the network — prevents mount attempts before WiFi is up. |
| `x-systemd.after=network-online.target` | Narrows the WiFi race window further. |
| `x-systemd.mount-timeout=10s` | Prevents effectively infinite waits on startup. |
| `x-systemd.idle-timeout=60s` | Unmount after 60s idle — keeps the connection clean. |
| `soft` | Do not wait forever on a dead server. |
| `serverino` | Use server-provided inode numbers; prevents inode weirdness. |
| `uid=1000,gid=1000` | Force ownership. Fixes "Operation not supported" when creating dirs or moving files (a classic GVFS-without-`gio` symptom). |
| `vers=3.1.1` | Pin the SMB version — avoids negotiation weirdness, often stabilises things. |
| `user` | Lets the desktop user `mount`/`umount` without `sudo`. |

## NTFS (dual-boot Windows partitions)

Find the partitions:

```shell
lsblk -f | grep ntfs      # UUIDs of the Windows filesystems
```

```
# /etc/fstab — auto-mount Windows filesystems, full access for desktop user (1000)
UUID=<C_UUID>  /mnt/c  ntfs3  defaults,uid=1000,gid=1000,umask=000,x-systemd.automount,x-systemd.mount-timeout=3s,noauto,nofail,user  0  0
UUID=<D_UUID>  /mnt/d  ntfs3  defaults,uid=1000,gid=1000,umask=000,x-systemd.automount,x-systemd.mount-timeout=3s,noauto,nofail,user  0  0
```

```shell
sudo mkdir -p /mnt/{c,d,e,f}
sudo systemctl daemon-reload   # required, or fstab changes are silently ignored
mount /mnt/c                   # as regular user, thanks to `user`
```

## Samba / CIFS

Credentials go in a root-owned file, never in fstab:

```shell
sudo mkdir -p /etc/samba
sudo tee /etc/samba/credentials-<host> << 'EOF'
username=<user>
password=<password>
EOF
sudo chmod 660 /etc/samba/credentials-<host>
sudo chown :<user> /etc/samba/credentials-<host>
```

```
# /etc/fstab
//<host>/<share>  /srv/<host>/<share>  cifs  credentials=/etc/samba/credentials-<host>,uid=1000,gid=1000,iocharset=utf8,vers=3.1.1,x-systemd.automount,x-systemd.idle-timeout=60s,noauto,nofail,_netdev,soft,serverino,x-systemd.mount-timeout=10s,x-systemd.after=network-online.target,x-systemd.requires=network-online.target,user  0  0
```

```shell
sudo apt-get install -y cifs-utils   # else mount fails with "No route to host"
sudo mkdir -p /srv/<host>/<share>
sudo systemctl daemon-reload
mount /srv/<host>/<share>
```

`cifs-utils` missing produces **"No route to host"**, which sends you off
debugging the network for an hour. It is in
[`setup/packages/desktop.list`](../../setup/packages/desktop.list) for exactly
this reason.

## Ad-hoc, user-only alternative

No fstab, no root — GVFS mount, visible under `/run/user/$(id -u)/gvfs/`:

```shell
gio mount smb://<host>/<share>
```

## See also

- [power-management.md](power-management.md) — network mounts are the usual reason
  a machine refuses to sleep; lazy-unmount handles it.
- [flatpak.md](flatpak.md) — sandboxed apps cannot see these mounts without an
  explicit override.
