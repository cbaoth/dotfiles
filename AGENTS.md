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
| `tools/`            | Repo tooling, notably the linking system (`tools/link.sh`)          |
| `docs/`             | Human documentation                                                 |

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

## System Scripts (`system-scripts/`)

- Single standalone scripts live directly under `system-scripts/`
  (e.g. `system-scripts/backup`).
- Multi-file scripts (daemon + unit file, config, or dedicated README) go in a
  named subdirectory; always include a `README.adoc` there.

## Documentation

- `README.md` holds the high-level overview and links into `docs/`; `TODO.md`
  tracks tasks and future improvements. Keep both up to date.
- Create new files in `docs/` for extensive changes or complex features.
- Prefer Asciidoc for new documentation; use spaces, never tabs.

## Environment (interactive shell)

Agents run in zsh with `setopt EXTENDED_GLOB` and `setopt INTERACTIVECOMMENTS`
enabled.
