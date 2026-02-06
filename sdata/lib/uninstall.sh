# Uninstall command for iNiR
# Safely removes iNiR while preserving user data and shared resources
# This script is meant to be sourced.

# shellcheck shell=bash

###############################################################################
# Configuration - What iNiR installs/manages
###############################################################################

# Categories of files:
# - inir_only: Files created exclusively by iNiR, safe to remove
# - shared: Files that may be used by other apps, ask before removing
# - user_data: User's personal data, preserve by default

# iNiR-exclusive files (safe to remove)
declare -A INIR_ONLY_PATHS=(
    ["${XDG_CONFIG_HOME}/quickshell/ii"]="iNiR shell configuration"
    ["${XDG_CONFIG_HOME}/illogical-impulse"]="iNiR user preferences"
    ["${XDG_STATE_HOME}/quickshell/user"]="iNiR state (notifications, todo)"
    ["${XDG_CACHE_HOME}/quickshell/ii"]="iNiR cache"
    ["${HOME}/.local/bin/ii_super_overview_daemon.py"]="iNiR super daemon"
    ["${XDG_CONFIG_HOME}/systemd/user/ii-super-overview.service"]="iNiR daemon service"
    ["${XDG_CONFIG_HOME}/vesktop/themes/system24.theme.css"]="iNiR Vesktop theme"
    ["${XDG_CONFIG_HOME}/vesktop/themes/ii-colors.css"]="iNiR Vesktop colors"
    ["${XDG_CONFIG_HOME}/Vesktop/themes/system24.theme.css"]="iNiR Vesktop theme (alt)"
    ["${XDG_CONFIG_HOME}/Vesktop/themes/ii-colors.css"]="iNiR Vesktop colors (alt)"
)

# Shared configs - may be used by other apps or user customizations
# Format: path -> "description|app_command|critical_level"
# critical_level: essential (user likely needs), optional (can remove), inir_default (iNiR created)
declare -A SHARED_PATHS=(
    ["${XDG_CONFIG_HOME}/niri/config.kdl"]="Niri compositor config|niri|essential"
    ["${XDG_CONFIG_HOME}/matugen"]="Matugen color config|matugen|optional"
    ["${XDG_CONFIG_HOME}/fuzzel"]="Fuzzel launcher config|fuzzel|optional"
    ["${XDG_CONFIG_HOME}/Kvantum"]="Kvantum Qt theme|kvantummanager|optional"
    ["${XDG_CONFIG_HOME}/kdeglobals"]="KDE global settings||optional"
    ["${XDG_CONFIG_HOME}/dolphinrc"]="Dolphin file manager config|dolphin|optional"
    ["${XDG_CONFIG_HOME}/gtk-3.0/gtk.css"]="GTK3 custom styles||optional"
    ["${XDG_CONFIG_HOME}/gtk-4.0/gtk.css"]="GTK4 custom styles||optional"
    ["${XDG_CONFIG_HOME}/fontconfig"]="Font configuration||essential"
    ["${HOME}/.local/share/color-schemes/Darkly.colors"]="Darkly color scheme||inir_default"
)

# Quickshell state that may be shared with other quickshell configs
declare -A QUICKSHELL_SHARED=(
    ["${XDG_STATE_HOME}/quickshell/.venv"]="Python virtual environment"
    ["${XDG_STATE_HOME}/quickshell/themes"]="Generated themes"
)

# Packages that iNiR may have installed - with usage context
# Format: command -> "package_name|description|shared_usage"
# shared_usage: inir_only, compositor, system_tool, optional_tool
declare -A INIR_PACKAGES=(
    ["qs"]="quickshell|Shell framework|inir_only"
    ["niri"]="niri|Wayland compositor|compositor"
    ["matugen"]="matugen|Color scheme generator|optional_tool"
    ["cliphist"]="cliphist|Clipboard history|system_tool"
    ["fuzzel"]="fuzzel|Application launcher|system_tool"
    ["swaylock"]="swaylock|Screen locker|system_tool"
    ["grim"]="grim|Screenshot tool|system_tool"
    ["slurp"]="slurp|Region selector|system_tool"
    ["wl-copy"]="wl-clipboard|Clipboard utilities|system_tool"
    ["brightnessctl"]="brightnessctl|Brightness control|system_tool"
    ["playerctl"]="playerctl|Media control|system_tool"
    ["dunstify"]="dunst|Notification daemon|system_tool"
    ["cava"]="cava|Audio visualizer|optional_tool"
    ["easyeffects"]="easyeffects|Audio effects|optional_tool"
)

