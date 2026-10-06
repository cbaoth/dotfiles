---
title: VS Code Remote-SSH windows show "cannot reconnect" after resume
hosts: [motoko]
status: open
revisit: 2026-10
tags: [vscode, ssh, suspend, keepassxc, nordvpn, sway]
updated: 2026-10-06
---

# VS Code Remote-SSH windows show "cannot reconnect" after resume

**Verdict: open, mostly fixed.** After a suspend, the remote windows (saito over
the LAN, the vserver over NordVPN) showed "Cannot reconnect. Please reload the
window." Three independent causes, two fixed, one under test.

Related: `docs/troubleshooting/secret-stores-locked-after-resume.md` (the SSH keys
come from KeePassXC, which is locked across suspend) and
`system-scripts/nordvpn-resume/` (the tunnel comes back with broken DNS).

## How VS Code reconnects (from the renderer and Remote-SSH logs)

VS Code *does* reconnect on its own: a reconnect loop with a backoff of
5, 5, 10, 10 ... 30s, per window. What ends it is the **error class**:

| Error | Treated as | Effect |
| ----- | ---------- | ------ |
| `Could not resolve hostname` | temporary | keeps retrying |
| `Permission denied (publickey)` | permanent | gives up after **one** attempt, dialog |
| `Unknown reconnection token (never seen)` | permanent | gives up, dialog |

So the DNS gap after resume is harmless on its own; auth failures and an
expired server session are not.

Logs: `~/.config/Code/logs/<session>/window<N>/renderer.log` (reconnect loop)
and `.../exthost/output_logging_*/1-Remote - SSH.log` (the ssh invocations).

## Cause 1: server session expired (fixed)

After a 37h suspend the vserver answered `Unknown reconnection token (never
seen)`: the VS Code server drops a disconnected session after its grace time,
**3h by default** (logged as `grace time: 10800000ms`). Nothing the client can do
once that happened.

Fix: `"remote.SSH.reconnectionGraceTime": 64800` (18h, covers a night) in the
VS Code `settings.json`. Takes effect when the server on the remote restarts
(a window reload or "Kill VS Code Server on Host"). Verified: `Client received
grace time from server: 64800000ms`. Cost: a disconnected window's extension
host, terminals and language servers stay alive that long on the remote.

## Cause 2: reconnect before the SSH keys are back (fixed)

VS Code reconnects within seconds of the resume, before the screen and KeePassXC
are unlocked. `lock-secrets --ssh` empties the agent before sleep, so the first
attempt fails with `publickey`, which is permanent. (The LAN window to saito hit
this; the vserver one usually didn't, because the DNS gap kept it retrying until
the keys were back.)

### Dead end: `remote.SSH.preconnect`

A script run "before attempting an SSH connection". It does run, but **only on a
window's first connection, never on reconnect attempts** (2026-10-03: one
"Running preconnect script" line at the reload, none for attempts 2-6). Useless
for this.

### Dead end: `remote.SSH.maxReconnectionAttempts`

Was lowered to 3 out of fear of fail2ban lockouts. Unfounded: an auth failure
already ends the loop after one attempt. Reset to the default (8).

### Fix: `bin/ssh-wait-agent` as a `Match exec` hook

Every reconnect attempt spawns a fresh `ssh`, so a hook *inside* ssh sees all
of them. In `~/.ssh/config` (machine-local, not in this repo), before the Host
blocks:

```
Match originalhost saito,saito-lan,sa,11001001.org,11001001,vserver,11,vs exec "~/bin/ssh-wait-agent -k SHA256:<hosts-key-fp> %n"
```

The block sets no options; it is only the hook. The script waits (up to 150s)
for that key in the agent, only for non-interactive ssh (a terminal `ssh saito`
fails fast instead of hanging). Log: `~/.local/state/ssh-wait-agent.log`.

VS Code kills an ssh that takes longer than `remote.SSH.connectTimeout + 2s`
(17s by default), so that is set to **180**.

Remote-SSH evaluates `Match exec` *itself* before spawning ssh, without
expanding tokens: those log lines show a literal `%n`.

## Cause 3: the key is listed but not usable yet (under test)

Twice the hook saw the key and the ssh started in the same second was still
rejected; saito's sshd logged `Connection closed by authenticating user cbaoth
[preauth]` with no failed key, and a reload 2-7s later was accepted.

- 2026-10-04: the hook waited for *any* key. Assumed a partial key list (the
  GitHub key first). Changed to wait for the hosts key specifically (`-k`).
- 2026-10-06: waited for the hosts key, `2 in agent`, still rejected within the
  second (10:28:54). So not (only) a partial list; the agent seems not to sign
  with a key in the first moment after KeePassXC adds it. Unverified guess.

Fix under test: after having waited, the hook settles 5s before returning
(free in the common case, where it returns instantly). To verify on the next
resume: leave any dialog alone for a minute after unlocking KeePassXC, then
check the log for `settling 5s` and the saito window for a dialog.

### Fallback if it still fails: remreload

The extension `viveksjain.remreload` reloads a remote window when its ssh
process exits, optionally after a connectivity command succeeds. Not used:
it reloads even windows VS Code would have reconnected (the vserver one does),
and it is a 9-commit, 0.1.0 extension running with full user rights. With
`checkConnectivityCommand` set to an `ssh ... exit` to the host it would also
run through the hook above.

## Where the settings live

| Setting | File | In a repo? |
| ------- | ---- | ---------- |
| `reconnectionGraceTime`, `connectTimeout` | `~/.config/Code/User/settings.json` | no; VS Code Settings Sync shares it between hosts |
| `Match exec` hook line | `~/.ssh/config` | no; machine-local (holds the key fingerprint) |
| `ssh-wait-agent` | `bin/` | yes |

The synced `settings.json` also carries Windows-only values
(`remote.SSH.path` = `plink-wrapper.bat`); on Linux each attempt logs
`spawn ... ENOENT` and falls back to plain `ssh`. Harmless noise.
