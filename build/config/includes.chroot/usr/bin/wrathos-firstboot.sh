#!/bin/bash
set -e

if grep -q "boot=live" /proc/cmdline; then
    echo "Live environment detected, skipping firstboot setup."
    exit 0
fi

REAL_USER=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' | head -1)
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

if [ -z "$REAL_USER" ]; then
    echo "No real user found, exiting."
    exit 0
fi

echo "Setting up WrathOS for user: $REAL_USER"

mkdir -p "${REAL_HOME}/.config/autostart"

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

cat > "${REAL_HOME}/.config/autostart/wrathos-wallpaper.desktop" << 'DESKEOF'
[Desktop Entry]
Type=Application
Name=WrathOS Wallpaper Setup
Exec=/usr/bin/wrathos-set-wallpaper.sh
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
DESKEOF

cat > "${REAL_HOME}/.config/plasma-org.kde.plasma.desktop-appletsrc" << 'KDEEOF'
[Containments][1][Wallpaper][org.kde.image][General]
Image=file:///usr/share/wallpapers/WrathOS/wrathos-default.png
KDEEOF

cat > "${REAL_HOME}/.config/plasma-welcomescreen.conf" << 'KDEEOF'
[General]
ShouldShow=false
KDEEOF

cat > "${REAL_HOME}/.config/kiorc" << 'KDEEOF'
[Executable scripts]
behaviourOnLaunch=execute
KDEEOF

mkdir -p "${REAL_HOME}/Desktop"
cat > "${REAL_HOME}/Desktop/wrathos-setup.desktop" << 'DESKEOF'
[Desktop Entry]
Type=Application
Name=WrathOS Gaming Setup
Exec=bash -c "wrathos-configurator"
Icon=/etc/calamares/branding/wrathos/logo.png
Terminal=false
Categories=System;Settings;
Keywords=gaming;setup;bundles;
Comment=Configure your WrathOS gaming bundles
DESKEOF
chmod +x "${REAL_HOME}/Desktop/wrathos-setup.desktop"

chown -R "${REAL_USER}:${REAL_USER}" \
    "${REAL_HOME}/.config/autostart" \
    "${REAL_HOME}/.config/plasma-org.kde.plasma.desktop-appletsrc" \
    "${REAL_HOME}/.config/plasma-welcomescreen.conf" \
    "${REAL_HOME}/.config/kiorc" \
    "${REAL_HOME}/Desktop/wrathos-setup.desktop"

cat > /usr/share/applications/wrathos-configurator.desktop << 'DESKEOF'
[Desktop Entry]
Type=Application
Name=WrathOS Gaming Setup
Exec=bash -c "wrathos-configurator"
Icon=/etc/calamares/branding/wrathos/logo.png
Terminal=false
Categories=System;Settings;
Keywords=gaming;setup;bundles;
Comment=Configure your WrathOS gaming bundles
DESKEOF

touch /var/lib/wrathos-firstboot-done
echo "WrathOS first boot setup complete for $REAL_USER."
