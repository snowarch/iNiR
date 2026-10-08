#!/usr/bin/env bash
# Install ii-pixel SDDM theme for iNiR
# Pixel aesthetic with Material You dynamic colors matching the Quickshell lockscreen.
# Requires: sddm, qt6-declarative, qt6-5compat

set -euo pipefail

THEME_NAME="ii-pixel"
THEME_SRC="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/dots/sddm/pixel"
THEME_DIR="/usr/share/sddm/themes/${THEME_NAME}"
SYNC_SCRIPT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/scripts/sddm/sync-pixel-sddm.py"
# Use a high-priority drop-in name so SDDM's alphabetical merge picks our values
# LAST and we win against KDE's kde_settings.conf or any other foreign drop-in.
# Old name (legacy, pre-2.26): /etc/sddm.conf.d/inir-theme.conf — cleaned up below.
SDDM_CONF="/etc/sddm.conf.d/99-inir-theme.conf"
SDDM_CONF_LEGACY="/etc/sddm.conf.d/inir-theme.conf"
AUTO_APPLY_MODE="${INIR_SDDM_AUTO_APPLY:-ask}" # ask|yes|no
# Whether this run may make SDDM the login screen. An update only refreshes the theme: someone who went
# back to GDM or another display manager keeps it.
ENABLE_SERVICE="${INIR_SDDM_ENABLE_SERVICE:-yes}" # yes|no
GREETER_MODE="${INIR_SDDM_GREETER:-keep}"
GREETER_CONF="/etc/sddm.conf.d/98-inir-greeter.conf"
GREETER_KDL_SRC="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/dots/sddm/niri-greeter.kdl"
GREETER_KDL="/usr/share/inir/sddm/niri-greeter.kdl"

log_info() { echo -e "\033[0;36m[sddm] $*\033[0m"; }
log_ok()   { echo -e "\033[0;32m[sddm] ✓ $*\033[0m"; }
log_warn() { echo -e "\033[0;33m[sddm] ⚠ $*\033[0m"; }
log_err()  { echo -e "\033[0;31m[sddm] ✗ $*\033[0m"; }

# Intelligent privilege escalation: sudo for terminal, pkexec for graphical/IPC mode
elevate() {
  # If we have a TTY, use interactive sudo
  if [[ -t 0 ]] && [[ -t 1 ]]; then
    sudo "$@"
    return $?
  fi
  
  # Try non-interactive sudo first (works if NOPASSWD is configured or credentials cached)
  if sudo -n true 2>/dev/null; then
    sudo "$@"
    return $?
  fi
  
  # Try pkexec for graphical environments with polkit
  if command -v pkexec &>/dev/null && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    pkexec "$@"
    return $?
  fi
  
  # Last resort: try sudo anyway (may fail without TTY)
  sudo "$@"
}

get_current_sddm_theme() {
    local from_dropin=""
    # Check new high-priority drop-in first; fall back to legacy name during migration.
    for f in "$SDDM_CONF" "$SDDM_CONF_LEGACY"; do
        if [[ -f "$f" ]]; then
            from_dropin=$(awk -F= '/^[[:space:]]*Current[[:space:]]*=/{gsub(/[[:space:]]/,"",$2); print $2; exit}' "$f" 2>/dev/null || true)
            [[ -n "$from_dropin" ]] && break
        fi
    done
    if [[ -n "$from_dropin" ]]; then
        echo "$from_dropin"
        return 0
    fi

    # Fallback to main sddm.conf if present
    if [[ -f "/etc/sddm.conf" ]]; then
        awk -F= '/^[[:space:]]*Current[[:space:]]*=/{gsub(/[[:space:]]/,"",$2); print $2; exit}' /etc/sddm.conf 2>/dev/null || true
        return 0
    fi
    echo ""
}

should_apply_theme() {
    local current_theme
    current_theme="$(get_current_sddm_theme)"

    if [[ "$AUTO_APPLY_MODE" == "yes" ]]; then
        return 0
    fi
    if [[ "$AUTO_APPLY_MODE" == "no" ]]; then
        log_info "Skipping SDDM Current theme switch by policy (INIR_SDDM_AUTO_APPLY=no)"
        return 1
    fi

    if [[ -z "$current_theme" || "$current_theme" == "$THEME_NAME" ]]; then
        return 0
    fi

    echo ""
    log_warn "Detected current SDDM theme: ${current_theme}"
    read -r -p "[sddm] Apply ${THEME_NAME} as SDDM Current theme? [y/N] " reply
    case "$reply" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        *)
            log_info "Keeping current SDDM theme: ${current_theme}"
            return 1
            ;;
    esac
}

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
# If user already owns the theme dir (from a previous install), skip sudo entirely.
# This allows IPC-triggered updates (inir shell update) to refresh the theme
# without needing a terminal for sudo prompts.

