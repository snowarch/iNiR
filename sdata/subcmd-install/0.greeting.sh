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
    
    # Package manager / host shape. These are hints only; dependency routing
    # still comes from dist-determine.sh.
    if declare -F get_package_manager >/dev/null 2>&1; then
        DETECTED_PACKAGE_MANAGER="$(get_package_manager)"
    else
        DETECTED_PACKAGE_MANAGER="unknown"
    fi

    if command -v yay &>/dev/null; then
        DETECTED_AUR="yay"
    elif command -v paru &>/dev/null; then
        DETECTED_AUR="paru"
    else
        DETECTED_AUR="none"
    fi

    DETECTED_CPU="$(awk -F: '/model name|Hardware/ {gsub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null)"
    [[ -n "$DETECTED_CPU" ]] || DETECTED_CPU="unknown"

    DETECTED_RAM_GIB="$(awk '/MemTotal:/ {printf "%.1f", $2/1024/1024; exit}' /proc/meminfo 2>/dev/null)"
    [[ -n "$DETECTED_RAM_GIB" ]] || DETECTED_RAM_GIB="?"

    DETECTED_GPU="unknown"
    if command -v lspci >/dev/null 2>&1; then
        DETECTED_GPU="$(lspci 2>/dev/null | awk -F': ' '/VGA compatible controller|3D controller|Display controller/ {print $2; exit}' \
            | sed -E 's/ \(rev [^)]+\)$//; s/^Advanced Micro Devices, Inc\. \[AMD\/ATI\] /AMD /; s/^NVIDIA Corporation /NVIDIA /; s/^Intel Corporation /Intel /')"
        [[ -n "$DETECTED_GPU" ]] || DETECTED_GPU="unknown"
    fi

    DETECTED_VIRT="none"
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        DETECTED_VIRT="$(systemd-detect-virt 2>/dev/null || true)"
        [[ -n "$DETECTED_VIRT" ]] || DETECTED_VIRT="none"
    fi

    DETECTED_PORTABLE="desktop"
    compgen -G '/sys/class/power_supply/BAT*' >/dev/null 2>&1 && DETECTED_PORTABLE="laptop"
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
    "Set up iNiR" \
    "Preparing ${DETECTED_VERSION} for ${DETECTED_DISTRO}." \
    "We'll install what this system needs, wire the session, keep backups, and leave the shell ready to start."

badges=(
    "Version" "$DETECTED_VERSION" "accent"
    "Distro" "$DETECTED_DISTRO_ID" "info"
    "Packages" "$DETECTED_PACKAGE_MANAGER" "success"
    "Session" "$DETECTED_SESSION" "muted"
    "Compositor" "$DETECTED_DE" "accent-dim"
)
[[ "${OS_GROUP_ID:-}" == "arch" ]] && badges+=("AUR" "$DETECTED_AUR" "success")
[[ "$DETECTED_VIRT" != "none" ]] && badges+=("VM" "$DETECTED_VIRT" "warning")
badges+=("UI" "$local_visual_mode" "warning")
tui_badge_row "${badges[@]}"

echo ""

system_snapshot=$(cat <<EOF
Version        ${DETECTED_VERSION}
Distro         ${DETECTED_DISTRO}
Packages       ${DETECTED_PACKAGE_MANAGER}
CPU            ${DETECTED_CPU}
GPU            ${DETECTED_GPU}
RAM            ${DETECTED_RAM_GIB} GiB
Host           ${DETECTED_PORTABLE}$( [[ "$DETECTED_VIRT" != "none" ]] && printf ' / %s VM' "$DETECTED_VIRT" )
Session        ${DETECTED_SESSION}
Compositor     ${DETECTED_DE}
EOF
)

tui_box "$system_snapshot" "System snapshot" "accent-dim" 62

echo ""

# Compatibility guidance follows the actual dependency router. Fedora and
# Debian/Ubuntu are first-class automated paths now; do not scare those users
# with the old Arch-only warning.
case "${OS_GROUP_ID:-unknown}" in
    arch|fedora|debian|ubuntu)
        tui_success "${DETECTED_DISTRO} has an automated dependency path."
        ;;
    nixos)
        tui_warn "NixOS is declarative: use the NixOS/Home Manager path in docs/NIXOS.md instead of treating this like a mutable distro."
        ;;
    *)
        compatibility_warning=$(cat <<EOF
Detected target: ${DETECTED_DISTRO}
The shell can still be installed, but dependency setup may need manual help on this distro.
Use './setup install --skip-deps' if you already manage the runtime packages yourself.
EOF
)
        tui_box "$compatibility_warning" "Compatibility note" "warning" 76
        ;;
esac

if declare -F is_immutable_distro >/dev/null 2>&1 && is_immutable_distro; then
    tui_warn "Atomic/immutable host detected. Package changes may be layered and can require a reboot before every runtime piece is visible."
fi

if [[ "$DETECTED_VIRT" != "none" ]]; then
    tui_info "VM detected ($DETECTED_VIRT). Blur, shader transitions and video performance can look very different from bare metal."
fi
if [[ "$DETECTED_GPU" == *NVIDIA* ]] && ! command -v nvidia-smi >/dev/null 2>&1; then
    tui_warn "NVIDIA GPU detected but nvidia-smi is not available. If rendering looks wrong, verify the driver before debugging shell effects."
fi
if [[ "$DETECTED_RAM_GIB" != "?" ]] && awk -v r="$DETECTED_RAM_GIB" 'BEGIN {exit !(r < 8)}'; then
    tui_info "Low-memory host detected (${DETECTED_RAM_GIB} GiB). Settings → Effects → Low power effects is worth enabling if the desktop feels heavy."
fi

echo ""

#####################################################################################
# Installation Plan
#####################################################################################
tui_title "Installation Plan"

install_plan=$(cat <<EOF
${ICON_ARROW} Install the runtime packages for ${DETECTED_DISTRO_ID} with ${DETECTED_PACKAGE_MANAGER}
${ICON_ARROW} Wire services, permissions and the Niri session
${ICON_ARROW} Install shell files and back up anything we replace
${ICON_ARROW} Generate the first Material palette, wallpaper and terminal theme
${ICON_ARROW} Save install state so Doctor, updates and rollback know what changed
EOF
)

tui_box "$install_plan" "What happens next" "accent" 78

echo ""
tui_subtitle "Most of the wait is package downloads; mirror/network speed matters more than the setup itself."
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
