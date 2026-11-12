---
title: Fonts — Nerd Fonts
hosts: [motoko]
status: resolved
tags: [fonts, terminal, gnome]
updated: 2026-11-12
automated_by: setup/modules/40-fonts.sh
---

# Fonts

**Automated:** `system-setup 40-fonts`

Installs [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) (FiraCode,
FiraMono) and sets `FiraMono Nerd Font 10` as the system monospace default.

Nerd Fonts are patched with the glyph sets that the shell prompt, `bat`, `lsd`,
and friends assume are present. Without them the prompt renders as a row of
tofu boxes.

## Why not the apt fonts

- `fonts-firacode` ships plain **Fira Code** (monospace, fine for terminals, no
  Nerd glyphs). There is no `fonts-firamono` package on Ubuntu.
- The configs here name `FiraMono Nerd Font` / `FiraCode Nerd Font`. If only
  the apt package is installed, `FiraMono*` is not found and terminals fall back
  to a wide-spaced font.
- `gnome-tweaks` (desktop.list) is how to pick the default "Monospace Text".

## Why release archives

The nerd-fonts repo is ~8 GB at full depth. The module downloads one pinned,
SHA-256-checked `<Family>.tar.xz` release archive per family (~3 MB each) and
extracts it (without `*Propo*`) to `~/.local/share/fonts/NerdFonts/<Family>/`.
Bumping the version: new tag and new checksums in `NF_VERSION` / `NF_SHA256`
(the module does not reinstall an already-present family).

Idempotency is keyed on `fc-list`, not on the install dir: the fonts count as
installed if fontconfig can see them, however they got there.

An old clone in `~/git/nerd-fonts` is no longer used and can be deleted.

## Text console

The console (kmscon, runs as root) cannot see these per-user fonts; it gets
its own system-wide copy of FiraMono — see [console.md](console.md).

## Verify

```shell
fc-list | grep -i 'nerd font'
gsettings get org.gnome.desktop.interface monospace-font-name
```
