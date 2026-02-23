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
    ["${XDG_CONFIG_HOME}/quickshell/inir"]="iNiR shell configuration"
    ["${XDG_CONFIG_HOME}/inir"]="iNiR user preferences"
    ["${XDG_STATE_HOME}/quickshell/user"]="iNiR state (notifications, todo)"
    ["${XDG_CACHE_HOME}/quickshell/inir"]="iNiR cache"
    ["${HOME}/.local/bin/inir_super_overview_daemon.py"]="iNiR super daemon"
    ["${XDG_CONFIG_HOME}/systemd/user/inir-super-overview.service"]="iNiR daemon service"
    ["${XDG_CONFIG_HOME}/vesktop/themes/system24.theme.css"]="iNiR Vesktop theme"
    ["${XDG_CONFIG_HOME}/vesktop/themes/inir-colors.css"]="iNiR Vesktop colors"
    ["${XDG_CONFIG_HOME}/Vesktop/themes/system24.theme.css"]="iNiR Vesktop theme (alt)"
    ["${XDG_CONFIG_HOME}/Vesktop/themes/inir-colors.css"]="iNiR Vesktop colors (alt)"
    ["${HOME}/.local/bin/sync-pixel-sddm.py"]="iNiR SDDM theme sync helper"
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
        local other_configs=$(find "$qs_dir" -maxdepth 1 -type d ! -name "inir" ! -name "quickshell" 2>/dev/null | wc -l)
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
    [[ -f "$config" ]] && grep -q "quickshell:inir" "$config" 2>/dev/null
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
    local install_marker="${XDG_CONFIG_HOME}/inir/installed_true"
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

    # Stop quickshell inir config only
    qs kill -c inir 2>/dev/null || true

    # Stop super daemon if running
    if command -v systemctl &>/dev/null && [[ -d /run/systemd/system ]]; then
        if systemctl --user is-active inir-super-overview.service &>/dev/null; then
            systemctl --user disable --now inir-super-overview.service 2>/dev/null || true
        fi
    fi

    tui_success "Services stopped"
}

uninstall_create_backup() {
    local backup_dir="${HOME}/.local/share/inir-uninstall-backup-$(date +%Y%m%d-%H%M%S)"

    tui_info "Creating backup before uninstall..." >&2
    mkdir -p "$backup_dir"

    # Backup iNiR-specific files
    if [[ -d "${XDG_CONFIG_HOME}/quickshell/inir" ]]; then
        cp -r "${XDG_CONFIG_HOME}/quickshell/inir" "$backup_dir/quickshell-inir"
    fi

    if [[ -d "${XDG_CONFIG_HOME}/inir" ]]; then
        cp -r "${XDG_CONFIG_HOME}/inir" "$backup_dir/inir"
    fi

    # Backup niri config
    if [[ -f "${XDG_CONFIG_HOME}/niri/config.kdl" ]]; then
        cp "${XDG_CONFIG_HOME}/niri/config.kdl" "$backup_dir/"
    fi

    # Backup user state
    if [[ -d "${XDG_STATE_HOME}/quickshell/user" ]]; then
        cp -r "${XDG_STATE_HOME}/quickshell/user" "$backup_dir/quickshell-state"
    fi

    tui_success "Backup created: $backup_dir" >&2
    echo "$backup_dir"
}

