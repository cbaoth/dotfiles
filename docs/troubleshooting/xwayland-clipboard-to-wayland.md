---
title: Copy from wine/XWayland apps never reaches Wayland apps
hosts: [motoko, puppet]
status: workaround
tags: [clipboard, sway, wlroots, xwayland, wine, proton, keepassxc]
updated: 2026-10-17
---

# Copy from wine/XWayland apps never reaches Wayland apps

**Verdict: worked around by `bin/xwayland-clipboard-bridge`** (2026-10-17,
motoko; deployed to puppet, untested there). Copy in a wine/XWayland app,
paste in a Wayland app (foot, browser, ...) failed or was lost again. Paste
in the other direction (Wayland → wine) always worked.

## Cause

Not a broken bridge, a wlroots policy (sway 1.11, wlroots 0.19.2):

1. wlroots takes an X11 `CLIPBOARD` selection into the Wayland clipboard only
   while **an XWayland surface has focus** (`xwayland/selection/incoming.c`,
   "denying write access to clipboard: no xwayland surface focused", DEBUG
   log only).
2. wlroots **clears** the Wayland clipboard when the X11 owner goes away.
3. wine drops and re-takes clipboard ownership, e.g. when the in-app
   selection changes. If that happens while a Wayland window has focus, the
   copy is first cleared, then refused.

