#!/bin/bash
# code: language=bash insertSpaces=true tabSize=2
#
# Bedtime Shutdown Script - Forces system shutdown at a configured time each night
# For installation and configuration, see README.adoc or run: sudo ./install.sh

# {{{ = COMMONS ==============================================================
# -e: exit on error
# -u: treat unset variables as an error
# -o pipefail: return exit code of the last command in the pipeline that failed
set -euo pipefail  # Fail if any command in a pipeline fails

# Global constants
declare -ri VERBOSITY_DEFAULT=0

# Global variables
declare CONFIG_FILE="/etc/bedtime-shutdown.conf"
declare DRY_RUN=false
declare LOGFILE=""   # Set via --logfile or BSS_LOGFILE config variable
declare SCRIPT_USER=$(whoami 2>/dev/null || echo "unknown")  # Get current user for logging context
declare -i VERBOSITY=$VERBOSITY_DEFAULT  # Effective verbosity after config/CLI merge
declare -i VERBOSITY_CLI=0               # Tracks CLI-requested verbosity before config merge

# Logging function with timestamp and colored levels
__log() {
  local level="$1"; shift
  local msg="$*"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local timestamp_log
  [[ -n "$LOGFILE" ]] && timestamp_log=$(date -Ins)

  case "$level" in
    E|ERR|ERROR)
      echo -e "$timestamp [\033[31mERROR\033[0m] $msg" >&2
      [[ -n "$LOGFILE" ]] && echo "$timestamp_log ERROR ${SCRIPT_USER}: $msg" >> "$LOGFILE" 2>/dev/null || true
      ;;
    W|WAR|WARN)
      echo -e "$timestamp [\033[33mWARN\033[0m]  $msg"
      [[ -n "$LOGFILE" ]] && echo "$timestamp_log WARN  ${SCRIPT_USER}: $msg" >> "$LOGFILE" 2>/dev/null || true
      ;;
    I|INF|INFO)
      [[ "$VERBOSITY" -lt 1 ]] && return 0  # Skip info messages if verbosity < 1
      echo -e "$timestamp [\033[32mINFO\033[0m]  $msg"
      [[ -n "$LOGFILE" ]] && echo "$timestamp_log INFO  ${SCRIPT_USER}: $msg" >> "$LOGFILE" 2>/dev/null || true
      ;;
    D|DEB|DEBUG)
      [[ "$VERBOSITY" -lt 2 ]] && return 0  # Skip debug messages if verbosity < 2
      echo -e "$timestamp [\033[34mDEBUG\033[0m] $msg"
      [[ -n "$LOGFILE" ]] && echo "$timestamp_log DEBUG ${SCRIPT_USER}: $msg" >> "$LOGFILE" 2>/dev/null || true
      ;;
    *)
      echo -e "$timestamp [*]     $msg"
      [[ -n "$LOGFILE" ]] && echo "$timestamp_log *     ${SCRIPT_USER}: $msg" >> "$LOGFILE" 2>/dev/null || true
      ;;
  esac
}
# Convenience wrappers
_log()       { __log "" "$*"; }      # Always shown (no level)
_log_error() { __log "ERROR" "$*"; } # Always shown
_log_warn()  { __log "WARN"  "$*"; } # Always shown
_log_info()  { __log "INFO"  "$*"; } # Shown if VERBOSITY >= 1
_log_debug() { __log "DEBUG" "$*"; } # Shown if VERBOSITY >= 2
# {{{ = COMMONS ==============================================================