###############################################################################
# Detection functions
###############################################################################

# Check if user has other quickshell configurations
has_other_quickshell_configs() {
    local qs_dir="${XDG_CONFIG_HOME}/quickshell"
    if [[ -d "$qs_dir" ]]; then
        local other_configs=$(find "$qs_dir" -maxdepth 1 -type d ! -name "ii" ! -name "quickshell" 2>/dev/null | wc -l)
        [[ "$other_configs" -gt 0 ]]
    else
        return 1
    fi
}

# Check if user is currently running Niri (would break their session)
is_running_niri_session() {
    [[ -n "$NIRI_SOCKET" ]] || pgrep -x niri &>/dev/null
}

# Check if user has other dotfiles that use niri
has_other_niri_usage() {
    # Check for niri in other common dotfile locations
    local niri_refs=0
    
    # Check if niri is in user's shell startup
    grep -q "niri" "${HOME}/.bashrc" 2>/dev/null && ((niri_refs++))
    grep -q "niri" "${HOME}/.zshrc" 2>/dev/null && ((niri_refs++))
    grep -q "niri" "${XDG_CONFIG_HOME}/fish/config.fish" 2>/dev/null && ((niri_refs++))
    
    # Check for niri in display manager configs
    [[ -f "/usr/share/wayland-sessions/niri.desktop" ]] && ((niri_refs++))
    
    # If niri is referenced elsewhere, user likely uses it independently
    [[ $niri_refs -gt 0 ]]
}

# Check if niri config has iNiR-specific content or is user-customized
niri_config_is_inir_default() {
    local config="${XDG_CONFIG_HOME}/niri/config.kdl"
    [[ -f "$config" ]] && grep -q "quickshell:ii" "$config" 2>/dev/null
}

# Check if niri config has user customizations beyond iNiR defaults
niri_config_has_user_customizations() {
    local config="${XDG_CONFIG_HOME}/niri/config.kdl"
    [[ ! -f "$config" ]] && return 1
    
    # Check for common user customizations
    local custom_markers=(
        "// Custom"
        "# Custom"
        "// My "
        "# My "
        "// User"
        "# User"
    )
    
    for marker in "${custom_markers[@]}"; do
        grep -qi "$marker" "$config" 2>/dev/null && return 0
    done
    
    # Check if file was modified after iNiR install
    local install_marker="${XDG_CONFIG_HOME}/illogical-impulse/installed_true"
    if [[ -f "$install_marker" && -f "$config" ]]; then
        [[ "$config" -nt "$install_marker" ]] && return 0
    fi
    
    return 1
}

# Check if a config file was modified by user (compare to defaults if available)
config_was_user_modified() {
    local config_path="$1"
    local default_path="${REPO_dots}/.config/${config_path#${XDG_CONFIG_HOME}/}"
    
    if [[ -f "$default_path" && -f "$config_path" ]]; then
        ! diff -q "$config_path" "$default_path" &>/dev/null
    else
        # If no default to compare, assume user modified
        return 0
    fi
}

# Parse shared path metadata
# Returns: description, app_command, critical_level
parse_shared_path_meta() {
    local meta="$1"
    IFS='|' read -r SHARED_DESC SHARED_APP SHARED_LEVEL <<< "$meta"
}

# Check if an app is installed and might use a config
app_uses_config() {
    local path="$1"
    local meta="${SHARED_PATHS[$path]}"
    
    parse_shared_path_meta "$meta"
    
    # If no app command specified, check by path pattern
    if [[ -z "$SHARED_APP" ]]; then
        case "$path" in
            *gtk*) return 0 ;; # GTK is always present
            *fontconfig*) return 0 ;; # fontconfig is always present
            *) return 1 ;;
        esac
    fi
    
    command -v "$SHARED_APP" &>/dev/null
}

