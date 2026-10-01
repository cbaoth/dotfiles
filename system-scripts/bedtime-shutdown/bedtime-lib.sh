# -*- mode: sh; sh-shell: bash; indent-tabs-mode: nil; tab-width: 2 -*-
# vim: ft=bash:et:ts=2:sts=2:sw=2
# code: language=bash insertSpaces=true tabSize=2
# shellcheck shell=bash disable=SC2148
#
# /opt/bin/bedtime-lib.sh - shared helpers for the bedtime-shutdown system.
# Sourced by bedtime-shutdown.sh (the every-5-min tick) and bedtime-rearm.sh.
# It relies on these globals being declared by the sourcing script BEFORE it is
# sourced: DRY_RUN, LOGFILE, SCRIPT_USER, VERBOSITY (and, for the PAM render,
# CONFIG_FILE + the BSS_* config vars). No shebang: this file is sourced, not run.

# {{{ = LOGGING ==============================================================
# Timestamped, colour-coded logging. Honours VERBOSITY (0 errors/warn/plain,
# 1 info, 2+ debug) and appends to LOGFILE when set. Level accepts short or long
# aliases (E/ERR/ERROR, W/WAR/WARN, I/INF/INFO, D/DEB/DEBUG); anything else is a
# plain, always-shown line.
__log() {
  declare -r __LOG_UNKNOWN_TIMESTAMP="????-??-?? ??:??:??"
  [[ $# -lt 2 ]] && { echo "Usage: __log LEVEL MESSAGE" >&2; return 1; }
  local -r level=$1; shift
  local -r msg="$*"
  local -r timestamp=$( date +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$__LOG_UNKNOWN_TIMESTAMP" )
  local -r timestamp_log=$( [[ -n "${LOGFILE:-}" ]] && date -Ins 2>/dev/null || echo "$__LOG_UNKNOWN_TIMESTAMP" )

  case "$level" in
    E|ERR|ERROR)
      echo -e "$timestamp [\033[31mERROR\033[0m] $msg" >&2
      [[ -n "${LOGFILE:-}" ]] && echo "$timestamp_log ERROR ${SCRIPT_USER}: $msg" >> "$LOGFILE" 2>/dev/null || true
      ;;
    W|WAR|WARN)
      echo -e "$timestamp [\033[33mWARN\033[0m]  $msg"
      [[ -n "${LOGFILE:-}" ]] && echo "$timestamp_log WARN  ${SCRIPT_USER}: $msg" >> "$LOGFILE" 2>/dev/null || true
      ;;
    I|INF|INFO)
      [[ "${VERBOSITY:-0}" -lt 1 ]] && return 0
      echo -e "$timestamp [\033[32mINFO\033[0m]  $msg"
      [[ -n "${LOGFILE:-}" ]] && echo "$timestamp_log INFO  ${SCRIPT_USER}: $msg" >> "$LOGFILE" 2>/dev/null || true
      ;;
    D|DEB|DEBUG)
      [[ "${VERBOSITY:-0}" -lt 2 ]] && return 0
      echo -e "$timestamp [\033[34mDEBUG\033[0m] $msg"
      [[ -n "${LOGFILE:-}" ]] && echo "$timestamp_log DEBUG ${SCRIPT_USER}: $msg" >> "$LOGFILE" 2>/dev/null || true
      ;;
    *)
      echo -e "$timestamp [*]     $msg"
      [[ -n "${LOGFILE:-}" ]] && echo "$timestamp_log *     ${SCRIPT_USER}: $msg" >> "$LOGFILE" 2>/dev/null || true
      ;;
  esac
}
_log()       { __log "" "$*"; }      # Always shown (no level)
_log_error() { __log "ERROR" "$*"; } # Always shown
_log_warn()  { __log "WARN"  "$*"; } # Always shown
_log_info()  { __log "INFO"  "$*"; } # Shown if VERBOSITY >= 1
_log_debug() { __log "DEBUG" "$*"; } # Shown if VERBOSITY >= 2

# Run a mutating command, or just log it in dry-run mode.
_do() {
  if [[ "${DRY_RUN:-false}" == "true" ]]; then _log "[DRY-RUN] would: $*"; return 0; fi
  "$@"
}
# }}} = LOGGING ==============================================================

# {{{ = TIME MATH ============================================================
# Convert HHMM / HH:MM to minutes since midnight (0-1439).
_hhmm_to_min() {
  local -r t="${1//:/}"
  printf "%d" "$(( 10#${t:0:2} * 60 + 10#${t:2:2} ))"
}

# Format an HHMM (or HH:MM) string as HH:MM.
_format_time() {
  local -r t="${1//:/}"
  printf "%s:%s" "${t:0:2}" "${t:2:2}"
}

