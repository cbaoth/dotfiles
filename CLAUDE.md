# Shell Script Style Guide (Summary)

Full guide: @docs/shell-style-guide.adoc

Based on the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) with project-specific additions.

## Shells

- **Zsh**: interactive shell, `.zsh.d/` config files
- **Bash**: standalone scripts (`bin/`, `lib/`)
- `lib/commons.sh` must work in both Bash and Zsh (use `typeset` instead of `declare`)

## Shebang

```bash
#!/usr/bin/env bash   # or zsh
```

Never `#!/bin/bash` or `#!/bin/env bash`. Libraries have no shebang.

## File Header

For executable scripts (with shebang):

```bash
#!/usr/bin/env bash
# -*- mode: sh; sh-shell: (bash|zsh|sh); indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=(bash|zsh|sh):et:ts=2:sts=2:sw=2
# code: language=(bash|zsh|sh) insertSpaces=true tabSize=2
# shellcheck shell=(bash|sh)
#
# Brief description of what the script does.
```

For sourced files and shell config files (no shebang):

```zsh
# -*- mode: sh; sh-shell: (bash|zsh|sh); indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=(bash|zsh|sh):et:ts=2:sts=2:sw=2
# code: language=(bash|zsh|sh) insertSpaces=true tabSize=2
# shellcheck shell=(bash|sh) disable=SC2148
#
# ~/.zshrc: executed by zsh(1)
```

