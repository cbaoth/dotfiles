---
title: zsh notes (options, globbing, keybindings)
hosts: [all]
status: resolved
tags: [zsh, shell, keybindings, emacs-mode, vi-mode, glob, foot, fzf]
updated: 2026-10-10
---

Some random notes on zsh, mostly for my own reference.

# Options

## Enabled

### `EXTENDED_GLOB`

Treats `#`, `~`, and `^` as pattern operators for advanced globbing [^1] [^2].

- Option: `setopt extendedglob`

- Why enabled: Mandatory for some functions and aliases in this setup

- Examples:

- `rm *-[0-9]##.png`: removes files like `foo-123.png`

- `rm ^*.(tar|bz2|gz) /tmp/`: removes non-archive files (`^` negates)

- `rm my-service.<12-234>.log`: removes files with numeric range in name

## Optional (currently disabled)

There are many more options[^3][^4] that can be enabled for specific use cases. Here are some that I have considered or want to mention for future reference.

### `CORRECT_ALL` (`-O`)

Tries to correct the spelling of all arguments in a command line [^5].

- Option: `#setopt correctall`

- Notes: Can use `CORRECT_IGNORE_FILE` to exclude filename patterns

### `AUTO_CD` (`-J`)

If a command is not executable but names a directory, zsh performs `cd` to it [^6].

- Option: `#setopt autocd`

- Examples:

- `~` behaves like `cd ~`

- `/var/log` behaves like `cd /var/log`

### `NULL_GLOB` (`-G`)

If a glob pattern has no matches, it is removed from the argument list instead of causing an error [^7].

- Option: `#setopt -o nullglob`

- Note: Overrides `NOMATCH`

### `CSH_NULL_GLOB` (`<C>`)

Like `NULL_GLOB`, but reports an error only if *all* patterns in a command have no matches [^8].

- Option: `#setopt -o cshnullglob`

- Note: Also overrides `NOMATCH`

### `GLOB_DOTS` (`-4`) / `DOT_GLOB`

Includes dotfiles in glob matches without requiring a leading `.` in the pattern.

- Option: `#setopt globdots`

- Note: `DOT_GLOB` is the bash-compatibility name for `GLOB_DOTS`

> [!WARNING]
> This can be dangerous. For example, `rm ^.*` can match and delete more than expected when dotfiles are included.

# Global Expansion

Glob patterns are short expressions that match filenames or strings. They are used in various contexts, such as filename expansion, parameter expansion, and command substitution.

Z-Shell supports a rich set of glob patterns[^9][^10].

In my setup, I use `setopt extendedglob` but not `setopt dotglob`. The latter can be enabled on a per-command basis by using the suffix `(D.)` in glob patterns.

Examples:

``` zsh
print -l **/*~(.git|node_modules)/*~*.(md|adoc|png)(D.)
# print -l:   print each match on a separate line
# **/*:       recursive glob for all files/directories
# ~(pattern): exclude matches of `pattern` (can be repeated)
# (D.):       include dot-files/directories in glob
```

# Commands to Remember

## run-help

The `run-help` command is a zsh built-in that provides access to the shell’s help system. It can be used to get information about built-in commands, shell options, and other topics.

## whence

The `whence` command is used to determine how a command name is interpreted by the shell. It can show whether a command is an alias, function, builtin, or external executable.

Compared to `which` (which only shows the path of external executables), `whence` provides more comprehensive information about command resolution in zsh.

Compared to `command -v` (which is POSIX-compliant and shows the path of external executables or indicates if it’s a shell builtin), `whence` can also identify aliases and functions, making it more versatile for zsh users.

## rehash

When you install new software that includes command-line tools, you may need to run `rehash` in zsh to update the command hash table. This allows zsh to recognize the new commands without needing to restart the shell.

## zargs

`zargs` is a zsh autoloadable function that works like `xargs` but understands zsh glob qualifiers natively and automatically batches arguments to stay under `ARG_MAX`. It is the idiomatic zsh solution to the "argument list too long" error.

