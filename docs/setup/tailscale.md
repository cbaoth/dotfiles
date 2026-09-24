---
title: Tailscale — tailnet client and Trayscale applet
hosts: [motoko, saito, 11001001]
status: resolved
tags: [tailscale, vpn, wireguard, flatpak, desktop]
updated: 2026-09-24
automated_by: setup/modules/35-tailscale.sh
---

# Tailscale

**Automated:** `system-setup 35-tailscale` (client) and `system-setup 20-flatpak`
(the Trayscale tray applet, `dev.deedles.Trayscale` in
`setup/packages/flatpak-desktop.list`).

## Install

The module runs the official installer
(<https://tailscale.com/docs/install/linux>):

```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

It adds Tailscale's own apt repo and installs the `tailscale` package, so from
then on apt handles updates. The module skips the installer if the `tailscale`
command already exists. Profiles: `desktop` and `server` (the Netdata streaming
in [monitoring.md](monitoring.md) runs over the tailnet).

## Trayscale needs an operator (manual, single-user desktops only)

```bash
sudo tailscale set --operator="$USER"
tailscale get operator    # verify (needs a recent client; older ones lack `get`)
```

Without it, Trayscale can show status but any toggle fails with "access
denied": tailscaled only takes changes from root or the operator user.
Trayscale itself shows a popup with this exact command.

**Deliberately not automated.** The operator can change the host's network
settings (routes, exit node, `tailscale down`) without sudo. On a single-user
desktop or notebook that user can sudo anyway, so nothing is lost. On a server
it is a needless privilege.

| Host | Operator |
| ---- | -------- |
| puppet, motoko (desktop/notebook) | set |
| saito (local server) | not set, leave it so |
| 11001001 (vserver) | not set, never |

On desktop hosts where no operator is set, the module prints the command as a
hint.

Sway starts the applet via `sway-run-after-waybar` (see [sway.md](sway.md)).

## Manual: joining the tailnet

Stays manual — it needs a browser login:

```bash
sudo tailscale up
```

The module prints a warning until the host has joined.

## Gotcha: NordVPN

NordVPN takes over the routes the tailnet needs. On saito it is disabled; on
motoko the tailnet is only reachable while NordVPN is off. See
[monitoring.md](monitoring.md).
