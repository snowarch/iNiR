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
        "matugen:matugen"
        "wlsunset:wlsunset"
        "dunstify:dunst"
        "fish:fish"
        "magick:ImageMagick"
        "swaylock:swaylock"
        "grim:grim"
        "mpv:mpv"
    )
    
    # Optional but recommended
    local optional_cmds=(
        "easyeffects:EasyEffects"
        "uv:uv"
        "cava:cava"
        "qalc:qalculate"
        "yt-dlp:yt-dlp"
        "blueman-manager:Blueman"
        "kwriteconfig6:KConfig"
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
        doctor_missing_deps=("${missing[@]}")
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
    
    # Check if venv exists
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

    # Check if quickshell is actually running (not swayidle or other processes)
    # Use pgrep -x to match exact command name "qs", then verify it's the right instance
    local qs_pid=$(pgrep -x "qs" 2>/dev/null | while read pid; do
        # Check if this process has "-c" and "ii" in its cmdline (null-separated)
        # Convert null bytes to newlines and check for both patterns
        if tr '\0' '\n' < /proc/$pid/cmdline 2>/dev/null | grep -qx "\-c" && \
           tr '\0' '\n' < /proc/$pid/cmdline 2>/dev/null | grep -qx "ii"; then
            echo $pid
            break
        fi
    done)
    
    if [[ -n "$qs_pid" ]]; then
        # Process exists - check if it's responsive/stuck
        # Check if process is in uninterruptible sleep (D state) or zombie (Z state)
        local proc_state=$(cat /proc/$qs_pid/stat 2>/dev/null | awk '{print $3}')
        
        # Check if quickshell socket exists (look for any socket in the quickshell directory)
        local socket_ok=false
        local socket_count=$(find /run/user/$(id -u)/quickshell/ -name "*.sock" 2>/dev/null | wc -l)
        if [[ "$socket_count" -gt 0 ]]; then
            socket_ok=true
        fi
        
        # Check if process has been running long enough (not stuck in startup)
        local proc_runtime=$(ps -o etimes= -p $qs_pid 2>/dev/null | tr -d ' ')
        
        # Only restart if process is definitely stuck (zombie or uninterruptible sleep)
        if [[ "$proc_state" == "D" ]] || [[ "$proc_state" == "Z" ]]; then
            echo -e "${STY_YELLOW}Quickshell process is stuck (state: $proc_state), restarting...${STY_RST}"
            kill -9 $qs_pid 2>/dev/null || true
            sleep 1
        elif [[ -n "$proc_runtime" ]] && [[ "$proc_runtime" -lt 3 ]]; then
            # Process started very recently - give it time to initialize
            echo -e "${STY_FAINT}Quickshell starting up, waiting for initialization...${STY_RST}"
            sleep 3
            # Re-check after waiting
            local new_qs_pid=$(pgrep -x "qs" 2>/dev/null | while read pid; do
                if tr '\0' '\n' < /proc/$pid/cmdline 2>/dev/null | grep -qx "\-c" && \
                   tr '\0' '\n' < /proc/$pid/cmdline 2>/dev/null | grep -qx "ii"; then
                    echo $pid
                    break
                fi
            done)
            if [[ -n "$new_qs_pid" ]]; then
                doctor_pass "Quickshell running"
                return 0
            else
                echo -e "${STY_YELLOW}Quickshell crashed during startup${STY_RST}"
            fi
        elif [[ "$socket_ok" == false ]] && [[ -n "$proc_runtime" ]] && [[ "$proc_runtime" -gt 30 ]]; then
            # Running for 30+ seconds but no socket files at all - likely crashed/hung
            # Be conservative here - only restart after significant time without sockets
            echo -e "${STY_YELLOW}Quickshell running but no IPC sockets found after 30s, restarting...${STY_RST}"
            kill -9 $qs_pid 2>/dev/null || true
            pkill -x "qs" 2>/dev/null || true
            sleep 1
        else
            # Process exists, not stuck, and either has sockets or hasn't been running long enough to be sure it's broken
            doctor_pass "Quickshell running"
            return 0
        fi
    fi

    # Not running - clean up any orphaned processes first
    echo -e "${STY_FAINT}Quickshell not running, cleaning up...${STY_RST}"
    qs kill -c ii 2>/dev/null || true
    pkill -x "qs" 2>/dev/null || true
    sleep 1

    echo -e "${STY_FAINT}Starting quickshell...${STY_RST}"

    # Start in background and capture output
    local logfile="/tmp/qs-doctor-$$.log"
    nohup qs -c ii >"$logfile" 2>&1 &
    local qs_pid=$!
    disown

    # Poll for up to 10 seconds (increased from 2)
    local attempts=0
    local max_attempts=20
    local started=false

    while [[ $attempts -lt $max_attempts ]]; do
        sleep 0.5
        ((attempts++))

        # Check if process is still alive
        if ! kill -0 "$qs_pid" 2>/dev/null; then
            # Process died, collect logs
            break
        fi

        # Check if quickshell actually started successfully
        # It should be in process list AND have created its socket
        local check_qs_pid=$(pgrep -x "qs" 2>/dev/null | while read pid; do
            if tr '\0' '\n' < /proc/$pid/cmdline 2>/dev/null | grep -qx "\-c" && \
               tr '\0' '\n' < /proc/$pid/cmdline 2>/dev/null | grep -qx "ii"; then
                echo $pid
                break
            fi
        done)
        if [[ -n "$check_qs_pid" ]]; then
            started=true
            break
        fi
    done

    # If it started, verify it's still running
    if $started; then
        sleep 1  # Give it a moment to stabilize
        local verify_qs_pid=$(pgrep -x "qs" 2>/dev/null | while read pid; do
            if tr '\0' '\n' < /proc/$pid/cmdline 2>/dev/null | grep -qx "\-c" && \
               tr '\0' '\n' < /proc/$pid/cmdline 2>/dev/null | grep -qx "ii"; then
                echo $pid
                break
            fi
        done)
        if [[ -n "$verify_qs_pid" ]]; then
            rm -f "$logfile"
            doctor_pass "Quickshell started"
            return 0
        fi
    fi

    # Failed to start - analyze the logs
    local output=$(cat "$logfile" 2>/dev/null)
    rm -f "$logfile"

    # Show the last 20 lines of output for debugging
    if [[ -n "$output" ]]; then
        echo ""
        echo -e "${STY_YELLOW}Last startup messages:${STY_RST}"
        echo "$output" | tail -20 | sed 's/^/  /'
        echo ""
    fi

    # Check for specific error patterns (exclude DEBUG messages)
    if echo "$output" | grep -vE "^\s*DEBUG" | grep -qE "(could not connect to display|no Qt platform plugin|qt.qpa.plugin)"; then
        doctor_fail "Quickshell cannot connect to display"
        echo -e "    ${STY_FAINT}Are you running in a graphical session?${STY_RST}"
        return 1
    fi

    # QML errors - look for actual import/module failures and type errors
    if echo "$output" | grep -vE "^\s*DEBUG" | grep -qE "(module.*not found|import.*failed|TypeError|qml.*Error:)"; then
        local qml_error=$(echo "$output" | grep -vE "^\s*DEBUG" | grep -E "(module.*not found|import.*failed|TypeError|qml.*Error:)" | head -1)
        doctor_fail "Quickshell QML error: $qml_error"
        return 1
    fi

    # General errors - exclude DEBUG/INFO lines and SyntaxError in debug context
    if echo "$output" | grep -vE "^\s*(DEBUG|INFO)" | grep -qE "\b(ERROR|error:)\b"; then
        local error_line=$(echo "$output" | grep -vE "^\s*(DEBUG|INFO)" | grep -E "\b(ERROR|error:)\b" | head -1)
        doctor_fail "Quickshell error: $error_line"
        return 1
    fi

    doctor_fail "Quickshell crashed on startup (check logs with: qs log -c ii)"
    return 1
}

