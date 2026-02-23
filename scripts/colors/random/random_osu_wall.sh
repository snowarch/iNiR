#!/usr/bin/env bash

get_pictures_dir() {
    if command -v xdg-user-dir &> /dev/null; then
        xdg-user-dir PICTURES
        return
    fi

    local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
    if [ -f "$config_file" ]; then
        local pictures_path
        pictures_path=$(source "$config_file" >/dev/null 2>&1; echo "$XDG_PICTURES_DIR")
        echo "${pictures_path/#\$HOME/$HOME}"
        return
    fi

    echo "$HOME/Pictures"
}

QUICKSHELL_CONFIG_NAME="inir"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
PICTURES_DIR=$(get_pictures_dir)
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$PICTURES_DIR/Wallpapers"

response=$(curl "https://osu.ppy.sh/api/v2/seasonal-backgrounds")
images=$(echo "$response" | jq '.backgrounds | length' -r);
randomIndex=$((RANDOM % images));
link=$(echo "$response" | jq ".backgrounds[$randomIndex].url" -r)
ext=$(echo "$link" | awk -F. '{print $NF}')
downloadPath="$PICTURES_DIR/Wallpapers/random_wallpaper.$ext"
illogicalImpulseConfigPath="$HOME/.config/inir/config.json"
currentWallpaperPath=$(jq -r '.background.wallpaperPath' $illogicalImpulseConfigPath)
if [ "$downloadPath" == "$currentWallpaperPath" ]; then
    downloadPath="$PICTURES_DIR/Wallpapers/random_wallpaper-1.$ext"
fi
curl "$link" -o "$downloadPath"

# Check if multi-monitor mode is enabled
multiMonitorEnabled=$(jq -r '.background.multiMonitor.enable' "$illogicalImpulseConfigPath" 2>/dev/null)

if [ "$multiMonitorEnabled" == "true" ]; then
    # Get focused monitor
    focusedMonitor=""
    if command -v niri &> /dev/null && niri msg outputs &> /dev/null; then
        focusedMonitor=$(niri msg -j outputs 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null)
    elif command -v hyprctl &> /dev/null; then
        focusedMonitor=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null)
    fi

    if [ -n "$focusedMonitor" ]; then
        # Detect workspace range for this monitor (Niri-specific)
        wsArgs=""
        if command -v niri &> /dev/null && niri msg workspaces &> /dev/null; then
            wsFirst=$(niri msg -j workspaces 2>/dev/null | jq -r "[.[] | select(.output == \"$focusedMonitor\") | .idx] | sort | first // empty" 2>/dev/null)
            wsLast=$(niri msg -j workspaces 2>/dev/null | jq -r "[.[] | select(.output == \"$focusedMonitor\") | .idx] | sort | last // empty" 2>/dev/null)
            if [ -n "$wsFirst" ] && [ -n "$wsLast" ]; then
                wsArgs="--start-workspace $wsFirst --end-workspace $wsLast"
            fi
        fi
        "$SCRIPT_DIR/../switchwall.sh" --image "$downloadPath" --monitor "$focusedMonitor" $wsArgs
    else
        "$SCRIPT_DIR/../switchwall.sh" --image "$downloadPath"
    fi
else
    "$SCRIPT_DIR/../switchwall.sh" --image "$downloadPath"
fi
