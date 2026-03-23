#!/bin/bash
WALLPAPER="/usr/share/wallpapers/WrathOS/wrathos-default.png"
FLAG="$HOME/.wrathos-wallpaper-set"

if [ -f "$FLAG" ]; then
    exit 0
fi

# Wait for plasmashell to be ready
for i in $(seq 1 20); do
    if pgrep -x plasmashell > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

sleep 5

if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
    plasma-apply-wallpaperimage "$WALLPAPER" && \
        touch "$FLAG" && \
        exit 0
fi

mkdir -p ~/.config
cat > ~/.config/plasma-org.kde.plasma.desktop-appletsrc << KDEEOF
[Containments][1][Wallpaper][org.kde.image][General]
Image=file://${WALLPAPER}
KDEEOF
touch "$FLAG"