```zsh
autoload -Uz zargs
zargs **/*.*(.) -- some_command
```

Add `autoload -Uz zargs` to `.zshrc` to have it always available.

### The problem

```zsh
some_command **/*.*(.)   # zsh: argument list too long: some_command
```

This happens when a glob expands to more filenames than the kernel's `ARG_MAX` limit allows in a single `execve()` call.

### Alternatives

| Approach | Notes |
|---|---|
| `for f in **/*.*(.) ; do some_command "$f"; done` | Simple; one subprocess per file; fine unless startup cost is high |
| `find ... -exec some_command {} +` | POSIX-portable; batches efficiently; no zsh glob qualifiers |
| `zargs **/*.*(.) -- some_command` | Zsh-native; supports glob qualifiers; batches automatically |
| `zmodload zsh/files` | Loads zsh built-in replacements for `rm`, `mv`, `ln` etc. that bypass `ARG_MAX` entirely |

### Examples

From zsh-lovers[^11]:

```zsh
# Remove setgid/setuid from mail dirs and all contents (dotfiles included)
zargs /home/*/*-mail(DNs,S) /home/*/*-mail/**/*(DNs,S) -- chmod -s

# Delete all regular files older than 3 hours in /Dir
rm -f /Dir/**/*(.mh+3)

# Delete all files older than 6 hours (use zargs if arg list too long)
autoload zargs; zargs **/*(mh+6) -- rm -f

# Alternative to zargs: load zsh built-in rm that bypasses ARG_MAX
zmodload zsh/files; rm -f **/*(mh+6)

# Delete all but the 10 newest files in a directory
rm ./*(Om[1,-11])
```

# Keyboard Shortcuts

Inspect bindings with `bindkey` (current keymap) or `bindkey -M <keymap>`
(`emacs`, `viins`, `vicmd`, `command`, …); `bindkey -l` lists keymaps. All bindings live
in the `ZSH KEYBINDINGS` section of `~/.zshrc`.

## Editing model: emacs mode

**Emacs** mode (`bindkey -e`, main keymap `emacs`). History:

| Period | Mode | Why |
| --- | --- | --- |
| years until 2026-07 | emacs | default |
| 2026-07 to 2026-10 | vi (`bindkey -v`) | modal motions and visual selection matching vim muscle memory |
| since 2026-10 | emacs | Emacs is back as the editor: same keys in shell and editor, more practice (see [docs/setup/emacs.md](../setup/emacs.md)) |

Switching back to vi mode is a two-line toggle in `~/.zshrc`: swap
`bindkey -e`/`#bindkey -v` and uncomment `KEYTIMEOUT=20` (0.2 s, a fast `ESC`
into command mode that still leaves time for the zaw `Alt`-chords). Everything
else works in both modes:

- The single-press editing keys below are bound in the main keymap, whichever
  mode that is.
- The cursor-shape hook draws a **beam** `|` while typing, and a solid
  **block** in vi command mode (so in emacs mode: always a beam).

**Emacs vs. zsh, same key, different action** (worth knowing while practicing
both):

| Key | zsh | Emacs |
| --- | --- | --- |
| `Ctrl-W` | no selection: delete word left | no selection: cut from the mark |
| `Ctrl-U` | delete to start of line | numeric prefix argument |
| `Ctrl-R` | fuzzy history (zaw) | search backward |

## Single-press editing keys

Emacs-style keys, bound in the main keymap (emacs mode; in vi mode: insert).

