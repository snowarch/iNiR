# Greeting for iNiR installer
# This script is meant to be sourced.

# shellcheck shell=bash

#####################################################################################
# System Detection
#####################################################################################
detect_system() {
    # Distro detection
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DETECTED_DISTRO="${PRETTY_NAME:-$NAME}"
        DETECTED_DISTRO_ID="${ID}"
    else
        DETECTED_DISTRO="Unknown Linux"
        DETECTED_DISTRO_ID="unknown"
    fi

    # Shell detection
    DETECTED_SHELL=$(basename "${SHELL:-unknown}")
    
    # DE/WM detection
    if [[ -n "$NIRI_SOCKET" ]]; then
        DETECTED_DE="Niri"
    elif [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
        DETECTED_DE="Hyprland"
    elif [[ -n "$SWAYSOCK" ]]; then
        DETECTED_DE="Sway"
    elif [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
        DETECTED_DE="$XDG_CURRENT_DESKTOP"
    else
        DETECTED_DE="Not detected"
    fi

    # Session type
    DETECTED_SESSION="${XDG_SESSION_TYPE:-unknown}"
    
    # Check for AUR helper
    if command -v yay &>/dev/null; then
        DETECTED_AUR="yay"
    elif command -v paru &>/dev/null; then
        DETECTED_AUR="paru"
    else
        DETECTED_AUR="none (will install)"
    fi
}

detect_system

# Read version from VERSION file
DETECTED_VERSION="unknown"
if [[ -f "${REPO_ROOT}/VERSION" ]]; then
    DETECTED_VERSION="v$(cat "${REPO_ROOT}/VERSION" | tr -d '[:space:]')"
elif [[ -f "VERSION" ]]; then
    DETECTED_VERSION="v$(cat VERSION | tr -d '[:space:]')"
fi

#####################################################################################
# Greeting Surface
#####################################################################################
clear

local_visual_mode="plain"
$HAS_GUM && local_visual_mode="gum"

tui_hero_card \
    "Setup bootstrap" \
    "Install ${DETECTED_VERSION} with a shell-native first run tuned for ${DETECTED_DISTRO}." \
    "This flow prepares packages, services, theming, and user files before the runtime shell takes over."

tui_badge_row \
    "Version" "$DETECTED_VERSION" "accent" \
    "Distro" "$DETECTED_DISTRO_ID" "info" \
    "Session" "$DETECTED_SESSION" "muted" \
    "Compositor" "$DETECTED_DE" "accent-dim" \
    "AUR" "$DETECTED_AUR" "success" \
    "UI" "$local_visual_mode" "warning"

echo ""

system_snapshot=$(cat <<EOF
Version        ${DETECTED_VERSION}
Distro         ${DETECTED_DISTRO}
Shell          ${DETECTED_SHELL}
Session        ${DETECTED_SESSION}
Compositor     ${DETECTED_DE}
AUR helper     ${DETECTED_AUR}
EOF
)

tui_box "$system_snapshot" "System snapshot" "accent-dim" 62

echo ""

# Arch check with better messaging
if [[ "$DETECTED_DISTRO_ID" != "arch" && "$DETECTED_DISTRO_ID" != "endeavouros" && "$DETECTED_DISTRO_ID" != "manjaro" && "$DETECTED_DISTRO_ID" != "garuda" && "$DETECTED_DISTRO_ID" != "cachyos" ]]; then
    distro_warning=$(cat <<EOF
This installer is tuned for Arch-based distributions.
Detected target: ${DETECTED_DISTRO}
You can continue, but package resolution may fail outside the supported package ecosystem.
EOF
)
    tui_box "$distro_warning" "Compatibility warning" "warning" 72
    echo ""
fi

#####################################################################################
# Installation Plan
#####################################################################################
tui_title "Installation Plan"

install_plan=$(cat <<EOF
${ICON_ARROW} Install dependencies for Niri, Quickshell, Qt6, fonts, and shell runtime pieces
${ICON_ARROW} Configure user groups, services, and machine-level integration
${ICON_ARROW} Apply GTK/Qt theming, Material pipeline defaults, and Kvantum support
${ICON_ARROW} Copy configs into ~/.config with backups before replacing anything
${ICON_ARROW} Set the default wallpaper and generate the first terminal/theme payload
EOF
)

tui_box "$install_plan" "What happens next" "accent" 78

echo ""
tui_subtitle "Network speed and package mirror health will dominate total time."
tui_key_value "Backup location:" "$BACKUP_DIR"
echo ""
tui_info "You can cancel now without changing the system."
echo ""

if $ask; then
    if ! tui_confirm "Ready to install?"; then
        echo ""
        tui_info "Installation cancelled"
        exit 0
    fi
    echo ""
fi
