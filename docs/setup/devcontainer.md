---
title: Devcontainers (dotfiles, cb-voice-lab, web-tools)
hosts: [motoko, saito]
status: open
tags: [docker, devcontainer, vscode, system-setup, claude]
updated: 2026-11-07
automated_by: .devcontainer/Dockerfile
---

# Devcontainers

**Automated:** `.devcontainer/` in each repo; the environment itself is
`system-setup --profile container`. web-tools-container is ported
(2026-11-01, motoko; saito not yet); med-plan-assistant is ported
(2026-11-07, motoko; Node 26 pinned via `.nvmrc`, `npm ci` in
`postCreateCommand`); cb-voice-lab is not, hence `status: open`.

Quick start (any repo with a `.devcontainer/`):

```bash
dcup  ~/dotfiles     # build if needed, start (devcontainer up)
dcsh  ~/dotfiles     # zsh -l inside
dcre  ~/dotfiles     # rebuild: replace the container, volumes kept
dcode ~/dotfiles     # VS Code window in the container, NEW window
```

The `dc*` shortcuts wrap the `devcontainer` CLI (`@devcontainers/cli`, an npm
global installed by `22-fnm` from `setup/packages/npm-global.list`). Plain
docker: `dps`, `dsh NAME`, `dlog NAME`, `dco` (= `docker compose`). All in
*DOCKER / DEVCONTAINER* in `home/.aliases`.

## The pattern: Dockerfile bootstraps, system-setup builds

The Dockerfile only creates the user context; `system-setup --profile
container` installs everything else. A container therefore gets what the hosts
get, from the same lists, and the dotfiles container doubles as a clean box
for testing `setup/` and `tools/link.sh`.

Profile `container` runs `00-apt-base` (with `packages/container.list`),
`10-locale`, `22-fnm`, `28-claude-code`, `31-github-copilot`, `34-uv` and
`56-sshd` (no-op without openssh-server). `--profile auto` detects a container
via `/.dockerenv` / `/run/.containerenv` (`st::is_container`).

The dotfiles image (`.devcontainer/Dockerfile`):

1. **System layer:** COPY only `bin/system-setup` + `setup/`, run
   `system-setup --yes --profile container`, then `apt-get clean` and
   `rm -rf /var/lib/apt/lists/*` in the same layer. This layer is rebuilt only
   when `setup/` changes or `CACHE_BUST` gets a new value.
2. **Dotfiles layer:** COPY the whole working tree (build context = repo
   root, minus `.dockerignore`), `tools/link.sh`, zinit bootstrap. This is
   cheap to rebuild on every dotfile edit.

The image is built from the **working tree**, so uncommitted changes can be
tested before pushing. `.dockerignore` keeps `_local/`, `*.local*`, `.env*`
out of the image, except `.link-profile.local`: the container uses the **same
link profile as the host clone** (`full`, `work`, ...), because `link.sh`
cannot ask for one during a build. If the host clone has none, the build stops
with a message; run `./tools/link.sh` on the host once (or
`echo full > .link-profile.local`) and rebuild.

`postCreateCommand` re-runs `link.sh` (see the Claude volume below) and then
`system-setup --dry-run --profile container`. A healthy image reports
`0 changed`: the idempotency contract, checked on a fresh box.

Gotchas this ran into:

- **Emptied apt lists looked fresh.** `rm -rf /var/lib/apt/lists/*` updates
  the directory's mtime, so `st::apt_update` judged the cache fresh, skipped
  `apt-get update`, and every package was "not available in apt, skipped".
  That is only a warning, so the run looked successful.
  `st::apt_update` now treats "no `*_Packages` index" as stale.
- **Appending to `~/.zshrc` in the Dockerfile** writes through the
  `link.sh` symlink into the tracked file. Use the container slot below.
- **`postCreateCommand` runs under `/bin/sh`**, which never runs `fnm env`,
  so `node` is not on PATH there. Wrap commands in `zsh -lc '…'`.

## Base image