| Key | Widget | Action |
| --- | --- | --- |
| `Ctrl-A` | `beginning-of-line` | jump to start of line |
| `Ctrl-E` | `end-of-line` | jump to end of line |
| `Alt-B` / `Alt-F` | `backward-word` / `forward-word` | move one word left / right |
| `Ctrl-W` | `_cb_kill_region_or_word` | cut the selection; without one, delete word to the **left** |
| `Alt-D` | `kill-word` | delete word to the **right** |
| `Ctrl-K` | `kill-line` | delete everything **right** of cursor |
| `Ctrl-U` | `backward-kill-line` | delete everything **left** of cursor |
| `Ctrl-Y` | `yank` | paste the last kill (`Alt-Y` cycles the kill-ring) |
| `Alt-.` | `insert-last-word` | insert **last arg of previous command** (repeat to cycle back) |
| `Ctrl-X Ctrl-E` | `edit-command-line` | open the current line (or only the selection) in **Emacs** (`$EDITOR` if Emacs is missing) |
| `→` / `Ctrl-E` / `End` | `forward-char` / `end-of-line` | accept the zsh-autosuggestions ghost text |

**Selection (Emacs-style, since 2026-10):**

| Key | Widget | Action |
| --- | --- | --- |
| `Ctrl-Space` | `set-mark-command` | start a selection (was `autosuggest-accept` until 2026-10) |
| `Alt-W` | `copy-region-as-kill` | copy the selection |
| `Ctrl-W` | `_cb_kill_region_or_word` | cut the selection |
| `Ctrl-Y` | `yank` | paste |
| `Ctrl-G` | `_cb_deactivate_or_break` | cancel the selection; without one, abort the line |
| `Ctrl-X Ctrl-X` | `exchange-point-and-mark` | jump to the other end of the selection |

**Prompt → editor → script.** For a one-liner that outgrows the prompt:
`Ctrl-X Ctrl-E` opens it in `emacs -nw` (set by the
`:zle:edit-command-line editor` zstyle in `.zshrc`, so `$EDITOR` stays nvim).
Edit, then `C-x C-s C-x C-c`: the result lands back at the prompt, not
executed. Optionally `C-c s` in Emacs first, to save a copy as an executable
script (zsh shebang added); the prompt still gets the edited line. The key runs
a small wrapper, `_cb-edit-command-line`, that redraws the whole prompt
afterwards: Emacs leaves the cursor in column 0, and without the redraw the
edit overwrote the `❯` on screen (the command itself was always right).
| `Ctrl-X a` | `_expand_alias` | expand the alias under the cursor **on demand** |
| `Alt-X` | `execute-named-cmd` | zsh's own `M-x`: run any zle widget by name (`Tab` completes), e.g. `quote-line`, `which-command` |

> **`Alt-.` is the path-reuse trick.** After `ll /long/path`, type e.g. `vim `
> then `Alt-.` → `vim /long/path`, without ever editing the long expanded alias.
> Related history word designators also work: `!$` (last arg), `!^` (first arg),
> `!*` (all args), `!!` (whole previous command).

> **`Ctrl-X Ctrl-E` exits through the editor.** It once "silently did nothing"
> while `$EDITOR` was `emacs -nw`; really there was no exit reflex left.
> In Emacs: `C-x C-s` save, `C-x C-c` quit. Without the Emacs zstyle it uses
> `$EDITOR` (`nvim`, see `_export_to_first_cmd EDITOR …` in `.common_env`).

## Vi command mode (`ESC`) — motions, selection, editing

**Vi mode only; inactive while emacs mode is on.** Kept for when vi mode is
switched back on. Standard vim command-mode keys apply to the command line:

| Key(s) | Action |
| --- | --- |
| `h` `l`, `w` `b` `e`, `0` `^` `$` | char / word / line-position motions |
| `v` / `V` | **visual** selection (char-wise / line-wise) |
| `y` / `d` / `x` | yank / delete / cut (the selection, or with a motion) |
| `d$` / `d^` | delete to end / start of line |
| `dw` `daw` `ciw` `cc` | delete-word / delete-a-word / change-inner-word / change-line |
| `/` … `?` … | search history backward / forward |
| `Ctrl-V` | `edit-command-line` — open the line in `$EDITOR` |

`v` is intentionally left at its vim default (visual mode); `Ctrl-V` (not `v`)
opens the editor.

