---
title: Power management, sleep, and digital detox
hosts: [motoko]
status: workaround
tags: [power, sleep, systemd, pam, sudoers, logind]
updated: 2026-07-23
automated_by: setup/modules/50-power.sh
---

# Power management & sleep

**Mostly not automated, on purpose.** Most of this note touches `sudoers` and
`pam.d` — a script that edits those unattended can lock you out of your own
machine. A typo in `/etc/pam.d/common-account` means no login and no `sudo`.
Read, understand, apply by hand.

The one exception is the **power key policy** below: a logind drop-in is safe and
idempotent, so it *is* automated by
[`setup/modules/50-power.sh`](../../setup/modules/50-power.sh).

Hibernate itself does **not** work on motoko — see
[../troubleshooting/hibernate-nvidia.md](../troubleshooting/hibernate-nvidia.md).
What follows is the sleep/shutdown machinery that *is* in place.

## Power button suspends, it does not power off

**Automated:** [`setup/modules/50-power.sh`](../../setup/modules/50-power.sh)
(`system-setup 50-power`).

logind's default is `HandlePowerKey=poweroff` — a stray press kills the session
with everything open. Check what is actually in force (the shipped
`/etc/systemd/logind.conf` has every setting commented out, so grepping it tells
you nothing — ask logind itself):

```shell
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 \
  org.freedesktop.login1.Manager HandlePowerKey HandlePowerKeyLongPress
```

The module writes a drop-in — never an edit of the package-managed
`logind.conf` — at `/etc/systemd/logind.conf.d/50-power-key.conf`:

```ini
[Login]
HandlePowerKey=suspend
HandlePowerKeyLongPress=poweroff
```

**Keep the long-press line.** Its default is `ignore`, so without it there is no
way to force a hard power-off from the button on a machine too wedged to suspend.

Apply with `systemctl reload systemd-logind` — **reload, never restart**;
restarting `systemd-logind` tears down the session. Sway does not grab the power
key, so logind handles it.

## Every sleep path goes through logind — which is what makes locking work

Worth writing down, because it is the reason
[security.md](security.md#locking-secrets-on-screen-lock-and-suspend) works at
all: `swayidle -w`'s `before-sleep` hook fires on logind's `PrepareForSleep`
signal, which is emitted **no matter who initiates the sleep**. Confirmed paths:

| Trigger | Route |
| ------- | ----- |
| `suspend` typed in a shell | alias → `pm-suspend` → `systemctl suspend` ([`lib/aliases-linux.sh`](../../lib/aliases-linux.sh)) |
| `$mod+Escape` → `Shift+s` / `Shift+h` | `swaylock -f && systemctl suspend`/`hibernate` |
| Power button | logind `HandlePowerKey=suspend` (above) |
| Idle timeout | swayidle |

The `suspend` alias is a **compatibility shim, not pm-utils**: `pm-utils` is long
dead and not installed (`dpkg -l pm-utils` finds nothing). The chain is
`suspend` → `pm-suspend` → `systemctl suspend`, kept only so decades of muscle
memory keep working. This matters — a *real* `pm-suspend` would write to
`/sys/power/state` directly, bypass logind, never emit `PrepareForSleep`, and
silently skip both the screen lock and the secret lock.

Verify swayidle is actually registered before trusting any of this:

```shell
systemd-inhibit --list | grep swayidle
# swayidle  1000  cbaoth  ...  sleep  Swayidle is preventing sleep  delay
```

No `delay` inhibitor listed means the hooks will not run before sleep.

## Inhibitors

When the machine refuses to sleep or shut down, look here first:

```shell
systemd-inhibit --list
```

Usual suspects: update services, active network mounts, apps that deliberately
keep the system awake.

## Auto lazy-unmount on sleep

The most common inhibitor here is a CIFS/NTFS mount that will not unmount.
Rather than fight it, lazy-unmount everything of those types before sleep:

```shell
sudo mkdir -p /etc/systemd/system-sleep
sudo tee /etc/systemd/system-sleep/unmount-net.sh << 'EOF'
#!/bin/bash
case "$1" in
  pre)
    # Lazy-unmount all network/NTFS mounts before sleep
    awk '$3 ~ /^(cifs|ntfs|ntfs3|fuseblk)$/ {print $2}' /proc/mounts \
      | while read -r mountpoint; do
          umount -l "$mountpoint" 2>/dev/null || true
        done
    ;;
esac
EOF
sudo chmod +x /etc/systemd/system-sleep/unmount-net.sh
```

Test it without actually sleeping — mount something, then:

```shell
/etc/systemd/system-sleep/unmount-net.sh pre
```

The dynamic (filesystem-type-based) version above is preferred over hardcoding
mount points: it keeps working when you add a share.

## Digital detox — `pam_time`

Blocks authentication for the main user overnight. This is a *self*-imposed
constraint, so it is worth being clear-eyed: it prevents login and `sudo`, but
anyone with physical access and a rescue disk is unaffected. That is fine — the
point is friction, not security.

```shell
# /etc/security/time.conf — deny login between 21:00 and 06:00
*; *; <user>; !Al2100-0600
```

```shell
# /etc/pam.d/common-account — enforce the above
account    required   pam_time.so
```

### The escape hatch

With the above in force, you also cannot `sudo` — which means you cannot force a
shutdown when a service hangs or a mount will not release. Grant *only* the
power-state commands, passwordless, in a dedicated sudoers file:

```shell
sudo visudo -f /etc/sudoers.d/power-states
```

```
# Allow <user> to force system power states (systemctl --force --force).
#
# Regular users can use --force to ignore user-level inhibitors.
# Only root can use --force --force, which ignores everything (unstoppable
# service, unmountable filesystem).
#
# Prefer systemctl over poweroff(8)/halt(8) — systemd's implementation is
# cleaner and `halt` is a synonym for `poweroff` on many SysV systems anyway.

<user> ALL=(ALL) NOPASSWD: /usr/bin/systemctl sleep -ff
<user> ALL=(ALL) NOPASSWD: /usr/bin/systemctl suspend -ff
<user> ALL=(ALL) NOPASSWD: /usr/bin/systemctl hibernate -ff
<user> ALL=(ALL) NOPASSWD: /usr/bin/systemctl suspend-then-hibernate -ff
<user> ALL=(ALL) NOPASSWD: /usr/bin/systemctl hybrid-sleep -ff
<user> ALL=(ALL) NOPASSWD: /usr/bin/systemctl reboot -ff
<user> ALL=(ALL) NOPASSWD: /usr/bin/systemctl poweroff -ff
```

**Grant the narrowest set that actually works.** Every NOPASSWD line is a hole.

Consider `sudo chattr +i /etc/sudoers.d/power-states` to make it immutable
(remove with `-i` before editing) — this is a file whose whole purpose is to be
hard for a tired, motivated version of yourself to undo.

## Sleep state reference

| State | RAM | Disk | Power |
| ----- | --- | ---- | ----- |
| `suspend` | preserved | — | consumed |
| `hibernate` | — | swap | off |
| `hybrid-sleep` | preserved | swap | consumed |
| `suspend-then-hibernate` | suspend first, hibernate later (e.g. low battery) | | |

## See also

- [../troubleshooting/hibernate-nvidia.md](../troubleshooting/hibernate-nvidia.md)
- [unattended-upgrades.md](unattended-upgrades.md) — the other thing that fights shutdown
- [security.md](security.md#locking-secrets-on-screen-lock-and-suspend) — what
  `before-sleep` actually locks (KeePassXC, keyring, SSH agent)
