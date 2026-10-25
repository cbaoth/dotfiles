---
title: foot color themes (foot-theme)
hosts: [motoko, puppet]
status: resolved
tags: [foot, terminal, theme, palette]
updated: 2026-10-25
---

# foot color themes

foot has exactly **two** palettes, `[colors-dark]` and `[colors-light]`
(foot ≥ 1.26; 1.28 removed the old `[colors]`/`[colors2]` names), toggled with
`Ctrl+Shift+t` (`color-theme-toggle`). No version supports more, and none can
reload its config at runtime. `bin/foot-theme` works around both: it recolors
**one window** with escape sequences (OSC 4/10/11/12/17/19), so any number of
themes can be tried, cycled, and compared side by side in separate windows.

## Layout

| Path (`~/.config/foot/`) | Contents |
| ------------------------ | -------- |
| `foot.ini` | main config; `include=`s the two palette files |
| `theme-dark.ini` | the `[colors-dark]` palette (default) |
| `theme-light.ini` | the `[colors-light]` palette (`Ctrl+Shift+t`) |
| `themes/*.ini` | theme library: collected favorites, one theme per file |

Library files are verbatim copies of
[iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes)
`foot/*.ini` (plus a `# Source:` line), so its whole collection works as a
theme directory too. `[colors-light]` is reported as the *light* scheme to apps
that query it (mode 2031), even when the palette is dark.

## Usage

```zsh
foot-theme list                 # library, * = this window's theme
foot-theme apply Eldritch -p    # recolor this window, then print a preview
foot-theme next / prev          # cycle alphabetically (wraps)
foot-theme reset                # back to the configured palette
foot-theme -d ~/git/iTerm2-Color-Schemes/foot next   # browse the full collection
FOOT_THEME_LIST='Eldritch:GitHub Dark:Tango Black' foot-theme next  # own list
foot-theme save dark 'GitHub Dark Default' -c 'daytime'  # new default palette
```

- **State is per window:** the current theme is kept per terminal session in
  `$XDG_RUNTIME_DIR/foot-theme/` (gone after logout). If it is not in the list
  being cycled (renamed, other `-d`), next/prev start over at the first theme.
- **`save`** rewrites `theme-{dark,light}.ini` through the symlink, i.e. in the
  dotfiles repo: commit it to share it. It only takes effect in **new**
  windows.
- **Not settable per window:** the cursor's text color, `dimN`, `alpha`. They
  apply only once a theme is saved.
- `Ctrl+Shift+t` also drops a theme applied with `foot-theme`.
- Completion: `_foot-theme` completes theme names from the active directory.
