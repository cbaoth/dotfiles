---
title: Secret stores stay locked and silent after resume (keyring, KeePassXC)
hosts: [motoko]
status: workaround
tags: [keyring, keepassxc, secrets, suspend, dbus, sway, swayidle, apparmor, flatpak]
updated: 2026-10-07
---

# Secret stores stay locked and silent after resume

**Verdict: workaround.** `bin/lock-secrets` locks KeePassXC and every persistent
gnome-keyring collection on `before-sleep`, and nothing ever asks for them back.
`bin/unlock-secrets` is the missing counterpart, wired into the swayidle
`after-resume` hook.

No `setup/` module: two scripts in `bin/` plus a config fragment, all deployed by
`dotfiles-link`.

## The symptom

After a resume:

- VS Code remote (SSH) windows show "connection lost — reconnect / cancel /
  close" dialogs, and reconnect only works *after* KeePassXC is unlocked by hand,
  because this host's SSH keys come from KeePassXC's agent integration.
- gnome-keyring is locked too, but **never prompts**. It silently stays locked
  until some application happens to need a secret, which can be hours later.

Measured on 2026-10-01, well after a resume and after a manual KeePassXC unlock:

```
/org/freedesktop/secrets/collection/login             locked=true  label="Login"
/org/freedesktop/secrets/collection/Default_5fkeyring locked=true  label="Default keyring"
```

`ssh-add -l` listed two identities at the same moment — so KeePassXC *was*
unlocked and the keyring *was not*. They are two independent stores, and
unlocking one says nothing about the other.

## Who provides what

| Name on the session bus | Owner |
| ----------------------- | ----- |
| `org.freedesktop.secrets` | `gnome-keyring-daemon --components=pkcs11,ssh,secrets` |
| `org.keepassxc.KeePassXC.MainWindow` | KeePassXC (flatpak, via `xdg-dbus-proxy`) |

KeePassXC does **not** provide the Secret Service here; gnome-keyring does.

## Dead end: unlocking the keyring from bash

The obvious `busctl` approach cannot work. `org.freedesktop.Secret.Service.Unlock`
returns a *prompt object* that must then be displayed with
`org.freedesktop.Secret.Prompt.Prompt`:

```
$ busctl --user call org.freedesktop.secrets /org/freedesktop/secrets \
    org.freedesktop.Secret.Service Unlock ao 1 .../collection/login
aoo 0 "/org/freedesktop/secrets/prompt/u1"

$ busctl --user call org.freedesktop.secrets /org/freedesktop/secrets/prompt/u1 \
    org.freedesktop.Secret.Prompt Prompt s ""
Call failed: Object does not exist at path "/org/freedesktop/secrets/prompt/u1"
```

**The prompt's lifetime is bound to the D-Bus connection that requested it.**
The first `busctl` exits, its connection closes, gnome-keyring destroys the
prompt — so the second call can never find it. Two `busctl` invocations are
structurally incapable of this, no matter the ordering.

Hence the keyring step of `unlock-secrets` is Python: libsecret drives
Unlock → Prompt → wait in **one** process, and `Collection.get_locked()` gives a
real lock state so nothing has to be inferred. Needs `gir1.2-secret-1`
(installed).

## Dead end: asking KeePassXC whether it is locked

Its whole interface:

```
$ busctl --user introspect org.keepassxc.KeePassXC.MainWindow /keepassxc
.appExit              method  -    -
.closeAllDatabases    method  -    -
.isHardwareKeySupported method -   b
.lockAllDatabases     method  -    -
.openDatabase         method  s    -
.openDatabase         method  ss   -
.openDatabase         method  sss  -
.refreshHardwareKeys  method  -    b
```

There is **no lock-state property and no unlock method**. `openDatabase` would
raise the unlock dialog, but it needs a path — and `keepassxc.ini` on this host
records no last-database key (checked both the flatpak and the native config;
only `SearchInAllDatabases`, `LockDatabaseIdle`, `LockDatabaseIdleSeconds`).

So `unlock-secrets` does two inexact things, both documented in its `--help`:

