#!/bin/bash
WALLPAPER="file:///usr/share/wallpapers/WrathOS/wrathos-default.png"

sleep 3

if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
    plasma-apply-wallpaperimage /usr/share/wallpapers/WrathOS/wrathos-default.png
fi

mkdir -p ~/.config
cat > ~/.config/plasma-org.kde.plasma.desktop-appletsrc << KDEEOF
[Containments][1][Wallpaper][org.kde.image][General]
Image=${WALLPAPER}
KDEEOF
