# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148,SC2034
#
# 57-wifi-resume: unload the Qualcomm ath12k Wi-Fi driver around suspend.
#
# SC2034: MODULE_* is read by bin/system-setup, which sources this file.
#
# Sourced by bin/system-setup. Helpers (st::*) come from setup/lib/setup-lib.sh.

MODULE_DESC="Reload the ath12k Wi-Fi driver across suspend/hibernate (resume bug)"
MODULE_PROFILES=(desktop)
MODULE_DOC="docs/troubleshooting/ath12k-resume-failure.md"

declare -r WIFI_HOOK="/etc/systemd/system-sleep/50-ath12k-reload"

# systemd-sleep runs every executable in this directory with $1=pre|post and
# $2=suspend|hibernate|... The card is unloaded BEFORE sleep so it is
# re-initialised from scratch on resume instead of being asked to wake from a
# low-power state it does not survive (see MODULE_DOC). The hook must never fail
# or hang: a non-zero exit would not block sleep, but the log line is the
# only trace of a problem, so it goes to the journal.
declare -r WIFI_HOOK_CONTENT='#!/bin/sh
# Managed by dotfiles: setup/modules/57-wifi-resume.sh — do not edit by hand.
# Docs: docs/troubleshooting/ath12k-resume-failure.md
case "$1" in
  pre)  modprobe -r ath12k_wifi7 ath12k || logger -t ath12k-sleep "unload failed" ;;
  post) modprobe ath12k_wifi7 || logger -t ath12k-sleep "reload failed" ;;
esac
exit 0'

module_run() {
  # Gate on the hardware, not just the profile: other desktops (Intel/MediaTek
  # cards) have nothing to unload, and the hook would only log noise.
  if [[ ! -d /sys/bus/pci/drivers/ath12k_wifi7_pci ]]; then
    st::skip "no ath12k_wifi7 device bound on this host"
    return 0
  fi

  st::file_content "${WIFI_HOOK}" "${WIFI_HOOK_CONTENT}" 0755

  # Content can match while the mode is wrong (a hand-made copy); a
  # non-executable hook is silently ignored by systemd-sleep.
  if [[ -x "${WIFI_HOOK}" ]]; then
    st::noop "hook is executable"
  elif [[ -e "${WIFI_HOOK}" ]]; then
    st::run "chmod 0755 ${WIFI_HOOK}" -- sudo chmod 0755 "${WIFI_HOOK}"
  fi
}
