#!/usr/bin/env bash
# Install ii-pixel SDDM theme for iNiR
# Pixel aesthetic with Material You dynamic colors matching the Quickshell lockscreen.
# Requires: sddm, qt6-declarative, qt6-5compat

set -euo pipefail

THEME_NAME="ii-pixel"
THEME_SRC="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/dots/sddm/pixel"
THEME_DIR="/usr/share/sddm/themes/${THEME_NAME}"
SYNC_SCRIPT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/scripts/sddm/sync-pixel-sddm.py"
SDDM_CONF="/etc/sddm.conf.d/inir-theme.conf"

log_info() { echo -e "\033[0;36m[sddm] $*\033[0m"; }
log_ok()   { echo -e "\033[0;32m[sddm] ✓ $*\033[0m"; }
log_warn() { echo -e "\033[0;33m[sddm] ⚠ $*\033[0m"; }
log_err()  { echo -e "\033[0;31m[sddm] ✗ $*\033[0m"; }

# Check SDDM is installed
if ! command -v sddm &>/dev/null; then
    log_warn "SDDM not installed. Skipping theme setup."
    log_info "Install with: sudo pacman -S sddm qt6-declarative qt6-5compat"
    exit 0
fi

if [[ ! -d "$THEME_SRC" ]]; then
    log_err "Theme source not found: $THEME_SRC"
    exit 1
fi

# Install theme files
log_info "Installing ${THEME_NAME} to ${THEME_DIR}..."
sudo mkdir -p "${THEME_DIR}/assets"
sudo cp -rf "${THEME_SRC}/." "${THEME_DIR}/"
log_ok "Theme files installed"

# Transfer ownership to the current user so the sync script can update colors
# and wallpaper on every wallpaper change without triggering sudo/polkit prompts.
sudo chown -R "${USER}:${USER}" "${THEME_DIR}"
log_ok "Theme directory owned by ${USER} — sync requires no sudo"

# Create a placeholder background (symlinked to wallpaper later by sync script)
if [[ ! -f "${THEME_DIR}/assets/background.png" ]]; then
    log_info "No background.png yet — creating placeholder..."
    # Copy default wallpaper from iNiR assets as initial background
    local_repo="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    default_wall="${local_repo}/assets/images/default_wallpaper.png"
    if [[ -f "$default_wall" ]]; then
        sudo cp "$default_wall" "${THEME_DIR}/assets/background.png"
        log_ok "Default wallpaper set as background"
    else
        # Create a minimal 1x1 black PNG as placeholder
        python3 -c "
import struct, zlib
def make_png():
    sig = b'\x89PNG\r\n\x1a\n'
    def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0))
    idat = chunk(b'IDAT', zlib.compress(b'\x00\x14\x1b\x20'))
    iend = chunk(b'IEND', b'')
    return sig + ihdr + idat + iend
import sys; sys.stdout.buffer.write(make_png())
" | sudo tee "${THEME_DIR}/assets/background.png" > /dev/null
        log_warn "Placeholder background created — run sync-pixel-sddm.py to set wallpaper"
    fi
fi

# Configure SDDM to use this theme
log_info "Configuring SDDM to use ${THEME_NAME}..."
sudo mkdir -p /etc/sddm.conf.d
sudo tee "${SDDM_CONF}" > /dev/null << SDDM_EOF
[Theme]
Current=${THEME_NAME}
SDDM_EOF
log_ok "SDDM configured (${SDDM_CONF})"

# Run initial color sync now that files are in place
log_info "Running initial color sync..."
if python3 "$SYNC_SCRIPT" 2>/dev/null; then
    log_ok "Colors synced from Material You palette"
else
    log_warn "Color sync skipped (run after first wallpaper generation)"
fi

# Install sync script to ~/.local/bin for wallpaper change hook
SYNC_DST="${HOME}/.local/bin/sync-pixel-sddm.py"
mkdir -p "$(dirname "$SYNC_DST")"
cp "$SYNC_SCRIPT" "$SYNC_DST"
chmod +x "$SYNC_DST"
log_ok "Sync script installed to ${SYNC_DST}"

# Integrate with matugen post-hook (append to matugen config if not already there)
MATUGEN_CONFIG="${XDG_CONFIG_HOME:-${HOME}/.config}/matugen/config.toml"
if [[ -f "$MATUGEN_CONFIG" ]]; then
    if ! grep -q "sync-pixel-sddm" "$MATUGEN_CONFIG" 2>/dev/null; then
        log_info "Adding sync hook to matugen config..."
        cat >> "$MATUGEN_CONFIG" << 'MATUGEN_EOF'

[templates.ii-pixel-sddm-sync]
input_path = '/dev/null'
output_path = '/dev/null'
post_hook = 'python3 ~/.local/bin/sync-pixel-sddm.py &'
MATUGEN_EOF
        log_ok "Matugen sync hook added"
    else
        log_info "Matugen sync hook already present"
    fi
else
    log_warn "Matugen config not found — add sync hook manually:"
    log_warn "  python3 ~/.local/bin/sync-pixel-sddm.py"
fi

# Enable SDDM service
if command -v systemctl &>/dev/null && [[ -d /run/systemd/system ]]; then
    for dm in gdm lightdm lxdm greetd; do
        if systemctl is-enabled "${dm}.service" &>/dev/null 2>&1; then
            log_info "Disabling conflicting display manager: ${dm}"
            sudo systemctl disable "${dm}.service" 2>/dev/null || true
            break
        fi
    done
    sudo systemctl enable sddm.service 2>/dev/null && log_ok "SDDM service enabled"
fi

log_ok "${THEME_NAME} installed and configured"
log_info "Test with: sddm-greeter-qt6 --test-mode --theme ${THEME_DIR}"
log_info "Colors auto-sync on wallpaper change via matugen hook"
log_info "Manual re-sync: python3 ~/.local/bin/sync-pixel-sddm.py"
