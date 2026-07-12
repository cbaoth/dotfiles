# `setup/` — system setup as code

Idempotent modules for the things that deploying this repo into `$HOME` does
*not* cover: apt packages, locales, flatpak apps, docker, fonts, system
services. The counterpart to `dotfiles-link`, not a replacement for it.

Run it with `bin/system-setup` (symlinked to `~/bin/system-setup`).

```bash
system-setup --list                      # what exists, and what each does
system-setup --dry-run --profile desktop # print what would change; change nothing
system-setup --profile auto              # detect desktop/server/wsl, run all matching
system-setup 20-flatpak 30-docker        # run specific modules
```

## The one rule

**A module must be safe to re-run, and a re-run must report zero changes.**

That is the whole contract, and it is what makes this readable a year from now:
you never have to reason about whether a script has already been applied — you
run it and look at the summary.

```
==> 0 changed, 47 already correct
```

The `st::*` helpers in `lib/setup-lib.sh` exist to make this cheap. Use
`st::apt_install` (which filters to the missing packages) rather than calling
`apt-get install` directly; use `st::noop` when you detect the desired state is
already in place, so the counter stays honest.

## Layout

```
setup/
├── lib/setup-lib.sh   # shared st:: helpers — logging, dry-run, apt, flatpak, files
├── packages/*.list    # package sets as DATA, not buried in bash
└── modules/NN-*.sh    # one topic per module, sourced by bin/system-setup
```

Package lists are plain data on purpose: *"which tools do I install on a fresh
box"* should be answerable without reading a single line of shell.

## Adding a module

Create `modules/NN-name.sh`. No shebang (it is sourced, not executed):

```bash
MODULE_DESC="One line, shown by --list"
MODULE_PROFILES=(desktop server wsl)   # omit for 'all profiles'
MODULE_DOC="docs/setup/name.md"        # the note this automates

module_run() {
  st::apt_install foo bar

  if [[ -f /etc/foo.conf ]]; then
    st::noop "foo already configured"
  else
    st::run "configure foo" -- sudo cp "${ST_SETUP_DIR}/files/foo.conf" /etc/foo.conf
  fi
}
```

Each module is sourced in its own subshell, so `MODULE_*` metadata and any
helper functions you define cannot leak into the next module.

Then write the matching note in `docs/setup/name.md` and cross-link both ways —
the module says *how*, the note says *why*, and neither is much use alone.

## Why bash and not Ansible

Considered, and rejected for now. This repo already *is* a shell ecosystem with
a style guide, a shellcheck config, and a linking system; Ansible would mean a
second paradigm plus a python dependency on every target (including a bare
Contabo box and WSL). The one thing genuinely given up is `--check --diff`, and
`--dry-run` covers most of that.

If it ever earns its place, the port is cheap *because* modules are one-topic
and idempotent — each becomes a role. That is a reason to keep them that way.