uninstall_remove_inir_only() {
    local removed=0
    local _start=$SECONDS

    tui_info "Removing iNiR-exclusive files..."
    echo ""

    # Pre-count existing items for N/M progress display
    local total=0
    for path in "${!INIR_ONLY_PATHS[@]}"; do
        local ep
        ep=$(eval echo "$path")
        [[ -e "$ep" ]] && ((total++))
    done

    if [[ $total -eq 0 ]]; then
        echo -e "  ${STY_FAINT}Nothing to remove — already clean.${STY_RST}"
    else
        local idx=0
        for path in "${!INIR_ONLY_PATHS[@]}"; do
            local ep
            ep=$(eval echo "$path")
            local desc="${INIR_ONLY_PATHS[$path]}"

            if [[ -d "$ep" ]]; then
                ((idx++))
                rm -rf "$ep"
                echo -e "  ${STY_FAINT}[$idx/$total]${STY_RST} ${STY_RED}✗${STY_RST} Removed: $desc"
                ((removed++))
            elif [[ -f "$ep" ]]; then
                ((idx++))
                rm -f "$ep"
                echo -e "  ${STY_FAINT}[$idx/$total]${STY_RST} ${STY_RED}✗${STY_RST} Removed: $desc"
                ((removed++))
            fi
        done
    fi

    # Clean up empty quickshell directory only if no other configs exist
    if ! has_other_quickshell_configs; then
        rmdir "${XDG_CONFIG_HOME}/quickshell" 2>/dev/null || true
    fi

    echo ""
    local _elapsed=$(( SECONDS - _start ))
    tui_success "Removed $removed iNiR-exclusive item(s)  (${_elapsed}s)"
}

