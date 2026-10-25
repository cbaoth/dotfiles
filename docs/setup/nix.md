---
title: Nix (upstream, from apt)
hosts: [motoko, puppet, saito]
status: in-progress
tags: [nix, packaging, determinate, apt]
updated: 2026-10-25
automated_by: setup/modules/23-nix.sh
---

# Nix (upstream, from apt)

**Automated:** `system-setup 23-nix`. Installs Nix only on profiles that have
a `setup/packages/nix-<profile>.list`, then the flake refs listed there
(currently desktop: `wayland-pipewire-idle-inhibit`).

## What and why

- **Package:** Ubuntu's `nix-setup-systemd` (pulls `nix-bin`). This is the
  upstream Nix source, multi-user, `nix-daemon` under systemd, `/nix` created
  via tmpfiles.d. apt updates it; `apt purge nix-setup-systemd nix-bin`
  removes it. Nothing is appended to shell rc files.
- **Not Determinate Nix** (used 2026-08 to 2026-10 on motoko, saito, puppet).
  Its Nix CLI is open source, but the `determinate-nixd` daemon it requires
  is closed source and it defaults `nixpkgs` to Determinate's FlakeHub. Its
  installer stopped installing upstream Nix in 2026. It also cost about 0.6 s
  per shell start (`determinate-nixd completion`, see `docs/TODO.md`).
- **Not the nixos.org script:** it is curl|sh, edits `/etc/bash.bashrc` and
  `/etc/zsh/zshrc`, and nothing updates it. apt gives the same Nix with none
  of that. The trade-off: apt's Nix can trail upstream by a minor version
  (2.34.3 vs 2.35 in 2026-10), which does not matter for a few `nix profile`
  packages.

Nix is the last resort (`docs/reference/package-managers.md`); keep the lists
short.

## Pieces

| Piece | Where |
| ----- | ----- |
| Daemon access | user in group `nix-users` (module adds it; active after re-login) |
| Flakes / `nix profile` | `home/.config/nix/nix.conf` (`experimental-features`) |
| PATH, desktop entries | `home/.common_env` adds `~/.nix-profile/{bin,share}` |
| Package set | `setup/packages/nix-<profile>.list` |

A program `exec`'d by sway only sees the new PATH once sway is restarted from
a shell that has it.

## Migrating a host off Determinate Nix

The module refuses to run while `/nix` belongs to another install (two daemons
on one store corrupt it). Per host:

1. Note what is installed: `nix profile list`.
2. `sudo /nix/nix-installer uninstall` (removes `/nix`, the daemon, the build
   users and its lines in `/etc/bash.bashrc` and `/etc/zsh/zshrc`).
3. Move aside `~/.nix-profile`, `~/.local/state/nix` and `~/.nix-defexpr`:
   they only link into the removed store, and a stale profile manifest breaks
   `nix profile` for the new install.
4. `system-setup 23-nix`, log out and in, `system-setup 23-nix` again (the
   second run installs the packages, once `nix-users` is active).
5. Reinstall anything host-specific from step 1 that is not in a list.

| Host | State (2026-10-25) |
| ---- | ------------------ |
| puppet | apt Nix 2.34.8 via `23-nix` (migrated 2026-10-25) |
| motoko | Determinate, contents unchecked (host was offline) |
| saito | no Nix: Determinate and its only package (Hermes, a test) purged 2026-10-25 |

saito is a server profile with no `nix-server.list`, so the module skips it
and the host stays Nix-free. Its purge found two things worth knowing for
motoko:

- Determinate's daemon ran a Sentry `crashpad_handler` that reports crashes
  to Determinate (another reason to drop it).
- The uninstaller (v3.17.3) removed its `/etc/zsh/zshrc` block but left the
  one in `/etc/bash.bashrc` (inert once `/nix` is gone). Check both files
  afterwards; remove a leftover with
  `sudo sed -i '/^# Nix$/,/^# End Nix$/d' /etc/bash.bashrc`.
