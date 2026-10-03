Ideas and future tasks for improving the shell scripts in this repository.

**Effort:** S = < 1 hr · M = 1–4 hrs · L = > 4 hrs

# 1. Code Quality & Maintenance

## Repository Housekeeping

- [ ] [S] Review and resolve FIXME/TODO comments in `system-scripts/dbbackup`
- [~] `~/bin/` vs `~/.local/bin/`: keeping `~/bin/` for now — conventional, most distros add it to `PATH` automatically. Revisit if a full XDG migration is planned.
- [ ] [S] Consider organizing `bin/` scripts by category if the collection grows

## Linting & Static Analysis

- [ ] [M] Integrate [ShellCheck](https://www.shellcheck.net/) into the development workflow
  - VS Code extension: [ShellCheck for VS Code](https://marketplace.visualstudio.com/items?itemName=timonwong.shellcheck)
  - Run against all scripts: `find bin/ lib/ system-scripts/ -type f -exec shellcheck {} +`
  - Consider a `.shellcheckrc` for project-wide settings
- [ ] [S] Evaluate [shfmt](https://github.com/mvdan/sh) for consistent formatting

## Pre-Commit Hooks

- [ ] [M] Investigate [pre-commit](https://pre-commit.com/) framework and set up hooks:
  - ShellCheck (see [pre-commit docs](https://github.com/koalaman/shellcheck?tab=readme-ov-file#pre-commit))
  - shfmt formatting check
  - Custom hook for shebang and file header validation

## Testing

- [ ] [L] Evaluate and adopt a shell testing framework ([BATS](https://github.com/bats-core/bats-core) or [ShellSpec](https://github.com/shellspec/shellspec))
- [ ] [M] Write tests for `lib/commons.sh` utility functions
- [ ] [M] Consider tests for critical `bin/` scripts (argument parsing, edge cases)

## Consistency Audit

- [ ] [L] Repo-wide audit for redundant, outdated, broken, or unused scripts, functions, and features
- [ ] [M] Build an inventory of repeated or diverging implementations (logging, output formatting, argument parsing)
- [ ] [M] Define consolidation targets; migrate callers to `lib/commons.sh` or a shared loader where sensible
- [ ] [M] Establish a ShellCheck cleanup baseline and iteratively reduce warnings to near-zero for active scripts

## Locale & Collation (LC_ALL=C)

Interactive `sort`/`uniq` now default to byte collation via `alias sort='LC_ALL=C
sort'` / `alias uniq='LC_ALL=C uniq'` (deterministic order, faster, avoids the
`_a` vs `a` locale-interleave and the classic `sort | uniq`/`comm`/`join`
mismatch bug). Aliases only reach *interactive* shells, so standalone scripts and
sourced libs need explicit handling. `lib/functions.sh` already fixed
(2026-09-19).

- [x] [S] Document the convention in the shell style guide
  (`docs/shell-style-guide.md`) and AI instructions
  (`.github/instructions/cb-shell-script.instructions.md`). **Done 2026-09-19.**
  Key points:
  - **When it matters:** any `sort` feeding `uniq`/`comm`/`join` (both sides must
    agree), and where reproducible output is wanted. A C-sort next to a
    locale-`uniq` is the actual dedup bug — worse than doing nothing.
  - **When it does not:** pure `sort -n` / numeric-field sorts (locale barely
    affects them) and human-facing alphabetical *display* (rare in scripts).
  - **Standalone scripts:** prefer a single `export LC_ALL=C` (or `LC_COLLATE=C`)
    near the header over prefixing every command.
  - **Sourced files (`lib/*.sh`, `.zsh.d/`): NEVER `export` at file scope** — it
    clobbers the user's whole interactive locale. Use per-command `LC_ALL=C`
    prefixes (or `local LC_ALL=C` inside a function).
- [x] [S] Audit remaining `bin/` scripts for candidates (not a blind sweep — many
  hits are false positives: jq `unique`, fzf `--no-sort`, a var named `sort`,
  Python `sorted()`). `bin/diff-ini` (`sort -u` for INI comparison) is the main
  determinism candidate; numeric sorts (`sway-ws`, `image-concat`) can stay.
  **Done 2026-09-19:** `bin/diff-ini` fixed via `export LC_COLLATE=C` near the
  header (structural diff — `sort -u` must be byte-exact). Everything else
  confirmed a non-candidate: numeric sorts (`sway-ws`, `image-concat`),
  human-facing display order (`mpv-find` playback, `ff-copy-mpv-bookmarks`,
  `exif-sanitize` ASCII help keys), and false positives (Perl/Python `join`,
  var named `sort`).

## Aliases & Functions Review

- [ ] [S] When touching `.zsh.d/` files, opportunistically review nearby aliases/functions for conversion candidates:
  - Multi-line aliases or aliases with complex quoting → convert to functions
  - Trivial single-line functions with no arguments → consider converting to aliases (if simpler)
  - Note: global (`-g`) and suffix (`-s`) aliases must remain aliases; no function equivalent exists

# 2. Script & Library Improvements

## commons.sh

- [ ] [S] Fix known typos in comments (e.g., `FUNCTONS` → `FUNCTIONS`)
- [ ] [S] Add missing type declarations (`-r`, `-i`, `-a`) and ensure all functions have documentation comments
- [ ] [S] Consider versioning `commons.sh` for backward compatibility tracking
- [ ] [M] Streamline the commons.sh sourcing mechanism across scripts. One option: a `commons-loader.sh` wrapper that scripts source with a 1-liner, handling candidate paths and required-symbol validation:

  ```bash
  source "${HOME}/lib/commons-loader.sh" || exit 1
  cl::require_commons || exit 1
  ```

## Specific Scripts

- [ ] [S] Review `.vimrc` local settings to confirm modeline options (`expandtab`, `tabstop=2`, `shiftwidth=2`, `filetype`) align with the canonical header block
- [ ] [M] `bin/while-read`: add a concurrency-limited job queue for `--background`.
  Currently `-b` spawns one process per input with no throttle, so e.g.
  `while-read -b wget` fed a stream of URLs launches unbounded parallel `wget`s.
  A simple FIFO queue capping concurrent jobs at N would fix this (this was the
  never-finished intent of the removed `.zsh.d/job.zsh` stub; original ref
  <https://blog.garage-coding.com/2016/02/05/bash-fifo-jobqueue.html>, now dead).
  See the `# TODO implement a simple queue` marker in `read_loop()`.

## General Output

- [ ] [S] Consolidate output text formatting if gaps remain
  - Consider [Zsh Prompt Expansion](https://zsh.sourceforge.io/Doc/Release/Prompt-Expansion.html) for zsh scripts (e.g., `print -P "%Uunderlined%u"`)

## Zsh Plugins (zinit)

Follow-ups after the zplug → zinit migration:

- [ ] [S] Turbo-load `zsh-autosuggestions` and `zaw` too (currently loaded
  synchronously so their keybindings resolve). Move their `bindkey` calls into
  `atload'…'` ice so the widgets exist when bound, then drop the sync loads.
- [ ] [S] Clean up leftover zplug state once the migration is confirmed good:
  `rm -rf ~/.zplug ~/.zplug-skip-install-prompt ~/.zplug-force-install`.
- [ ] [S] Re-evaluate `zsh-expand` config vars (`ZPWR_EXPAND*`, `ZPWR_CORRECT`,
  `ZPWR_EXPAND_BLACKLIST`) and the dropped `magic-space` binding after living
  with the new space-key behavior.
- [ ] [S] Audit the OMZ plugin list — several were loaded but rarely used; prune
  what you don't need to further cut startup cost.
  2026-09: broken/redundant ones removed (catimg, docker, git, git-extras, mvn,
  tmux, vagrant, web-search). Never-used ones are commented out as "ON TRIAL"
  in `.zshrc` (encode64, jsontools, systemd, urltools, vscode): try or delete.

# 3. Desktop / Sway Setup

GDM is currently required only to provide a graphical login. Since Sway is started manually from a TTY (`sudo systemctl stop gdm && sway-start`), GDM adds overhead with no benefit.

**Prerequisite:** Sway must be confirmed stable (waybar, keyring, key bindings all verified working) before making any change permanent.

Options (in order of preference):

- **No display manager** — TTY auto-login via systemd drop-in + auto-start sway from `~/.zprofile`
  - Pros: minimal, no extra packages, full control
  - Cons: no graphical greeter (acceptable if YubiKey unlock happens inside sway)
- **greetd + tuigreet** — modern Wayland-native session manager; proper PAM/keyring integration; designed for wlroots compositors
- **LightDM** — familiar, well-supported on Ubuntu; more overhead; X11-centric but Wayland sessions work

## Tasks

- [ ] [S] Decide on approach (no-DM vs greetd vs LightDM)
- [ ] [S] `sudo systemctl disable gdm` — stop GDM from starting at boot
- [ ] [M] Configure chosen session startup method
- [ ] [S] Update `docs/setup/sway.md` with chosen approach and steps
- [ ] [S] Verify YubiKey unlock still works (KeePassXC prompt visible at login)
- [ ] [S] Verify GNOME remains usable if needed (`sudo systemctl enable gdm`)

## Conky

- [ ] [M] Add conky config for puppet (notebook): derive from motoko config, adapt for
  smaller viewport, no Nvidia GPU, no Windows/dual-boot partitions

## Clipboard — XWayland ↔ Wayland bridge not working (motoko)

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
adding their own chaos → copyq removed 2026-09-08; diodon autostart still
present (`~/.config/autostart/diodon-autostart.desktop`), remove too.

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
  `dotfiles/.config/mpv/input.conf`.

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
  - Only if it is genuinely a wlroots gap: a sync daemon (e.g.
    `wl-clip-persist` is for *persistence*, not X11↔WL sync — wrong tool;
    look for an actual bridge). Earlier daemon attempt was abandoned
    without real setup effort.
  - For flatpak: check portal / clipboard permissions
    (`flatpak info --show-permissions`).
  - Reproduce on the notebook (puppet) too — same class of issue reported there.

## Game streaming — Moonlight / Sunshine (parked 2026-08-16)

Snaps removed 2026-08-16. The client is easy (Flatpak, same version); the open
question is the **Sunshine host on motoko**, where AppImage/Flatpak cannot do
KMS capture at all — `setcap` has no real binary to attach to. Full context,
including the unverified udev/ufw setup that was already applied:
[`docs/troubleshooting/sunshine-kms-capture.md`](troubleshooting/sunshine-kms-capture.md).

- [ ] [S] Try the Moonlight **Flatpak** client — likely a straight swap
- [ ] [M] Sunshine host: try the native `.deb` instead of the AppImage, so
      `setcap cap_sys_admin+p` works and KMS capture is available
- [ ] [S] Re-check the `usermod -aG input` step — it grants read access to every
      input device including the keyboard; the `uaccess` udev tag may suffice
- [ ] [S] If it sticks, extract a `setup/` module + `docs/setup/` note and drop
      the `~/Applications` AppImage symlink (invisible to `dotfiles-link`)

## Chorded Keybindings — keyd / xremap (dropped 2026-08-15)

Both experiments were removed along with `docs/misc/` (the configs remain in git
history at `93d3913`). What replaced them lives in
`dotfiles/.config/xkb/symbols/custom` — pure xkb, no daemon.

Why each was dropped, plus the Super/Mod4 and VS Code dead ends:
[`docs/troubleshooting/xkb-altgr-key-mappings.md`](troubleshooting/xkb-altgr-key-mappings.md).

- [ ] [M] Revisit only if a WM with weaker keybinding coverage than sway is
      adopted (GNOME, …). A chord prefix needs an evdev-level remapper; check
      first whether that compositor lets the remapper's own keymap survive.

## Window Placement & Layout Persistence

Background, with the sway-1.11 source traces behind every claim:
[`docs/reference/sway-window-placement.md`](reference/sway-window-placement.md).

Done 2026-09-30: workspace placement migrated from `for_window … move container
to workspace` to `assign` (the former re-fires on title change after a reload and
on every remap — that was the "window jumps back to its assigned workspace" bug),
and `bin/sway-float-geometry` now brackets suspend to stop floating windows
piling up in the centre on resume
([note](troubleshooting/sway-floating-geometry-on-resume.md)).

Remaining:

Done 2026-09-30: `bin/sway-arrange` ($mod+Alt+x mode: 1 vscode, 2 browser,
0 all) sweeps each app's windows onto their mapped workspace and sets the tab
order, from `dotfiles/.config/sway/window-map.conf` (rule order = tab order).
Two measurements shaped it: a VS Code title is still **null** at `window::new`,
so per-folder placement can never be a rule; and `move container to mark`
inserts after the mark, so ordering needs no `move left/right` walking.
Grouping into a tabbed container needed no code — `workspace_layout tabbed`
already does it.

- [ ] [M] Two sibling tabbed containers on one workspace (ws3: code tabbed
      left, browsers tabbed right). `workspace_layout tabbed` puts every child
      of a workspace in ONE tabbed container, so a newly built container lands
      *inside* it rather than beside it (measured). Needs a per-workspace
      `workspace_layout` override, or building the split above sway's automatic
      container. This is the one piece of the original "place + tab + order"
      goal still done by hand.
- [ ] [S] Ordering across two apps sharing a workspace is undefined —
      `sway-arrange` orders each app within itself only. Currently worked around
      by running the apps in the desired order.
- [ ] [M] `bin/sway-layout` — snapshot/restore the container tree of
      **already-running** windows: workspace, nesting, `tabbed`/`stacked`, order,
      split ratios. Never relaunches anything, so `con_id` matching is exact
      within a session and there is no cross-boot identity problem. Build it with
      `splith`/`splitv` + `move` + `focus` + `layout tabbed`, and
      `resize set <n> ppt` applied top-down shallowest-first with the last child
      left unsized. There is no `append_layout` in sway (PR #3022 closed
      unmerged, 2020), so no placeholder/swallow shortcut exists.
- [ ] [L] Only if the above proves insufficient: relaunch + cross-boot matching
      via a hand-curated title-regex map, along the lines of `sway-layout` (Go)
      or `sway-session-restore`. Note up front that this **cannot** be fully
      automatic for VS Code and browsers — they serve N windows from one process,
      so `/proc/<pid>/cmdline` cannot say which window is which.
- [ ] [S] Evaluate `window_type=dialog` and `shell=xwayland` in
      `70-window-rules.conf`. `window_type` is the generic "is this a dialog"
      handle and would collapse the per-dialog rules; `shell` is a cleaner
      XWayland discriminator than maintaining paired `app_id`/`class` twins.
      Overlaps the `class` → `app_id` switch that winewayland forces (see the
      *Clipboard* subsection above).
- [ ] [S] Remaining `assign` gap: a genuine unmap/remap still re-fires the rule
      (`view_unmap()` clears the per-view executed-criteria list), so an XWayland
      window that remaps can still jump back. A full fix needs an IPC daemon that
      marks manually-moved windows and refuses to re-place them. Deferred —
      `assign` covers the common cases.
- [ ] [S] Watch sway/wlroots for `xdg-session-management-v1` (already in KWin
      6.4 and Mutter). It solves window identity across restarts properly and
      obsoletes most of the above.
- [ ] [S] Confirm the `after-resume` restore timing over a few real suspend
      cycles; raise `--wait` before reaching for a `sleep` if windows still land
      centred.

# 4. Dotfiles Linking Enhancements

Current implementation documented in `docs/linking-system.md`. Low priority; revisit only if requirements change.

## Host-Specific Configuration

- [ ] [M] Implement a clean host-specific override mechanism (replaces ad-hoc `_overrides/`):
  - Option A: Conditional loading in `.zshrc`/`.bashrc`: `[[ -f ~/.zshrc.local.$(hostname) ]] && source ...`
  - Option B: Extend `link-config.conf` to define host-specific sync directories per hostname
  - Option C: Adopt chezmoi if multi-host templating becomes complex (currently single-user, single-host focus)
- [ ] [S] Host-specific opt-out for global AI agent instructions (work PC): skip linking
  `dotfiles/.claude/rules/` + `dotfiles/.copilot/` and/or leave `COPILOT_CUSTOM_INSTRUCTIONS_DIRS`
  unset there, so personal conventions (esp. commit messages — Gerrit at work) don't leak into
  work repos. Could reuse the host-override mechanism above (e.g. per-host `.linkignore` entries).
  See `docs/agent-instructions.adoc`.

## Extensibility

- [ ] [M] Add support for symlink groups (e.g., `gaming-tools`, `work-setup`) that can be toggled on/off
- [ ] [S] User-level override config (`~/.dotfiles-link-local.conf`) for personal customizations
- [ ] [S] Dry-run mode that estimates space impact (useful on constrained systems)

## Observability & Debugging

- [ ] [M] Add optional JSON output mode (`--format=json`) for automation/dashboards
- [ ] [S] Checksum-based verification to detect if a symlink target has been modified on disk vs. repo
- [ ] [M] Optional hook system: `run_before_link()` / `run_after_link()` for custom setup steps

## Documentation

- [ ] [S] Add troubleshooting guide to main README linking to `docs/linking-system.md`
- [ ] [S] Document recovery from accidental file deletions using the backup copies
- [ ] [S] Consider `.nolink` as a more discoverable alternative to `.linkignore` (low priority)

# 5. Archived Scripts Backlog

Scripts in `_archive/` awaiting individual evaluation: keep as-is, update/rewrite, find a modern alternative, or delete.

- [ ] [S] `audio-volume.sh` — Toggle mute/volume via hotkeys. Likely superseded by `bin/media-keys`; confirm full overlap then delete.
- [ ] [S] `gallery.sh` — Static HTML image gallery with JPEG thumbnails (2005). Evaluate against modern alternatives (sigal, thumbsup).
- [ ] [S] `getbyext.sh` — Fetch media files by extension via wget (2001). Compare with `bin/getbyext`; delete if redundant.
- [ ] [S] `pdfprint.sh` — Print PDF/PS with n-up and duplex via `psnup` (2003). Check if still functional; evaluate cups/lp alternatives.
- [ ] [S] `backup2ftp.sh` — Copy backups to FTP server (2010). Consider replacing with rsync/sftp/rclone if FTP backup is still needed.
- [ ] [S] `wget-mp.py` — Parallel wget in Python 2 (2010). Evaluate against `bin/wget-p` and modern alternatives (aria2c).
- [ ] [S] `clear-cache.sh` — Clear local caches and temp files (2011). Cache paths likely stale; review and update or delete.

# 6. Git & Cross-Host Workflow

## Auth: move own repos to SSH with dedicated per-host keys

Current state: the dotfiles remote (and other own repos) use **HTTPS with a
shared "saito" PAT**, copied by hand to saito, the vserver, and sometimes work,
and left in plaintext via a repo-local `store` helper (`~/.git-credentials`).
The credential *cache* was an ad-hoc "stop asking me" workaround. One token
reused everywhere = large blast radius; manual copying; plaintext at rest.

Target: **SSH for own repos, with a dedicated key _file_ per host** — not agent
forwarding, which keeps breaking on WSL/dev-containers and depends on a
long-lived setup that never quite stays working. Each host's public key added
to the GitHub account (or a per-repo deploy key). Then: no PAT, nothing to copy,
per-host revocation, works headless.

**Progress (2026-08-15, puppet):** `dotfiles`, `AutoHotkey` and `notes` all use
SSH remotes here, verified with `git pull` (and `push` for `dotfiles`), and
`~/.git-credentials` is gone on this host. Remaining hosts untouched.

Deliberate deviation from the "key file per host" target above: there are **no
key files in `~/.ssh`**. The ed25519 keys live in KeePassXC and are published to
the session SSH agent by its agent integration. This is not agent *forwarding*,
so the objection above does not apply — and it is arguably better than key
files: encrypted at rest in the vault, and revocable from one place. Open
question is only whether the remaining hosts follow the same model.

- [ ] [M] Generate a dedicated ed25519 key per remote host (saito, vserver,
      WSL@work); add each to GitHub; retire the shared PAT.
- [~] [S] Switch own-repo remotes from HTTPS to SSH
      (`git remote set-url origin git@github.com:cbaoth/<repo>.git`).
      Done on puppet; still to do on motoko, saito, vserver, work.
- [ ] [S] vserver: account-key vs. a write **deploy key** scoped to only the
      repos it needs (it may push notes back). Narrower is better.
- [ ] [S] Remove the plaintext `~/.git-credentials` / repo-local `store` helper
      once SSH is in place.
- [ ] [S] WSL: local key file over agent forwarding (the fragile path). Real
      work identity/paths live in `~/notes`, not in this public repo — the
      `includeIf` template in `dotfiles/.gitconfig.local.example` is ready.

## Automated cross-host file sync (deferred)

For now, cross-host coordination = git (dotfiles + `~/notes`) as the bus, plus
`bin/hsync` (rsync wrapper) for blobs. That is likely sufficient.

- [ ] [S] Evaluate **Syncthing** for continuous, bidirectional saito<->vserver
      (and maybe desktop) sync of a shared working dir. It sidesteps the
      NordVPN-inbound problem via relays and needs no manual trigger, but wants
      install + device pairing on both ends. Revisit if `hsync` proves too manual.

## Quick Notes

Just some quick unrefined notes, before I forget:

- `bin/bt-audio-reset` fails when no profile is active
  - `ERROR: card 'bluez_card.AC_80_0A_15_0E_96' has no active A2DP profile (currently: off)`
  - example scenario (with WH-1000XM4):
    1. start voice input in vscode github copilot chat -> switches to HSP/HFP MSBC
    2. stop voice input -> switches to off (instead of back to the best A2DP profile)
  - potential fixes:
    - instead of resetting, which could reset to an undesired profile like in this case off, choose the best possible profile for the device. i assume there is a way to identify it, or potentially some kind of default for hifi stereo audio output. if not consider some kind of lookup (which profiles do exist) and choose the best from a predefined (hard coded list). simplest but least desirable case: hard code A2DP SBC-XQ (works for WH-1000XM4 at least).
    - check the github copilot chat extension behavior: why does it behave this way? can the behavior be changed?
  - hints:
    - the script is used by a sway shortcut (`dotfiles/.config/sway/config.d/40-keybindings.conf`)
    - i verified that the claude code extension, opposed to copilot, always selects A2DP SBC-XQ after turning of voice input, no matter which profile was active before initiating voice input (including off). so it seems to choose the best profile automatically, which is the desired behavior (at least for WH-1000XM4)
- evaluate if our custom dotfiles linking system is still the best option for all hosts
  - consider that i would like to have at least a minimal root user setup as well, which is currently not the case. i tried to use the dotfiles repo for root, the basics seem to work, but i think it's a bad idea unless we clearly separate certain things, ensure that no canonical paths to user space are used, and ensure that shell scripts and such are safe to run with root permissions (mostly not designed for that purpose, might be dangerous, mess with file permissions, or similar).
  - i had juast a very brief look into the following tools, there might be more, but i think they are worth a look and evaluation. all "claims" are just anecdotes i read online, vague from memory (so not necessarily accurate):
    - [chezmoi](https://www.chezmoi.io/) - seems to be the pretty popular, but i think it may be a bit overkill for our use case (as far as i understand it).
      - e.g., we don't need templating for example (single user + root, no enterprise setup), no extra key management (unless it can be a reasonable addition to keepassxc and gnome keyring). while the encryption feature seems nice, it may be overkill as well (we try to keep sensitive data out of this repo, i'm considering making the repo proviate which would at least lower the risk of data leaks; but whatever we do, there is always the risk of e.g. some app writing a sensitive token into a config file that is tracked by git).
    - [yadm](https://yadm.io/) - seems to be more minimalistic than chezmoi, but also less popular. a single comment i read claims, that it uses tools that are no longer maintained. but i also read that it uses common gnu/linux tools only, which makes it future proof.
      - https://github.com/yadm-dev/yadm (assuming that's the official and best maintined repo) - last commit bbb58e (as of 2026-09-19) was over 1 year ago at 2025-03-23, so it seems to be not very actively maintained it seems.
    - [nix home](https://nix-community.github.io/nix-home/) - seems to be a bit more complex, but also more powerful. i saw some github repos of people who migrated from chezmoi to nix os or nix home (+ ansible), and they seemed to be happy with the decision.
      - regarding nix: some say that nix os in particular (not an option for me, at least right now) is great, after a steep learning curve, while others say that it is great as long as it works, but as soon as something breaks, it can be a nightmare to fix plus it needs a lot of disk space due to the way it works.
      - regarding ansible: we setup our own system-setup scripts. i have some experience with ansible (not a lot, and some time ago), but if it is still considered a good and modern option, it might be worth a second look. considering that at least nix os seems to combine both in one.
  - related things to consider, if not already covered by the current solution, or a potential future solution (open topic, see previous point:
    - orphan pruning of symlinks (see `tools/link.sh`), potentially empty dirs as well (this can however be dangerous, unless we know that i dir is only used for dotfile repo purposes).
    - potentially an uninstall option, to remove all symlinks (and other fs objects that were created by the dotfiles setup, and that can safely be removed)

# 7. System Updates — Reminders & Auto-Update

**Open for a planning session (not started).** Goal: stop relying on memory to
keep software current across hosts. Decide per source and per host what should
update automatically, what should only produce a reminder, and how that
reminder reaches the user.

**Trigger (2026-09-24):** the Tailscale client on the vserver (11001001) was
outdated without anyone noticing. It only came up because `tailscale get
operator` failed with an unknown subcommand; `sudo tailscale update` fixed it.
Without that accident it would have stayed outdated for a long time.

**Current state, as far as known:**

- Only **apt** is auto-updated, via unattended-upgrades, and not everywhere:
  it is **disabled on motoko** (boot-time updates were a nuisance), so apt is
  updated by hand there. Options and the "fold into bedtime-shutdown" idea are
  in [docs/setup/unattended-upgrades.md](setup/unattended-upgrades.md); verify
  each host's actual state. Also check which origins are allowed: third-party
  repos (Tailscale, browsers, Netdata) are probably not covered by the default
  config.
- **flatpak**: several desktop apps, practically never updated unless an app
  prompts or something breaks.
- **snap**: rarely used, but present.
- **Containers** (docker on saito and the vserver): images updated only by hand.
  - Pinned to exact versions on purpose, so an update is an edit plus a
    `compose up -d`, never a surprise. What is missing is the *notification*
    that a new release exists — the pin means nothing tells you.
  - **A container upgrade can carry a checklist item**, not just a new tag:
    SilverBullet runs with `user: "1000:1000"` only because 2.10.0 silently
    ignores `PUID`/`PGID` (the rust rewrite dropped the setup shim). If a later
    release restores it, that line can go — and if the workaround ever stops
    working, the space fills with root-owned `.md` files that SilverBullet and
    `sb-sync` then cannot write. So whatever mechanism reports new images
    should be able to carry a per-service "re-check this on upgrade" note.
    Details: `~/notes/systems/11001001/silverbullet.md`.
- **Software outside package managers** (software with their own update features,
  static binaries, vrious package managers, etc.), e.g.:
```bash
# should work unless it is installed via deb package, which it should not
yt-dlp --update

# zsh plugin manager (--all is implied by default)
# note that per repo the git log is shown using a pager (per default)
# in this case (other may exist) it might be helpful to check for fatal git errors (e.g. "fatal: Not possible to fast-forward, aborting.") since from what i can tell, the zinit command still success in such a case.
zinit update

# claude code cli may notify, and i'm not sure what happens when updating while instances are running (update may exit, not sure)
claude update   # Claude Code

# npm update npm -g  # nodejs `node`, `nvm`, 'npm`
# presumably best to only use fnm where possible instead of installing a single nodejs version into a fixed location in home
fnm install --lts && fnm default lts-latest` (no update iirc, but install, and maybe uninstall e.g. the previous version?)

# at least assuming the user is tailscale operator (see `tailscale get operator`, either `cbaoth` or empty), which should be the case on desktop and notebook, but is currently not the case for servers (saito, vserver).
tailscale update

# python pip: `pip install --upgrade pip` (or `python -m pip install --upgrade pip`) but wouldn't work with system python (deb package), so unless conda, venv, or similar is currently used (not done by default), this may be worth an alias but presumably not an auto update mechanism. also consider that from what i know `uv` should always be the prefered method nowadays.
uv self update

# rust/cargo
rustup update
```
  - One exception is `nix`, which prints a "MOD" message when opening a new shell, or connecting remotely via SSH. Which can be a bit annoying at times (rather regularly, maybe a weekly or bi-weekly cadence would suffice), but at least it is a reminder. Auto update would surely be convenient, if it can be done reliably and safely (e.g. weekly cron/timer early in the morning, or on next startup when the system was down, which is likely the case for desktop and notebook).
- There is no regular habit of checking for updates. In practice updates happen
  only when a tool nags or when something breaks or is missing.
- Existing helpers: the `pk*` shell functions/aliases (e.g. `pku` updates apt,
  snap and flatpak in one go). They only run when invoked by hand.
- Consider that some updaters may install script snippets into .zshrc, .bashrc, .profile, or similar. this should be avoided since the current config should already handle these cases. And there is a presumably low risk, that an update requires a change in the way the tool environments are set up.

On a somewhat related note, it would be good if there were some kind of install mechanism for at least some of the tools mentioned above (vs. searching online), since it's usually just a `curl | bash` or similar command that could easily be added to a script or alias. Examples:

```bash
# https://docs.astral.sh/uv/getting-started/installation/
curl -LsSf https://astral.sh/uv/install.sh | sh

# https://github.com/Schniz/fnm
curl -fsSL https://fnm.vercel.app/install | bash

# https://github.com/DeterminateSystems/nix-installer
curl -fsSL https://install.determinate.systems/nix | sh -s -- install

# https://doc.rust-lang.org/cargo/getting-started/installation.html
curl https://sh.rustup.rs -sSf | sh

# https://github.com/VocaHQ/vocalinux/blob/main/docs/INSTALL.md
curl -fsSL https://raw.githubusercontent.com/VocaHQ/vocalinux/main/install.sh -o /tmp/vl.sh
bash /tmp/vl.sh
# note: snap may be an option in the future (iirc still in review, thus old version or manual download only), in which case auto update would be convenient.
#   at the the time of writing this, using the installer script is the recommended way
#   flatpak and appimage exists as well, afaik both with manual update only


```

For these it might be sensible to reference the official install doc or repo page so the user can have quick look to confirm that the install procedure is still the recommended one. Or alternatively just show or open the url (basically a bookmark instead of a adding the code to our repo). On the other hand we already have a few such cases (e.g. `bin/ffmpeg-install`, `setup/modules/27-wine.sh`, `setup/modules/35-tailscale.sh`, and more).


**Questions for the session:**

- [ ] [L] Inventory per host (puppet, motoko, saito, 11001001): what is installed
      from which source, and how does each source update today?
- [ ] [M] Where is auto-update safe and reasonable (e.g. flatpak apps on
      desktops, security-only on servers), and where should it stay a
      reminder only (e.g. containers with state, anything on the public vserver)?
- [ ] [M] Native options first: unattended-upgrades origins, flatpak's own
      update timer or GNOME Software, snap refresh (already automatic?), and
      container options (Watchtower or similar; or just a "newer image
      available" check).
- [ ] [M] Reminder channel: login/MOTD message, zsh startup hint, waybar/tray
      indicator on desktops, ntfy (already used for Netdata alerts; see
      [docs/setup/monitoring.md](setup/monitoring.md)), or a periodic report.
- [ ] [S] Review the `pk*` functions: keep, extend (flatpak/snap/containers/
      non-package tools), or replace with whatever comes out of this.
- [ ] [S] If parts are idempotent: `setup/` module(s) plus a `docs/setup/` note,
      as usual.

# 8. system-setup — Profiles & Host Targeting

Not urgent; for a later discussion. Context: saito still has a full desktop
installed (historically a TV box with a VNC server), is being slimmed down to a
server, and may later run a few GUI apps remotely only (Wayland remote
protocol). The profile system has to cope with hosts like that.

- [ ] [M] **Per-host profile override.** Pin a host to a profile (e.g. saito →
      `server`) so `--profile auto` or a mistyped `--profile desktop` cannot
      apply desktop-only steps there. Discuss other use cases (per-host module
      opt-in/opt-out, host-specific values), pros/cons, and how it relates to
      the linking system's host overrides (§4 *Host-Specific Configuration*).
- [ ] [M] **Desktop detection.** `st::is_desktop` now only checks for a
      graphical session (`WAYLAND_DISPLAY`/`DISPLAY`); the `gnome-shell` check
      was dropped (2026-09-24) because leftover desktop packages made servers
      look like desktops. Modules now use the chosen `--profile` via
      `st::profile` rather than guessing again. Open: a fresh desktop install
      may be set up from a TTY/SSH (auto then detects `server`). Goal both ways:
      no server-specific steps on a desktop, no desktop-specific steps
      (e.g. the Tailscale operator) on a server.
- [ ] [S] Revisit the Ansible question (`setup/README.md` *Why bash and not
      Ansible*; also the tool evaluation in §6 *Quick Notes*) if host targeting
      makes the bash runner noticeably more complex.

# 9. SSH / firewall (added 2026-09-23)

See `docs/setup/ssh-hardening.md`; host-specific addresses in
`~/notes/systems/motoko/ssh.md`.

- [x] [S] motoko: add the ufw rules for port 22 (done 2026-09-24, rules
      `[12]`–`[15]` on `wlp14s0`; verify a real login from the notebook)
- [ ] [S] saito: run `system-setup 56-sshd` to adopt the managed baseline — the
      hand-written `10-hardening.conf` gets replaced and its `AllowUsers` moves
      to `01-local.conf` automatically; verify the dry-run says so
- [ ] [M] 11001001: adopt the module — rename `01-hardening.conf` to
      `01-local.conf`, keep only the host-specific lines, and update
      `bootstrap-new-server.sh` in the notes repo so a rebuild does not
      reintroduce the old file
- [ ] [S] motoko: review ufw rules `[9]`/`[10]` — KDE Connect `1714:1764` is
      open from Anywhere, on every interface including `tailscale0`
- [ ] [M] motoko: narrow ufw rule `[11]` (`ALLOW IN 10.0.24.0/24`, the direct
      link to saito) to the services that link actually carries

# 10. Prompt, Terminal Theme & Shell Startup (added 2026-09-25)

**State:** powerlevel10k replaced by starship (zinit `gh-r`, config
`dotfiles/.config/starship.toml`, based on the `tokyo-night` preset + username/
hostname for ssh/root). foot has two palettes: Tango in `[colors]` (default)
and Tokyo Night in `[colors2]`, toggled with `Ctrl+Shift+t` — kept on purpose
as a side-by-side comparison tool (no scrolling, no second window).

## Terminal palette (foot)

- [ ] [M] Research foot themes + starship presets online and find a combo that
      works as a whole. Constraints learned so far:
  - Pure black background preferred (`000000`); a grey one (foot's default
    `242424`) is not wanted.
  - **`ls` type contrast matters most:** Tokyo Night was rejected on this —
    regular files turn bluish and blur into blue directories, symlinks sit
    in between with no clear hue difference. Tango keeps white files.
  - Light text on mid/bright backgrounds is hard to read (see prompt below).
- [ ] [S] Once decided, move the winner into `[colors]`. `[colors2]` counts as
      the *light* theme for apps querying mode 2031, so it must not be the
      permanent dark choice. Keep the toggle for future comparisons if useful.
- [ ] [S] Consider `LS_COLORS` / `dircolors` tuning if the palette alone
      doesn't give distinct file types.
- [ ] [S] Consider an explicit foot font (`font=FiraMono Nerd Font:pixelsize=12`):
      `monospace` resolves to DejaVu Sans Mono, Nerd Font glyphs only render
      via fallback.
- [ ] [S] Evaluate foot server mode (`foot --server` + `footclient`; units
      `foot-server.{service,socket}` are installed and enabled by the package
      but inactive — sway's `$term` is plain `foot`). Pros: faster window
      startup, one shared font/glyph cache (less RAM). Cons: all windows die if
      the server crashes; config changes need a server restart; windows inherit
      the server's environment, not the launching shell's.

## Starship prompt — build our own, step by step

Liked facets per preset: tokyo-night (current base; left edge "emerges" from
the window border with `░▒▓`), catppuccin-powerline (black text), gruvbox-rainbow
(calm warm tint, prompt on its own line), pastel-powerline (triangular
separators, time segment). Hard requirements: input on its **own line** in a
fixed column; see when it's **not my user** (root/other/ssh) and which host
over ssh.

- [ ] [S] Path segment readability: preset uses `#e3e5e5` on `#769ff0`
      (contrast 2.08). Dark text fixes it: `#1a1b26` → 6.5, `#090c0c` → 7.5.
      Same idea for any light-text-on-bright segment.
- [ ] [S] Prompt character: the old style — a solid block with a background
      color ending in a triangular tip, `λ` inside (or a compact variant);
      color reflects state (error, vi command mode, sudo cached, root).
- [ ] [S] Re-add modules the preset dropped and the old prompt had: exit
      status, command duration, sudo indicator, background jobs, battery
      (notebook), plus language/tool modules beyond the preset's five
      (python, docker, …).
- [ ] [S] Separators: triangles instead of rounded ends (optional; rounded is
      fine for now).
- [ ] [S] Root: decide on a separate, lightweight root shell setup instead of
      root using this repo (see §6 *Quick Notes* — root setup / linking).
- [ ] [S] Drop leftover p10k state once settled (every host):
      `zinit delete romkatv/powerlevel10k` and `rm -f ~/.cache/p10k-*`.
- [ ] [S] Maybe: foot `prompt-prev`/`prompt-next` (`Ctrl+Shift+z/x`, jump
      between prompts in scrollback) need OSC 133 prompt marks — check whether
      starship emits them or a small precmd hook is needed.

## Shell startup time

Measured on motoko: ~1.6 s full, ~1.5 s even with `PLUGIN_MODE=skip` — plugins
and prompt are no longer the bottleneck.

- [ ] [S] `.common_env`: cache `determinate-nixd completion zsh` output to a
      file, regenerate only when the binary changes (**0.6 s** per start).
- [ ] [S] `.common_env`: lazy-load nvm on first `node`/`npm`/`nvm` use
      (~0.17 s). Benefits bash too.
- [ ] [M] Profile the remaining ~0.7 s of `.zshrc` (zprof, or
      `PS4='+%D{%s.%6.} %N:%i> ' zsh -xic exit`); `compinit` without a
      cache check is a suspect.
- [ ] [S] Simplify plugin modes: drop `mini` — since the OMZ `git` plugin was
      removed (2026-09), `full` now differs from it only by `ssh-agent`. Keep
      `full` and `skip` (debugging kill switch, Termux).
- [ ] [S] Keep the one-line fallback prompt (`$IS_STARSHIP || prompt fade 0`),
      but drop the per-host `prompt fade N` overrides in `zshrc-motoko.zsh` /
      `zshrc-puppet.zsh` (only matter without starship).

# 11. Root shell dotfiles (added 2026-09-26)

A separate, stripped-down, safer dotfiles deployment for `root`, used on every
host (irrelevant elsewhere). Motivated by the tmux auto-attach trial: parked
`sudo -i` root shells can live for days in a session, and my own risk tolerance
for that is "fine for now" — but a root-only profile lets us add a root-only
idle timeout without touching the interactive user shell (where an idle timeout
is unwanted: I deliberately leave prepared commands sitting at a prompt).

- [ ] [M] Design a root profile with **no canonical references to a user's
      `$HOME`** — no sourcing `/home/<user>/...`, no files owned by root landing
      in a user home. Decide the mechanism (own `bin/` deploy target, or a
      guarded minimal set of files) so `dotfiles-link` can deploy it as root
      without dragging in the full user config.
- [ ] [S] Once the root profile exists: add a **root-only idle timeout**
      (`(( EUID == 0 )) && TMOUT=<n>` in the root rc). Covers `sudo -i`,
      `sudo -s`, `su -`. Best-effort only — `TMOUT` fires at an idle prompt,
      not while a foreground program (vim, `journalctl -f`) is running.
- [ ] [S] Revisit after living with tmux auto-attach on saito / 11001001:
      if forgotten root shells actually bite, raise priority; if not, this can
      stay parked.


## Text to speeck (TTS)

look into TTS options. it should help reading longer texts; including AI agent responses (e.g. claude code), articles, and documentation.

basice piper test setup already done:

```shell
cd ~/
# common venv already created in the past
# use `uv venv` to create a new one if needde
. ./.venv/bin/activate
uv pip install piper-tts

# download some default voices into a new local data dir
# official voices can be found here: https://huggingface.co/rhasspy/piper-voices/tree/main
mkdir -p ~/.cache/piper-tts
cd ~/.cache/piper-tts

python3 -m piper.download_voices en_US-amy-medium
piper -m en_US-amy-medium --data-dir ~/.cache/piper-tts --cuda -- This is a test of the Piper TTS-Stimme "Amy".

python3 -m piper.download_voices de_DE-thorsten-high
piper -m de_DE-thorsten-high --data-dir ~/.cache/piper-tts --cuda -- Das ist ein Test der Piper TTS-Stimme "Thorsten".
```

- consider tool or custom script
- read:
  - selected text (e.g. in terminal window / shell, editor, browser)
  - from cursor location
  - entire document
  - file (e.g. by filename in clipboard, selected file or file name in in editor, nautilus, doublecmd, terminal window / shell)
- tool or sway keyboard shortcuts
  - play any of the above read modes (auto detect would be nice if possible, otherwise one per mode in case there are multiple, at least selected test should be supported)
  - stop playback
  - if possible forward/rewind (e.g. by word, paragraph, or similar)
  - increase/decrease/reset playback speed (+/- 0.25 increments seem reasonable). default should be to remember the last used speed, and fallback should be 1.0 for starters but that may change (could also be voice specific, e.g. `"length_scale": 1` in voice's json)
