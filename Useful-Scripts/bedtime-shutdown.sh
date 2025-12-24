#!/bin/bash

# {{{ = USAGE EXAMPLE ========================================================
#
# 1. Put this file into `/opt/bin/bedtime-shutdown.sh`
#
# 2. Adjust configuration variables in the "CONFIGURATION" section below as needed.
#
# 3. Ensure limited file access:
#> sudo chown root:root /opt/bin/bedtime-shutdown.sh
#> sudo chmod 700 /opt/bin/bedtime-shutdown.sh
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
# NOTE: Whenever you want to adjust the schedule, edit the "OnCalendar" line in
#       `/etc/systemd/system/bedtime.timer` and then run:
#> sudo systemctl daemon-reload
#> sudo systemctl restart bedtime.timer
#> sudo systemctl status bedtime.timer
#
# }}} = USAGE EXAMPLE ========================================================

# {{{ = CONFIGURATION ========================================================
# User to notify before shutdown
USER_NAME=cbaoth
USER_ID=$(id -u $USER_NAME)

# Grace period (seconds) between notification and shutdown
GRACE_PERIOD=180

# Shutdown schedule
# Format: HHMM (24-hour format)
# Example: 2130 = 9:30 PM, 0500 = 5:00 AM

# The time the "Bedtime Zone" begins (Shutdown allowed)
#SHUTDOWN_START=2130
SHUTDOWN_START=2200

# The time the "Safe Zone" begins (Shutdown skipped)
#SHUTDOWN_END=0500
SHUTDOWN_END=0500
# }}} = CONFIGURATION ========================================================

# }}} = SANITY CHECK =========================================================
# Get current time as a number (e.g. 2130)
CURRENT_TIME=$(date +%H%M)

# We force base-10 ((10#...)) to prevent bash from thinking "0800" is an octal number and crashing.
NOW=$((10#$CURRENT_TIME))
START=$((10#$SHUTDOWN_START))
END=$((10#$SHUTDOWN_END))
# }}} = SANITY CHECK =========================================================

# {{{ = FUNCTIONS ============================================================
# Sends a BEDTIME notification to USER_NAME
# We add '|| true' so the script doesn't crash if PAM has already locked your user out.
_notify_user() {
  sudo -u $USER_NAME DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${USER_ID}/bus \
    notify-send "BEDTIME" "$*" --urgency=critical || true
}

# Convert HHMM to HH:MM format (for user notifications)
_format_time() {
  printf "%s:%s" "${1:0:2}" "${1:2:2}"
}

# Exits the script if we are in the "Safe Zone" (no shutdown allowed)
_exit_if_safe_zone() {
  # We assume the "Safe Zone" is the daytime block between morning (END) and night (START).
  # If we are inside that block, we exit.
  # Example: If NOW (1200) >= 0500 AND NOW (1200) < 2200 -> Exit.
  if (( NOW >= END && NOW < START )); then
      echo "Current time ($(_format_time $CURRENT_TIME)) is within the safe window ($(_format_time $SHUTDOWN_END) to $(_format_time $SHUTDOWN_START)). Skipping bedtime shutdown."
      exit 0
  fi
}

# Main function
main() {
  # Check if we are in the "Safe Zone", exit if so
  _exit_if_safe_zone

  # We are in the "Bedtime Zone", notify user of impending shutdown
  _notify_user "Shutting down in ${GRACE_PERIOD} seconds. Save your work."

  # Grace period before shutdown
  sleep $GRACE_PERIOD

  # Initiate shutdown
  _notify_user "Shutting down now!"
  systemctl poweroff
}
# }}} = FUNCTIONS ============================================================

# Invoke the main function
main
