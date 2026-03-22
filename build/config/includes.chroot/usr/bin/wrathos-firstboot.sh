#!/bin/bash
set -e

# Find the first real user (uid >= 1000)
REAL_USER=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' | head -1)
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

if [ -z "$REAL_USER" ]; then
    echo "No real user found, exiting."
    exit 0
fi

echo "Setting up WrathOS for user: $REAL_USER"

# Create autostart directory
mkdir -p "${REAL_HOME}/.config/autostart"

# Write configurator autostart
cat > "${REAL_HOME}/.config/autostart/wrathos-configurator.desktop" << 'DESKEOF'
[Desktop Entry]
Type=Application
Name=Wrath/OS Setup
Exec=wrathos-configurator
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-KDE-autostart-phase=2
DESKEOF

# Write desktop icon
mkdir -p "${REAL_HOME}/Desktop"
cat > "${REAL_HOME}/Desktop/wrathos-setup.desktop" << 'DESKEOF'
[Desktop Entry]
Type=Application
Name=Wrath/OS Gaming Setup
Exec=wrathos-configurator --force
Icon=/etc/calamares/branding/wrathos/logo.png
Terminal=false
Categories=System;Settings;
Keywords=gaming;setup;bundles;
Comment=Configure your WrathOS gaming bundles
DESKEOF
chmod +x "${REAL_HOME}/Desktop/wrathos-setup.desktop"

# Fix ownership
chown -R "${REAL_USER}:${REAL_USER}" \
    "${REAL_HOME}/.config/autostart" \
    "${REAL_HOME}/Desktop/wrathos-setup.desktop"

# Write application menu entry
cat > /usr/share/applications/wrathos-configurator.desktop << 'DESKEOF'
[Desktop Entry]
Type=Application
Name=Wrath/OS Gaming Setup
Exec=wrathos-configurator --force
Icon=/etc/calamares/branding/wrathos/logo.png
Terminal=false
Categories=System;Settings;
Keywords=gaming;setup;bundles;
Comment=Configure your WrathOS gaming bundles
DESKEOF

# Mark as done
touch /var/lib/wrathos-firstboot-done

echo "WrathOS first boot setup complete."
