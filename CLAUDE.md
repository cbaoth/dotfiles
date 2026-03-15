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
- Without: define `log_error()`, `log_warn()`, `log_info()` helpers

## Linting

Use [ShellCheck](https://www.shellcheck.net/) for static analysis.

## AI Agent Mode

When working in interactive shell you can expect the following to be setup for you:

- Default shell is `zsh` with:
  - `setopt EXTENDED_GLOB`
  - `setopt INTERACTIVECOMMENTS`
