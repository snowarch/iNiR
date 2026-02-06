# Conflict detection for iNiR
# Checks for packages that might conflict with Quickshell's functionality

check_conflicts() {
    echo -e "${STY_CYAN}Checking for conflicting packages...${STY_RST}"
    
    local conflicts=()
    local conflict_services=()
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
    
    # Check for installed conflicts
    for pkg in "${!conflict_map[@]}"; do
        local installed=false
        case $package_manager in
            pacman)
                if pacman -Qi "$pkg" &>/dev/null; then installed=true; fi
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
            conflicts+=("$pkg (${conflict_map[$pkg]})")
            # Check if it's a systemd service
            if systemctl --user list-unit-files "${pkg}.service" &>/dev/null 2>&1; then
                conflict_services+=("${pkg}.service")
            fi
        fi
    done
    
    if [ ${#conflicts[@]} -gt 0 ]; then
        echo -e "${STY_YELLOW}Found potential conflicting packages:${STY_RST}"
        for c in "${conflicts[@]}"; do
            echo -e "  ${STY_RED}⚠${STY_RST} $c"
        done
        echo ""
        echo -e "${STY_BOLD}Quickshell provides these functionalities natively.${STY_RST}"
        echo -e "Running them simultaneously might cause visual glitches or double notifications."
        echo ""
        
        # Offer to disable conflicting services
        if [ ${#conflict_services[@]} -gt 0 ]; then
            echo -e "${STY_CYAN}Detected running services:${STY_RST}"
            for svc in "${conflict_services[@]}"; do
                if systemctl --user is-active "$svc" &>/dev/null; then
                    echo -e "  ${STY_YELLOW}●${STY_RST} $svc (active)"
                elif systemctl --user is-enabled "$svc" &>/dev/null; then
                    echo -e "  ${STY_FAINT}○${STY_RST} $svc (enabled)"
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
                echo -e "${STY_YELLOW}Non-interactive mode: Skipping service disable${STY_RST}"
                echo -e "${STY_YELLOW}Disable manually with: systemctl --user disable --now <service>${STY_RST}"
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
