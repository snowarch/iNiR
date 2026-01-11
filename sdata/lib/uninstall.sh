# Uninstall command for iNiR
# Safely removes iNiR while preserving user data
# This script is meant to be sourced.

# shellcheck shell=bash

###############################################################################
# Configuration
###############################################################################

# Files/directories installed by iNiR
# Format: path:type:description
# Types: dir (remove entirely), file (remove file), managed (iNiR-managed, safe to remove)
INIR_INSTALLED_PATHS=(
    # Core iNiR
    "${XDG_CONFIG_HOME}/quickshell/ii:dir:Quickshell ii config"
    "${XDG_CONFIG_HOME}/illogical-impulse:dir:iNiR user config"

    # State and cache
    "${XDG_STATE_HOME}/quickshell:dir:Quickshell state (themes, notifications)"
    "${XDG_CACHE_HOME}/quickshell:dir:Quickshell cache"
    "${SNAPSHOTS_DIR:-${XDG_STATE_HOME}/quickshell/snapshots}:dir:iNiR snapshots"

    # Niri config (user may have customized - ask)
    "${XDG_CONFIG_HOME}/niri/config.kdl:file:Niri config"

    # Theming configs (iNiR-managed)
    "${XDG_CONFIG_HOME}/matugen:dir:Matugen config"
    "${XDG_CONFIG_HOME}/Kvantum/MaterialAdw:dir:Kvantum MaterialAdw theme"
    "${XDG_CONFIG_HOME}/Kvantum/kvantum.kvconfig:file:Kvantum config"
    "${XDG_CONFIG_HOME}/kdeglobals:file:KDE globals"
    "${XDG_CONFIG_HOME}/dolphinrc:file:Dolphin config"
    "${XDG_STATE_HOME:-$HOME/.local/state}/dolphinstaterc:file:Dolphin state"

    # GTK theming
    "${XDG_CONFIG_HOME}/gtk-3.0/gtk.css:file:GTK3 custom CSS"
    "${XDG_CONFIG_HOME}/gtk-4.0/gtk.css:file:GTK4 custom CSS"

    # Vesktop themes
    "${XDG_CONFIG_HOME}/vesktop/themes/system24.theme.css:file:Vesktop theme"
    "${XDG_CONFIG_HOME}/vesktop/themes/ii-colors.css:file:Vesktop colors"
    "${XDG_CONFIG_HOME}/Vesktop/themes/system24.theme.css:file:Vesktop theme (alt)"
    "${XDG_CONFIG_HOME}/Vesktop/themes/ii-colors.css:file:Vesktop colors (alt)"

    # Fuzzel
    "${XDG_CONFIG_HOME}/fuzzel:dir:Fuzzel config"

    # Fontconfig
    "${XDG_CONFIG_HOME}/fontconfig:dir:Fontconfig"

    # Color schemes
    "${HOME}/.local/share/color-schemes/Darkly.colors:file:Darkly color scheme"

    # Super daemon (legacy)
    "${HOME}/.local/bin/ii_super_overview_daemon.py:file:Super daemon script"
    "${XDG_CONFIG_HOME}/systemd/user/ii-super-overview.service:file:Super daemon service"

    # Python venv
    "${XDG_STATE_HOME}/quickshell/.venv:dir:Python virtual environment"
)

# System changes that need manual reversal
SYSTEM_CHANGES=(
    "User added to groups: video, i2c, input"
    "i2c-dev module: /etc/modules-load.d/i2c-dev.conf"
    "ydotool service enabled"
)

###############################################################################
# Uninstall functions
###############################################################################

uninstall_stop_services() {
    tui_info "Stopping iNiR services..."

    # Stop quickshell
    qs kill -c ii 2>/dev/null || true

    # Stop super daemon if running
    if systemctl --user is-active ii-super-overview.service &>/dev/null; then
        systemctl --user disable --now ii-super-overview.service 2>/dev/null || true
    fi

    # Stop ydotool user service (optional - user may want to keep it)
    # We don't stop it by default as other apps may use it

    tui_success "Services stopped"
}

