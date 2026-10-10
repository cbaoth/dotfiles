---
title: Emacs — fresh start after ~10 years
hosts: [all]
status: open
revisit: 2026-12
tags: [emacs, editor, terminal, zsh, vscode, keyboard]
updated: 2026-10-10
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
   only for now, so a fresh host starts offline with nothing to download.

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

`dotfiles-link` links files, not directories, so `~/.config/emacs/` is a real
directory. Everything Emacs writes stays there, outside the repo:
`custom.el` (Customize output), `backups/`, `auto-saves/`, `history`,
`places`, `recentf`, `elpa/` (packages, once installed).

Principles:

- **Stock key bindings.** The tutorial (`C-h t`), help and which-key then
  describe what the keys actually do. Personal additions only under `C-c
  <letter>`, which is reserved for the user. The old personal remaps (C-o, C-k,
  windmove, paren swap) are in `init.el`, commented out, under *Legacy
  preferences*.
- **No third-party packages yet.** Emacs 30 has, built in: `which-key`,
  `fido-vertical-mode` (fuzzy completion), `modus-themes`, `editorconfig`,
  `eglot` (LSP), tree-sitter modes, TRAMP. Add packages one at a time, only
  when a gap hurts.
- **Relearning aids on:** which-key, the menu bar (`F10`, in a terminal too),
  `help-window-select`.

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
frame; `M-x kill-emacs` stops the server. A systemd user unit
(`systemctl --user enable --now emacs`) would start it at login; unverified
whether the Ubuntu package ships one (`systemctl --user cat emacs`). With
`-a ''` it is not needed.

**TRAMP** edits remote files from a local Emacs:
`C-x C-f /ssh:saito:/etc/hosts` opens a file over ssh, and
`/sudo::/etc/hosts` opens a local file as root. Remote dired, shell and git
work through it too. It is the closest thing to VS Code Remote-SSH: a GUI
Emacs on the desktop, editing files on the servers.

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
- [ ] Packages, only when a gap hurts. Candidates: magit (git), vertico,
      orderless, marginalia, consult (completion beyond fido), markdown-mode.
      Not planned: evil (vim keys) defeats the point.
- [ ] Windows: native Emacs with the same `init.el`.
- [ ] Verdict by the revisit date: keep going, or back to nvim.