`mcr.microsoft.com/devcontainers/base:ubuntu26.04`, pinned to the release
(not the floating `:ubuntu`).

- `system-setup` is apt/Ubuntu-specific (deb822 mirror rewrite, Ubuntu
  package names). Alpine or Debian-slim would test something else.
- It ships the `vscode` user (uid 1000, mapped to the host uid by the CLI),
  sudo, git and zsh. That is everything the bootstrap needs.
- Size barely matters. Once layers are cached, a container starts in about a
  second; the build cost is the `system-setup` layer, whatever the base.
- Same LTS as the servers (saito, vserver). Desktops run the interim
  release.

Later option: test the interim release (26.10) in a container. Microsoft
publishes no interim tags, so that needs plain `ubuntu:26.10` and a self-made
user. Ubuntu images since 24.04 already have an `ubuntu` user at uid 1000, so
rename or remove it first. Not built until it is needed.

## Shell customisation inside containers

- **Tracked, all containers:** `source_ifex_custom` (`home/.common_rc`) also
  loads `PREFIX-container{EXT}` when `IS_DOCKER=true`, between the OS and the
  host files. Use `lib/env-container.sh`, `lib/aliases-container.sh`,
  `home/.zsh.d/zshrc-container.zsh`, `home/.zsh.d/aliases-container.zsh`.
- **Per project:** `containerEnv` in that repo's `devcontainer.json`.
- **Untracked, per machine:** `~/.aliases.local` (sourced at the end of
  `home/.aliases`).

This replaced the old `/workspace/local/*.local` hooks, which never fired:
`/workspace` is the bind-mounted repo, so the files sat at
`/workspace/.devcontainer/root/workspace/local/`. The hooks also looked for
`*.extras`, while the templates were named `*.local`.

### Telling a container shell apart

Several markers, so a glance is enough even among floating terminals:

- **Hostname = short project name**, set by `"runArgs":
  ["--hostname=<name>"]` in `devcontainer.json` (docker's default is the
  container id). It shows in the prompt and in tmux. Pick a short, unique
  name (`web-tools`, not `web-tools-container`).
- **Starship:** the first segment turns green (palette `container`) and shows
  the user, a docker whale (nf-linux-docker) and the hostname. Same
  mechanism as the amber ssh variant: `~/.zshrc` exports
  `CB_PROMPT_CONTAINER` and generates
  `~/.cache/starship/container.toml`. The built-in `container` module was not
  used: for docker it only shows "Docker", not the name.
- **Username:** shown whenever the user is not `cbaoth` (`CB_PROMPT_USER`;
  WSL exempt, the work login differs), so `vscode` always shows.
- **tmux:** `lib/env-container.sh` sets `CB_TMUX_AUTOATTACH=1`, so `dcsh`
  and `dsh` land in a fresh tmux session. Containers have no TPM, so tmux
  keeps its stock green status bar, with the hostname on the right. Skipped
  in VS Code terminals, and when the host shell is already in tmux or VS Code
  (`dcsh`/`dsh` pass `CB_TMUX_SKIP=1`), so tmux is never nested.

`dcsh` also passes `SHLVL=0`: the devcontainer CLI injects the environment of
its own probe shell, including `SHLVL=1`, which made every `dcsh` shell look
nested to the tmux hook. Root in the container has no dotfiles yet, so its
prompt is the stock bash one.

## Host and container side by side (VS Code)

VS Code allows one window per folder. "Reopen in Container" (and its prompt)
turns the **current** host window into the container window. If the
container is broken, that window is stuck: no host editing, and the chat
session running in it is gone.

1. **Iterate with the CLI.** Use `dcup`/`dcre` to build, read the errors in
   the terminal, and `dcsh` to poke around. The host window and its Claude
   session are never touched.
2. **Never click "Reopen in Container" in the host window.** Answer the
   prompt with *Don't Show Again* per workspace. Dev Containers 0.469 has no
   global setting for that prompt.
