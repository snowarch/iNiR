# Conflict detection for iNiR
# Checks for packages that might conflict with Quickshell's functionality

check_conflicts() {
    echo -e "${STY_CYAN}Checking for conflicting packages...${STY_RST}"
    
    local conflicts=()
    local conflict_services=()
    local critical_conflicts=()
    local package_manager=""
    
    if command -v pacman &>/dev/null; then
        package_manager="pacman"
    elif command -v rpm &>/dev/null; then
        package_manager="rpm"
    elif command -v dpkg &>/dev/null; then
        package_manager="dpkg"
    fi
    
    # Define conflict groups
    declare -A conflict_map
    
    # Notifications (Quickshell has built-in notifications)
    conflict_map["dunst"]="Notification Daemon"
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
    
    # Quickshell-based shells — these are critical because they ship their own
    # Quickshell fork or config that directly conflicts with iNiR at runtime.
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

    # Packages that are critical conflicts — they break iNiR at the package
    # level (provide/replace quickshell, or own overlapping config paths).
    # Unlike notification daemons or bars, these cannot coexist at all.
    declare -A critical_map
    critical_map["cachyos-niri-noctalia"]=1
    critical_map["noctalia-shell"]=1
    critical_map["noctalia-qs"]=1
    critical_map["noctalia-qs-git"]=1
    critical_map["dms-shell"]=1
    critical_map["dms-shell-git"]=1
    critical_map["caelestia-shell"]=1
    critical_map["caelestia-shell-git"]=1
    critical_map["bms-shell-bin"]=1
    
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
            if [[ "$real" != "$pkg" ]]; then
                conflicts+=("$real (provides $pkg, ${conflict_map[$pkg]})")
            else
                conflicts+=("$pkg (${conflict_map[$pkg]})")
            fi
            if [[ -n "${critical_map[$pkg]:-}" ]]; then
                critical_conflicts+=("$pkg")
            fi
            # Check if it's a systemd service
            if systemctl --user list-unit-files "${pkg}.service" &>/dev/null 2>&1; then
                conflict_services+=("${pkg}.service")
            fi
        fi
    done
    
    if [ ${#conflicts[@]} -gt 0 ]; then
        echo -e "${STY_YELLOW}Found potential conflicting packages:${STY_RST}"
        for c in "${conflicts[@]}"; do
            echo -e "  ${STY_RED}!${STY_RST} $c"
        done
        echo ""

        if [ ${#critical_conflicts[@]} -gt 0 ]; then
            echo -e "${STY_RED}${STY_BOLD}Critical:${STY_RST} ${critical_conflicts[*]} must be removed for iNiR to work."
            echo -e "These packages ship their own Quickshell runtime or configs that directly conflict."
            echo ""

            if [[ "$package_manager" == "pacman" ]]; then
                # On Arch, offer to remove critical conflicts now.
                # Removal order matters: meta-packages first, then shells, then runtimes.
                local ordered_remove=()
                for pkg in cachyos-niri-noctalia noctalia-shell noctalia-qs noctalia-qs-git \
                           dms-shell dms-shell-git caelestia-shell caelestia-shell-git bms-shell-bin; do
                    for cpkg in "${critical_conflicts[@]}"; do
                        if [[ "$pkg" == "$cpkg" ]]; then
                            ordered_remove+=("$pkg")
                        fi
                    done
                done

                if [[ "$ask" == "true" ]]; then
                    if tui_confirm "Remove conflicting packages? (${ordered_remove[*]})"; then
                        _remove_critical_conflicts "${ordered_remove[@]}"
                    else
                        echo -e "${STY_YELLOW}Keeping conflicting packages — iNiR will NOT work correctly.${STY_RST}"
                    fi
                else
                    echo -e "${STY_CYAN}Non-interactive mode: removing conflicting packages...${STY_RST}"
                    _remove_critical_conflicts "${ordered_remove[@]}"
                fi
            else
                echo -e "${STY_YELLOW}Remove them manually before continuing.${STY_RST}"
            fi
            echo ""
        fi

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
    else
        log_success "No conflicting packages found."
    fi
}

# Remove critical conflicting packages on Arch.
# Uses -Rdd to skip dependency checks since we're replacing the whole stack.
_remove_critical_conflicts() {
    local pkg
    for pkg in "$@"; do
        if ! pacman -Qi "$pkg" &>/dev/null 2>&1; then
            continue  # already gone (removed as dependency of a previous one)
        fi

        # Stop related services before removal
        local svc_name="${pkg}.service"
        systemctl --user stop "$svc_name" 2>/dev/null || true
        systemctl --user disable "$svc_name" 2>/dev/null || true

        log_info "Removing $pkg..."
        pkg_sudo pacman -Rdd --noconfirm "$pkg" 2>/dev/null \
            || pkg_sudo pacman -R --noconfirm "$pkg" 2>/dev/null \
            || log_warning "Could not remove $pkg — install may fail"
    done

    # After removing noctalia-qs (or its -git variant), quickshell is gone.
    # The dependency installer will pick it up, but reload the package db
    # so pacman knows the slot is free.
    pkg_sudo pacman -Sy 2>/dev/null || true
}
