#!/usr/bin/env bash
set -euo pipefail
# Apply Qt/KDE/GTK theme colors from iNiR's generated palette contract.
# Generates:
#   - GTK3 and GTK4/libadwaita CSS overrides
#   - kdeglobals (KDE/Qt app colors for Dolphin, etc.)
#   - Darkly.colors (Qt style color scheme)
#   - Pywalfox colors (Firefox theming)
#   - Vesktop/Discord theme (if enabled)
#   - qt5ct/qt6ct color scheme config
# Prefers palette.json and falls back to colors.json for compatibility.

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
PALETTE_JSON="$XDG_STATE_HOME/quickshell/user/generated/palette.json"
COLORS_JSON="$XDG_STATE_HOME/quickshell/user/generated/colors.json"
KDEGLOBALS="$HOME/.config/kdeglobals"
DARKLY_COLORS="$XDG_DATA_HOME/color-schemes/Darkly.colors"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/lib/config-path.sh
source "$SCRIPT_DIR/../lib/config-path.sh"
SHELL_CONFIG_FILE="$(inir_config_file)"

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

# Read colors from the explicit palette contract first, then fall back to colors.json
COLOR_SOURCE="$PALETTE_JSON"
if [[ ! -f "$COLOR_SOURCE" ]]; then
    COLOR_SOURCE="$COLORS_JSON"
fi

if [[ ! -f "$COLOR_SOURCE" ]] || ! command -v jq &>/dev/null; then
    echo "[apply-gtk-theme] palette/colors JSON not found or jq missing, skipping"
    exit 0
fi

BG=$(jq -r '.background // empty' "$COLOR_SOURCE" 2>/dev/null || echo "#1e1e2e")
FG=$(jq -r '.on_background // empty' "$COLOR_SOURCE" 2>/dev/null || echo "#cdd6f4")
PRIMARY=$(jq -r '.primary // empty' "$COLOR_SOURCE" 2>/dev/null || echo "#cba6f7")
ON_PRIMARY=$(jq -r '.on_primary // empty' "$COLOR_SOURCE" 2>/dev/null || echo "#1e1e2e")
SURFACE=$(jq -r '.surface // empty' "$COLOR_SOURCE" 2>/dev/null || echo "$BG")
ON_SURFACE=$(jq -r '.on_surface // empty' "$COLOR_SOURCE" 2>/dev/null || echo "$FG")
SURFACE_CONTAINER=$(jq -r '.surface_container // empty' "$COLOR_SOURCE" 2>/dev/null)
SURFACE_CONTAINER_HIGH=$(jq -r '.surface_container_high // empty' "$COLOR_SOURCE" 2>/dev/null)
SURFACE_CONTAINER_LOW=$(jq -r '.surface_container_low // empty' "$COLOR_SOURCE" 2>/dev/null)
SURFACE_DIM=$(jq -r '.surface_dim // empty' "$COLOR_SOURCE" 2>/dev/null)
OUTLINE_VARIANT=$(jq -r '.outline_variant // empty' "$COLOR_SOURCE" 2>/dev/null)
SURFACE_CONTAINER_HIGHEST=$(jq -r '.surface_container_highest // empty' "$COLOR_SOURCE" 2>/dev/null)

# Semantic colors from Material tokens
ERROR_COLOR=$(jq -r '.error // empty' "$COLOR_SOURCE" 2>/dev/null)
TERTIARY=$(jq -r '.tertiary // empty' "$COLOR_SOURCE" 2>/dev/null)
SECONDARY=$(jq -r '.secondary // empty' "$COLOR_SOURCE" 2>/dev/null)

# If ThemePresets passes args (bg fg primary on_primary surface surface_dim), use them
# This avoids the race condition between generateColorsJson() writing to disk and this script reading
if [[ -n "${1:-}" ]]; then
    BG="$1"
    FG="${2:-$FG}"
    PRIMARY="${3:-$PRIMARY}"
    ON_PRIMARY="${4:-$ON_PRIMARY}"
    SURFACE="${5:-$SURFACE}"
    SURFACE_DIM="${6:-$SURFACE_DIM}"
    # Derive extra colors from available values when args provided
    ON_SURFACE="$FG"
    SURFACE_CONTAINER="$SURFACE"
    SURFACE_CONTAINER_HIGH="$SURFACE"
    SURFACE_CONTAINER_LOW="$SURFACE_DIM"
    OUTLINE_VARIANT="$SURFACE_DIM"
    SURFACE_CONTAINER_HIGHEST="$SURFACE"
