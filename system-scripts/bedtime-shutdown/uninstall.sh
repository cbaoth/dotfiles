#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash
#
# Purge everything install.sh / bedtime-rearm.sh put on the system: units, timers,
# scripts, config, PAM managed block, root cron entry, lock and log files.

# -u/pipefail only: a purge should keep going past individual failures and
# report them at the end, rather than stop half-way.
set -uo pipefail

# {{{ = CONSTANTS ============================================================
# Stop order matters: the re-arm timer first, so it cannot re-enable the rest.
declare -ra UNITS=(
  bedtime-rearm.timer bedtime-rearm.service
  bedtime.timer bedtime.service
)
declare -ra FILES=(
  /opt/bin/bedtime-shutdown.sh
  /opt/bin/bedtime-lib.sh
  /opt/bin/bedtime-rearm.sh
  /opt/bin/bedtime-lock
  /opt/bin/bedtime-unlock
  /etc/bedtime-shutdown.conf
  /etc/systemd/system/bedtime.service
  /etc/systemd/system/bedtime.timer
  /etc/systemd/system/bedtime-rearm.service
  /etc/systemd/system/bedtime-rearm.timer
  /run/bedtime-shutdown.lock
)
declare -r TIME_CONF="/etc/security/time.conf"
declare -r PAM_BEGIN="# >>> bedtime-rearm managed >>>"
declare -r CRON_PATTERN="bedtime-shutdown.sh"

declare DRY_RUN=false
declare KEEP_LOG=false
declare LOGFILE="/var/log/bedtime-shutdown.log"
declare -i ERRORS=0
# }}} = CONSTANTS ============================================================

# {{{ = HELPERS ==============================================================
ok()   { printf '\033[0;32m✓\033[0m %s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '\033[1;33m⚠\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[0;31m✗ %s\033[0m\n' "$*" >&2; ERRORS+=1; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Remove bedtime-shutdown from this system: stop + disable all bedtime units,
clear immutability, delete scripts/config/units (and their .bak copies), drop
the PAM managed block from ${TIME_CONF}, the root cron entry, lock and log.

/etc/pam.d/common-account is never edited (pam_time.so is only reported).

Options:
  -n, --dry-run   Show what would be done; change nothing.
      --keep-log  Keep the log file (${LOGFILE}).
  -h, --help      Show this help.
EOF
}

# Run a command, or only print it on a dry run.
run() {
  if [[ "${DRY_RUN}" == true ]]; then info "[dry-run] $*"; return 0; fi
  "$@" || { err "failed: $*"; return 1; }
}

is_immutable() {
  [[ -e "$1" ]] && lsattr -d "$1" 2>/dev/null | awk '{print $1}' | grep -q i
}
# }}} = HELPERS ==============================================================

# {{{ = STEPS ================================================================
stop_units() {
  local unit state
  for unit in "${UNITS[@]}"; do
    state="$(systemctl is-enabled "${unit}" 2>/dev/null)"
    if [[ "${state}" == masked ]]; then run systemctl unmask "${unit}"; fi
    if systemctl is-active --quiet "${unit}"; then run systemctl stop "${unit}"; fi
    if [[ "${state}" == enabled ]]; then run systemctl disable "${unit}"; fi
  done
  ok "units stopped + disabled"
}

remove_files() {
  local f
  for f in "${FILES[@]}" "${FILES[@]/%/.bak}" /etc/systemd/system/bedtime{,-rearm}.{service,timer}.d; do
    [[ -e "${f}" || -L "${f}" ]] || continue
    if is_immutable "${f}"; then run chattr -i "${f}"; fi
    run rm -rf -- "${f}"
  done
  if [[ "${KEEP_LOG}" == false && -e "${LOGFILE}" ]]; then run rm -f -- "${LOGFILE}"; fi
  run systemctl daemon-reload
  # Errors here only mean "nothing to reset" for already-unloaded units.
  [[ "${DRY_RUN}" == true ]] || systemctl reset-failed "${UNITS[@]}" 2>/dev/null || true
  ok "files removed"
}

# bedtime-rearm writes its block from the begin marker to EOF, so cut there.
remove_pam_block() {
  if ! grep -qF "${PAM_BEGIN}" "${TIME_CONF}" 2>/dev/null; then
    ok "no PAM managed block in ${TIME_CONF}"
  else
    if is_immutable "${TIME_CONF}"; then run chattr -i "${TIME_CONF}"; fi
    run cp -a "${TIME_CONF}" "${TIME_CONF}.bedtime-uninstall.bak"
    if [[ "${DRY_RUN}" == true ]]; then
      info "[dry-run] would cut ${TIME_CONF} from line: ${PAM_BEGIN} ..."
    else
      local tmp; tmp="$(mktemp)"
      if ! { awk -v m="${PAM_BEGIN}" 'index($0, m) == 1 { exit } { print }' "${TIME_CONF}" > "${tmp}" \
          && cat "${tmp}" > "${TIME_CONF}"; }; then
        err "failed to rewrite ${TIME_CONF}"
      fi
      rm -f "${tmp}"
    fi
    ok "PAM managed block removed (backup: ${TIME_CONF}.bedtime-uninstall.bak)"
  fi
  if grep -qE '^[[:space:]]*account[[:space:]].*pam_time\.so' /etc/pam.d/common-account 2>/dev/null; then
    warn "pam_time.so is active in /etc/pam.d/common-account - left as-is (remove by hand if only bedtime needed it)"
  fi
}

remove_cron() {
  local tab
  tab="$(crontab -l 2>/dev/null)" || true
  if ! grep -qF "${CRON_PATTERN}" <<<"${tab}"; then
    ok "no root cron entry"
    return 0
  fi
  if [[ "${DRY_RUN}" == true ]]; then
    info "[dry-run] would drop root cron lines: $(grep -F "${CRON_PATTERN}" <<<"${tab}")"
    return 0
  fi
  grep -vF "${CRON_PATTERN}" <<<"${tab}" | crontab - || err "failed to update root crontab"
  ok "root cron entry removed"
}

verify() {
  local f unit left=0
  for unit in "${UNITS[@]}"; do
    if systemctl is-active --quiet "${unit}" || systemctl is-enabled --quiet "${unit}" 2>/dev/null; then
      warn "still active/enabled: ${unit}"; left=1
    fi
  done
  for f in "${FILES[@]}"; do
    [[ -e "${f}" ]] && { warn "still present: ${f}"; left=1; }
  done
  grep -qF "${PAM_BEGIN}" "${TIME_CONF}" 2>/dev/null && { warn "PAM block still in ${TIME_CONF}"; left=1; }
  return "${left}"
}
# }}} = STEPS ================================================================

main() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -n|--dry-run) DRY_RUN=true ;;
      --keep-log)   KEEP_LOG=true ;;
      -h|--help)    usage; exit 0 ;;
      *) err "unknown argument: $1"; usage >&2; exit 1 ;;
    esac
    shift
  done

  if [[ "${DRY_RUN}" == false && ${EUID} -ne 0 ]]; then
    err "needs root; re-run with sudo (or preview with --dry-run)"
    exit 1
  fi

  stop_units
  remove_pam_block
  remove_cron
  remove_files

  if [[ "${DRY_RUN}" == true ]]; then
    ok "dry run complete - nothing changed"
  elif verify && (( ERRORS == 0 )); then
    ok "bedtime-shutdown fully removed"
  else
    err "uninstall incomplete (see warnings above)"
    exit 1
  fi
}

main "$@"
