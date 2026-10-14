---
title: Root shell (dotfiles for root)
hosts: [all]
status: resolved
tags: [dotfiles, root, zsh, security]
updated: 2026-10-14
---

# Root shell (dotfiles for root)

Root gets the same zsh/starship setup as the regular user, trimmed to a
root-safe subset: the allowlist [`tools/profiles/root.list`](../../tools/profiles/root.list).
Mechanism and guards: *Profiles* in [`docs/linking-system.md`](../linking-system.md).

**Manual on purpose**, no `setup/` module (yet): it is a one-time clone per
host, and the update is a single `dotu`.

## Why a separate clone

Root must never source or execute a file a regular user can write. Linking
root's `~/.zshrc` into `/home/<user>/dotfiles` would let that user (or
anything running as that user) run code as root on the next `sudo -i`. The
same goes for `.git/hooks` on `git pull`. So root clones the public repo
itself, over HTTPS (no credential, read-only by nature), and every file is
root-owned. `link.sh` refuses to run as root otherwise.

## Setup (per host)

```bash
sudo -i
git clone https://github.com/cbaoth/dotfiles.git /root/dotfiles
/root/dotfiles/tools/link.sh --dry-run -v   # profile 'root' is automatic
/root/dotfiles/tools/link.sh
chsh -s /bin/zsh root
exec zsh                                    # first start installs zinit + plugins
```

Starship shows the root marker (`CB_PROMPT_ROOT`, set in `.zshrc` when
`EUID == 0`).

## Update

```bash
sudo -i
dotu        # dotfiles-update: git pull + dotfiles-link
```

If the repo moves to Forgejo, switch root's remote too:
`git -C /root/dotfiles remote set-url origin <new-https-url>`.

## Gotchas

- Use `sudo -i` (login shell, `HOME=/root`). `link.sh` aborts when `HOME` is
  not root's home, e.g. under `sudo -E`.
- `ZDOTDIR` is deliberately not exported by `.zshenv`: it would survive
  `su`/`sudo -E` and make a root zsh read the user's rc files.
- A file missing for root is not a bug. Add it to `root.list` after the
  checks listed under *Profiles* in `docs/linking-system.md`.
