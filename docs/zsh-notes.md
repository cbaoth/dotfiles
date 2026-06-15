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

You can use the `bindkey` command to display all key bindings in zsh.

## Special Characters

`M-(^M|^J|^I)` as well as `ESC, (ENTER|...)` insert the literal character. For example, `Alt-RETURN` and `ESC, RETURN` both insert a literal newline instead of executing the command, and `ESC, TAB` insearts a literal tab `\t` character instead of triggering `completion`.

```shell
"^[^I" self-insert-unmeta
"^[^J" self-insert-unmeta
"^[^M" self-insert-unmeta
"!"-"~" self-insert
"\M-^@"-"\M-^?" self-insert
```

## Expansion, Completion, History

- `C-x, r`: `"^Xr" history-incremental-search-backward` → Incrementally search backward through command history.

- `C-r`: `"^R" zaw-history` → Search/filter command history with `zaw` fuzzy finder.

- `C-x a`: `"^Xa" _expand_alias` → Expand aliases in the current command line.

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
