---
title: Sunshine host — AppImage/Flatpak cannot do KMS capture (motoko)
hosts: [motoko]
status: open
revisit: when Moonlight/Sunshine is picked up again — try the Flatpak client first
tags: [sunshine, moonlight, streaming, kms, appimage, flatpak, wayland, udev, ufw]
updated: 2026-08-16
---

# Sunshine host — KMS capture vs. sandboxed packaging

**Status: open, parked.** The Moonlight *client* is a non-problem (Flatpak, same
version as the snap, works). The unresolved half is the **Sunshine host** on
motoko. Written down because it was about to be lost with the snap cleanup on
2026-08-16 — the notes below were never verified end to end.

Upstream: <https://github.com/LizardByte/Sunshine>

## The actual blocker

`setcap` is the documented way to give Sunshine the privileges it needs:

```shell
sudo setcap cap_sys_admin+p $(readlink -f ~/bin/sunshine)
```

**This does not work for AppImage or Flatpak builds.** The capability has to
land on the real binary, which lives inside the sandbox/image, not on the
launcher you point `setcap` at. Sunshine says so itself in its log:

```
AppImage and Flatpak do not support KMS capture. Use another capture method.
```

So the packaging choice and the capture method are coupled — this is not a
permissions bug to grind on. The realistic options when this is revisited:

1. A **native package** (`.deb` from the LizardByte releases, or their apt repo)
   so `setcap` has a real binary to attach to, and KMS capture works.
2. Stay on AppImage/Flatpak and use a **different capture method** (X11 or
   wlroots capture), accepting whatever that costs on a sway/Wayland session.

Option 1 is the one worth trying first, and it is also the one that fits this
repo (apt, `setup/` module, no `~/Applications` sprawl).

## What was set up, unverified

Kept verbatim for the next attempt. **None of this was reviewed** — the udev
rule in particular was AI-suggested and never checked against what Sunshine
actually needs.

```shell
mkdir -p ~/Applications/
wget -O ~/Applications/sunshine.AppImage \
  https://github.com/LizardByte/Sunshine/releases/latest/download/sunshine.AppImage
ln -s ~/Applications/sunshine.AppImage ~/bin/sunshine
```

Virtual input device access (uinput) plus group membership:

```shell
echo 'KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"' \
  | sudo tee /etc/udev/rules.d/85-sunshine-input.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
sudo usermod -aG input "$USER"
# group membership needs a re-login (or reboot) to take effect
```

Firewall openings for LAN clients (`<LAN_SUBNET>` — real value in `_local/`):

```shell
sudo ufw allow from <LAN_SUBNET> to any port 47984 proto tcp
sudo ufw allow from <LAN_SUBNET> to any port 47989 proto tcp
sudo ufw allow from <LAN_SUBNET> to any port 47990 proto tcp
sudo ufw allow from <LAN_SUBNET> to any port 48010 proto tcp
sudo ufw allow from <LAN_SUBNET> to any port 47998:48000 proto udp
sudo ufw enable && sudo ufw status numbered
```

## Loose ends for next time

- Adding the user to `input` grants read access to **every** input device,
  keyboard included. That is a real keylogging surface for anything running as
  that user — worth a second look before re-applying it, especially since the
  `uaccess` tag may already be sufficient on its own.
- `~/Applications` + a hand-made `~/bin` symlink is outside how this repo does
  anything else; `dotfiles-link` neither knows about nor cleans up that symlink.
- The udev rule and the ufw rules are the parts that survive a packaging
  change — they are worth keeping even if the AppImage is dropped.

## Related

- Moonlight *client*: Flatpak, same version as the snap that was removed
  2026-08-16. Snap was Canonical's channel, Flatpak is the cross-distro one;
  both official.
- [`../reference/package-managers.md`](../reference/package-managers.md) — why
  apt/flatpak and not snap.