# Check if a package is used by other applications (reverse dependency check)
package_has_dependents() {
    local pkg="$1"
    local distro="${OS_GROUP_ID:-unknown}"
    
    case "$distro" in
        arch)
            # Check if anything depends on this package
            local deps=$(pacman -Qi "$pkg" 2>/dev/null | grep "Required By" | cut -d: -f2)
            [[ "$deps" != " None" && -n "$deps" ]]
            ;;
        fedora)
            # Check reverse dependencies
            local deps=$(dnf repoquery --whatrequires "$pkg" 2>/dev/null | head -1)
            [[ -n "$deps" ]]
            ;;
        debian|ubuntu)
            # Check reverse dependencies
            local deps=$(apt-cache rdepends "$pkg" 2>/dev/null | grep -v "^$pkg$" | head -1)
            [[ -n "$deps" ]]
            ;;
        *)
            # Can't check, assume it might have dependents
            return 0
            ;;
    esac
}

# Determine if a package is safe to suggest removal
get_package_removal_safety() {
    local cmd="$1"
    local meta="${INIR_PACKAGES[$cmd]}"
    
    [[ -z "$meta" ]] && echo "unknown" && return
    
    IFS='|' read -r pkg_name pkg_desc pkg_usage <<< "$meta"
    
    case "$pkg_usage" in
        inir_only)
            # Only used by iNiR - safe to remove if no other qs configs
            if has_other_quickshell_configs; then
                echo "keep_qs"
            else
                echo "safe"
            fi
            ;;
        compositor)
            # Niri - check if user is in a Niri session or uses it elsewhere
            if is_running_niri_session; then
                echo "keep_session"
            elif has_other_niri_usage; then
                echo "keep_user"
            else
                echo "ask"
            fi
            ;;
        system_tool)
            # Tools that might be used by other apps
            if package_has_dependents "$pkg_name"; then
                echo "keep_deps"
            else
                echo "ask"
            fi
            ;;
        optional_tool)
            # Optional tools - generally safe to remove
            echo "safe"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

###############################################################################
# Uninstall functions
###############################################################################

uninstall_stop_services() {
    tui_info "Stopping iNiR services..."

    # Stop quickshell ii config only
    qs kill -c ii 2>/dev/null || true

    # Stop super daemon if running
    if command -v systemctl &>/dev/null && [[ -d /run/systemd/system ]]; then
        if systemctl --user is-active ii-super-overview.service &>/dev/null; then
            systemctl --user disable --now ii-super-overview.service 2>/dev/null || true
        fi
    fi

    tui_success "Services stopped"
}

uninstall_create_backup() {
    local backup_dir="${HOME}/.local/share/inir-uninstall-backup-$(date +%Y%m%d-%H%M%S)"

    tui_info "Creating backup before uninstall..."
    mkdir -p "$backup_dir"

    # Backup iNiR-specific files
    if [[ -d "${XDG_CONFIG_HOME}/quickshell/ii" ]]; then
        cp -r "${XDG_CONFIG_HOME}/quickshell/ii" "$backup_dir/quickshell-ii"
    fi

    if [[ -d "${XDG_CONFIG_HOME}/illogical-impulse" ]]; then
        cp -r "${XDG_CONFIG_HOME}/illogical-impulse" "$backup_dir/illogical-impulse"
    fi

    # Backup niri config
    if [[ -f "${XDG_CONFIG_HOME}/niri/config.kdl" ]]; then
        cp "${XDG_CONFIG_HOME}/niri/config.kdl" "$backup_dir/"
    fi

    # Backup user state
    if [[ -d "${XDG_STATE_HOME}/quickshell/user" ]]; then
        cp -r "${XDG_STATE_HOME}/quickshell/user" "$backup_dir/quickshell-state"
    fi

    tui_success "Backup created: $backup_dir"
    echo "$backup_dir"
}

uninstall_remove_inir_only() {
    local removed=0
    
    tui_info "Removing iNiR-exclusive files..."

    for path in "${!INIR_ONLY_PATHS[@]}"; do
        local expanded_path=$(eval echo "$path")
        local desc="${INIR_ONLY_PATHS[$path]}"

        if [[ -d "$expanded_path" ]]; then
            rm -rf "$expanded_path"
            echo -e "  ${STY_RED}✗${STY_RST} Removed: $desc"
            ((removed++))
        elif [[ -f "$expanded_path" ]]; then
            rm -f "$expanded_path"
            echo -e "  ${STY_RED}✗${STY_RST} Removed: $desc"
            ((removed++))
        fi
    done

    # Clean up empty quickshell directory only if no other configs exist
    if ! has_other_quickshell_configs; then
        rmdir "${XDG_CONFIG_HOME}/quickshell" 2>/dev/null || true
    fi

    echo ""
    tui_success "Removed $removed iNiR-exclusive items"
}