# {{{ = ARGUMENT PARSING =====================================================
# Loop through arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -c|--config)
      [[ -z "$2" ]] && { _log_error "No config file specified after [$1]. Exiting ..."; exit 1; }
      [[ ! -f "$2" ]] && { _log_error "Config file [$2] not found. Exiting ..."; exit 1; }
      CONFIG_FILE="$2"; shift
    ;;
    -l|--logfile)
      [[ -z "$2" ]] && { _log_error "No logfile specified after [$1]. Exiting ..."; exit 1; }
      LOGFILE="$2"; shift
    ;;
    -n|--dry-run|--no-act)
      DRY_RUN=true
    ;;
    -v|-vv|-vvv|-vvvv)
      VERBOSITY_CLI=$((VERBOSITY_CLI + ${#1} - 1))
    ;;
    -q|--quiet)
      VERBOSITY_CLI=0
    ;;
    -h|--help)
      cat <<EOL
Usage: $(basename $0) [OPTIONS]

Options:
  -c, --config FILE        Specify an alternative configuration file (default: /etc/bedtime-shutdown.conf).
  -l, --logfile FILE       Write log output to specified file (overrides BSS_LOGFILE from config).
  -n, --no-act, --dry-run  Log shutdown command instead of executing it; all other logic executes normally.
  -v, --verbose            Increase verbosity level (can be specified multiple times, in short: -vvvv for full trace)
  -q, --quiet              Suppress debug output.
  -h, --help               Show this help message.

Verbosity Levels:
  0 (default)  Standard output
  1            Info output
  2            Debug output
  3            Debug output with set -v (shows commands before expansion)
  4            Debug output with set -x (shows command execution with expansions)
EOL
      exit 0
    ;;
    *)
      _log_error "Unknown parameter [$1]. Exiting ..."
      exit 1
    ;;
  esac
  shift
done
# }}} = ARGUMENT PARSING =====================================================

# {{{ = LOAD CONFIGURATION ===================================================
# Ensure config file exists and is readable, then source it
if [[ -f "$CONFIG_FILE" ]]; then
  _log_debug "Loading configuration file: $CONFIG_FILE"
  # In dry-run mode, check if config file is readable
  if [[ ! -r "$CONFIG_FILE" ]]; then
    _log_error "Config file [$CONFIG_FILE] is not readable by current user. Run as root or use --config to specify a readable config file. Exiting ..."
    exit 1
  fi
  source "$CONFIG_FILE"
else
  _log_error "Configuration file [$CONFIG_FILE] not found. Exiting ..."
  exit 1
fi

# Use BSS_LOGFILE from config if --logfile was not specified via CLI and config variable is set
[[ -z "$LOGFILE" && -n "${BSS_LOGFILE:-}" ]] && LOGFILE="$BSS_LOGFILE"

