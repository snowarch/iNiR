# Doctor command for iNiR
# Diagnoses AND FIXES common issues
# This script is meant to be sourced.

# shellcheck shell=bash

doctor_passed=0
doctor_failed=0
doctor_fixed=0
doctor_missing_deps=()

doctor_pass() {
    tui_success "$1"
    ((doctor_passed++)) || true
}

doctor_fail() {
    tui_error "$1"
    ((doctor_failed++)) || true
}

doctor_fix() {
    tui_warn "Fixed: $1"
    ((doctor_fixed++)) || true
}

###############################################################################
# Checks
###############################################################################

check_dependencies() {
    local missing=()
    local missing_cmds=()
    
    # Commands to check (command:friendly_name)
    # These are distro-agnostic - we check for the command, not the package
    local cmds=(
        "qs:Quickshell"
        "niri:Niri"
        "nmcli:NetworkManager"
        "wpctl:WirePlumber"
        "jq:jq"
        "rsync:rsync"
        "curl:curl"
        "git:git"
        "python3:python3"
        "matugen:matugen"
        "fish:fish"
        "magick:ImageMagick"
        "grim:grim"
        "cliphist:cliphist"
        "wl-copy:wl-clipboard"
        "wl-paste:wl-clipboard"
        "fuzzel:fuzzel"
        "hyprpicker:hyprpicker"
        "songrec:SongRec"
        "trans:translate-shell"
    )
    
    # Optional but recommended
    local optional_cmds=(
        "easyeffects:EasyEffects"
        "uv:uv"
        "cava:cava"
        "qalc:qalculate"
        "yt-dlp:yt-dlp"
        "socat:socat"
        "brightnessctl:brightnessctl"
        "slurp:slurp"
        "wf-recorder:wf-recorder"
        "tesseract:tesseract"
        "blueman-manager:Blueman"
        "kwriteconfig6:KConfig"
        "checkupdates:pacman-contrib"
        "ddcutil:ddcutil"
        "xdg-settings:xdg-utils"
        "mpv:mpv"
        "swaylock:swaylock"
        "swayidle:swayidle"
        "wlsunset:wlsunset"
        "dunstify:dunst"
    )
    
    # Check required commands
    for item in "${cmds[@]}"; do
        local cmd="${item%%:*}"
        local name="${item##*:}"
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$name")
            missing_cmds+=("$cmd")
        fi
    done
    
    # Check optional commands (warn but don't fail)
    local optional_missing=()
    for item in "${optional_cmds[@]}"; do
        local cmd="${item%%:*}"
        local name="${item##*:}"
        command -v "$cmd" &>/dev/null || optional_missing+=("$name")
    done
    
    if [[ ${#missing[@]} -eq 0 ]]; then
        doctor_missing_deps=()
        if [[ ${#optional_missing[@]} -gt 0 ]]; then
            doctor_pass "Required commands OK (optional missing: ${optional_missing[*]})"
        else
            doctor_pass "All required commands available"
        fi
    else
        # Keep command identifiers here (qs, niri, wl-copy, etc.) because
        # setup/update installers map these keys to distro package names.
        doctor_missing_deps=("${missing_cmds[@]}")
        doctor_fail "Missing: ${missing[*]}"
        
        # Provide distro-specific install hints
        case "${OS_GROUP_ID:-unknown}" in
            arch)
                echo -e "    ${STY_FAINT}Run: yay -S ${missing_cmds[*]}${STY_RST}"
                ;;
            fedora)
                echo -e "    ${STY_FAINT}Run: sudo dnf install ... (see ./setup install)${STY_RST}"
                ;;
            debian|ubuntu)
                echo -e "    ${STY_FAINT}Run: sudo apt install ... (see ./setup install)${STY_RST}"
                ;;
            *)
                echo -e "    ${STY_FAINT}Install these tools using your package manager${STY_RST}"
                ;;
        esac
    fi
}

get_missing_dependencies() {
    doctor_missing_deps=()
    check_dependencies
    printf '%s\n' "${doctor_missing_deps[*]}"
}

check_critical_files() {
    local target="${XDG_CONFIG_HOME}/quickshell/ii"
    local critical=("shell.qml" "GlobalStates.qml" "modules/common/Config.qml" "services/NiriService.qml")
    local missing=0
    
    for file in "${critical[@]}"; do
        [[ ! -f "$target/$file" ]] && { doctor_fail "Missing: $file"; ((missing++)) || true; }
    done
    
    [[ $missing -eq 0 ]] && doctor_pass "Critical files present"
}

check_script_permissions() {
    local target="${XDG_CONFIG_HOME}/quickshell/ii/scripts"
    [[ ! -d "$target" ]] && return 0
    
    local bad=$(find "$target" \( -name "*.sh" -o -name "*.fish" -o -name "*.py" \) ! -executable 2>/dev/null | wc -l)
    
    if [[ $bad -gt 0 ]]; then
        find "$target" \( -name "*.sh" -o -name "*.fish" -o -name "*.py" \) -exec chmod +x {} \;
        doctor_fix "Fixed permissions on $bad script(s)"
    else
        doctor_pass "Script permissions OK"
    fi
}

check_user_config() {
    local config="${XDG_CONFIG_HOME}/illogical-impulse/config.json"
    
    if [[ ! -f "$config" ]]; then
        doctor_pass "User config (using defaults)"
        return 0
    fi
    
    if command -v jq &>/dev/null && ! jq empty "$config" 2>/dev/null; then
        doctor_fail "Invalid JSON: $config"
        echo -e "    ${STY_FAINT}Backup and delete to reset${STY_RST}"
    else
        doctor_pass "User config valid"
    fi
}

check_state_directories() {
    local dirs=("${XDG_STATE_HOME}/quickshell/user" "${XDG_CACHE_HOME}/quickshell" "${XDG_CONFIG_HOME}/illogical-impulse")
    local created=0
    
    for dir in "${dirs[@]}"; do
        [[ ! -d "$dir" ]] && { mkdir -p "$dir"; ((created++)) || true; }
    done
    
    [[ $created -gt 0 ]] && doctor_fix "Created $created directory(ies)" || doctor_pass "State directories exist"
}

check_python_packages() {
    local venv="${XDG_STATE_HOME}/quickshell/.venv"
    local req="${XDG_CONFIG_HOME}/quickshell/ii/sdata/uv/requirements.txt"
    
    # Check for broken venv (e.g. after python update)
    if [[ -d "$venv/bin" ]]; then
        if ! "$venv/bin/python" --version &>/dev/null; then
            doctor_fail "Broken Python venv detected"
            rm -rf "$venv"
        fi
    fi

    # Check if venv exists (or was just removed above)
    if [[ ! -d "$venv" ]]; then
        if command -v uv &>/dev/null; then
            uv venv "$venv" -p 3.12 2>/dev/null || uv venv "$venv" 2>/dev/null
            doctor_fix "Created Python venv"
        else
            doctor_fail "Python venv missing (install uv)"
            return
        fi
    fi
    
    [[ ! -f "$req" ]] && { doctor_pass "Python (no requirements.txt)"; return; }
    
    # Use uv to check packages
    if command -v uv &>/dev/null; then
        local installed
        installed=$(VIRTUAL_ENV="$venv" uv pip list 2>/dev/null | tail -n +3 | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
        local missing=0
        
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
            local pkg="${line%%[<>=]*}"
            pkg=$(echo "$pkg" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
            echo "$installed" | grep -q "^${pkg}$" || ((missing++)) || true
        done < "$req"
        
        if [[ $missing -gt 0 ]]; then
            VIRTUAL_ENV="$venv" uv pip install -r "$req" 2>/dev/null
            doctor_fix "Installed $missing Python package(s)"
        else
            doctor_pass "Python packages OK"
        fi
    else
        doctor_fail "uv not installed, cannot check Python packages"
    fi
}

check_niri_running() {
    if [[ -n "$NIRI_SOCKET" && -S "$NIRI_SOCKET" ]]; then
        doctor_pass "Niri compositor running"
    else
        doctor_fail "Niri not detected (run inside Niri session)"
    fi
}

check_version_tracking() {
    local version_file="${XDG_CONFIG_HOME}/illogical-impulse/version.json"
    local installed_marker="${XDG_CONFIG_HOME}/illogical-impulse/installed_true"
    
    if [[ -f "$installed_marker" && ! -f "$version_file" ]]; then
        # Existing install without tracking - create it
        local repo_ver=$(get_repo_version 2>/dev/null || echo "unknown")
        local repo_commit=$(get_repo_commit 2>/dev/null || echo "unknown")
        set_installed_version "$repo_ver" "$repo_commit" "doctor"
        doctor_fix "Created version tracking"
    else
        doctor_pass "Version tracking OK"
    fi
}

check_manifest() {
    local manifest="${XDG_CONFIG_HOME}/quickshell/ii/.ii-manifest"
    local installed_marker="${XDG_CONFIG_HOME}/illogical-impulse/installed_true"
    
    if [[ -f "$installed_marker" && ! -f "$manifest" ]]; then
        # Generate manifest from current state
        local target="${XDG_CONFIG_HOME}/quickshell/ii"
        if [[ -d "$target" ]]; then
            generate_manifest "$target" "$manifest" 2>/dev/null || true
            doctor_fix "Created file manifest"
        fi
    else
        doctor_pass "File manifest OK"
    fi
}

check_quickshell_loads() {
    # Skip if no graphical session
    if [[ -z "$WAYLAND_DISPLAY" && -z "$DISPLAY" && -z "$NIRI_SOCKET" ]]; then
        doctor_pass "Quickshell (skipped - no display)"
        return 0
    fi
    
    # If already running, just check it's responsive
    if pgrep -f "qs.*-c.*ii" &>/dev/null; then
        doctor_pass "Quickshell running"
        return 0
    fi
    
    # Not running - try to start and check for errors
    echo -e "${STY_FAINT}Starting quickshell...${STY_RST}"
    
    # Start in background and capture initial output
    local logfile="/tmp/qs-doctor-$$.log"
    nohup qs -c ii >"$logfile" 2>&1 &
    local qs_pid=$!
    disown
    
    # Wait a bit for startup
    sleep 2
    
    # Check if it's still running
    if ! kill -0 "$qs_pid" 2>/dev/null; then
        # Crashed - check why
        local output=$(cat "$logfile" 2>/dev/null)
        rm -f "$logfile"
        
        if echo "$output" | grep -qE "(could not connect to display|no Qt platform plugin)"; then
            doctor_fail "Quickshell cannot connect to display"
            return 1
        fi
        
        local errors=$(echo "$output" | grep -E "(ERROR|error:)" | head -1)
        if [[ -n "$errors" ]]; then
            doctor_fail "Quickshell crashed: $errors"
            return 1
        fi
        
        doctor_fail "Quickshell crashed on startup"
        return 1
    fi
    
    rm -f "$logfile"
    doctor_pass "Quickshell started"
    return 0
}

check_matugen_colors() {
    local colors_json="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/colors.json"
    local colors_scss="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/material_colors.scss"
    local darkly_file="${HOME}/.local/share/color-schemes/Darkly.colors"
    
    # Check if colors exist (colors.json is primary, scss is legacy)
    if [[ ! -f "$colors_json" && ! -f "$colors_scss" ]]; then
        # Try to auto-generate from current wallpaper
        local wallpaper=""
        local config="${XDG_CONFIG_HOME}/illogical-impulse/config.json"
        if [[ -f "$config" ]] && command -v jq &>/dev/null; then
            wallpaper=$(jq -r '.background.wallpaperPath // empty' "$config" 2>/dev/null)
        fi
        
        if [[ -n "$wallpaper" && -f "$wallpaper" && -s "$wallpaper" ]] && command -v matugen &>/dev/null; then
            local matugen_cfg="${XDG_CONFIG_HOME}/matugen/config.toml"
            if [[ -f "$matugen_cfg" ]]; then
                matugen -c "$matugen_cfg" image "$wallpaper" 2>/dev/null
                doctor_fix "Regenerated theme colors from wallpaper"
            else
                matugen image "$wallpaper" 2>/dev/null
                doctor_fix "Regenerated theme colors (no matugen config)"
            fi
        else
            doctor_fail "Theme colors not generated (no valid wallpaper set)"
            echo -e "    ${STY_FAINT}Set a wallpaper via ii settings or run: matugen image /path/to/wallpaper.png${STY_RST}"
            return 1
        fi
    else
        doctor_pass "Theme colors generated"
    fi
    
    if [[ ! -f "$darkly_file" ]]; then
        # Try to regenerate Darkly colors
        local darkly_script="${XDG_CONFIG_HOME}/quickshell/ii/scripts/colors/apply-gtk-theme.sh"
        if [[ -f "$darkly_script" ]]; then
            bash "$darkly_script" 2>/dev/null
            [[ -f "$darkly_file" ]] && doctor_fix "Regenerated Darkly Qt colors" || doctor_fail "Darkly Qt colors generation failed"
        else
            doctor_fail "Darkly Qt colors missing"
        fi
    else
        doctor_pass "Darkly Qt colors OK"
    fi
    return 0
}

check_conflicting_services() {
    local conflicts=("dunst" "mako" "swaync")
    local running=()
    
    for svc in "${conflicts[@]}"; do
        if pgrep -x "$svc" &>/dev/null; then
            running+=("$svc")
        fi
    done
    
    if [[ ${#running[@]} -gt 0 ]]; then
        # Auto-kill conflicting notification daemons
        for proc in "${running[@]}"; do
            pkill -x "$proc" 2>/dev/null
            systemctl --user disable --now "${proc}.service" 2>/dev/null || true
        done
        doctor_fix "Killed conflicting: ${running[*]} (Quickshell has built-in notifications)"
    else
        doctor_pass "No conflicting notification daemons"
    fi
}

check_wallpaper_health() {
    local wallpaper_dir
    wallpaper_dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Wallpapers"
    local assets_dir="${XDG_CONFIG_HOME}/quickshell/ii/assets/wallpapers"
    
    [[ ! -d "$wallpaper_dir" ]] && { doctor_pass "Wallpapers (dir not created yet)"; return 0; }
    
    local zero_byte=0
    local fixed=0
    local _wp_files=()
    while IFS= read -r -d '' f; do
        _wp_files+=("$f")
    done < <(find "$wallpaper_dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -print0 2>/dev/null)
    for f in "${_wp_files[@]}"; do
        if [[ ! -s "$f" ]]; then
            ((zero_byte++)) || true
            # Try to restore from assets
            local basename=$(basename "$f")
            if [[ -f "$assets_dir/$basename" && -s "$assets_dir/$basename" ]]; then
                cp -f "$assets_dir/$basename" "$f"
                ((fixed++)) || true
            else
                rm -f "$f"  # Remove corrupt 0-byte file
                ((fixed++)) || true
            fi
        fi
    done
    
    if [[ $zero_byte -gt 0 ]]; then
        doctor_fix "Repaired $fixed/$zero_byte corrupt wallpaper(s)"
    else
        doctor_pass "Wallpapers healthy"
    fi
}

check_environment_vars() {
    local venv_path="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/.venv"
    local fixed=0
    
    # Check bash
    if [[ -f "$HOME/.bashrc" ]] && ! grep -q "ILLOGICAL_IMPULSE_VIRTUAL_ENV" "$HOME/.bashrc" 2>/dev/null; then
        cat >> "$HOME/.bashrc" << BEOF

# iNiR environment
export ILLOGICAL_IMPULSE_VIRTUAL_ENV="${venv_path}"
# end iNiR
BEOF
        ((fixed++)) || true
    fi
    
    # Check fish
    local fish_conf="${XDG_CONFIG_HOME}/fish/conf.d/inir-env.fish"
    if command -v fish &>/dev/null && [[ ! -f "$fish_conf" ]]; then
        mkdir -p "$(dirname "$fish_conf")"
        cat > "$fish_conf" << FEOF
# iNiR environment — auto-generated by doctor
set -gx ILLOGICAL_IMPULSE_VIRTUAL_ENV "${venv_path}"
FEOF
        ((fixed++)) || true
    fi
    
    # Check zsh
    if [[ -f "$HOME/.zshrc" ]] && ! grep -q "ILLOGICAL_IMPULSE_VIRTUAL_ENV" "$HOME/.zshrc" 2>/dev/null; then
        cat >> "$HOME/.zshrc" << ZEOF

# iNiR environment
export ILLOGICAL_IMPULSE_VIRTUAL_ENV="${venv_path}"
# end iNiR
ZEOF
        ((fixed++)) || true
    fi
    
    if [[ $fixed -gt 0 ]]; then
        doctor_fix "Added environment variables to $fixed shell profile(s)"
    else
        doctor_pass "Shell environment variables OK"
    fi
}

check_qt_theming() {
    # Check that plasma-integration is installed (required for kde platform theme)
    # Without it, Darkly style can't read kdeglobals colors → black text on dark bg
    local plugin_found=false
    for plugindir in /usr/lib/qt6/plugins/platformthemes /usr/lib64/qt6/plugins/platformthemes \
                     /usr/lib/x86_64-linux-gnu/qt6/plugins/platformthemes; do
        if [[ -f "${plugindir}/KDEPlasmaPlatformTheme6.so" ]]; then
            plugin_found=true
            break
        fi
    done

    if ! $plugin_found; then
        doctor_fail "plasma-integration not installed (Qt apps will have broken colors)"
        case "${OS_GROUP_ID:-unknown}" in
            arch) echo -e "    ${STY_FAINT}Run: sudo pacman -S plasma-integration${STY_RST}" ;;
            fedora) echo -e "    ${STY_FAINT}Run: sudo dnf install plasma-integration${STY_RST}" ;;
            debian|ubuntu) echo -e "    ${STY_FAINT}Run: sudo apt install plasma-integration${STY_RST}" ;;
            *) echo -e "    ${STY_FAINT}Install plasma-integration using your package manager${STY_RST}" ;;
        esac
    else
        # Also check niri config isn't stuck on qt6ct when kde plugin is available
        local niri_cfg="${XDG_CONFIG_HOME}/niri/config.kdl"
        if [[ -f "$niri_cfg" ]] && grep -q 'QT_QPA_PLATFORMTHEME "qt6ct"' "$niri_cfg"; then
            sed -i 's/QT_QPA_PLATFORMTHEME "qt6ct"/QT_QPA_PLATFORMTHEME "kde"/' "$niri_cfg"
            doctor_fix "Switched QT_QPA_PLATFORMTHEME from qt6ct to kde"
        else
            doctor_pass "Qt theming OK (plasma-integration + kde platform)"
        fi
    fi

    # Check Darkly style is installed
    local darkly_found=false
    for styledir in /usr/lib/qt6/plugins/styles /usr/lib64/qt6/plugins/styles \
                    /usr/lib/x86_64-linux-gnu/qt6/plugins/styles; do
        if [[ -f "${styledir}/darkly6.so" ]]; then
            darkly_found=true
            break
        fi
    done

    if ! $darkly_found; then
        doctor_fail "Darkly Qt style not installed (Qt apps won't have Material You style)"
        case "${OS_GROUP_ID:-unknown}" in
            arch) echo -e "    ${STY_FAINT}Run: yay -S darkly-bin${STY_RST}" ;;
            *) echo -e "    ${STY_FAINT}Install darkly from: https://github.com/AlessioC31/darkly${STY_RST}" ;;
        esac
    else
        doctor_pass "Darkly Qt style OK"
    fi
}

check_niri_config() {
    local niri_cfg="${XDG_CONFIG_HOME}/niri/config.kdl"
    [[ ! -f "$niri_cfg" ]] && { doctor_pass "Niri config (not installed)"; return 0; }
    
    if command -v niri &>/dev/null; then
        local output
        output=$(niri validate 2>&1)
        if echo "$output" | grep -qi "valid"; then
            doctor_pass "Niri config valid"
        else
            doctor_fail "Niri config has errors"
            echo -e "    ${STY_FAINT}$(echo "$output" | grep -i error | head -2)${STY_RST}"
        fi
    else
        doctor_pass "Niri config (niri not installed, skipping validation)"
    fi
}

###############################################################################
# Main
###############################################################################

run_doctor_with_fixes() {
    local total_steps=16
    doctor_passed=0
    doctor_failed=0
    doctor_fixed=0
    
    tui_step 1 $total_steps "Checking dependencies"
    check_dependencies

    if [[ ${#doctor_missing_deps[@]} -gt 0 ]]; then
        detect_distro
        case "$OS_GROUP_ID" in
            arch|fedora|debian|ubuntu)
                if ! $ask || tui_confirm "Install missing dependencies now?"; then
                    SKIP_SYSUPDATE=true
                    ONLY_MISSING_DEPS="${doctor_missing_deps[*]}"
                    source ./sdata/subcmd-install/1.deps-router.sh
                    check_dependencies
                fi
                ;;
            *)
                echo -e "${STY_YELLOW}Automatic dependency installation not available for ${OS_GROUP_ID}.${STY_RST}"
                echo -e "${STY_YELLOW}Please install missing dependencies manually.${STY_RST}"
                ;;
        esac
    fi
    
    tui_step 2 $total_steps "Checking critical files"
    check_critical_files
    
    tui_step 3 $total_steps "Checking script permissions"
    check_script_permissions
    
    tui_step 4 $total_steps "Checking user config"
    check_user_config
    
    tui_step 5 $total_steps "Checking state directories"
    check_state_directories
    
    tui_step 6 $total_steps "Checking version tracking"
    check_version_tracking
    
    tui_step 7 $total_steps "Checking file manifest"
    check_manifest
    
    tui_step 8 $total_steps "Checking Niri compositor"
    check_niri_running
    
    tui_step 9 $total_steps "Checking Python packages"
    check_python_packages
    
    tui_step 10 $total_steps "Checking Quickshell"
    check_quickshell_loads
    
    tui_step 11 $total_steps "Checking theme colors"
    check_matugen_colors
    
    tui_step 12 $total_steps "Checking Qt theming"
    check_qt_theming
    
    tui_step 13 $total_steps "Checking conflicting services"
    check_conflicting_services
    
    tui_step 14 $total_steps "Checking wallpaper health"
    check_wallpaper_health
    
    tui_step 15 $total_steps "Checking environment variables"
    check_environment_vars
    
    tui_step 16 $total_steps "Checking Niri config"
    check_niri_config
    
    echo ""
    tui_divider
    echo ""
    
    # Summary
    tui_title "Summary"
    echo ""
    tui_status_line "Passed:" "$doctor_passed" "ok"
    tui_status_line "Fixed:" "$doctor_fixed" "warn"
    tui_status_line "Failed:" "$doctor_failed" "error"
    
    echo ""
    if [[ $doctor_failed -gt 0 ]]; then
        tui_error "Some issues need manual attention."
        return 1
    elif [[ $doctor_fixed -gt 0 ]]; then
        tui_success "All issues fixed automatically."
    else
        tui_success "Everything looks good!"
    fi
}

# Legacy function name for compatibility
run_doctor() {
    run_doctor_with_fixes
}
