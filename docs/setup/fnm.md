---
title: fnm (NodeJS version manager)
hosts: [motoko, puppet]
status: resolved
tags: [fnm, node, npm, claude]
updated: 2026-10-10
automated_by: setup/modules/22-fnm.sh
---

# fnm (NodeJS version manager)

**Automated:** `system-setup 22-fnm` (all profiles). Update the binary with
`fnm-setup` (aliases `fnm-update`, `fnm-upgrade`, `fnm-install`): updates the
fnm binary, then installs the newest Node LTS and makes it the default.

## Why fnm, why this way

- No apt package; upstream installer
  (`curl -fsSL https://fnm.vercel.app/install | bash`) into
  `~/.local/share/fnm`. No root needed.
- **Always `--skip-shell`.** Without it the installer appends a block to
  `.zshrc`/`.bashrc`/`.profile`, which are symlinks into this repo. Shell setup
  is already in `dotfiles/.common_env` (PATH + `fnm env`, active only once the
  dir exists) and `cb_devtools_completions` in `.common_rc`.
- `--install-dir` is passed explicitly: the installer prefers an existing
  `~/.fnm` over the XDG path, and `.common_env` only looks at
  `~/.local/share/fnm`.
- Re-running the installer overwrites the binary, so it doubles as the update
  path. It does not update Node; `fnm-setup` does that
  afterwards via `fnm install --lts && fnm default lts-latest` (old versions
  are kept: `fnm list`, `fnm uninstall <ver>`).

## Claude Code is independent of fnm/Node

Claude Code's recommended install is the native binary
(`~/.local/bin/claude` → `~/.local/share/claude/versions/`), which does not
use Node ([docs/setup/claude.md](claude.md)). The npm package also ships that
same native binary; only its *installation* lives under npm's global prefix.

That is the likely cause of the breakage on motoko: Claude Code had been
installed via a system/global npm, so removing the old npm directories removed
`claude` with it. Cause not re-verified (no record in the notes). On a native
install, nothing about fnm/npm can affect it. Check any host with
`ls -l ~/.local/bin/claude` (symlink into `~/.local/share/claude` = native)
and `claude doctor`; migrate an npm install with the native installer, then
`npm uninstall -g @anthropic-ai/claude-code`.

`npm install -g` under fnm goes to the active Node version's prefix, so
packages are per Node version and need reinstalling after switching.

## Hosts

- **puppet**: native Claude Code; no Node before this module (only a stale
  `~/.npm` cache dir).
- **motoko**: fnm installed by hand earlier; Claude Code migrated to native.
