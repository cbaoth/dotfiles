---
title: Emacs — fresh start after ~10 years
hosts: [all]
status: open
revisit: 2026-12
tags: [emacs, editor, terminal, zsh, vscode, keyboard]
updated: 2026-10-15
automated_by: setup/modules/00-apt-base.sh
---

# Emacs — fresh start after ~10 years

**Status: trial.** Emacs was the daily editor 2001–2011, then dropped for vim
(always present on servers) and later VS Code. The question now: can Emacs be
the *one* editor for terminal work, now that the servers are my own and Emacs
can be installed everywhere? Or is it just nostalgia? Re-learn the basics
first, then decide. Revisit 2026-12.

Key cheatsheet: [docs/reference/emacs.md](../reference/emacs.md).

## Requirements

1. **Terminal first.** Everything must work in `emacs -nw` over ssh, in tmux
   and on a bare TTY.
2. **One config for terminal and GUI.** GUI-only settings apply to graphical
   frames only, not in a separate setup.
3. **Same on every host.** Deployed by `dotfiles-link`, and built-in features
   first, so a fresh host starts offline with nothing to download. The one
   exception so far, atomic-chrome, is desktop-daemon-only (see *Packages*).

## Install

The Debian/Ubuntu Emacs builds **conflict with each other** (one `emacs`
binary each), so the build is chosen per profile, not in `base.list`:

| Profile | Package | Why |
| --- | --- | --- |
| server, wsl | `emacs-nox` | terminal-only, no GTK/X dependencies |
| desktop | `emacs-pgtk` | pure-GTK build, native on Wayland (sway); also runs `emacs -nw` |

Lists: `setup/packages/{server,wsl,desktop}.list`, installed by
`system-setup 00-apt-base`. Ubuntu 26.04 ships Emacs 30.2.

- `emacs-gtk` (X11 GTK) is the choice for an X11 session; the pgtk build is
  meant for Wayland and is discouraged on X11. All desktops here run sway.
- Windows (untested): the native GNU Emacs build reads the same `init.el`.
  Neither the `.reg` font files from the old config nor the Windows-only
  `keyboard-translate` paren swap are needed any more; see *Legacy*.

## Config

Repo: `dotfiles/.config/emacs/{early-init.el,init.el}` → `~/.config/emacs/`
(XDG location, supported since Emacs 27).

> **Gotcha: `~/.emacs` and `~/.emacs.d/` win.** If either exists, Emacs
> ignores `~/.config/emacs/` silently. Check with
> `ls -d ~/.emacs ~/.emacs.d` when the config seems not to load.
>
> Bit on puppet (2026-10-12): an `emacs --daemon` started from the launcher
> (`Emacs (Client)`) *before* the config was deployed kept `~/.emacs.d/` as
> its directory for two days, ran without `init.el`, and recreated
> `~/.emacs.d/` when it next wrote caches (proof: its PID in
> `auto-save-list/.saves-<pid>-<host>~`). Fix, per host, manual:
> `ln -s ~/.config/emacs ~/.emacs.d`, so both paths are the same directory.
> Check with `emacsclient --eval user-init-file`; `emacs --batch` never loads
> the init file, so it always reports `nil`.
>
> Bit on motoko too (2026-10-15): a `~/.emacs.d/` left over from an Emacs
> run in 2026-04, before the config existed. Symptoms: the splash screen in a
> split window next to the file, and the light default theme.

`dotfiles-link` links files, not directories, so `~/.config/emacs/` is a real
directory. Everything Emacs writes stays there, outside the repo:
`custom.el` (Customize output), `backups/`, `auto-saves/`, `history`,
`places`, `recentf`, `elpa/` (packages).

Principles:

- **Stock key bindings.** The tutorial (`C-h t`), help and which-key then
  describe what the keys actually do. Personal additions only under `C-c
  <letter>`, which is reserved for the user. The old personal remaps (C-o, C-k,
  windmove, paren swap) are in `init.el`, commented out, under *Legacy
  preferences*.
- **Built-in first.** Emacs 30 has, built in: `which-key`,
  `fido-vertical-mode` (fuzzy completion), `modus-themes`, `editorconfig`,
  `eglot` (LSP), tree-sitter modes, TRAMP. Add packages one at a time, only
  when a gap hurts; see *Packages*.
- **Relearning aids on:** which-key, the menu bar (`F10`, in a terminal too),
  `help-window-select`.

### Theme

