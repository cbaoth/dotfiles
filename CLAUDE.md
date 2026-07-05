@AGENTS.md

<!-- Shared agent instructions live in AGENTS.md (imported above, read natively
     by GitHub Copilot). Keep this file limited to Claude-Code-specific notes. -->

## Claude Code Specifics

- Path-scoped style rules load automatically via `.claude/rules/` (symlinks to
  `.github/instructions/cb-*.instructions.md`); run `/memory` to inspect what
  is loaded in the current session.