uninstall_create_backup() {
    local backup_dir="${HOME}/.local/share/inir-uninstall-backup-$(date +%Y%m%d-%H%M%S)"

    tui_info "Creating backup before uninstall..."
    mkdir -p "$backup_dir"

    # Backup user config
    if [[ -f "${XDG_CONFIG_HOME}/illogical-impulse/config.json" ]]; then
        cp "${XDG_CONFIG_HOME}/illogical-impulse/config.json" "$backup_dir/"
    fi

    # Backup niri config
    if [[ -f "${XDG_CONFIG_HOME}/niri/config.kdl" ]]; then
        cp "${XDG_CONFIG_HOME}/niri/config.kdl" "$backup_dir/"
    fi

    # Backup notifications
    if [[ -f "${XDG_STATE_HOME}/quickshell/user/notifications.json" ]]; then
        cp "${XDG_STATE_HOME}/quickshell/user/notifications.json" "$backup_dir/"
    fi

    # Backup todo
    if [[ -f "${XDG_STATE_HOME}/quickshell/user/todo.json" ]]; then
        cp "${XDG_STATE_HOME}/quickshell/user/todo.json" "$backup_dir/"
    fi

    tui_success "Backup created: $backup_dir"
    echo "$backup_dir"
}

uninstall_remove_files() {
    local keep_niri="${1:-false}"
    local keep_user_config="${2:-false}"
    local removed=0
    local skipped=0

    tui_info "Removing iNiR files..."

    for entry in "${INIR_INSTALLED_PATHS[@]}"; do
        local path="${entry%%:*}"
        local rest="${entry#*:}"
        local type="${rest%%:*}"
        local desc="${rest#*:}"

        # Expand variables
        path=$(eval echo "$path")

        # Skip niri config if requested
        if [[ "$keep_niri" == "true" && "$path" == *"niri"* ]]; then
            echo -e "  ${STY_YELLOW}⊘${STY_RST} Keeping: $desc"
            ((skipped++))
            continue
        fi

        # Skip user config if requested
        if [[ "$keep_user_config" == "true" && "$path" == *"illogical-impulse"* ]]; then
            echo -e "  ${STY_YELLOW}⊘${STY_RST} Keeping: $desc"
            ((skipped++))
            continue
        fi

        if [[ "$type" == "dir" && -d "$path" ]]; then
            rm -rf "$path"
            echo -e "  ${STY_RED}✗${STY_RST} Removed: $desc"
            ((removed++))
        elif [[ "$type" == "file" && -f "$path" ]]; then
            rm -f "$path"
            echo -e "  ${STY_RED}✗${STY_RST} Removed: $desc"
            ((removed++))
        fi
    done

    # Clean up empty parent directories
    rmdir "${XDG_CONFIG_HOME}/quickshell" 2>/dev/null || true
    rmdir "${XDG_STATE_HOME}/quickshell" 2>/dev/null || true
    rmdir "${XDG_CACHE_HOME}/quickshell" 2>/dev/null || true
    rmdir "${HOME}/.local/share/color-schemes" 2>/dev/null || true

    echo ""
    tui_success "Removed $removed items, skipped $skipped"
}

uninstall_show_manual_steps() {
    echo ""
    tui_subtitle "Manual cleanup (optional)"
    echo ""
    echo -e "${STY_FAINT}These system changes were made during install and may be used by other apps:${STY_RST}"
    echo ""

    for change in "${SYSTEM_CHANGES[@]}"; do
        echo -e "  ${STY_YELLOW}•${STY_RST} $change"
    done

    echo ""
    echo -e "${STY_FAINT}To fully revert:${STY_RST}"
    echo -e "  ${STY_CYAN}# Remove user from groups (may break other apps)${STY_RST}"
    echo -e "  sudo gpasswd -d \$(whoami) i2c"
    echo ""
    echo -e "  ${STY_CYAN}# Remove i2c module autoload${STY_RST}"
    echo -e "  sudo rm /etc/modules-load.d/i2c-dev.conf"
    echo ""
    echo -e "  ${STY_CYAN}# Disable ydotool (if not needed)${STY_RST}"
    echo -e "  systemctl --user disable ydotool"
    echo ""
}

