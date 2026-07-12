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
