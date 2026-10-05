#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2034
# SC2034: VERBOSITY/SCRIPT_USER are consumed by the sourced bedtime-lib.sh,
# which shellcheck cannot follow through the dynamic source loop.
#
# Self-heal the bedtime-shutdown system: re-enable its timer(s), enforce file
# ownership/mode (and optionally immutability), and re-assert the PAM time rules.
# Runs enable-only: it never stops or disables anything. Driven from the same
# /etc/bedtime-shutdown.conf as bedtime-shutdown.sh. See README.md.

# {{{ = COMMONS ==============================================================
# -e: exit on error, -u: unset vars are errors, -o pipefail: fail on any pipe stage
set -euo pipefail

declare SCRIPT_DIR=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare CONFIG_FILE="/etc/bedtime-shutdown.conf"
declare DRY_RUN=false
declare MODE="rearm"     # rearm | lock | unlock
declare -i VERBOSITY=0
declare SCRIPT_USER=""
SCRIPT_USER=$(whoami 2>/dev/null || echo "unknown")
declare LOGFILE=""

# Shared helpers (logging, _do, time math, PAM render). Prefer a repo-local copy
# (when running from the repo) over the deployed one, so tests use the edited lib.
declare _lib=""
for _lib in "${SCRIPT_DIR}/bedtime-lib.sh" /opt/bin/bedtime-lib.sh; do
  # shellcheck source=/dev/null
  [[ -r "$_lib" ]] && { source "$_lib"; break; }
done
unset _lib
if ! command -v __log >/dev/null 2>&1; then
  printf "bedtime-lib.sh not found (looked in %s and /opt/bin); exiting.\n" "$SCRIPT_DIR" >&2
  exit 1
fi
# }}} = COMMONS ==============================================================

# {{{ = ARGUMENT PARSING =====================================================
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -c|--config)
      [[ -z "${2:-}" ]] && { _log_error "No config file after [$1]."; exit 1; }
      [[ ! -f "$2" ]] && { _log_error "Config file [$2] not found."; exit 1; }
      CONFIG_FILE="$2"; shift
    ;;
    -n|--dry-run|--no-act) DRY_RUN=true ;;
    -v|-vv|-vvv) VERBOSITY=$(( ${#1} - 1 )) ;;
    --lock)   MODE="lock" ;;
    --unlock) MODE="unlock" ;;
    -h|--help)
      cat <<EOL
Usage: $(basename "$0") [OPTIONS]

Self-heal the bedtime-shutdown system. Enable-only: never stops/disables anything.

Options:
  -c, --config FILE   Alternative config file (default: /etc/bedtime-shutdown.conf).
  -n, --dry-run       Report what would change; write nothing (no root needed).
  -v, -vv             Increase verbosity (info, debug).
      --lock          Only chattr +i the protected bedtime files, then exit.
      --unlock        Only chattr -i the protected bedtime files, then exit.
  -h, --help          Show this help.

Default (no --lock/--unlock): re-enable bedtime.timer + bedtime-rearm.timer,
enforce ownership/mode (BSS_REARM_ENFORCE_PERMS), optionally immutability
(BSS_REARM_ENFORCE_IMMUTABLE) and PAM rules (BSS_REARM_ENFORCE_PAM).
EOL
      exit 0
    ;;
    *) _log_error "Unknown parameter [$1]."; exit 1 ;;
  esac
  shift
done
# }}} = ARGUMENT PARSING =====================================================

# {{{ = LOAD CONFIGURATION ===================================================
if [[ -f "$CONFIG_FILE" && -r "$CONFIG_FILE" ]]; then
  # shellcheck source=/etc/bedtime-shutdown.conf disable=SC1091
  source "$CONFIG_FILE"
elif [[ -f "$CONFIG_FILE" ]]; then
  _log_error "Config file [$CONFIG_FILE] not readable (run as root or use --dry-run with a readable config)."
  exit 1