- **Detection is a heuristic.** KeePassXC removes its agent keys when the
  database locks, so an `ssh-add -l` with no identities implies a locked
  database. True for this host's setup specifically; `-K` bypasses it.
- **The trigger is a re-launch.** The desktop entry sets `SingleMainWindow=true`,
  so a second `flatpak run org.keepassxc.KeePassXC` raises the existing instance,
  and a locked database shows its unlock form. This needs no database path.
  Raising is the same action whether locked or not — which is why the heuristic
  exists at all, to avoid a pointless window.

## Timing: the prompt must come after swaylock

`after-resume` fires while swaylock is still up. A prompt raised there sits
*behind* the lock screen where it cannot be answered. `unlock-secrets
--wait-for-unlock` polls for swaylock to exit first (default timeout 1h), and
`flock` keeps a second resume from stacking another waiting process.

Wired in `dotfiles/.config/sway/config.d/90-launch-apps.conf`:

```
after-resume '~/bin/conky-restart; ~/bin/sway-float-geometry restore; ~/bin/unlock-secrets --wait-for-unlock &'
```

Backgrounded with `&` on purpose — the waiter can block for a long time.

KeePassXC is handled before the keyring, so the SSH keys land in the agent as
early as possible and a VS Code reconnect succeeds on the first retry.

## The two keyrings, and why the password "did not work"

A first live test failed repeatedly with a password that was definitely correct
(confirmed independently against the account password via `sudo`). The cause was
not the password:

```
14:06:33  gcr-prompter: completed password prompt ... secret=88xN/...   <- answered
14:06:33  gcr-prompter: starting password prompt                        <- AGAIN
14:06:34  gcr-prompter: completed password prompt      (no secret=)     <- dismissed
          keyring: unlocked=0 still-locked: Login, Default keyring
```

`unlock_sync()` had been handed **both** collections at once, which produces two
back-to-back dialogs with nothing on screen to say which keyring each belongs
to. The correct password went to the wrong prompt. Unlocking one collection per
call fixed it immediately:

```
keyring: unlocked: Default keyring
```

### They are not interchangeable

```
~/.local/share/keyrings/
  default                   -> "Default_keyring"      (this is the default)
  login.keyring             328 bytes   2026-05-27     1 item
  Default_keyring.keyring   20763 bytes 2026-09-28    30 items
  bak/login.keyring         10805 bytes 2026-03-13    (pre-migration)
```

Secrets were migrated out of `login` into `Default keyring` around 2026-05-26.
What is left in `login` is a single item with an empty label and the attributes
`gkr:compat:hashed:keyring` + `xdg:schema` — a gnome-keyring **internal marker**,
not a user secret. Its password is not the account password.

`Default keyring` holds everything that matters, including the entries behind the
symptoms in this note:

```
Application key for code / com.visualstudio.code / vscode-test
copilot-cli/https
Chrome / Brave / Chromium Safe Storage, Nextcloud, GOA credentials, Claude, Signal
```

So `unlock-secrets` **skips collections with no user secrets** by default: it
reads each locked collection's item attributes (readable while locked, verified)
and skips any whose items are all `gkr:compat:*`. Otherwise every resume would
raise an unanswerable dialog for `login`. `-a` includes them anyway.

## Dead end: `exec 9>file 2>/dev/null`

The single-waiter guard was first written as:

```bash
exec 9>"${LOCK_FILE}" 2>/dev/null || true
```

`exec` **with no command** applies its redirections to the shell itself, so that
`2>/dev/null` silenced stderr for the entire rest of the run — every `p_warn`
and all `set -x` output vanished, which is how a filter bug stayed invisible for
several rounds. A failed `exec` redirection also exits a non-interactive shell
outright, so it must not be attempted blind either. Correct form: probe
writability with an ordinary command first (whose redirection is scoped), then
`exec`.

## Verified

Dry run distinguishes the stores and skips the useless keyring:

```
KeePassXC: agent has identities, assuming unlocked (use -K to override)
keyring: skipped Login: no user secrets (1 internal item(s))
keyring: nothing to unlock
```

