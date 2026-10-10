---
title: Emacs cheatsheet (relearning the basics)
hosts: [all]
status: resolved
tags: [emacs, editor, keybindings, cheatsheet]
updated: 2026-10-10
---

# Emacs cheatsheet

Notation: `C-x` = Ctrl+x, `M-x` = Alt+x (or `ESC` then `x`), `C-x C-s` = two
chords in sequence. Setup and background: [docs/setup/emacs.md](../setup/emacs.md).

## Survival

| Key | Action |
| --- | --- |
| `C-g` | **cancel** whatever is happening (press repeatedly if needed) |
| `C-x C-s` | save |
| `C-x C-c` | quit (asks about unsaved buffers) |
| `C-/` or `C-_` | undo (`C-?` / `C-M-_` redo) |
| `C-h t` | built-in tutorial (~30 min, worth it) |
| `F10` | menu bar, also in a terminal |

Broken config? `emacs -Q` starts without it, and `emacs --debug-init` shows
where it fails.

## Files, buffers, windows

| Key | Action |
| --- | --- |
| `C-x C-f` | open file (creates it if new; **`M-j`** forces a new name while the completion list matches an existing one) |
| `C-x C-w` | save as |
| `C-x b` | switch buffer |
| `C-x C-b` | buffer list |
| `C-x k` | close (kill) buffer |
| `C-x 2` / `C-x 3` | split below / right |
| `C-x o` | next window |
| `C-x 0` / `C-x 1` | close this window / close all others |
| `C-x d` | dired (file manager) |

## Moving

| Key | Action |
| --- | --- |
| `C-f` `C-b` / `M-f` `M-b` | char / word forward, back |
| `C-n` `C-p` | next / previous line |
| `C-a` `C-e` | line start / end (same as zsh) |
| `M-<` `M->` | buffer start / end |
| `C-v` `M-v` | page down / up |
| `C-l` | recenter (repeat: top, bottom) |
| `M-g g` | go to line |
| `C-s` / `C-r` | incremental search forward / back (again: next match) |
| `M-%` | query replace (`y` / `n` / `!` all) |

## Editing, selecting, copying

| Key | Action |
| --- | --- |
| `C-SPC` | set mark = start selection (or Shift+arrows) |
| `C-w` / `M-w` | cut / copy selection (Emacs: kill / kill-ring-save) |
| `C-y` | paste (yank); then `M-y` cycles older kills |
| `C-k` | kill to end of line (at line start: whole line) |
| `C-d` / `M-d` | delete char / word forward |
| `M-DEL` | delete word back |
| `C-o` | open line at point |
| `C-t` / `M-t` | transpose chars / words |
| `M-u` `M-l` `M-c` | upcase / downcase / capitalize word |
| `M-;` | comment (dwim) |
| `C-x h` | select all |
| `C-x C-;` | comment line (GUI only; terminal: `C-c ;`) |

## Help (the way to rediscover everything)

| Key | Action |
| --- | --- |
| `C-h k` | what does this key do? |
| `C-h f` / `C-h v` | describe function / variable |
| `C-h m` | help for the current mode(s) |
| `C-h b` | all bindings |
| `M-x` | run any command by name (fuzzy) |
| prefix + wait | which-key lists what can follow (e.g. `C-x`, then pause) |

`q` closes a help window.

## Own bindings (init.el)

| Key | Action |
| --- | --- |
| `C-c d` | duplicate line or region |
| `C-c ;` | comment / uncomment line (terminal-safe) |
| `C-c r` | recent files |
| `C-c s` | save a copy as executable script (for zsh's `Ctrl-X Ctrl-E`) |
| `C-c h` | fold / unfold code block (programming modes) |

## Shell (zsh emacs mode) vs Emacs

Same keys, same action: `C-a` `C-e` `C-f` `C-b` `M-f` `M-b` `C-k` `C-y`
`M-y` `M-d` `M-DEL` `C-d` `C-t`, and the selection keys `C-SPC` (start), `C-w`
(cut), `M-w` (copy), `C-g` (cancel). Differences:

| Key | zsh | Emacs |
| --- | --- | --- |
| `C-w` without selection | delete word left | cut from the mark |
| `C-g` without selection | abort the line | nothing to cancel |
| `C-u` | delete to line start | prefix argument (`C-u 8 *` → `********`) |
| `C-r` | fuzzy history (zaw) | search backward |

**Prompt → Emacs:** `C-x C-e` at the zsh prompt opens the line in Emacs;
`C-x C-s C-x C-c` puts the result back at the prompt. `C-c s` saves a copy as
a script.