# True (0) if `now` is within the half-open window [start, end), midnight-wrap
# aware. All args in HHMM / HH:MM form.
_in_window() {
  local -r now=$((10#${1//:/}))
  local -r start=$((10#${2//:/}))
  local -r end=$((10#${3//:/}))

  if (( start <= end )); then
    (( now >= start && now < end ))
  else
    (( now >= start || now < end ))
  fi
}

# Shift an HHMM / HH:MM time by +N minutes (wraps at midnight), echo as HHMM.
# Used to postpone the sleep/shutdown start times by a bedtime allowance delta.
_shift_hhmm() {
  local -ri base=$(_hhmm_to_min "$1")
  local -ri delta=${2:-0}
  local -ri m=$(( ( base + delta + 1440 ) % 1440 ))
  printf "%02d%02d" "$(( m / 60 ))" "$(( m % 60 ))"
}
# }}} = TIME MATH ============================================================

# {{{ = PAM RE-ASSERT ========================================================
# Re-assert the PAM time.conf rules inside a managed marker block (tail of file).
# Verify-only for common-account (editing it risks breaking pam-auth-update).
# Rules come verbatim from the BSS_PAM_BLOCK array; a clearly malformed line is
# warned-and-skipped so a bad rule can never lock the user out. Callable from
# both the re-arm (08/12/16+boot) and the tick (to apply an evening sudo grant).
_reassert_pam() {
  [[ "${BSS_REARM_ENFORCE_PAM:-false}" == "true" ]] || { _log_debug "PAM re-assert disabled."; return 0; }
  local -r conf="/etc/security/time.conf"
  local -r begin="# >>> bedtime-rearm managed >>> DO NOT EDIT BELOW THIS LINE"
  local -r end="# <<< bedtime-rearm managed <<<"

  if [[ ! -f "$conf" ]]; then
    _log_warn "$conf not found; skipping PAM re-assert."
    return 0
  fi

  # Enforcement point: without pam_time active in common-account the rules do
  # nothing. Refuse to write a rule that would give a false sense of security.
  if ! grep -Eq '^[[:space:]]*account[[:space:]]+(required|requisite)[[:space:]]+pam_time\.so' \
        /etc/pam.d/common-account 2>/dev/null; then
    _log_warn "pam_time.so is NOT active in /etc/pam.d/common-account; time.conf rules will not be enforced."
    _log_warn "Add 'account required pam_time.so' there (see README), then re-run. Skipping time.conf edit."
    return 0
  fi

  if [[ -z "${BSS_PAM_BLOCK+x}" ]] || (( ${#BSS_PAM_BLOCK[@]} == 0 )); then
    _log_warn "BSS_PAM_BLOCK is empty/unset; nothing to re-assert. Skipping time.conf edit."
    return 0
  fi

  local -a valid=()
  local line semis
  for line in "${BSS_PAM_BLOCK[@]}"; do
    [[ -z "${line//[[:space:]]/}" ]] && continue        # skip blank lines
    # Expect exactly 4 ';'-separated fields (logic operators & | add no ';').
    semis="${line//[^;]/}"
    if (( ${#semis} != 3 )); then
      _log_warn "PAM rule skipped (need 4 ';'-separated fields): $line"
      continue
    fi
    # pam_time times are HHMM with NO colon (man 5 time.conf); an HH:MM colon is
    # the classic footgun - refuse it rather than write a misparsing rule.
    if [[ "$line" =~ [0-9]:[0-9] ]]; then
      _log_warn "PAM rule skipped (colon in time; pam_time uses HHMM, e.g. 2100-0500): $line"
      continue
    fi
    valid+=("$line")
  done

  if (( ${#valid[@]} == 0 )); then
    _log_warn "No valid rules in BSS_PAM_BLOCK; leaving time.conf unchanged."
    return 0
  fi

  # Build the managed block from the validated rules (written verbatim).
  local block
  block="${begin}"$'\n'
  block+="# Regenerated by bedtime-rearm.sh from ${CONFIG_FILE} (BSS_PAM_BLOCK)."$'\n'
  block+="# Manual edits from the begin-marker to EOF are overwritten on re-arm."$'\n'
  block+="# pam_time ANDs all matching rules; format: <services>; <ttys>; <users>; <times>"$'\n'
  for line in "${valid[@]}"; do
    block+="${line}"$'\n'
  done
  block+="${end}"

  # Compose the desired file: everything above the begin-marker + the fresh block.
  # Trailing blank lines above the marker are trimmed so the single separator we
  # add is idempotent - otherwise each run would append one more blank line,
  # rewrite the file, and log "Updated" forever.
  local tmp
  tmp=$(mktemp) || { _log_error "mktemp failed."; return 1; }
  local -a above
  mapfile -t above < <(awk -v b="$begin" 'index($0,b){exit} {print}' "$conf")
  while (( ${#above[@]} > 0 )) && [[ -z "${above[-1]}" ]]; do
    unset 'above[-1]'
  done
  { (( ${#above[@]} > 0 )) && printf '%s\n' "${above[@]}"; printf '\n%s\n' "$block"; } > "$tmp"

  if cmp -s "$tmp" "$conf"; then
    _log_debug "time.conf managed block already current."
    rm -f "$tmp"
    return 0
  fi

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    _log "[DRY-RUN] would update managed block in $conf:"
    diff -u "$conf" "$tmp" 2>/dev/null || true
    rm -f "$tmp"
    return 0
  fi

  cp -a "$conf" "${conf}.bedtime.bak" 2>/dev/null && _log_debug "backed up -> ${conf}.bedtime.bak"
  install -m 0644 -o root -g root "$tmp" "$conf"
  rm -f "$tmp"
  _log "Updated PAM managed block in $conf."
}
# }}} = PAM RE-ASSERT ========================================================
