---
title: Security — KeePassXC, FIDO2/U2F, firewall
hosts: [motoko]
status: workaround
tags: [security, pam, u2f, fido2, keepassxc, ufw]
updated: 2026-07-12
---

# Security

**Not automated.** Editing `/etc/pam.d/*` unattended is how you lock yourself out
of your own machine. Every change below should be made with a **second terminal
already open and authenticated as root**, so you can undo it when it goes wrong.

## KeePassXC

**From flatpak** (`org.keepassxc.KeePassXC`), in
[`setup/packages/flatpak-desktop.list`](../../setup/packages/flatpak-desktop.list).

The reasoning is easy to get backwards. A *sandboxed browser* cannot do native
messaging to KeePassXC — so the **browsers** stay native (see
[browsers.md](browsers.md)). But a sandboxed **KeePassXC** serving a native
browser works fine, and the flatpak tracks upstream far more closely (2.7.12 vs
apt's 2.7.10). That matters, because the browser extension complains when
KeePassXC is too old — so flatpak's freshness is what *fixes* the integration,
not what breaks it. Full rule:
[../reference/package-managers.md](../reference/package-managers.md).

KeePassXC also manages the SSH agent (`SSH_AUTH_SOCK`) on motoko. Note this
interacts badly with agent forwarding: if an intermediate host runs its own
KeePassXC or gnome-keyring, it shadows `SSH_AUTH_SOCK` and breaks `ssh -A`.

## FIDO2 / U2F hardware key

Packages are in `desktop.list`. List connected keys:

```shell
fido2-token -L          # generic
# ykman list            # genuine YubiKey (yubikey-manager)
```

### Where to store the key mapping

**In `$HOME`** (default) — simple, but fails if `$HOME` is encrypted separately
from root: the file is not available at the point auth is needed.

```shell
mkdir -p ~/.config/Yubico && pamu2fcfg >> ~/.config/Yubico/u2f_keys
```

**In `/etc`** — required for the encrypted-home case:

```shell
pamu2fcfg | sudo tee -a /etc/u2f_keys
sudo chown root:root /etc/u2f_keys
sudo chmod 600 /etc/u2f_keys
```

### Enabling it

Appending to `/etc/pam.d/common-auth` enables the key everywhere at once — login,
`sudo`, ssh:

```
# Hardware key first; if it works, we are done.
#   sufficient → on success, return immediately and never ask for a password
#   required   → demand BOTH key and password
#   cue        → prompt the user to touch the key
#   nouserok   → users *without* a key can still authenticate
#                (drop this and anyone without a key is locked out)
auth sufficient pam_u2f.so authfile=/etc/u2f_keys cue nouserok
```

Omit `nouserok` and you have locked out every user who has not enrolled a key.
That includes you, on the console, right now. Keep it until every account is
enrolled.

### The `sudo -n true` trap

Some tooling (notably the zsh `sudo` plugin) calls `sudo -n true` on shell
startup. With the config above, that prompts for a key touch **every time you
open a terminal**.

*Preferred fix* — restrict the key to interactive auth (`-n` means
non-interactive):

```
auth sufficient pam_u2f.so authfile=/etc/u2f_keys cue nouserok interactive
```

*Not fully verified.* If it misbehaves, `nodetect` reportedly helps.

*Fallback* — allow just that one command without auth:

```shell
sudo visudo -f /etc/sudoers.d/sudo-true
```

```
# Some tooling (zsh sudo plugin) probes with `sudo -n true` on shell startup.
%sudo   ALL=(ALL) NOPASSWD: /usr/bin/true
```

## Firewall (ufw)

Installed by default; just needs enabling. Default policy is deny-in/allow-out,
which is what you want.

```shell
sudo ufw enable
sudo ufw app list      # profiles from installed apps (CUPS, etc.)
gufw                   # GUI; supports Home/Office/Public profiles
```

## Cryptomator

**From apt, via PPA** — `ppa:sebastian-stenzel/cryptomator`. In
[`setup/packages/desktop.list`](../../setup/packages/desktop.list); the module
warns and skips it if the PPA is not configured.

```shell
sudo add-apt-repository -y ppa:sebastian-stenzel/cryptomator
sudo apt-get update && sudo apt-get install -y cryptomator
```

> **Do not delete `/etc/apt/sources.list.d/sebastian-stenzel-ubuntu-cryptomator-*.sources`.**
> It looks like a leftover from an abandoned experiment. It is not — it is what
> feeds the installed package (`1.19.3-0ppa1`). Remove it and Cryptomator
> silently stops getting updates.

Upstream also ships a flatpak (same version), AppImage, AUR, and nix builds. If
this ever moves to flatpak it will need explicit `--filesystem` overrides to
reach mounts ([../reference/flatpak.md](../reference/flatpak.md)) plus
`user_allow_other` in `/etc/fuse.conf` — one more reason apt is currently the
lower-friction choice.

Cryptomator's future role is the **sensitive-tier vault** (health, personal,
paperwork) synced via own Nextcloud — see `projects/06-future-ideas.md` in the
private notes repo.

## See also

- [power-management.md](power-management.md) — `pam_time` and the sudoers escape hatch