# Checksum comparison: skip copy if source and target are identical.
# Only compare QML/JS/conf files (not assets like background.png which are user-generated).
theme_needs_update=true
if [[ -d "${THEME_DIR}" ]]; then
    src_hash=$(find "${THEME_SRC}" -maxdepth 1 -type f \( -name '*.qml' -o -name '*.js' -o -name '*.conf' -o -name 'metadata.desktop' \) -exec sha256sum {} + 2>/dev/null | sort | sha256sum | cut -d' ' -f1)
    tgt_hash=$(find "${THEME_DIR}" -maxdepth 1 -type f \( -name '*.qml' -o -name '*.js' -o -name '*.conf' -o -name 'metadata.desktop' \) -exec sha256sum {} + 2>/dev/null | sort | sha256sum | cut -d' ' -f1)
    if [[ -n "$src_hash" && "$src_hash" == "$tgt_hash" ]]; then
        theme_needs_update=false
    fi
fi

if $theme_needs_update; then
    log_info "Installing ${THEME_NAME} to ${THEME_DIR}..."
    if [[ -d "${THEME_DIR}" ]] && [[ -O "${THEME_DIR}" ]]; then
        # User already owns the directory — no sudo needed
        mkdir -p "${THEME_DIR}/assets"
        cp -rf "${THEME_SRC}/." "${THEME_DIR}/"
        log_ok "Theme files updated (no sudo needed — user owns dir)"
    else
        # First install or owned by root — requires elevation (sudo or pkexec)
        elevate mkdir -p "${THEME_DIR}/assets"
        elevate cp -rf "${THEME_SRC}/." "${THEME_DIR}/"
        log_ok "Theme files installed"

        # Transfer ownership to the current user so the sync script can update colors
        # and wallpaper on every wallpaper change without triggering sudo/polkit prompts.
        elevate chown -R "${USER}:${USER}" "${THEME_DIR}"
        log_ok "Theme directory owned by ${USER} — sync requires no sudo"
    fi
else
    log_ok "Theme files already up to date — skipping copy"
fi

# The iRiS appearance's faces, one static file per weight: the sddm user cannot read the shell's copy.
FONTS_SRC="${THEME_SRC%/dots/sddm/pixel}/assets/fonts"
for font in "$FONTS_SRC"/rubik/Rubik-*.ttf "$FONTS_SRC"/inter/Inter-{Regular,Medium,SemiBold,Bold}.ttf; do
    [[ -f "$font" ]] || continue
    target="${THEME_DIR}/fonts/$(basename "$font")"
    cmp -s "$font" "$target" && continue
    if [[ -O "${THEME_DIR}" ]]; then
        install -Dm644 "$font" "$target"
    else
        elevate install -Dm644 "$font" "$target"
    fi
done

# Create a placeholder background (symlinked to wallpaper later by sync script)
if [[ ! -f "${THEME_DIR}/assets/background.png" ]]; then
    log_info "No background.png yet — creating placeholder..."
    # Copy default wallpaper from iNiR assets as initial background
    repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
    default_wall="${repo_root}/assets/images/default_wallpaper.png"
    if [[ -f "$default_wall" ]]; then
        cp "$default_wall" "${THEME_DIR}/assets/background.png"
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
" > "${THEME_DIR}/assets/background.png"
        log_warn "Placeholder background created — run sync-pixel-sddm.py to set wallpaper"
    fi
fi

# Migrate from the old SDDM_CONF filename (inir-theme.conf) to the new
# alphabetical-last name (99-inir-theme.conf). Done idempotently: if the legacy
# file exists and we own the new name's location, just remove the legacy one.
migrate_legacy_sddm_conf() {
    [[ -f "$SDDM_CONF_LEGACY" ]] || return 0
    log_info "Removing legacy ${SDDM_CONF_LEGACY} (replaced by $(basename "$SDDM_CONF"))"
    elevate rm -f "$SDDM_CONF_LEGACY"
}

# Configure only the theme. DisplayServer, compositor and input-method policy
# belong to SDDM/distro provider packages (for example Fedora's sddm-x11 or
# sddm-wayland-* packages) and must not be overridden by a theme installer.
desired_conf="[Theme]
Current=${THEME_NAME}"

current_conf=""
[[ -f "$SDDM_CONF" ]] && current_conf=$(cat "$SDDM_CONF" 2>/dev/null || true)

if [[ "$current_conf" == "$desired_conf" ]]; then
    log_ok "SDDM configuration already up to date"
else
    if should_apply_theme; then
        log_info "Updating SDDM configuration (requires sudo)..."
        elevate mkdir -p /etc/sddm.conf.d
        echo "$desired_conf" | elevate tee "${SDDM_CONF}" > /dev/null
        log_ok "SDDM configured (${SDDM_CONF})"
    elif [[ -f "$SDDM_CONF" ]] && grep -q "Current=${THEME_NAME}" "$SDDM_CONF" 2>/dev/null; then
        # Theme is already ii-pixel but settings are stale — update without asking
        log_info "Updating SDDM settings (requires sudo)..."
        elevate mkdir -p /etc/sddm.conf.d
        echo "$desired_conf" | elevate tee "${SDDM_CONF}" > /dev/null
        log_ok "SDDM settings updated (${SDDM_CONF})"
    else
        log_info "Installed ${THEME_NAME}, but did not change SDDM Current theme"
    fi
