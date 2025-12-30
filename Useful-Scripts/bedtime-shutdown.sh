#!/bin/bash

# {{{ = USAGE EXAMPLE ========================================================
#
# 1. Put this file into `/opt/bin/bedtime-shutdown.sh`
#> sudo mkdir -p /opt/bin
#> sudo cp bedtime-shutdown.sh /opt/bin/bedtime-shutdown.sh
# Later on, when the file already exists, you can use the following instead (since cp may change file ownership):
#> sudo tee /opt/bin/bedtime-shutdown.sh <bedtime-shutdown.sh >/dev/null
#
# 2. Adjust configuration variables in the "CONFIGURATION" section below.
#
# 3. Ensure limited file access:
#> sudo chown root:root /opt/bin/bedtime-shutdown.sh
#> sudo chmod 700 /opt/bin/bedtime-shutdown.sh
# Optional: Make immutable to prevent accidental changes (use `-i` to remove):
#> sudo chattr +i /opt/bin/bedtime-shutdown.sh
#
# 4. Setup service:
#> sudo tee /etc/systemd/system/bedtime.service <<EOF
#[Unit]
#Description=Bedtime Shutdown Script
#[Service]
#Type=simple
#ExecStart=/opt/bin/bedtime-shutdown.sh
#EOF
#
# 5. Setup service timer:
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
#
#> sudo systemctl enable --now bedtime.timer
#
# In case you make changes to the systemd service or timer files, reload and check as needed:
#> sudo systemctl daemon-reload
#> sudo systemctl status bedtime.service
#> sudo systemctl restart bedtime.timer
#> sudo systemctl status bedtime.timer
# }}} = USAGE EXAMPLE ========================================================

# {{{ = CONFIGURATION ========================================================
# {{{ - Mandatory Settings ---------------------------------------------------
# Conigure the following (mandatory) variables to suit your needs.

# --- User Settings ---
# User to notify before shutdown
USER_NAME=cbaoth

# --- Grace Periods ---
# Grace period (seconds) between user notification and shutdown
#GRACE_PERIOD_USER=0     # Immediate shutdown without prior warning
GRACE_PERIOD_USER=180    # 3 minutes

# Grace period (seconds) between graceful poweroff attempt and forced poweroff
#GRACE_PERIOD_SYSTEM=0   # Disable forced poweroff fallback
GRACE_PERIOD_SYSTEM=180  # 3 minutes

# --- Shutdown schedule (24-hour format) ---
# Format: HHMM (24-hour format), e.g. "2130" = 21:30 (9:30 PM), "0500" = 5:00 (AM)
# The time the "Bedtime Zone" begins (Shutdown allowed)
#SHUTDOWN_START=2130
SHUTDOWN_START=2130

# The time the "Safe Zone" begins (Shutdown skipped)
#SHUTDOWN_END=0500
SHUTDOWN_END=0500
# }}} - Mandatory Settings ---------------------------------------------------

# {{{ - Optional Emergency Override Settings ---------------------------------
# Uncomment and adjust any of the following variables to enable emergency shutdown overrides.

# 1. File on USB Stick Override
# If a specific file is found on any mounted media, shutdown aborts.
# This override is ignored if the variables are not set.
# Adjust path to where USBs mount (Ubuntu: /media/$USER_NAME)
#EMERGENCY_OVERRIDE_FILE_MEDIA_DIR="/media/$USER_NAME"
# Adjust filename to look for on the USB stick
#EMERGENCY_OVERRIDE_FILE_NAME=".bedtime-shutdown.emergency-override.$USER_NAME"

# 2. USB Flash Drive Label Override
# If a USB flash drive (or any other block device) with this specific LABEL is plugged in, shutdown aborts.
# This override is ignored if the variable is not set.
# Use `lsblk -f` or `lsblk -fno LABEL | grep -v '^$'` to find the labels.
#EMERGENCY_OVERRIDE_BLOCK_DEVICE_LABEL="NO_SHUTDOWN"

# 3. USB Device ID Override
# If a USB device with this specific ID is plugged in, shutdown aborts.
# This override is ignored if the variable is not set.
# Use `lsusb` (e.g. `lsusb | grep -i realtek`) to find the device ID (format: "1234:abcd").
#EMERGENCY_OVERRIDE_USB_ID="abcd:1234"
# }}} - Optional Emergency Override Settings ---------------------------------

# {{{ - Debug Settings -------------------------------------------------------
# The command used to power off the system
SYSTEMCTL_POWEROFF_CMD="systemctl poweroff"
# For testing purposes we can set this to "echo" to prevent actual shutdowns.
#SYSTEMCTL_POWEROFF_CMD="echo"
# }}} - Debug Settings -------------------------------------------------------
# }}} = CONFIGURATION ========================================================

# }}} = INITIALIZATION =======================================================
# Get the user ID of USER_NAME
USER_ID=$(id -u $USER_NAME)

# Get current time as a number (e.g. 2130 for 21:30 or 9:30 PM)
CURRENT_TIME=$(date +%H%M)

