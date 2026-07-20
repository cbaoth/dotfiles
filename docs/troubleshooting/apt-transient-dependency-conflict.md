---
title: system-setup docker module failed on a containerd dependency conflict — the module was innocent
hosts: [11001001]
status: resolved
tags: [apt, docker, containerd, mirror, system-setup, ubuntu]
updated: 2026-07-19
---

# apt dependency conflict during `system-setup` — a mirror transient, not a bug

**Resolved by `sudo apt update` and retrying.** No code change was needed. This
note exists because the failure *looks* exactly like a broken setup module, and
re-auditing `setup/modules/30-docker.sh` is a waste of an evening.

## Symptom

During the vserver rebuild (Ubuntu 26.04, fresh install), `system-setup` failed
while installing Docker:

```
E: Unable to satisfy dependencies. Reached two conflicting assignments:
   1. containerd:amd64=2.2.2-0ubuntu1.1 is selected for install because:
      but none of the choices are installable:
```

It recurred across more than one `system-setup` invocation, which made it look
systematic rather than transient.

## Fix

```bash
sudo apt update
# re-run system-setup
```

After that the install completed and the packages resolved normally:

```
containerd         2.2.2-0ubuntu1.1
docker.io          29.1.3-0ubuntu4.1
docker-buildx      0.30.1-0ubuntu1
docker-compose-v2  2.40.3+ds1-0ubuntu1
```

## Why the module was not at fault

The obvious hypothesis — "the module installs packages without refreshing the
apt index" — is wrong. `setup/modules/00-apt-base.sh` already handles this, and
deliberately:

```bash
# A mirror switch must re-fetch regardless of cache age; otherwise package
# availability is judged against the old mirror's stale index.
if (( force_refresh )); then st::apt_update --force; else st::apt_update; fi
```

`force_refresh=1` is set whenever the regional-mirror rewrite actually changes
`sources.list`, and `00-` runs before `30-`. So the index *was* refreshed.

Most likely cause: the regional mirror was **mid-sync**, briefly serving a
`docker.io` / `containerd` version pair that could not resolve against each
other. A later `apt update` picked up a consistent set. Nothing on this side was
broken, and nothing could have prevented it.

**The repetition across runs is misleading** — each retry re-read the same
inconsistent index, so it reproduced faithfully until the mirror caught up.
Reproducibility looked like determinism; it was just a stale cache.

## What *was* a real bug (separate issue, fixed)

Found while investigating this, and easy to conflate with it:

`30-docker.sh` installed `docker.io docker-buildx` but **not**
`docker-compose-v2`. `docker.io` does not pull the compose plugin, so
`docker compose` silently does not exist — which presents as a broken Docker
rather than a missing package. Now installed explicitly by the module.

That one *was* worth code. This one was not.

## Rule of thumb

An apt dependency conflict on a **freshly installed** machine, against a
**recently switched** mirror, is a mirror-state problem until proven otherwise.
Try `apt update` and a retry **before** reading any code.
