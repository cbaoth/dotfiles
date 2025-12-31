#!/bin/bash

# {{{ = DOC: BASIC SETUP =====================================================
# 1. Optional: Create a test config, adjust it to your needs and perform a dry
#      run (without root deployment or actual shutdown):
# > cp etc/bedtime-shutdown.conf /tmp/bedtime-shutdown.conf
# > editor /tmp/bedtime-shutdown.conf
# > ./bedtime-shutdown.sh --config /tmp/bedtime-shutdown.conf --dry-run -v -v
# # Note: Dry-run with a readable config can run as non-root for safe testing.
# # Adjust config as needed until satisfied with the dry-run output.
#
# 2. Put this file into `/opt/bin/bedtime-shutdown.sh`
# > sudo mkdir -p /opt/bin
# > sudo cp bedtime-shutdown.sh /opt/bin/bedtime-shutdown.sh
# Note: sudo cp can potentially change ownership and/or permissions in case
# the file already exists (e.g. on updates). To prevent that, you may use:
# > sudo tee /opt/bin/bedtime-shutdown.sh < bedtime-shutdown.sh >/dev/null
#
# 3. Copy and adjust the configuration file
# > sudo cp etc/bedtime-shutdown.conf /etc/bedtime-shutdown.conf
# > sudo editor /etc/bedtime-shutdown.conf
# # Adjust the configuration values as needed.
#
# 4. Ensure limited file access:
#> sudo chown root:root /opt/bin/bedtime-shutdown.sh
#> sudo chmod 700 /opt/bin/bedtime-shutdown.sh
#  # Optional: Make immutable to prevent accidental changes (use `-i` to remove):
#> sudo chattr +i /opt/bin/bedtime-shutdown.sh
#> sudo chown root:root /etc/bedtime-shutdown.conf
#> sudo chmod 600 /etc/bedtime-shutdown.conf
#
# 5. Setup service:
# > sudo tee /etc/systemd/system/bedtime.service <<EOF
#[Unit]
#Description=Bedtime Shutdown Script
#[Service]
#Type=simple
#ExecStart=/opt/bin/bedtime-shutdown.sh
#EOF
#
# 6. Setup service timer:
#> sudo tee /etc/systemd/system/bedtime.timer <<EOF
#[Unit]
#Description=Run Bedtime Script at 21:30
#[Timer]
#OnCalendar=*-*-* 21:30:00
#Persistent=true
#
#[Install]
#WantedBy=timers.target
#EOF
# > sudo systemctl enable --now bedtime.timer
#
# # In case you make changes to the systemd service or timer files, reload and check as needed:
# > sudo systemctl daemon-reload
# > sudo systemctl status bedtime.service
# > sudo systemctl restart bedtime.timer
# > sudo systemctl status bedtime.timer
# }}} = DOC: BASIC SETUP =====================================================

# {{{ = COMMONS ==============================================================
# Logging function with timestamp and colored levels
SCRIPT_USER=$(whoami 2>/dev/null || echo "unknown")
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
      [[ -n "$LOGFILE" ]] && echo "$timestamp_log WARN ${SCRIPT_USER}: $msg" >> "$LOGFILE" 2>/dev/null || true
      ;;
    D|DEB|DEBUG)
      [[ "$VERBOSITY" -lt 2 ]] && return 0  # Skip debug messages if verbosity < 2
      echo -e "$timestamp [\033[34mDEBUG\033[0m] $msg"
      [[ -n "$LOGFILE" ]] && echo "$timestamp_log DEBUG ${SCRIPT_USER}: $msg" >> "$LOGFILE" 2>/dev/null || true
      ;;
    *) # Currently no distinct INFO level (vs. standard output level)
      echo -e "$timestamp [INFO]  $msg"
      [[ -n "$LOGFILE" ]] && echo "$timestamp_log INFO ${SCRIPT_USER}: $msg" >> "$LOGFILE" 2>/dev/null || true
      ;;
  esac
}
# Convenience wrappers
_log_error() { __log "ERROR" "$*"; }
_log_warn()  { __log "WARN"  "$*"; }
_log_info()  { __log "INFO"  "$*"; }
_log_debug() { __log "DEBUG" "$*"; }
_log()       { __log "" "$*"; } # Currently equivalent to _log_info (no distinct INFO level)
# {{{ = COMMONS ==============================================================

