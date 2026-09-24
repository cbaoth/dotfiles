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
- [ ] [S] Consider p10k *instant prompt*: run `p10k configure` to generate
  `~/.p10k.zsh`, then add the instant-prompt preamble at the top of `.zshrc`
  (biggest perceived-startup win on slow machines).
- [ ] [S] Clean up leftover zplug state once the migration is confirmed good:
  `rm -rf ~/.zplug ~/.zplug-skip-install-prompt ~/.zplug-force-install`.
- [ ] [S] Re-evaluate `zsh-expand` config vars (`ZPWR_EXPAND*`, `ZPWR_CORRECT`,
  `ZPWR_EXPAND_BLACKLIST`) and the dropped `magic-space` binding after living
  with the new space-key behavior.
- [ ] [S] Audit the OMZ plugin list — several were loaded but rarely used; prune
  what you don't need to further cut startup cost.

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

- improve contrasts in zsh prompt (p10k) and maybe shell in general. for example the default (non-home) path segment shows cyan background and silver text which is barely readable.
  - consider potentially existing color themes, maybe there are better ones (used this one for ages with p9k and now p10k)
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
- **Software outside package managers** (installers with their own updater,
  static binaries, tools like `tailscale update`, `uv`, Claude Code, ...): no
  overview, no reminders.
- There is no regular habit of checking for updates. In practice updates happen
  only when a tool nags or when something breaks or is missing.
- Existing helpers: the `pk*` shell functions/aliases (e.g. `pku` updates apt,
  snap and flatpak in one go). They only run when invoked by hand.

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
