#!/bin/bash
WALLPAPER="/usr/share/wallpapers/WrathOS/wrathos-default.png"

sleep 5

# Apply via plasma tool - this handles any containment number
if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
    plasma-apply-wallpaperimage "$WALLPAPER"
    exit 0
fi

# Fallback - find all containments and set wallpaper on each
CONFIG="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

if [ -f "$CONFIG" ]; then
    # Find all containment numbers that have wallpaperplugin
    CONTAINMENTS=$(grep -n "wallpaperplugin" "$CONFIG" | \
        grep -o '\[Containments\]\[[0-9]*\]' | \
        grep -o '\[[0-9]*\]' | tr -d '[]' | sort -u)

    for NUM in $CONTAINMENTS; do
        python3 -c "
import configparser
import sys

config = configparser.RawConfigParser()
config.optionxform = str
config.read('$CONFIG')

section = 'Containments][${NUM}][Wallpaper][org.kde.image][General'
try:
    if not config.has_section(section):
        config.add_section(section)
    config.set(section, 'Image', 'file://$WALLPAPER')
    with open('$CONFIG', 'w') as f:
        config.write(f)
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
" 2>/dev/null || true
    done
fi
