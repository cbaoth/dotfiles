#!/bin/bash
# Bedtime Shutdown - Install & Update Script
# Installs/updates the bedtime-shutdown script and configuration template

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="bedtime-shutdown.sh"
SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_NAME"
SCRIPT_TARGET="/opt/bin/$SCRIPT_NAME"

CONFIG_SOURCE="$SCRIPT_DIR/bedtime-shutdown.conf"
CONFIG_TARGET="/etc/bedtime-shutdown.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Error: This script must be run as root.${NC}" >&2
  exit 1
fi

# Verify source files exist
if [[ ! -f "$SCRIPT_SOURCE" ]]; then
  echo -e "${RED}Error: Source script not found: $SCRIPT_SOURCE${NC}" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_SOURCE" ]]; then
  echo -e "${RED}Error: Source config template not found: $CONFIG_SOURCE${NC}" >&2
  exit 1
fi

echo "===================================="
echo "Bedtime Shutdown - Install & Update"
echo "===================================="
echo

# Check if script is already installed
if [[ -f "$SCRIPT_TARGET" ]]; then
  SOURCE_MD5=$(md5sum "$SCRIPT_SOURCE" | awk '{print $1}')
  TARGET_MD5=$(md5sum "$SCRIPT_TARGET" | awk '{print $1}')

  if [[ "$SOURCE_MD5" == "$TARGET_MD5" ]]; then
    echo -e "${GREEN}✓ Script is already up-to-date.${NC}"
    exit 0
  else
    echo "Updating bedtime-shutdown script..."
  fi
else
  echo "Installing bedtime-shutdown script..."
fi

# Create target directory if needed
mkdir -p /opt/bin

# Install/update script
echo "  → Copying script to $SCRIPT_TARGET"
cp "$SCRIPT_SOURCE" "$SCRIPT_TARGET"
chown root:root "$SCRIPT_TARGET"
chmod 700 "$SCRIPT_TARGET"

# Install/update config template (only if it doesn't exist)
if [[ ! -f "$CONFIG_TARGET" ]]; then
  echo "  → Copying config template to $CONFIG_TARGET"
  cp "$CONFIG_SOURCE" "$CONFIG_TARGET"
  chown root:root "$CONFIG_TARGET"
  chmod 600 "$CONFIG_TARGET"

  echo
  echo -e "${YELLOW}⚠ Configuration file created at $CONFIG_TARGET${NC}"
  echo "  Please edit it before enabling the systemd timer:"
  echo "    sudo editor $CONFIG_TARGET"
  echo
  echo "Then run the post-install setup to create systemd units."
else
  echo "  → Config already exists at $CONFIG_TARGET (skipped)"
fi

echo
echo -e "${GREEN}✓ Installation complete.${NC}"
echo

cat <<EOF
------------------------------------
Next Steps
------------------------------------

1. Edit the configuration file (if you haven't already):

    sudo editor /etc/bedtime-shutdown.conf

2. Create systemd service and timer:

    sudo mkdir -p /etc/systemd/system
    sudo tee /etc/systemd/system/bedtime.service > /dev/null <<SEOF
[Unit]
Description=Bedtime Shutdown Script
[Service]
Type=simple
ExecStart=/opt/bin/bedtime-shutdown.sh
SEOF

    sudo tee /etc/systemd/system/bedtime.timer > /dev/null <<TEOF
[Unit]
Description=Run Bedtime Script at 21:30 (repeat every 10 min until 05:00)
[Timer]
OnCalendar=*-*-* 21:30:00
OnCalendar=*-*-* 21..04:00/10:00
Persistent=true
[Install]
WantedBy=timers.target
TEOF

3. Enable and start the timer:

    sudo systemctl daemon-reload
    sudo systemctl enable --now bedtime.timer
    sudo systemctl status bedtime.timer

4. Test in dry-run mode:

    sudo /opt/bin/bedtime-shutdown.sh --dry-run -v

For more information, see: README.adoc
EOF

exit 0
