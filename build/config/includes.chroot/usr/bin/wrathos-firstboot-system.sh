#!/bin/bash
set -e

# Never run in live environment
if grep -q "boot=live" /proc/cmdline; then
    exit 0
fi

# Find the real user
REAL_USER=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' | head -1)
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

if [ -z "$REAL_USER" ]; then
    exit 0
fi

mkdir -p "${REAL_HOME}/.config/autostart"
mkdir -p "${REAL_HOME}/Desktop"
mkdir -p "${REAL_HOME}/.local/share/applications"

# Configurator autostart
cat > "${REAL_HOME}/.config/autostart/wrathos-configurator.desktop" << 'DESKEOF'
[Desktop Entry]
Type=Application
Name=WrathOS Setup
Exec=wrathos-configurator
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-KDE-autostart-phase=2
DESKEOF

# Wallpaper autostart
cat > "${REAL_HOME}/.config/autostart/wrathos-wallpaper.desktop" << 'DESKEOF'
[Desktop Entry]
Type=Application
Name=WrathOS Wallpaper Setup
Exec=/usr/bin/wrathos-set-wallpaper.sh
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
DESKEOF

# Desktop icon
cat > "${REAL_HOME}/Desktop/wrathos-setup.desktop" << 'DESKEOF'
[Desktop Entry]
Type=Application
Name=WrathOS Setup
Exec=wrathos-configurator
Icon=/etc/calamares/branding/wrathos/logo.png
Terminal=false
Categories=System;Settings;
Keywords=setup;bundles;configuration;
Comment=Configure your WrathOS installation
DESKEOF
chmod +x "${REAL_HOME}/Desktop/wrathos-setup.desktop"

cp "${REAL_HOME}/Desktop/wrathos-setup.desktop" \
   "${REAL_HOME}/.local/share/applications/wrathos-setup.desktop" 2>/dev/null || true

cat > /usr/share/applications/wrathos-configurator.desktop << 'DESKEOF'
[Desktop Entry]
Type=Application
Name=WrathOS Setup
Exec=wrathos-configurator
Icon=/etc/calamares/branding/wrathos/logo.png
Terminal=false
Categories=System;Settings;
Keywords=setup;bundles;configuration;
Comment=Configure your WrathOS installation
DESKEOF

chown -R "${REAL_USER}:${REAL_USER}" \
    "${REAL_HOME}/.config/autostart" \
    "${REAL_HOME}/Desktop" \
    "${REAL_HOME}/.local" 2>/dev/null || true

touch /var/lib/wrathos-firstboot-done

