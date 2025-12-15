# Doctor command for ii-niri
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
    local cmds=("qs:quickshell-git" "niri:niri" "nmcli:networkmanager" "wpctl:wireplumber" "jq:jq" "matugen:matugen-bin" "wlsunset:wlsunset" "dunstify:dunst" "fish:fish" "easyeffects:easyeffects")
    
    for item in "${cmds[@]}"; do
        local cmd="${item%%:*}"
        local pkg="${item##*:}"
        command -v "$cmd" &>/dev/null || missing+=("$pkg")
    done
    
    if [[ ${#missing[@]} -eq 0 ]]; then
        doctor_missing_deps=()
        doctor_pass "All required commands available"
    else
        doctor_missing_deps=("${missing[@]}")
        doctor_fail "Missing: ${missing[*]}"
        echo -e "    ${STY_FAINT}Run: yay -S ${missing[*]}${STY_RST}"
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
    local req="${XDG_CONFIG_HOME}/quickshell/ii/requirements.txt"
    
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

###############################################################################
# Main
###############################################################################

run_doctor_with_fixes() {
    doctor_passed=0
    doctor_failed=0
    doctor_fixed=0
    
    tui_step 1 10 "Checking dependencies"
    check_dependencies

    if [[ ${#doctor_missing_deps[@]} -gt 0 ]]; then
        detect_distro
        if [[ "$OS_GROUP_ID" == "arch" ]]; then
            if ! $ask || tui_confirm "Install missing dependencies now?"; then
                SKIP_SYSUPDATE=true
                ONLY_MISSING_DEPS="${doctor_missing_deps[*]}"
                source ./sdata/subcmd-install/1.deps-router.sh
                check_dependencies
            fi
        fi
    fi
    
    tui_step 2 10 "Checking critical files"
    check_critical_files
    
    tui_step 3 10 "Checking script permissions"
    check_script_permissions
    
    tui_step 4 10 "Checking user config"
    check_user_config
    
    tui_step 5 10 "Checking state directories"
    check_state_directories
    
    tui_step 6 10 "Checking version tracking"
    check_version_tracking
    
    tui_step 7 10 "Checking file manifest"
    check_manifest
    
    tui_step 8 10 "Checking Niri compositor"
    check_niri_running
    
    tui_step 9 10 "Checking Python packages"
    check_python_packages
    
    tui_step 10 10 "Checking Quickshell"
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