fi

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

# Break a symlink, replacing it with a regular file slot.
# Prevents writing through symlinks to external themes.
break_symlink() {
    [[ -L "$1" ]] && rm -f "$1"
}

# Derive missing surface variants from BG — fallback when palette.json is incomplete
[[ -z "$SURFACE_DIM" ]]              && SURFACE_DIM=$(adjust_color "$BG" -10)
[[ -z "$SURFACE_CONTAINER" ]]        && SURFACE_CONTAINER=$(adjust_color "$BG" 13)
[[ -z "$SURFACE_CONTAINER_LOW" ]]    && SURFACE_CONTAINER_LOW=$(adjust_color "$BG" 9)
[[ -z "$SURFACE_CONTAINER_HIGH" ]]   && SURFACE_CONTAINER_HIGH=$(adjust_color "$BG" 23)
[[ -z "$SURFACE_CONTAINER_HIGHEST" ]] && SURFACE_CONTAINER_HIGHEST=$(adjust_color "$BG" 34)
[[ -z "$OUTLINE_VARIANT" ]]          && OUTLINE_VARIANT=$(adjust_color "$BG" 52)

# Derive semantic color fallbacks from Material tokens
[[ -z "$ERROR_COLOR" ]] && ERROR_COLOR="#ff6b6b"
[[ -z "$TERTIARY" ]]    && TERTIARY="#ffa94d"
[[ -z "$SECONDARY" ]]   && SECONDARY="#69db7c"

# Map to KDE semantic names
FG_NEGATIVE="$ERROR_COLOR"
FG_NEUTRAL="$TERTIARY"
FG_POSITIVE="$SECONDARY"

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
    # Generate pywalfox-compatible JSON from iNiR palette for Firefox theming
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
ForegroundNegative=${FG_NEGATIVE}
ForegroundNeutral=${FG_NEUTRAL}
ForegroundNormal=${FG}
ForegroundPositive=${FG_POSITIVE}
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
ForegroundNegative=${FG_NEGATIVE}
ForegroundNeutral=${FG_NEUTRAL}
ForegroundNormal=${FG}
ForegroundPositive=${FG_POSITIVE}
ForegroundVisited=${PRIMARY}

[Colors:View]
BackgroundAlternate=${BG}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=${FG_NEGATIVE}
ForegroundNeutral=${FG_NEUTRAL}
ForegroundNormal=${FG}
ForegroundPositive=${FG_POSITIVE}
ForegroundVisited=${PRIMARY}

[Colors:Window]
BackgroundAlternate=${BG}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=${FG_NEGATIVE}
ForegroundNeutral=${FG_NEUTRAL}
ForegroundNormal=${FG}
ForegroundPositive=${FG_POSITIVE}
ForegroundVisited=${PRIMARY}

[Colors:Complementary]
BackgroundAlternate=${BG_DARK}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=${FG_NEGATIVE}
ForegroundNeutral=${FG_NEUTRAL}
ForegroundNormal=${FG}
ForegroundPositive=${FG_POSITIVE}
ForegroundVisited=${PRIMARY}

[Colors:Header]
BackgroundAlternate=${BG}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=${FG_NEGATIVE}
ForegroundNeutral=${FG_NEUTRAL}
ForegroundNormal=${FG}
ForegroundPositive=${FG_POSITIVE}
ForegroundVisited=${PRIMARY}

[Colors:Header][Inactive]
BackgroundAlternate=${BG}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=${FG_NEGATIVE}
ForegroundNeutral=${FG_NEUTRAL}
ForegroundNormal=${FG}
ForegroundPositive=${FG_POSITIVE}
ForegroundVisited=${PRIMARY}

