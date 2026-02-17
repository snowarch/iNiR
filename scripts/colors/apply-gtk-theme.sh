#!/bin/bash
# Apply Qt/KDE theme colors from matugen's colors.json
# GTK CSS is handled by matugen templates — this script only generates:
#   - kdeglobals (KDE/Qt app colors for Dolphin, etc.)
#   - Darkly.colors (Qt style color scheme)
#   - Pywalfox colors (Firefox theming)
#   - Vesktop/Discord theme (if enabled)
# Reads from colors.json (matugen's output) for UI consistency.

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
COLORS_JSON="$XDG_STATE_HOME/quickshell/user/generated/colors.json"
KDEGLOBALS="$HOME/.config/kdeglobals"
DARKLY_COLORS="$HOME/.local/share/color-schemes/Darkly.colors"
SHELL_CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read config options
enable_apps_shell="true"
enable_qt_apps="true"
if [[ -f "$SHELL_CONFIG_FILE" ]] && command -v jq &>/dev/null; then
    enable_apps_shell=$(jq -r '.appearance.wallpaperTheming.enableAppsAndShell // true' "$SHELL_CONFIG_FILE")
    enable_qt_apps=$(jq -r '.appearance.wallpaperTheming.enableQtApps // true' "$SHELL_CONFIG_FILE")
fi

# Exit if shell theming is disabled
if [[ "$enable_apps_shell" == "false" ]]; then
    exit 0
fi

# Read colors from matugen's colors.json (UI authority)
if [[ ! -f "$COLORS_JSON" ]] || ! command -v jq &>/dev/null; then
    echo "[apply-gtk-theme] colors.json not found or jq missing, skipping"
    exit 0
fi

BG=$(jq -r '.background // "#1e1e2e"' "$COLORS_JSON")
FG=$(jq -r '.on_background // "#cdd6f4"' "$COLORS_JSON")
PRIMARY=$(jq -r '.primary // "#cba6f7"' "$COLORS_JSON")
ON_PRIMARY=$(jq -r '.on_primary // "#1e1e2e"' "$COLORS_JSON")
SURFACE=$(jq -r '.surface // "#1e1e2e"' "$COLORS_JSON")
SURFACE_DIM=$(jq -r '.surface_dim // "#11111b"' "$COLORS_JSON")

# Helper
adjust_color() {
    local hex="${1#\#}"
    local amount="$2"
    local r=$((0x${hex:0:2} + amount))
    local g=$((0x${hex:2:2} + amount))
    local b=$((0x${hex:4:2} + amount))
    ((r < 0)) && r=0; ((r > 255)) && r=255
    ((g < 0)) && g=0; ((g > 255)) && g=255
    ((b < 0)) && b=0; ((b > 255)) && b=255
    printf "#%02x%02x%02x" $r $g $b
}

avg_brightness() {
    local hex="${1#\#}"
    local r=$((0x${hex:0:2}))
    local g=$((0x${hex:2:2}))
    local b=$((0x${hex:4:2}))
    echo $(((r + g + b) / 3))
}

bg_avg=$(avg_brightness "$BG")
fg_avg=$(avg_brightness "$FG")

# Use smaller deltas for very dark/light colors to avoid clamping to #000000/#ffffff
bg_alt_delta=20
bg_dark_delta=-20
fg_inactive_delta=-60

if (( bg_avg < 40 )); then
    bg_alt_delta=12
    bg_dark_delta=-10
fi
if (( fg_avg < 80 )); then
    fg_inactive_delta=-35
fi

BG_ALT=$(adjust_color "$BG" $bg_alt_delta)
BG_DARK=$(adjust_color "$BG" $bg_dark_delta)
FG_INACTIVE=$(adjust_color "$FG" $fg_inactive_delta)

generate_pywalfox() {
    # Generate pywalfox-compatible JSON from matugen colors for Firefox theming
    local wallpaper_path=""
    local wp_file="$XDG_STATE_HOME/quickshell/user/generated/wallpaper/path.txt"
    [[ -f "$wp_file" ]] && wallpaper_path=$(cat "$wp_file" | tr -d '\n')

    cat << EOF
{
  "wallpaper": "$wallpaper_path",
  "alpha": "100",
  "special": {
    "background": "$BG",
    "foreground": "$FG",
    "cursor": "$PRIMARY"
  }
}
EOF
}

