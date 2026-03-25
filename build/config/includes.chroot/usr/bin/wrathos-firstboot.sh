#!/bin/bash
set -e

# Don't run in live environment
if grep -q "boot=live" /proc/cmdline; then
    exit 0
fi

# Don't run if already completed
if [ -f "/var/lib/wrathos-firstboot-done" ]; then
    # Remove our autostart so we never run again
    rm -f "${HOME}/.config/autostart/wrathos-firstboot.desktop"
    exit 0
fi

REAL_USER=$(whoami)
REAL_HOME="${HOME}"

echo "Setting up WrathOS for user: $REAL_USER"

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

# Wallpaper config
cat > "${REAL_HOME}/.config/plasma-welcomescreen.conf" << 'KDEEOF'
[General]
ShouldShow=false
KDEEOF

cat > "${REAL_HOME}/.config/kiorc" << 'KDEEOF'
[Executable scripts]
behaviourOnLaunch=execute
KDEEOF

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
   "${REAL_HOME}/.local/share/applications/wrathos-setup.desktop"

# App menu entry
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

# Launch configurator immediately in this session
wrathos-configurator &

# Apply wallpaper immediately in this session
/usr/bin/wrathos-set-wallpaper.sh &

# Mark as done
sudo touch /var/lib/wrathos-firstboot-done 2>/dev/null ||     touch /var/lib/wrathos-firstboot-done

# Remove this autostart so it never runs again
rm -f "${REAL_HOME}/.config/autostart/wrathos-firstboot.desktop"

echo "WrathOS first boot setup complete for $REAL_USER."
