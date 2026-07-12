---
title: Docker
hosts: [motoko, saito]
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
trade, not an oversight, and it is why this module is **not** in the `wsl`
profile: Docker Desktop owns that environment.

Group changes need a fresh login to take effect. `newgrp docker` works for the
current shell if you cannot log out.

## Not covered

- Rootless docker — not currently used.
- Docker's own apt repo — Ubuntu's `docker.io` has been fine; if a newer engine
  is ever needed, the repo follows the pattern in [browsers.md](browsers.md).
