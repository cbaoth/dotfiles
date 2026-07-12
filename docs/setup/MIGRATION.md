---
title: Obsidian → docs/ migration status
hosts: [all]
status: open
tags: [meta, migration, notes]
updated: 2026-07-12
---

# Obsidian → `docs/` migration status

Tracking the split of the old Obsidian system notes into the three buckets.
Delete this file when the table is empty.

## Done

**`001 Setup Basics (Ubuntu).md`** (2,093 lines) — split into:

| Destination | Content |
| ----------- | ------- |
| [`setup/modules/00-apt-base.sh`](../../setup/modules/00-apt-base.sh) + `packages/*.list` | mirror, upgrade, base/desktop/server packages, default editor |
| [`setup/modules/10-locale.sh`](../../setup/modules/10-locale.sh) | locales |
| [`setup/modules/20-flatpak.sh`](../../setup/modules/20-flatpak.sh) | flatpak, flathub, apps, NAS overrides |
| [`setup/modules/30-docker.sh`](../../setup/modules/30-docker.sh) | docker |
| [`setup/modules/40-fonts.sh`](../../setup/modules/40-fonts.sh) | nerd fonts |
| [ubuntu-base.md](ubuntu-base.md), [locale.md](locale.md), [flatpak.md](flatpak.md), [docker.md](docker.md), [fonts.md](fonts.md) | the "why" for each of the above |
| [browsers.md](browsers.md), [security.md](security.md), [power-management.md](power-management.md), [mounts.md](mounts.md), [unattended-upgrades.md](unattended-upgrades.md) | deliberately manual |
| [../troubleshooting/hibernate-nvidia.md](../troubleshooting/hibernate-nvidia.md) | the NVIDIA hibernate saga |
| [../reference/apt.md](../reference/apt.md), [../reference/flatpak.md](../reference/flatpak.md) | cheatsheets |

**Dropped on purpose** (obsolete, superseded, or noise): Anaconda/Miniconda
(use `uv`), `~/.pam_environment` (deprecated), the swap-fragmentation theory
(a red herring — see the hibernate note), assorted `TODO: not tested` blocks
that were never verified.

## To do

| Source note | Plan | Sanitize first |
| ----------- | ---- | -------------- |
| `015 Setup Gnome Desktop (Ubuntu).md` (440 lines) | Almost entirely `gsettings` → becomes `setup/modules/45-gnome-settings.sh` + `docs/setup/gnome.md`. The keybindings section is the interesting part. | — |
| `090 System (Kernel & Boot).md` (136 lines) | Split: GRUB console-recovery → `troubleshooting/`; WiFi/NordVPN startup problems → `troubleshooting/`. | **Yes — contains real WiFi SSIDs.** |
| `010 Wayland & Desktop.md` (57 lines) | Chorded keybindings (keyd/xremap) → merge with the existing [`docs/misc/keyd/`](../misc/keyd/) and [`docs/misc/xremap/`](../misc/xremap/). | — |
| Remaining app installs from `001` (ULauncher + its ~25 extensions, JDownloader, WINE, browsers, image/AV apps) | Mostly reference-shaped. ULauncher's extension list is long and opinionated → probably its own `setup/ulauncher.md`. | — |

## Sanitization rules

This repo is **public**. Before migrating anything, strip:

- **WiFi SSIDs** — they geolocate the household via wigle.net. `090 System` has two.
- **Disk / partition UUIDs** — `001` had four NTFS filesystem UUIDs.
- **MAC addresses** — `001` had a Bluetooth headphone MAC in the ULauncher section.
- **Swap offsets, credentials, keys.**

Replace with placeholders (`<SSID>`, `UUID=<C_UUID>`) and keep real values in the
gitignored `_local/`.

Verify before committing:

```bash
grep -rIEn '([0-9a-f]{2}:){5}[0-9a-f]{2}|[0-9A-F]{8}-[0-9A-F]{4}|[0-9A-F]{16}' docs/ setup/
```