3. **For a VS Code window in the container, open a second window:**
   - `dcode DIR`: `code --new-window --folder-uri
     vscode-remote://dev-container+<hex of host path>/workspace`. Covers the
     default config location (`.devcontainer/devcontainer.json`);
   - command palette: *Dev Containers: Open in Container in New Window*;
   - after `dcup`: *Dev Containers: Attach to Running Container…*.
4. **A broken container window can just be closed.** The host window keeps
   editing files and chatting; fix, `dcre`, try again.

The two windows are separate VS Code sessions, so Claude Code in the
container window is a separate Claude session as well. Its login persists in
the volume below.

## Mounts: what goes where

There is no standard for a user-facing exchange dir. The common split is:

| What | How | Here |
| --- | --- | --- |
| The code | workspace bind mount | repo → `/workspace` |
| Tool state that must survive rebuilds | named volume | `claude-config-${devcontainerId}` → `~/.claude` |
| Caches worth sharing with the host | bind mount of the host cache | e.g. `~/.cache/huggingface` (cb-voice-lab) |
| Data you want on the host | bind mount | `~/container/<name>` → `/home/vscode/share` |

- **Claude Code** in a container: the named volume plus
  `containerEnv.CLAUDE_CONFIG_DIR=/home/vscode/.claude` keeps the login and
  history across rebuilds. It stays separate from the host's `~/.claude`, so
  the container is still a sandbox. Docker seeds a new volume from the image
  (the `link.sh` symlinks), and `postCreateCommand` re-runs `link.sh` so
  later dotfile changes reach it.
- **`~/container/<name>`** stays as the host-side layout. On saito, if a
  share should live on the bulk storage (web-tools downloads), make
  `~/container/<name>` a symlink there. No repo change is needed, and the
  path in muscle memory stays the same.
- **uv in containers:** a host cache bind mount puts the cache on another
  filesystem than `.venv`, so uv cannot hardlink and warns. Set
  `UV_LINK_MODE=copy` in `containerEnv` when doing that.

## On saito (no VS Code)

Docker comes from `30-docker`, the devcontainer CLI from `22-fnm` (server
profile). From a tmux session over SSH (phone, puppet):

```bash
dcup ~/git/web-tools-container
dcsh ~/git/web-tools-container    # zsh in the container
```

`devcontainer up` keeps the container running (it overrides the command with
a sleep), so it survives the SSH session. Alternatives:

- VS Code Remote-SSH to saito, then *Open in Container in New Window*;
- a compose service with `command: sleep infinity` plus `dsh NAME`.
  web-tools-container ships one: `docker compose up -d --build`, then
  `dsh web-tools`.

## Porting another repo

Other repos cannot COPY the dotfiles, so they clone them. Reference
Dockerfile:

```dockerfile
FROM mcr.microsoft.com/devcontainers/base:ubuntu26.04
ARG USERNAME=vscode
ENV DEBIAN_FRONTEND=noninteractive

RUN mkdir -p /workspace && chown ${USERNAME}:${USERNAME} /workspace \
    && chsh -s "$(command -v zsh)" ${USERNAME} \
    && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

USER ${USERNAME}
WORKDIR /home/${USERNAME}

# New value = fresh dotfiles clone + system-setup re-run
ARG CACHE_BUST=0
# Project extras: explicit modules (they override the profile filter) and
# project-only apt packages, in the same layer while the apt lists exist.
RUN git clone --depth 1 https://github.com/cbaoth/dotfiles "$HOME/dotfiles" \
    && "$HOME/dotfiles/bin/system-setup" --yes --profile container \
    && "$HOME/dotfiles/bin/system-setup" --yes 24-yt-dlp \
    && sudo apt-get install -y --no-install-recommends ffmpeg \
    && sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/*
ENV LANG=en_US.UTF-8

# The host clone's link profile (full, wsl, ...), copied by initializeCommand
COPY --chown=${USERNAME}:${USERNAME} link-profile /home/${USERNAME}/dotfiles/.link-profile.local
RUN "$HOME/dotfiles/tools/link.sh" && ZINIT_TURBO=false zsh -ic true
```

