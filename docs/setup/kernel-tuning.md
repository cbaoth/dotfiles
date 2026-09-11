---
title: Kernel tuning for containerised services
hosts: [11001001]
status: done
tags: [kernel, sysctl, redis, docker, memory]
updated: 2026-09-11
automated_by: setup/modules/55-sysctl.sh
---

# Kernel tuning for containerised services

Steady state: one `sysctl` drop-in, `/etc/sysctl.d/99-overcommit.conf`, setting
`vm.overcommit_memory = 1`. Automated by `setup/modules/55-sysctl.sh`
(profile: `server`).

## Why `vm.overcommit_memory = 1`

Redis writes its snapshot by forking. Under the default heuristic overcommit
(`0`) the kernel estimates whether the child could theoretically dirty every
page it inherits, and refuses the fork when the parent's RSS is large relative
to free memory. That estimate is wrong for this workload: the fork is
copy-on-write and touches only the pages that actually change, so a background
save can fail on a machine with plenty of memory free.

Redis says so itself, on every single start:

```
WARNING Memory overcommit must be enabled! Without it, a background save or
replication may fail under low memory condition. Being disabled, it can also
cause failures without low memory condition
```

`1` means always overcommit. This is the setting Redis upstream asks for, not a
local workaround.

## Scope: server profile only

Deliberately **not** applied to desktops. Always-overcommit trades an early,
localised allocation failure for a later OOM kill chosen by the kernel. On a
server running known, sized services that is the better trade; on a desktop with
unpredictable memory pressure it mostly makes the failure mode less predictable.
No desktop here runs a forking datastore, so there is nothing to buy.

## How it was found

The Redis container's log, read during a routine Nextcloud log review
(2026-09-11). It is a startup warning, not an error, and nothing had failed —
the box has enough headroom that no background save had yet been refused. It
would have stayed invisible until the first save failure under pressure.

Worth noting the general shape: warnings emitted once per container start are
easy to never see, because they scroll past during a restart nobody is watching.
Reviewing `docker logs` for the *whole* stack periodically, not just the service
you are debugging, is how these surface.

## Verifying

```bash
sysctl -n vm.overcommit_memory        # expect: 1
cat /etc/sysctl.d/99-overcommit.conf  # expect: the managed drop-in
```

The module checks both: the file content *and* the running value. A drop-in that
was written but never applied looks identical on disk, so checking only the file
would report success on a kernel that never picked it up.

## Related

- Nextcloud stack (which is what runs this Redis): `docs/setup/docker.md`
- Netdata, which monitors the same host: `docs/setup/monitoring.md`
