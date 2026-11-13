# VS Code extension lists

One directory per host, one `<profile>.list` per VS Code profile, written by
`vscode-profiles export`. Each line is `id<TAB>enabled|disabled<TAB>scope`:

| scope     | meaning                                                         |
| --------- | --------------------------------------------------------------- |
| `app`     | flagged "Apply Extension to all Profiles" (in every profile)    |
| `own`     | installed in this profile only                                  |
| `own+app` | flagged *and* a redundant own copy (`vscode-profiles dedupe`)   |

No versions, so extension updates do not show up as changes.

Only hosts whose extension lists may be public go here. Work machines do
not: compare there without committing anything.

```bash
vscode-profiles diff                                  # live vs. this host's lists
vscode-profiles diff live ~/dotfiles/setup/vscode/motoko   # e.g. at work vs. home
vscode-profiles export                                # refresh after a cleanup
```

The full config history (settings, keybindings, snippets, extension lists
every hour) lives in the private notes repo, written by
`vscode-config-snapshot`; this directory is the shareable subset.

Why this exists, and how the "Apply Extension to all Profiles" flag really
behaves: `docs/troubleshooting/vscode-extensions-resurrected.md`.