else
  _log_error "Config file [$CONFIG_FILE] not found."
  exit 1
fi

[[ -z "$LOGFILE" && -n "${BSS_LOGFILE:-}" ]] && LOGFILE="$BSS_LOGFILE"
# Only keep the logfile if we can actually write to it (root); otherwise stay on
# stdout. Clear LOGFILE *before* logging about it, so __log does not try (and
# noisily fail) to append to the unwritable path.
if [[ -n "$LOGFILE" ]]; then
  if { [[ -f "$LOGFILE" && ! -w "$LOGFILE" ]]; } || { [[ ! -f "$LOGFILE" ]] && [[ ! -w "$(dirname "$LOGFILE")" ]]; }; then
    declare _unwritable_logfile="$LOGFILE"
    LOGFILE=""
    _log_debug "Logfile [$_unwritable_logfile] not writable; logging to stdout only."
    unset _unwritable_logfile
  fi
fi

declare BSS_USER_NAME="${BSS_USER_NAME:-}"
[[ -z "$BSS_USER_NAME" ]] && { _log_error "BSS_USER_NAME not set in config."; exit 1; }
# }}} = LOAD CONFIGURATION ===================================================

# {{{ = HELPERS ==============================================================
_require_root() {
  if [[ $EUID -ne 0 && "$DRY_RUN" != "true" ]]; then
    _log_error "Must run as root (except --dry-run). Try: sudo $0"
    exit 1
  fi
}

# Files whose state (owner/mode, and optionally immutability) is enforced.
# Format: "path|octal-mode", one per line.
_protected_files() {
  printf '%s\n' \
    "/opt/bin/bedtime-shutdown.sh|700" \
    "/opt/bin/bedtime-lib.sh|644" \
    "/opt/bin/bedtime-rearm.sh|700" \
    "/opt/bin/bedtime-lock|700" \
    "/opt/bin/bedtime-unlock|700" \
    "${CONFIG_FILE}|600" \
    "/etc/systemd/system/bedtime.service|644" \
    "/etc/systemd/system/bedtime.timer|644" \
    "/etc/systemd/system/bedtime-rearm.service|644" \
    "/etc/systemd/system/bedtime-rearm.timer|644"
}

# True if a file carries the immutable (i) attribute.
_is_immutable() {
  local -r path=$1
  [[ -e "$path" ]] || return 1
  lsattr -d "$path" 2>/dev/null | awk '{print $1}' | grep -q 'i'
}

_do_chattr() {
  local -r flag=$1 path=$2
  if [[ "$DRY_RUN" == "true" ]]; then _log "[DRY-RUN] would: chattr $flag $path"; return 0; fi
  chattr "$flag" "$path" 2>/dev/null || _log_warn "chattr $flag failed on $path (unsupported fs?)."
}

# Restore root:root and the expected mode, only when drifted (keeps re-runs quiet).
_fix_perms() {
  local -r path=$1 mode=$2
  [[ -e "$path" ]] || { _log_debug "skip perms (missing): $path"; return 0; }
  local cur_owner cur_mode
  cur_owner=$(stat -c '%U:%G' "$path" 2>/dev/null || echo '?')
  cur_mode=$(stat -c '%a' "$path" 2>/dev/null || echo '?')
  if [[ "$cur_owner" != "root:root" ]]; then
    _log "Fixing owner ($cur_owner -> root:root): $path"
    _do chown root:root "$path" || _log_warn "chown failed: $path"
  fi
  if [[ "$cur_mode" != "$mode" ]]; then
    _log "Fixing mode ($cur_mode -> $mode): $path"
    _do chmod "$mode" "$path" || _log_warn "chmod failed: $path"
  fi
}
# }}} = HELPERS ==============================================================