[Colors:Menu]
BackgroundAlternate=${BG_ALT}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=${FG_NEGATIVE}
ForegroundNeutral=${FG_NEUTRAL}
ForegroundNormal=${FG}
ForegroundPositive=${FG_POSITIVE}
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
    local error_rgb=$(hex_to_rgb "$FG_NEGATIVE")
    local neutral_rgb=$(hex_to_rgb "$FG_NEUTRAL")
    local positive_rgb=$(hex_to_rgb "$FG_POSITIVE")
    
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
ForegroundNegative=${error_rgb}
ForegroundNeutral=${neutral_rgb}
ForegroundNormal=${fg_rgb}
ForegroundPositive=${positive_rgb}
ForegroundVisited=${primary_rgb}

[Colors:Complementary]
BackgroundAlternate=${bg_dark_rgb}
BackgroundNormal=${bg_rgb}
DecorationFocus=${primary_rgb}
DecorationHover=${primary_rgb}
ForegroundActive=${fg_rgb}
ForegroundInactive=${fg_inactive_rgb}
ForegroundLink=${primary_rgb}
ForegroundNegative=${error_rgb}
ForegroundNeutral=${neutral_rgb}
ForegroundNormal=${fg_rgb}
ForegroundPositive=${positive_rgb}
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
ForegroundNegative=${error_rgb}
ForegroundNeutral=${neutral_rgb}
ForegroundNormal=${fg_rgb}
ForegroundPositive=${positive_rgb}
ForegroundVisited=${primary_rgb}

[Colors:View]
BackgroundAlternate=${bg_rgb}
BackgroundNormal=${bg_rgb}
DecorationFocus=${primary_rgb}
DecorationHover=${primary_rgb}
ForegroundActive=${fg_rgb}
ForegroundInactive=${fg_inactive_rgb}
ForegroundLink=${primary_rgb}
ForegroundNegative=${error_rgb}
ForegroundNeutral=${neutral_rgb}
ForegroundNormal=${fg_rgb}
ForegroundPositive=${positive_rgb}
ForegroundVisited=${primary_rgb}

[Colors:Window]
BackgroundAlternate=${bg_alt_rgb}
BackgroundNormal=${bg_rgb}
DecorationFocus=${primary_rgb}
DecorationHover=${primary_rgb}
ForegroundActive=${fg_rgb}
ForegroundInactive=${fg_inactive_rgb}
ForegroundLink=${primary_rgb}
ForegroundNegative=${error_rgb}
ForegroundNeutral=${neutral_rgb}
ForegroundNormal=${fg_rgb}
ForegroundPositive=${positive_rgb}
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

# Generate GTK3 CSS (legacy apps)
GTK3_CSS="$HOME/.config/gtk-3.0/gtk.css"
mkdir -p "$(dirname "$GTK3_CSS")"
break_symlink "$GTK3_CSS"
cat > "$GTK3_CSS" << EOF
/*
 * GTK Colors - Generated with iNiR theming
 * This file is overwritten when you change wallpaper
 */

@define-color accent_color ${PRIMARY};
@define-color accent_fg_color ${ON_PRIMARY};
@define-color accent_bg_color ${PRIMARY};

@define-color window_bg_color ${BG};
@define-color window_fg_color ${FG};

@define-color headerbar_bg_color ${BG};
@define-color headerbar_fg_color ${FG};

@define-color popover_bg_color ${SURFACE_CONTAINER};
@define-color popover_fg_color ${ON_SURFACE};

@define-color view_bg_color ${BG};
@define-color view_fg_color ${FG};

@define-color card_bg_color ${SURFACE_CONTAINER_LOW};
@define-color card_fg_color ${ON_SURFACE};

@define-color sidebar_bg_color ${BG};
@define-color sidebar_fg_color ${FG};
@define-color sidebar_border_color ${BG};
@define-color sidebar_backdrop_color ${BG};

headerbar {
    background-color: ${BG} !important;
    box-shadow: none !important;
    border-bottom: none !important;
}

headerbar separator {
    background-color: transparent !important;
}

.nautilus-window .sidebar,
.nautilus-window sidebar,
placessidebar,
placessidebar list {
    background-color: ${BG} !important;
    color: ${FG} !important;
    border-right: none !important;
}

placessidebar row {
    background-color: transparent !important;
    color: ${FG} !important;
}

placessidebar row:hover {
    background-color: alpha(${PRIMARY}, 0.08) !important;
}

