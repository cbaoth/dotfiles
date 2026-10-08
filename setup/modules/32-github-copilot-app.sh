# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 32-github-copilot-app: GitHub Copilot desktop app (Linux AppImage).
#
# The counterpart to 31-github-copilot. The app is only published as an
# AppImage (~600 MB), so there is no package channel to prefer; the module
# downloads it once into ~/Applications and gives it what an AppImage lacks:
#
#   - a launcher entry (~/.local/share/applications/github-copilot.desktop with
#     an icon extracted from the image), which rofi's drun mode, ulauncher and
#     any other XDG launcher pick up;
#   - a wrapper, bin/github-copilot-app, for the Electron keyring problem under
#     Sway (see bin/claude-desktop for the explanation).
#
# Why the module owns its own .desktop: the app writes one itself on first run
# (com.github.githubapp.desktop), but it is NoDisplay and its Exec points into
# the temporary /tmp/.mount_* of that run, so it is dead on arrival. The other
# one it writes, github-handler.desktop, is the x-scheme-handler for the
# gh:// OAuth callback and is correct; leave it alone.
#
# Present means done. The download URL is an unversioned "latest" redirect, so
# there is no cheap way to tell whether the local copy is current; to update,
# remove the AppImage and re-run the module.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="GitHub Copilot desktop app (AppImage in ~/Applications + launcher)"
MODULE_PROFILES=(desktop)
MODULE_DOC="docs/setup/github-copilot.md"

declare -r COPILOT_APP_URL="https://gh.io/copilot-app-linux"
declare -r COPILOT_APP_IMAGE="${HOME}/Applications/GitHub-Copilot-linux-x64.AppImage"
declare -r COPILOT_APP_ICON="${HOME}/.local/share/icons/hicolor/256x256/apps/github-copilot.png"
declare -r COPILOT_APP_DESKTOP="${HOME}/.local/share/applications/github-copilot.desktop"

# The wrapper is linked into ~/bin by dotfiles-link. Absolute in Exec because a
# launcher started from the compositor may not have ~/bin on its PATH.
declare -r COPILOT_APP_WRAPPER="${HOME}/bin/github-copilot-app"

copilot_app_desktop_entry() {
  cat <<DESKTOP
[Desktop Entry]
Type=Application
Name=GitHub Copilot
Comment=GitHub Copilot desktop app
Exec=${COPILOT_APP_WRAPPER} %U
Icon=github-copilot
Terminal=false
Categories=Development;
StartupWMClass=GitHub Copilot
DESKTOP
}

module_run() {
  if [[ -x "${COPILOT_APP_IMAGE}" ]]; then
    st::noop "Copilot app already installed: ${COPILOT_APP_IMAGE}"
  else
    if ! st::have_cmd curl; then
      st::war "curl not found — skipping (run '00-apt-base' first, or install curl)"
      return 0
    fi
    # Download to .part and rename: an interrupted 600 MB transfer must not
    # leave an executable-looking, truncated AppImage that satisfies the check
    # above on the next run.
    st::run_sh "download Copilot app AppImage" \
      "set -e; mkdir -p '${HOME}/Applications'; curl -fL --progress-bar -o '${COPILOT_APP_IMAGE}.part' '${COPILOT_APP_URL}'; chmod +x '${COPILOT_APP_IMAGE}.part'; mv '${COPILOT_APP_IMAGE}.part' '${COPILOT_APP_IMAGE}'"
  fi

  # Icon: the AppImage root carries a 256x256 PNG, named with a space.
  if [[ -f "${COPILOT_APP_ICON}" ]]; then
    st::noop "icon already present: ${COPILOT_APP_ICON}"
  elif (( ST_DRY_RUN )) || [[ -x "${COPILOT_APP_IMAGE}" ]]; then
    st::run_sh "extract launcher icon" \
      "set -e; tmp=\$(mktemp -d); trap 'rm -rf \"\$tmp\"' EXIT; cd \"\$tmp\"; '${COPILOT_APP_IMAGE}' --appimage-extract 'GitHub Copilot.png' >/dev/null; mkdir -p '$(dirname "${COPILOT_APP_ICON}")'; cp 'squashfs-root/GitHub Copilot.png' '${COPILOT_APP_ICON}'"
  fi

  local want
  want="$(copilot_app_desktop_entry)"
  if [[ -f "${COPILOT_APP_DESKTOP}" ]] && [[ "$(cat "${COPILOT_APP_DESKTOP}")" == "${want}" ]]; then
    st::noop "launcher already up to date: ${COPILOT_APP_DESKTOP}"
  else
    st::run_sh "write ${COPILOT_APP_DESKTOP}" \
      "mkdir -p '$(dirname "${COPILOT_APP_DESKTOP}")'; printf '%s\n' $(printf '%q' "${want}") > '${COPILOT_APP_DESKTOP}'"
  fi

  if ! (( ST_DRY_RUN )) && [[ ! -x "${COPILOT_APP_WRAPPER}" ]]; then
    st::war "${COPILOT_APP_WRAPPER} missing — run dotfiles-link so the launcher can start the app"
  fi
}
