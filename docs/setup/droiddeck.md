---
title: DroidDeck — Ubuntu in a PRoot on Android
hosts: [droiddeck]
status: workaround
tags: [android, proot, droiddeck, zsh, performance, flatpak, browser, arm64]
updated: 2026-11-14
automated_by: setup/modules/00-apt-base.sh
---

# DroidDeck (Ubuntu in a PRoot on Android)

[DroidDeck](https://github.com/Droid-Deck/DroidDeck) is an Android app that
runs a full Ubuntu (26.04, arm64, glibc) desktop: patched KDE/kwin, Mesa/Turnip
for the Adreno GPU, Steam/FEX. Hostname `DroidDeck` on every install. The
dotfiles detect it as `IS_ANDROID=true IS_PROOT=true` (`home/.common_env`).

## What it is (and is not)

- **A PRoot, not a container.** The rootfs is a plain directory in the app's
  private storage (`$PROOT_FP_ROOT`, under `/data/user/0/com.droiddeck.launcher/`).
  No namespaces, no PID 1, **no systemd**. Parent processes outside the rootfs
  are hidden (`/proc` is `hidepid=invisible`), which is what broke
  `cl::is_remote`'s ppid walk.
- **Not real root.** The user is the Android app UID (e.g. 10529) *named*
  `root`, `HOME=/root`. `link.sh` sees `EUID != 0` and treats it as a normal
  user, so the profile prompt applies (use `proot`, see below).
- **`sudo` works, passwordless.** `/usr/local/bin/sudo` (and `su`, `pkexec`,
  `apt`) are DroidDeck wrappers that run the command as uid 0 through the
  app's root socket (`droiddeck-root`). There is no password to know; `chsh`
  prompting for one is the real `chsh`, not the wrapper.

## Persistence

- Restarts keep everything: apt packages, `/etc`, `$HOME`.
- A **DroidDeck update** replaces the system and then re-installs "the apps
  you added" (its own restore step, log: `~/.cache/droiddeck/apt-restore.log`).
  Hand edits under `/etc` (e.g. the login shell in `/etc/passwd`) are likely
  lost — unverified until the first update. Set zsh in the Konsole profile as
  well; that lives in `$HOME`.
- Prefer per-user installs (`~/.local/bin`, zinit, fnm, uv): they do not
  depend on the restore step.

## Shell startup: forks are expensive

`exec` costs ~10 ms under PRoot (a `$(...)` subshell without exec ~1 ms).
Startup was 8.5 s and plugins were skipped on Android. Profiled 2026-11
(`zsh -i -c exit`, averaged):

| Change | Startup |
| ------ | ------- |
| before (any plugin mode) | ~8.5 s |
| `cl::p_dbg` fork-free (~100 calls, ~7 execs each) | ~2.1 s |
| + `skip_global_compinit=1` (Ubuntu's compinit rewrote the dump every start) | |
| + one `grep` in `cl::is_remote`, no `tr` in the flatpak alias loop | ~1.15 s |

`PLUGIN_MODE=full` vs `skip` is within noise after that, so Android now uses
`full` (`_PLUGIN_MODE_ANDROID` / `_PLUGIN_MODE_TERMUX` in `home/.zshrc`).
**Keep the startup path fork-free** rather than dropping plugins.

## system-setup: the `proot` profile

`system-setup --profile auto` guesses `proot` here. It selects only modules
that need neither systemd nor real kernel access: apt base + locale, XDG dirs,
fonts, browser repos, and the per-user tool installers (ffmpeg, fnm, yt-dlp,
uv, Claude Code, Copilot CLI). Not included: snap, nix, docker, tailscale,
sysctl, power, console, release upgrades, vicinae (systemd user service), and
flatpak apps (see Browsers). Termux is refused outright: own repos, no sudo.

## Linking: the `proot` profile

`tools/profiles/proot.list` = everything except the desktop integration
DroidDeck's KDE owns: `mimeapps.list`, GTK 2/3/4 settings, `portals.conf`.
KDE rewrites those, and through a symlink it writes into the repo. The vendor
originals were backed up by the first `full` link run under
`~/.local/state/dotfiles-link/backups/` (Breeze, `breeze-dark` icons,
`breeze_cursors` at size 30).

## Browsers

- **Firefox (native deb)** works with GPU: DroidDeck sets
  `security.sandbox.content.level=0` in `/usr/lib/firefox/defaults/pref/droiddeck.js`
  and `MOZ_DISABLE_*_SANDBOX=1`. The permanent "security sandbox is disabled"
  bar has no pref; hide it in the profile's `chrome/userChrome.css`:
  `notification-message[value="sandbox-content-disabled"] { display: none !important; }`
  plus `toolkit.legacyUserProfileCustomizations.stylesheets=true` in `user.js`.
- **Chromium-based flatpaks** (Vivaldi) crash: the Chromium sandbox calls the
  `Flatpak.Spawn` portal ("only works in a flatpak", DroidDeck replaces bwrap).
  With `--no-sandbox --no-zygote` they run, but software-rendered: the flatpak
  runtime has no DroidDeck Mesa. A copy of the app's `.desktop` file in
  `~/.local/share/applications/` with those flags fixes the launcher.
- Native arm64 debs use the host's patched Mesa; prefer them over flatpaks for
  anything GPU-heavy.
- **`25-browsers` runs in the `proot` profile.** Vivaldi, Chrome and Brave
  publish arm64 debs in the same repos as on the PC (checked 2026-11); Edge
  does not and is skipped. The Mozilla repo and its pin come from DroidDeck,
  so the module leaves them alone. `bin/browser-wrapper` adds `--no-sandbox`
  under PRoot (no user namespaces, no real root for the setuid helper).
  Only `BR_PROOT_INSTALL` (vivaldi-snapshot) is installed here; the other
  browsers get their repo only, `sudo apt install` them when needed.
  GPU use of native Chromium here is untested.

## Input

Desktop sessions default to **touchpad mode** (relative cursor, tap = click,
two-finger scroll): the Android side translates touch before kwin sees it, so
KDE's input settings cannot change it (`kcm_mouse: Error on receiving device
list from KWin`). Other touch modes exist in the DroidDeck app; a Bluetooth
mouse paired with Android works as a normal pointer.
