---
title: Ollama — local LLM runtime
hosts: [motoko]
status: resolved
tags: [ollama, llm, gpu, systemd]
updated: 2026-11-13
automated_by: setup/modules/39-ollama.sh
---

# Ollama

**Automated:** `system-setup 39-ollama` (motoko only; other hosts skip it).

## Install and update

Ollama is not in Ubuntu apt and has no apt repo, so nothing updates it behind
your back. The module uses the official installer:

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

It unpacks the release into `/usr/local`, creates the `ollama` user and writes
`/etc/systemd/system/ollama.service`. The installer calls `sudo` itself, so run
the module from a terminal (no tty = no password prompt).

Idempotence: the module compares `ollama -v` with the target of
`https://github.com/ollama/ollama/releases/latest` and re-runs the installer
only when they differ. A re-run on a current install reports zero changes;
offline it warns and keeps what is there.

## Notes

- Models live in `/usr/share/ollama/.ollama` (service user), not in `$HOME`.
- The installer overwrites `ollama.service`. Local tweaks belong in a drop-in
  (`sudo systemctl edit ollama`), which survives updates.
- Profile `desktop` plus a hostname check for motoko; add a host by changing
  `OLLAMA_HOST_ONLY` in the module.
- First update done 2026-11-13: 0.20.7 → latest.