# {{{ = ACTIONS ==============================================================
# Ensure a unit is unmasked, enabled and active. Never disables.
_ensure_unit() {
  local -r unit=$1
  local state
  state=$(systemctl is-enabled "$unit" 2>/dev/null || true)
  if [[ "$state" == "masked" ]]; then
    _log "$unit is masked; unmasking."
    _do systemctl unmask "$unit" || _log_warn "unmask failed: $unit"
    state=$(systemctl is-enabled "$unit" 2>/dev/null || true)
  fi
  if [[ "$state" != "enabled" ]]; then
    _log "$unit not enabled ($state); enabling."
    _do systemctl enable "$unit" || _log_warn "enable failed: $unit"
  else
    _log_debug "$unit already enabled."
  fi
  if ! systemctl is-active --quiet "$unit" 2>/dev/null; then
    _log "$unit not active; starting."
    _do systemctl start "$unit" || _log_warn "start failed: $unit"
  else
    _log_debug "$unit already active."
  fi
}

# Enforce ownership/mode and (optionally) immutability of the protected files.
_enforce_state() {
  local -r enforce_perms="${BSS_REARM_ENFORCE_PERMS:-true}"
  local -r enforce_imm="${BSS_REARM_ENFORCE_IMMUTABLE:-false}"
  if [[ "$enforce_perms" != "true" && "$enforce_imm" != "true" ]]; then
    _log_debug "State enforcement disabled (perms and immutable both off)."
    return 0
  fi
  local path mode
  while IFS='|' read -r path mode; do
    [[ -e "$path" ]] || { _log_debug "skip (missing): $path"; continue; }
    if [[ "$enforce_imm" == "true" ]]; then
      # Must clear immutability before we can chown/chmod, then re-apply.
      _is_immutable "$path" && _do_chattr -i "$path"
      _fix_perms "$path" "$mode"
      _do_chattr +i "$path"
    else
      if _is_immutable "$path"; then
        _log_warn "$path is immutable but BSS_REARM_ENFORCE_IMMUTABLE=false; leaving as-is (use bedtime-unlock to edit)."
        continue
      fi
      [[ "$enforce_perms" == "true" ]] && _fix_perms "$path" "$mode"
    fi
  done < <(_protected_files)
}

# --lock / --unlock: only toggle immutability on the protected files.
_toggle_immutable() {
  local -r flag=$1   # +i or -i
  _require_root
  # Unlocking weakens the protection: gate it (locking never is).
  if [[ "$flag" == "-i" ]]; then
    # A real unlock must be judged by the deployed config, not a hand-picked one.
    if [[ $EUID -eq 0 && "$CONFIG_FILE" != /etc/bedtime-shutdown.conf ]]; then
      _log_error "--unlock as root only works with the deployed config (/etc/bedtime-shutdown.conf)."
      exit 1
    fi
    _tamper_gate "unlock" || exit 1
  fi
  local -r verb=$([[ "$flag" == "+i" ]] && echo "Locking" || echo "Unlocking")
  _log "$verb (chattr $flag) the protected bedtime files..."
  local path mode
  while IFS='|' read -r path mode; do
    [[ -e "$path" ]] || continue
    _do_chattr "$flag" "$path"
  done < <(_protected_files)
  _log "Done."
}
# }}} = ACTIONS ==============================================================

# {{{ = MAIN =================================================================
main() {
  case "$MODE" in
    lock)   _toggle_immutable "+i"; exit 0 ;;
    unlock) _toggle_immutable "-i"; exit 0 ;;
  esac

  _require_root
  # Server guard: do not re-enable timers or edit PAM on a listed server.
  if _is_server_host; then
    _log_error "Host '$(_bss_hostname)' is a known server (BSS_SERVER_HOSTS); refusing to re-arm. Uninstall bedtime-shutdown here."
    exit 0
  fi
  _log_info "Starting bedtime re-arm (config: $CONFIG_FILE, dry-run: $DRY_RUN)..."

  _ensure_unit "bedtime.timer"
  _ensure_unit "bedtime-rearm.timer"
  _enforce_state
  _reassert_pam

  _log_info "Re-arm complete."
}
main
# }}} = MAIN =================================================================
