#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash
#
# Purge everything install.sh / bedtime-rearm.sh put on the system: units, timers,
# scripts, config, PAM managed block, root cron entry, lock and log files.
# Gated by tamper protection (protected window, cooling-off, typing challenge).

# -u/pipefail only: a purge should keep going past individual failures and
# report them at the end, rather than stop half-way.
set -uo pipefail

# {{{ = CONSTANTS ============================================================
declare SCRIPT_DIR=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR

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
  /run/bedtime-shutdown      # allowance status snapshot (tmpfs; skipped if absent)
  /var/lib/bedtime-shutdown
)
declare -r TIME_CONF="/etc/security/time.conf"
declare -r PAM_BEGIN="# >>> bedtime-rearm managed >>>"
declare -r CRON_PATTERN="bedtime-shutdown.sh"

declare -r DEFAULT_CONFIG="/etc/bedtime-shutdown.conf"

declare DRY_RUN=false
declare KEEP_LOG=false
declare CANCEL=false
declare CONFIG_FILE="${DEFAULT_CONFIG}"
declare BSS_LOG_PATH="/var/log/bedtime-shutdown.log"   # replaced by BSS_LOGFILE from the config
declare -i ERRORS=0

# Globals bedtime-lib.sh expects (it logs to LOGFILE when set; keep it empty).
declare LOGFILE="" SCRIPT_USER="${USER:-root}"
declare -i VERBOSITY=0

# Cooling-off request (state dir overridable for non-root tests only).
declare STATE_DIR="/var/lib/bedtime-shutdown"
[[ ${EUID} -ne 0 && -n "${BSS_TEST_STATE_DIR:-}" ]] && STATE_DIR="${BSS_TEST_STATE_DIR}"
declare -r STATE_DIR
declare -r REQUEST_FILE="${STATE_DIR}/uninstall-request"
# }}} = CONSTANTS ============================================================

# {{{ = LIBRARY ==============================================================
# The repo-local lib (this script runs from the repo; /opt/bin may be gone).
# shellcheck source=bedtime-lib.sh
source "${SCRIPT_DIR}/bedtime-lib.sh" || { printf 'bedtime-lib.sh not found in %s\n' "${SCRIPT_DIR}" >&2; exit 1; }
# }}} = LIBRARY ==============================================================

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

Tamper protection (BSS_TAMPER_* in ${DEFAULT_CONFIG}; skipped on listed
server hosts and when not configured):
  - refused inside the protected window (also in rescue/emergency mode)
  - cooling-off: the first run only files a request; uninstall works on a
    later run, once BSS_TAMPER_UNINSTALL_DELAY_H have passed and before
    BSS_TAMPER_REQUEST_EXPIRY_H
  - then a typing challenge, before anything is changed

Options:
  -n, --dry-run        Show what would be done; change nothing.
      --keep-log       Keep the log file (BSS_LOGFILE, default ${BSS_LOG_PATH}).
      --cancel         Withdraw a pending uninstall request.
  -c, --config FILE    Other config (non-root testing only).
  -h, --help           Show this help.
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
  if [[ "${KEEP_LOG}" == false && -e "${BSS_LOG_PATH}" ]]; then run rm -f -- "${BSS_LOG_PATH}"; fi
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

# {{{ = TAMPER PROTECTION ====================================================
# Load the deployed config (it holds the BSS_TAMPER_* settings). No config means
# nothing is protected, so no hurdles.
load_config() {
  if [[ ! -e "${CONFIG_FILE}" ]]; then
    info "no config at ${CONFIG_FILE}: tamper protection not configured"
    return 0
  fi
  if [[ ! -r "${CONFIG_FILE}" ]]; then
    warn "cannot read ${CONFIG_FILE} (dry run as non-root?): tamper state unknown, treated as off"
    return 0
  fi
  # shellcheck source=/dev/null
  source "${CONFIG_FILE}"
  [[ -n "${BSS_LOGFILE:-}" ]] && BSS_LOG_PATH="${BSS_LOGFILE}"
  return 0
}

