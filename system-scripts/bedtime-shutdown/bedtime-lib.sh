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

# {{{ = SERVER GUARD =========================================================
# Hosts bedtime-shutdown must never act on (no poweroff, no sleep, no PAM edit).
# A constant here, not a config var, so it applies before any config exists.
# Matched against the full and the short hostname.
[[ -v BSS_SERVER_HOSTS ]] || declare -ra BSS_SERVER_HOSTS=(saito 11001001.org 11001001)

# Test overrides (BSS_TEST_*) are honoured for non-root runs only: as root they
# would be a one-word bypass (sudo lets an ALL-user set env vars on the command line).
_bss_test_env() { [[ $EUID -ne 0 && -n "${!1:-}" ]]; }

_bss_hostname() {
  if _bss_test_env BSS_TEST_HOSTNAME; then printf '%s' "$BSS_TEST_HOSTNAME"; return 0; fi
  uname -n
}

# True if this host is on the server list (deterministic; used at runtime).
_is_server_host() {
  local full short h
  full=$(_bss_hostname)
  short=${full%%.*}
  for h in "${BSS_SERVER_HOSTS[@]}"; do
    [[ "$full" == "$h" || "$short" == "$h" ]] && return 0
  done
  return 1
}

# True if sshd (or OpenSSH 9.8+ sshd-session) is an ancestor of this process.
# Walks the process tree because sudo strips the SSH_* variables.
_is_remote_session() {
  local pid=$$ comm
  while (( pid > 1 )); do
    comm=$(< "/proc/${pid}/comm") 2>/dev/null || return 1
    [[ "$comm" == sshd* ]] && return 0
    pid=$(awk '/^PPid:/ { print $2 }' "/proc/${pid}/status" 2>/dev/null) || return 1
    [[ -n "$pid" ]] || return 1
  done
  return 1
}

# True if anything suggests a graphical desktop: graphical default target, an
# enabled display manager, or a live x11/wayland login session (sway from a TTY).
_has_graphical_hint() {
  [[ "$(systemctl get-default 2>/dev/null)" == graphical.target ]] && return 0
  systemctl is-enabled --quiet display-manager.service 2>/dev/null && return 0
  local sid
  while read -r sid _; do
    [[ -n "$sid" ]] || continue
    [[ "$(loginctl show-session "$sid" -p Type --value 2>/dev/null)" =~ ^(x11|wayland)$ ]] && return 0
  done < <(loginctl list-sessions --no-legend 2>/dev/null)
  return 1
}

# Best-effort reasons this may be a server (one per line, none = looks fine).
# For install-time warnings only; never used to skip protection.
_server_signals() {
  _is_server_host && echo "hostname '$(_bss_hostname)' is on the server list (BSS_SERVER_HOSTS in bedtime-lib.sh)"
  _has_graphical_hint || echo "no graphical desktop: default target is '$(systemctl get-default 2>/dev/null)', no display manager, no x11/wayland session"
  _is_remote_session && echo "this is a remote (SSH) session - the target is the REMOTE machine"
  return 0
}

# Prominent red warning box on stderr: _warn_banner TITLE [LINE..]
_warn_banner() {
  local -r title=$1; shift
  local -r bar="!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  local line
  {
    printf '\n\033[1;41;97m%s\033[0m\n' "$bar"
    printf '\033[1;31m  %s\033[0m\n\n' "$title"
    for line in "$@"; do printf '\033[31m  %s\033[0m\n' "$line"; done
    printf '\033[1;41;97m%s\033[0m\n\n' "$bar"
  } >&2
}

# Ask the user to type this machine's hostname (full or short); 0 on a match.
# The "type the name to confirm" pattern: it makes you check WHICH host this is.
_confirm_hostname() {
  local -r want=$(_bss_hostname)
  local ans=""
  if ! { true <>/dev/tty; } 2>/dev/null; then
    _log_error "No terminal to confirm on; refusing."
    return 1
  fi
  printf "Type this machine's hostname to continue (anything else aborts): " >/dev/tty
  IFS= read -r ans </dev/tty || return 1
  [[ -n "$ans" && ( "$ans" == "$want" || "$ans" == "${want%%.*}" ) ]]
}
# }}} = SERVER GUARD =========================================================

# {{{ = TAMPER PROTECTION ====================================================
# Friction against impulsive bypasses (uninstall, unlock, redeploy) inside a
# protected daily window (BSS_TAMPER_START/END). Off when unset or invalid.
declare -ri BSS_TAMPER_MIN_GAP_MIN=60   # minimal unprotected time per day
declare -ri BSS_TAMPER_LEN_MIN=20 BSS_TAMPER_LEN_MAX=1000

_tamper_enabled() { [[ -n "${BSS_TAMPER_START:-}" || -n "${BSS_TAMPER_END:-}" ]]; }