uninstall_show_packages() {
    echo ""
    tui_subtitle "Installed packages"
    echo ""
    echo -e "${STY_FAINT}iNiR installed these package groups. Remove if not needed:${STY_RST}"
    echo ""
    echo -e "  ${STY_CYAN}# Core dependencies${STY_RST}"
    echo -e "  yay -R inir-core inir-audio inir-toolkit"
    echo ""
    echo -e "  ${STY_CYAN}# Or remove individual packages${STY_RST}"
    echo -e "  yay -R quickshell-git matugen-bin niri"
    echo ""
    echo -e "${STY_YELLOW}Note: Only remove packages you don't need for other purposes.${STY_RST}"
    echo ""
}

###############################################################################
# Interactive uninstall
###############################################################################

run_uninstall() {
    echo ""
    tui_title "iNiR Uninstaller"
    echo ""

    # Check if installed
    if [[ ! -f "${XDG_CONFIG_HOME}/illogical-impulse/installed_true" ]] && \
       [[ ! -d "${XDG_CONFIG_HOME}/quickshell/ii" ]]; then
        tui_warn "iNiR does not appear to be installed"
        return 1
    fi

    # Warning
    echo -e "${STY_RED}${STY_BOLD}⚠ WARNING${STY_RST}"
    echo ""
    echo "This will remove iNiR from your system."
    echo "Your Niri session will continue running, but without the shell UI."
    echo ""

    # Confirm
    if ! tui_confirm "Continue with uninstall?" "no"; then
        echo "Cancelled."
        return 0
    fi

    echo ""

    # Options
    local keep_niri=false
    local keep_user_config=false

    if tui_confirm "Keep Niri config? (recommended if you customized it)" "yes"; then
        keep_niri=true
    fi

    if tui_confirm "Keep user preferences (config.json)? (for potential reinstall)" "yes"; then
        keep_user_config=true
    fi

    echo ""
    tui_divider
    echo ""

    # Create backup
    local backup_dir
    backup_dir=$(uninstall_create_backup)

    # Stop services
    uninstall_stop_services

    # Remove files
    uninstall_remove_files "$keep_niri" "$keep_user_config"

    # Show manual steps
    uninstall_show_manual_steps

    # Show package info
    uninstall_show_packages

    # Final message
    echo ""
    tui_divider
    echo ""

    printf "${STY_GREEN}${STY_BOLD}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║                  ✓ Uninstall Complete                        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    printf "${STY_RST}"
    echo ""

    echo -e "${STY_CYAN}Backup saved to:${STY_RST} $backup_dir"
    echo ""

    if [[ "$keep_niri" == "true" ]]; then
        echo -e "${STY_FAINT}Your Niri config was preserved. You can continue using Niri${STY_RST}"
        echo -e "${STY_FAINT}with another shell or bar (waybar, etc).${STY_RST}"
    else
        echo -e "${STY_YELLOW}Niri config was removed. You'll need to create a new one${STY_RST}"
        echo -e "${STY_YELLOW}or restore from backup to use Niri.${STY_RST}"
    fi

    echo ""
    echo -e "${STY_FAINT}To reinstall iNiR later: git clone ... && ./setup install${STY_RST}"
    echo ""
}

###############################################################################
# Quick uninstall (non-interactive)
###############################################################################

run_uninstall_quick() {
    echo ""
    tui_title "iNiR Quick Uninstall"
    echo ""

    tui_warn "This will remove iNiR keeping Niri config and user preferences"
    echo ""

    if ! tui_confirm "Continue?" "no"; then
        echo "Cancelled."
        return 0
    fi

    uninstall_create_backup >/dev/null
    uninstall_stop_services
    uninstall_remove_files "true" "true"

    echo ""
    tui_success "iNiR removed. Niri config and preferences preserved."
    echo ""
}
