#!/bin/bash
WALLPAPER="/usr/share/wallpapers/WrathOS/wrathos-default.png"
FLAG="$HOME/.wrathos-wallpaper-set"

# Only run once - if flag exists user may have changed wallpaper
if [ -f "$FLAG" ]; then
    exit 0
fi

sleep 5

# Apply wallpaper
if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
    plasma-apply-wallpaperimage "$WALLPAPER" && \
        touch "$FLAG" && \
        exit 0
fi

# Fallback - write config directly
mkdir -p ~/.config
cat > ~/.config/plasma-org.kde.plasma.desktop-appletsrc << KDEEOF
[Containments][1][Wallpaper][org.kde.image][General]
Image=file://${WALLPAPER}
KDEEOF

touch "$FLAG"
