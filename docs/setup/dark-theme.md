---
title: Dark theme across toolkits (Qt6 / Qt5 / GTK3 / GTK2)
hosts: [motoko]
status: resolved
tags: [theme, dark-mode, qt, gtk, gtk2, sway, desktop, kvantum]
updated: 2026-09-19
---

# Dark theme across toolkits

On a Sway (non-Plasma, non-GNOME-session) desktop, "make everything dark" is
per-**toolkit**, not one global switch. The desktop already advertises the
preference; each toolkit picks it up differently — or not at all.

The one thing that ties it together: the **xdg-desktop-portal** reports
`org.freedesktop.appearance color-scheme = 1` (prefer-dark). Verify with:

```shell
gdbus call --session --dest org.freedesktop.portal.Desktop \
  --object-path /org/freedesktop/portal/desktop \
  --method org.freedesktop.portal.Settings.Read \
  org.freedesktop.appearance color-scheme      # => (<<uint32 1>>,)
```

## The rule of thumb

| Toolkit | Dark on this box | What it needs |
| ------- | ---------------- | ------------- |
| **Qt6** | **automatic** | Qt 6.10 + Fusion read the portal — nothing to configure |
| **Qt5** | needs a nudge | `QT_QPA_PLATFORMTHEME=gtk3` (plugin `qt5-gtk-platformtheme`) — no Qt5 GUI apps here yet, so not set |
| **GTK3/4** | yes | `gtk-application-prefer-dark-theme=1` in `~/.config/gtk-{3,4}.0/settings.ini` + the portal; **flatpaks are a special case** → [flatpak.md](flatpak.md) |
| **GTK2** | **manual** | `~/.gtkrc-2.0` naming a dark GTK2 theme (ignores everything above) |

**Kvantum / qt5ct are obsolete here — do not re-add them.** See below.

## Qt6 — already dark, do nothing

Qt 6.10 (Ubuntu 26.04) reads the portal's `color-scheme` and applies a dark
palette via the Fusion style with no config. Proven by probing a bare PySide6
app: `QApplication().palette()` window colour comes back `#2a2a2a` (dark) with
`QT_QPA_PLATFORMTHEME` unset. So **no Qt packages, no env var, no qt6ct** are
needed for Qt6 dark.

**nextcloud-desktop (Qt6)** is the caveat: its QWidget windows follow the dark
palette, but its modernized **QtQuick / QML tray popup** (QuickControls2) themes
itself independently of the Qt palette and renders light. That is app-internal —
no env var reliably overrides it — and is left as-is.

## GTK2 — the one that needed work (doublecmd)

`doublecmd` is installed as `doublecmd-gtk`, i.e. the **GTK2** widgetset
(`libgtk-x11-2.0`), not Qt/KDE as its "kvantum era" history suggests. GTK2 reads
**none** of the GTK3/4 `settings.ini`, gsettings, or the portal, so it renders
light regardless of the rest of the desktop. Fix: name a dark GTK2 theme in
`~/.gtkrc-2.0` (tracked as [`dotfiles/.gtkrc-2.0`](../../dotfiles/.gtkrc-2.0)):

```
gtk-theme-name="Yaru-magenta-dark"
gtk-icon-theme-name="Yaru-magenta-dark"
gtk-font-name="Ubuntu Sans 11"
```

`Yaru-magenta-dark` (matching the GTK3 theme) already ships a `gtk-2.0/` variant
from `yaru-theme-gtk` (part of `ubuntu-desktop`, so present on any desktop box; a
host without it falls back to the GTK2 default silently). doublecmd's own
`<Colors>` in `doublecmd.xml` are theme-default, so this darkens **both** the
chrome and the file panels — no per-colour hex editing needed. Restart doublecmd
to apply.

## Kvantum / qt5ct — obsolete, removed (do not retry)

An earlier attempt (before Qt6 handled the portal) installed the **Kvantum**
SVG style engine + qt5ct and never produced a reliable dark result. With Qt6
dark now automatic, that whole stack does nothing — no `QT_STYLE_OVERRIDE` or
`QT_QPA_PLATFORMTHEME` is set anywhere, so the style was never even active.
Removed 2026-09-19:

```shell
sudo apt purge qt-style-kvantum qt-style-kvantum-l10n qt-style-kvantum-themes \
                qt5-style-kvantum qt6-style-kvantum
# libqt5x11extras5 autoremoved with them (Kvantum-Qt5 dependency) — expected
rm -rf ~/.config/Kvantum ~/.config/QtProject.conf   # stray, untracked
```

Kept: `qt5-gtk-platformtheme` / `qt6-gtk-platformtheme` (harmless; the Qt5 one is
the mechanism a future Qt5 app would use via `QT_QPA_PLATFORMTHEME=gtk3`).

**If a Qt app is ever light in future, do not reach for Kvantum.** The order is:
is it Qt6 (should be dark already — restart it), Qt5 (`QT_QPA_PLATFORMTHEME=gtk3`),
or GTK2 (`~/.gtkrc-2.0`)? Determine the toolkit first: `ldd $(which app) | grep -iE 'libQt|libgtk'`.

## Not automated

No `setup/` module: the GTK2 dark preference is a single tracked dotfile
(`dotfiles/.gtkrc-2.0`, deployed by `dotfiles-link`), Qt6 needs nothing, and the
Kvantum removal was a one-off cleanup of a mistake, not repeatable desired state.

## See also

- [flatpak.md](flatpak.md) — the same "app renders light" problem for
  **non-libadwaita GTK flatpaks** (e.g. Safe Eyes), fixed per-app with
  `GTK_THEME=Adwaita:dark`.
- [../reference/flatpak.md](../reference/flatpak.md) — override/env cheatsheet.
