---
title: WSL at work — the wsl-work profile
hosts: [wsl-work]
status: resolved
tags: [wsl, work, licensing, policy, ai]
updated: 2026-10-30
automated_by: setup/modules/00-apt-base.sh
---

# `wsl-work` profile

`wsl` is the personal WSL profile. `wsl-work` is for a company-managed Windows
PC: the same shell environment, minus everything that is personal-use, has a
doubtful licence, or conflicts with the company's software/AI policy.

```bash
system-setup --dry-run --profile wsl-work   # never auto-detected: pass it
system-setup --profile wsl-work
```

`--profile auto` yields `wsl` on any WSL box. To make it pick `wsl-work`, add
`<hostname> wsl-work` to `setup/hosts.list` — but a work hostname is not
something to publish in this public repo, so pass the profile explicitly.

## What it runs

| Module | wsl-work | Why |
| ------ | -------- | --- |
| `00-apt-base` | yes, without `personal.list` | `base.list` + `wsl.list` (see below) |
| `05-release-upgrades` | yes (`lts`) | |
| `10-locale` | yes | |
| `22-fnm` | yes | fnm and Node are MIT. Needs the upstream installer (`fnm.vercel.app`) to be reachable through the corporate proxy |
| `31-github-copilot` | yes | Enterprise Copilot is the approved AI. Sign in with the **work** GitHub account, and check the enterprise policy allows Copilot CLI |
| `56-sshd` | yes (no-op without `openssh-server`) | auth hardening only |
| `21-snap` | **no** | Snap store is an extra software channel outside IT's approved ones; only holds `bottom` (btop/htop already in base), and the shared list would pull in anything personal added later |
| `28-claude-code` | **no** | Not an approved AI tool at work |
| `29-claude-desktop`, `32-github-copilot-app`, `33-vocalinux` | no | desktop profile only anyway |
| `30-docker` | yes | Docker Engine (`docker.io`) is Apache-2.0, free for business. Only Docker Desktop is paid, and it is not installed. Needs systemd in WSL, see [docker.md](docker.md) |
| `35-tailscale`, `60-netdata` | no | Personal tailnet / exposing metrics: needs IT approval, not a default |

## apt packages

Only packages that serve a personal tool are moved out of `base.list` into
`personal.list` (every profile except `wsl-work`).

| Package | wsl-work | Reason |
| ------- | -------- | ------ |
| `socat`, `bubblewrap` | no | Only there for Claude Code's sandbox; `socat` is also a generic tunnel tool |
| `restic` | yes | BSD-2. Used at work: work-owned repositories and credentials only |
| `aria2` | yes | GPL-2.0. Chunked downloads of large files; BitTorrent only for legitimate distribution (official ISOs) |
| `ghostscript` | yes | AGPL-3.0. Fine as a local CLI tool for PDF work; do not embed it in a product or expose it as a service. Some company licence policies blocklist AGPL: confirm with legal/IT if in doubt |
| `ngrep`, `iftop` | yes | Packet capture for dev/pen-testing, authorised targets only. No endpoint-protection agent on WSL as of 2026-10: recheck if that changes. WSL2 only sees its virtual NIC |

The caveats are repeated as comments next to each entry in `base.list`.

Kept in `base.list` (all free, no policy concern): zsh, vim, neovim, tmux,
htop, btop, lsof, git, git-lfs, gh, wget, curl, rsync, sshfs, gnupg, bat, less,
multitail, ripgrep, fd-find, jq, gawk, parallel, zip/unzip, 7zip, python3 tools,
shellcheck, cronic, jdupes, rmlint, gdu, rename. `wsl.list`: emacs-nox, wslu.

## No personal backups or notes at work

`system-setup` sets up none of this, for any profile: no module installs or
enables `notes-sync`, `notes-pull`, `onedrive-sync`, `sb-sync@` or any backup
job, and `host-<hostname>.list` only exists for saito. The units are *linked*
into `~/.config/systemd/user/` by `dotfiles-link` but stay disabled until
`systemctl --user enable` is run by hand. On the work box:

- Do not enable them, and do not clone `~/notes`.
- `notes-sync` fails with "not a git repo" if `~/notes` is absent, so an
  accidental enable does nothing useful.
- Any restic job added later is a work job: work repository, work credentials,
  kept out of this public repo.

## Linking the dotfiles at work

`dotfiles-link` asks for a profile on the first run in a clone; choose `work`.
It is saved in the untracked `.link-profile.local` (details: *Profiles* in
[`docs/linking-system.md`](../linking-system.md)). The allowlist is
`tools/profiles/work.list`.

- **Left out:** all desktop config (sway, waybar, mpv, ...), the systemd user
  units (notes, OneDrive, VS Code snapshot), host-specific zsh files, personal
  `bin/` scripts, and Claude Code's `settings.json` and skills.
- **Kept:** `~/.claude/rules` and `~/.copilot/.github/instructions`. They are the
  coding-style instruction files that VS Code and Copilot CLI read; nothing
  Claude-specific runs from them.
- **Git:** `home/.gitconfig` is linked and carries the personal identity. For
  work repositories set the work identity per directory in the untracked
  `~/.gitconfig.local`, see `home/.gitconfig.local.example`. The real work email
  and company name never go into this repo.
- **Clone read-only** (https, no credentials); develop the dotfiles at home.

Nothing is ever removed: applying `wsl-work` to a box that already ran `wsl`
leaves the personal packages in place.
