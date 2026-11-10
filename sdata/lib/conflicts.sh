# Conflict detection for iNiR
# Checks for packages that might conflict with Quickshell's functionality

check_conflicts() {
    echo -e "${STY_CYAN}Checking for conflicting packages...${STY_RST}"
    
    local conflicts=()
    local conflict_services=()
    local other_shells=()
    local package_manager=""
    local usable_systemd_user_manager=false
    if declare -F has_usable_systemd_user_manager >/dev/null 2>&1 \
            && has_usable_systemd_user_manager; then
        usable_systemd_user_manager=true
    fi
    
    if command -v pacman &>/dev/null; then
        package_manager="pacman"
    elif command -v xbps-query &>/dev/null; then
        package_manager="xbps"
    elif command -v rpm &>/dev/null; then
        package_manager="rpm"
    elif command -v dpkg &>/dev/null; then
        package_manager="dpkg"
    fi
    
    # Define conflict groups
    declare -A conflict_map
    
    # Notifications (Quickshell has built-in notifications). The dunst package
    # is intentionally allowed because iNiR uses its dunstify client; a running
    # dunst daemon is handled at runtime by ConflictKiller/Doctor instead.
    conflict_map["mako"]="Notification Daemon"
    conflict_map["swaync"]="Notification Daemon"
    
    # Bars/Shells (Quickshell provides the bar/shell)
    conflict_map["waybar"]="Status Bar"
    conflict_map["ironbar"]="Status Bar"
    conflict_map["eww"]="Widget System"
    conflict_map["ags"]="Shell System"
    
    # Wallpaper (Quickshell handles wallpaper)
    conflict_map["hyprpaper"]="Wallpaper Daemon"
    conflict_map["swww"]="Wallpaper Daemon"
    conflict_map["mpvpaper"]="Wallpaper Daemon"
    conflict_map["wpaperd"]="Wallpaper Daemon"
    
    # Other Quickshell shells: they can stay installed. iNiR runs on its own runtime (qs-rs, or Quickshell), from its
    # own config folder, and starts only in the compositors it is set up on; two shells in one session is what clashes.
    # Noctalia (CachyOS default Niri shell)
    conflict_map["cachyos-niri-noctalia"]="Quickshell Shell (Noctalia/CachyOS)"
    conflict_map["noctalia-shell"]="Quickshell Shell (Noctalia)"
    conflict_map["noctalia-qs"]="Quickshell Fork (Noctalia)"
    conflict_map["noctalia-qs-git"]="Quickshell Fork (Noctalia)"
    # DankMaterialShell
    conflict_map["dms-shell"]="Quickshell Shell (DankMaterialShell)"
    conflict_map["dms-shell-git"]="Quickshell Shell (DankMaterialShell)"
    # Caelestia
    conflict_map["caelestia-shell"]="Quickshell Shell (Caelestia)"
    conflict_map["caelestia-shell-git"]="Quickshell Shell (Caelestia)"
    # BMS
    conflict_map["bms-shell-bin"]="Quickshell Shell (BMS)"

    declare -A shell_map
    for pkg in cachyos-niri-noctalia noctalia-shell noctalia-qs noctalia-qs-git \
               dms-shell dms-shell-git caelestia-shell caelestia-shell-git bms-shell-bin; do
        shell_map[$pkg]=1
    done

    # Check for installed conflicts
    for pkg in "${!conflict_map[@]}"; do
        local installed=false
        # pacman -Qi also answers for a package that only provides the name (awww provides swww):
        # show and remove the package that is really installed.
        local real="$pkg"
        case $package_manager in
            pacman)
                if pacman -Qi "$pkg" &>/dev/null; then
                    installed=true
                    real=$(LC_ALL=C pacman -Qi "$pkg" 2>/dev/null | awk -F': *' '/^Name/ { print $2; exit }')
                    [[ -n "$real" ]] || real="$pkg"
                fi
                ;;
            xbps)
                if xbps-query -p pkgver "$pkg" &>/dev/null; then installed=true; fi
                ;;
            rpm)
                if rpm -q "$pkg" &>/dev/null; then installed=true; fi
                ;;
            dpkg)
                if dpkg -s "$pkg" &>/dev/null; then installed=true; fi
                ;;
            *)
                # Fallback: check if binary exists in path
                if command -v "$pkg" &>/dev/null; then installed=true; fi
                ;;
        esac
        
        if $installed; then
            if [[ -n "${shell_map[$pkg]:-}" ]]; then
                other_shells+=("$pkg")
                continue
            fi
            if [[ "$real" != "$pkg" ]]; then
                conflicts+=("$real (provides $pkg, ${conflict_map[$pkg]})")
            else
                conflicts+=("$pkg (${conflict_map[$pkg]})")
            fi
            # Check if it's a systemd service
            if $usable_systemd_user_manager \
                    && systemctl --user list-unit-files "${pkg}.service" &>/dev/null 2>&1; then
                conflict_services+=("${pkg}.service")
            fi
        fi
    done
    
    if [ ${#other_shells[@]} -gt 0 ]; then
        echo -e "${STY_YELLOW}Other shells installed:${STY_RST} ${other_shells[*]}"
        echo -e "${STY_BOLD}They can stay:${STY_RST} iNiR runs on its own runtime and config, and starts only"
        echo -e "in the compositors you set it up on. Just don't start both shells in the same session."
        echo ""
        # INIR_REMOVE_OTHER_SHELLS carries the pick from the inir install wizard; asked here otherwise, and -y keeps them.
        local remove_shells="${INIR_REMOVE_OTHER_SHELLS:-}"
        if [[ -z "$remove_shells" ]] && [[ "$package_manager" == "pacman" || "$package_manager" == "xbps" ]]; then
            tui_confirm "Remove ${other_shells[*]}? (not needed for iNiR)" "no" && remove_shells=yes
        fi
        if [[ "$remove_shells" == yes ]]; then
            # Meta-packages first, then shells, then runtimes.
            local ordered_remove=()
            for pkg in cachyos-niri-noctalia noctalia-shell noctalia-qs noctalia-qs-git \
                       dms-shell dms-shell-git caelestia-shell caelestia-shell-git bms-shell-bin; do
                [[ " ${other_shells[*]} " == *" $pkg "* ]] && ordered_remove+=("$pkg")
            done
            _remove_other_shells "${ordered_remove[@]}"
        else
            # The distro's deps step keeps a Quickshell fork they bring instead of swapping it.
            INIR_KEPT_SHELLS="${other_shells[*]}"
            export INIR_KEPT_SHELLS
        fi
        echo ""
    fi

    if [ ${#conflicts[@]} -gt 0 ]; then
        echo -e "${STY_YELLOW}Found potential conflicting packages:${STY_RST}"
        for c in "${conflicts[@]}"; do
            echo -e "  ${STY_RED}!${STY_RST} $c"
        done
        echo ""

        echo -e "${STY_BOLD}iNiR provides its own bar, notifications, wallpaper, and shell.${STY_RST}"
        echo -e "Running other shells/bars simultaneously causes visual glitches or double notifications."
        echo ""
        
        # Offer to disable non-critical conflicting services
        if [ ${#conflict_services[@]} -gt 0 ]; then
            echo -e "${STY_CYAN}Detected running services:${STY_RST}"
            for svc in "${conflict_services[@]}"; do
                if systemctl --user is-active "$svc" &>/dev/null; then
                    echo -e "  ${STY_YELLOW}*${STY_RST} $svc (active)"
                elif systemctl --user is-enabled "$svc" &>/dev/null; then
                    echo -e "  ${STY_FAINT}o${STY_RST} $svc (enabled)"
                fi
            done
            echo ""
            
            if [[ "$ask" == "true" ]]; then
                if tui_confirm "Disable conflicting services automatically?"; then
                    echo ""
                    for svc in "${conflict_services[@]}"; do
                        if systemctl --user is-enabled "$svc" &>/dev/null 2>&1 || systemctl --user is-active "$svc" &>/dev/null 2>&1; then
                            echo -e "${STY_CYAN}Disabling $svc...${STY_RST}"
                            systemctl --user disable --now "$svc" 2>/dev/null && \
                                log_success "Disabled $svc" || \
                                log_warning "Could not disable $svc (may need manual intervention)"
                        fi
                    done
                    echo ""
                    log_success "Conflicting services disabled"
                else
                    echo -e "${STY_YELLOW}You can disable them later with:${STY_RST}"
                    echo -e "  ${STY_FAINT}systemctl --user disable --now <service>${STY_RST}"
                fi
            else
                # Non-interactive (-y): auto-disable conflicting services
                echo -e "${STY_CYAN}Non-interactive mode: Auto-disabling conflicting services...${STY_RST}"
                for svc in "${conflict_services[@]}"; do
                    if systemctl --user is-enabled "$svc" &>/dev/null 2>&1 || systemctl --user is-active "$svc" &>/dev/null 2>&1; then
                        systemctl --user disable --now "$svc" 2>/dev/null && \
                            log_success "Disabled $svc" || \
                            log_warning "Could not disable $svc"
                    fi
                done
            fi
        else
            echo -e "${STY_YELLOW}Recommendation: Uninstall or disable them manually.${STY_RST}"
        fi
        
        echo ""
        if [[ "$ask" == "true" ]]; then
            read -p "Press Enter to continue installation (or Ctrl+C to abort)..."
        else
            echo "Continuing in non-interactive mode..."
        fi
    elif [ ${#other_shells[@]} -eq 0 ]; then
        log_success "No conflicting packages found."
    fi
}

# Remove other shells the person chose to remove (pacman, xbps).
# Uses -Rdd to skip dependency checks: a shell's meta-package, the shell and its runtime go together.
_remove_other_shells() {
    local pkg
    for pkg in "$@"; do
        case "$package_manager" in
            pacman)
                pacman -Qi "$pkg" &>/dev/null 2>&1 || continue
                ;;
            xbps)
                xbps-query -p pkgver "$pkg" &>/dev/null 2>&1 || continue
                ;;
            *)
                continue
                ;;
        esac

        # Stop related services before removal
        local svc_name="${pkg}.service"
        if declare -F has_usable_systemd_user_manager >/dev/null 2>&1 \
                && has_usable_systemd_user_manager; then
            systemctl --user stop "$svc_name" 2>/dev/null || true
            systemctl --user disable "$svc_name" 2>/dev/null || true
        fi

        log_info "Removing $pkg..."
        case "$package_manager" in
            pacman)
                pkg_sudo pacman -Rdd --noconfirm "$pkg" 2>/dev/null \
                    || pkg_sudo pacman -R --noconfirm "$pkg" 2>/dev/null \
                    || log_warning "Could not remove $pkg — install may fail"
                ;;
            xbps)
                pkg_sudo xbps-remove -R -- "$pkg" 2>/dev/null \
                    || log_warning "Could not remove $pkg — install may fail"
                ;;
        esac
    done

    if [[ "$package_manager" == "pacman" ]]; then
        # After removing noctalia-qs (or its -git variant), quickshell is gone.
        # The dependency installer will pick it up, but reload the package db
        # so pacman knows the slot is free.
        pkg_sudo pacman -Sy 2>/dev/null || true
    fi
}
