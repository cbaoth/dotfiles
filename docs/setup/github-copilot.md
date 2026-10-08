---
title: GitHub CLI and GitHub Copilot (CLI and desktop app)
hosts: [motoko, puppet]
status: resolved
tags: [github, copilot, gh, cli, appimage, electron, rofi]
updated: 2026-10-08
automated_by: setup/modules/31-github-copilot.sh, setup/modules/32-github-copilot-app.sh
---

# GitHub CLI and GitHub Copilot

**Automated:**

| Module | Profiles | What |
| ------ | -------- | ---- |
| `setup/packages/base.list` (`gh`) | all | GitHub CLI from the Ubuntu repo (2.46) |
| `system-setup 31-github-copilot` | all | Copilot CLI via the official installer into `~/.local/bin/copilot` |
| `system-setup 32-github-copilot-app` | desktop | Copilot desktop app AppImage in `~/Applications`, plus launcher entry |

## Copilot CLI

`curl -fsSL https://gh.io/copilot-install | bash` installs one self-contained
binary (no Node) to `~/.local/bin`, after verifying a SHA256 from the release.
Chosen over npm (`@github/copilot`, needs Node everywhere) and the VS Code
`copilot` shim (needs a VS Code install, absent on WSL with only vscode-server).
Never run it with `sudo`: as root it targets `/usr/local/bin`.

```bash
copilot --version
copilot update          # check for and apply a newer release
VERSION=1.0.93 curl -fsSL https://gh.io/copilot-install | bash   # pin a version
```

Sign-in is its own flow (`copilot`, then `/login`); it does not reuse `gh auth`.

## Desktop app

Only published as an AppImage (`https://gh.io/copilot-app-linux`, ~600 MB).
The module downloads it once and adds what an AppImage lacks:

- `~/.local/share/applications/github-copilot.desktop` with an extracted icon.
  rofi's `drun` mode (already in the configured modes) lists it; so does any
  other XDG launcher.
- `bin/github-copilot-app`, linked into `~/bin` by `dotfiles-link`: appends
  `GNOME` to `XDG_CURRENT_DESKTOP` for the Electron keyring (see
  [sway.md](sway.md#claude-desktop)). Untested for this app.

The app also writes two `.desktop` files itself on first run. Leave
`github-handler.desktop` (the `gh://` OAuth callback) alone. Ignore
`com.github.githubapp.desktop`: it is `NoDisplay` and points into a `/tmp`
mount that is gone after the first exit.

Update: remove `~/Applications/GitHub-Copilot-linux-x64.AppImage` and re-run
`system-setup 32-github-copilot-app`. The URL is an unversioned redirect, so
the module cannot tell whether the local copy is current.

## GitHub CLI token scope

`gh auth login` via the browser grants `repo`, `read:org`, `gist` across every
repo the account can reach, work-org private repos included. The OAuth app list
offers no per-org restriction for a personal account. A fine-grained PAT with
the personal account as resource owner is the way to scope it:
`gh auth login --with-token < tokenfile`.
