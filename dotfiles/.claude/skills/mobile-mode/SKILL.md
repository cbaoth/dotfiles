---
name: mobile-mode
description: Low-typing workflow for driving a session from a phone or tablet over SSH/tmux. Hand every manual step over as a staged, self-verifying script at a fixed path with a log you read back yourself — never as commands to copy or files to hand-edit.
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

Stage every manual step at the **fixed path `~/.ccrun`**, always overwritten,
always `chmod +x`. The path never changes, so after the first time they recall
it from history with `↑` instead of typing it.

Every staged script must:

1. Start with `#!/usr/bin/env bash` and `set -euo pipefail`.
2. **Log everything** — first real line is
   `exec > >(tee "$HOME/.ccrun.log") 2>&1`. You read that log yourself with
   your own tools; the user never pipes, selects, or pastes output.
3. **Default to a dry run.** Act only on an explicit `apply` argument:
   `[[ ${1:-} == apply ]] || DRY=1`. This mirrors `system-setup --dry-run`,
   which the user already thinks in.
4. **Verify inside the script**, before and after. Anything you would otherwise
   ask them to check by hand — a version, a file mode, an HTTP status, a
   container state — is a line in the script.
5. **End with a single machine-readable status line**, e.g.
   `echo "STATUS: ok — 3 changed, 0 failed"`, so the outcome is unambiguous
   even if the log is long.
6. Echo a short banner per step (`>>> step 2/4: …`) so a partial run is
   diagnosable from the log alone.

Then tell them **exactly one line**, on its own, nothing else to decide:

```
! ~/.ccrun
```

The `!` prefix runs it in the session and drops the output straight into the
conversation, so you see the result with no relaying. Follow up with
`! ~/.ccrun apply` once the dry run looks right.

## When the step needs sudo or is interactive

`!` cannot service a password prompt. In that case say plainly: *"run
`~/.ccrun apply` in another tmux window (`Ctrl-b c`), then just say done."*
You then read `~/.ccrun.log` yourself. They type one command and one word —
nothing is relayed by hand.

Optionally `Monitor` `~/.ccrun.log` for changes so you pick the result up
without even needing the "done".

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
