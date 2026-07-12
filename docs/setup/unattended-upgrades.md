---
title: Unattended upgrades — taming boot-time updates
hosts: [motoko, saito]
status: workaround
tags: [apt, upgrades, systemd, boot]
updated: 2026-07-12
---

# Unattended upgrades

**Not automated** — this is a preference, not a fact, and the right answer
differs per machine.

## The problem

By default, apt applies certain updates *on boot* (offline, pre-downloaded).
That delays boot **and then shuts the machine down again**, which is
infuriating when you sat down to use it.

## Options

**1. Disable entirely** — simplest, and defensible on a desktop you update by hand:

```shell
sudo systemctl disable --now unattended-upgrades
```

```shell
# /etc/apt/apt.conf.d/20auto-upgrades  (defaults: both "1")
APT::Periodic::Enable "0";
APT::Periodic::Unattended-Upgrade "0";
```

**2. Restrict to security only** — edit `/etc/apt/apt.conf.d/50unattended-upgrades`
and trim `Unattended-Upgrade::Allowed-Origins` to just:

```
"${distro_id}:${distro_codename}";
"${distro_id}:${distro_codename}-security";
```

Test whether this actually changes anything for you — in practice it may not.

**3. Delegate to GNOME Software** — needed anyway for snap and flatpak, since
`unattended-upgrades` only handles apt. But apt is the one that carries the
security updates that matter most, so this trades away the important half.

**4. Manual** — with a cached "updates available" hint in the zsh prompt. Still
requires handling snap/flatpak separately.

Currently: **option 1 on motoko**, with updates applied deliberately.

## Idea: fold upgrades into bedtime-shutdown

The [bedtime-shutdown](../../system-scripts/bedtime-shutdown/) script force-shuts
the machine anyway — an obvious place to run pending upgrades first:

```shell
command -v unattended-upgrade >/dev/null && sudo unattended-upgrade
```

Two constraints if this is ever built: it must not *interrupt* an in-flight
upgrade, and it must not become a loophole that keeps the machine usable past
bedtime (which would defeat the script's entire purpose). Not implemented.

## needrestart

After a library upgrade, services keep running against the old, deleted `.so`.
`needrestart` finds them:

```shell
sudo apt-get install -y needrestart
sudo needrestart -m u -r i     # not yet fully verified
```

In [`setup/packages/server.list`](../../setup/packages/server.list) — it matters
far more on a long-uptime server than on a desktop that reboots weekly.

## GNOME Software knobs

```shell
gsettings list-recursively org.gnome.software

# defaults are true
gsettings set org.gnome.software download-updates false
gsettings set org.gnome.software download-updates-notify false
```
