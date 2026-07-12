---
title: Power management, sleep, and digital detox
hosts: [motoko]
status: workaround
tags: [power, sleep, systemd, pam, sudoers]
updated: 2026-07-12
---

# Power management & sleep

**Not automated, on purpose.** This note touches `sudoers` and `pam.d` — a script
that edits those unattended can lock you out of your own machine. A typo in
`/etc/pam.d/common-account` means no login and no `sudo`. Read, understand, apply
by hand.

Hibernate itself does **not** work on motoko — see
[../troubleshooting/hibernate-nvidia.md](../troubleshooting/hibernate-nvidia.md).
What follows is the sleep/shutdown machinery that *is* in place.

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