# Force base-10 ((10#...)) to prevent bash from thinking "0800" is an octal number and crashing.
NOW=$((10#$CURRENT_TIME))
START=$((10#$SHUTDOWN_START))
END=$((10#$SHUTDOWN_END))
# }}} = INITIALIZATION =======================================================

# {{{ = FUNCTIONS ============================================================
# Sends a BEDTIME GUI notification to USER_NAME and broadcasts a message to all terminals.
_notify_user() {
  # 1. GUI Notification
  # Ignore failure if PAM blocked user notifications via `|| true`
  sudo -u $USER_NAME DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${USER_ID}/bus \
    notify-send "BEDTIME" "$*" --urgency=critical || true

  # 2. Terminal Broadcast
  wall <<<"BEDTIME: $*"
}

# Convert HHMM (24-hour) to HH:MM format (for user notifications)
_format_time() {
  printf "%s:%s" "${1:0:2}" "${1:2:2}"
}

# Exits the script if not run as root
_exit_if_not_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Exiting."
    exit 1
  fi
}

# Exits the script if we are in the "Safe Zone" (no shutdown allowed)
_exit_if_safe_zone() {
  local is_safe=0

  # Case 1: Standard day `START > END` (e.g. 05:00 to 21:30)
  if (( START > END )); then
      if (( NOW >= END && NOW < START )); then
          is_safe=1
      fi
  # Case 2: Wrapping over midnight `START < END` (e.g. 21:30 to 05:00)
  else
      # Safe if it's AFTER morning start OR BEFORE night shutdown
      if (( NOW >= END || NOW < START )); then
          is_safe=1
      fi
  fi

  if (( is_safe == 1 )); then
      echo "Current time ($(_format_time $CURRENT_TIME)) is within the safe window. Skipping shutdown."
      exit 0
  fi
}

# Exits the script if one of the emergency overrides is enabled
_exit_if_emergency_override() {
  # 1. Check for USB Label (Hardware Key with specific LABEL is present)
  # Syntax: [[ -n "$VAR" ]] checks if variable is set and not empty
  if [[ -n "${EMERGENCY_OVERRIDE_BLOCK_DEVICE_LABEL:-}" ]]; then
    # We use lsblk to check all block device labels
    if lsblk -o LABEL -n | grep -Fqx "$EMERGENCY_OVERRIDE_BLOCK_DEVICE_LABEL"; then
      _notify_user "EMERGENCY OVERRIDE: Hardware key with label '$EMERGENCY_OVERRIDE_BLOCK_DEVICE_LABEL' detected. Skipping shutdown."
      exit 0
    fi
  fi

  # 2. Check for specific file on mounted media (Hardware Key with specific FILE is present)
  if [[ -n "${EMERGENCY_OVERRIDE_FILE_MEDIA_DIR:-}" ]] && [[ -n "${EMERGENCY_OVERRIDE_FILE_NAME:-}" ]]; then
      # Only run find if the media directory actually exists (stick is mounted)
      if [[ -d "$EMERGENCY_OVERRIDE_FILE_MEDIA_DIR" ]]; then
        # Find the file on the mounted media (max depth 2 to allow for root or 1-level subdirectory)
        local _first_override_file="$(find "$EMERGENCY_OVERRIDE_FILE_MEDIA_DIR" -maxdepth 2 -name "$EMERGENCY_OVERRIDE_FILE_NAME" -print -quit | head -n 1 2>/dev/null)"
          if [[ -n "$_first_override_file" ]]; then
              _notify_user "EMERGENCY OVERRIDE: Hardware key with file '${_first_override_file}' detected. Skipping shutdown."
              exit 0
          fi
      fi
  fi

  # 3. Check for specific USB Device ID (lsusb)
  if [[ -n "${EMERGENCY_OVERRIDE_USB_ID:-}" ]]; then
    # Search for specific USB device ID (format: "1234:abcd")
    if lsusb -d "$EMERGENCY_OVERRIDE_USB_ID" >/dev/null 2>&1; then
      _notify_user "EMERGENCY OVERRIDE: USB Device '$EMERGENCY_OVERRIDE_USB_ID' detected. Skipping shutdown."
      exit 0
    fi
  fi
}

# Exits the script if any of the _exit_if_* conditions are met (see above)
_exit_if_any() {
  _exit_if_not_root
  _exit_if_safe_zone
  _exit_if_emergency_override
}

# Main function
main() {
  # 1. Run all checks (Root? Safe Time? Emergency Key?)
  _exit_if_any

  # 2. Notifications & User Grace Period
  _notify_user "Shutting down in ${GRACE_PERIOD_USER} seconds. Save your work."
  sleep $GRACE_PERIOD_USER

  # 3. Shutdown Sequence
  _notify_user "Shutting down now!"

  # Stage 1: Polite but firm (Ignore Inhibitors, Non-blocking)
  # -i | --ignore-inhibitors: Ignore inhibitors (e.g. "stay awake" apps like Caffeine)
  # --no-block: Send the command and returns IMMEDIATELY (asynchronous), don't wait for response.
  $SYSTEMCTL_POWEROFF_CMD --ignore-inhibitors --no-block

  # Stage 2: System Grace Period (Wait for graceful shutdown)
  # Skip if GRACE_PERIOD_SYSTEM is set to 0 or less.
  [[ $GRACE_PERIOD_SYSTEM -gt 0 ]] \
    && sleep $GRACE_PERIOD_SYSTEM

  # Stage 3: Nuclear Option (Force Force)
  # If we are still running, instantly "pull the power plug" (software equivalent).
  # -ff | --force --force (doubled): Tell the kernel to "power off" immediately
  # This bypasses all systemd shutdown scripts, unmounting, etc.
  # Skip if GRACE_PERIOD_SYSTEM is set to 0 or less.
  [[ $GRACE_PERIOD_SYSTEM -gt 0 ]] \
    && $SYSTEMCTL_POWEROFF_CMD --force --force
}
# }}} = FUNCTIONS ============================================================

# Invoke the main function
main