The same rule applies the other way: an X11 client cannot read the Wayland
clipboard while a Wayland window has focus (`xclip -o` from foot: "target
STRING not available"). That is why `xclip` tests run from a terminal were
false negatives (see the journal below).

Proton games may differ: in-game Ctrl-C in Path of Exile reached Wayland
even without the bridge (2026-10-17, not investigated).

## Fix: `bin/xwayland-clipboard-bridge`

A ~150-line system-Python daemon (`python3-xlib`, `xclip`, `wl-clipboard`,
all in `setup/packages/desktop.list`). It runs as the systemd user unit
`xwayland-clipboard-bridge.service`, started by
`exec systemctl --user start …` in `home/.config/sway/config.d/90-launch-apps.conf`.

- XFixes reports every `CLIPBOARD` owner change.
- Owner is a **real X11 client** → read the content with `xclip`, hand it to
  `wl-copy`. `wl-copy` keeps serving it after wine lets go, so point 2 above
  no longer loses anything.
- Owner belongs to the **wlroots XWM** (same client id base as the window in
  root's `_NET_SUPPORTING_WM_CHECK`, `_NET_WM_NAME` "wlroots wm") → skip.
  That content came from Wayland. It also prevents a loop: after `wl-copy`,
  the XWM owns the X11 clipboard again.
- Copies offering `x-kde-passwordManagerHint` → skip (backstop for password
  managers running under X11).
- Text first, else an image (`image/png`, `image/bmp`, ...) with its type.
- Contents are never logged: `journalctl --user -u xwayland-clipboard-bridge`
  shows owner, type and size only. `-v` also logs skips.

Wayland-native apps never pass through X11, so the bridge never sees them:
KeePassXC (flatpak, `QT_QPA_PLATFORM=wayland`, checked 2026-10-17) and wine
apps on the Wayland driver.

### Verified (2026-10-17, motoko)

| Case | Result |
| ---- | ------ |
| `xclip` copy with foot focused (wlroots alone: not synced) | bridged, `wl-paste` OK |
| PoB Ctrl-C, switch to foot, paste | OK |
| PoB: paste back into PoB after the bridge took ownership | OK |
| `xclip -t image/png` | bridged, `wl-paste -t image/png` byte-identical |
| X11 owner offering `x-kde-passwordManagerHint` | skipped |
| `wl-copy` (Wayland source) | skipped, no loop |

### Limits

- `PRIMARY` (select / middle-click) is not bridged.
- Right after a copy the wine app no longer owns the X11 clipboard. Pasting
  back into it works through the XWM relay, but an app that reacts to losing
  ownership may behave oddly.
- An X11 password manager would be bridged unless it sets the hint; its
  clear-timeout would then not clear the Wayland copy.

## Rejected: a clipboard keeper (`wl-clip-persist`)

Would also have fixed point 2, but not point 1 (the copy has to reach Wayland
first). It keeps *every* copy alive after its source is gone, so it fights
KeePassXC's clipboard clear: the keeper's job is to restore an emptied
clipboard. It also keeps the last secret in memory indefinitely, and needed
a `cargo install`. Fixing one wine gap by changing the lifetime of every
copy was the wrong trade.

## Journal

### Original TODO entry (moved verbatim from docs/TODO.md, 2026-10-17)

Copy from XWayland apps (e.g. Path of Building under wine) never reaches
Wayland apps: in-app copy/paste works, but nothing propagates to sway's
clipboard. Same class of symptom as flatpak↔flatpak copy failures
(XnView → ungoogled-chromium file/name copy).

**Root cause found (2026-09-08, motoko/sway 1.11):** the XWayland↔Wayland
clipboard bridge is dead in *both* directions, for *both* CLIPBOARD and
PRIMARY. Verified with **zero** clipboard managers running:

- `printf x | xclip -selection clipboard` → `wl-paste` does not see it.
- `printf x | wl-copy` → `xclip -selection clipboard -o` does not see it.
- same for `-selection primary` / `wl-paste --primary`.

Single Xwayland on `:0` (`-rootless … -wm 169`, i.e. sway is the XWM), so
it is not a wrong-X-server problem. Normally wlroots/sway syncs this
automatically, so something specific here is off.

**Ruled out:** copyq and diodon (bridge fails with nothing running).
Both were vestigial X11 clipboard managers from the old GNOME/Unity setup
adding their own chaos → copyq removed 2026-09-08 (package itself only
purged 2026-10-17, on motoko and puppet); diodon was no longer installed,
its leftover autostart entry and icon cache removed 2026-10-17 (both hosts).

**Bridge behaviour (refined 2026-09-08):** not simply dead — it appears to
engage only while an XWayland surface is mapped. With a real mapped X11
GTK window present, `xclip` and `wl-paste` finally agreed; with no
XWayland window, the two clipboards are fully independent. Even engaged,
the X11→Wayland direction is flaky (a mapped X11 app's own copy got
clobbered by the Wayland selection being pushed back into X11). Too shaky
to rely on for wine.

**Already fixed / sidestepped:**

- mpv path-copy bindings now use mpv's native Wayland clipboard
  (`set clipboard/text`) / `wl-copy` instead of xclip — see
  `home/.config/mpv/input.conf`.

- `bin/while-read` clipboard mode (`-c`, old `-x`/`--xclip` kept as alias)
  now polls `wl-paste` instead of xclip (2026-10-17). No script in this
  repo reads or writes the X11 clipboard any more; only `wl-copy` /
  `wl-paste`.

- **wine → native Wayland driver (primary avenue, pending verification).**
  wine 11.0 ships `winewayland.drv`; the `~/.wine` prefix was defaulting
  to x11 (→ XWayland → broken bridge). Set on `~/.wine`:
  `wine reg add "HKCU\Software\Wine\Drivers" /v Graphics /d "wayland,x11" /f`.
  Confirmed the driver loads and produces a **native** `xdg_shell` window
  (notepad: `app_id=notepad.exe`, no X11 id). Driver is per-prefix/per-
  wineserver, not per-app; Proton prefixes (bg3mm) are separate. Left ON
  pending an interactive copy test (copy in wine → `wl-paste`). Revert:
  `wine reg delete "HKCU\Software\Wine\Drivers" /v Graphics /f`. If it
  sticks, document as a setup step (machine state, not repo-tracked).
  Caveats: `xdg_toplevel_icon_manager_v1` unsupported (no window icons);
  sway `for_window` rules keyed on X11 `class` must switch to `app_id`.
  - **Clipboard: CONFIRMED working** under winewayland (copied SimpleGraphic
    text out to `wl-paste`). Goal achieved for wine→Wayland copy.
  - **GL init fix:** SimpleGraphic (PoB's renderer) is OpenGL. Default EGL
    dispatch sent wine's GL to Mesa dri2 on the NVIDIA card
    (`libEGL … driver (null)`, `failed to create dri2 screen`) → hang. Force
    NVIDIA's EGL vendor:
    `__EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json`.
    With that, EGL init is clean and wine creates a GL context and loops on
    `wglSwapBuffers` (verified via `WINEDEBUG=+wgl,+egl`).
  - **Remaining blocker:** even rendering, PoB's window presents blank/stuck
    on NVIDIA — a winewayland GL *presentation* rough edge (app runs at ~48%
    CPU swapping buffers but nothing visible). Non-GL wine apps (notepad) are
    fine. PoB kept on x11 (`Graphics=x11`) for now; revisit winewayland GL
    presentation on NVIDIA (wine/wlroots issue tracker) later.
  - **Driver mechanics learned:** graphics driver is per-wineprefix/per-
    wineserver, not per-app; every change needs `wineserver -k` to reload.
    `reg delete` reverts to wine's default (may be wayland on wine 11 with
    WAYLAND_DISPLAY set) — set `Graphics=x11` explicitly to force XWayland.

- [ ] [M] Root-cause the sway/wlroots XWayland clipboard sync failure:
  - Check `sway -V` / wlroots build, `swaymsg -t get_config`, and the sway
    log for XWM / clipboard errors right after an XWayland copy.
  - Confirm whether *real* mapped XWayland GUI clients sync (the CLI test
    with xclip uses an unmapped selection window — verify it is not a
    false negative by copying inside an actual X11 app and reading
    `wl-paste`).
  - Search sway/wlroots issues for 1.11 XWayland clipboard regressions.
  - ~~Only if it is genuinely a wlroots gap: a sync daemon~~ — not a gap,
    see findings below; `wl-clip-persist` (persistence) is the relevant
    tool after all.
  - For flatpak: check portal / clipboard permissions
    (`flatpak info --show-permissions`).
  - Reproduce on the notebook (puppet) too — same class of issue reported there.
  - **Findings 2026-10-17 (motoko, sway 1.11, wlroots 0.19.2, wine 11.0,
    PoB on `Graphics=x11`):**
    - The bridge is not broken. wlroots only takes an X11 selection into
      the Wayland clipboard while *an* XWayland surface has focus
      (`xwayland/selection/incoming.c`: "denying write access to
      clipboard: no xwayland surface focused", DEBUG log only). The owner
      window itself need not be focused or mapped.
    - Hence the old CLI test (`xclip` from foot) was a false negative by
      design. Controlled test: `xclip` with foot focused → not synced;
      with PoB focused → synced; Ctrl-C inside PoB with PoB focused →
      synced (owner: wine's hidden unmapped window).
    - wlroots also *clears* the Wayland clipboard when the X11 owner goes
      away (owner → None). PoB/wine appears to drop ownership when the
      in-app selection changes (`xclip -o` → "target STRING not
      available" afterwards), and was once seen holding the X clipboard
      while `wl-paste` was empty after focus moved to foot — suspected:
      wine released and re-acquired ownership while unfocused, so wlroots
      cleared and then denied. Unconfirmed; log owner changes to confirm.
    - Likely fix for the remaining loss: a clipboard keeper
      (`wl-clip-persist --clipboard regular`) — it re-serves the last
      content when the owner goes away, which also fixes "copied text is
      gone after closing the foot window" (normal Wayland semantics).