## On-demand alias expansion (vs. auto-expand)

The `zsh-expand` plugin used to expand aliases inline on space/enter. It was
**disabled** (2026-07) because auto-expanding `ll` into its full
`LC_COLLATE=C ls --color=auto …` made every copy/paste and edit tedious. Expand
**only when wanted** instead:

- `Ctrl-X a` (`_expand_alias`) — expand the alias under the cursor, e.g. right
  before copying a command into docs or a message so the full detail is kept.
- Or recall the executed command from history and expand that copy separately,
  leaving what you type untouched.

## Special characters (insert a literal)

Prefix a key with **`Ctrl-V`** (`vi-quoted-insert`, also on `Ctrl-Q`) to insert
it literally instead of acting on it:

| Sequence | Inserts |
| --- | --- |
| `Ctrl-V` `Tab` | literal tab `\t` (instead of completion) |
| `Ctrl-V` `Enter` | literal carriage return — multi-line command (instead of executing) |
| `Ctrl-V` `Ctrl-J` | literal newline (LF) |
| `Ctrl-V` `Esc` | literal `ESC` byte |

> In emacs mode the **meta form** works too: `Alt-Enter` (or `ESC`, `Enter`)
> inserts a newline, `Alt-Tab` a tab (`"^[^M"/"^[^J"/"^[^I" self-insert-unmeta`,
> emacs-keymap defaults). In vi mode it does not: `ESC` enters command mode, so
> `Ctrl-V` is the only way there.

## History & completion widgets

| Key | Widget | Action |
| --- | --- | --- |
| `Ctrl-R` | `zaw-history` | fuzzy-filter command history (`zaw`) |
| `Ctrl-X r` | `history-incremental-search-backward` | plain incremental reverse search |
| `Alt-R` | `zaw` | open the `zaw` source menu |
| `Alt-V Alt-L/R/S` | `zaw-git-log` / `-reflog` / `-status` | git pickers via `zaw` |

## Terminal (foot): grab text from output above the prompt

zsh/zle cannot touch the scrollback — that is the terminal's buffer. foot pipes
it to a picker instead (`~/.config/foot/foot.ini` → `bin/foot-fzf-pick`):

| Key | Action |
| --- | --- |
| `Ctrl+Shift+g` | pick line/token from the **visible screen** via fzf → clipboard |
| `Ctrl+Shift+b` | pick line/token from the **whole scrollback** via fzf → clipboard |
| `Ctrl+Shift+v` | paste the clipboard (also middle-click) |
| `Ctrl+Shift+c` | copy the mouse selection |
| `Ctrl+Shift+r` | foot's built-in scrollback search |

`foot-fzf-pick` offers each non-blank line **and** each whitespace token (paths,
hashes, words), deduped — so a full `ls` line or a single `/etc/hosts` path can
be grabbed with the keyboard alone. Multi-select with `Tab`.

# Global aliases (typing shortcuts)

Global aliases (`alias -g`) expand **anywhere** on the line, not just in command
position — so a bare token mid-command becomes its expansion:

```zsh
ls -la ,g conf ,l      # -> ls -la | grep -E conf | less
journalctl -b ,gi fail ,t   # -> journalctl -b | grep -Ei fail | tail
find . -name '*.md' ,c      # -> find . -name '*.md' | wc -l
```