Built-in **Modus Vivendi**, recolored to **GitHub Dark Default** (the theme
in VS Code and foot) via `modus-vivendi-palette-overrides` in `init.el`.
Overrides instead of a MELPA theme: it stays built in (offline, every host),
and Modus covers far more faces (diff, org, magit, …) than a small port.
The alternative, if the look is not close enough:
[`github-dark-vscode-theme`](https://github.com/justintime50/github-dark-vscode-emacs-theme)
on MELPA.

- Tweak: edit a color in the `setq`, `C-M-x` on it, then `M-x load-theme RET
  modus-vivendi`. Names and preview: `M-x modus-themes-list-colors-current`.
- Try others: `M-x modus-themes-select` (Modus family), `M-x load-theme` (all
  installed; `M-x disable-theme` the current one first, themes stack).

## Ways to run it

| Command | What |
| --- | --- |
| `emacs -nw FILE` | terminal frame, standalone process |
| `emacs FILE` | GUI frame (desktop), terminal if there is no display |
| `emacsclient -t -a '' FILE` | terminal frame of a shared server; `-a ''` starts the daemon if none runs |
| `emacsclient -c -a '' FILE` | GUI frame of the same server |
| `emacsclient -n FILE` | open in an existing frame and return immediately |

**Daemon/client** is the modern answer to slow startup and to "one session,
several windows": buffers, kill ring and history are shared across all
frames, terminal and GUI alike. `C-x C-c` in a client frame closes only that
frame.

On the desktop the daemon is a **systemd user unit, started by sway**:

- The package ships `/usr/lib/systemd/user/emacs.service` (`emacs
  --fg-daemon`). It is *not* `enable`d: the user manager starts at TTY login,
  before `sway-start`, without the Wayland env. Instead
  `dotfiles/.config/sway/config.d/90-launch-apps.conf` runs `systemctl --user
  start emacs.service` after the env import, like swaync and swayosd.
- Drop-in `dotfiles/.config/systemd/user/emacs.service.d/env.conf` starts it
  through `zsh -c`, so it gets the full `.common_env` PATH (`~/bin`, fnm's
  node). The user manager's own PATH lacks those, and Emacs hands its env to
  everything it runs (compile, shell, eglot).
- Control: `systemctl --user {status,restart,stop} emacs`. `M-x kill-emacs`
  also stops it (clean exit, no restart).
- Lifetime: without linger the user manager, and with it the daemon, stops
  when the last login session ends. Save before logging out.
- The launcher's `Emacs (Client)` and `emacsclient -c -a ''` connect to this
  daemon; `-a ''` only starts one where none runs (servers).

**TRAMP** edits remote files from a local Emacs:
`C-x C-f /ssh:saito:/etc/hosts` opens a file over ssh, and
`/sudo::/etc/hosts` opens a local file as root. Remote dired, shell and git
work through it too. It is the closest thing to VS Code Remote-SSH: a GUI
Emacs on the desktop, editing files on the servers.

## Packages

**package.el + use-package, no straight.el.** Both are built in (use-package
since Emacs 29). Archives: GNU ELPA and NonGNU ELPA (vetted, default), plus
MELPA (community, largest, built from upstream git). For a package that has
to come from a git repo, Emacs 30's use-package `:vc` keyword (package-vc)
covers what straight.el was once needed for.

straight.el would replace package.el, not complement it: its docs say to
disable package.el, both maintain their own copy of every dependency (two
`websocket`s, whichever loads first wins), and use-package needs different
keywords (`:ensure` vs `:straight`). Worth it only for pinning every package
or hacking on packages; revisit then, as a switch, not a mix.

| Package | Source | Where | Why |
| --- | --- | --- | --- |
| atomic-chrome | git, fork `KarimAziev/atomic-chrome` (`:vc`, newest commit) | desktop daemon only | edit browser text fields in Emacs via the [chrome-emacs](https://github.com/KarimAziev/chrome-emacs) extension |

atomic-chrome notes:

- MELPA's recipe still builds the unmaintained original
  (`alpha22jp/atomic-chrome`), hence the fork from git. Its dependency
  `websocket` comes from the archives.
- It is a WebSocket server *inside* one Emacs process, on
  `127.0.0.1:64292`. Only one process can hold the port, so `init.el` starts
  it only in the daemon (`:if (and (daemonp) (featurep 'pgtk))`; pgtk =
  desktop build, so servers never download it). In a standalone `emacs`
  with no daemon running: `M-x atomic-chrome-start-server` by hand.
- First daemon start downloads it (online needed); after that it starts
  offline. Update: `M-x package-vc-upgrade`.

## Terminal caveats

- **VS Code's integrated terminal keeps many keys for itself** (`C-p`,
  `C-k` chords, `C-b`, …), so Emacs never sees them. Fix:
  `"terminal.integrated.sendKeybindingsToShell": true` or
  `terminal.integrated.commandsToSkipShell`. Or use foot.
- **Some keys cannot be typed in a terminal**, e.g. `C-;` and `C-S-<key>`.
  That's why `comment-line` also sits on `C-c ;`.
- **Clipboard over ssh:** `init.el` enables OSC 52 (`xterm-extra-capabilities
  '(setSelection)`), so killed text lands in the local clipboard. Needs
  terminal support: tmux has `set-clipboard on`; foot and the VS Code
  terminal are untested.
- **Mouse:** `xterm-mouse-mode` is on. Hold Shift while dragging to use the
  terminal's own selection.

## Shell consistency

zsh went back to **emacs mode** on 2026-10-10 (vi mode 2026-07..10), so the
shell and the editor share one set of movement and editing keys, including
Emacs-style selection (`C-SPC`, `C-w`, `M-w`, `C-y`, `C-g`, `C-x C-x`).
tmux copy mode uses emacs keys too (`mode-keys emacs`, see
[docs/reference/tmux.md](../reference/tmux.md#copy-mode-emacs-keys)). `Ctrl-X Ctrl-E`
at the prompt opens the line in `emacs -nw` (zstyle, independent of
`$EDITOR`); `C-c s` there saves a copy as an executable script. Toggle and
the keys that differ: [docs/reference/zsh.md](../reference/zsh.md#editing-model-emacs-mode).

`$EDITOR` is still `nvim` (`.common_env`). Switching it to `emacsclient -t -a ''`
is undecided: git commit messages and `Ctrl-X Ctrl-E` would open Emacs, which
is more practice but more friction while relearning.

## Legacy config (2001–2011)

Found 2026-10 in old backups (paths in the private notes). Five generations,
2002 → 2011. The newest is from 2011 and was Linux + Windows; saito's
`~/.emacs.d` was an older 2005 base, used until 2019. It was tarred to
`~/emacs_config_legacy_saito.tar.bz2` on saito and deleted.

**Verdict: nothing to port as code.** It was built around hand-copied
2007-era packages and a homemade color-theme system, and nearly all of its
helper functions are built-in now (`delete-trailing-whitespace`,
`duplicate-line`, `C-x RET f` for line endings). The few preferences worth
keeping are in the new `init.el`; the rest is commented out there.

- The `;; Time-stamp: <…>` header in each file is the reliable age signal,
  not mtimes (those are copy dates).
- **()/[] swap:** on Linux via xmodmap (`xmodmap-104-us`): `( )` unshifted on
  the bracket keys, `[ ]` on Shift+9/0, `{ }` unchanged. On Windows via
  `keyboard-translate` in Emacs. Today: commented out in
  `dotfiles/.config/xkb/symbols/custom`, ready to test.
- **`.reg` files:** only set `Emacs.Font` (Courier New) in the Windows
  registry. Obsolete; the font is set in `init.el`.

## Open items

- [ ] Relearn the basics: `C-h t` (built-in tutorial), then daily use in the
      terminal.
- [ ] Test OSC 52 clipboard: foot, tmux, VS Code terminal.
- [ ] Desktop: install `emacs-pgtk` (`system-setup 00-apt-base`), try GUI
      and daemon + `emacsclient -c`, try TRAMP to saito.
- [ ] Shell aliases for `emacsclient -t -a ''` / `-c` (only once the daemon
      workflow sticks).
- [ ] Decide `$EDITOR` (see *Shell consistency*).
- [ ] VS Code review, on the desktop (settings live in Settings Sync on the
      client, not on the servers): `~/.config/Code/User/settings.json`,
      `keybindings.json`, `code --list-extensions`. Look for common ground:
      editorconfig, font, theme, whitespace and ruler settings, and maybe an
      Emacs keymap extension in VS Code.
- [ ] Test the ()/[] swap in xkb.
- [ ] Caps Lock: Backspace (Colemak, years of habit) vs Ctrl (the classic
      Emacs remedy for reaching Ctrl with the left pinky). First try using the
      Ctrl on the opposite hand, like Shift; revisit if Ctrl chords still slow
      things down.
- [ ] tmux prefix `C-a` shadows line-start (`C-a C-a` sends it). Kept for
      the screen habit; `C-b` would only move the clash to backward-char.
- [ ] Try chrome-emacs + atomic-chrome in daily use (daemon set up
      2026-10-12, server verified listening; browser side untested).
- [ ] motoko runs the **snap** `emacs` 31.1 (classic, `/snap/bin` in PATH),
      not `emacs-pgtk`: an X11/GTK3 build (XWayland), and it ships no
      `emacs.service`, so sway's `systemctl --user start emacs.service`
      fails and no daemon (or atomic-chrome) runs. Decide: apt
      `emacs-pgtk` (30.2) as documented, or keep the snap (31.1) and adapt.
- [ ] New desktop host: `ln -s ~/.config/emacs ~/.emacs.d` (see *Config*
      gotcha), then log in to sway once so the daemon installs atomic-chrome.
- [ ] Packages, only when a gap hurts. Candidates: magit (git), vertico,
      orderless, marginalia, consult (completion beyond fido), markdown-mode.
      Not planned: evil (vim keys) defeats the point.
- [ ] Windows: native Emacs with the same `init.el`.
- [ ] Verdict by the revisit date: keep going, or back to nvim.