* **Emacs** modeline `# -*- `: Always use `mode: sh` and set `ft=(bash|zsh|sh)` to the script specific shell (if any, fallback `bash).
* **VIM** modeline `# vim:`: Set `language=(bash|zsh|sh)` to the script specific shell (if any, fallback `bash).
* **Spellcheck** modeline `# spellcheck `: Set `shell=(bash|sh)` to either `bash` (fallback, no support for `zsh`), or `sh` if specifically required.
** For sourced/rc files (no shebang) set spellcheck `disable=SC2148` (prevents "no shebang" lint error).
* **Description:** a concise, single line summary of the script's purpose/usage/functionality. For sourced/rc files where location is semantically important lead with the canonical path.
* **Spacing:** empty line between header block and following script implementation.

## Script Structure

shebang -> header -> script path constants -> source libs -> set options/traps -> constants -> functions -> `main()` -> `main "$@"`

## Error Handling

`set -euo pipefail` is a **per-script decision** (not mandatory). Document the choice. Use ERR/SIGINT/SIGTERM traps for error reporting and cleanup. Do NOT use `set -e` in interactive shell functions (`.zsh.d/`).

## Naming

| What               | Convention                       | Example                    |
| ------------------- | --------------------------------- | --------------------------- |
| Functions           | `lowercase_underscores`           | `parse_args()`             |
| Library functions   | `namespace::name`                 | `cl::p_err()`              |
| Local variables     | `lowercase_underscores` + `local` | `local -r config_file="x"` |
| Constants/globals   | `UPPERCASE_UNDERSCORES` + `declare -r` | `declare -r MAX_RETRIES=5` |
| Library constants   | `NAMESPACE_NAME`                  | `CL_SCRIPT_PATH`           |

Underscore prefix (`_helper`) is acceptable in sourced files to distinguish internal helpers from user-facing functions, but not required in standalone scripts.

Avoid shadowing env vars: never use `PATH`, `PWD`, `HOME`, `USER`, `CMD`, `LOG`, etc. as local names.

## Variable Declarations

- `local -r` / `declare -r` for readonly
- `local -i` / `declare -i` for integers
- `local -a` / `declare -a` for arrays
- `local -A` / `declare -A` for associative arrays
- Separate declaration from assignment for command substitution: `local result; result=$(cmd)`

## Formatting

- **2 spaces** indentation, no tabs
- **120-char** soft limit for code; **78-char** for folding/decorative lines
- Brace-delimit variables: `"${var}"` (except `$1`, `$@`, `$?`)
- Always double-quote variable expansions
- `; then` / `; do` on same line as `if` / `for` / `while`
- Use `name() {` without `function` keyword

## Section Folding

```bash
# {{{ = SECTION NAME =========================================================
# ... content ...
# }}} = SECTION NAME =========================================================

# {{{ - Sub Section ----------------------------------------------------------
# ... content ...
# }}} - Sub Section ----------------------------------------------------------
```

Level 1 uses `=`, level 2 uses `-`. Fill to column 78. Closing line repeats section name.

## Features

- Prefer `[[ ... ]]` over `[ ... ]`
- Prefer `$(cmd)` over backticks
- Prefer `(( ... ))` for arithmetic, never `let` or `expr`
- Prefer parameter expansion over external commands
- Avoid `eval`
- Use `"$@"` not `$*`
- Use process substitution (`< <(cmd)`) instead of piping to `while`

## commons.sh Usage

```bash
for f in {"${SCRIPT_PATH}"/,"${SCRIPT_PATH}"/lib/,"${HOME}"/lib/}commons.sh; do
  if [[ -f "$f" ]]; then source "$f"; break; fi
done
if ! command -v "cl::cmd_p" > /dev/null 2>&1; then
  printf "commons lib not found, exiting ..\n" >&2; exit 1
fi
```

Namespace: functions `cl::name`, constants `CL_NAME`.

## Argument Parsing

`while` / `case` / `shift` pattern with `usage()` heredoc and `--` separator.

## Logging

- Errors/warnings to stderr (`>&2`)
- With commons.sh: `cl::p_err`, `cl::p_war`, `cl::p_msg`, `cl::p_dbg`
- Without: use `p_err()`, `p_war()`, `p_msg()`, `p_nfo()`, `p_dbg()` helpers with raw ANSI codes
  (or `log_error()`, `log_warn()`, `log_info()` for scripts with structured logging)

## Linting

Use [ShellCheck](https://www.shellcheck.net/) for static analysis.

## Dotfiles Linking & Deployment

This repository uses symlink-based configuration management. **After any changes to files in `bin/`, `lib/`, or `dotfiles/`, you must run the linking script.**

### Understanding the System

Two-part linking approach:

1. **Nested dotfiles** (`dotfiles/` → `$HOME/`): Preserves directory structure
   - Example: `dotfiles/.zshrc` → `~/.zshrc`
   - Example: `dotfiles/.config/sway/config` → `~/.config/sway/config`

2. **Flat directory sync** (`bin/` → `$HOME/bin`, `lib/` → `$HOME/lib`): Files only, stale symlink cleanup
   - Example: `bin/my-script` → `~/bin/my-script`
   - Automatically removes broken symlinks when source files are deleted

### When to Run

**Always run after:**
- Creating new scripts in `bin/` or executable files in `lib/`
- Creating/modifying dotfiles in `dotfiles/`
- Renaming, moving, or deleting files in above directories
- Fresh checkout or after `git pull`

### How to Run

**User/testing (shell-agnostic, works in both bash and zsh):**
```bash
dotfiles-link              # Run linking (function in .aliases, includes command cache refresh)
dotfiles-link --dry-run    # Preview changes before applying
dotfiles-link -vv          # Verbose output (debug)
```

**Direct script invocation (if function not available):**
```bash
./tools/link.sh --help     # See all options
```

**Configuration:** Synced directories are defined in `tools/link-config.conf`; patterns to exclude are in `tools/.linkignore`.

### Safety & Backups

- Conflicting files are automatically backed up to `~/.local/state/dotfiles-link/backups/run-TIMESTAMP/`
- Last 10 backup directories are kept; older ones auto-deleted
- Symlinks already pointing to the correct target are skipped (idempotent)
- External/custom symlinks in `$HOME/bin` and `$HOME/lib` are preserved

### Common Issues

**File doesn't appear in `$HOME` after creation:**
→ Run `dotfiles-link` after creating the file

**Testing new script/config but changes don't take effect:**
→ Verify the symlink exists: `ls -l ~/bin/script` or `ls -l ~/.zshrc`
→ If not linked, run `dotfiles-link`

**I manually copied/linked a file for testing:**
→ Clean up by running `dotfiles-link` (it handles orphaned links)
→ Never rely on manual linking; always use the script for consistency

**See also:** `docs/linking-system.adoc` for detailed architecture and troubleshooting.

## AI Agent Mode

When working in interactive shell you can expect the following to be setup for you:

- Default shell is `zsh` with:
  - `setopt EXTENDED_GLOB`
  - `setopt INTERACTIVECOMMENTS`

## Documentation

- Use `README.md` for high-level overview and link to detailed docs in `@docs/`. Use `TODO.md` for tracking tasks and future improvements. Keep both files up to date with the project's current state and plans.
  - Create new documentation files in `@docs/` whenever it seems appropriate; especially when more extensive changes are planned/made, or complex features are added that require detailed explanation.
- Use `@docs/shell-style-guide.adoc` for the full style guide, and this `CLAUDE.md` for a concise summary.

### Formatting and Style Guidelines

- Use [Asciidoc](https://asciidoctor.org/docs/asciidoc-syntax-quick-reference/) for documentation.
- Avoid the use of tabs, use spaces for indentation.
