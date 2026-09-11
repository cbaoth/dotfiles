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
2. **Log everything, appending** — first real lines are

   ```bash
   exec > >(tee -a "$HOME/.ccrun.log") 2>&1
   printf '\n===== %s  %s =====\n' "$(date -Is)" "${*:-<no args>}"
   ```

   You read that log yourself with your own tools; the user never pipes,
   selects, or pastes output. **Append, never overwrite** — the user may run a
   script several times (dry-run, then apply, then a retry), and each run is
   evidence. A `tee` without `-a` throws away every run but the last, which has
   already cost one debugging cycle.
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

Neither your own Bash tool nor the `!` prefix has a tty — both verified. `!`
reports `not a tty` and sudo there fails with *"interactive authentication is
required"*. That is sudo's own error, not a permission block: `!` is not gated
by the allow/deny rules at all, it simply has no terminal to prompt on, and no
setting can change that. **Never route a privileged step through either.**

A tmux window *does*, including one you create yourself, and creating it
detached neither steals focus nor leaves clutter (verified: it gets a real
pty and closes on completion). So launch the work rather than dictating it,
keeping the `tmux` argument a bare invocation of the script:

```bash
tmux new-window -d -n ccrun '~/.ccrun apply'
```

Everything interactive belongs *inside* the script, where the `tee` logs it and
you can read it back afterwards — not inline in a one-shot tmux argument, where
it is invisible to you and unversioned.

**Pause in the script, immediately before the first command that prompts.**
`new-window -d` starts the script at once, while the user is still in the other
window — with no pause, the sudo prompt is racing their window switch and times
out before they arrive:

```bash
echo
echo "  --- this step needs your sudo password ---"
read -r -p "  switch here, then press Enter to continue: " _
sudo …
```

**Trap EXIT so the window never closes on an unread result.** Without it the
window vanishes the moment the script ends — the user cannot tell success from
failure, and `tee` is killed before flushing, so the `STATUS:` line is lost from
the log too (observed: an apply run whose summary reached neither the screen nor
the log):

```bash
finish() {
  local rc=$?
  echo
  (( rc == 0 )) && echo "EXIT: 0 (ok)" || echo "EXIT: $rc (FAILED)"
  sleep 0.3
  { read -rsn1 -p "--- press any key to close ---" _ </dev/tty; } 2>/dev/null || true
  echo
  sleep 0.2
}
trap finish EXIT
```

The `</dev/tty` redirect makes the pause a no-op when there is no terminal, so
the same script still runs unattended under `!`.

Then tell the user only: *"`Ctrl-b n`, press Enter, type your password,
`Ctrl-b p` back."* A password and two chords, with no command to type and
nothing to relay. You read `~/.ccrun.log` yourself afterwards.

If several privileged steps are needed, have the script run `sudo -v` right
after that `read` so the credential is cached for the rest of the run — note
the cache is normally per-tty (`tty_tickets`), so the caching and the work must
happen in that same window, which this flow does naturally.

If tmux is not available, fall back to: *"run `~/.ccrun apply` in another
window, then just say done."*

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
