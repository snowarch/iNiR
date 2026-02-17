#!/usr/bin/env bash
# Install and configure SilentSDDM theme for iNiR
# This script requires sudo access and is called from setup install

set -euo pipefail

THEME_NAME="silent"
THEME_DIR="/usr/share/sddm/themes/${THEME_NAME}"
SDDM_CONF="/etc/sddm.conf"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/sddm-theme"

log_info() { echo -e "\033[0;36m[sddm] $*\033[0m"; }
log_ok()   { echo -e "\033[0;32m[sddm] ✓ $*\033[0m"; }
log_warn() { echo -e "\033[0;33m[sddm] $*\033[0m"; }
log_err()  { echo -e "\033[0;31m[sddm] ✗ $*\033[0m"; }

# Check if SDDM is installed
if ! command -v sddm &>/dev/null; then
    log_warn "SDDM not installed. Skipping theme setup."
    log_info "Install with: sudo pacman -S sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg"
    exit 0
fi

SUDO_PASS="${INIR_SUDO_PASS:-}"

run_sudo() {
    if [[ -n "$SUDO_PASS" ]]; then
        echo "$SUDO_PASS" | sudo -S "$@" 2>/dev/null
    else
        sudo "$@"
    fi
}

# Clone or update SilentSDDM
log_info "Setting up SilentSDDM theme..."
mkdir -p "$CACHE_DIR"

if [[ -d "$CACHE_DIR/SilentSDDM/.git" ]]; then
    log_info "Updating existing SilentSDDM clone..."
    git -C "$CACHE_DIR/SilentSDDM" pull --ff-only 2>/dev/null || true
else
    rm -rf "$CACHE_DIR/SilentSDDM"
    git clone -b main --depth=1 https://github.com/uiriansan/SilentSDDM "$CACHE_DIR/SilentSDDM" 2>&1 | tail -1
fi

if [[ ! -d "$CACHE_DIR/SilentSDDM" ]]; then
    log_err "Failed to clone SilentSDDM"
    exit 1
fi

# Create iNiR custom config
# Minimal, dark, clean — complements iNiR's Material You aesthetic
cat > "$CACHE_DIR/SilentSDDM/configs/inir.conf" << 'CONF_EOF'
# iNiR SilentSDDM Configuration
# Minimal dark login screen complementing Material You theming

[General]
# Background — uses user's current wallpaper if available, falls back to bundled
Background=""
BackgroundSpeed=1.0
BackgroundPausedOnLogin=true

# Layout
ScreenPadding=60
FormPosition="center"

# Behavior
HideLoginButton=false
HideVirtualKeyboardButton=true
HideSystemButtons=false
HideSessionButton=false

# Date & time
DateFormat="dddd, MMMM d"
TimeFormat="hh:mm"

[Appearance]
# Font
FontFamily="Rubik"
FontSize=13
HeaderFontSize=48

# Colors — dark Material You base (overridden by sync script when available)
AccentColor="#cac4d5"
BackgroundColor="#0f0e0f"
FormBackgroundColor="#1d1b20"
FormBorderColor="#49454f"
LoginButtonBackgroundColor="#cac4d5"
LoginButtonTextColor="#322e3c"
TextColor="#e6e1e6"
PlaceholderColor="#938f99"
SessionButtonColor="#cac4d5"
SystemButtonColor="#cac4d5"
DateColor="#e6e1e6"
TimeColor="#e6e1e6"

# Shape
FormRadius=16
InputRadius=12
LoginButtonRadius=24
AvatarRadius=999

# Effects
DimBackground=true
DimBackgroundAmount=0.45
BlurBackground=true
BlurBackgroundAmount=32
FormHasShadow=true
InputHasShadow=false

# Avatar
AvatarSize=96
ShowAvatar=true
CONF_EOF

log_ok "iNiR config created"

# Set iNiR config as active in metadata.desktop
sed -i 's|^ConfigFile=.*|ConfigFile=configs/inir.conf|' "$CACHE_DIR/SilentSDDM/metadata.desktop"

# Install theme to system directory
log_info "Installing theme to ${THEME_DIR}..."
run_sudo mkdir -p "$THEME_DIR"
run_sudo cp -rf "$CACHE_DIR/SilentSDDM/." "$THEME_DIR/"

# Install fonts
if [[ -d "$THEME_DIR/fonts" ]]; then
    run_sudo cp -r "$THEME_DIR/fonts/"* /usr/share/fonts/ 2>/dev/null || true
    fc-cache -f 2>/dev/null || true
fi

# Configure SDDM to use Silent theme
log_info "Configuring SDDM..."
if [[ -f "$SDDM_CONF" ]]; then
    # Backup existing config
    run_sudo cp "$SDDM_CONF" "${SDDM_CONF}.bak"
fi

# Write sddm.conf
run_sudo tee "$SDDM_CONF" > /dev/null << SDDM_EOF
[General]
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard

[Theme]
Current=silent
SDDM_EOF

# Enable SDDM service (only if no other DM is enabled)
if command -v systemctl &>/dev/null && [[ -d /run/systemd/system ]]; then
    # Check if any display manager is already enabled
    local_dm_enabled=false
    for dm in gdm lightdm lxdm sddm greetd; do
        if systemctl is-enabled "${dm}.service" &>/dev/null 2>&1; then
            local_dm_enabled=true
            if [[ "$dm" != "sddm" ]]; then
                log_info "Display manager '${dm}' already enabled. Switching to SDDM..."
                run_sudo systemctl disable "${dm}.service" 2>/dev/null || true
                local_dm_enabled=false
            fi
            break
        fi
    done

    if ! $local_dm_enabled || systemctl is-enabled sddm.service &>/dev/null 2>&1; then
        run_sudo systemctl enable sddm.service 2>/dev/null || true
        log_ok "SDDM service enabled"
    fi
fi

log_ok "SilentSDDM theme installed and configured"
