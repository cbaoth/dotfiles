# Introduction

This document covers the one-time setup steps required to run Sway on Ubuntu when migrating from (or alongside) a GNOME desktop. It focuses on things that are **not** handled automatically by the config files or the `sway-start` launch script — those are considered working by definition.

The Sway configuration lives at `~/.config/sway/config` (symlinked from `dotfiles/dotfiles/.config/sway/config`). The launch script is `~/bin/sway-start`.

# Required Packages

Install before first launch. Some of these are optional but strongly recommended.

``` bash
sudo apt install \
  sway swaylock swaynag swayidle \
  foot \
  waybar \
  rofi \
  mako-notifier \
  grim slurp \
  brightnessctl \
  swayosd \
  network-manager-applet \
  xdg-desktop-portal-wlr \
  playerctl \
  flameshot
```

|  |  |
|----|----|
| Package | Purpose |
| `sway`, `swaylock`, `swaynag`, `swayidle` | Core Sway components |
| `foot` | Primary terminal emulator (Wayland-native, default `$term`) |
| `waybar` | Status bar (replaces i3bar/i3status) |
| `rofi` | Application/run launcher (`mod+r`, `mod+space`) |
| `mako-notifier` | Notification daemon (`org.freedesktop.Notifications`) |
| `grim`, `slurp` | Screenshot tools (Wayland-native, used by `flameshot` on Wayland or as CLI tools) |
| `brightnessctl` | Backlight control (replaces `xbacklight` which is X11 only) |
| `swayosd` | On-screen display for volume/brightness/caps-lock (see [Volume / Brightness OSD](#volume--brightness-osd-swayosd)) |
| `network-manager-applet` | nm-applet tray icon (WiFi/VPN status) |
| `xdg-desktop-portal-wlr` | XDG desktop portal backend for wlroots compositors (Sway). Required for file pickers, screen sharing, and other portal-based features in Firefox, VS Code, etc. Ubuntu ships `xdg-desktop-portal-gnome` by default which requires a GNOME session. |
| `playerctl` | Media key support (used by `media-keys` script) |
| `flameshot` | Screenshot GUI (Print key binding) |

> [!NOTE]
> `ulauncher` is intentionally excluded. Rofi covers the use case and works reliably on Wayland without a background daemon.

# Launching Sway

Sway must be started from a TTY (not inside an existing Wayland/X11 session). The `sway-start` script sets required environment variables and, if the proprietary Nvidia driver is detected (or forced via `--nvidia`), adds the Nvidia-specific flag/vars automatically.

``` bash
# In a TTY — stop GDM first if it is running
sudo systemctl stop gdm

# Launch Sway, redirect output for debugging
sway-start >/tmp/sway.log 2>&1
```

To inspect startup issues:

``` bash
cat /tmp/sway.log
```

## Why stop GDM?

Running Sway on top of an active GDM/GNOME session causes conflicts: many apps (browser, KeePassXC, etc.) detect an existing instance and refuse to open a second one, or connect to the GNOME session’s D-Bus services instead of the Sway session’s.

If you want to keep GDM running (e.g., for multi-seat), you can switch to a free VT and start Sway there, but the app-conflict issue remains.

# Secrets / Keyring

**`gnome-keyring-daemon` with the secrets component** is the secrets provider for both Sway and GNOME sessions. It provides `org.freedesktop.secrets` on D-Bus, which is used by VS Code, Chromium-based browsers, and most other apps.

KeePassXC is used as a standalone password manager only — its Secret Service Integration must remain **disabled** (`Tools → Settings → Secret Service Integration`) to avoid claiming `org.freedesktop.secrets` and conflicting with gnome-keyring.

> [!NOTE]
> KeePassXC’s Secret Service implementation has a known limitation: it fails silently when the database is locked, so apps that check at startup (VS Code, browsers) see "no keyring" even if the database unlocks a moment later. gnome-keyring handles this correctly with proper session unlock semantics.

## Setup (one-time per machine)

The gnome-keyring-daemon override is managed by the dotfiles repo at `dotfiles/dotfiles/.config/systemd/user/gnome-keyring-daemon.service.d/no-secrets.conf` (symlinked to `~/.config/systemd/user/gnome-keyring-daemon.service.d/`). It explicitly enables all three components (`pkcs11,ssh,secrets`):

``` bash
mkdir -p ~/.config/systemd/user/gnome-keyring-daemon.service.d
ln -sf ~/dotfiles/dotfiles/.config/systemd/user/gnome-keyring-daemon.service.d/no-secrets.conf \
    ~/.config/systemd/user/gnome-keyring-daemon.service.d/no-secrets.conf
systemctl --user daemon-reload
systemctl --user restart gnome-keyring-daemon
```

## Keyring unlock

`pam_gnome_keyring.so` auto-unlock never applies here:

- **GDM auto-login** skips the password prompt entirely, so PAM has no password to match against the keyring password.

- **U2F / YubiKey login** (sudo, screen lock, etc.) similarly provides no passphrase for gnome-keyring to consume.

The `Default_keyring` (user-set password) is used. The first app that needs secrets triggers a gnome-keyring unlock dialog; the user enters the password once and it stays unlocked for the session. This applies identically in GNOME and Sway sessions.

There is no `login.keyring` by design. If a spurious one appears (can happen if gnome-keyring-daemon is restarted while a session is live and PAM is not involved), remove it:

``` bash
systemctl --user stop gnome-keyring-daemon gnome-keyring-daemon.socket
rm -f ~/.local/share/keyrings/login.keyring
systemctl --user start gnome-keyring-daemon.socket gnome-keyring-daemon
```

## VS Code

VS Code must be told explicitly to use gnome-libsecret. File at `~/.config/Code/argv.json` (note: `Code/` root, not `Code/User/`):

``` json
{
  "password-store": "gnome-libsecret"
}
```

### VS Code in Sway: XDG_CURRENT_DESKTOP workaround

Even with `password-store=gnome-libsecret` set, VS Code shows *"OS keyring couldn’t be identified for storing the encryption related data"* and falls back to basic-text storage when launched in Sway.

Root cause: Electron calls `safeStorage.isEncryptionAvailable()`, which in turn calls into Chromium’s `OSCrypt::IsEncryptionAvailable()`. Chromium checks `XDG_CURRENT_DESKTOP` and returns `false` for any desktop it does not recognise (GNOME, KDE, MATE, Cinnamon are recognised; `sway` is not). This `false` result short-circuits the `password-store` setting — VS Code never attempts to use gnome-libsecret.

The fix is `~/bin/code` (symlinked from `dotfiles/bin/code`), a wrapper that sets `XDG_CURRENT_DESKTOP=GNOME` before exec-ing the real binary. It only overrides the variable when not already in a recognised desktop, so the wrapper is a no-op in GNOME sessions. `portals.conf` statically selects the `wlr` portal backend, so changing `XDG_CURRENT_DESKTOP` inside VS Code does not affect file pickers or screen sharing.

`~/.local/share/applications/code.desktop` (symlinked from dotfiles) overrides the system `.desktop` to call `code` (the wrapper, found via PATH) instead of `/usr/share/code/code` directly, so both terminal and rofi drun invocations go through the wrapper.

## Cloud file services (GNOME Online Accounts)

GNOME Online Accounts (`goa-daemon`) — used by Nautilus for Google Drive and OneDrive integration — requires a full GNOME session and is not available in Sway regardless of which secrets provider is used. Use sync clients (rclone, nextcloud, etc.) for cloud file access instead.

# XDG Desktop Portal

Ubuntu ships `xdg-desktop-portal-gnome` as default. Outside a GNOME session it times out, breaking file pickers (Firefox save dialogs, VS Code open file, etc.) and screen sharing.

The Sway config handles this by:

1.  Propagating `WAYLAND_DISPLAY` and `XDG_CURRENT_DESKTOP=sway` to the systemd user session via `dbus-update-activation-environment`.

2.  `~/.config/xdg-desktop-portal/portals.conf` (symlinked from dotfiles) explicitly selects the `wlr` backend — no `GNOME` session required and no manual portal restart needed at startup.

The portal starts on demand via D-Bus socket activation and reads `portals.conf` automatically. No `exec` restart in sway config is needed or wanted — restarting the portal at the same time waybar starts causes a race condition.

If file pickers or screen sharing still fail, restart manually:

``` bash
systemctl --user status xdg-desktop-portal.service
# Should be: active (running)

# Manual restart if needed
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway DISPLAY
systemctl --user restart xdg-desktop-portal
```

# KeePassXC

KeePassXC is launched via sway config (`exec flatpak run org.keepassxc.KeePassXC`). The XDG autostart entry (`~/.config/autostart/keepassxc.desktop`) has `NotShowIn=sway;` so systemd’s autostart generator does not start a duplicate.

KeePassXC with the **SSH Agent** integration (Settings → SSH Agent) can serve as the SSH agent, injecting keys after database unlock. This works independently of GNOME Keyring.

## Window placement

The sway config makes all KeePassXC windows **floating and sticky** (visible on every workspace). This is essential: without it, the unlock prompt and Secret Service auth dialogs appear on the assigned workspace (ws10 by default) while apps waiting for secrets appear to hang on other workspaces.

The regex `(?i).*keepassxc.*` is required (not `keepassxc.*`) because the Flatpak app_id is `org.keepassxc.KeePassXC` — sway anchors the regex, so the `.*` prefix is necessary to match.

## Minimize to tray

Enable **Tools → Settings → GUI → Close button minimizes instead of quitting the application** in KeePassXC so that closing the main window hides it to the system tray rather than exiting. The database remains unlocked and the Secret Service integration stays active.

## Browser integration

KeePassXC browser integration works when the browser is installed via `apt` (not Flatpak). Flatpak browsers cannot access the KeePassXC socket.

# Waybar

Waybar is configured at `~/.config/waybar/config.jsonc` (symlinked from `dotfiles/dotfiles/.config/waybar/config.jsonc`).

The Ubuntu system default (`/etc/xdg/waybar/config.jsonc`) includes `custom/media`, `custom/power`, and `mpd` modules that require scripts and services not present in a minimal setup — it will crash on first start without user config.

The user config uses safe built-in modules only. Waybar icons use Unicode characters from common symbol fonts; for the full icon set install a Nerd Font or Font Awesome:

``` bash
sudo apt install fonts-font-awesome
```

## One-time setup

Ubuntu enables `waybar.service` in the systemd user session by default (`preset: enabled`). When the graphical session activates, systemd starts waybar with the **system** config before Sway has a chance to start it with the user config — causing two competing instances and unreliable bar display.

Mask the service so Sway exclusively manages waybar via `swaybar_command`. `disable` alone is insufficient because the package preset enables it in global scope — `mask` creates a `/dev/null` symlink that overrides all presets:

``` bash
systemctl --user mask waybar
```

# Notifications

`mako` is used as the notification daemon. It starts via `exec mako` in the Sway config. Without a notification daemon, apps silently drop notifications or log errors to stderr.

Basic `mako` configuration (optional) goes in `~/.config/mako/config`. The defaults work without any config file.

# Volume / Brightness OSD (swayosd)

`swayosd` draws the on-screen volume/brightness overlay and applies the change (PipeWire/WirePlumber-aware). The keys are bound in the Sway config to `swayosd-client` (`XF86AudioRaiseVolume` etc., plus `$mod+Alt+=/-/0`); those talk over D-Bus to a running `swayosd-server`.

**Server as a systemd user unit.** The server runs via `~/.config/systemd/user/swayosd.service` (deployed from `dotfiles/.config/systemd/user/swayosd.service`), started from the Sway config with `exec systemctl --user start swayosd.service` — *after* the `dbus-update-activation-environment --systemd` line, so it inherits `WAYLAND_DISPLAY`. No `systemctl --user enable` is needed; deploying the two files is enough.

Why a unit instead of a bare `exec swayosd-server`: the server registers **two** session-bus names (`org.erikreider.swayosd` and `org.erikreider.swayosd-server`, the latter is what `swayosd-client` calls). Started too early it can win the first name but never finish registering the second, leaving the volume keys silently dead (`org.freedesktop.DBus.Error.ServiceUnknown`) while the process still appears to run. `Restart=on-failure` in the unit recovers from that race automatically.

Diagnosing if the keys ever go dead again:

``` bash
busctl --user list | grep erikreider          # both names must be present
systemctl --user restart swayosd.service       # re-register cleanly
```

`swayosd` also ships `swayosd-libinput-backend.service`, a system service that grabs input globally so swayosd can show an OSD for keys it captures itself (Caps/Scroll/Num-Lock). **This setup does not use it** — the media keys are bound in the Sway config — and it plays no part in the volume/brightness OSD. It ships disabled; leave it that way (no action needed). If a package upgrade ever enables it per its preset, that is harmless. A `SwayOSD LibInput Backend isn't available, waiting...` line from the server (`journalctl --user -u swayosd.service`) is expected and can be ignored.

# Idle Inhibit & Keep-Awake

`swayidle` locks after 15 min and blanks the display after 60 min (see the `exec swayidle` line in the Sway config). Two mechanisms suppress this when appropriate, and a waybar module shows the current state at a glance.

**Automatic (media/games)** — `wayland-pipewire-idle-inhibit` keeps the screen awake whenever audio plays through PipeWire, filtering short notification sounds via `media_minimum_duration` (config: `~/.config/wayland-pipewire-idle-inhibit/config.toml`). Apps that set their own inhibitor (Firefox video, mpv) and any fullscreen window (`inhibit_idle fullscreen` catch-all) are covered too. These register as **application** inhibitors.

Install (prebuilt binary from nixpkgs, requires Determinate Nix / Nix):

``` bash
nix profile add nixpkgs#wayland-pipewire-idle-inhibit
```

Alternatives: `cargo install wayland-pipewire-idle-inhibit` (needs `libpipewire-0.3-dev libspa-0.2-dev clang`), or the AUR/Nixpkgs packages.

**Manual (`sway-awake`)** — `bin/sway-awake` toggles a keep-awake state on demand. It holds a Sway **user** idle inhibitor via a tiny invisible holder window (app_id `sway-awake-idle-inhibitor`), which is what lets the bar tell manual mode apart from automatic mode.

``` bash
sway-awake toggle          # on/off
sway-awake toggle 30m      # on, auto-off after 30 min (also: 45s, 90, 1h)
sway-awake status          # off / manual / auto
```

- Hotkey: `$mod+Alt+x` enters the system mode, then `a` toggles (or `Shift+a` toggles with a 30-min auto-off).
- Waybar `custom/sway-awake` module: coffee = manual (yellow), film = auto (blue), moon = off. Left-click toggles, right-click enables a 30-min auto-off. Colors encode *why* the screen is awake (manual vs media), not which button was pressed. The timeout uses a transient `systemd --user` timer (`sway-awake-timeout`).
- Dependency: the bar's automatic (blue) state uses `pactl` to detect active audio — install `pulseaudio-utils` (`sudo apt install pulseaudio-utils`). Without it, media that does not set its own inhibitor is still kept awake by the PipeWire tool, but the bar will not surface the blue "auto" state.

# Nvidia Proprietary Drivers

The `sway-start` script auto-detects the proprietary Nvidia driver (via `/sys/module/nvidia`) and, when active, sets:

- `WLR_NO_HARDWARE_CURSORS=1` — software cursor (hardware cursors not supported by the proprietary driver under wlroots)

- `sway --unsupported-gpu` — required flag for the proprietary driver

`XDG_CURRENT_DESKTOP=sway` is set unconditionally (required for portal backend selection regardless of GPU driver).

Detection (and thus the flag/vars above) goes away on its own once the open kernel modules (nvidia-open) or Nouveau are in use — no script changes needed. Use `--nvidia` / `--no-nvidia` to override the auto-detection.

# Known Harmless Log Noise

The following messages appear in `/tmp/sway.log` and can be ignored:

|  |  |
|----|----|
| Message | Reason |
| `!!! Proprietary Nvidia drivers are in use !!!` | Expected; suppressed by `--unsupported-gpu` |
| `compositor does not implement the XDG toplevel icon protocol` | Optional protocol; Sway does not implement it, apps fall back gracefully |
| `compositor does not implement the XDG system bell protocol` | Same as above |
| `xkbcomp: Unsupported maximum keycode 708` / virtual modifier warnings | XWayland limitation; X11 keycodes cap at 255. Harmless for Wayland-native apps. |
| `Gtk-CRITICAL: gtk_widget_get_scale_factor` | nm-applet/libayatana issue on Wayland; cosmetic, tray icon still works |
| `libayatana-appindicator is deprecated` | nm-applet upstream issue; no user impact |