Keyring unlock, one collection, correct password:

```
$ unlock-secrets -v --keyring-only -c Default_keyring
keyring: unlocked: Default keyring
  'Login'            locked=True
  'Default keyring'  locked=False
```

KeePassXC raise (`-K`, DB already unlocked — the trigger is the same either way):

```
before: (no window - hidden to tray)
KeePassXC: raised (flatpak) -- unlock prompt should be on screen
after:  id=268 app_id=org.keepassxc.KeePassXC name="AWe - KeePassXC" focused=true
```

The repeated `Gcr: couldn't find the callback for prompting operation ...` lines
in the journal are normal gcr noise on cancel, not an error worth chasing.

## Confirmed end to end

A real suspend (14:58 -> 20:13, ~5h15m), from
`~/.local/state/unlock-secrets.log`:

```
20:13:42 --- run: unlock-secrets --wait-for-unlock (pid 2845293)
20:13:42 wait: swaylock up, waiting up to 3600s
20:13:52 wait: unlocked after 10s
20:13:52 KeePassXC: raised (flatpak) -- unlock prompt should be on screen
20:14:23 keyring: skipped Login: no user secrets (1 internal item(s))
20:14:23 keyring: unlocked: Default keyring
```

Both prompts appeared, in order, *after* the screen unlock rather than behind it
— which is the whole point of `--wait-for-unlock`. The 31s gap is the password
entry. `Login` was skipped as intended.

## 2026-10-03: KeePassXC skipped, keys survived the lock

After the first resume of the day, every later one skipped KeePassXC:

```
11:29:34 KeePassXC: agent has identities, assuming unlocked (use -K to override)
11:56:24 KeePassXC: agent has identities, assuming unlocked (use -K to override)
```

The database *was* locked; the heuristic was wrong because the keys outlived the
lock. A live `busctl ... lockAllDatabases` (exit 0) left both identities in the
agent for 5s+, and minutes later SSH to saito and the vserver still worked.
Quitting KeePassXC removed them. A freshly started instance then added and
removed them correctly on every unlock/lock, across a real suspend too: the
per-entry settings ("add on unlock", "remove on lock") were never the problem.

The trigger was a **Nextcloud sync while the database was open**:

| Time | Event |
| ---- | ----- |
| 02:05 | `private.kdbx` changed on another device (motoko asleep) |
| 11:24:30 | first resume; stale local copy unlocked, keys added |
| 11:28:19 | Nextcloud downloads the new file; KeePassXC reloads the database |
| 11:28:57 | suspend; `lock-secrets` locks the database, keys stay |

KeePassXC remembers which database each added key came from and on lock removes
only the keys of the database being locked; on quit it removes all of them. A
reload swaps in a new database instance, so the old instance's keys match
nothing any more and stay in the agent until KeePassXC exits. (Inferred from
the behaviour, not from the source. Not reproduced on purpose yet: edit an
entry elsewhere while unlocked here, wait for the sync, lock, `ssh-add -L`.)

**Fix:** both swayidle lock hooks now run `lock-secrets --ssh`, which empties
the agent (`ssh-add -D`) after locking. That closes the security gap (keys
usable through a suspend with every store locked) and makes the
`unlock-secrets` heuristic true again. KeePassXC re-adds the keys on the next
unlock. `lock-secrets` now also logs to `~/.local/state/lock-secrets.log`;
before, nothing proved it had run at all.

## Open

- **swayidle must be restarted** for a changed hook to take effect: `swaymsg
  reload` does not re-run `exec` lines, so the running swayidle keeps the
  argument list it was started with. Verified twice the hard way — check with
  `tr '\0' '\n' < /proc/$(pgrep -x swayidle)/cmdline`.
- `--wait-for-unlock` assumes swaylock. Any other locker needs its process name
  added, or a switch to a logind `Unlock` signal — swaylock does not emit one,
  which is why polling is used.
