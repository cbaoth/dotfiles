# zsh completions (in-repo tools)

Completion functions for commands **shipped by this repo**. Each file is named
`_<command>` and starts with `#compdef <command>`; compinit autoloads it because
this directory is placed on `fpath` before `compinit` in `dotfiles/.zshrc`.
Deployed to `~/.zsh.d/completions/` on every host by `dotfiles-link`.

| File | Completes |
| ---- | --------- |
| `_system-setup` | `bin/system-setup` — options, `--profile` values, and module names (discovered live from `setup/modules/`) |
| `_check_script` | the `check_script` function (`lib/functions.sh`) |

Completions for **separate cloned projects** (e.g. `~/git/cb-voice-lab`) do
**not** live here — they ship inside their own repo's `completions/` dir and are
registered dynamically in `dotfiles/.zshrc`.

**Keep in sync:** these are hand-maintained. When a tool gains, renames, or
drops an option / subcommand / enumerated value, update its `_<cmd>` in the same
change. Full rule and rationale: see *Shell Completions* in `AGENTS.md`.

Reload after editing:

```zsh
rm -f "${ZSH_COMPDUMP:-~/.zcompdump}" && exec zsh
```
