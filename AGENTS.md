# Agent Instructions — cbaoth/dotfiles

Personal dotfiles: zsh shell configuration, standalone scripts, and system
configs, deployed into `$HOME` via symlinks.

## Repository Layout

| Path                | Contents                                                            |
| ------------------- | ------------------------------------------------------------------- |
| `bin/`              | Standalone executable scripts (mostly Bash, no file extension)      |
| `lib/`              | Shared shell libraries (sourced; `lib/commons.sh`, `cl::` namespace) |
| `dotfiles/`         | Dotfiles mirrored into `$HOME` (e.g. `dotfiles/.zshrc` → `~/.zshrc`) |
| `dotfiles/.zsh.d/`  | Zsh config modules (`*.zsh`, sourced)                               |
| `system-scripts/`   | Scripts/units deployed outside `$HOME` (see section below)          |
| `setup/`            | Idempotent system setup modules (`bin/system-setup`; see below)     |
| `tools/`            | Repo tooling, notably the linking system (`tools/link.sh`)          |
| `docs/`             | Human documentation and system notes (see below)                    |

## Critical Workflow: Dotfiles Linking

Files only take effect through symlinks (`dotfiles/` → `$HOME/`, flat sync of
`bin/` → `~/bin` and `lib/` → `~/lib`, with stale-link cleanup).

**After creating, renaming, moving, or deleting files in `bin/`, `lib/`, or
`dotfiles/`, run the linking script:**

```bash
dotfiles-link              # apply (shell function; fallback: ./tools/link.sh)
dotfiles-link --dry-run    # preview changes
dotfiles-link -vv          # verbose/debug output
```

- New file missing in `$HOME`, or changes don't take effect? Verify the
  symlink (`ls -l ~/bin/<script>`), then run `dotfiles-link`.
- Never link or copy files manually; `dotfiles-link` is idempotent and also
  cleans up orphaned links.
- Conflicting files are backed up automatically to
  `~/.local/state/dotfiles-link/backups/` (last 10 runs kept).
- Configuration: `tools/link-config.conf`; excludes: `tools/.linkignore`.
  Architecture and troubleshooting: `docs/linking-system.md`.

## Style Guides (path-scoped, single source of truth)

Coding conventions live in `.github/instructions/*.instructions.md` and are
loaded automatically per file type — by GitHub Copilot via the `applyTo`
frontmatter, and by Claude Code via the `paths` frontmatter. They are also
deployed machine-wide (all repos) via `dotfiles-link`: `~/.claude/rules/` for
Claude Code and VS Code Copilot, `~/.copilot/.github/instructions/` (with
`COPILOT_CUSTOM_INSTRUCTIONS_DIRS` set in `.common_env`) for Copilot CLI:

- `cb-shell-script.instructions.md` — Bash/Zsh/sh scripts and shell rc files.
  Consult it before writing a new shell script if it is not already loaded.
- `cb-python.instructions.md` — Python (uv, Ruff, pyright, pytest)
- `cb-commit-messages.instructions.md` — commit conventions (always loaded)

The extended human-readable shell guide is `docs/shell-style-guide.md` —
reference documentation only; for agents the instruction files above are
authoritative. Setup details: `docs/agent-instructions.adoc`.

### Slash Commands (repo-level, shared)

The same single-source-plus-symlink pattern as the instruction files, applied to
slash commands:

| File | Consumer |
| ---- | -------- |
| `.github/prompts/cb-note.prompt.md` | **Source of truth.** GitHub Copilot Chat → `/note` |
| `.claude/commands/note.md` → symlink to it | Claude Code → `/note` |

Keep shared command files free of tool-specific placeholders (`$ARGUMENTS` for
Claude, `${input:...}` for Copilot) — both tools already see whatever the user
typed after the command, so plain prose works in both.

