# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 58-wslg-x11: make /tmp/.X11-unix writable so nested compositors get Xwayland.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="WSLg: writable /tmp/.X11-unix at boot, for Xwayland in nested sway"
MODULE_PROFILES=(wsl wsl-work)
MODULE_DOC="docs/setup/sway-wslg.md"

declare -r WSLG_X11_UNIT="wslg-x11-unix.service"
declare -r WSLG_X11_UNIT_FILE="/etc/systemd/system/${WSLG_X11_UNIT}"

# WSL's generated wslg.service bind-mounts /mnt/wslg/.X11-unix read-only and
# without the sticky bit over /tmp/.X11-unix, so wlroots refuses to create
# its own X socket. This unit undoes that after it and links WSLg's own X0
# back, so DISPLAY=:0 keeps working. A second, older entry can stay in
# mountinfo below tmp.mount: umount reports "not mounted" and the directory is
# already the writable one, hence `|| break`.
declare -r WSLG_X11_UNIT_CONTENT='# Managed by dotfiles: setup/modules/58-wslg-x11.sh — do not edit by hand.
# Docs: docs/setup/sway-wslg.md
[Unit]
Description=Writable /tmp/.X11-unix for Xwayland of nested compositors (WSLg)
After=wslg.service
ConditionPathIsDirectory=/mnt/wslg/.X11-unix

[Service]
Type=oneshot
ExecStart=/bin/sh -c "while mountpoint -q /tmp/.X11-unix; do umount /tmp/.X11-unix || break; done"
ExecStart=/bin/chmod 1777 /tmp/.X11-unix
ExecStart=/bin/ln -sfn /mnt/wslg/.X11-unix/X0 /tmp/.X11-unix/X0

[Install]
WantedBy=multi-user.target'

module_run() {
  if ! st::is_wsl; then
    st::skip "not WSL"
    return 0
  fi
  if [[ "$(ps -p 1 -o comm= 2>/dev/null)" != "systemd" ]]; then
    st::war "WSL without systemd: set [boot] systemd=true in /etc/wsl.conf, then 'wsl --shutdown'"
    return 0
  fi

  local -i before="${ST_CHANGED:-0}"
  st::file_content "${WSLG_X11_UNIT_FILE}" "${WSLG_X11_UNIT_CONTENT}" 0644
  if (( "${ST_CHANGED:-0}" > before )); then
    st::run "reload systemd units" -- sudo systemctl daemon-reload
  fi

  if systemctl is-enabled --quiet "${WSLG_X11_UNIT}" 2>/dev/null; then
    st::noop "${WSLG_X11_UNIT} enabled"
  else
    st::run "enable ${WSLG_X11_UNIT}" -- sudo systemctl enable "${WSLG_X11_UNIT}"
  fi

  # Apply now too; WSLg's own X11 clients stay connected through the X0 link.
  if [[ -k /tmp/.X11-unix && -L /tmp/.X11-unix/X0 ]]; then
    st::noop "/tmp/.X11-unix already writable (sticky, X0 linked)"
  else
    st::run "start ${WSLG_X11_UNIT}" -- sudo systemctl start "${WSLG_X11_UNIT}"
  fi
}