generate_kdeglobals() {
    local icon_theme
    icon_theme=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
    [[ -z "$icon_theme" ]] && icon_theme="Adwaita"
    
    cat << EOF
[ColorEffects:Disabled]
Color=${BG}
ColorAmount=0.5
ColorEffect=3
ContrastAmount=0
ContrastEffect=0
IntensityAmount=0
IntensityEffect=0

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=${BG_DARK}
ColorAmount=0.025
ColorEffect=0
ContrastAmount=0.1
ContrastEffect=0
Enable=false
IntensityAmount=0
IntensityEffect=0

[Colors:Button]
BackgroundAlternate=${BG_ALT}
BackgroundNormal=${SURFACE}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=#ff6b6b
ForegroundNeutral=#ffa94d
ForegroundNormal=${FG}
ForegroundPositive=#69db7c
ForegroundVisited=${PRIMARY}

[Colors:Selection]
BackgroundAlternate=${PRIMARY}
BackgroundNormal=${PRIMARY}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${ON_PRIMARY}
ForegroundInactive=${ON_PRIMARY}
ForegroundLink=${ON_PRIMARY}
ForegroundNegative=${ON_PRIMARY}
ForegroundNeutral=${ON_PRIMARY}
ForegroundNormal=${ON_PRIMARY}
ForegroundPositive=${ON_PRIMARY}
ForegroundVisited=${ON_PRIMARY}

[Colors:Tooltip]
BackgroundAlternate=${BG_ALT}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=#ff6b6b
ForegroundNeutral=#ffa94d
ForegroundNormal=${FG}
ForegroundPositive=#69db7c
ForegroundVisited=${PRIMARY}

[Colors:View]
BackgroundAlternate=${BG}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=#ff6b6b
ForegroundNeutral=#ffa94d
ForegroundNormal=${FG}
ForegroundPositive=#69db7c
ForegroundVisited=${PRIMARY}

[Colors:Window]
BackgroundAlternate=${BG}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=#ff6b6b
ForegroundNeutral=#ffa94d
ForegroundNormal=${FG}
ForegroundPositive=#69db7c
ForegroundVisited=${PRIMARY}

[Colors:Complementary]
BackgroundAlternate=${BG_DARK}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=#ff6b6b
ForegroundNeutral=#ffa94d
ForegroundNormal=${FG}
ForegroundPositive=#69db7c
ForegroundVisited=${PRIMARY}

[Colors:Header]
BackgroundAlternate=${BG}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=#ff6b6b
ForegroundNeutral=#ffa94d
ForegroundNormal=${FG}
ForegroundPositive=#69db7c
ForegroundVisited=${PRIMARY}

[Colors:Header][Inactive]
BackgroundAlternate=${BG}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=#ff6b6b
ForegroundNeutral=#ffa94d
ForegroundNormal=${FG}
ForegroundPositive=#69db7c
ForegroundVisited=${PRIMARY}

[Colors:Menu]
BackgroundAlternate=${BG_ALT}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=#ff6b6b
ForegroundNeutral=#ffa94d
ForegroundNormal=${FG}
ForegroundPositive=#69db7c
ForegroundVisited=${PRIMARY}

[General]
ColorScheme=Darkly

[Icons]
Theme=${icon_theme}

[KDE]
widgetStyle=Darkly

[WM]
activeBackground=${BG}
activeBlend=${FG}
activeForeground=${FG}
inactiveBackground=${BG}
inactiveBlend=${FG_INACTIVE}
inactiveForeground=${FG_INACTIVE}
EOF
}

# GTK CSS is handled by matugen templates — no bash generation needed

# Helper to convert hex to RGB
hex_to_rgb() {
    local hex="${1#\#}"
    local r=$((0x${hex:0:2}))
    local g=$((0x${hex:2:2}))
    local b=$((0x${hex:4:2}))
    echo "$r,$g,$b"
}

