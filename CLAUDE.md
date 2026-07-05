@AGENTS.md

<!-- Shared agent instructions live in AGENTS.md (imported above, read natively
     by GitHub Copilot). Keep this file limited to Claude-Code-specific notes. -->

## Claude Code Specifics

- Path-scoped style rules load automatically from the user-level
  `~/.claude/rules/` (symlinks into this repo's `.github/instructions/`,
  deployed by `dotfiles-link`); run `/memory` to inspect what is loaded in the
  current session.