check_matugen_colors() {
    local colors_file="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/material_colors.scss"
    local darkly_file="${HOME}/.local/share/color-schemes/Darkly.colors"
    
    if [[ ! -f "$colors_file" ]]; then
        doctor_fail "Material colors not generated"
        echo -e "    ${STY_FAINT}Run: matugen image /path/to/wallpaper.png${STY_RST}"
        echo -e "    ${STY_FAINT}Or: Set wallpaper via ii settings${STY_RST}"
        return 1
    fi
    
    if [[ ! -f "$darkly_file" ]]; then
        doctor_fail "Darkly Qt colors not generated"
        echo -e "    ${STY_FAINT}Run: bash ~/.config/quickshell/ii/scripts/colors/apply-gtk-theme.sh${STY_RST}"
        return 1
    fi
    
    doctor_pass "Theme colors generated"
    return 0
}

###############################################################################
# Main
###############################################################################

run_doctor_with_fixes() {
    doctor_passed=0
    doctor_failed=0
    doctor_fixed=0
    
    tui_step 1 11 "Checking dependencies"
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
    
    tui_step 2 11 "Checking critical files"
    check_critical_files
    
    tui_step 3 11 "Checking script permissions"
    check_script_permissions
    
    tui_step 4 11 "Checking user config"
    check_user_config
    
    tui_step 5 11 "Checking state directories"
    check_state_directories
    
    tui_step 6 11 "Checking version tracking"
    check_version_tracking
    
    tui_step 7 11 "Checking file manifest"
    check_manifest
    
    tui_step 8 11 "Checking Niri compositor"
    check_niri_running
    
    tui_step 9 11 "Checking Python packages"
    check_python_packages
    
    tui_step 10 11 "Checking Quickshell"
    check_quickshell_loads
    
    tui_step 11 11 "Checking theme colors"
    check_matugen_colors
    check_quickshell_loads
    
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