fi

# Login screen display server. X11 is SDDM's default on Arch; on laptops with an NVIDIA GPU next to the
# integrated one, Xorg can start on the GPU that has no screens attached and the greeter stays black
# (https://bbs.archlinux.org/viewtopic.php?id=291860). Niri drives the right GPU, as GDM's Wayland greeter does.
apply_greeter_mode() {
    case "$GREETER_MODE" in
        niri)
            local niri_bin
            niri_bin="$(command -v niri || true)"
            if [[ -z "$niri_bin" || ! -f "$GREETER_KDL_SRC" ]]; then
                log_warn "Niri or the greeter config is missing; login screen left as it is"
                return 0
            fi
            local desired="[General]
DisplayServer=wayland

[Wayland]
CompositorCommand=${niri_bin} -c ${GREETER_KDL}"
            elevate install -Dm644 "$GREETER_KDL_SRC" "$GREETER_KDL"
            if [[ "$(cat "$GREETER_CONF" 2>/dev/null || true)" != "$desired" ]]; then
                elevate mkdir -p /etc/sddm.conf.d
                echo "$desired" | elevate tee "$GREETER_CONF" > /dev/null
            fi
            log_ok "Login screen runs on Wayland with Niri (${GREETER_CONF})"
            ;;
        x11)
            if [[ -f "$GREETER_CONF" ]]; then
                elevate rm -f "$GREETER_CONF"
                log_ok "Login screen back to the distribution's default display server"
            fi
            ;;
    esac
}
apply_greeter_mode

# Clean up legacy drop-in name (if user is migrating from pre-2.26 install).
# Our new 99- prefixed file already wins by alphabetical merge order.
migrate_legacy_sddm_conf

# Run initial color sync now that files are in place
log_info "Running initial color sync..."
if python3 "$SYNC_SCRIPT" 2>/dev/null; then
    log_ok "Colors synced from Material You palette"
else
    log_warn "Color sync skipped (run after first wallpaper generation)"
fi

# The colour pipeline runs the sync from the iNiR tree (scripts/colors/modules/60-sddm.sh); the copy older
# installs left here went stale and raced it.
rm -f "${HOME}/.local/bin/sync-pixel-sddm.py"

# NOTE: We no longer mutate the user theming config here.
# Color sync runs from the unified Python theming pipeline. Keep installer idempotent.

# Cleanup stale sudo-based hook variants from very old setups if present
MATUGEN_CONFIG="${XDG_CONFIG_HOME:-${HOME}/.config}/matugen/config.toml"
if [[ -f "$MATUGEN_CONFIG" ]]; then
    if grep -qE "post_hook\s*=\s*'.*sudo.*sync-pixel-sddm\.py" "$MATUGEN_CONFIG" 2>/dev/null; then
        log_warn "Detected legacy sudo SDDM theming hook in user config"
        log_warn "Please remove old ii-pixel-sddm hook block from: $MATUGEN_CONFIG"
    fi
fi

# Enable SDDM service (only on first install — on updates the service is already enabled,
# and running sudo without a terminal would fail in IPC mode)
if [[ "$ENABLE_SERVICE" == "yes" ]] && command -v systemctl &>/dev/null && [[ -d /run/systemd/system ]]; then
    if ! systemctl is-enabled sddm.service &>/dev/null 2>&1; then
        # Handle conflicting display-manager.service symlink (e.g., plasmalogin, gdm, etc.)
        if [[ -L /etc/systemd/system/display-manager.service ]]; then
            current_dm=$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null | xargs basename 2>/dev/null || echo "unknown")
            if [[ "$current_dm" != "sddm.service" ]]; then
                log_info "Removing conflicting display-manager.service -> ${current_dm}"
                elevate rm -f /etc/systemd/system/display-manager.service 2>/dev/null || true
            fi
        fi
        
        # Disable known conflicting display managers
        for dm in gdm lightdm lxdm greetd plasmalogin; do
            if systemctl is-enabled "${dm}.service" &>/dev/null 2>&1; then
                log_info "Disabling conflicting display manager: ${dm}"
                elevate systemctl disable "${dm}.service" 2>/dev/null || true
            fi
        done
        
        elevate systemctl enable sddm.service 2>/dev/null && log_ok "SDDM service enabled"
    fi
fi

log_ok "${THEME_NAME} installed and configured"
log_info "Test with: sddm-greeter-qt6 --test-mode --theme ${THEME_DIR}"
log_info "Colors auto-sync on wallpaper change via the iNiR theming pipeline"