Defined in [`.zsh.d/aliases.zsh`](../../dotfiles/.zsh.d/aliases.zsh). Convention:
a **`,` (comma) prefix** — unshifted, fast, and collision-proof (a bare `,g`
can't be a filename/command, unlike a bare `G`). fast-syntax-highlighting
highlights them as you type. Pattern: `,<x>` = `| <cmd>`; leading `e` = include
stderr (`|&`); `i` = case-insensitive (`-i`).

| Alias | Expands to | | Alias | Expands to |
| --- | --- | --- | --- | --- |
| `,g` | `\| grep -E` | | `,n` | `> /dev/null 2>&1` |
| `,gi` | `\| grep -Ei` | | `,en` | `2> /dev/null` |
| `,eg` | `\|& grep -E` | | `,s` | `\| sort` |
| `,h` | `\| head` | | `,su` | `\| sort -u` |
| `,t` | `\| tail` | | `,c` | `\| wc -l` |
| `,tf` | `\| tail -f` | | `,x` | `\| xargs` |
| `,l` | `\| less` / `most` | | `,x0` | `\| xargs -0` |
| `,lower` / `,upper` | case fold via `tr` | | `,xl` | NUL-split batched `xargs` |
| `,sum` | sum first column (`awk`) | | `,mpv` | pipe file list into `mpv` |
| `,urlclean` | URL-decode + strip query (`sed`) | | | |

Add more as you find repetition — keep the `,` prefix and lowercase letters.

# External Resources

## Official

- [Z Shell](https://zsh.org) — official website
  - [Z Shell on SourceForge](https://zsh.sourceforge.io) — mirror with additional resources
  - [Documentation](https://zsh.sourceforge.io/Doc/)
  - [User Guide](https://zsh.sourceforge.io/Guide/)
  - [FAQ](https://zsh.sourceforge.io/FAQ/zshfaq.html)

## Documentation & Reference

- [DevDocs: Z-Shell](https://devdocs.io/zsh/) — browsable, searchable, offline-capable
- [Z-Shell Community Wiki](https://zshell.dev)
- [Z Shell Reference Card (PDF)](https://www.bash2zsh.com/zsh_refcard/refcard.pdf) — concise single-page cheat sheet
- [Wikipedia: Z shell](https://en.wikipedia.org/wiki/Z_shell)

## Guides & Examples

- [zsh-lovers](https://github.com/grml/zsh-lovers/blob/master/zsh-lovers.1.txt) — extensive collection of tips, tricks, and real-world examples (globbing, `zargs`, array operations, etc.)
- [grml.org/zsh](https://grml.org/zsh/) — grml project zsh page; links to configs and zsh-lovers resources
- [Pip!'s ZSH Prompt Guide](https://aperiodic.net/phil/prompt/) — detailed prompt customization walkthrough
- [Adam's ZSH Page](https://www.adamspiers.org/computing/zsh/) — curated tips and config examples

## Books

- [From Bash to Z Shell: Conquering the Command Line](https://www.bash2zsh.com/) — comprehensive English-language reference book

[^1]: [DevDocs: `EXTENDED_GLOB`](https://devdocs.io/zsh/options#index-BAREGLOBQUAL)

[^2]: [Gist examples](https://gist.github.com/roblogic/63f70f13665c689adca099c8d6d73641)

[^3]: [DevDocs: Options](https://devdocs.io/zsh/options)

[^4]: [ZSH Documentation: Options](https://zsh.sourceforge.net/Doc/Release/Options.html#Expansion-and-Globbing)

[^5]: [DevDocs: `CORRECT_ALL`](https://devdocs.io/zsh/options#index-CLOBBER)

[^6]: [DevDocs: `AUTO_CD`](https://devdocs.io/zsh/options#index-AUTO_005fCD)

[^7]: [DevDocs: `NULL_GLOB`](https://devdocs.io/zsh/options#index-CASE_005fMATCH)

[^8]: [DevDocs: `CSH_NULL_GLOB`](https://devdocs.io/zsh/options#index-BARE_005fGLOB_005fQUAL)

[^9]: [ZSH Documentation: 14 Expansion](https://zsh.sourceforge.io/Doc/Release/Expansion.html)

[^10]: [Z-Shell Community Wiki: Roadmap - Expansion](https://wiki.zshell.dev/community/zsh_guide/roadmap/expansion)

[^11]: [grml/zsh-lovers: zsh-lovers.1.txt](https://github.com/grml/zsh-lovers/blob/master/zsh-lovers.1.txt)
