---
title: Ubuntu base setup
hosts: [all]
status: resolved
tags: [ubuntu, apt, packages, bootstrap]
updated: 2026-07-12
automated_by: setup/modules/00-apt-base.sh
---

# Ubuntu base setup

The baseline every machine gets: a regional mirror, a full upgrade, the base
package set, and vim as the system editor.

**Automated.** Run it rather than reading it:

```bash
system-setup --dry-run --profile auto   # see what would change
system-setup --profile auto             # apply
```

Packages are data, not code — see [`setup/packages/`](../../setup/packages/):

| List | Applies to |
| ---- | ---------- |
| `base.list` | every machine |
| `desktop.list` | GUI session (motoko, work laptop) |
| `server.list` | headless (saito, vserver) |
| `wsl.list` | WSL — deliberately thin; the Windows host owns GUI and drivers |

To add a tool, add a line to the relevant `.list`. That is the whole workflow.

## Bootstrapping a fresh machine

Chicken-and-egg: `system-setup` lives in this repo, and the repo is not deployed
yet. So clone first, run the setup, *then* link the dotfiles:

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/cbaoth/dotfiles.git ~/dotfiles
~/dotfiles/bin/system-setup --profile auto   # installs zsh, git, etc.
~/dotfiles/tools/link.sh                     # deploy into $HOME
chsh -s /bin/zsh                             # default shell
```

`system-setup` deliberately does not depend on `~/lib/commons.sh`, precisely so
it works at this point — before anything has been linked.

> `chsh` does not work everywhere. On Android (Termux/UserLAnd) `sh`/`bash` is
> invoked directly and the login shell setting is ignored.

## Regional mirror

The German mirror is materially faster from here. The module rewrites
`//archive.ubuntu.com` → `//de.archive.ubuntu.com` in whichever sources file the
release uses (`/etc/apt/sources.list.d/ubuntu.sources` on 24.04+, the older
`/etc/apt/sources.list` before that).

## FFmpeg

Not in any package list, on purpose. The apt build is older and less complete
(no `rubberband`, among others). Use the static GPL builds instead, via
[`bin/ffmpeg-install`](../../bin/ffmpeg-install):

```bash
ffmpeg-install
```

## Not automated

Things that are deliberately left manual — see their own notes:

- [browsers.md](browsers.md) — third-party apt repos and signing keys
- [power-management.md](power-management.md) — `sudoers`, `pam_time`
- [mounts.md](mounts.md) — `/etc/fstab`, host-specific UUIDs and credentials
