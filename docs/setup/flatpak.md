---
title: Flatpak — apps and sandbox permissions
hosts: [motoko]
status: resolved
tags: [flatpak, desktop, sandbox]
updated: 2026-07-12
automated_by: setup/modules/20-flatpak.sh
---

# Flatpak

**Automated:** `system-setup 20-flatpak` — installs flatpak, adds the Flathub
remote, installs [`setup/packages/flatpak-desktop.list`](../../setup/packages/flatpak-desktop.list),
and grants NAS access to the apps that need it.

## apt or flatpak?

Full decision rule and the cases that bit:
[../reference/package-managers.md](../reference/package-managers.md). The short
version — **does anything else have to invoke it by name?** A flatpak is not on
`$PATH`, so scripts, aliases, and `xdg-open` handlers cannot reach it.

- **apt** when something invokes it: `mpv` (see below), ffmpeg, CLI tools; plus
  drivers, PAM, and the browsers.
- **flatpak** for self-contained GUI apps you only ever click: GIMP, Krita, VLC,
  Signal, Obsidian, KeePassXC.

**mpv is apt, not flatpak** — [`bin/mpv-find`](../../bin/mpv-find) and the `@MPV`
alias both pipe into `xargs ... mpv`, which needs a real binary. The flatpak
breaks them silently.

**KeePassXC is flatpak**, and this is worth stating because the old notes said
the opposite. A sandboxed *browser* cannot do native messaging to KeePassXC —
that is true, and it is why the browsers stay native. But a sandboxed
*KeePassXC* serving a native browser is fine, and the flatpak tracks upstream
much more closely, which matters because the extension complains when KeePassXC
is too old.

## The sandbox will bite you

Flatpak apps cannot see `/srv/saito` (or any host path outside `$HOME`) by
default. Every app that needs the NAS gets an explicit override — the module does
this, but only on machines where `/srv/saito` actually exists.

Override syntax lives in [../reference/flatpak.md](../reference/flatpak.md).
[Flatseal](https://flathub.org/apps/com.github.tchx84.Flatseal) is the GUI
equivalent and is installed by default.

App data does **not** land in the usual places:

| Kind | Path |
| ---- | ---- |
| Config | `~/.var/app/<app.id>/config/` (instead of `~/.config/`) |
| Data | `~/.var/app/<app.id>/data/` (instead of `~/.local/share/`) |
| Cache | `~/.var/app/<app.id>/cache/` |

To let other users reach FUSE mounts (Cryptomator), uncomment `user_allow_other`
in `/etc/fuse.conf`.

## Known app quirks

### XnViewMP — frozen for a minute on drag-and-drop

A Qt/X11 app on Wayland. Trying to close the window while frozen makes it close
*after* the timeout, which looks like a crash but is not.

```shell
flatpak override --user --env=QT_QPA_PLATFORM=xcb com.xnview.XnViewMP
```

Do **not** set `QT_QPA_PLATFORM=xcb` globally. Every Qt Wayland-native app would
then lose portal-based screen capture, the richer Wayland clipboard, correct
fractional scaling, and portal file pickers — a large price for fixing
drag-and-drop in one app.

If video thumbnails or playback do not work, enable the internal video player in
`~/.config/xnviewmp/xnview.ini` (`useInternalVideoPlayer=true`). Setting
`QT_XCB_GL_INTEGRATION=xcb_egl` was tried and made the window go black — avoid.

### AppImages

Need `libfuse2t64` installed. [Gear Lever](https://flathub.org/apps/it.mijorus.gearlever)
(in the list) manages them — it creates the desktop entries and metadata that
AppImages otherwise lack.

## See also

- [../reference/flatpak.md](../reference/flatpak.md) — override/permission cheatsheet
- [browsers.md](browsers.md) — why the browsers come from apt
