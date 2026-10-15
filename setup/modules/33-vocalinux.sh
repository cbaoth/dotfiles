# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 33-vocalinux: Vocalinux voice dictation via the upstream installer.
#
# The upstream installer is the recommended channel
# (https://github.com/VocaHQ/vocalinux/blob/main/docs/INSTALL.md); snap is still
# in review, flatpak and AppImage update by hand only. It installs per user:
# venv in ~/.local/share/vocalinux, launcher ~/.local/bin/vocalinux, models
# beside the venv, config ~/.config/vocalinux/config.json (kept across
# reinstalls). It must NOT run as root -- it refuses -- and calls sudo itself
# for the apt dependencies, so the password prompt comes from inside it.
#
# --auto: non-interactive, whisper.cpp engine, GPU backend detected by the
# installer (Vulkan -> CUDA -> CPU), so the same call fits a CPU-only notebook.
# It also stops a running Vocalinux; the module starts it again under sway.
#
# Installed means done, like 26-vicinae: a re-run reports zero changes and
# needs no network. Update with VOCALINUX_UPDATE=1 (latest release, a no-op
# when already there); pin a release with VOCALINUX_TAG=v0.18.2. v0.17.0 had a
# push-to-talk race that left dictation recording for hours; see
# docs/troubleshooting/vocalinux-ptt-stuck-recording.md.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Vocalinux voice dictation (upstream installer, ~/.local/share/vocalinux)"
MODULE_PROFILES=(desktop)
MODULE_DOC="docs/setup/vocalinux.md"

declare -r VL_REPO="VocaHQ/vocalinux"
declare -r VL_VENV_PY="${HOME}/.local/share/vocalinux/venv/bin/python3"
declare -r VL_CONFIG="${HOME}/.config/vocalinux/config.json"

# {{{ = Helpers =============================================================

# Installed package version (e.g. 0.17.0), empty when not installed. Read from
# the venv rather than `vocalinux --version`, which would start GTK.
vl_installed_version() {
  [[ -x "${VL_VENV_PY}" ]] || return 0
  "${VL_VENV_PY}" -I -c \
    'import importlib.metadata as m; print(m.version("vocalinux"))' 2>/dev/null || true
}

# Release tag to install: VOCALINUX_TAG, else the latest GitHub release.
vl_target_tag() {
  if [[ -n "${VOCALINUX_TAG:-}" ]]; then
    printf '%s\n' "${VOCALINUX_TAG}"
    return 0
  fi
  curl -fsSL "https://api.github.com/repos/${VL_REPO}/releases/latest" \
    | sed -n 's/^ *"tag_name": *"\([^"]*\)".*/\1/p'
}

# Match the venv entry point, not the process name: the GUI runs as
# `python .../venv/bin/vocalinux-gui` (comm "vocalinux-gui"), so a
# `pgrep -x vocalinux` misses it.
vl_running() {
  pgrep -u "$(id -u)" -f '/vocalinux/venv/bin/vocalinux' >/dev/null 2>&1
}

vl_install() {
  local -r tag="$1"
  # Temp file, not a pipe, and fetched from the tag (not main), so the
  # installer matches the release it installs.
  st::run_sh "install Vocalinux ${tag} (upstream installer, --auto)" \
    "set -euo pipefail
     tmp=\$(mktemp)
     trap 'rm -f \"\$tmp\"' EXIT
     curl -fsSL 'https://raw.githubusercontent.com/${VL_REPO}/${tag}/install.sh' -o \"\$tmp\"
     bash \"\$tmp\" --auto --tag='${tag}'"
}

# }}} = Helpers =============================================================

module_run() {
  if ! st::have_cmd curl; then
    st::war "curl not found — skipping (run '00-apt-base' first, or install curl)"
    return 0
  fi

  local installed tag
  installed="$(vl_installed_version)"
  if [[ -n "${installed}" && -z "${VOCALINUX_UPDATE:-}" && -z "${VOCALINUX_TAG:-}" ]]; then
    st::noop "Vocalinux ${installed} already installed (VOCALINUX_UPDATE=1 to update)"
    return 0
  fi

  tag="$(vl_target_tag)"
  if [[ -z "${tag}" ]]; then
    st::err "could not determine the latest Vocalinux release (GitHub API)"
    (( ST_FAILED++ ))
    return 1
  fi
  if [[ "${installed}" == "${tag#v}" ]]; then
    st::noop "Vocalinux ${installed} is already ${tag}"
    return 0
  fi

  # The installer keeps config.json, but a copy costs nothing and makes a
  # surprising rewrite (engine fallback) recoverable.
  if [[ -f "${VL_CONFIG}" ]]; then
    st::run "back up ${VL_CONFIG}" -- \
      cp -p "${VL_CONFIG}" "${VL_CONFIG}.bak-${installed:-none}"
  fi

  local -i was_running=0
  vl_running && was_running=1

  vl_install "${tag}" || return 1

  # The installer stopped it. Restart through sway so it lands in the session
  # log like the autostarted one (90-launch-apps.conf).
  if (( was_running )) && ! vl_running; then
    if [[ -n "${SWAYSOCK:-}" ]] && st::have_cmd swaymsg; then
      st::run "restart Vocalinux in the sway session" -- \
        swaymsg -q exec 'sway-run-after-waybar vocalinux'
    else
      st::war "Vocalinux was stopped by the installer — start it again: vocalinux"
    fi
  fi
}
