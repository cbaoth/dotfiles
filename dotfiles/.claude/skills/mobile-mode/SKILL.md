---
name: mobile-mode
description: Low-typing workflow for driving a session from a phone or tablet over SSH/tmux. Hand every manual step over as a staged, self-verifying ccrun script with a log you read back yourself — never as commands to copy or files to hand-edit.
disable-model-invocation: true
---

# Mobile mode

The user is driving this session from a **phone or tablet**, over SSH into tmux
(e.g. Termius). Typing is slow, text selection is painful, and typos are likely.

Optimise for **the fewest keystrokes on their side** and **the most information
that reaches you without them relaying it**. Verbosity in a script is free;
verbosity in the terminal that they must read and retype is not.

## The one rule

> Never hand back something to type, copy, or hand-edit. Stage a script, and
> tell them the single line that runs it.

## The runner contract

The shared core — stage with `ccrun`, dry run by default, logged, guarded,
self-verifying, ending with `STATUS:` — is always-loaded project instruction
(`AGENTS.md` → *Privileged & interactive steps*). It applies in every session,
phone or not; read it there. What follows is only the phone-specific
ergonomics; keep the two in step when either changes.

- **Reserve one ID per session** (`ccrun new "<topic>"`) and keep it. Every fix
  overwrites the same `run`, so the user recalls `ccrun N` with `↑` and appends
  ` a` for the apply — never a new command to type.
- **Verbosity in the payload is free**: `cr::step` banners, pre/post checks,
  `cr::status`. The log carries it to you, not their screen.

Then tell them **exactly one line**, on its own, nothing else to decide:

```
! ccrun 1
```

The `!` prefix runs it in the session and drops the output straight into the
conversation, so you see the result with no relaying. Follow up with
`! ccrun 1 a` once the dry run looks right.

## When the step needs sudo or is interactive

Neither your own Bash tool nor the `!` prefix has a tty — both verified. `!`
reports `not a tty` and sudo there fails with *"interactive authentication is
required"*. That is sudo's own error, not a permission block: `!` is not gated
by the allow/deny rules at all, it simply has no terminal to prompt on, and no
setting can change that. **Never route a privileged step through either.**

A tmux window *does*, including one you create yourself, and creating it
detached neither steals focus nor leaves clutter (verified: it gets a real
pty and closes on completion). So launch the work rather than dictating it:

```bash
tmux new-window -d -n ccrun1 'ccrun 1 a -p'
```

`-p` (`--pause`) is what makes this safe:

- **`cr::sudo` pauses for Enter** before `sudo -v`. `new-window -d` starts the
  script at once, while the user is still in the other window — without the
  pause, the sudo prompt races their window switch and times out. Call
  `cr::sudo` once, right before the first privileged command; the credential
  is cached for the rest of the run (per tty, which this window is).
- **The window waits for a key before closing**, so the user can tell success
  from failure. The log is complete either way: `ccrun` writes the
  `EXIT:` line before the pause.

Everything interactive belongs *inside* the payload, where it is logged and you
can read it back — not inline in the tmux argument, where it is invisible to
you and unversioned.

Then tell the user only: *"`Ctrl-b n`, press Enter, type your password,
`Ctrl-b p` back."* A password and two chords, with no command to type and
nothing to relay. You read the log yourself afterwards.

If the apply guard refuses (no dry run of this version yet, or already
applied), the tmux window shows a `yes` prompt; rather than relying on it, run
the dry run first or fix the script.

If tmux is not available, fall back to: *"run `ccrun 1 a` in another
window, then just say done."*

Optionally `Monitor` the log for changes so you pick the result up without
even needing the "done".

## Everything else

- **Never ask them to edit a file.** Make the change with your own file tools,
  or stage it in the script with a heredoc plus a `diff` preview. If you need
  their judgement on the content, show the diff and ask a yes/no.
- **Ask by tap, not by typing.** Batch open questions into `AskUserQuestion`
  so answers are a tap. Never end a message with three open-ended questions.
- **Keep prose tight.** Short paragraphs, few tables, no wide code blocks —
  a phone terminal is ~50 columns and does not soft-wrap kindly.
- **Put long output in files, not the transcript.** Write reports to the
  scratchpad and summarise in two lines.
- **Prefer background execution** for anything slow, so their session is not
  blocked on a spinner they cannot easily interrupt.
- **Multi-host work** (`saito`, the vserver): the script does the `ssh`
  itself. Do not ask them to hop hosts and run something over there.
- **Batch aggressively.** One script with four verified steps beats four
  round-trips; each round-trip costs them a context switch on a phone.

## Turning it off

The mode lasts for the session. To drop it, the user says so — or just starts
a new session, since this skill is user-invoked only and never auto-loads.
