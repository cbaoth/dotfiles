---
title: VS Code extensions reappear and re-enable after cleanup (profiles + Settings Sync)
hosts: [motoko]
status: workaround
revisit: when puppet is back online
tags: [vscode, settings-sync, profiles, extensions]
updated: 2026-11-13
---

# VS Code extensions reappear and re-enable after cleanup

**Cleaned up on 2026-11-10 with `vscode-profiles rebuild-default`; one
bulk re-enable was traced to Settings Sync, the machine that pushed it is
not identified.** The guards below should catch a repeat within an hour.

## Symptom

After a thorough cleanup (new profiles, unused extensions disabled or
uninstalled), extensions kept coming back: some reinstalled, many disabled
ones enabled again, mostly in the Default profile. Every profile had grown to
~155–165 installed extensions and differed only in what it disabled.

## How VS Code actually stores this

Verified on VS Code 1.145 by reading the files (not public API):

| What | Where |
| ---- | ----- |
| Extension code | once, in `~/.vscode/extensions/` (shared by all profiles) |
| Installed in Default | `~/.vscode/extensions/extensions.json` |
| Installed in a profile | `~/.config/Code/User/profiles/<id>/extensions.json` |
| "Apply Extension to all Profiles" | `isApplicationScoped` in **Default's** manifest only |
| Disabled extensions | per profile: `.../globalStorage/state.vscdb`, key `extensionsIdentifiers/disabled` |
| Profile names, `useDefaultFlags` | `~/.config/Code/User/globalStorage/storage.json` |

What that means in practice:

- **The flag shares installation, not state.** A flagged extension shows up in
  every profile, but enabled/disabled is still per profile. Disabling it in
  Default does not disable it anywhere else, and flagging it does not enable
  it in Default either (bit me with Pylance on 2026-11-10).
- **Uninstall is per profile**, except for flagged extensions: uninstalling a
  flagged one in Default removes it everywhere, including profiles' own copies.
  The UI's *Uninstall (All Profiles)* is the way to remove anything
  everywhere.
- **Flagged and also installed per profile** is possible and was the norm
  here: 72 flagged extensions, nearly all also in every profile's own manifest
  (left over from creating profiles by copying). The flag then did nothing;
  unflagging would not have removed anything.
- A profile with `useDefaultFlags.extensions` (the built-in *Agents*) has no
  extensions of its own; it uses Default's.
- The `code` CLI cannot disable an extension persistently (`--disable-extension`
  lasts one launch), and profile import always creates a *new* profile.

## Findings

### 2026-10-16 — one extension: a dependency install, not sync

`ms-vscode.azure-repos` appeared in Default only, unflagged. It is an
`extensionDependencies` entry of `ms-vscode.remote-repositories` (flagged, and
itself pulled in by `github.remotehub`). VS Code installs missing dependencies
on install/update of the parent, so removing the dependency alone never
sticks. Removed all three on 2026-11-06; nothing else depended on them.

### 2026-10-26 15:17 — bulk re-enable by Settings Sync

`~/.config/Code/logs/20261026T151730/userDataSync.log`: in the first sync of
that session, within one second, **23 extensions were enabled** in Default and
4 installed (`continue`, `kubernetes-tools`, `azureresourcegroups`,
`gitblame`), plus changes in the other profiles. The hourly
`vscode-config-snapshot` commit `a7b821b` in `~/notes` (10-26 15:24) shows the
same: 23 IDs left Default's disabled list.

That is a three-way merge treating another machine's older state as the newer
change. Which machine is **not confirmed**:

- Servers and Remote-SSH hosts do not sync (their extensions live in
  `~/.vscode-server` on the remote).
- The work machine uses only the work profile and another account.
- **Candidates:** puppet (offline since, battery), or an old vscode.dev
  session (e.g. on the tablet). vscode.dev runs the same Settings Sync in both
  directions.

### Ruled out

- **GitHub and Microsoft sync mixing:** one provider per machine
  (`userDataSyncAccountProvider` = `microsoft` here), and sync data is stored per
  account, so two accounts cannot merge into each other.
- **Remote-SSH sessions:** see above.

## Fix applied

1. `vscode-profiles rebuild-default --apply` (2026-11-10, VS Code closed):
   - *keep* = everything any non-Default profile enables, plus hard
     dependencies; everything else (53 extensions) uninstalled everywhere;
   - *common* = enabled in **all** of them → flagged and enabled in Default,
     profiles' own copies dropped;
   - the rest only as own copy in the profiles that enable it, disabled in
     Default; no disabled entries left in the profiles.
   Result: 59 common, 59 situational, 118 installed (was 171).
2. Sync uploaded the result for Default and all six profiles on restart; a
   second dry run planned no changes.
3. Turned Settings Sync off for every machine in *Synced Machines*, then on
   again on motoko. Machines that come back (puppet, a stale vscode.dev) have
   to opt in again, and should pick **replace local**.

Not done: clearing the cloud data. At 2026-11-10 20:27 the cloud copy of
Default still carried five extensions motoko only skips
(`warzone762.vscode-geckscript`, `haaaad.ansible`, `vscoss.vscode-ansible`,
`denis-net.vscode-ahk-manager`, `stkb.rewrap`). A machine that merges could
install them.

## Guards now in place

- **`vscode-config-snapshot`** (hourly user timer, history in
  `~/notes/systems/<host>/vscode`) exits 1 → ntfy alert when one run changes
  the enabled set of a profile by 10 or more. It fires after your own big
  cleanups too (it did on 2026-11-10, 67 changes).
- **`vscode-profiles diff`** compares live state with
  `setup/vscode/<host>/*.list` (committed after every deliberate change). Run
  it right after another machine rejoins sync.

## Gotchas found on the way

- `code --uninstall-extension X` on a flagged X removes it from **every**
  profile. `vscode-profiles` therefore edits manifests directly instead of
  using the CLI.
- Edits to `extensions.json` / `state.vscdb` only stick with **VS Code fully
  closed**: it keeps the state in memory and writes it back on exit. A Claude
  Code session inside VS Code cannot run `--apply`; use a terminal outside it.
- After manifest-only removal, VS Code deletes the unreferenced extension
  folders on its next start.
- "Too many requests. Only 100 requests allowed in 5 minutes", then *Settings
  sync is suspended temporarily*: cleared at once after disconnecting the VPN.
  Unconfirmed cause: the sync service counts requests per shared exit address.

## If it happens again

1. Check the alert's journal: `journalctl --user -u vscode-config-snapshot -n 20`.
2. `git -C ~/notes log -p -- systems/motoko/vscode` around that time: what
   changed, in which profile.
3. `grep -E 'Enabled|Disabled|Installed|Uninstalled' ~/.config/Code/logs/*/userDataSync.log`
   for the exact second, then *Settings Sync: Show Synced Data* → *Synced
   Machines* / *Remote Activity* to name the machine.
4. Restore with `vscode-profiles apply`/`purge`, or from the backups under
   `~/.local/state/vscode-profiles/backups/` (`SOURCES.tsv` maps each file
   back), then clear the cloud data before re-enabling sync elsewhere.

Tools: `bin/vscode-profiles`, `bin/vscode-config-snapshot`,
`setup/vscode/README.md`.