_tamper_now() {
  if _bss_test_env BSS_TEST_NOW; then printf '%s' "${BSS_TEST_NOW//:/}"; return 0; fi
  date +%H%M
}

# Print every problem with the tamper settings (none = valid); 1 if invalid.
_tamper_validate() {
  local -r re='^([01][0-9]|2[0-3]):?[0-5][0-9]$'
  local -i bad=0 delay expiry gap
  if [[ ! "${BSS_TAMPER_START:-}" =~ $re || ! "${BSS_TAMPER_END:-}" =~ $re ]]; then
    echo "BSS_TAMPER_START/END must both be set as HHMM or HH:MM (got '${BSS_TAMPER_START:-}'-'${BSS_TAMPER_END:-}')"
    return 1
  fi
  gap=$(( ( $(_hhmm_to_min "$BSS_TAMPER_START") - $(_hhmm_to_min "$BSS_TAMPER_END") + 1440 ) % 1440 ))
  if (( gap < BSS_TAMPER_MIN_GAP_MIN )); then
    echo "the protected window $(_format_time "$BSS_TAMPER_START")-$(_format_time "$BSS_TAMPER_END") leaves only ${gap} min/day unprotected (minimum ${BSS_TAMPER_MIN_GAP_MIN}); uninstall/unlock would be (nearly) impossible"
    bad=1
  fi
  delay=${BSS_TAMPER_UNINSTALL_DELAY_H:-24}
  expiry=${BSS_TAMPER_REQUEST_EXPIRY_H:-72}
  if (( expiry < delay + 24 )); then
    echo "BSS_TAMPER_REQUEST_EXPIRY_H (${expiry}) must be >= BSS_TAMPER_UNINSTALL_DELAY_H + 24 ($(( delay + 24 ))), or a request may expire before an unprotected slot"
    bad=1
  fi
  if [[ ! "${BSS_TAMPER_CHALLENGE_MODE:-words}" =~ ^(words|chars)$ ]]; then
    echo "BSS_TAMPER_CHALLENGE_MODE must be 'words' or 'chars' (got '${BSS_TAMPER_CHALLENGE_MODE}')"
    bad=1
  fi
  return "$bad"
}

# True if tamper protection is configured, valid and the window is open now.
# An invalid config counts as OFF (with a warning): it must never lock you out.
_tamper_active() {
  _tamper_enabled || return 1
  local problems
  if ! problems=$(_tamper_validate); then
    _log_warn "Tamper protection config invalid, treated as OFF: ${problems//$'\n'/; }"
    return 1
  fi
  _in_window "$(_tamper_now)" "$BSS_TAMPER_START" "$BSS_TAMPER_END"
}

# True if tamper protection applies at all (configured + valid, not a server).
_tamper_applies() {
  _tamper_enabled || return 1
  _is_server_host && return 1
  _tamper_validate >/dev/null
}

_tamper_in_rescue() {
  systemctl is-active --quiet rescue.target 2>/dev/null \
    || systemctl is-active --quiet emergency.target 2>/dev/null \
    || [[ "$(systemctl is-system-running 2>/dev/null)" == maintenance ]]
}

# Log why ACTION is refused right now (inside the protected window).
_tamper_refuse() {
  local -r action=$1
  _log_error "Tamper protection: '$action' is blocked between $(_format_time "$BSS_TAMPER_START") and $(_format_time "$BSS_TAMPER_END")."
  _tamper_in_rescue && _log_error "Rescue/emergency mode does not lift this."
  _log_error "Sleep on it. Try again after $(_format_time "$BSS_TAMPER_END")."
}

# Gate for a weakening ACTION: 0 = may proceed (challenge passed, or protection
# not applicable), 1 = refused/aborted. Dry runs stop before the challenge.
_tamper_gate() {
  local -r action=$1
  if _is_server_host; then
    _log_warn "Server host ($(_bss_hostname)): tamper protection skipped for '$action'."
    return 0
  fi
  if ! _tamper_enabled; then
    _log_debug "Tamper protection not configured; '$action' allowed."
    return 0
  fi
  if _tamper_active; then _tamper_refuse "$action"; return 1; fi
  _tamper_validate >/dev/null || return 0   # invalid = off (warned above)
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    _log "[DRY-RUN] '$action' would now require the typing challenge."
    return 0
  fi
  _tamper_challenge "$action"
}
# }}} = TAMPER PROTECTION ====================================================

