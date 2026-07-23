---
title: Security — KeePassXC, FIDO2/U2F, firewall
hosts: [motoko]
status: workaround
tags: [security, pam, u2f, fido2, keepassxc, ufw, keyring, swayidle, sleep]
updated: 2026-07-23
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

## Locking secrets on screen lock and suspend

**Automated:** [`bin/lock-secrets`](../../bin/lock-secrets), wired into the
swayidle hooks in `dotfiles/.config/sway/config`.

### The problem

Locking the screen did **not** lock anything else. After `swaylock` engaged, the
KeePassXC database was still unlocked, the gnome-keyring `Default_keyring` was
still unlocked, and — the part that is easy to miss — the SSH agent still held
usable keys:

```shell
ls ~/.ssh/          # no private keys at all
ssh-add -l          # ...yet two identities loaded
```

There are no key files on disk. Both identities come from KeePassXC's agent
integration (`[SSHAgent] Enabled=true`), pushed into the gcr agent at
`$XDG_RUNTIME_DIR/gcr/ssh`. So an unlocked KeePassXC is not merely "passwords
readable" — it is **live SSH access to every host those keys reach**.

### Why the KeePassXC checkbox does not fix it

KeePassXC's *"Lock databases when session is locked or the screen saver starts"*
is enabled by default and **never fires under Sway**. It waits for the
logind / `org.freedesktop.ScreenSaver` **Lock** signal, and `swaylock` does not
emit it — swaylock is a plain Wayland surface plus a PAM check, it does not talk
to logind at all. The signal flows the *other* way: `swayidle` listens for that
signal so `loginctl lock-session` works.

*"Lock databases after inactivity"* (`Security/LockDatabaseIdle`) has the same
root problem: its idle detection has no Wayland path.

So this needs an explicit push, not a setting.

### The fix

`lock-secrets` locks each store over D-Bus, best effort and independent — an
absent or already-locked store is skipped, and it always exits 0 so it can be
chained after `swaylock` without breaking the caller:

| Store | Method |
| ----- | ------ |
| KeePassXC | `org.keepassxc.KeePassXC.MainWindow.lockAllDatabases` on `/keepassxc` |
| gnome-keyring | `org.freedesktop.Secret.Service.Lock` per collection |
| SSH agent | `ssh-add -D` — opt-in via `--ssh` (see below) |

The KeePassXC call works against the **flatpak** build unchanged: its bus name is
proxied onto the session bus by `xdg-dbus-proxy`.

```shell
lock-secrets --dry-run     # show what would be locked
lock-secrets -v            # lock, and say what happened
```

Wiring, in `dotfiles/.config/sway/config`:

```
exec swayidle -w \
       timeout 900  'swaylock -f -c 000000' \
       timeout 1800 '~/bin/lock-secrets' \
       ...
       before-sleep 'swaylock -f -c 000000; ~/bin/lock-secrets' \
```

**The tiering is deliberate.** The screen locks at 15min — cheap to undo, one
password. Secrets lock at 30min — expensive to undo, the master password. But
always before sleep, where the machine is left unattended by intent.

### `--ssh` is opt-in

KeePassXC removes its own keys from the agent when the database locks, provided
the entry has *"Remove key from agent when database is closed or locked"*
checked. Verify rather than assume:

```shell
lock-secrets -v && ssh-add -l     # want: "The agent has no identities."
```

If keys survive, either tick that box per entry or add `--ssh` to the swayidle
hooks. `--ssh` is not the default because it would also flush identities added
by other means, which no longer applies here but might on another host.

### What this is and is not worth

Be clear-eyed. Against an attacker **already executing code as your user**, this
is not a boundary — they can keylog the master password, hook the prompt, or
simply wait for the next unlock. What it does buy:

- **Smash-and-grab payloads.** Most infostealers dump once and leave. Locked
  stores at that moment yield nothing.
- **Suspend with keys in RAM.** A suspended machine holds the unlocked database
  and the agent keys in memory; whoever walks off with it has them. This is the
  strongest argument for the `before-sleep` hook — and for preferring
  **hibernate** when leaving for real, given encrypted swap.
- Core dumps, crash reports, memory scrapes.

The bigger lever, if going further, is not more locking but shrinking what a live
agent can do — per-use confirmation on the SSH keys.

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
- [power-management.md](power-management.md#every-sleep-path-goes-through-logind--which-is-what-makes-locking-work)
  — why `before-sleep` catches *every* suspend route, including the power button