uninstall_handle_shared_configs() {
    local removed=0
    local kept=0

    echo ""
    tui_subtitle "Shared configurations"
    echo ""
    echo -e "${STY_FAINT}These configs may be used by other applications.${STY_RST}"
    echo ""

    for path in "${!SHARED_PATHS[@]}"; do
        local expanded_path=$(eval echo "$path")
        local meta="${SHARED_PATHS[$path]}"

        # Skip if doesn't exist
        [[ ! -e "$expanded_path" ]] && continue

        # Parse metadata
        parse_shared_path_meta "$meta"
        local desc="$SHARED_DESC"
        local app_cmd="$SHARED_APP"
        local level="$SHARED_LEVEL"

        # Check if the app that uses this config is still installed
        local app_installed=false
        [[ -n "$app_cmd" ]] && command -v "$app_cmd" &>/dev/null && app_installed=true

        # Determine recommendation based on level and app status
        local recommendation="keep"
        local reason=""
        local icon="${STY_YELLOW}⊘${STY_RST}"

        case "$level" in
            essential)
                # Essential configs - always recommend keeping
                recommendation="keep"
                if $app_installed; then
                    reason="${STY_GREEN}(app installed, essential)${STY_RST}"
                else
                    reason="${STY_YELLOW}(essential system config)${STY_RST}"
                fi
                ;;
            optional)
                if $app_installed; then
                    recommendation="keep"
                    reason="${STY_GREEN}(app installed)${STY_RST}"
                elif config_was_user_modified "$expanded_path"; then
                    recommendation="keep"
                    reason="${STY_YELLOW}(has custom changes)${STY_RST}"
                else
                    recommendation="remove"
                    reason="${STY_FAINT}(app not found, iNiR default)${STY_RST}"
                    icon="${STY_RED}✗${STY_RST}"
                fi
                ;;
            inir_default)
                # iNiR created this - safe to remove
                recommendation="remove"
                reason="${STY_FAINT}(created by iNiR)${STY_RST}"
                icon="${STY_RED}✗${STY_RST}"
                ;;
        esac

        # Special handling for niri config
        if [[ "$path" == *"niri"* ]]; then
            if is_running_niri_session; then
                recommendation="keep"
                reason="${STY_RED}(YOU ARE IN A NIRI SESSION!)${STY_RST}"
                icon="${STY_YELLOW}⊘${STY_RST}"
            elif niri_config_has_user_customizations; then
                recommendation="keep"
                reason="${STY_YELLOW}(has your customizations)${STY_RST}"
                icon="${STY_YELLOW}⊘${STY_RST}"
            fi
        fi

        # In interactive mode, ask user
        if $ask; then
            local default_choice="yes"
            [[ "$recommendation" == "remove" ]] && default_choice="no"

            echo -e "  ${STY_CYAN}$desc${STY_RST} $reason"
            if tui_confirm "    Keep this config?" "$default_choice"; then
                echo -e "    ${STY_YELLOW}⊘${STY_RST} Keeping"
                ((kept++))
            else
                if [[ -d "$expanded_path" ]]; then
                    rm -rf "$expanded_path"
                else
                    rm -f "$expanded_path"
                fi
                echo -e "    ${STY_RED}✗${STY_RST} Removed"
                ((removed++))
            fi
        else
            # Non-interactive: keep essential, remove inir_default
            if [[ "$level" == "inir_default" ]]; then
                if [[ -d "$expanded_path" ]]; then
                    rm -rf "$expanded_path"
                else
                    rm -f "$expanded_path"
                fi
                echo -e "  ${STY_RED}✗${STY_RST} Removed: $desc $reason"
                ((removed++))
            else
                echo -e "  ${STY_YELLOW}⊘${STY_RST} Keeping: $desc $reason"
                ((kept++))
            fi
        fi
    done

    echo ""
    tui_info "Shared configs: $removed removed, $kept kept"
}

