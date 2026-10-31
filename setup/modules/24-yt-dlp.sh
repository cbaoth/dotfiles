# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 24-yt-dlp: yt-dlp via the official standalone binary, into $HOME.
#
# yt-dlp ships several ways (apt, pip, standalone release binary) and apt
# lags upstream — YouTube's anti-bot changes break extraction every few
# weeks, and apt only moves on a dist upgrade. The standalone binary
# self-updates via `yt-dlp -U` and needs no root, so it is installed into
# ~/.local/bin, same reasoning as 22-fnm/28-claude-code.
#
# Skipped on the vserver (11001001.org): running a browser-impersonating
# downloader + JS engine on the one internet-facing host is a deliberate no
# for now. Use ~/git/web-tools-container there if actually needed.
#
# curl_cffi (TLS/browser impersonation — some extractors warn "no
# impersonate target is available" without it) is installed via pip --user:
# the standalone binary is plain `#!/usr/bin/env python3` over a zip of pure
# yt_dlp source, so it resolves curl_cffi from the normal running
# interpreter's site-packages like any other import — no venv needed. See
# MODULE_DOC for the full reasoning and how to opt out.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="yt-dlp (official standalone binary, ~/.local/bin/yt-dlp)"
MODULE_PROFILES=(desktop server)
MODULE_DOC="docs/setup/yt-dlp.md"

declare -r YTDLP_BIN="${HOME}/.local/bin/yt-dlp"
declare -r YTDLP_URL="https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"

# The one internet-facing host; see the module header. hostname -s as
# written by setup/hosts.list.
declare -r YTDLP_SKIP_HOST="11001001"

module_run() {
  if [[ "$(hostname -s)" == "${YTDLP_SKIP_HOST}" ]]; then
    st::noop "skipping yt-dlp on ${YTDLP_SKIP_HOST} (internet-facing; see module header)"
    return 0
  fi

  if ! st::have_cmd curl; then
    st::war "curl not found — skipping (run '00-apt-base' first, or install curl)"
    return 0
  fi

  # Not this module's call to remove — see 28-claude-code's identical stance.
  # In practice this is mpv's Recommends, not a deliberate install, but the
  # warning is cheap and the override is the user's either way.
  if dpkg-query -W -f='${db:Status-Status}' yt-dlp 2>/dev/null \
       | st::grep_q -x 'installed'; then
    st::war "the apt package 'yt-dlp' is also installed (likely pulled in by mpv's Recommends)"
    st::war "the one in \${HOME}/.local/bin wins on PATH, so it is unused, but it lags upstream: 'sudo apt remove yt-dlp' to drop it"
  fi

  if ! st::have_cmd node && ! st::have_cmd deno && ! st::have_cmd bun; then
    st::war "no JS runtime (node/deno/bun) found — YouTube's JS challenges may fail to solve (run '22-fnm' first)"
  fi

  # Present means done: update with YTDLP_UPDATE=1 (yt-dlp -U is itself
  # idempotent — a no-op when already current).
  if [[ -x "${YTDLP_BIN}" && -z "${YTDLP_UPDATE:-}" ]]; then
    st::noop "yt-dlp already installed: ${YTDLP_BIN} (YTDLP_UPDATE=1 to update)"
  elif [[ -x "${YTDLP_BIN}" ]]; then
    st::run "update yt-dlp (${YTDLP_BIN} -U)" -- "${YTDLP_BIN}" -U
  else
    if [[ -d "${HOME}/.local/bin" ]]; then
      st::noop "directory exists: ${HOME}/.local/bin"
    else
      st::run "create ${HOME}/.local/bin" -- mkdir -p "${HOME}/.local/bin"
    fi

    # pipefail: a failed curl must not look like a successful install.
    st::run_sh "install yt-dlp into ${YTDLP_BIN}" \
      "set -o pipefail; curl -fsSL '${YTDLP_URL}' -o '${YTDLP_BIN}' && chmod a+rx '${YTDLP_BIN}'"

    if ! (( ST_DRY_RUN )) && [[ -x "${YTDLP_BIN}" ]] && ! st::have_cmd yt-dlp; then
      st::war "installed, but ~/.local/bin is not on PATH — run dotfiles-link, then a new shell"
    fi
  fi

  # curl_cffi: picked up automatically by the standalone binary (see module
  # header). --break-system-packages is required even with --user on a
  # PEP 668 pip (confirmed: --user alone still refuses); scoped to the user
  # site-packages only, never touches dpkg-tracked files, so this is the
  # "I know what I'm doing, it's not apt-packaged" case the error message
  # itself is written for. pip itself is idempotent/no-op when satisfied.
  if st::have_cmd pip3; then
    if pip3 show curl_cffi >/dev/null 2>&1; then
      st::noop "curl_cffi already installed (TLS impersonation)"
    else
      st::run "install curl_cffi --user (TLS impersonation for yt-dlp)" -- \
        pip3 install --user --break-system-packages --quiet curl_cffi
    fi
  else
    st::war "pip3 not found — skipping curl_cffi (impersonation warnings will persist; run '00-apt-base' first)"
  fi
}