placessidebar row:selected,
placessidebar row:selected:hover {
    background-color: alpha(${PRIMARY}, 0.15) !important;
    color: ${PRIMARY} !important;
}

placessidebar image {
    color: inherit !important;
}

.view {
    background-color: ${BG} !important;
}

separator.sidebar {
    background-color: transparent !important;
    min-width: 0;
}

/* Context menus and popovers */
popover,
popover.background {
    background-color: ${SURFACE_CONTAINER} !important;
    color: ${ON_SURFACE} !important;
}

menu,
.context-menu,
.popup {
    background-color: ${SURFACE_CONTAINER} !important;
    color: ${ON_SURFACE} !important;
}

menuitem {
    color: ${ON_SURFACE} !important;
}

menuitem:hover,
menuitem:selected {
    background-color: alpha(${PRIMARY}, 0.12) !important;
}

menu separator {
    background-color: alpha(${ON_SURFACE}, 0.12) !important;
}
EOF

# Generate GTK4/libadwaita CSS (Nautilus, GNOME apps)
GTK4_CSS="$HOME/.config/gtk-4.0/gtk.css"
mkdir -p "$(dirname "$GTK4_CSS")"
break_symlink "$GTK4_CSS"
cat > "$GTK4_CSS" << EOF
/*
 * GTK4/libadwaita Colors — Generated by iNiR theming
 * This file is overwritten when you change wallpaper or apply a color theme.
 * Dark colors applied unconditionally so they work without xdg-desktop-portal.
 */

@define-color accent_color ${PRIMARY};
@define-color accent_fg_color ${ON_PRIMARY};
@define-color accent_bg_color ${PRIMARY};

@define-color window_bg_color ${BG};
@define-color window_fg_color ${FG};

@define-color headerbar_bg_color ${BG};
@define-color headerbar_fg_color ${FG};

@define-color popover_bg_color ${SURFACE_CONTAINER};
@define-color popover_fg_color ${ON_SURFACE};

@define-color dialog_bg_color ${SURFACE_CONTAINER_HIGH};
@define-color dialog_fg_color ${ON_SURFACE};

@define-color view_bg_color ${BG};
@define-color view_fg_color ${FG};

@define-color card_bg_color ${SURFACE_CONTAINER_LOW};
@define-color card_fg_color ${ON_SURFACE};

@define-color sidebar_bg_color ${BG};
@define-color sidebar_fg_color ${FG};
@define-color sidebar_border_color ${BG};
@define-color sidebar_backdrop_color ${BG};

@define-color thumbnail_bg_color ${SURFACE_CONTAINER_HIGHEST};
@define-color thumbnail_fg_color ${ON_SURFACE};

@define-color card_shade_color alpha(black, 0.15);
@define-color shade_color alpha(black, 0.25);
@define-color scrollbar_outline_color alpha(white, 0.1);

headerbar {
    background-color: ${BG} !important;
    box-shadow: none !important;
    border-bottom: none !important;
}

headerbar separator {
    background-color: transparent !important;
}

.nautilus-window .sidebar,
.nautilus-window sidebar,
navigation-view > navigation-sidebar,
placessidebar,
placessidebar list {
    background-color: ${BG} !important;
    color: ${FG} !important;
    border-right: none !important;
}

placessidebar row {
    background-color: transparent !important;
    color: ${FG} !important;
}

placessidebar row:hover {
    background-color: alpha(${PRIMARY}, 0.08) !important;
}

placessidebar row:selected,
placessidebar row:selected:hover {
    background-color: alpha(${PRIMARY}, 0.15) !important;
    color: ${PRIMARY} !important;
}

placessidebar image {
    color: inherit !important;
}

.view,
.nautilus-window .view {
    background-color: ${BG} !important;
}

separator.sidebar,
paned > separator {
    background-color: transparent !important;
    min-width: 0;
}

/* Remove navigation pane borders */
.navigation-sidebar {
    border-right: none !important;
}

/* Context menus and popovers */
popover,
popover > contents {
    background-color: ${SURFACE_CONTAINER} !important;
    color: ${ON_SURFACE} !important;
}

popover modelbutton:hover,
popover row:hover {
    background-color: alpha(${PRIMARY}, 0.08) !important;
}