uninstall_handle_quickshell_shared() {
    echo ""
    tui_subtitle "Quickshell shared resources"
    echo ""

    # Check if other quickshell configs exist
    if has_other_quickshell_configs; then
        echo -e "${STY_YELLOW}Other Quickshell configurations detected.${STY_RST}"
        echo -e "${STY_FAINT}Keeping shared Quickshell resources (venv, themes).${STY_RST}"
        
        for path in "${!QUICKSHELL_SHARED[@]}"; do
            local expanded_path=$(eval echo "$path")
            local desc="${QUICKSHELL_SHARED[$path]}"
            [[ -e "$expanded_path" ]] && echo -e "  ${STY_YELLOW}⊘${STY_RST} Keeping: $desc"
        done
    else
        echo -e "${STY_FAINT}No other Quickshell configs found.${STY_RST}"
        
        if $ask && tui_confirm "Remove Quickshell shared resources (venv, themes)?" "yes"; then
            for path in "${!QUICKSHELL_SHARED[@]}"; do
                local expanded_path=$(eval echo "$path")
                local desc="${QUICKSHELL_SHARED[$path]}"
                if [[ -d "$expanded_path" ]]; then
                    rm -rf "$expanded_path"
                    echo -e "  ${STY_RED}✗${STY_RST} Removed: $desc"
                elif [[ -f "$expanded_path" ]]; then
                    rm -f "$expanded_path"
                    echo -e "  ${STY_RED}✗${STY_RST} Removed: $desc"
                fi
            done
            
            # Clean up empty state directory
            rmdir "${XDG_STATE_HOME}/quickshell" 2>/dev/null || true
            rmdir "${XDG_CACHE_HOME}/quickshell" 2>/dev/null || true
        else
            for path in "${!QUICKSHELL_SHARED[@]}"; do
                local expanded_path=$(eval echo "$path")
                local desc="${QUICKSHELL_SHARED[$path]}"
                [[ -e "$expanded_path" ]] && echo -e "  ${STY_YELLOW}⊘${STY_RST} Keeping: $desc"
            done
        fi
    fi
}

uninstall_show_manual_steps() {
    echo ""
    tui_subtitle "Manual cleanup (optional)"
    echo ""
    echo -e "${STY_FAINT}These system changes were made during install.${STY_RST}"
    echo -e "${STY_FAINT}They may be used by other apps - only remove if not needed:${STY_RST}"
    echo ""

    echo -e "  ${STY_YELLOW}•${STY_RST} User groups: video, i2c, input"
    echo -e "    ${STY_FAINT}Used by: screen brightness, DDC monitor control, input devices${STY_RST}"
    echo ""
    echo -e "  ${STY_YELLOW}•${STY_RST} i2c-dev module: /etc/modules-load.d/i2c-dev.conf"
    echo -e "    ${STY_FAINT}Used by: ddcutil (external monitor brightness)${STY_RST}"
    echo ""
    echo -e "  ${STY_YELLOW}•${STY_RST} ydotool service"
    echo -e "    ${STY_FAINT}Used by: automation tools, some Wayland apps${STY_RST}"
    echo ""

    if $ask && tui_confirm "Show commands to revert these changes?" "no"; then
        echo ""
        echo -e "  ${STY_CYAN}# Remove user from i2c group${STY_RST}"
        echo -e "  sudo gpasswd -d \$(whoami) i2c"
        echo ""
        echo -e "  ${STY_CYAN}# Remove i2c module autoload${STY_RST}"
        echo -e "  sudo rm /etc/modules-load.d/i2c-dev.conf"
        echo ""
        if command -v systemctl &>/dev/null; then
            echo -e "  ${STY_CYAN}# Disable ydotool${STY_RST}"
            echo -e "  systemctl --user disable ydotool"
        fi
        echo ""
    fi
}

