---
title: tmux — SSH auto-attach, sessions vs windows, and getting back to work
hosts: [all]
status: resolved
tags: [tmux, ssh, shell, remote, agents]
updated: 2026-10-10
---

# tmux on SSH logins

Why an SSH login sometimes shows a **clean shell** while a long-running job
(e.g. a Claude Code session) is still alive somewhere else — and how to reach it.

## What the auto-attach actually does

`cb_tmux_autoattach()` in `dotfiles/.common_rc`, opt-in per host via
`CB_TMUX_AUTOATTACH=1` in `lib/env-<host>.sh` (currently the vserver and saito),
runs exactly one command:

```bash
tmux new-session -A -s "${CB_TMUX_SESSION:-main}"
```

`-A` means *attach if it exists, otherwise create*. The key word is **name**: it
only ever touches the session called `main`.

It skips itself when already inside tmux, with no tty (`scp`, `ssh host cmd`,
agents), on a local console, for root, in VS Code / Emacs terminals, and when
`SHLVL > 1`.

## So why a clean shell when something is running?

Because a session started **by hand** is not named `main`. A bare `tmux` names
the session `0`, `1`, … — the hook cannot match that, so it creates `main`
alongside it:

```
$ tmux ls
0     1 windows  (attached)    # started by hand, holds the running agent
main  1 windows  (attached)    # created by the SSH login
```

Two **sibling** sessions, nothing nested. That surprises people (it did here,
2026-10-01) because the second session looks like a nested tmux, and tmux has no
visible "you are in session X of 2" indicator by default.

**This is deliberate, not a bug to fix.** Attaching to whatever ran last would
drop the first keystrokes of a half-typed command into an unknown window — an
agent's prompt, `vim`, `less`. Landing in a predictable fresh shell is worth more
than being saved one keypress, especially when reconnecting a day later with no
memory of what was left running.

### Why exiting that shell reveals the other session

`.tmux.conf` sets `detach-on-destroy off`. When the last window of `main` exits,
the session is destroyed, and instead of ending the connection the client
switches to a **remaining** session — which is the one that was running all
along. That is the setting working as intended, not a second surprise.

## Sessions vs. windows

| Level | Holds | Default lifetime |
| ----- | ----- | ---------------- |
| **Server** | all sessions, one per user | until the last session ends |
| **Session** | windows; what a client attaches *to* | survives disconnects — this is why work is parked here |
| **Window** | panes; one "screen" | until its last pane exits |

A client attaches to a *session* and sees one *window* at a time. Two clients on
the same session mirror each other.

## Navigating (prefix is `C-a` here, not `C-b`)

| Keys | Does |
| ---- | ---- |
| `prefix s` | **session list** — pick the one holding the work |
| `prefix w` | window list, across sessions |
| `prefix (` / `prefix )` | previous / next session |
| `prefix c` / `prefix n` / `prefix p` | new / next / previous window |
| `prefix d` | detach (leaves everything running) |
| `prefix $` | rename the current session |

From the fresh `main` shell, `prefix s` then the other session is the whole
answer.

`C-a` is also line-start in zsh and Emacs: press **`C-a C-a`** to send it to
the program.

## Copy mode (emacs keys)

`mode-keys emacs` since 2026-10 (vi before; a two-line toggle in
`.tmux.conf`), so scrollback works like zsh and Emacs:

| Keys | Does |
| ---- | ---- |
| `prefix [` | enter copy mode (scrollback) |
| arrows, `C-n` / `C-p`, `C-v` / `M-v` | move, page down / up |
| `C-s` / `C-r` | search forward / backward |
| `C-SPC` | start selection |
| `M-w` | copy selection and leave (also to the outer terminal's clipboard, `set-clipboard on`) |
| `C-g` / `q` | clear selection / leave copy mode |
| `prefix ]` | paste the last copy |

With `mouse on`, dragging selects and copies too.

## Practices that keep this legible

- **Name sessions started by hand**: `tmux new -s claude`, not bare `tmux`.
  `prefix s` then lists `claude` instead of `0`. Rename an existing one with
  `prefix $`.
- **Park long-running agents in a named session** — that is the whole point of
  tmux here, and it is what makes an SSH drop a non-event.
- **Detach the small client when done** (`prefix d`) — see *Two devices, two
  sizes* below for why that is the actual remedy.
- **Check before assuming nothing runs**: `tmux ls` costs nothing and answers
  "did I leave something open?" — which is otherwise unanswerable after a day.

## Two devices, two sizes

Who decides a window's size, given a phone (≈82x29 over Termius) and the desktop
(≈120x50)? The `window-size` option (default `smallest`) picks *which* attached
client wins; `aggressive-resize` changes *which clients count*. Three cases, and
only one of them is a real problem:

| Both clients are… | What happens |
| ----------------- | ------------ |
| in **different sessions** | Sizes are already independent — a session is sized by its own clients. The phone cannot shrink a session it is not attached to. Nothing to configure. |
| in the **same session**, on **different windows** | Normally the whole session is sized for the smallest client. This is the *only* case `aggressive-resize on` improves: a window is then sized for the clients whose current window it is. |
| in the **same session**, on the **same window** | Unavoidable. One window is one pty with one size, so it must fit both; `smallest` clamps to the phone. No option removes this. |

That last case is the one that prompts the question, and it is inherent rather
than misconfigured. The options are `window-size latest` (size for whichever
client was last active: the desktop regains full width, the phone view is
cropped) or simply **detaching the phone** with `prefix d`.

**`aggressive-resize` is deliberately left off here.** tmux(1) says it is "good
for full-screen programs which support SIGWINCH and poor for interactive
programs such as shells" — and these windows are mostly shells. It was briefly
enabled on 2026-10-01 and reverted the same day once the man page was actually
read: it addresses neither of the two cases that occur in practice here, since
both SSH logins attach to the *same* session (`main`).

## Related

- `dotfiles/.common_rc` — the hook, with the attach-by-name rationale inline.
- `dotfiles/.tmux.conf` — prefix, `detach-on-destroy`, `aggressive-resize`.
- `~/.claude/skills/mobile-mode/SKILL.md` — phone sessions use a detached
  window (`tmux new-window -d`) to give an interactive step a real tty.