popover modelbutton:selected,
popover row:selected {
    background-color: alpha(${PRIMARY}, 0.14) !important;
}

popover separator {
    background-color: alpha(${ON_SURFACE}, 0.12) !important;
}

/* Menu styling (GtkPopoverMenu in GTK4) */
popover.menu > contents,
popover.menu box.inline-buttons {
    background-color: ${SURFACE_CONTAINER} !important;
    color: ${ON_SURFACE} !important;
}

popover.menu modelbutton {
    color: ${ON_SURFACE} !important;
}

popover.menu modelbutton:hover {
    background-color: alpha(${PRIMARY}, 0.08) !important;
}

popover.menu accelerator {
    color: alpha(${ON_SURFACE}, 0.55) !important;
}
EOF

# Configure qt6ct to use the Darkly color scheme (fixes Dolphin and other Qt apps being white)
# qt6ct is the platform theme (QT_QPA_PLATFORMTHEME=qt6ct) — it needs a color scheme
QT6CT_CONF="$HOME/.config/qt6ct/qt6ct.conf"
mkdir -p "$(dirname "$QT6CT_CONF")"
CURRENT_ICON_THEME=$(grep '^icon_theme=' "$QT6CT_CONF" 2>/dev/null | cut -d= -f2)
[[ -z "$CURRENT_ICON_THEME" ]] && CURRENT_ICON_THEME="Adwaita"
CURRENT_QT_STYLE=$(grep '^style=' "$QT6CT_CONF" 2>/dev/null | cut -d= -f2)
[[ -z "$CURRENT_QT_STYLE" ]] && CURRENT_QT_STYLE="Darkly"
cat > "$QT6CT_CONF" << EOF
[Appearance]
color_scheme_path=${DARKLY_COLORS}
custom_palette=true
icon_theme=${CURRENT_ICON_THEME}
style=${CURRENT_QT_STYLE}
EOF

# Configure qt5ct to use the Darkly color scheme (mirrors qt6ct setup above)
QT5CT_CONF="$HOME/.config/qt5ct/qt5ct.conf"
mkdir -p "$(dirname "$QT5CT_CONF")"
CURRENT_QT5_ICON_THEME=$(grep '^icon_theme=' "$QT5CT_CONF" 2>/dev/null | cut -d= -f2)
[[ -z "$CURRENT_QT5_ICON_THEME" ]] && CURRENT_QT5_ICON_THEME="$CURRENT_ICON_THEME"
CURRENT_QT5_STYLE=$(grep '^style=' "$QT5CT_CONF" 2>/dev/null | cut -d= -f2)
[[ -z "$CURRENT_QT5_STYLE" ]] && CURRENT_QT5_STYLE="Darkly"
cat > "$QT5CT_CONF" << EOF
[Appearance]
color_scheme_path=${DARKLY_COLORS}
custom_palette=true
icon_theme=${CURRENT_QT5_ICON_THEME}
style=${CURRENT_QT5_STYLE}
EOF

# Sync icon theme and cursor to GTK settings.ini files
# These are static files that become stale when user changes icon theme at runtime
sync_gtk_settings_ini() {
    local settings_file="$1"
    [[ ! -f "$settings_file" ]] && return

    local current_icon
    current_icon=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
    [[ -z "$current_icon" ]] && return

    local current_cursor
    current_cursor=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'")

    # Update icon theme in place
    if grep -q '^gtk-icon-theme-name=' "$settings_file"; then
        sed -i "s/^gtk-icon-theme-name=.*/gtk-icon-theme-name=${current_icon}/" "$settings_file"
    fi

    # Update cursor theme in place (if present and we have a value)
    if [[ -n "$current_cursor" ]] && grep -q '^gtk-cursor-theme-name=' "$settings_file"; then
        sed -i "s/^gtk-cursor-theme-name=.*/gtk-cursor-theme-name=${current_cursor}/" "$settings_file"
    fi
}

sync_gtk_settings_ini "$HOME/.config/gtk-3.0/settings.ini"
sync_gtk_settings_ini "$HOME/.config/gtk-4.0/settings.ini"

# Restart Nautilus so it picks up new GTK CSS
nautilus -q 2>/dev/null &
