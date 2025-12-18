#!/bin/bash

# USAGE EXAMPLE
# -------------
#
# 1. Put this file into `/opt/bin/digital-detox-bedtime.sh`
#
# 2. Ensure limited file access:
#> sudo chown root:root /opt/bin/digital-detox-bedtime.sh
#> sudo chmod 700 /opt/bin/digital-detox-bedtime.sh
#
# 3. Setup service:
#> sudo tee /etc/systemd/system/bedtime.service <<EOF
#[Unit]
#Description=Bedtime Shutdown Script
#[Service]
#Type=simple
#ExecStart=/opt/bin/digital-detox-bedtime.sh
#EOF
#
# 4. Setup service timer:
#> sudo tee /etc/systemd/system/bedtime.timer <<EOF
#[Unit]
#Description=Run Bedtime Script at 22:00
#[Timer]
#OnCalendar=*-*-* 22:00:00
#Persistent=true
#
#[Install]
#WantedBy=timers.target
#EOF
#
#sudo systemctl enable --now bedtime.timer

# User to notify before shutdown
USER_NAME=cbaoth
USER_ID=$(id -u $USER_NAME)
# Timeout in seconds before shutdown
TIMEOUT=180

# Sends a BEDTIME notification to USER_NAME
notify_user() {
  sudo -u $USER_NAME DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${USER_ID}/bus \
    notify-send "BEDTIME" "$*" --urgency=critical
}

notify_user "Shutting down in ${TIMEOUT} seconds. Save your work."

sleep $TIMEOUT

# The final shutdown
notify_user "Shutting down now!"
systemctl poweroff

