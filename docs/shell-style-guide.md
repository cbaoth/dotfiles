<div id="header">

# Shell Script Style Guide

<span id="author">Andreas Weyer</span>  
<span id="email" class="monospaced">\<<cbaoth>\></span>  

<div id="toc">

<div id="toctitle">

Table of Contents

</div>

**JavaScript must be enabled in your browser to display the table of contents.**

</div>

</div>

<div id="content">

<div class="sect1">

## Introduction

<div class="sectionbody">

<div class="paragraph">

This document defines the shell scripting conventions for the [cbaoth/dotfiles](https://github.com/cbaoth/dotfiles) repository. It covers Bash and Zsh scripts in a single guide, with clearly marked sections where shell-specific behavior differs.

</div>

<div class="paragraph">

The guide builds on top of the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) ([GitHub source](https://github.com/google/styleguide/blob/gh-pages/shellguide.md)). Readers should be familiar with it; this document focuses on **additions, deviations, and project-specific conventions** rather than repeating every rule verbatim.

</div>

<div class="sect2">

### Additional References

<div class="ulist">

- [Oh My Zsh Code Style Guide](https://github.com/ohmyzsh/ohmyzsh/wiki/Code-Style-Guide) ([GitHub source](https://github.com/ohmyzsh/wiki/blob/main/Code-Style-Guide.md))  — Zsh-specific conventions

- [YSAP Shell Style Guide](https://style.ysap.sh) — opinionated alternative reference (some recommendations differ from this guide)

- [TLDP Bash Programming Intro](https://tldp.org/HOWTO/Bash-Prog-Intro-HOWTO.html)  — introductory reference

- [ShellCheck Wiki](https://www.shellcheck.net/wiki/) — common pitfalls and fixes

</div>

</div>

<div class="sect2">

### Scope

<div class="paragraph">

This guide applies to all shell scripts in the repository:

</div>

|  |  |
|----|----|
| <span class="monospaced">bin/</span> | Standalone executable scripts (primarily Bash) |
| <span class="monospaced">lib/</span> | Shared libraries (sourced, not executed directly) |
| <span class="monospaced">.zsh.d/</span> | Zsh shell configuration (aliases, functions, host-specific) |
| <span class="monospaced">Useful-Scripts/</span> | Miscellaneous utility scripts (to be integrated, from <https://github.com/cbaoth/Useful-Scripts>) |

</div>

</div>

</div>

<div class="sect1">

## Which Shell to Use

<div class="sectionbody">

<div class="paragraph">

**Zsh** is the primary interactive shell. All files under <span class="monospaced">.zsh.d/</span> are Zsh-specific.

</div>

<div class="paragraph">

**Bash** is used for standalone scripts (<span class="monospaced">bin/</span>, <span class="monospaced">lib/</span>) to ensure portability across systems where Zsh may not be installed.

</div>

<div class="paragraph">

**<span class="monospaced">lib/commons.sh</span>** must remain compatible with **both Bash and Zsh**, since it is sourced from scripts written in either shell.

</div>

<div class="paragraph">

**POSIX <span class="monospaced">sh</span>** should only be used when absolutely required (e.g., system scripts, environments where neither Bash nor Zsh is available).

</div>

</div>

</div>

<div class="sect1">

## File Organization

<div class="sectionbody">

<div class="sect2">

### Shebang

<div class="paragraph">

Always use <span class="monospaced">env</span> for portability:

</div>

<div class="listingblock">

<div class="content monospaced">

    #!/usr/bin/env bash
    #!/usr/bin/env zsh

</div>

</div>

<div class="paragraph">

Never use:

</div>

<div class="ulist">

- <span class="monospaced">\#!/bin/bash</span> or <span class="monospaced">\#!/bin/zsh</span> (not portable)

- <span class="monospaced">\#!/bin/env bash</span> (non-standard path)

</div>

<div class="paragraph">

Libraries (<span class="monospaced">.sh</span> files intended to be sourced) do **not** have a shebang.

</div>

</div>

<div class="sect2">

### File Extensions

|  |  |
|----|----|
| Executables | No extension (per Google convention), placed in <span class="monospaced">bin/</span> |
| Libraries | <span class="monospaced">.sh</span> extension (e.g., <span class="monospaced">lib/commons.sh</span>) |
| Zsh config files | <span class="monospaced">.zsh</span> extension (e.g., <span class="monospaced">.zsh.d/aliases.zsh</span>) |

</div>

<div class="sect2">

### File Header

<div class="paragraph">

Header layout differs between executable scripts and sourced/rc files.

</div>

<div class="paragraph">

For executable scripts (with shebang):

</div>

<div class="listingblock">

<div class="content monospaced">

    #!/usr/bin/env bash
    # -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
    # vim: ft=bash:et:ts=2:sts=2:sw=2
    # code: language=bash insertSpaces=true tabSize=2
    # shellcheck shell=bash
    #
    # Brief description of what the script does.

</div>

</div>

<div class="paragraph">

For sourced files and shell config files (no shebang):

</div>

<div class="listingblock">

<div class="content monospaced">

    # -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
    # vim: ft=bash:et:ts=2:sts=2:sw=2
    # code: language=bash insertSpaces=true tabSize=2
    # shellcheck shell=bash disable=SC2148
    #
    # ~/.zshrc: executed by zsh(1)

</div>

</div>

<div class="ulist">

- **Shebang:**

- Files named <span class="monospaced">\*.zsh</span> use <span class="monospaced">\#!/usr/bin/env zsh</span> (there may be other cases where <span class="monospaced">zsh</span> is to be used).

- For compatibility reasons <span class="monospaced">\#!/usr/bin/env sh</span> may be used in rare cases.

- Otherwise always use <span class="monospaced">\#!/usr/bin/env bash</span>.

- **Modelines:** Emacs, Vim, and VSCode (in that order for editor compatibility).

- **Emacs:** Always <span class="monospaced">\# -\*- mode: sh; sh-shell: \$SHELL; indent-tabs-mode: nil; tab-width: 2 -\*-</span> where <span class="monospaced">\$SHELL</span> is one of <span class="monospaced">bash</span>, <span class="monospaced">zsh</span>, or <span class="monospaced">sh</span>

- **VIM:** Always <span class="monospaced">\# vim: ft=\$SHELL:et:ts=2:sts=2:sw=2</span>, same <span class="monospaced">\$SHELL</span> value as the above

- **VS Code:** Always <span class="monospaced">\# code: language=bash insertSpaces=true tabSize=2</span>, same <span class="monospaced">\$SHELL</span> value as the above

- **ShellCheck:** Always <span class="monospaced">\# shellcheck shell=\$SHELL</span> for singlefile/executable files (with shebang), and <span class="monospaced">\# shellcheck shell=\$SHELL disable=SC2148</span> for sourced/rc files to prevent "missing shebang" lint error. In case of shellcheck, the \$SHELL must never be <span class="monospaced">zsh</span> (not supported, use <span class="monospaced">bash</span> instead).

- **Description:** a concise, single line summary of the script’s purpose and usage. For sourced/rc files where location is semantically important (for example <span class="monospaced">~/.zshrc</span>), include the canonical path.

- **Spacing:** Leave one empty line between the header block and the script implementation (incl. additional documentation).

</div>

</div>

<div class="sect2">

### Editor Modelines

<div class="paragraph">

The header includes three editor metadata lines in this order:

</div>

<div class="olist arabic">

1.  Emacs modeline

2.  Vim modeline

3.  VS Code modeline (<span class="monospaced">\# code: ...</span>)

</div>

<div class="paragraph">

Use matching values for tabs/spaces and indentation width across all modelines.

</div>

<div class="paragraph">

For files with a shebang, keep the Emacs modeline on line 2. For files without a shebang, keep the Emacs modeline on line 1.

</div>

<div class="paragraph">

In VS Code this repository currently relies on: [vscode-modelines](https://marketplace.visualstudio.com/items?itemName=chrislajoie.vscode-modelines).

</div>

<div class="ulist">

- It parses Vim <span class="monospaced">vim:</span>, Emacs <span class="monospaced">-\*-</span>, and VS Code <span class="monospaced">code:</span> modelines, then merges them in that order<span class="footnote">  
  \[<https://github.com/ctlajoie/vscode-modelines/blob/master/src/modelines.ts>\]  
  </span>.

- Effective precedence is two-layered: first by parser order (Vim \< Emacs \< VS Code), then by scan order within each parser (top and bottom file regions, left-to-right). In conflicts, the later parsed value wins.

- Practical implication: if you keep modelines for multiple editors, keep overlapping keys (<span class="monospaced">tabSize</span>/<span class="monospaced">tab-width</span>/<span class="monospaced">tabstop</span>, <span class="monospaced">insertSpaces</span>/<span class="monospaced">indent-tabs-mode</span>/<span class="monospaced">expandtab</span>, <span class="monospaced">language</span>/<span class="monospaced">mode</span>/<span class="monospaced">filetype</span>) semantically aligned to avoid accidental overrides.

- Language values <span class="monospaced">sh</span>, <span class="monospaced">zsh</span>, <span class="monospaced">ksh</span>, <span class="monospaced">csh</span>, and <span class="monospaced">bash</span> are translated to VS Code <span class="monospaced">shellscript</span>, so shell-specific filetypes do not remain distinct in VS Code after modelines are applied.

- Use shell-specific values in Vim/VS Code modelines anyway (<span class="monospaced">zsh</span> for zsh files, <span class="monospaced">bash</span> for bash files): this keeps intent explicit for other editors/tools and remains future-proof if translation behavior changes.

</div>

<div class="paragraph">

ShellCheck should also be provided with explicit shell information, specifically the shell (<span class="monospaced">bash</span> or <span class="monospaced">sh</span>, since <span class="monospaced">zsh</span> is not supported) and <span class="monospaced">disable=SC2148</span> to prevent "missing shebang" errors for sourced/rc files without a shebang.

</div>

<div class="paragraph">

Modelines are editor metadata only. They must not change script behavior.

</div>

<div class="paragraph">

If modelines are changed, keep them semantically aligned (indent width, tabs/spaces, filetype/language).

</div>

</div>

<div class="sect2">

### Script Structure Order

<div class="paragraph">

Scripts should follow this structure:

</div>

<div class="listingblock">

<div class="content monospaced">

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

</div>

</div>

</div>

</div>

</div>

<div class="sect1">

## Error Handling & Safety

<div class="sectionbody">

<div class="sect2">

### <span class="monospaced">set</span> Options

<div class="paragraph">

Whether to use <span class="monospaced">set -euo pipefail</span> is a **per-script decision**. Document the choice in a comment.

</div>

<div class="sect3">

#### When to use <span class="monospaced">set -euo pipefail</span>

<div class="paragraph">

Recommended for standalone scripts that should **fail fast** on unexpected errors:

</div>

<div class="listingblock">

<div class="content monospaced">

    # -e: exit on error
    # -u: treat unset variables as an error
    # -o pipefail: return exit code of the last failed command in a pipeline
    set -euo pipefail

</div>

</div>

</div>

<div class="sect3">

#### When NOT to use it

<div class="ulist">

- **Interactive shell functions** (<span class="monospaced">.zsh.d/</span>) — an error in one function should not terminate the shell session

- Scripts with **intentional non-zero exits** from subcommands (e.g., using <span class="monospaced">grep -q</span> which returns 1 on no match)

- Scripts that need **fine-grained error control** — <span class="monospaced">set -e</span> can mask intentional failures and has subtle scoping rules (see [BashFAQ \#105](https://mywiki.wooledge.org/BashFAQ/105))

</div>

<div class="paragraph">

When <span class="monospaced">set -e</span> is active and a command is expected to fail, use explicit guards:

</div>

<div class="listingblock">

<div class="content monospaced">

    some_command || true            # Ignore failure
    if ! some_command; then ... fi  # Handle failure explicitly

</div>

</div>

</div>

<div class="sect3">

#### Additional options

<div class="paragraph">

<span class="monospaced">set -o errtrace</span> (<span class="monospaced">-E</span>) with an <span class="monospaced">ERR</span> trap provides detailed error reporting:

</div>

<div class="listingblock">

<div class="content monospaced">

    set -o errtrace
    trap '_rc=$?; \
          printf "ERROR(%s) in %s:%s\n  -> %s\n  -> %s\n" "${_rc}" \
                 "${0:-N/A}" "${LINENO:-N/A}" "${FUNCNAME[@]:-N/A}" \
                 "${BASH_COMMAND:-N/A}"; \
          exit $_rc' ERR

</div>

</div>

<div class="paragraph">

<span class="monospaced">set -o xtrace</span> (<span class="monospaced">-x</span>) for debug output, typically guarded:

</div>

<div class="listingblock">

<div class="content monospaced">

    (( ${DEBUG_LVL:-0} >= 2 )) && set -o xtrace

</div>

</div>

</div>

</div>

<div class="sect2">

### Traps

<div class="paragraph">

Always set up traps for clean error reporting and interrupt handling:

</div>

<div class="listingblock">

<div class="content monospaced">

    trap '_rc=$?; \
          printf "ERROR(%s) in %s:%s\n  -> %s\n  -> %s\n" "${_rc}" \
                 "${0:-N/A}" "${LINENO:-N/A}" "${FUNCNAME[@]:-N/A}" \
                 "${BASH_COMMAND:-N/A}"; \
          exit $_rc' ERR
    trap 'printf "\nINTERRUPT\n"; exit 1' SIGINT SIGTERM

</div>

</div>

<div class="paragraph">

If the script creates temporary files or needs cleanup, use an <span class="monospaced">EXIT</span> trap:

</div>

<div class="listingblock">

<div class="content monospaced">

    cleanup() {
      rm -f "${tmp_file:-}"
    }
    trap cleanup EXIT

</div>

</div>

</div>

<div class="sect2">

### IFS

<div class="paragraph">

Setting <span class="monospaced">IFS</span> to exclude spaces can prevent subtle word-splitting bugs when handling filenames:

</div>

<div class="listingblock">

<div class="content monospaced">

    IFS=$'\t\n\0'

</div>

</div>

<div class="paragraph">

This is optional and should be used when the script processes filenames or other data that may contain spaces. Document when and why it is set.

</div>

</div>

</div>

</div>

<div class="sect1">

## Naming Conventions

<div class="sectionbody">

<div class="sect2">

### Functions

<div class="paragraph">

Use <span class="monospaced">lowercase_with_underscores</span> (per Google convention):

</div>

<div class="listingblock">

<div class="content monospaced">

    parse_args() { ... }
    process_file() { ... }

</div>

</div>

<div class="paragraph">

**Library functions** use a namespace prefix with <span class="monospaced">::</span> separator:

</div>

<div class="listingblock">

<div class="content monospaced">

    cl::p_err() { ... }    # commons lib: print error
    cl::cmd_p() { ... }    # commons lib: command predicate

</div>

</div>

<div class="paragraph">

**Underscore prefix for "private" identifiers**: Not required as a general convention, but acceptable in **sourced files** (<span class="monospaced">.zsh.d/</span>, <span class="monospaced">lib/</span>) to distinguish internal helper functions from user-facing ones. This is a pragmatic approach for files where functions enter the user’s shell namespace:

</div>

<div class="listingblock">

<div class="content monospaced">

    # In .zsh.d/functions.zsh:
    _helper_function() { ... }  # Internal, not intended for direct use
    public_function() { ... }   # User-facing, callable from the shell

</div>

</div>

<div class="paragraph">

In standalone scripts this distinction is unnecessary since functions do not leak into the caller’s namespace.

</div>

</div>

<div class="sect2">

### Variables

<div class="paragraph">

**Local variables**: <span class="monospaced">lowercase_with_underscores</span>, declared with <span class="monospaced">local</span>:

</div>

<div class="listingblock">

<div class="content monospaced">

    local -r config_file="/etc/myapp.conf"
    local -i retry_count=3

</div>

</div>

<div class="paragraph">

**Constants and global variables**: <span class="monospaced">UPPERCASE_WITH_UNDERSCORES</span>:

</div>

<div class="listingblock">

<div class="content monospaced">

    declare -r MAX_RETRIES=5
    declare -ra REQUIRED_COMMANDS=(rsync parallel)

</div>

</div>

<div class="paragraph">

**Library constants**: namespace prefix:

</div>

<div class="listingblock">

<div class="content monospaced">

    declare -r CL_SCRIPT_PATH="..."
    declare -r CL_TIMESTAMP_FORMAT="%Y-%m-%dT%H:%M:%S%z"

</div>

</div>

</div>

<div class="sect2">

### Avoiding Name Conflicts

<div class="paragraph">

Never use common environment variable names for local variables without a distinguishing prefix. Names to avoid in particular:

</div>

<div class="paragraph">

<span class="monospaced">PATH</span>, <span class="monospaced">PWD</span>, <span class="monospaced">HOME</span>, <span class="monospaced">USER</span>, <span class="monospaced">SHELL</span>, <span class="monospaced">TERM</span>, <span class="monospaced">LANG</span>, <span class="monospaced">IFS</span>, <span class="monospaced">CMD</span>, <span class="monospaced">LOG</span>, <span class="monospaced">HOSTNAME</span>, <span class="monospaced">EDITOR</span>, <span class="monospaced">DISPLAY</span>, <span class="monospaced">UID</span>, <span class="monospaced">GROUPS</span>

</div>

<div class="paragraph">

When in doubt, use a descriptive prefix or more specific name (e.g., <span class="monospaced">log_file</span> instead of <span class="monospaced">LOG</span>, <span class="monospaced">target_path</span> instead of <span class="monospaced">PATH</span>).

</div>

</div>

</div>

</div>

<div class="sect1">

## Variable Declarations

<div class="sectionbody">

<div class="paragraph">

Use <span class="monospaced">declare</span> / <span class="monospaced">local</span> with appropriate type flags:

</div>

<div class="listingblock">

<div class="content monospaced">

    local -r name="value"        # readonly
    local -i count=0             # integer
    local -a items=()            # indexed array
    local -A map=()              # associative array
    declare -r GLOBAL_CONST="x"  # global readonly constant

</div>

</div>

<div class="paragraph">

Prefer <span class="monospaced">declare -r</span> / <span class="monospaced">local -r</span> over the <span class="monospaced">readonly</span> builtin for consistency.

</div>

<div class="paragraph">

**Separate declaration from assignment** when capturing command output (prevents masking the command’s exit code):

</div>

<div class="listingblock">

<div class="content monospaced">

    # Good:
    local result
    result=$(some_command)

    # Bad (exit code of some_command is lost):
    local result=$(some_command)

</div>

</div>

<div class="paragraph">

**Bash/Zsh compatibility**: In code that must work in both shells (notably <span class="monospaced">lib/commons.sh</span>), use <span class="monospaced">typeset</span> instead of <span class="monospaced">declare</span>, as its behavior is more consistent across shells.

</div>

</div>

</div>

<div class="sect1">

## Formatting

<div class="sectionbody">

<div class="sect2">

### Indentation

<div class="paragraph">

**2 spaces**, no tabs. This is declared in the file metadata:

</div>

<div class="listingblock">

<div class="content monospaced">

    # code: language=bash insertSpaces=true tabSize=2

</div>

</div>

</div>

<div class="sect2">

### Line Length

<div class="ulist">

- **Code lines**: 120-character soft limit. Prefer breaking long lines for readability, but do not contort logic to fit an arbitrary limit.

- **Decorative / folding lines**: 78 characters total (fill character <span class="monospaced">=</span> or <span class="monospaced">-</span> padded to that length).

- **URLs and file paths**: may exceed either limit; isolate on their own line when possible.

</div>

</div>

<div class="sect2">

### Variable Expansion

<div class="paragraph">

Brace-delimit variables for clarity:

</div>

<div class="listingblock">

<div class="content monospaced">

    # Preferred:
    echo "${my_var}"
    echo "${array[@]}"

    # Acceptable for positional parameters and special variables:
    echo "$1" "$@" "$?" "$#"

</div>

</div>

<div class="paragraph">

Always double-quote variable expansions unless intentional word splitting is needed (which should be rare and documented).

</div>

</div>

<div class="sect2">

### Control Flow

<div class="paragraph">

Place <span class="monospaced">; then</span> and <span class="monospaced">; do</span> on the same line as the keyword:

</div>

<div class="listingblock">

<div class="content monospaced">

    if [[ -f "${file}" ]]; then
      process "${file}"
    fi

    for item in "${items[@]}"; do
      echo "${item}"
    done

    while read -r line; do
      echo "${line}"
    done < "${input_file}"

</div>

</div>

</div>

<div class="sect2">

### Section Folding

<div class="paragraph">

Use <span class="monospaced">{{{</span> / <span class="monospaced">}}}</span> markers for editor folding (compatible with [VS Code explicit-folding](https://marketplace.visualstudio.com/items?itemName=zokugun.explicit-folding) and [Emacs folding-mode](https://www.emacswiki.org/emacs/FoldingMode)):

</div>

<div class="paragraph">

**Level 1** (top-level sections) — fill with <span class="monospaced">=</span> to column 79:

</div>

<div class="listingblock">

<div class="content monospaced">

    # {{{ = SECTION NAME =========================================================

    # ... section content ...

    # }}} = SECTION NAME =========================================================

</div>

</div>

<div class="paragraph">

**Level 2** (sub-sections) — fill with <span class="monospaced">-</span> to column 79:

</div>

<div class="listingblock">

<div class="content monospaced">

    # {{{ - Sub Section ----------------------------------------------------------

    # ... sub-section content ...

    # }}} - Sub Section ----------------------------------------------------------

</div>

</div>

<div class="paragraph">

The closing line **repeats the section name** for readability. The total line length (including \`# {{{ = \` prefix and fill characters) is 78 characters.

</div>

<div class="sect3">

#### Enabling Folding in Editors

<div class="paragraph">

For **VS Code explicit-folding** add suggested default to\`settings.json\`:

</div>

<div class="listingblock">

<div class="content monospaced">

    "explicitFolding.rules": {
        "*": {
            "begin": "{{{",
            "end": "}}}"
        }
    },

</div>

</div>

<div class="paragraph">

Alternatively more specific and only for shell scripts:

</div>

<div class="listingblock">

<div class="content monospaced">

    "[shellscript]": {
      "explicitFolding.rules": [
        {
          "begin": "# {{{",
          "end": "# }}}"
        }
      ]
    }

</div>

</div>

<div class="paragraph">

For **Emacs fold-mode**, add the following to <span class="monospaced">.emacs</span>:

</div>

<div class="listingblock">

<div class="content monospaced">

    ;; folding-mode
    (load "folding" 'nomessage 'noerror)
    (folding-add-to-marks-list 'shell-script-mode "# {{{ " "# }}}" nil t)
    (folding-mode-add-find-file-hook)

</div>

</div>

</div>

</div>

</div>

</div>

<div class="sect1">

## Functions

<div class="sectionbody">

<div class="paragraph">

Use <span class="monospaced">name() {</span> syntax without the <span class="monospaced">function</span> keyword (per Google convention):

</div>

<div class="listingblock">

<div class="content monospaced">

    # Good:
    my_function() {
      ...
    }

    # Avoid:
    function my_function {
      ...
    }

</div>

</div>

<div class="sect2">

### Function Documentation

<div class="paragraph">

Document non-trivial functions with a comment block. For library functions, include all applicable fields:

</div>

<div class="listingblock">

<div class="content monospaced">

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

</div>

</div>

<div class="paragraph">

For simple helper functions in standalone scripts, a one-line comment suffices.

</div>

</div>

<div class="sect2">

### Function Organization

<div class="ulist">

- Group all function definitions **before** <span class="monospaced">main</span>.

- Define <span class="monospaced">main()</span> as the **last function**.

- Call <span class="monospaced">main "\$@"</span> as the **last line** of the script.

</div>

</div>

<div class="sect2">

### <span class="monospaced">usage()</span> Function

<div class="paragraph">

Every script that accepts arguments should have a <span class="monospaced">usage()</span> function using a heredoc:

</div>

<div class="listingblock">

<div class="content monospaced">

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

</div>

</div>

</div>

</div>

</div>

<div class="sect1">

## Features & Builtins

<div class="sectionbody">

<div class="paragraph">

Follow the Google Shell Style Guide recommendations:

</div>

<div class="ulist">

- Prefer <span class="monospaced">\[\[ ... \]\]</span> over <span class="monospaced">\[ ... \]</span> or <span class="monospaced">test</span>

- Prefer <span class="monospaced">\$(command)</span> over backticks

- Prefer <span class="monospaced">(( ... ))</span> / <span class="monospaced">\$(( ... ))</span> for arithmetic; never <span class="monospaced">let</span> or <span class="monospaced">expr</span>

- Prefer parameter expansion over external commands (e.g., <span class="monospaced">\${var##\*/}</span> over <span class="monospaced">basename "\$var"</span>)

- Avoid <span class="monospaced">eval</span>

- Use arrays for command argument lists

- Use process substitution (<span class="monospaced">\< \<(command)</span>) instead of piping to <span class="monospaced">while</span>

- Use <span class="monospaced">"\$@"</span> instead of <span class="monospaced">\$\*</span>

</div>

</div>

</div>

<div class="sect1">

## Argument Parsing

<div class="sectionbody">

<div class="paragraph">

Use a <span class="monospaced">while</span> / <span class="monospaced">case</span> / <span class="monospaced">shift</span> loop:

</div>

<div class="listingblock">

<div class="content monospaced">

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

</div>

</div>

</div>

</div>

<div class="sect1">

## Library Usage (<span class="monospaced">commons.sh</span>)

<div class="sectionbody">

<div class="sect2">

### Standard Inclusion Pattern

<div class="listingblock">

<div class="content monospaced">

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

</div>

</div>

</div>

<div class="sect2">

### When to Use commons.sh

<div class="ulist">

- **Prefer commons.sh** for logging (<span class="monospaced">cl::p_err</span>, <span class="monospaced">cl::p_war</span>, <span class="monospaced">cl::p_msg</span>), text effects (<span class="monospaced">cl::fx</span>), predicates (<span class="monospaced">cl::is_int</span>, <span class="monospaced">cl::cmd_p</span>), and other utilities it provides — to reduce code duplication.

- **Standalone is OK** for simple scripts that only need basic functionality and benefit from having no external dependencies.

- **Never duplicate** commons.sh functionality in a script that already sources it.

</div>

</div>

<div class="sect2">

### Namespace Convention

<div class="paragraph">

All <span class="monospaced">commons.sh</span> public identifiers use the <span class="monospaced">cl</span> namespace:

</div>

<div class="ulist">

- Functions: <span class="monospaced">cl::function_name</span>

- Constants: <span class="monospaced">CL_CONSTANT_NAME</span>

</div>

</div>

</div>

</div>

<div class="sect1">

## Zsh-Specific Conventions

<div class="sectionbody">

<div class="paragraph">

This section applies to files under <span class="monospaced">.zsh.d/</span> and other Zsh-only code.

</div>

<div class="sect2">

### File Conventions

<div class="ulist">

- Files use <span class="monospaced">.zsh</span> extension

- No shebang (they are sourced, not executed directly)

- End sourced files with <span class="monospaced">return 0</span>

</div>

</div>

<div class="sect2">

### Global Aliases

<div class="paragraph">

Zsh supports global aliases (expanded anywhere in a command line). Use sparingly and with distinctive names to avoid accidental expansion:

</div>

<div class="listingblock">

<div class="content monospaced">

    alias -g @G='| grep'
    alias -g @L='| less'
    alias -g @H='| head'
    alias -g @T='| tail'

</div>

</div>

</div>

<div class="sect2">

### Private Functions in Sourced Files

<div class="paragraph">

In <span class="monospaced">.zsh.d/</span> function files, use underscore prefix for helper functions that should not be called directly by the user:

</div>

<div class="listingblock">

<div class="content monospaced">

    # Internal helper -- not for direct use
    _format_output() { ... }

    # User-facing function
    my_tool() {
      local result
      result=$(_format_output "$@")
      echo "${result}"
    }

</div>

</div>

</div>

<div class="sect2">

### Compatibility with Bash

<div class="paragraph">

When writing code that must work in both shells (primarily <span class="monospaced">lib/commons.sh</span>):

</div>

<div class="ulist">

- Use <span class="monospaced">typeset</span> instead of <span class="monospaced">declare</span> for more consistent behavior

- Be aware of array indexing differences (Zsh starts at 1, Bash at 0)

- Test with both <span class="monospaced">bash</span> and <span class="monospaced">zsh</span> before committing

</div>

</div>

</div>

</div>

<div class="sect1">

## Logging & Output

<div class="sectionbody">

<div class="sect2">

### Error Output

<div class="paragraph">

All error and warning messages go to **stderr** (<span class="monospaced">\>&2</span>):

</div>

<div class="listingblock">

<div class="content monospaced">

    printf "ERROR: %s\n" "${message}" >&2

</div>

</div>

</div>

<div class="sect2">

### With commons.sh

<div class="paragraph">

Use the provided logging functions:

</div>

<div class="listingblock">

<div class="content monospaced">

    cl::p_err "Something went wrong: ${details}"
    cl::p_war "Proceeding without optional feature"
    cl::p_msg "Processing file: ${file}"
    cl::p_dbg 1 "Debug detail (level 1)"

</div>

</div>

</div>

<div class="sect2">

### Without commons.sh

<div class="paragraph">

Define minimal helpers for consistent formatting. The standard template used across most <span class="monospaced">bin/</span> scripts (comment out unused functions):

</div>

<div class="listingblock">

<div class="content monospaced">

    p_msg() { printf '%s\n' "$*"; }
    #p_nfo() { printf '\033[32mINFO\033[0m %s\n' "$*"; }
    #p_war() { printf '\033[33mWARNING\033[0m %s\n' "$*" >&2; }
    p_err() { printf '\033[31mERROR\033[0m: %s\n' "$*" >&2; }
    #p_dbg() { (( "${1:-0}" <= "${DEBUG_LVL:-0}" )) && printf '\033[36mDEBUG\033[0m: %s\n' "${*:2}" >&2 || true; }

</div>

</div>

<div class="paragraph">

For scripts with structured logging (timestamps, log levels, file output), a <span class="monospaced">log\_\*</span> naming convention is also acceptable:

</div>

<div class="listingblock">

<div class="content monospaced">

    log_error() { printf "\033[31mERROR\033[0m: %s\n" "$*" >&2; }
    log_warn()  { printf "\033[33mWARN\033[0m: %s\n" "$*" >&2; }
    log_info()  { printf "%s\n" "$*"; }

</div>

</div>

</div>

</div>

</div>

<div class="sect1">

## Linting & Static Analysis

<div class="sectionbody">

<div class="sect2">

### ShellCheck

<div class="paragraph">

[ShellCheck](https://www.shellcheck.net/) ([GitHub](https://github.com/koalaman/shellcheck)) is the recommended linting tool. The Google Shell Style Guide also recommends it.

</div>

<div class="paragraph">

Run it against scripts to catch common bugs, quoting issues, and portability problems:

</div>

<div class="listingblock">

<div class="content monospaced">

    shellcheck bin/my-script
    shellcheck lib/commons.sh

</div>

</div>

<div class="paragraph">

A VS Code extension is available: [ShellCheck for VS Code](https://marketplace.visualstudio.com/items?itemName=timonwong.shellcheck).

</div>

<div class="admonitionblock">

|  |  |
|----|----|
| ![Note](./images/icons/note.png) | Deeper integration with CI pipelines, pre-commit hooks, and testing frameworks is tracked in <span class="monospaced">docs/TODO.md</span>. |

</div>

</div>

</div>

</div>

<div class="sect1">

## Documentation

<div class="sectionbody">

<div class="ulist">

- Use <span class="monospaced">README.md</span> for high-level overview and link to detailed docs in <span class="monospaced">@docs/</span>. Use <span class="monospaced">TODO.md</span> for tracking tasks and future improvements. Keep both files up to date with the project’s current state and plans.

  <div class="ulist">

  - Create new documentation files in <span class="monospaced">@docs/</span> whenever it seems appropriate; especially when more extensive changes are planned/made, or complex features are added that require detailed explanation.

  </div>

- Use this <span class="monospaced">@docs/shell-style-guide.md</span> for the full style guide, and <span class="monospaced">CLAUDE.md</span> for a concise summary.

</div>

<div class="sect2">

### Formatting and Style Guidelines

<div class="ulist">

- Use \[Asciidoc\](<https://asciidoctor.org/docs/asciidoc-syntax-quick-reference/>) for documentation.

- Avoid the use of tabs, use spaces for indentation.

</div>

</div>

</div>

</div>

</div>

<div id="footnotes">

------------------------------------------------------------------------

</div>

<div id="footer">

<div id="footer-text">

Last updated 2026-06-01 13:39:24 CEST

</div>

</div>