**The link profile is mandatory.** `link.sh` cannot ask for one during a
build, and a fresh `git clone` has none. Do not hardcode `--profile full`:
the container must link what its host links (`wsl` on the work machines). So
`initializeCommand` copies the host clone's profile into the build context,
the Dockerfile COPYs it in (the build fails early when it is missing), and
`.devcontainer/link-profile` goes into the repo's `.gitignore`:

```jsonc
"initializeCommand": "cp \"$HOME/dotfiles/.link-profile.local\" .devcontainer/link-profile && mkdir -p \"$HOME/container/<name>\""
```

This assumes the host clone is at `~/dotfiles`. The failure is easy to miss on
a host with an old cached image (the clone predates the mandatory profile,
2026-11-03) and shows up on the first fresh build elsewhere.

`devcontainer.json`: `"build": {"dockerfile": "Dockerfile", "args":
{"CACHE_BUST": "${localEnv:CACHE_BUST}"}}`, `remoteUser: vscode`, workspace
at `/workspace`, `"runArgs": ["--hostname=<short-name>"]` (see *Telling a
container shell apart*), the Claude volume and `CLAUDE_CONFIG_DIR` as in this
repo,
and `postCreateCommand: "zsh -lc 'uv sync'"` for Python projects. GPU
containers additionally need `--gpus=all` in `runArgs` and the
nvidia-container-toolkit on the host (no setup module yet).

Learned porting web-tools-container:

- **A bind-mount source must exist on the host**, or docker creates it
  owned by root. `"initializeCommand": "mkdir -p \"$HOME/container/<name>\""`
  runs on the host before the container starts.
- **Build-time warnings from extra modules are expected.** `24-yt-dlp`
  warns "no JS runtime" and "~/.local/bin is not on PATH": `link.sh` runs
  one layer later, so the dotfiles PATH (fnm, `~/.local/bin`) is not active
  yet. Check at runtime instead: `yt-dlp -v --simulate` lists `JS runtimes:
  node-…` and `curl_cffi` once the container is up.

## Node.js in containers

Node comes from `22-fnm` (LTS at build time), so every container has it.

- **Non-Node projects** (voice-lab, web-tools, dotfiles): no pin. They get
  the LTS of the day, whenever the `system-setup` layer is built. That layer
  is cached, so it goes stale: rebuild with `CACHE_BUST=$(date +%s) dcre .`
  after a Node security release. (Oct 2026 releases: fixed in 22.23.4,
  24.22.1, 26.12.1; the zlib/Brotli, TLS and DNS issues are in the runtime
  itself, not in npm packages.)
- **Node projects** (med-plan-assistant): pin a major (an even-numbered LTS)
  in `.nvmrc` plus `engines` in `package.json`; install in
  `postCreateCommand` with `zsh -lc '… && cd /workspace && fnm install &&
  eval "$(fnm env)" && fnm use && fnm default "$(cat .nvmrc)" && npm ci'`.
  A major pin still gets the newest patch on every container recreate.
  Review the major once a year (Oct/Nov, when the next LTS starts).
- **Commit `package-lock.json`** and use `npm ci`; add a dependency update
  bot: Dependabot on GitHub, Renovate for repos on the Forgejo instance
  (Forgejo has no Dependabot). Dependency CVEs are the other half of the
  risk.
- **Do not `npm update` during a build**: builds would stop being
  reproducible. Updates go through reviewed PRs.
- Do not update npm separately from Node; it ships with Node.
- Warnings in `npm ci` output: "install-scripts … not covered by
  allowScripts" is the npm 11 safety feature (review with `npm
  install-scripts ls`); "new major version of npm" can be ignored.

## Later

- One shared base image (dotfiles + `system-setup` baked in) in the Forgejo
  container registry, with the project Dockerfiles `FROM` it. Worth it once
  the per-repo builds feel slow; until then each repo builds the reference
  Dockerfile above.
- A 26.10 variant (see Base image).
