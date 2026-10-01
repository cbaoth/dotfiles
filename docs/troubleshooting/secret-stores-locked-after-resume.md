---
title: Secret stores stay locked and silent after resume (keyring, KeePassXC)
hosts: [motoko]
status: workaround
tags: [keyring, keepassxc, secrets, suspend, dbus, sway, swayidle]
updated: 2026-10-01
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

## Open

- End-to-end over a real suspend is still unconfirmed. Note that **swayidle must
  be restarted** for a changed hook to take effect: `swaymsg reload` does not
  re-run `exec` lines, so the running swayidle keeps the argument list it was
  started with.
- `--wait-for-unlock` assumes swaylock. Any other locker needs its process name
  added, or a switch to a logind `Unlock` signal — swaylock does not emit one,
  which is why polling is used.
- KeePassXC lock state remains a heuristic (SSH agent identities). If the agent
  ever holds keys from another source, the heuristic silently stops being right;
  `-K` is the escape hatch.
