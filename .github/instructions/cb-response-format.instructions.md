---
description: 'Response shape for a reader with limited executive-function bandwidth — conditions before steps, scannable lists, closing action checklist'
# applyTo: used by GitHub Copilot; Claude Code loads this unconditionally
# (no `paths` key) as an always-on rule via .claude/rules/ symlink
applyTo: '**'
---

# Response Format

The reader often starts acting on a reply while still reading it, and misses
details buried in long prose, even bold ones. Shape every reply to the human so
it works when acted on top to bottom, and can be recovered from its last
section alone.

Scope: replies to the human user. This does not apply to files you write,
commit messages, or reports returned to another agent.

## Order: no condition after the step it affects

- Prerequisites, warnings and "only if X" conditions go **before** the first
  step they affect, never after. A condition learned after running a command
  is a failure.
- If something must not be done yet (wait for X, check Y first), say so at the
  top.
- Settle the plan before writing steps. If a step turns out wrong, rewrite the
  step instead of appending a correction further down.

## Shape

- Lead with the answer or result. No preamble.
- Put critical facts in short bullets or numbered steps, not in paragraphs.
  Bold text inside a long paragraph is not enough.
- Number steps when order matters: one action per step, exact command or path
  in the step.
- Keep paragraphs to about 3 lines. Group long lists; at most about 5 items per
  group, most important first.
- Keep "what I did / found" separate from "what you need to do".
- Errors: state what failed and the evidence. Name a cause only when the
  evidence supports it; otherwise say it is unconfirmed and how to confirm it.
- Tangents: at most one line near the end, offered as a question, never mixed
  into the steps.

## Close with the reader's checklist

When the reader has anything to do, decide, or watch out for, end the reply
with a section headed `Your next steps`:

1. Steps in execution order, each with its condition inline ("first …",
   "only if …").
2. Self-contained: actionable without re-reading the text above. Repeat the
   exact command, path, or value.
3. Include every required step and every warning that changes what to do.
   Leave out nice-to-haves.
4. Decisions the reader must make go in this list as short questions.

This is the reader's to-do list, not a recap of your work, so it is not
covered by any "no closing recap" style guidance. When the reader has nothing
to do, omit the section rather than padding it.

<!-- Partly adapted from https://github.com/ayghri/i-have-adhd (MIT) -->