Note: Copilot **CLI** does not read `.github/prompts/` yet
([copilot-cli#618](https://github.com/github/copilot-cli/issues/618)); this
currently reaches Copilot in VS Code only.

These are **repo-level on purpose.** `/note` is saturated with knowledge specific
to this repo (the `docs/` buckets, `setup/modules/`, the public-repo sanitization
rules) and would be meaningless in another project.

## System Scripts (`system-scripts/`)

- Single standalone scripts live directly under `system-scripts/`
  (e.g. `system-scripts/backup`).
- Multi-file scripts (daemon + unit file, config, or dedicated README) go in a
  named subdirectory; always include a `README.adoc` there.

## System Setup (`setup/`)

Idempotent modules for what deploying this repo into `$HOME` does *not* cover:
apt packages, locales, flatpak apps, docker, fonts. The counterpart to
`dotfiles-link`, not a replacement.

```bash
system-setup --list                      # modules and what each does
system-setup --dry-run --profile desktop # print changes; change nothing
system-setup --profile auto              # detect desktop/server/wsl
system-setup 20-flatpak                  # one module
```

**The one rule: a module must be safe to re-run, and a re-run must report zero
changes.** Use the `st::*` helpers from `setup/lib/setup-lib.sh` (they handle
dry-run and the change counters); call `st::noop` when the desired state is
already in place so the counter stays honest. Details: `setup/README.md`.

Package sets are **data**, not code — `setup/packages/*.list`. Adding a tool
means adding a line to a list, not editing bash.

Modules must not depend on `~/lib/commons.sh`: `system-setup` runs on fresh
machines, before `dotfiles-link` has created `~/lib/`.

## Notes & System Documentation

`docs/` holds two different things. **Repo meta** (`linking-system.md`,
`shell-style-guide.md`, `TODO.md`) stays at the root. **System notes** — knowledge
about the *machines* — go in one of three buckets:

| Bucket | Contents |
| ------ | -------- |
| `docs/setup/` | How a machine got the way it is. Steady state, not the journey. Links to the module that automates it. |
| `docs/troubleshooting/` | Problem journals. **Append-only; never becomes code.** The dead ends are the content. |
| `docs/reference/` | Cheatsheets with no machine state attached. |

Every bucket note carries YAML frontmatter (`title`, `hosts`, `status`, `tags`,
`updated`, optional `revisit` / `automated_by`). Schema and rationale:
`docs/README.md`.

**The rule when working on this repo:**

1. Fix a system problem, or set something up → write or update the note.
2. If the fix is idempotent and repeatable → **also** extract a `setup/` module,
   and cross-link both ways (`automated_by:` in the note, a `MODULE_DOC` in the
   module). The note says *why*, the module says *how*; neither is much use alone.
3. If it should stay manual (anything editing `sudoers`, `pam.d`, `fstab`) — say
   so explicitly in the note, so the reader is not left wondering whether a
   module is missing.

The `/note` slash command automates this workflow — see *Slash Commands* above.

**Verify against the machine, not the old notes.** The legacy Obsidian notes are
not a spec; several were simply wrong (they claimed KeePassXC had to come from
apt — it is in fact the flatpak, and the flatpak is the *better* choice). Check
`dpkg -l` / `flatpak list` / `apt-cache policy` before encoding anything as a
rule. Watch for **virtual apt packages** (`exiftool`, `p7zip-full`): they install
fine but `dpkg-query` never reports them installed, which silently breaks the
re-run contract. Use the real package name — `docs/reference/package-managers.md`.

### This repo is PUBLIC — sanitize

Never commit to this repo: WiFi SSIDs (they geolocate the household),
disk/partition UUIDs, MAC addresses, swap offsets, credentials, keys. Use
placeholders (`<SSID>`, `UUID=<C_UUID>`) and keep real values in the gitignored
`_local/`.

Anything genuinely private — vserver internals, health, work, personal, gaming —
belongs in the **separate private notes repo at `~/notes`**, not here. When in
doubt, it goes there. Migration status and remaining hazards:
`docs/setup/MIGRATION.md`.

## Documentation

- `README.md` holds the high-level overview and links into `docs/`; `docs/TODO.md`
  tracks tasks and future improvements. Keep both up to date.
- Create new files in `docs/` for extensive changes or complex features.
- Prefer Asciidoc for new *repo* documentation; use spaces, never tabs.
  System notes in the three buckets are Markdown (they are also read in Obsidian
  and by agents).

## Environment (interactive shell)

Agents run in zsh with `setopt EXTENDED_GLOB` and `setopt INTERACTIVECOMMENTS`
enabled.
