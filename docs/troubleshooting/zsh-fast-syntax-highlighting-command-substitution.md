---
title: fast-syntax-highlighting mangles zsh input on command substitution
hosts: [all]
status: workaround
tags: [zsh, zinit, fast-syntax-highlighting, command-substitution, backticks, history, wsl]
updated: 2026-09-25
revisit: 2026-12-01
---

## fast-syntax-highlighting mangles zsh input on command substitution

## Symptom

Recalling or pasting a command line that contains balanced command substitution
can corrupt the interactive editor state.

Observed trigger:

```zsh
git clone "ssh://<user>@<internal-git-host>:29418/<group>/<repo>" && (cd "<repo>" && mkdir -p `git rev-parse --git-dir`/hooks/ && curl -Lo `git rev-parse --git-dir`/hooks/commit-msg https://<internal-git-host>/tools/hooks/commit-msg && chmod +x `git rev-parse --git-dir`/hooks/commit-msg)
```

Symptoms once the buggy history entry is on the command line:

- left/right arrows move two positions instead of one
- typing inserts doubled characters (`a` -> `aa`)
- backspace deletes two characters
- after a little more interaction, syntax highlighting breaks and the entire
  command line becomes plain white

The trigger was the legacy backtick form. Removing one backtick (making the
command substitution unbalanced) made the duplication stop immediately.

## What ruled things out

- vi mode vs. emacs mode: `bindkey -v` and `bindkey -e` behaved the same
- ordinary history recall/paste without command substitution: no issue
- zsh itself with plugins truly disabled: no issue

An early test with `PLUGIN_MODE=skip zsh -i` was misleading because
[`dotfiles/.zshrc`](../../dotfiles/.zshrc) used to overwrite an exported
`PLUGIN_MODE`; that was fixed on 2026-09-25, so `skip` now really disables the
plugin stack.

## Isolation

Confirmed good:

- `wsl sh -c 'PLUGIN_MODE=skip zsh -i'` -> plain shell, no highlighting, no bug
- commenting out the fast-syntax-highlighting load and restarting the shell ->
  no highlighting, no bug

Confirmed bad:

- normal startup with `zdharma-continuum/fast-syntax-highlighting` enabled ->
  bug reproducible from history recall / paste

That isolates the problem to `fast-syntax-highlighting`, not to zsh keymaps,
history options, prompt theme, or WSL itself.

## Upstream status

This matches the upstream bug report:

- <https://github.com/zdharma-continuum/fast-syntax-highlighting/issues/34>

Issue title: `Input mangling when using command substitution`

The upstream report uses `$()`; local reproduction used backticks. The failure
mode is the same: duplicated input and broken editor behavior after command
substitution enters the buffer.

## Workaround

Keep the plugin enabled normally, but if line editing starts duplicating input
on a pasted/recalled command with command substitution:

1. cancel the line with `Ctrl-C`
2. avoid backticks; rewrite to `$()` when editing manually
3. if needed, start a plugin-free shell with `PLUGIN_MODE=skip zsh -i`
4. if the bug becomes frequent, disable or replace fast-syntax-highlighting

For this repo, the edge case is rare enough that keeping the plugin is an
acceptable tradeoff for now.
