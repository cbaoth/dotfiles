# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 28-claude-code: Claude Code CLI via Anthropic's native installer.
#
# This is the one module that installs into $HOME rather than the system, and
# deliberately so. Anthropic publishes the CLI three ways — a native installer,
# an apt/dnf/apk repo, and npm — and the native one is the only ONE setup that
# works everywhere these dotfiles land: hosts without root, hosts that are not
# Debian-based, and containers. Every machine then has the same install, the
# same path, and the same update mechanism, instead of apt here and a tarball
# there.
#
# The other reason is updates: a native install auto-updates itself in the
# background, while the apt package does not (`apt upgrade` only, per
# Anthropic's own docs). A tool that ships several releases a week is a poor
# fit for a channel that only moves when the machine is upgraded.
#
# The cost is a pipe-to-shell, which nothing else in setup/ does. It is
# accepted here because the alternative — the apt repo — is signed by the same
# key and served from the same host (downloads.claude.ai), so trusting one and
# not the other would be theatre. The installer itself verifies a SHA256 from a
# signed manifest before it runs anything.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Claude Code CLI (native installer, ~/.local/bin/claude)"
MODULE_PROFILES=(desktop server wsl)
MODULE_DOC="docs/setup/claude.md"

# Release channel: latest | stable | an exact version (e.g. 2.1.89).
# 'stable' trails 'latest' by roughly a week and skips releases with known
# major regressions; it is the better choice on a machine that must not break.
declare -r CLAUDE_CLI_CHANNEL="latest"

declare -r CLAUDE_CLI_INSTALL_URL="https://claude.ai/install.sh"

# The launcher the installer manages. Checked directly rather than trusting
# `command -v claude`, because system-setup may run with a PATH that does not
# include ~/.local/bin (a sudo -i shell, cron) — and then the module would
# reinstall on every run, which is exactly the re-run contract this repo cares
# about.
declare -r CLAUDE_CLI_BIN="${HOME}/.local/bin/claude"

# {{{ = Helpers =============================================================

# Warn about a second CLI installed from a package manager. Two installs put
# two `claude` binaries on PATH and the winner depends on PATH order, so the
# version you run stops matching the version you updated. Not this module's
# call to resolve — removing a package the user installed deliberately is a
# worse surprise than the warning.
claude_cli_warn_conflicts() {
  if dpkg-query -W -f='${db:Status-Status}' claude-code 2>/dev/null \
     | st::grep_q -x 'installed'; then
    st::war "the apt package 'claude-code' is also installed — two CLIs on PATH"
    st::war "keep one: 'sudo apt remove claude-code' (see docs/setup/claude.md)"
  fi

  if st::have_cmd npm && npm ls -g --depth=0 @anthropic-ai/claude-code >/dev/null 2>&1; then
    st::war "a global npm @anthropic-ai/claude-code is also installed — two CLIs on PATH"
    st::war "keep one: 'npm uninstall -g @anthropic-ai/claude-code'"
  fi
}

# }}} = Helpers =============================================================

module_run() {
  # curl is in setup/packages/base.list, but this module can be run on its own
  # against a machine that never saw 00-apt-base.
  if ! st::have_cmd curl; then
    st::war "curl not found — skipping (run '00-apt-base' first, or install curl)"
    return 0
  fi

  claude_cli_warn_conflicts

  # Present means done: the native install keeps itself current, so there is
  # nothing for a re-run to do. `claude update` forces one immediately, and
  # `claude doctor` reports what the last background attempt did.
  if [[ -x "${CLAUDE_CLI_BIN}" ]]; then
    st::noop "Claude Code CLI already installed: ${CLAUDE_CLI_BIN} (self-updating)"
    return 0
  fi

  # An existing `claude` somewhere else on PATH (Homebrew, a hand-placed
  # binary) is not our launcher, but installing over it would leave two.
  if st::have_cmd claude; then
    st::war "a 'claude' is on PATH at $(command -v claude) but not at ${CLAUDE_CLI_BIN}"
    st::war "leaving it alone — see docs/setup/claude.md"
    return 0
  fi

  # pipefail is not decoration: without it a failed curl feeds bash an empty
  # script, bash exits 0, and the module reports a successful install of
  # nothing. The installer refuses to run under sudo by design (it installs
  # into $HOME), so this must NOT be wrapped in st::run's sudo-using siblings.
  st::run_sh "install Claude Code CLI (${CLAUDE_CLI_CHANNEL} channel)" \
    "set -o pipefail; curl -fsSL '${CLAUDE_CLI_INSTALL_URL}' | bash -s '${CLAUDE_CLI_CHANNEL}'"

  # ~/.local/bin is put on PATH by dotfiles/.common_env, i.e. by dotfiles-link
  # rather than by this module — worth saying out loud on a fresh box where
  # setup ran before linking.
  if ! (( ST_DRY_RUN )) && [[ -x "${CLAUDE_CLI_BIN}" ]] && ! st::have_cmd claude; then
    st::war "installed, but ~/.local/bin is not on PATH — run dotfiles-link, then a new shell"
  fi
}