# {{{ = TYPING CHALLENGE =====================================================
# Random text: lowercase words (dictionary, else pronounceable pseudo-words) or
# 5-char [a-z0-9] groups; single spaces, no line breaks. _challenge_text LEN MODE
_challenge_text() {
  local -ri len=$1
  local -r mode=$2
  local -r cons="bcdfghjklmnprstvz" vows="aeiou" alnum="abcdefghijklmnopqrstuvwxyz0123456789"
  local -a dict=()
  local text="" word
  local -i i n
  if [[ "$mode" == words && -r /usr/share/dict/words ]]; then
    mapfile -t dict < <(grep -E '^[a-z]{3,8}$' /usr/share/dict/words 2>/dev/null || true)
  fi
  while (( ${#text} < len )); do
    word=""
    if [[ "$mode" == chars ]]; then
      for (( i = 0; i < 5; i++ )); do word+=${alnum:$(( ${SRANDOM:-$RANDOM} % 36 )):1}; done
    elif (( ${#dict[@]} >= 1000 )); then
      word=${dict[$(( ${SRANDOM:-$RANDOM} % ${#dict[@]} ))]}
    else
      n=$(( 2 + ${SRANDOM:-$RANDOM} % 2 ))   # 2-3 consonant-vowel syllables
      for (( i = 0; i < n; i++ )); do
        word+=${cons:$(( ${SRANDOM:-$RANDOM} % ${#cons} )):1}${vows:$(( ${SRANDOM:-$RANDOM} % ${#vows} )):1}
      done
      (( ${SRANDOM:-$RANDOM} % 3 == 0 )) && word+=${cons:$(( ${SRANDOM:-$RANDOM} % ${#cons} )):1}
    fi
    text+=${text:+ }$word
  done
  printf '%s' "$text"
}

# Typing-tutor overlay: the reference text is shown dim; each keystroke
# overwrites its cell in place (green = right, red = wrong), so input and
# reference always wrap identically. Backspace corrects, Enter is accepted only
# when everything is right, Ctrl-C aborts. Pasted input (bracketed paste, or a
# burst of >2 queued keys) is dropped. Talks to /dev/tty directly, so it works
# with stdout piped to a log. _tamper_challenge ACTION; 0 = passed.
_tamper_challenge() {
  local -r action=$1
  local -i len=${BSS_TAMPER_CHALLENGE_LENGTH:-200}
  (( len < BSS_TAMPER_LEN_MIN )) && len=BSS_TAMPER_LEN_MIN
  (( len > BSS_TAMPER_LEN_MAX )) && len=BSS_TAMPER_LEN_MAX
  local -r mode=${BSS_TAMPER_CHALLENGE_MODE:-words}
  local -ri max_err_pct=${BSS_TAMPER_CHALLENGE_MAX_ERRORS_PCT:-0}

  local -i tty
  if ! { : <>/dev/tty; } 2>/dev/null; then
    _log_error "Tamper protection: '$action' needs an interactive terminal for the typing challenge."
    return 1
  fi
  exec {tty}<>/dev/tty
  local saved_stty
  saved_stty=$(stty -g <&"$tty")
  # Restore the terminal however we leave (incl. Ctrl-C, which aborts the caller).
  # shellcheck disable=SC2064  # expand now: tty/saved_stty are locals
  trap "printf '\033[?2004l\033[0m\n' >&$tty; stty '$saved_stty' <&$tty; exit 130" INT TERM
  stty -echo -icanon min 1 time 0 <&"$tty"
  printf '\033[?2004h' >&"$tty"   # bracketed paste: pastes arrive wrapped in ESC[200~ .. ESC[201~

  local -i width rc=1
  width=$(stty size <&"$tty" 2>/dev/null | awk '{ print $2 }') || width=80
  (( width > 81 )) && width=81
  (( width < 30 )) && width=30
  width=$(( width - 1 ))   # never fill the last column (autowrap quirks)

  local text line word key seq burst status esc queued_key c_
  local -a words lines row col
  local -i i r c pos wrong errors nrows done_ok=0 queued
  while (( ! done_ok )); do
    text=$(_challenge_text "$len" "$mode")
    len=${#text}
    # Word-wrap; the space at a break stays at the end of its line.
    read -ra words <<<"$text"
    lines=() line=""
    for word in "${words[@]}"; do
      if [[ -z "$line" ]]; then line=$word
      elif (( ${#line} + 1 + ${#word} <= width )); then line+=" $word"
      else lines+=("$line "); line=$word
      fi
    done
    lines+=("$line")
    nrows=${#lines[@]}
    row=() col=() i=0
    for (( r = 0; r < nrows; r++ )); do
      for (( c = 0; c < ${#lines[r]}; c++ )); do row[i]=$r; col[i]=$c; i+=1; done
    done

    {
      printf '\n\033[1mTamper protection: type the text below to confirm "%s".\033[0m\n' "$action"
      printf 'Typos show red - fix them with Backspace. Enter confirms. Ctrl-C aborts. Pasting is ignored.\n\n'
      # Reserve the rows first (forces any scrolling now), then remember the origin.
      for (( i = 0; i < nrows + 2; i++ )); do printf '\n'; done
      printf '\033[%dA\0337' $(( nrows + 2 ))
      for line in "${lines[@]}"; do printf '\033[2m%s\033[0m\n' "$line"; done
    } >&"$tty"

    # Move the cursor to cell I (I == len: just after the last character).
    _ch_goto() {
      local -i gr gc
      if (( $1 < len )); then gr=${row[$1]} gc=${col[$1]}; else gr=${row[len-1]} gc=$(( ${col[len-1]} + 1 )); fi
      printf '\0338' >&"$tty"
      (( gr > 0 )) && printf '\033[%dB' "$gr" >&"$tty"
      (( gc > 0 )) && printf '\033[%dC' "$gc" >&"$tty"
      return 0
    }
    _ch_status() {
      printf '\0338\033[%dB\r\033[K%s' $(( nrows + 1 )) "$1" >&"$tty"
      _ch_goto "$pos"
    }

    pos=0 wrong=0 errors=0
    local -a typed=()
    status="0/${len} - Enter confirms, Ctrl-C aborts"
    _ch_status "$status"
    while :; do
      IFS= read -rsn1 -d '' -u "$tty" key || break
      # Burst = paste (or a scripted feed): more than 2 keys already queued.
      burst=""
      while read -t 0 -u "$tty" && IFS= read -rsn1 -d '' -t 0.005 -u "$tty" queued_key 2>/dev/null; do
        burst+=$queued_key
      done
      if (( ${#burst} > 2 )); then
        _ch_status $'\033[33mPaste ignored - type it.\033[0m'
        continue
      fi
      seq="$key$burst"
      for (( queued = 0; queued < ${#seq}; queued++ )); do
        key=${seq:queued:1}
        case "$key" in
          $'\e')
            # Bracketed paste start: swallow everything up to ESC[201~.
            esc=${seq:queued+1}
            while IFS= read -rsn1 -d '' -t 0.05 -u "$tty" c_; do esc+=$c_; [[ "$esc" =~ ^\[[0-9\;]*[~A-Za-z] ]] && break; done
            if [[ "$esc" == "[200~"* ]]; then
              while [[ "$esc" != *$'\e[201~' ]] && IFS= read -rsn1 -d '' -t 0.5 -u "$tty" c_; do esc+=$c_; done
              _ch_status $'\033[33mPaste ignored - type it.\033[0m'
            fi
            break   # rest of seq was part of the escape sequence
            ;;
          $'\n'|$'\r')
            if (( pos == len && wrong == 0 )); then done_ok=1; break 2; fi
            if (( wrong > 0 )); then
              _ch_status $'\033[31m'"${wrong} wrong character(s) left - fix them first."$'\033[0m'
            else
              _ch_status "Not finished: ${pos}/${len}."
            fi
            ;;
          $'\x7f'|$'\b')
            (( pos > 0 )) || continue
            pos=$(( pos - 1 ))
            [[ "${typed[pos]}" != "${text:pos:1}" ]] && wrong=$(( wrong - 1 ))
            _ch_goto "$pos"
            printf '\033[2m%s\033[0m' "${text:pos:1}" >&"$tty"
            _ch_status "${pos}/${len} - ${wrong} wrong"
            ;;
          [[:print:]])
            (( pos < len )) || continue
            typed[pos]=$key
            _ch_goto "$pos"
            if [[ "$key" == "${text:pos:1}" ]]; then
              printf '\033[32m%s\033[0m' "$key" >&"$tty"
            else
              # Show the EXPECTED character on red, so a wrong space is visible too.
              printf '\033[41;97m%s\033[0m' "${text:pos:1}" >&"$tty"
              wrong=$(( wrong + 1 )) errors=$(( errors + 1 ))
            fi
            pos=$(( pos + 1 ))
            if (( max_err_pct > 0 && errors * 100 > max_err_pct * len )); then
              _ch_status $'\033[31mToo many typos - new text.\033[0m'
              printf '\0338\033[%dB\n' $(( nrows + 2 )) >&"$tty"
              sleep 1
              continue 3
            fi
            _ch_status "${pos}/${len} - ${wrong} wrong"
            ;;
        esac
      done
    done
    break   # read failed (EOF)
  done

  printf '\0338\033[%dB\n\033[?2004l' $(( nrows + 2 )) >&"$tty"
  stty "$saved_stty" <&"$tty"
  trap - INT TERM
  exec {tty}>&-
  unset -f _ch_goto _ch_status
  if (( done_ok )); then
    _log "Typing challenge passed for '$action'."
    rc=0
  else
    _log_error "Typing challenge not completed; '$action' aborted."
  fi
  return "$rc"
}
# }}} = TYPING CHALLENGE =====================================================