# {{{ = ARGUMENT PARSING =====================================================
CONFIG_FILE="/etc/bedtime-shutdown.conf"
DRY_RUN=false
VERBOSITY=0  # 0=normal, 1=verbose, 2+=debug
LOGFILE=""   # Set via --logfile or BSS_LOGFILE config variable

# Loop through arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -c|--config)
      [[ -z "$2" ]] && _log_error "No config file specified after [$1]. Exiting ..." && exit 1
      [[ ! -f "$2" ]] && _log_error "Config file [$2] not found. Exiting ..." && exit 1
      CONFIG_FILE="$2"; shift
    ;;
    -l|--logfile)
      [[ -z "$2" ]] && _log_error "No logfile specified after [$1]. Exiting ..." && exit 1
      LOGFILE="$2"; shift
    ;;
    -n|--dry-run|--no-act)
      DRY_RUN=true
    ;;
    -v|--verbose)
      VERBOSITY=$((VERBOSITY + 1))
    ;;
    -q|--quiet)
      VERBOSITY=0
    ;;
    -h|--help)
      cat <<EOL
Usage: $(basename $0) [OPTIONS]

Options:
  -c, --config FILE        Specify an alternative configuration file (default: /etc/bedtime-shutdown.conf).
  -l, --logfile FILE       Write log output to specified file (overrides BSS_LOGFILE from config).
  -n, --no-act, --dry-run  Log shutdown command instead of executing it; all other logic executes normally.
  -v, --verbose            Increase verbosity level (can be specified multiple times).
  -q, --quiet              Suppress debug output.
  -h, --help               Show this help message.

Verbosity Levels:
  0 (default)  Normal output
  1            Verbose output with set -v (shows commands before expansion)
  2+           Debug output with set -x (shows command execution with expansions)
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

# Apply debug options based on verbosity
if [[ "$VERBOSITY" -ge 1 ]]; then
  _log_info "Verbosity level: $VERBOSITY"
  set -v  # Print commands before expansion
fi
if [[ "$VERBOSITY" -ge 2 ]]; then
  set -x  # Print commands with expansions (debug mode)
fi
# }}} = ARGUMENT PARSING =====================================================

# {{{ = PRECONDITIONS CHECKS =================================================
# Check if we need root privileges
# Root is required for:
# - Executing systemctl poweroff (production mode)
# - Using sudo to send notifications to other users
# - Using wall to broadcast to all terminals
# - Reading the config file if it has restricted permissions (default: 600 root:root)
#
# In dry-run mode with a readable config file, root is not strictly required
# since systemctl poweroff won't execute and notification failures are handled gracefully.
if [[ $EUID -ne 0 ]]; then
  # Not root - check if we can proceed anyway
  if [[ "$DRY_RUN" != "true" ]]; then
    _log_error "This script must be run as root (non-dry-run mode requires root for systemctl poweroff). Exiting ..."
    exit 1
  fi

  # In dry-run mode, check if config file is readable
  if [[ ! -r "$CONFIG_FILE" ]]; then
    _log_error "Config file [$CONFIG_FILE] is not readable by current user. Run as root or use --config to specify a readable config file. Exiting ..."
    exit 1
  fi

  # We can proceed without root in dry-run mode
  _log_warn "Running in dry-run mode as non-root user (notifications and wall may fail, but this is safe for testing)"
else
  _log_debug "Running as root"
fi
# }}} = PRECONDITIONS CHECKS =================================================

# {{{ = LOAD CONFIGURATION ===================================================
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck source=/etc/bedtime-shutdown.conf
  source "$CONFIG_FILE"
else
  _log_error "Configuration file [$CONFIG_FILE] not found. Exiting ..."
  exit 1
fi

# Use BSS_LOGFILE from config if --logfile was not specified via CLI and config variable is set
[[ -z "$LOGFILE" && -n "${BSS_LOGFILE:-}" ]] && LOGFILE="$BSS_LOGFILE"

