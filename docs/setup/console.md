---
title: Text console — kmscon on tty3-6, plain fallback on tty1-2
hosts: [puppet, motoko, saito]
status: resolved
tags: [console, tty, kmscon, fonts, systemd, logind, tmux, starship]
updated: 2026-10-17
automated_by: setup/modules/41-console.sh
---

# Text console (TTY)

**Automated:** `system-setup 41-console` (desktop and server profiles; skipped
on VMs, so not on the vserver).

The console is rarely used — log in on tty1 and run `sway-start`, or recover
when sway is broken — but then it has to be readable: e.g. re-attaching a tmux
session with Claude Code in it after the compositor died.

## Layout

| VT | Runs | Why |
| --- | --- | --- |
| tty1 | stock `getty` | `sway-start` is run from here; a compositor on a kmscon VT fights kmscon for DRM master |
| tty2 | stock `getty` | safety net if kmscon misbehaves |
| tty3–6 | `kmscon` | real fonts (FiraMono Nerd Font Mono), truecolor, mouse |

**For a broken sway session, use tty3** (Ctrl+Alt+F3): everything renders
there as in foot. tty1/2 only get the plain fallback below.

## Why the stock console looks bad

- Console fonts (PSF) are bitmaps with at most 512 glyphs: no Nerd Font icons,
  at best a few powerline arrows. Already the best stock choice here:
  `FONTFACE="TerminusBold"`, `FONTSIZE="16x32"` in `/etc/default/console-setup`.
- 16 colors; 256-color/truecolor output is squeezed into them.
- And a self-inflicted one: `~/.common_env` used to force
  `TERM=xterm-256color` everywhere, so tmux, starship and Claude Code believed
  they were on an xterm. It now leaves `TERM=linux` alone.

## kmscon

A userspace console on KMS/DRM; renders with pango/fontconfig, so any TTF/OTF
font works. Packaged in Ubuntu (`kmscon`, 9.x on 26.04), actively maintained,
and Fedora has proposed it as its default console — not a hack.

- Config: `/etc/kmscon/kmscon.conf` — the module sets `font-name`, `font-size`
  (default 14, per-host table in the module) and `term=xterm-256color`.
  kmscon's own default `term` is `linux`, which would trigger the plain
  fallback inside kmscon too.
- Zoom at runtime: Ctrl+Shift+Plus / Ctrl+Shift+Minus. Mouse works; touch moves
  the pointer but cannot select.
- Config changes apply when a console's login prompt restarts (log out there).
  The module never restarts the units: that would kill sessions on them.
- Each instance takes ~15–30 MB RSS.

### The font must be system-wide

kmscon runs as root, so `~/.local/share/fonts` (where `40-fonts` installs) is
invisible to it. The module installs the pinned, checksummed `FiraMono.tar.xz`
release (~3 MB) into `/usr/local/share/fonts/nerd-fonts/FiraMono/` — only the
**Mono** variant, whose icons fit one cell.

A missing font is not fatal: fontconfig falls back to DejaVu Sans Mono and
pango picks missing glyphs from any other system font that has them. That is
how the first manual test "worked" with a font name that did not exist — the
icons came from a hand-copied FiraMono in `/usr/local/share/fonts/`.

### What the package does on install (and the module undoes)

`apt install kmscon` runs `systemctl enable kmsconvt@` (via
`deb-systemd-helper`), which:

- enables `kmsconvt@tty1.service` (`DefaultInstance=tty1`) — tty1 becomes
  kmscon at the next boot, conflicting with `getty@tty1`;
- symlinks `/etc/systemd/system/autovt@.service` → `kmsconvt@.service`, so
  logind spawns kmscon on *every* VT you switch to.

The module disables tty1, removes the template alias, and enables each VT
statically: `getty@tty1-2`, `kmsconvt@tty3-6`. A logind drop-in
(`/etc/systemd/logind.conf.d/60-console-vts.conf`: `NAutoVTs=0`,
`ReserveVT=0`) stops logind spawning `autovt@` units on demand — those would
hit the units' `Conflicts=` and stop whatever already runs on that VT.
Enabled units take effect at the **next boot**.

### Failure modes

- kmscon fails to start → its unit has `OnFailure=getty@%i.service`, you get a
  stock login prompt on that VT.
- kmscon starts but renders garbage / black → not covered; that is what tty1/2
  are for.
- `/etc/needrestart/conf.d/kmscon.conf` (from the package) keeps needrestart
  from restarting kmscon units after upgrades.

## Plain fallback on the stock console

Detection is `TERM=linux`, which only the stock console sets (kmscon reports
`xterm-256color`). Force it elsewhere with `CB_PLAIN_TERM=1`, e.g. for a
terminal without a Nerd Font; there is no reliable automatic test for that.

- **zsh** (`~/.zshrc`, STARSHIP section): starship is not loaded; the host's
  `prompt fade N` theme is used instead (its shade blocks `░▒▓` exist in
  Terminus). Inside tmux the attached client's TERM is checked once, at shell
  start.
- **tmux** (`~/.tmux.conf` hooks → `~/.tmux/plain.conf`): on attach / session
  change from a `linux` client, catppuccin is swapped for an ASCII, 8-color
  status bar; attaching from a capable terminal re-sources `~/.tmux.conf`.
  The options are global: the last client to attach decides.
- **Limitation:** shells already running in tmux panes keep the prompt they
  started with. Another reason to use tty3 for a broken sway session.

## Verify

```shell
systemctl is-enabled getty@tty{1,2} kmsconvt@tty{3,4,5,6}   # all "enabled"
systemctl is-enabled kmsconvt@tty1                           # "disabled"
fc-list | grep -i 'FiraMono Nerd Font Mono'
journalctl -b -u 'kmsconvt@*' | grep font_pango   # "Using font FiraMono Nerd Font Mono …"
```