# Generate Darkly.colors for Qt style override
generate_darkly_colors() {
    local bg_rgb=$(hex_to_rgb "$BG")
    local bg_alt_rgb=$(hex_to_rgb "$BG_ALT")
    local bg_dark_rgb=$(hex_to_rgb "$BG_DARK")
    local fg_rgb=$(hex_to_rgb "$FG")
    local fg_inactive_rgb=$(hex_to_rgb "$FG_INACTIVE")
    local primary_rgb=$(hex_to_rgb "$PRIMARY")
    local on_primary_rgb=$(hex_to_rgb "$ON_PRIMARY")
    local surface_rgb=$(hex_to_rgb "$SURFACE")
    
    cat << EOF
[ColorEffects:Disabled]
Color=${bg_rgb}
ColorAmount=0.5
ColorEffect=3
ContrastAmount=0.5
ContrastEffect=0
IntensityAmount=0
IntensityEffect=0

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=${bg_dark_rgb}
ColorAmount=0.4
ColorEffect=3
ContrastAmount=0.4
ContrastEffect=0
Enable=true
IntensityAmount=-0.2
IntensityEffect=0

[Colors:Button]
BackgroundAlternate=${bg_alt_rgb}
BackgroundNormal=${surface_rgb}
DecorationFocus=${primary_rgb}
DecorationHover=${primary_rgb}
ForegroundActive=${fg_rgb}
ForegroundInactive=${fg_inactive_rgb}
ForegroundLink=${primary_rgb}
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=${fg_rgb}
ForegroundPositive=36,173,89
ForegroundVisited=${primary_rgb}

[Colors:Complementary]
BackgroundAlternate=${bg_dark_rgb}
BackgroundNormal=${bg_rgb}
DecorationFocus=${primary_rgb}
DecorationHover=${primary_rgb}
ForegroundActive=${fg_rgb}
ForegroundInactive=${fg_inactive_rgb}
ForegroundLink=${primary_rgb}
ForegroundNegative=237,21,21
ForegroundNeutral=201,206,59
ForegroundNormal=${fg_rgb}
ForegroundPositive=17,209,22
ForegroundVisited=${primary_rgb}

[Colors:Selection]
BackgroundAlternate=${primary_rgb}
BackgroundNormal=${primary_rgb}
DecorationFocus=${primary_rgb}
DecorationHover=${primary_rgb}
ForegroundActive=${on_primary_rgb}
ForegroundInactive=${on_primary_rgb}
ForegroundLink=${on_primary_rgb}
ForegroundNegative=${on_primary_rgb}
ForegroundNeutral=${on_primary_rgb}
ForegroundNormal=${on_primary_rgb}
ForegroundPositive=${on_primary_rgb}
ForegroundVisited=${on_primary_rgb}

[Colors:Tooltip]
BackgroundAlternate=${bg_alt_rgb}
BackgroundNormal=${bg_rgb}
DecorationFocus=${primary_rgb}
DecorationHover=${primary_rgb}
ForegroundActive=${fg_rgb}
ForegroundInactive=${fg_inactive_rgb}
ForegroundLink=${primary_rgb}
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=${fg_rgb}
ForegroundPositive=36,173,89
ForegroundVisited=${primary_rgb}

[Colors:View]
BackgroundAlternate=${bg_rgb}
BackgroundNormal=${bg_rgb}
DecorationFocus=${primary_rgb}
DecorationHover=${primary_rgb}
ForegroundActive=${fg_rgb}
ForegroundInactive=${fg_inactive_rgb}
ForegroundLink=${primary_rgb}
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=${fg_rgb}
ForegroundPositive=36,173,89
ForegroundVisited=${primary_rgb}

[Colors:Window]
BackgroundAlternate=${bg_alt_rgb}
BackgroundNormal=${bg_rgb}
DecorationFocus=${primary_rgb}
DecorationHover=${primary_rgb}
ForegroundActive=${fg_rgb}
ForegroundInactive=${fg_inactive_rgb}
ForegroundLink=${primary_rgb}
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=${fg_rgb}
ForegroundPositive=36,173,89
ForegroundVisited=${primary_rgb}

[General]
ColorScheme=Darkly
Name=Darkly
shadeSortColumn=true

[KDE]
contrast=0

[WM]
activeBackground=${bg_rgb}
activeBlend=255,255,255
activeForeground=${fg_rgb}
inactiveBackground=${bg_rgb}
inactiveBlend=${fg_inactive_rgb}
inactiveForeground=${fg_inactive_rgb}
EOF
}

# Apply KDE/Qt theming if enabled
if [[ "$enable_qt_apps" != "false" ]]; then
    generate_kdeglobals > "$KDEGLOBALS"
    
    # Generate Darkly color scheme for Qt style
    mkdir -p "$(dirname "$DARKLY_COLORS")"
    generate_darkly_colors > "$DARKLY_COLORS"
fi

# Generate Pywalfox colors for Firefox theming
mkdir -p "$XDG_STATE_HOME/quickshell/user/generated"
generate_pywalfox > "$XDG_STATE_HOME/quickshell/user/generated/pywalfox-colors.json"

# Restart Nautilus so it picks up new GTK CSS from matugen
nautilus -q 2>/dev/null &