# Ensure logfile is writable if specified
if [[ -n "$LOGFILE" ]]; then
  # Check if we can write to the logfile or its directory
  if [[ -f "$LOGFILE" && ! -w "$LOGFILE" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      _log_warn "Logfile [$LOGFILE] is not writable in dry-run mode. Disabling logfile."
      LOGFILE=""
    else
      _log_error "Logfile [$LOGFILE] is not writable. Exiting ..."
      exit 1
    fi
  elif [[ ! -f "$LOGFILE" ]]; then
    LOGDIR=$(dirname "$LOGFILE")
    if [[ ! -w "$LOGDIR" ]]; then
      if [[ "$DRY_RUN" == "true" ]]; then
        _log_warn "Logfile directory [$LOGDIR] is not writable in dry-run mode. Disabling logfile."
        LOGFILE=""
      else
        _log_error "Logfile directory [$LOGDIR] is not writable. Exiting ..."
        exit 1
      fi
    fi
  fi
fi

# Log to file if configured
[[ -n "$LOGFILE" ]] && _log_info "Start logging to file: $LOGFILE"
# }}} = LOAD CONFIGURATION ===================================================

# {{{ = PRECONDITIONS ========================================================
# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  if [[ "$DRY_RUN" != "true" ]]; then
    _log_error "This script must be run as root (except in dry-run mode). Exiting ..."
    exit 1
  fi
  _log_debug "Running in dry-run mode as non-root user."
else
  _log_debug "Running as root user."
fi

# {{{ = CONFIG VALIDATION & VERBOSITY MERGE ==================================
# Validate optional verbosity minimum from config (default 0) and merge with CLI
declare -ri CONFIG_VERBOSITY_MIN=${BSS_VERBOSITY_MIN:-$VERBOSITY_DEFAULT}

if ! [[ "$CONFIG_VERBOSITY_MIN" =~ ^[0-9]+$ ]]; then
  _log_error "Invalid BSS_VERBOSITY_MIN ['$CONFIG_VERBOSITY_MIN'] - must be an integer between 0 and 4. Exiting ..."
  exit 1
fi

if (( CONFIG_VERBOSITY_MIN < 0 || CONFIG_VERBOSITY_MIN > 4 )); then
  _log_error "Invalid BSS_VERBOSITY_MIN [$CONFIG_VERBOSITY_MIN] - must be between 0 and 4. Exiting ..."
  exit 1
fi

# Effective verbosity is the higher of config min and CLI request
VERBOSITY=$(( VERBOSITY_CLI > CONFIG_VERBOSITY_MIN ? VERBOSITY_CLI : CONFIG_VERBOSITY_MIN ))
_log_debug "Effective verbosity: $VERBOSITY (config min=$CONFIG_VERBOSITY_MIN, cli=$VERBOSITY_CLI)"

# Apply debug options based on final verbosity
if [[ "$VERBOSITY" -ge 3 ]]; then
  set -v  # Print commands before expansion
fi
if [[ "$VERBOSITY" -ge 4 ]]; then
  set -x  # Print commands with expansions (debug mode)
fi
# }}} = CONFIG VALIDATION & VERBOSITY MERGE ==================================

# {{{ = INITIALIZATION =======================================================
# Get the user ID of BSS_USER_NAME (loaded from config)
if [[ -z "$BSS_USER_NAME" ]]; then
  _log_error "BSS_USER_NAME not set in config. Exiting ..."
  exit 1
fi

# Helper function to convert HHMM (24-hour) to HH:MM format (must be defined before use in logging)
_format_time() {
  printf "%s:%s" "${1:0:2}" "${1:2:2}"
}

# Get the user ID of BSS_USER_NAME
declare -r USER_ID=$(id -u "$BSS_USER_NAME")
_log_debug "Resolved user '$BSS_USER_NAME' to UID $USER_ID"

# Get current time as a number (e.g. 2130 for 21:30 or 9:30 PM)
declare -r CURRENT_TIME=$(date +%H%M)

# Force base-10 ((10#...)) to prevent bash from thinking "0800" is an octal number and crashing.
# Also strip any colons from time values to support both HHMM and HH:MM formats
declare -r NOW=$((10#$CURRENT_TIME))
declare -r START=$((10#${BSS_SHUTDOWN_START//:/}))  # Strip colons for HH:MM format support
declare -r END=$((10#${BSS_SHUTDOWN_END//:/}))      # Strip colons for HH:MM format support

_log_debug "Time check - NOW: $NOW ($(date '+%H:%M')), START: $START ($(_format_time ${BSS_SHUTDOWN_START//:/})), END: $END ($(_format_time ${BSS_SHUTDOWN_END//:/}))"
_log_debug "DRY_RUN: $DRY_RUN, VERBOSITY: $VERBOSITY"

if [[ "$DRY_RUN" == "true" ]]; then
  _log "DRY RUN MODE: Shutdown commands will be logged but not executed"
fi
# }}} = INITIALIZATION =======================================================

# {{{ = FUNCTIONS ============================================================
# Safe wrapper for systemctl poweroff - respects DRY_RUN mode
_poweroff() {
  local args=("$@")

  if [[ "$DRY_RUN" == "true" ]]; then
    _log "[DRY-RUN] Would execute: systemctl poweroff ${args[*]}"
    return 0
  fi

  _log "Executing: systemctl poweroff ${args[*]}"
  systemctl poweroff "${args[@]}"
}

# Sends a BEDTIME GUI notification to BSS_USER_NAME and broadcasts a message to all terminals.
_notify_user() {
  local msg="$*"
  _log_debug "Attempting to notify user [$BSS_USER_NAME] with message: $msg"

  # 1. GUI Notification
  # Ignore failure if user is not logged in, PAM blocked notifications, etc.
  # This is async via notify-send, so no need to wait
  _log_debug "Sending GUI notification to user '$BSS_USER_NAME': $msg"
  sudo -u "$BSS_USER_NAME" DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${USER_ID}/bus \
    notify-send --urgency=critical "BEDTIME" "$msg" 2>/dev/null || {
    _log_warn "GUI notification to user '$BSS_USER_NAME' failed (user may not be logged in)"
  }

  # 2. Terminal Broadcast
  _log_debug "Broadcasting wall message: BEDTIME: $msg"
  wall <<<"BEDTIME: $msg" 2>/dev/null || {
    _log_warn "wall broadcast failed (no terminal sessions available)"
  }
}

# Exits the script if we are in the "Safe Zone" (no shutdown allowed)
_exit_if_safe_zone() {
  local is_safe=0

  _log_debug "Checking if current time is within safe zone..."
  _log_debug "Time boundaries - NOW: $NOW, START: $START, END: $END"

  # Case 1: Standard day `START > END` (e.g. 05:00 to 21:30)
  if (( START > END )); then
    _log_debug "Standard schedule mode (START > END): Safe zone is [END=$END, START=$START)"
    if (( NOW >= END && NOW < START )); then
      is_safe=1
      _log_debug "Current time $NOW is within safe zone"
    fi
  # Case 2: Wrapping over midnight `START < END` (e.g. 21:30 to 05:00)
  else
    _log_debug "Wrapping schedule mode (START < END): Safe zone is [END=$END or NOW < START=$START)"
    # Safe if it's AFTER morning start OR BEFORE night shutdown
    if (( NOW >= END || NOW < START )); then
      is_safe=1
      _log_debug "Current time $NOW is within safe zone"
    fi
  fi

  if (( is_safe == 1 )); then
      _log "Current time ($(_format_time $CURRENT_TIME)) is within the safe window [$(_format_time ${BSS_SHUTDOWN_END//:/}) to $(_format_time ${BSS_SHUTDOWN_START//:/})]. Skipping shutdown."
      exit 0
  else
    _log_debug "Current time is within shutdown window. Proceeding with checks."
  fi
}

# Exits the script if one of the emergency overrides is enabled
_exit_if_emergency_override() {
  _log_debug "Checking emergency override conditions..."

  # 1. Check for USB Label (Hardware Key with specific LABEL is present)
  # Syntax: [[ -n "$VAR" ]] checks if variable is set and not empty
  if [[ -n "${BSS_EMERGENCY_OVERRIDE_BLOCK_DEVICE_LABEL:-}" ]]; then
    _log_debug "Checking for block device with label: $BSS_EMERGENCY_OVERRIDE_BLOCK_DEVICE_LABEL"
    # We use lsblk to check all block device labels
    if lsblk -o LABEL -n 2>/dev/null | grep -Fqx "$BSS_EMERGENCY_OVERRIDE_BLOCK_DEVICE_LABEL"; then
      _log "Emergency override triggered: Block device with label '$BSS_EMERGENCY_OVERRIDE_BLOCK_DEVICE_LABEL' detected"
      _notify_user "EMERGENCY OVERRIDE: Hardware key with label '$BSS_EMERGENCY_OVERRIDE_BLOCK_DEVICE_LABEL' detected. Skipping shutdown."
      exit 0
    else
      _log_debug "No matching block device label found"
    fi
  fi

  # 2. Check for specific file on mounted media (Hardware Key with specific FILE is present)
  if [[ -n "${BSS_EMERGENCY_OVERRIDE_FILE_MEDIA_DIR:-}" ]] && [[ -n "${BSS_EMERGENCY_OVERRIDE_FILE_NAME:-}" ]]; then
    _log_debug "Checking for emergency override file '$BSS_EMERGENCY_OVERRIDE_FILE_NAME' in '$BSS_EMERGENCY_OVERRIDE_FILE_MEDIA_DIR'"
    # Only run find if the media directory actually exists (stick is mounted)
    if [[ -d "$BSS_EMERGENCY_OVERRIDE_FILE_MEDIA_DIR" ]]; then
      # Find the file on the mounted media (max depth 2 to allow for root or 1-level subdirectory)
      local first_override_file="$(find "$BSS_EMERGENCY_OVERRIDE_FILE_MEDIA_DIR" -maxdepth 2 -name "$BSS_EMERGENCY_OVERRIDE_FILE_NAME" -print -quit | head -n 1 2>/dev/null)"
      if [[ -n "$first_override_file" ]]; then
        _log "Emergency override triggered: File '${first_override_file}' detected"
        _notify_user "EMERGENCY OVERRIDE: Hardware key with file '${first_override_file}' detected. Skipping shutdown."
        exit 0
      else
        _log_debug "No matching emergency override file found in $BSS_EMERGENCY_OVERRIDE_FILE_MEDIA_DIR"
      fi
    else
      _log_debug "Media directory '$BSS_EMERGENCY_OVERRIDE_FILE_MEDIA_DIR' not found or not mounted"
    fi
  fi

  # 3. Check for specific USB Device ID (lsusb)
  if [[ -n "${BSS_EMERGENCY_OVERRIDE_USB_ID:-}" ]]; then
    _log_debug "Checking for USB device with ID: $BSS_EMERGENCY_OVERRIDE_USB_ID"
    # Search for specific USB device ID (format: "1234:abcd")
    if lsusb -d "$BSS_EMERGENCY_OVERRIDE_USB_ID" >/dev/null 2>&1; then
      _log "Emergency override triggered: USB device '$BSS_EMERGENCY_OVERRIDE_USB_ID' detected"
      _notify_user "EMERGENCY OVERRIDE: USB Device '$BSS_EMERGENCY_OVERRIDE_USB_ID' detected. Skipping shutdown."
      exit 0
    else
      _log_debug "No matching USB device found"
    fi
  fi

  _log_debug "All emergency override checks passed"
}

# Attempts to cleanly unmount specified filesystems before forced shutdown
# This is a best-effort operation to prevent dirty flags on NTFS/exFAT partitions
_cleanup_mounts() {
  # Check if cleanup is enabled
  if [[ -z "${BSS_CLEANUP_MOUNTS[@]:-}" ]] || [[ "${#BSS_CLEANUP_MOUNTS[@]}" -eq 0 ]]; then
    _log_debug "Mount cleanup disabled (BSS_CLEANUP_MOUNTS is empty)"
    return 0
  fi

  _log_info "Starting mount cleanup before forced shutdown..."
  _log_debug "Cleanup settings: strategy=${BSS_CLEANUP_STRATEGY:-force-lazy}, stop_automount=${BSS_CLEANUP_STOP_AUTOMOUNT:-true}, kill_processes=${BSS_CLEANUP_KILL_PROCESSES:-true}"

  # Expand glob patterns and collect actual mount points
  local mount_candidates=()
  local pattern
  for pattern in "${BSS_CLEANUP_MOUNTS[@]}"; do
    _log_debug "Processing pattern: $pattern"

    # Expand glob pattern (disable error on no match)
    shopt -s nullglob
    local expanded=($pattern)
    shopt -u nullglob

    if [[ "${#expanded[@]}" -eq 0 ]]; then
      _log_debug "Pattern '$pattern' matched no paths"
      # If it's not a glob pattern (no wildcards), add it directly
      if [[ ! "$pattern" =~ [*?\[] ]]; then
        mount_candidates+=("$pattern")
      fi
    else
      _log_debug "Pattern '$pattern' expanded to ${#expanded[@]} path(s)"
      mount_candidates+=("${expanded[@]}")
    fi
  done

  # Filter: Only keep paths that are actually mounted
  local mounted_targets=()
  local candidate
  for candidate in "${mount_candidates[@]}"; do
    if mountpoint -q "$candidate" 2>/dev/null; then
      mounted_targets+=("$candidate")
      _log_debug "Mount point confirmed: $candidate"
    else
      _log_debug "Skipping '$candidate' (not mounted or doesn't exist)"
    fi
  done

  if [[ "${#mounted_targets[@]}" -eq 0 ]]; then
    _log_info "No mounted filesystems found to clean up"
    return 0
  fi

  _log "Found ${#mounted_targets[@]} mounted filesystem(s) to unmount: ${mounted_targets[*]}"

  # =============================================================================
  # PHASE 1: Stop systemd automount units to prevent re-mounting
  # =============================================================================
  if [[ "${BSS_CLEANUP_STOP_AUTOMOUNT:-true}" == "true" ]]; then
    _log_info "PHASE 1: Stopping automount units..."
    local mount_point
    for mount_point in "${mounted_targets[@]}"; do
      local unit_name=$(systemd-escape --path --suffix=automount "$mount_point" 2>/dev/null || true)
      if [[ -n "$unit_name" ]]; then
        if systemctl is-active --quiet "$unit_name" 2>/dev/null; then
          _log_info "Stopping automount trigger: $unit_name"
          if [[ "$DRY_RUN" == "true" ]]; then
            _log "[DRY-RUN] Would execute: systemctl stop '$unit_name'"
          else
            systemctl stop "$unit_name" 2>/dev/null || _log_warn "Failed to stop automount unit: $unit_name"
          fi
        else
          _log_debug "Automount unit '$unit_name' not active"
        fi
      fi
    done
  else
    _log_debug "Skipping automount cleanup (disabled)"
  fi

  # =============================================================================
  # PHASE 2: Kill processes using the filesystems
  # =============================================================================
  if [[ "${BSS_CLEANUP_KILL_PROCESSES:-true}" == "true" ]]; then
    _log_info "PHASE 2: Terminating processes using the filesystems..."

    # Check if fuser is available
    if ! command -v fuser >/dev/null 2>&1; then
      _log_warn "fuser command not found. Skipping process termination (install 'psmisc' package)."
    else
      # SIGTERM (graceful)
      _log_info "Sending SIGTERM to processes..."
      if [[ "$DRY_RUN" == "true" ]]; then
        _log "[DRY-RUN] Would execute: fuser -k -TERM -m ${mounted_targets[*]}"
      else
        fuser -k -TERM -m "${mounted_targets[@]}" >/dev/null 2>&1 || true
        _log_debug "Waiting 1 second for graceful termination..."
        sleep 1
      fi

      # SIGKILL (forceful)
      _log_info "Sending SIGKILL to remaining processes..."
      if [[ "$DRY_RUN" == "true" ]]; then
        _log "[DRY-RUN] Would execute: fuser -k -KILL -m ${mounted_targets[*]}"
      else
        fuser -k -KILL -m "${mounted_targets[@]}" >/dev/null 2>&1 || true
        _log_debug "Waiting 1 second for kernel to release file handles..."
        sleep 1
      fi
    fi
  else
    _log_debug "Skipping process termination (disabled)"
  fi

  # =============================================================================
  # PHASE 3: Sync disk buffers BEFORE unmounting
  # =============================================================================
  _log_info "PHASE 3: Syncing buffers to disk (this may take a while)..."
  if [[ "$DRY_RUN" == "true" ]]; then
    _log "[DRY-RUN] Would execute: sync"
  else
    sync
    _log "Disk sync completed"
  fi

  # =============================================================================
  # PHASE 4: Unmount filesystems (try clean first, then force-lazy)
  # =============================================================================
  _log_info "PHASE 4: Unmounting filesystems..."
  local mount_point
  for mount_point in "${mounted_targets[@]}"; do
    _log_info "Unmounting: $mount_point"

    if [[ "$DRY_RUN" == "true" ]]; then
      _log "[DRY-RUN] Would execute: umount '$mount_point' (or umount -f -l on failure)"
      continue
    fi

    # Attempt 1: Clean unmount
    if umount "$mount_point" 2>/dev/null; then
      _log "Successfully unmounted: $mount_point"
    else
      # Attempt 2: Force + Lazy unmount
      _log_warn "Standard unmount failed for '$mount_point'. Retrying with force+lazy..."
      local unmount_opts
      case "${BSS_CLEANUP_STRATEGY:-force-lazy}" in
        force-lazy)
          unmount_opts="-f -l"
          ;;
        lazy|*)
          unmount_opts="-l"
          ;;
      esac

      if umount $unmount_opts "$mount_point" 2>/dev/null; then
        _log "Successfully unmounted (with $unmount_opts): $mount_point"
      else
        _log_error "Failed to unmount '$mount_point' completely (will proceed anyway)"
      fi
    fi
  done

  # =============================================================================
  # PHASE 5: Final sync (additional safety measure)
  # =============================================================================
  if [[ ${BSS_CLEANUP_SYNC_COUNT:-2} -gt 0 ]]; then
    _log_info "PHASE 5: Final disk buffer flush (${BSS_CLEANUP_SYNC_COUNT:-2} sync calls)..."
    local sync_delay="${BSS_CLEANUP_SYNC_DELAY:-1}"
    local i
    for ((i=1; i<=${BSS_CLEANUP_SYNC_COUNT:-2}; i++)); do
      if [[ "$DRY_RUN" == "true" ]]; then
        _log "[DRY-RUN] Would execute: sync (call $i/${BSS_CLEANUP_SYNC_COUNT:-2})"
      else
        _log_debug "Sync call $i/${BSS_CLEANUP_SYNC_COUNT:-2}"
        sync
      fi
      [[ $i -lt ${BSS_CLEANUP_SYNC_COUNT:-2} ]] && sleep "$sync_delay"
    done
  fi

  _log_info "Mount cleanup completed"
}

# Main function
main() {
  _log_info "Starting bedtime shutdown sequence..."
  _log_debug "Configuration: User=$BSS_USER_NAME, Grace periods: user=${BSS_GRACE_PERIOD_USER}s, system=${BSS_GRACE_PERIOD_SYSTEM}s"

  # 1. Run all checks
  _exit_if_safe_zone
  _exit_if_emergency_override

  _log "All safety checks passed. Proceeding with shutdown sequence."

  # 2. Notifications & User Grace Period
  _log "Notifying user. Grace period: ${BSS_GRACE_PERIOD_USER} seconds"
  _notify_user "Shutting down in ${BSS_GRACE_PERIOD_USER} seconds. Save your work."

  if [[ "$BSS_GRACE_PERIOD_USER" -gt 0 ]]; then
    _log_info "Waiting ${BSS_GRACE_PERIOD_USER} seconds before proceeding to shutdown..."
    sleep $BSS_GRACE_PERIOD_USER
  fi

  # 3. Shutdown Sequence
  _log "User grace period complete. Proceeding to shutdown."
  _notify_user "Shutting down now!"

  # Stage 1: Polite but firm (Ignore Inhibitors, Non-blocking)
  # -i | --ignore-inhibitors: Ignore inhibitors (e.g. "stay awake" apps like Caffeine)
  # --no-block: Send the command and returns IMMEDIATELY (asynchronous), don't wait for response.
  _log_info "Stage 1 (Polite): Initiating graceful shutdown..."
  _poweroff --ignore-inhibitors --no-block

  # Stage 2: System Grace Period (Wait for graceful shutdown)
  # Skip if BSS_GRACE_PERIOD_SYSTEM is set to 0 or less.
  if [[ $BSS_GRACE_PERIOD_SYSTEM -gt 0 ]]; then
    _log_info "Waiting ${BSS_GRACE_PERIOD_SYSTEM} seconds for graceful shutdown..."
    sleep $BSS_GRACE_PERIOD_SYSTEM

    # Stage 3: Pre-shutdown Cleanup (Best-effort unmount)
    # Attempt to cleanly unmount specified filesystems to prevent dirty flags
    _cleanup_mounts

    # Stage 4: Nuclear Option (Force Force)
    # If we are still running, instantly "pull the power plug" (software equivalent).
    # -ff | --force --force (doubled): Tell the kernel to "power off" immediately
    # This bypasses all systemd shutdown scripts, unmounting, etc.
    _log "Stage 4 (Force): Forcing immediate shutdown..."
    _poweroff --force --force
  else
    _log_info "System grace period is <= 0. Force fallback disabled."
  fi
}
# }}} = FUNCTIONS ============================================================

# Invoke the main function
main