uninstall_show_packages() {
    echo ""
    tui_subtitle "Installed packages"
    echo ""
    echo -e "${STY_FAINT}iNiR may have installed these packages. Review before removing.${STY_RST}"
    echo ""

    # Detect distro
    local distro="${OS_GROUP_ID:-unknown}"
    [[ -z "$distro" || "$distro" == "unknown" ]] && detect_distro 2>/dev/null

    # Categorize packages by safety
    local safe_to_remove=()
    local ask_before_remove=()
    local keep_packages=()

    echo -e "${STY_CYAN}Package analysis:${STY_RST}"
    echo ""

    for cmd in "${!INIR_PACKAGES[@]}"; do
        # Skip if not installed
        command -v "$cmd" &>/dev/null || continue

        local meta="${INIR_PACKAGES[$cmd]}"
        IFS='|' read -r pkg_name pkg_desc pkg_usage <<< "$meta"
        
        local safety=$(get_package_removal_safety "$cmd")
        
        case "$safety" in
            safe)
                safe_to_remove+=("$pkg_name")
                echo -e "  ${STY_GREEN}✓${STY_RST} $pkg_name - $pkg_desc"
                echo -e "    ${STY_FAINT}Safe to remove (only used by iNiR)${STY_RST}"
                ;;
            ask)
                ask_before_remove+=("$pkg_name")
                echo -e "  ${STY_YELLOW}?${STY_RST} $pkg_name - $pkg_desc"
                echo -e "    ${STY_FAINT}May be used by other apps - check before removing${STY_RST}"
                ;;
            keep_qs)
                keep_packages+=("$pkg_name")
                echo -e "  ${STY_CYAN}⊘${STY_RST} $pkg_name - $pkg_desc"
                echo -e "    ${STY_YELLOW}KEEP: Other Quickshell configs detected${STY_RST}"
                ;;
            keep_session)
                keep_packages+=("$pkg_name")
                echo -e "  ${STY_RED}⊘${STY_RST} $pkg_name - $pkg_desc"
                echo -e "    ${STY_RED}KEEP: You are currently in a Niri session!${STY_RST}"
                ;;
            keep_user)
                keep_packages+=("$pkg_name")
                echo -e "  ${STY_CYAN}⊘${STY_RST} $pkg_name - $pkg_desc"
                echo -e "    ${STY_YELLOW}KEEP: Used by your system configuration${STY_RST}"
                ;;
            keep_deps)
                keep_packages+=("$pkg_name")
                echo -e "  ${STY_CYAN}⊘${STY_RST} $pkg_name - $pkg_desc"
                echo -e "    ${STY_YELLOW}KEEP: Required by other installed packages${STY_RST}"
                ;;
            *)
                ask_before_remove+=("$pkg_name")
                echo -e "  ${STY_YELLOW}?${STY_RST} $pkg_name - $pkg_desc"
                echo -e "    ${STY_FAINT}Unknown usage - check before removing${STY_RST}"
                ;;
        esac
    done

    echo ""
    
    # Show removal commands based on distro
    if [[ ${#safe_to_remove[@]} -gt 0 || ${#ask_before_remove[@]} -gt 0 ]]; then
        echo -e "${STY_CYAN}Removal commands:${STY_RST}"
        echo ""
        
        case "$distro" in
            arch)
                if [[ ${#safe_to_remove[@]} -gt 0 ]]; then
                    echo -e "  ${STY_GREEN}# Safe to remove:${STY_RST}"
                    echo -e "  yay -R ${safe_to_remove[*]}"
                    echo ""
                fi
                if [[ ${#ask_before_remove[@]} -gt 0 ]]; then
                    echo -e "  ${STY_YELLOW}# Check before removing:${STY_RST}"
                    echo -e "  # yay -R ${ask_before_remove[*]}"
                    echo ""
                fi
                ;;
            fedora)
                if [[ ${#safe_to_remove[@]} -gt 0 ]]; then
                    echo -e "  ${STY_GREEN}# Safe to remove:${STY_RST}"
                    echo -e "  sudo dnf remove ${safe_to_remove[*]}"
                    echo ""
                fi
                if [[ ${#ask_before_remove[@]} -gt 0 ]]; then
                    echo -e "  ${STY_YELLOW}# Check before removing:${STY_RST}"
                    echo -e "  # sudo dnf remove ${ask_before_remove[*]}"
                    echo ""
                fi
                echo -e "  ${STY_FAINT}# To disable COPRs:${STY_RST}"
                echo -e "  sudo dnf copr disable errornointernet/quickshell"
                echo -e "  sudo dnf copr disable yalter/niri"
                echo ""
                ;;
            debian|ubuntu)
                if [[ ${#safe_to_remove[@]} -gt 0 ]]; then
                    echo -e "  ${STY_GREEN}# Safe to remove:${STY_RST}"
                    echo -e "  sudo apt remove ${safe_to_remove[*]}"
                    echo ""
                fi
                if [[ ${#ask_before_remove[@]} -gt 0 ]]; then
                    echo -e "  ${STY_YELLOW}# Check before removing:${STY_RST}"
                    echo -e "  # sudo apt remove ${ask_before_remove[*]}"
                    echo ""
                fi
                echo -e "  ${STY_FAINT}# Compiled packages (in /usr/local/bin):${STY_RST}"
                echo -e "  # sudo rm /usr/local/bin/qs"
                echo -e "  # sudo rm /usr/local/bin/niri"
                echo ""
                ;;
            *)
                echo -e "${STY_FAINT}Remove packages using your package manager.${STY_RST}"
                echo -e "${STY_FAINT}Check ~/.cargo/bin and ~/go/bin for tools installed there.${STY_RST}"
                echo ""
                ;;
        esac
    fi

    if [[ ${#keep_packages[@]} -gt 0 ]]; then
        echo -e "${STY_YELLOW}Packages marked KEEP should not be removed:${STY_RST}"
        echo -e "  ${keep_packages[*]}"
        echo ""
    fi

    echo -e "${STY_FAINT}Tip: Run 'pacman -Qi <package>' or 'apt show <package>' to see what depends on a package.${STY_RST}"
    echo ""
}

###############################################################################
# Main uninstall flow
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

    # Detect distro for package info
    detect_distro 2>/dev/null || true

    # Check for critical conditions
    local warnings=()
    
    if is_running_niri_session; then
        warnings+=("You are currently running a Niri session")
    fi
    
    if has_other_quickshell_configs; then
        warnings+=("Other Quickshell configurations detected")
    fi

    # Warning
    echo -e "${STY_RED}${STY_BOLD}⚠ WARNING${STY_RST}"
    echo ""
    echo "This will remove iNiR from your system."
    echo ""
    
    if [[ ${#warnings[@]} -gt 0 ]]; then
        echo -e "${STY_YELLOW}Important notices:${STY_RST}"
        for warn in "${warnings[@]}"; do
            echo -e "  ${STY_YELLOW}•${STY_RST} $warn"
        done
        echo ""
    fi
    
    echo -e "${STY_FAINT}What will happen:${STY_RST}"
    echo "  • iNiR shell configuration will be removed"
    if is_running_niri_session; then
        echo -e "  • ${STY_YELLOW}Your Niri session will continue (without the shell UI)${STY_RST}"
        echo -e "  • ${STY_YELLOW}Niri config will be preserved (you're using it!)${STY_RST}"
    else
        echo "  • Shared configs will be preserved unless you choose to remove them"
    fi
    echo "  • System packages will NOT be removed automatically"
    echo ""

    # Confirm
    if ! tui_confirm "Continue with uninstall?" "no"; then
        echo "Cancelled."
        return 0
    fi

    echo ""
    tui_divider
    echo ""

    # Create backup first
    local backup_dir
    backup_dir=$(uninstall_create_backup)

    # Stop services
    uninstall_stop_services

    # Remove iNiR-exclusive files (always safe)
    uninstall_remove_inir_only

    # Handle shared configs (ask user)
    uninstall_handle_shared_configs

    # Handle quickshell shared resources
    uninstall_handle_quickshell_shared

    # Show manual steps
    uninstall_show_manual_steps

    # Show package info with smart recommendations
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

    echo -e "${STY_CYAN}Backup saved to:${STY_RST}"
    echo -e "  $backup_dir"
    echo ""
    echo -e "${STY_FAINT}To restore from backup:${STY_RST}"
    echo -e "  cp -r $backup_dir/quickshell-ii ${XDG_CONFIG_HOME}/quickshell/ii"
    echo ""
    echo -e "${STY_FAINT}To reinstall iNiR:${STY_RST}"
    echo -e "  git clone https://github.com/anomalyco/inir && cd inir && ./setup install"
    echo ""
}

###############################################################################
# Quick uninstall (non-interactive, safe defaults)
###############################################################################

run_uninstall_quick() {
    echo ""
    tui_title "iNiR Quick Uninstall"
    echo ""

    echo -e "${STY_YELLOW}Quick uninstall will:${STY_RST}"
    echo "  • Remove iNiR-exclusive files only"
    echo "  • Keep all shared configs (Niri, themes, etc.)"
    echo "  • Keep all system packages"
    echo "  • Create a backup first"
    echo ""

    if ! tui_confirm "Continue?" "no"; then
        echo "Cancelled."
        return 0
    fi

    # Backup
    local backup_dir
    backup_dir=$(uninstall_create_backup)

    # Stop services
    uninstall_stop_services

    # Remove only iNiR-exclusive files
    ask=false  # Disable prompts for shared configs
    uninstall_remove_inir_only

    echo ""
    tui_success "iNiR removed. All shared configs and packages preserved."
    echo ""
    echo -e "${STY_CYAN}Backup:${STY_RST} $backup_dir"
    echo ""
}