hours_fmt() { printf '%dh%02dm' $(( $1 / 3600 )) $(( $1 % 3600 / 60 )); }

# Cooling-off: 0 = a ripe request exists; otherwise file/report it and exit.
check_request() {
  local -ri delay=$(( ${BSS_TAMPER_UNINSTALL_DELAY_H:-24} * 3600 ))
  local -ri expiry=$(( ${BSS_TAMPER_REQUEST_EXPIRY_H:-72} * 3600 ))
  local -i now age=-1
  now=$(date +%s)
  [[ -f "${REQUEST_FILE}" ]] && age=$(( now - $(stat -c %Y "${REQUEST_FILE}") ))

  if (( age >= delay && age <= expiry )); then
    ok "uninstall request is $(hours_fmt "${age}") old (cooling-off $(hours_fmt "${delay}") passed)"
    return 0
  fi
  if (( age >= 0 && age < delay )); then
    warn "uninstall requested $(hours_fmt "${age}") ago; cooling-off ends in $(hours_fmt $(( delay - age ))) ($(date -d "@$(( now - age + delay ))" '+%a %H:%M'))."
    info "Withdraw it with: $(basename "$0") --cancel"
    exit 2
  fi

  (( age > expiry )) && warn "previous uninstall request expired ($(hours_fmt "${age}") old); filing a new one."
  if [[ "${DRY_RUN}" == true ]]; then
    info "[dry-run] would file an uninstall request: ${REQUEST_FILE}"
  else
    if ! { mkdir -p -- "${STATE_DIR}" && touch -- "${REQUEST_FILE}"; }; then
      err "cannot write ${REQUEST_FILE}"
      exit 1
    fi
  fi
  _warn_banner "Uninstall REQUESTED - nothing removed yet." \
    "Cooling-off: run this again between $(date -d "@$(( now + delay ))" '+%a %H:%M') and $(date -d "@$(( now + expiry ))" '+%a %H:%M')," \
    "outside the protected window $(_format_time "${BSS_TAMPER_START}")-$(_format_time "${BSS_TAMPER_END}")." \
    "If you still want this tomorrow, it is a decision, not an impulse." \
    "Changed your mind? $(basename "$0") --cancel"
  exit 2
}

# All hurdles before anything is touched. Returns only when uninstall may run.
tamper_hurdles() {
  if _is_server_host; then
    warn "server host ($(_bss_hostname)): tamper protection skipped"
    return 0
  fi
  if ! _tamper_enabled; then
    info "tamper protection not configured"
    return 0
  fi
  if _tamper_active; then _tamper_refuse "uninstall"; exit 1; fi
  _tamper_validate >/dev/null || return 0   # invalid = off (warned above)
  check_request
  _tamper_gate "uninstall" || exit 1
}
# }}} = TAMPER PROTECTION ====================================================

main() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -n|--dry-run) DRY_RUN=true ;;
      --keep-log)   KEEP_LOG=true ;;
      --cancel)     CANCEL=true ;;
      -c|--config)
        [[ -n "${2:-}" ]] || { err "missing FILE after $1"; exit 1; }
        CONFIG_FILE=$2; shift ;;
      -h|--help)    usage; exit 0 ;;
      *) err "unknown argument: $1"; usage >&2; exit 1 ;;
    esac
    shift
  done

  if [[ "${DRY_RUN}" == false && ${EUID} -ne 0 ]]; then
    err "needs root; re-run with sudo (or preview with --dry-run)"
    exit 1
  fi
  # A real uninstall is judged by the deployed config, not a hand-picked one.
  if [[ ${EUID} -eq 0 && "${CONFIG_FILE}" != "${DEFAULT_CONFIG}" ]]; then
    err "--config is for non-root testing only"
    exit 1
  fi

  if [[ "${CANCEL}" == true ]]; then
    if [[ -f "${REQUEST_FILE}" ]]; then run rm -f -- "${REQUEST_FILE}"; ok "uninstall request withdrawn"
    else ok "no pending uninstall request"; fi
    exit 0
  fi

  load_config
  tamper_hurdles

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