- KeePassXC lock state remains a heuristic (SSH agent identities). It broke once
  already (see 2026-10-03), which is why the lock hooks now flush the agent. Any
  path that locks KeePassXC *without* `lock-secrets --ssh` (its own idle lock,
  a manual lock) can still leave keys behind after a reload; `-K` is the escape
  hatch.

## 2026-10-07: KeePassXC still unlocked after wake — stale AppArmor label

After a suspend the keyring asked for its password as usual, but the KeePassXC
database was already unlocked. `lock-secrets.log` has the first failure in five
nights:

```text
2026-10-06 22:05:02 WARN: KeePassXC: lockAllDatabases failed
2026-10-06 22:05:02 keyring: locked login            <- the other steps were fine
```

The script only says "failed". The kernel log says why:

```text
apparmor="DENIED" operation="dbus_method_call" bus="session" path="/keepassxc"
  interface="org.keepassxc.KeePassXC.MainWindow" member="lockAllDatabases"
  label="bwrap//&unpriv_bwrap" … info="No such file or directory"
apparmor="DENIED" operation="dbus_signal" bus="system" path="/org/freedesktop/login1"
  member="PrepareForSleep" label="bwrap//&unpriv_bwrap" …
```

**Cause (verified):** the flatpak KeePassXC (started Oct 3) and its
`xdg-dbus-proxy` still carry the label `bwrap//&unpriv_bwrap` from the
`bwrap-userns-restrict` profile. That profile was disabled on 10-06 for the
Claude sandbox experiment ([claude.md](../setup/claude.md)), which removed the
`unpriv_bwrap` child. The running processes kept a label that no longer exists,
and dbus-daemon cannot evaluate it: `busctl --user introspect
org.keepassxc.KeePassXC.MainWindow /keepassxc` fails with `Failed to query
AppArmor policy: No such file or directory`. So such a process can **receive
nothing over D-Bus** — not our `lockAllDatabases` call, and not logind's
`PrepareForSleep`, which is what KeePassXC's own lock-on-sleep listens to. Both
locks failed at once, which is why relying on KeePassXC's internal setting would
not have saved us.

Which processes: every flatpak started *before* the AppArmor change
(`cat /proc/<pid>/attr/current` shows `bwrap//&unpriv_bwrap (mixed)`); instances
started after it show `bwrap (unconfined)` and work. On 10-07: KeePassXC, a
Chromium flatpak, Trayscale and the Firefox native-messaging proxy.

**Fix:** quit and restart each affected flatpak. A new process gets the current
label. Verify with the `introspect` call above (read-only, locks nothing).

**Do not assume the rollback is harmless.** Changing the profile set under
running flatpaks is what broke this; applying `~/.ccrun-sandbox` (the rollback)
may do it again in the other direction. Restart all flatpak apps, or log out,
right after it, and re-check labels.

**Verified 2026-10-07** after restarting KeePassXC (and the other stale
flatpaks) and rolling the AppArmor change back: `lock-secrets -v` locks the
database, and a real suspend logged `KeePassXC: databases locked`.

`lock-secrets` now logs the `busctl` error text instead of a bare "failed", and
adds a "stale AppArmor label? restart the flatpak" hint when the error mentions
AppArmor.

**Fail closed (decided 2026-10-07):** `lock-secrets --fail-closed`, used on the
`before-sleep` hook only, stops KeePassXC (`flatpak kill`) when the lock cannot be
delivered, verifies it is gone, and leaves a marker in `$XDG_RUNTIME_DIR`.
`unlock-secrets` normally skips an app that is not running; with the marker it
starts KeePassXC again on resume. A stop that does not take is logged as an
ERROR, never as success. Accepted risk: `flatpak kill` is abrupt, so an entry
still open in its edit dialog is lost (saved changes are not — autosave, a backup
of the previous file, and Nextcloud file history). The idle-timeout hook stays
soft on purpose. Not covered: gnome-keyring, whose lock failure still only warns.
Caught by the stubbed test: the script sets `IFS=$'\t\n'`, so an unquoted
`${how}` command string is never split — use arrays there.

