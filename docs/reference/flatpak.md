---
title: Flatpak permissions & overrides cheatsheet
hosts: [motoko]
status: resolved
tags: [flatpak, sandbox, permissions]
updated: 2026-07-12
---

# Flatpak permissions & overrides

Setup and app-specific quirks live in [../setup/flatpak.md](../setup/flatpak.md).
This is the syntax lookup.

## Inspect

```shell
flatpak info --show-permissions <AppID>    # everything, including overrides
flatpak override --show <AppID>            # only the overrides you added
```

Overrides are stored in `/var/lib/flatpak/overrides/<AppID>` (system) or
`~/.local/share/flatpak/overrides/<AppID>` (user).

## Grant filesystem access

```shell
sudo flatpak override --filesystem=/srv/saito <AppID>      # read-write
sudo flatpak override --filesystem=/srv/saito:ro <AppID>   # read-only
sudo flatpak override --filesystem=host <AppID>            # everything (last resort)
```

`--user` scopes it to your user instead of system-wide. Prefer `--user` unless
the app genuinely runs for multiple users.

## Revoke / reset

```shell
flatpak override --nofilesystem=host <AppID>   # revoke one grant
flatpak override --reset <AppID>               # drop ALL overrides for the app
```

Note the asymmetry: `--nofilesystem=X` revokes a specific grant, it does not deny
access that comes from the app's own manifest.

## Environment variables

```shell
flatpak override --user --env=QT_QPA_PLATFORM=xcb <AppID>
```

Scope these to the single app that needs them. Setting Qt/GTK platform hints
globally degrades every other sandboxed app — see the XnViewMP note in
[../setup/flatpak.md](../setup/flatpak.md).

## Run with host access

```shell
flatpak run --usr-path=/usr <AppID>    # let the app see host binaries
```

## FUSE

For an app to see a FUSE mount (Cryptomator) made by another user, uncomment in
`/etc/fuse.conf`:

```
user_allow_other
```

## Search & maintain

```shell
flatpak search <term>
flatpak update
flatpak remotes --columns=name
```

[Flatseal](https://flathub.org/apps/com.github.tchx84.Flatseal) is the GUI for
all of the above and is worth having installed.
