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

## Verified

Dry run correctly distinguished the two stores:

```
KeePassXC: agent has identities, assuming unlocked (use -K to override)
keyring: would unlock -- 2 locked: Login, Default keyring
```

A live run raised a real dialog and reported the outcome honestly
(journal, prompt deliberately cancelled):

```
13:53:27 gcr-prompter: Gcr: starting password prompt for callback .../p28
13:53:39 gcr-prompter: Gcr: completed password prompt
         keyring: unlocked=0 still-locked: Login, Default keyring
```

The repeated `Gcr: couldn't find the callback for prompting operation ...` lines
are normal gcr noise on cancel, not an error worth chasing.

## Open

- The success path (actually entering the password) is still unconfirmed; the
  test above was cancelled on purpose.
- `--wait-for-unlock` assumes swaylock. Any other locker would need its process
  name added, or a switch to a logind `Unlock` signal — swaylock does not emit
  one, which is why polling is used.
