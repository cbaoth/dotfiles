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

## Not covered

- Devcontainers and the docker shortcuts (`dps`, `dsh`, `dlog`, `dco`) —
  [devcontainer.md](devcontainer.md).
- Rootless docker — not currently used.
- Docker's own apt repo — Ubuntu's `docker.io` has been fine; if a newer engine
  is ever needed, the repo follows the pattern in [browsers.md](browsers.md).
