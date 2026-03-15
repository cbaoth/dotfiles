# Shell Script Coding Instructions

These instructions define the shell scripting conventions for the
[cbaoth/dotfiles](https://github.com/cbaoth/dotfiles) repository. Use them
when generating, editing, or reviewing shell scripts in this project.

The full style guide is at `docs/shell-style-guide.adoc`. These instructions are
based on the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
with project-specific additions and deviations.

## Project Context

This is a personal dotfiles repository containing:

- `bin/` -- standalone executable scripts (primarily Bash)
- `lib/` -- shared libraries, notably `commons.sh` (must work in both Bash and Zsh)
- `.zsh.d/` -- Zsh interactive shell configuration (aliases, functions, host-specific config)
- `Useful-Scripts/` -- miscellaneous utility scripts (being integrated, from https://github.com/cbaoth/Useful-Scripts)

Zsh is the primary interactive shell. Bash is used for standalone scripts to
ensure portability. `lib/commons.sh` provides shared utilities (logging,
predicates, text effects) using the `cl::` function namespace and `CL_` constant
prefix.

## Key Rules

### Shebang

```bash
#!/usr/bin/env bash   # or #!/usr/bin/env zsh
```

Never `#!/bin/bash`, `#!/bin/zsh`, or `#!/bin/env bash`. Libraries have no shebang.

### File Header

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

### Script Structure Order

1. Shebang + header comment
2. Script path constants (`SCRIPT_PATH`, `SCRIPT_FILE`)
3. Source libraries (if applicable)
4. `set` options and traps
5. Constants
6. Function definitions
7. `main()` function (defined last)
8. `main "$@"` (last line of the script)

### Error Handling

- `set -euo pipefail` is a **per-script decision**, not mandatory
- When used, document why and add `|| true` guards for expected failures
- Use ERR trap for detailed error reporting (with `set -o errtrace`)
- Always trap SIGINT/SIGTERM for clean interrupt handling
- Do NOT use `set -e` in interactive shell functions (`.zsh.d/`)

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Functions | `lowercase_underscores` | `parse_args()` |
| Library functions | `namespace::name` | `cl::p_err()` |
| Local variables | `lowercase_underscores` + `local` | `local -r config_file="x"` |
| Constants / globals | `UPPERCASE_UNDERSCORES` + `declare -r` | `declare -r MAX_RETRIES=5` |
| Library constants | `NAMESPACE_NAME` | `CL_SCRIPT_PATH` |

- Underscore prefix (`_helper`) is acceptable in sourced files (`.zsh.d/`, `lib/`) to mark internal helpers vs. user-facing functions
- Never shadow common env vars (`PATH`, `PWD`, `HOME`, `USER`, `CMD`, `LOG`, `SHELL`, `TERM`, `IFS`, `UID`)

### Variable Declarations

- Always use `local` inside functions
- Use type flags: `-r` (readonly), `-i` (integer), `-a` (array), `-A` (associative array)
- Prefer `declare -r` / `local -r` over `readonly` builtin
- **Separate declaration from assignment** for command substitution:

  ```bash
  local result
  result=$(some_command)    # exit code preserved
  ```

- In bash/zsh-compatible code (`lib/commons.sh`): use `typeset` instead of `declare`

### Formatting

- **2-space indentation**, no tabs
- **120-character** soft limit for code lines
- **78-character** limit for decorative/folding lines
- Brace-delimit variables: `"${var}"` (except `$1`, `$@`, `$?`, `$#`)
- Always double-quote variable expansions
- `; then` / `; do` on same line as `if` / `for` / `while`
- Function syntax: `name() {` (no `function` keyword)

### Section Folding

```bash
# {{{ = SECTION NAME =========================================================
# ... content ...
# }}} = SECTION NAME =========================================================

# {{{ - Sub Section ----------------------------------------------------------
# ... content ...
# }}} - Sub Section ----------------------------------------------------------
```

Level 1: `=` fill, Level 2: `-` fill. Both to column 78. Closing repeats name.

### Shell Features

- Prefer `[[ ... ]]` over `[ ... ]` or `test`
- Prefer `$(command)` over backticks
- Prefer `(( ... ))` / `$(( ... ))` for arithmetic; never `let` or `expr`
- Prefer parameter expansion over external commands (`${var##*/}` not `basename`)
- Avoid `eval`
- Use `"$@"` not `$*`
- Use process substitution (`< <(command)`) instead of piping to `while`

### commons.sh Library

Include pattern:

```bash
for f in {"${SCRIPT_PATH}"/,"${SCRIPT_PATH}"/lib/,"${HOME}"/lib/}commons.sh; do
  if [[ -f "$f" ]]; then source "$f"; break; fi
done
if ! command -v "cl::cmd_p" > /dev/null 2>&1; then
  printf "commons lib not found, exiting ..\n" >&2; exit 1
fi
```

- Functions: `cl::name` (e.g., `cl::p_err`, `cl::p_war`, `cl::cmd_p`, `cl::is_int`)
- Constants: `CL_NAME` (e.g., `CL_SCRIPT_PATH`, `CL_TIMESTAMP_FORMAT`)

### Argument Parsing

Use `while` / `case` / `shift` pattern with a `usage()` function (heredoc) and `--` option separator.

### Logging

- All errors/warnings to stderr (`>&2`)
- With commons.sh: `cl::p_err`, `cl::p_war`, `cl::p_msg`, `cl::p_dbg`
- Without commons.sh: define minimal `log_error()` / `log_warn()` / `log_info()` helpers

### Linting

Use [ShellCheck](https://www.shellcheck.net/) for static analysis.

### Zsh-Specific (`.zsh.d/`)

- `.zsh` extension, no shebang
- End sourced files with `return 0`
- Global aliases use distinctive prefixes (e.g., `@G`, `@L`)
- Underscore prefix for internal helper functions

### AI Agent Mode

When working in interactive shell you can expect the following to be setup for you:

- Default shell is `zsh` with:
  - `setopt EXTENDED_GLOB`
  - `setopt INTERACTIVECOMMENTS`