uninstall_handle_shared_configs() {
    local removed=0
    local kept=0
    local _start=$SECONDS

    echo ""
    tui_section_start "Shared configurations"
    echo ""
    echo -e "  ${STY_FAINT}These configs may be used by other applications.${STY_RST}"
    echo ""

    # ── Phase 1: pre-scan all existing shared paths ────────────────────────
    local -a _paths=()
    local -A _desc=() _rec=() _reason=() _level=()

    for path in "${!SHARED_PATHS[@]}"; do
        local ep
        ep=$(eval echo "$path")
        [[ ! -e "$ep" ]] && continue

        parse_shared_path_meta "${SHARED_PATHS[$path]}"
        local desc="$SHARED_DESC"
        local app_cmd="$SHARED_APP"
        local level="$SHARED_LEVEL"

        local app_installed=false
        [[ -n "$app_cmd" ]] && command -v "$app_cmd" &>/dev/null && app_installed=true

        local rec="keep"
        local reason=""

        case "$level" in
            essential)
                $app_installed \
                    && reason="app installed, essential" \
                    || reason="essential system config"
                ;;
            optional)
                if $app_installed; then
                    reason="app installed"
                elif config_was_user_modified "$ep"; then
                    reason="has custom changes"
                else
                    rec="remove"
                    reason="app not found, iNiR default"
                fi
                ;;
            inir_default)
                rec="remove"
                reason="created by iNiR"
                ;;
        esac

        # Special niri override
        if [[ "$path" == *"niri"* ]]; then
            if is_running_niri_session; then
                rec="keep"
                reason="YOU ARE IN A NIRI SESSION!"
            elif niri_config_has_user_customizations; then
                rec="keep"
                reason="has your customizations"
            fi
        fi

        _paths+=("$ep")
        _desc["$ep"]="$desc"
        _rec["$ep"]="$rec"
        _reason["$ep"]="$reason"
        _level["$ep"]="$level"
    done

    if [[ ${#_paths[@]} -eq 0 ]]; then
        tui_info "No shared configs found (already clean)"
        tui_section_end
        return 0
    fi

    # ── Phase 2: summary overview ──────────────────────────────────────────
    local _keep_count=0
    local _remove_count=0
    for ep in "${_paths[@]}"; do
        [[ "${_rec[$ep]}" == "keep" ]] && ((_keep_count++)) || ((_remove_count++))
    done

    echo -e "  Found ${STY_BOLD}${#_paths[@]}${STY_RST} shared config(s):  ${STY_YELLOW}${_keep_count} keep${STY_RST}  ${STY_RED}${_remove_count} remove${STY_RST}  ${STY_FAINT}(recommended)${STY_RST}"
    echo ""

    for ep in "${_paths[@]}"; do
        local rec="${_rec[$ep]}"
        local reason="${_reason[$ep]}"
        local desc="${_desc[$ep]}"
        local reason_color="${STY_FAINT}"
        [[ "$reason" == *"SESSION"* ]] && reason_color="${STY_RED}"
        [[ "$reason" == *"custom"* || "$reason" == *"customiz"* ]] && reason_color="${STY_YELLOW}"
        [[ "$reason" == *"installed"* ]] && reason_color="${STY_GREEN}"
        if [[ "$rec" == "keep" ]]; then
            echo -e "  ${STY_YELLOW}⊘${STY_RST} ${STY_BOLD}$desc${STY_RST}  ${reason_color}($reason)${STY_RST}"
        else
            echo -e "  ${STY_RED}✗${STY_RST} ${STY_BOLD}$desc${STY_RST}  ${STY_FAINT}($reason)${STY_RST}"
        fi
        echo -e "    ${STY_FAINT}$ep${STY_RST}"
    done

    echo ""
    tui_divider

    # ── Phase 3: interactive decisions ────────────────────────────────────
    if $ask; then
        echo ""
        echo -e "  ${STY_FAINT}Press Enter to accept the recommendation, or choose the opposite action.${STY_RST}"
        echo ""

        local idx=0
        local total=${#_paths[@]}

        for ep in "${_paths[@]}"; do
            ((idx++))
            local desc="${_desc[$ep]}"
            local rec="${_rec[$ep]}"
            local reason="${_reason[$ep]}"
            local reason_color="${STY_FAINT}"
            [[ "$reason" == *"SESSION"* ]] && reason_color="${STY_RED}"
            [[ "$reason" == *"custom"* || "$reason" == *"customiz"* ]] && reason_color="${STY_YELLOW}"
            [[ "$reason" == *"installed"* ]] && reason_color="${STY_GREEN}"

            echo -e "  ${STY_FAINT}[$idx/$total]${STY_RST} ${STY_CYAN}${STY_BOLD}${desc}${STY_RST}"
            echo -e "    ${reason_color}${reason}${STY_RST}"
            echo -e "    ${STY_FAINT}${ep}${STY_RST}"
            echo ""

            local user_wants_keep
            if [[ "$rec" == "keep" ]]; then
                if tui_confirm "    Keep this config?" "yes"; then
                    user_wants_keep=true
                else
                    user_wants_keep=false
                fi
            else
                if tui_confirm "    Remove this config?" "yes"; then
                    user_wants_keep=false
                else
                    user_wants_keep=true
                fi
            fi

            if $user_wants_keep; then
                echo -e "    ${STY_YELLOW}⊘${STY_RST} Keeping"
                ((kept++))
            else
                if [[ -d "$ep" ]]; then
                    rm -rf "$ep"
                else
                    rm -f "$ep"
                fi
                echo -e "    ${STY_RED}✗${STY_RST} Removed"
                ((removed++))
            fi
            echo ""
        done

    else
        # Non-interactive: apply recommendations strictly
        for ep in "${_paths[@]}"; do
            local desc="${_desc[$ep]}"
            local rec="${_rec[$ep]}"
            local reason="${_reason[$ep]}"
            local level="${_level[$ep]}"
            if [[ "$level" == "inir_default" ]]; then
                [[ -d "$ep" ]] && rm -rf "$ep" || rm -f "$ep"
                echo -e "  ${STY_RED}✗${STY_RST} Removed: $desc ($reason)"
                ((removed++))
            else
                echo -e "  ${STY_YELLOW}⊘${STY_RST} Keeping: $desc ($reason)"
                ((kept++))
            fi
        done
    fi

    local _elapsed=$(( SECONDS - _start ))
    echo ""
    tui_info "Shared configs: ${removed} removed, ${kept} kept  (${_elapsed}s)"
    tui_section_end
}

uninstall_handle_quickshell_shared() {
    echo ""
    tui_section_start "Quickshell shared resources"
    echo ""

    # Check if other quickshell configs exist
    if has_other_quickshell_configs; then
        tui_warn "Other Quickshell configurations detected — keeping shared resources."
        echo ""
        for path in "${!QUICKSHELL_SHARED[@]}"; do
            local ep
            ep=$(eval echo "$path")
            local desc="${QUICKSHELL_SHARED[$path]}"
            [[ -e "$ep" ]] && echo -e "  ${STY_YELLOW}⊘${STY_RST} Keeping: $desc"
        done
    else
        echo -e "  ${STY_FAINT}No other Quickshell configs found.${STY_RST}"
        echo ""

        if $ask && tui_confirm "  Remove Quickshell shared resources (venv, themes)?" "yes"; then
            local _removed=0
            for path in "${!QUICKSHELL_SHARED[@]}"; do
                local ep
                ep=$(eval echo "$path")
                local desc="${QUICKSHELL_SHARED[$path]}"
                if [[ -d "$ep" ]]; then
                    rm -rf "$ep"
                    echo -e "  ${STY_RED}✗${STY_RST} Removed: $desc"
                    ((_removed++))
                elif [[ -f "$ep" ]]; then
                    rm -f "$ep"
                    echo -e "  ${STY_RED}✗${STY_RST} Removed: $desc"
                    ((_removed++))
                fi
            done
            # Clean up empty state directory
            rmdir "${XDG_STATE_HOME}/quickshell" 2>/dev/null || true
            rmdir "${XDG_CACHE_HOME}/quickshell" 2>/dev/null || true
            echo ""
            tui_success "Removed $_removed shared resource(s)"
        else
            for path in "${!QUICKSHELL_SHARED[@]}"; do
                local ep
                ep=$(eval echo "$path")
                local desc="${QUICKSHELL_SHARED[$path]}"
                [[ -e "$ep" ]] && echo -e "  ${STY_YELLOW}⊘${STY_RST} Keeping: $desc"
            done
        fi
    fi
    tui_section_end
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
    echo -e "  ${STY_YELLOW}•${STY_RST} SDDM theme: /usr/share/sddm/themes/inir-pixel"
    echo -e "    ${STY_FAINT}Used by: SDDM login screen${STY_RST}"
    echo ""
    echo -e "  ${STY_YELLOW}•${STY_RST} SDDM theme drop-in: /etc/sddm.conf.d/inir-theme.conf"
    echo -e "    ${STY_FAINT}Used by: sets Current=inir-pixel${STY_RST}"
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
        echo -e "  ${STY_CYAN}# Remove SDDM theme${STY_RST}"
        echo -e "  sudo rm -rf /usr/share/sddm/themes/inir-pixel"
        echo ""
        echo -e "  ${STY_CYAN}# Remove SDDM theme config drop-in${STY_RST}"
        echo -e "  sudo rm -f /etc/sddm.conf.d/inir-theme.conf"
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
    local _uninstall_start=$SECONDS
    echo ""
    tui_title "iNiR Uninstaller"
    echo ""

    # Safety: if no TTY available, force non-interactive safe mode
    # This prevents catastrophic removal when piped or run via SSH
    if $ask && ! tty -s 2>/dev/null; then
        echo -e "${STY_YELLOW}No interactive terminal detected — using safe mode${STY_RST}"
        echo -e "${STY_FAINT}(All shared configs will be preserved. Use -y flag for non-interactive uninstall.)${STY_RST}"
        echo ""
        ask=false
    fi

    # Check if installed
    if [[ ! -f "${XDG_CONFIG_HOME}/inir/installed_true" ]] && \
       [[ ! -d "${XDG_CONFIG_HOME}/quickshell/inir" ]]; then
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

    # Confirm — in non-interactive mode (-y), skip confirmation
    if $ask; then
        if ! tui_confirm "Continue with uninstall?" "no"; then
            echo "Cancelled."
            return 0
        fi
    else
        echo -e "${STY_CYAN}Non-interactive mode: proceeding with safe uninstall...${STY_RST}"
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

    # Show manual steps (interactive only — don't overwhelm non-interactive output)
    if $ask; then
        uninstall_show_manual_steps
        uninstall_show_packages
    else
        echo ""
        echo -e "${STY_FAINT}Run './setup uninstall' interactively for package removal guidance.${STY_RST}"
    fi

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
    echo -e "  cp -r $backup_dir/quickshell-inir ${XDG_CONFIG_HOME}/quickshell/inir"
    echo ""
    local _total_elapsed=$(( SECONDS - _uninstall_start ))
    echo -e "${STY_FAINT}To reinstall iNiR:${STY_RST}"
    echo -e "  git clone https://github.com/snowarch/inir.git && cd inir && ./setup install"
    echo ""
    echo -e "${STY_FAINT}Total time: ${_total_elapsed}s${STY_RST}"
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
