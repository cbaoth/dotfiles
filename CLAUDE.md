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

```bash
#!/usr/bin/env bash
# ~/bin/script-name: Brief description
# code: language=bash insertSpaces=true tabSize=2
# keywords: bash shell relevant-keywords
# author: Andreas Weyer
```

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
