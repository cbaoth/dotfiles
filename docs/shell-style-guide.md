# Shell Script Style Guide

## Introduction

This document defines the shell scripting conventions for the
[cbaoth/dotfiles](https://github.com/cbaoth/dotfiles) repository. It covers
Bash and Zsh scripts in a single guide, with clearly marked sections where
shell-specific behavior differs.

The guide builds on top of the
[Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
([GitHub source](https://github.com/google/styleguide/blob/gh-pages/shellguide.md)).
Readers should be familiar with it; this document focuses on **additions,
deviations, and project-specific conventions** rather than repeating every rule
verbatim.

### Additional References

- [Oh My Zsh Code Style Guide](https://github.com/ohmyzsh/ohmyzsh/wiki/Code-Style-Guide)
  ([GitHub source](https://github.com/ohmyzsh/wiki/blob/main/Code-Style-Guide.md))
  — Zsh-specific conventions
- [YSAP Shell Style Guide](https://style.ysap.sh) — opinionated alternative
  reference (some recommendations differ from this guide)
- [TLDP Bash Programming Intro](https://tldp.org/HOWTO/Bash-Prog-Intro-HOWTO.html)
  — introductory reference
- [ShellCheck Wiki](https://www.shellcheck.net/wiki/) — common pitfalls and fixes

### Scope

This guide applies to all shell scripts in the repository:

| Path | Description |
|---|---|
| `bin/` | Standalone executable scripts (primarily Bash) |
| `lib/` | Shared libraries (sourced, not executed directly) |
| `.zsh.d/` | Zsh shell configuration (aliases, functions, host-specific) |
| `Useful-Scripts/` | Miscellaneous utility scripts (to be integrated, from <https://github.com/cbaoth/Useful-Scripts>) |


## Which Shell to Use

**Zsh** is the primary interactive shell. All files under `.zsh.d/` are
Zsh-specific.

**Bash** is used for standalone scripts (`bin/`, `lib/`) to ensure portability
across systems where Zsh may not be installed.

**`lib/commons.sh`** must remain compatible with **both Bash and Zsh**, since
it is sourced from scripts written in either shell.

**POSIX `sh`** should only be used when absolutely required (e.g., system
scripts, environments where neither Bash nor Zsh is available).


## File Organization

### Shebang

Always use `env` for portability:

```bash
#!/usr/bin/env bash
#!/usr/bin/env zsh
```

Never use:

- `#!/bin/bash` or `#!/bin/zsh` (not portable)
- `#!/bin/env bash` (non-standard path)

Libraries (`.sh` files intended to be sourced) do **not** have a shebang.

### File Extensions

| Type | Convention |
|---|---|
| Executables | No extension (per Google convention), placed in `bin/` |
| Libraries | `.sh` extension (e.g., `lib/commons.sh`) |
| Zsh config files | `.zsh` extension (e.g., `.zsh.d/aliases.zsh`) |

### File Header

Header layout differs between executable scripts and sourced/rc files.

For executable scripts (with shebang):

```bash
#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash
#
# Brief description of what the script does.
```

For sourced files and shell config files (no shebang):

```zsh
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# ~/.zshrc: executed by zsh(1)
```

- **Shebang:**
  - Files named `*.zsh` use `#!/usr/bin/env zsh` (there may be other cases where `zsh` is to be used).
  - For compatibility reasons `#!/usr/bin/env sh` may be used in rare cases.
  - Otherwise always use `#!/usr/bin/env bash`.
- **Modelines:** Emacs, Vim, and VSCode (in that order for editor compatibility).
  - **Emacs:** Always `# -*- mode: sh; sh-shell: $SHELL; indent-tabs-mode: nil; tab-width: 2 -*-` where `$SHELL` is one of `bash`, `zsh`, or `sh`
  - **VIM:** Always `# vim: ft=$SHELL:et:ts=2:sts=2:sw=2`, same `$SHELL` value as the above
  - **VS Code:** Always `# code: language=bash insertSpaces=true tabSize=2`, same `$SHELL` value as the above
  - **ShellCheck:** Always `# shellcheck shell=$SHELL` for singlefile/executable files (with shebang), and `# shellcheck shell=$SHELL disable=SC2148` for sourced/rc files to prevent "missing shebang" lint error. In case of shellcheck, the `$SHELL` must never be `zsh` (not supported, use `bash` instead).
- **Description:** a concise, single line summary of the script's purpose and usage. For sourced/rc files where location is semantically important (for example `~/.zshrc`), include the canonical path.
- **Spacing:** Leave one empty line between the header block and the script implementation (incl. additional documentation).


### Editor Modelines

The header includes three editor metadata lines in this order:

1. Emacs modeline
2. Vim modeline
3. VS Code modeline (`# code: ...`)

Use matching values for tabs/spaces and indentation width across all modelines.

For files with a shebang, keep the Emacs modeline on line 2.
For files without a shebang, keep the Emacs modeline on line 1.

In VS Code this repository currently relies on:
[vscode-modelines](https://marketplace.visualstudio.com/items?itemName=chrislajoie.vscode-modelines).

- It parses Vim `vim:`, Emacs `-*-`, and VS Code `code:` modelines, then merges them in that order
  (see [modelines.ts](https://github.com/ctlajoie/vscode-modelines/blob/master/src/modelines.ts)).
- Effective precedence is two-layered: first by parser order (Vim < Emacs < VS Code), then by scan order within each parser (top and bottom file regions, left-to-right). In conflicts, the later parsed value wins.
- Practical implication: if you keep modelines for multiple editors, keep overlapping keys (`tabSize`/`tab-width`/`tabstop`, `insertSpaces`/`indent-tabs-mode`/`expandtab`, `language`/`mode`/`filetype`) semantically aligned to avoid accidental overrides.
- Language values `sh`, `zsh`, `ksh`, `csh`, and `bash` are translated to VS Code `shellscript`, so shell-specific filetypes do not remain distinct in VS Code after modelines are applied.
- Use shell-specific values in Vim/VS Code modelines anyway (`zsh` for zsh files, `bash` for bash files): this keeps intent explicit for other editors/tools and remains future-proof if translation behavior changes.

ShellCheck should also be provided with explicit shell information, specifically the shell (`bash` or `sh`, since `zsh` is not supported) and `disable=SC2148` to prevent "missing shebang" errors for sourced/rc files without a shebang.

Modelines are editor metadata only. They must not change script behavior.

If modelines are changed, keep them semantically aligned (indent width,
tabs/spaces, filetype/language).

### Script Structure Order

Scripts should follow this structure:

```bash
#!/usr/bin/env bash
# Modelines
#
# File description

# 1. Script path / file constants
declare -r SCRIPT_PATH="$(cd "$(dirname "$0")"; pwd -P)"
declare -r SCRIPT_FILE="$(basename "$0")"

# 2. Source libraries (if applicable)
# ... (see Library Usage section)

# 3. Set options and traps
set -euo pipefail  # if appropriate (see Error Handling)

# 4. Constants
declare -r MY_CONSTANT="value"

# 5. Function definitions (alphabetical or logical grouping)
usage() { ... }
parse_args() { ... }
do_work() { ... }

# 6. Main function (last function defined)
main() {
  parse_args "$@"
  do_work
}

# 7. Entry point (last line)
main "$@"
```


## Error Handling & Safety

### `set` Options

Whether to use `set -euo pipefail` is a **per-script decision**. Document the
choice in a comment.

#### When to use `set -euo pipefail`

Recommended for standalone scripts that should **fail fast** on unexpected
errors:

```bash
# -e: exit on error
# -u: treat unset variables as an error
# -o pipefail: return exit code of the last failed command in a pipeline
set -euo pipefail
```

#### When NOT to use it

- **Interactive shell functions** (`.zsh.d/`) — an error in one function
  should not terminate the shell session
- Scripts with **intentional non-zero exits** from subcommands (e.g., using
  `grep -q` which returns 1 on no match)
- Scripts that need **fine-grained error control** — `set -e` can mask
  intentional failures and has subtle scoping rules (see
  [BashFAQ #105](https://mywiki.wooledge.org/BashFAQ/105))

When `set -e` is active and a command is expected to fail, use explicit
guards:

```bash
some_command || true            # Ignore failure
if ! some_command; then ... fi  # Handle failure explicitly
```

#### Additional options

`set -o errtrace` (`-E`) with an `ERR` trap provides detailed error reporting:

```bash
set -o errtrace
trap '_rc=$?; \
      printf "ERROR(%s) in %s:%s\n  -> %s\n  -> %s\n" "${_rc}" \
             "${0:-N/A}" "${LINENO:-N/A}" "${FUNCNAME[@]:-N/A}" \
             "${BASH_COMMAND:-N/A}"; \
      exit $_rc' ERR
```

`set -o xtrace` (`-x`) for debug output, typically guarded:

```bash
(( ${DEBUG_LVL:-0} >= 2 )) && set -o xtrace
```

### Traps

Always set up traps for clean error reporting and interrupt handling:

```bash
trap '_rc=$?; \
      printf "ERROR(%s) in %s:%s\n  -> %s\n  -> %s\n" "${_rc}" \
             "${0:-N/A}" "${LINENO:-N/A}" "${FUNCNAME[@]:-N/A}" \
             "${BASH_COMMAND:-N/A}"; \
      exit $_rc' ERR
trap 'printf "\nINTERRUPT\n"; exit 1' SIGINT SIGTERM
```

If the script creates temporary files or needs cleanup, use an `EXIT` trap:

```bash
cleanup() {
  rm -f "${tmp_file:-}"
}
trap cleanup EXIT
```

### IFS

Setting `IFS` to exclude spaces can prevent subtle word-splitting bugs when
handling filenames:

```bash
IFS=$'\t\n\0'
```

This is optional and should be used when the script processes filenames or
other data that may contain spaces. Document when and why it is set.


## Naming Conventions

### Functions

Use `lowercase_with_underscores` (per Google convention):

```bash
parse_args() { ... }
process_file() { ... }
```

**Library functions** use a namespace prefix with `::` separator:

```bash
cl::p_err() { ... }    # commons lib: print error
cl::cmd_p() { ... }    # commons lib: command predicate
```

**Underscore prefix for "private" identifiers**: Not required as a general
convention, but acceptable in **sourced files** (`.zsh.d/`, `lib/`) to
distinguish internal helper functions from user-facing ones. This is a
pragmatic approach for files where functions enter the user's shell namespace:

```bash
# In .zsh.d/functions.zsh:
_helper_function() { ... }  # Internal, not intended for direct use
public_function() { ... }   # User-facing, callable from the shell
```

In standalone scripts this distinction is unnecessary since functions do not
leak into the caller's namespace.

### Variables

**Local variables**: `lowercase_with_underscores`, declared with `local`:

```bash
local -r config_file="/etc/myapp.conf"
local -i retry_count=3
```

**Constants and global variables**: `UPPERCASE_WITH_UNDERSCORES`:

```bash
declare -r MAX_RETRIES=5
declare -ra REQUIRED_COMMANDS=(rsync parallel)
```

**Library constants**: namespace prefix:

```bash
declare -r CL_SCRIPT_PATH="..."
declare -r CL_TIMESTAMP_FORMAT="%Y-%m-%dT%H:%M:%S%z"
```

### Avoiding Name Conflicts

Never use common environment variable names for local variables without a
distinguishing prefix. Names to avoid in particular:

`PATH`, `PWD`, `HOME`, `USER`, `SHELL`, `TERM`, `LANG`, `IFS`, `CMD`, `LOG`,
`HOSTNAME`, `EDITOR`, `DISPLAY`, `UID`, `GROUPS`

When in doubt, use a descriptive prefix or more specific name (e.g.,
`log_file` instead of `LOG`, `target_path` instead of `PATH`).


## Variable Declarations

Use `declare` / `local` with appropriate type flags:

```bash
local -r name="value"        # readonly
local -i count=0             # integer
local -a items=()            # indexed array
local -A map=()              # associative array
declare -r GLOBAL_CONST="x"  # global readonly constant
```

Prefer `declare -r` / `local -r` over the `readonly` builtin for consistency.

**Separate declaration from assignment** when capturing command output (prevents
masking the command's exit code):

```bash
# Good:
local result
result=$(some_command)

# Bad (exit code of some_command is lost):
local result=$(some_command)
```

**Bash/Zsh compatibility**: In code that must work in both shells (notably
`lib/commons.sh`), use `typeset` instead of `declare`, as its behavior is more
consistent across shells.


## Formatting

### Indentation

**2 spaces**, no tabs. This is declared in the file metadata:

```
# code: language=bash insertSpaces=true tabSize=2
```

### Line Length

- **Code lines**: 120-character soft limit. Prefer breaking long lines for
  readability, but do not contort logic to fit an arbitrary limit.
- **Decorative / folding lines**: 78 characters total (fill character `=` or
  `-` padded to that length).
- **URLs and file paths**: may exceed either limit; isolate on their own line
  when possible.

### Variable Expansion

Brace-delimit variables for clarity:

```bash
# Preferred:
echo "${my_var}"
echo "${array[@]}"

# Acceptable for positional parameters and special variables:
echo "$1" "$@" "$?" "$#"
```

Always double-quote variable expansions unless intentional word splitting is
needed (which should be rare and documented).

### Control Flow

Place `; then` and `; do` on the same line as the keyword:

```bash
if [[ -f "${file}" ]]; then
  process "${file}"
fi

for item in "${items[@]}"; do
  echo "${item}"
done

while read -r line; do
  echo "${line}"
done < "${input_file}"
```

### Section Folding

Use `{{{` / `}}}` markers for editor folding (compatible with
[VS Code explicit-folding](https://marketplace.visualstudio.com/items?itemName=zokugun.explicit-folding)
and [Emacs folding-mode](https://www.emacswiki.org/emacs/FoldingMode)):

**Level 1** (top-level sections) — fill with `=` to column 79:

```bash
# {{{ = SECTION NAME =========================================================

# ... section content ...

# }}} = SECTION NAME =========================================================
```

**Level 2** (sub-sections) — fill with `-` to column 79:

```bash
# {{{ - Sub Section ----------------------------------------------------------

# ... sub-section content ...

# }}} - Sub Section ----------------------------------------------------------
```

The closing line **repeats the section name** for readability. The total line
length (including `# {{{ = ` prefix and fill characters) is 78 characters.

#### Enabling Folding in Editors

For _VS Code explicit-folding_ add suggested default to `settings.json`:

```jsonc
"explicitFolding.rules": {
    "*": {
        "begin": "{{{",
        "end": "}}}"
    }
},
```

Alternatively more specific and only for shell scripts:

```jsonc
"[shellscript]": {
  "explicitFolding.rules": [
    {
      "begin": "# {{{",
      "end": "# }}}"
    }
  ]
}
```

For _Emacs fold-mode_, add the following to `.emacs`:

```lisp
;; folding-mode
(load "folding" 'nomessage 'noerror)
(folding-add-to-marks-list 'shell-script-mode "# {{{ " "# }}}" nil t)
(folding-mode-add-find-file-hook)
```


## Functions

Use `name() {` syntax without the `function` keyword (per Google convention):

```bash
# Good:
my_function() {
  ...
}

# Avoid:
function my_function {
  ...
}
```

### Function Documentation

Document non-trivial functions with a comment block. For library functions,
include all applicable fields:

```bash
# Brief description of what the function does.
#
# Globals:
#   SOME_GLOBAL  - read
#   OTHER_GLOBAL - modified
# Arguments:
#   $1 - description
#   $2 - description (optional, default: "foo")
# Outputs:
#   Writes result to stdout
# Returns:
#   0 on success, 1 on invalid input
my_function() {
  ...
}
```

For simple helper functions in standalone scripts, a one-line comment suffices.

### Function Organization

- Group all function definitions **before** `main`.
- Define `main()` as the **last function**.
- Call `main "$@"` as the **last line** of the script.

### `usage()` Function

Every script that accepts arguments should have a `usage()` function using a
heredoc:

```bash
usage() {
  cat <<EOF
Usage: ${SCRIPT_FILE} [OPTIONS] ARG...

Description of what the script does.

Options:
  -n, --dry-run    Print commands without executing
  -v, --verbose    Enable verbose output
  -h, --help       Show this help message and exit
EOF
}
```


## Features & Builtins

Follow the Google Shell Style Guide recommendations:

- Prefer `[[ ... ]]` over `[ ... ]` or `test`
- Prefer `$(command)` over backticks
- Prefer `(( ... ))` / `$(( ... ))` for arithmetic; never `let` or `expr`
- Prefer parameter expansion over external commands
  (e.g., `${var##*/}` over `basename "$var"`)
- Avoid `eval`
- Use arrays for command argument lists
- Use process substitution (`< <(command)`) instead of piping to `while`
- Use `"$@"` instead of `$*`


## Argument Parsing

Use a `while` / `case` / `shift` loop:

```bash
parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      -n|--dry-run) dry_run=true ;;
      -v|--verbose) verbose=true ;;
      -j|--jobs)
        shift
        jobs="$1"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        printf "Unknown option: %s\n" "$1" >&2
        usage >&2
        exit 1
        ;;
      *)
        break
        ;;
    esac
    shift
  done
}
```


## Library Usage (`commons.sh`)

### Standard Inclusion Pattern

```bash
# include commons lib
for f in {"${SCRIPT_PATH}"/,"${SCRIPT_PATH}"/lib/,"${HOME}"/lib/}commons.sh; do
  if [[ -f "$f" ]]; then
    source "$f"
    break
  fi
done
if ! command -v "cl::cmd_p" > /dev/null 2>&1; then
  printf "commons lib not found, exiting ..\n" >&2
  exit 1
fi
```

### When to Use commons.sh

- **Prefer commons.sh** for logging (`cl::p_err`, `cl::p_war`, `cl::p_msg`),
  text effects (`cl::fx`), predicates (`cl::is_int`, `cl::cmd_p`), and other
  utilities it provides — to reduce code duplication.
- **Standalone is OK** for simple scripts that only need basic functionality
  and benefit from having no external dependencies.
- **Never duplicate** commons.sh functionality in a script that already sources
  it.

### Namespace Convention

All `commons.sh` public identifiers use the `cl` namespace:

- Functions: `cl::function_name`
- Constants: `CL_CONSTANT_NAME`


## Zsh-Specific Conventions

This section applies to files under `.zsh.d/` and other Zsh-only code.

### File Conventions

- Files use `.zsh` extension
- No shebang (they are sourced, not executed directly)
- End sourced files with `return 0`

### Aliases vs. Functions

Both aliases and functions expose named commands in the interactive shell. Use
the right tool for each case:

**Use a function when:**

- The body spans multiple lines or requires control flow
- Arguments need to be accessed, validated, or forwarded selectively
- Local variables or a return code are needed

**Keep as an alias when:**

- It is a simple rename or command substitution (`alias vim='nvim'`)
- It prepends fixed flags to a command (`alias grep='grep --color=auto'`)
- It fixes a typo or abbreviation (`alias grpe=grep`)

**Must remain aliases — no function equivalent:**

- **Global aliases** (`alias -g @G='| grep'`) — expand anywhere in a command
  line, not only at the command position; functions cannot do this
- **Suffix aliases** (`alias -s pdf=zathura`) — file-type dispatch triggered
  by typing a filename; functions cannot do this
- **Trailing-space trick** (`alias sudo='sudo '`) — forces alias expansion of
  the following word; cannot be replicated with a function

Avoid converting working single-line aliases to functions purely for style
reasons. The multi-line / argument / logic threshold is the meaningful signal.

### Global Aliases

Zsh supports global aliases (expanded anywhere in a command line). Use
sparingly and with distinctive names to avoid accidental expansion:

```zsh
alias -g @G='| grep'
alias -g @L='| less'
alias -g @H='| head'
alias -g @T='| tail'
```

### Private Functions in Sourced Files

In `.zsh.d/` function files, use underscore prefix for helper functions that
should not be called directly by the user:

```zsh
# Internal helper -- not for direct use
_format_output() { ... }

# User-facing function
my_tool() {
  local result
  result=$(_format_output "$@")
  echo "${result}"
}
```

### Compatibility with Bash

When writing code that must work in both shells (primarily `lib/commons.sh`):

- Use `typeset` instead of `declare` for more consistent behavior
- Be aware of array indexing differences (Zsh starts at 1, Bash at 0)
- Test with both `bash` and `zsh` before committing


## Logging & Output

### Error Output

All error and warning messages go to **stderr** (`>&2`):

```bash
printf "ERROR: %s\n" "${message}" >&2
```

### With commons.sh

Use the provided logging functions:

```bash
cl::p_err "Something went wrong: ${details}"
cl::p_war "Proceeding without optional feature"
cl::p_msg "Processing file: ${file}"
cl::p_dbg 1 "Debug detail (level 1)"
```

### Without commons.sh

Define minimal helpers for consistent formatting. The standard template used
across most `bin/` scripts (comment out unused functions):

```bash
p_msg() { printf '%s\n' "$*"; }
#p_nfo() { printf '\033[32mINFO\033[0m %s\n' "$*"; }
#p_war() { printf '\033[33mWARNING\033[0m %s\n' "$*" >&2; }
p_err() { printf '\033[31mERROR\033[0m: %s\n' "$*" >&2; }
#p_dbg() { (( "${1:-0}" <= "${DEBUG_LVL:-0}" )) && printf '\033[36mDEBUG\033[0m: %s\n' "${*:2}" >&2 || true; }
```

For scripts with structured logging (timestamps, log levels, file output),
a `log_*` naming convention is also acceptable:

```bash
log_error() { printf "\033[31mERROR\033[0m: %s\n" "$*" >&2; }
log_warn()  { printf "\033[33mWARN\033[0m: %s\n" "$*" >&2; }
log_info()  { printf "%s\n" "$*"; }
```


## Linting & Static Analysis

### ShellCheck

[ShellCheck](https://www.shellcheck.net/)
([GitHub](https://github.com/koalaman/shellcheck)) is the recommended linting
tool. The Google Shell Style Guide also recommends it.

Run it against scripts to catch common bugs, quoting issues, and portability
problems:

```bash
shellcheck bin/my-script
shellcheck lib/commons.sh
```

A VS Code extension is available:
[ShellCheck for VS Code](https://marketplace.visualstudio.com/items?itemName=timonwong.shellcheck).

> **Note:** Deeper integration with CI pipelines, pre-commit hooks, and testing
> frameworks is tracked in `docs/TODO.md`.


## Related Files

This document is the full, human-readable style guide. The concise agent-facing
summary lives in `.github/instructions/cb-shell-script.instructions.md`
(loaded automatically by GitHub Copilot and, via `.claude/rules/`, by Claude
Code) — keep the two in sync when conventions change. See
`docs/agent-instructions.adoc` for how the AI instruction files are wired up.