# In dry-run mode as non-root, verify logfile is writable if specified
if [[ -n "$LOGFILE" && "$DRY_RUN" == "true" && $EUID -ne 0 ]]; then
  # Check if we can write to the logfile or its directory
  if [[ -f "$LOGFILE" && ! -w "$LOGFILE" ]]; then
    _log_warn "Logfile [$LOGFILE] is not writable in dry-run mode. Disabling logfile."
    LOGFILE=""
  elif [[ ! -f "$LOGFILE" ]]; then
    LOGDIR=$(dirname "$LOGFILE")
    if [[ ! -w "$LOGDIR" ]]; then
      _log_warn "Logfile directory [$LOGDIR] is not writable in dry-run mode. Disabling logfile."
      LOGFILE=""
    fi
  fi
fi

# Log to file if configured
[[ -n "$LOGFILE" ]] && _log_debug "Logging to file: $LOGFILE"
# }}} = LOAD CONFIGURATION ===================================================

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
USER_ID=$(id -u "$BSS_USER_NAME")
_log_debug "Resolved user '$BSS_USER_NAME' to UID $USER_ID"

# Get current time as a number (e.g. 2130 for 21:30 or 9:30 PM)
CURRENT_TIME=$(date +%H%M)

# Force base-10 ((10#...)) to prevent bash from thinking "0800" is an octal number and crashing.
# Also strip any colons from time values to support both HHMM and HH:MM formats
NOW=$((10#$CURRENT_TIME))
START=$((10#${BSS_SHUTDOWN_START//:/}))  # Strip colons for HH:MM format support
END=$((10#${BSS_SHUTDOWN_END//:/}))      # Strip colons for HH:MM format support

_log_debug "Time check - NOW: $NOW ($(date '+%H:%M')), START: $START ($(_format_time ${BSS_SHUTDOWN_START//:/})), END: $END ($(_format_time ${BSS_SHUTDOWN_END//:/}))"
_log_debug "DRY_RUN: $DRY_RUN, VERBOSITY: $VERBOSITY"

if [[ "$DRY_RUN" == "true" ]]; then
  _log_info "DRY RUN MODE: Shutdown commands will be logged but not executed"
fi
# }}} = INITIALIZATION =======================================================

# {{{ = FUNCTIONS ============================================================
# Safe wrapper for systemctl poweroff - respects DRY_RUN mode
_poweroff() {
  local args=("$@")

  if [[ "$DRY_RUN" == "true" ]]; then
    _log_info "[DRY-RUN] Would execute: systemctl poweroff ${args[*]}"
    return 0
  fi

  _log_info "Executing: systemctl poweroff ${args[*]}"
  systemctl poweroff "${args[@]}"
}

# Sends a BEDTIME GUI notification to BSS_USER_NAME and broadcasts a message to all terminals.
_notify_user() {
  local msg="$*"
  _log_debug "Attempting to notify user [$BSS_USER_NAME] with message: $msg"

  # 1. GUI Notification
  # Ignore failure if user is not logged in, PAM blocked notifications, etc.
  # This is async via notify-send, so no need to wait
  _log_info "Sending GUI notification to user '$BSS_USER_NAME': $msg"
  sudo -u "$BSS_USER_NAME" DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${USER_ID}/bus \
    notify-send --urgency=critical "BEDTIME" "$msg" 2>/dev/null || {
    _log_warn "GUI notification to user '$BSS_USER_NAME' failed (user may not be logged in)"
  }

  # 2. Terminal Broadcast
  _log_info "Broadcasting wall message: BEDTIME: $msg"
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
    _log_info "Current time is within shutdown window. Proceeding with checks."
  fi
}

# Exits the script if one of the emergency overrides is enabled
_exit_if_emergency_override() {
  _log_debug "Checking emergency override conditions..."

  # 1. Check for USB Label (Hardware Key with specific LABEL is present)
  # Syntax: [[ -n "$VAR" ]] checks if variable is set and not empty
  if [[ -n "${BSS_EMERGENCY_OVERRIDE_BLOCK_DEVICE_LABEL:-}" ]]; then
    _log_info "Checking for block device with label: $BSS_EMERGENCY_OVERRIDE_BLOCK_DEVICE_LABEL"
    # We use lsblk to check all block device labels
    if lsblk -o LABEL -n 2>/dev/null | grep -Fqx "$BSS_EMERGENCY_OVERRIDE_BLOCK_DEVICE_LABEL"; then
      _log_warn "Emergency override triggered: Block device with label '$BSS_EMERGENCY_OVERRIDE_BLOCK_DEVICE_LABEL' detected"
      _notify_user "EMERGENCY OVERRIDE: Hardware key with label '$BSS_EMERGENCY_OVERRIDE_BLOCK_DEVICE_LABEL' detected. Skipping shutdown."
      exit 0
    else
      _log_debug "No matching block device label found"
    fi
  fi

  # 2. Check for specific file on mounted media (Hardware Key with specific FILE is present)
  if [[ -n "${BSS_EMERGENCY_OVERRIDE_FILE_MEDIA_DIR:-}" ]] && [[ -n "${BSS_EMERGENCY_OVERRIDE_FILE_NAME:-}" ]]; then
    _log_info "Checking for emergency override file '$BSS_EMERGENCY_OVERRIDE_FILE_NAME' in '$BSS_EMERGENCY_OVERRIDE_FILE_MEDIA_DIR'"
    # Only run find if the media directory actually exists (stick is mounted)
    if [[ -d "$BSS_EMERGENCY_OVERRIDE_FILE_MEDIA_DIR" ]]; then
      # Find the file on the mounted media (max depth 2 to allow for root or 1-level subdirectory)
      local first_override_file="$(find "$BSS_EMERGENCY_OVERRIDE_FILE_MEDIA_DIR" -maxdepth 2 -name "$BSS_EMERGENCY_OVERRIDE_FILE_NAME" -print -quit | head -n 1 2>/dev/null)"
      if [[ -n "$first_override_file" ]]; then
        _log_warn "Emergency override triggered: File '${first_override_file}' detected"
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
    _log_info "Checking for USB device with ID: $BSS_EMERGENCY_OVERRIDE_USB_ID"
    # Search for specific USB device ID (format: "1234:abcd")
    if lsusb -d "$BSS_EMERGENCY_OVERRIDE_USB_ID" >/dev/null 2>&1; then
      _log_warn "Emergency override triggered: USB device '$BSS_EMERGENCY_OVERRIDE_USB_ID' detected"
      _notify_user "EMERGENCY OVERRIDE: USB Device '$BSS_EMERGENCY_OVERRIDE_USB_ID' detected. Skipping shutdown."
      exit 0
    else
      _log_debug "No matching USB device found"
    fi
  fi

  _log_debug "All emergency override checks passed"
}

# Main function
main() {
  _log_info "Starting bedtime shutdown sequence..."
  _log_debug "Configuration: User=$BSS_USER_NAME, Grace periods: user=${BSS_GRACE_PERIOD_USER}s, system=${BSS_GRACE_PERIOD_SYSTEM}s"

  # 1. Run all checks
  _exit_if_safe_zone
  _exit_if_emergency_override

  _log_info "All safety checks passed. Proceeding with shutdown sequence."

  # 2. Notifications & User Grace Period
  _log_info "Notifying user. Grace period: ${BSS_GRACE_PERIOD_USER} seconds"
  _notify_user "Shutting down in ${BSS_GRACE_PERIOD_USER} seconds. Save your work."

  if [[ "$BSS_GRACE_PERIOD_USER" -gt 0 ]]; then
    _log_info "Waiting ${BSS_GRACE_PERIOD_USER} seconds before proceeding to shutdown..."
    sleep $BSS_GRACE_PERIOD_USER
  fi

  # 3. Shutdown Sequence
  _log_info "User grace period complete. Proceeding to shutdown."
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

    # Stage 3: Nuclear Option (Force Force)
    # If we are still running, instantly "pull the power plug" (software equivalent).
    # -ff | --force --force (doubled): Tell the kernel to "power off" immediately
    # This bypasses all systemd shutdown scripts, unmounting, etc.
    _log_warn "Stage 3 (Force): Forcing immediate shutdown..."
    _poweroff --force --force
  else
    _log_info "System grace period is <= 0. Force fallback disabled."
  fi
}
# }}} = FUNCTIONS ============================================================

# Invoke the main function
main
