---
title: Fonts — Nerd Fonts
hosts: [motoko]
status: resolved
tags: [fonts, terminal, gnome]
updated: 2026-07-12
automated_by: setup/modules/40-fonts.sh
---

# Fonts

**Automated:** `system-setup 40-fonts`

Installs [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) (FiraCode,
FiraMono) and sets `FiraMono Nerd Font 10` as the system monospace default.

Nerd Fonts are patched with the glyph sets that the shell prompt, `bat`, `lsd`,
and friends assume are present. Without them the prompt renders as a row of
tofu boxes.

## Why a git clone

The repo is enormous (~8 GB at full depth). The module uses `--depth 1` and
`install.sh <font>...` to fetch and install only the two families — releases
also exist, but the install script handles the fontconfig cache refresh for you.

Idempotency is keyed on `fc-list`, not on the clone: the fonts count as installed
if fontconfig can see them, however they got there.

## Verify

```shell
fc-list | grep -i 'nerd font'
gsettings get org.gnome.desktop.interface monospace-font-name
```
