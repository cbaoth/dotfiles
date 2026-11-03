---
title: Docker
hosts: [motoko, saito, wsl-work]
status: resolved
tags: [docker, containers]
updated: 2026-07-12
automated_by: setup/modules/30-docker.sh
---

# Docker

**Automated:** `system-setup 30-docker`

Ubuntu's `docker.io` + `docker-buildx`, plus adding the user to the `docker`
group.

## The group is root

Membership in `docker` is effectively root on the host — the daemon runs as root
and will happily bind-mount `/` into a container for you. This is a deliberate
trade, not an oversight. On `wsl-work` it only applies inside the WSL VM.

**Licensing:** Docker Engine (`docker.io`) is Apache-2.0 and free for business
use. Only *Docker Desktop* needs a paid subscription at larger companies, and
nothing here installs it. The plain `wsl` profile does not run this module (it
was excluded on the mistaken assumption that Docker Desktop owns WSL).

**WSL needs systemd** for `dockerd` to start: `[boot] systemd=true` in
`/etc/wsl.conf`, then `wsl --shutdown` from Windows. The module warns if it is
missing. Ports published by containers are reachable from Windows via
`localhost` (WSL2 localhost forwarding).

**Podman** is the alternative (Apache-2.0, rootless, `podman-docker` provides a
`docker` shim). Not used: Docker works with Testcontainers, devcontainers and
`docker compose` out of the box, while Podman needs `podman.socket` plus
`DOCKER_HOST` for those, and rootless networking differs. Switch if the company
standardises on it.

Group changes need a fresh login to take effect. `newgrp docker` works for the
current shell if you cannot log out.

## An engine from Docker's own repo already exists

If `docker-ce` is installed (Docker's apt repo), the module leaves the engine
alone, and skips Ubuntu's `docker-buildx` / `docker-compose-v2` when Docker's
`docker-buildx-plugin` / `docker-compose-plugin` are present. Installing
`docker.io` over them makes apt remove `docker-ce` and `containerd.io`, and the
plugin packages then fail with "trying to overwrite ... docker-buildx" half-way
through dpkg, leaving `docker.io` unpacked but unconfigured (seen on the work WSL,
2026-11). Recovery from that state; images and volumes in `/var/lib/docker` are
not touched by any of these steps.

```bash
sudo dpkg --configure -a     # finish docker.io, containerd, runc
system-setup 30-docker       # now reports 0 changes
```

The leftover Docker plugins keep working but get no updates once their repo is
gone. To move to Ubuntu's packages, first `sudo apt-get remove
docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras`, then
re-run the module.

## Not covered

- Devcontainers and the docker shortcuts (`dps`, `dsh`, `dlog`, `dco`) —
  [devcontainer.md](devcontainer.md).
- Rootless docker — not currently used.
- Docker's own apt repo. Ubuntu's `docker.io` is the choice on every profile,
  personal and work alike: it needs no third-party repo, follows the release
  (the repo is codename-pinned and is disabled by every release upgrade, which
  is how the work WSL ended up with orphaned `*-plugin` packages), and lags
  Docker's own builds by only a few minor versions. If a newer engine is ever
  needed, the repo follows the pattern in [browsers.md](browsers.md).
