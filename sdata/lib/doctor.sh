# Doctor command for iNiR
# Diagnoses AND FIXES common issues
# This script is meant to be sourced.

# shellcheck shell=bash

doctor_passed=0
doctor_failed=0
doctor_fixed=0
doctor_missing_deps=()

# Ensure XDG paths are always defined (doctor can be sourced outside setup bootstrap)
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

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
        "fish:fish"
        "magick:ImageMagick"
        "grim:grim"
        "cliphist:cliphist"
        "wl-copy:wl-clipboard"
        "wl-paste:wl-clipboard"
        "fuzzel:fuzzel"
        "awww:awww"
        "hyprpicker:hyprpicker"
        "playerctl:playerctl"
        "notify-send:libnotify"
        "flock:util-linux"
        "go:go"
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
        "ffmpeg:ffmpeg"
        "swappy:swappy"
        "tesseract:tesseract"
        "blueman-manager:Blueman"
        "gowall:gowall"
        "kwriteconfig6:KConfig"
        "checkupdates:pacman-contrib"
        "ddcutil:ddcutil"
        "missioncenter:mission-center"
        "nm-connection-editor:nm-connection-editor"
        "xdg-settings:xdg-utils"
        "mpv:mpv"
        "swaylock:swaylock"
        "swayidle:swayidle"
        "wlsunset:wlsunset"
        "songrec:SongRec"
        "trans:translate-shell"
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

doctor_runtime_missing_reported=false

doctor_repo_root() {
    if [[ -n "${REPO_ROOT:-}" && -f "${REPO_ROOT}/shell.qml" ]]; then
        printf '%s' "$REPO_ROOT"
        return 0
    fi

    local guessed
    guessed="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)"
    if [[ -n "$guessed" && -f "$guessed/shell.qml" ]]; then
        printf '%s' "$guessed"
        return 0
    fi

    return 1
}

doctor_fallback_wallpaper() {
    local runtime_dir
    local repo_root
    local search_dirs=()

    runtime_dir="$(doctor_runtime_dir)"
    [[ -n "$runtime_dir" ]] && search_dirs+=("$runtime_dir/assets/wallpapers")

    repo_root="$(doctor_repo_root || true)"
    [[ -n "$repo_root" ]] && search_dirs+=("$repo_root/assets/wallpapers")

    local dir
    local candidate
    for dir in "${search_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' candidate; do
            if [[ -f "$candidate" && -s "$candidate" ]]; then
                printf '%s' "$candidate"
                return 0
            fi
        done < <(find "$dir" -maxdepth 1 -type f \
            \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
            -print0 2>/dev/null)
    done

    return 1
}

doctor_runtime_dir() {
    local target
    target="$(get_runtime_shell_dir)"
    if [[ -n "$target" && -f "$target/shell.qml" ]]; then
        printf '%s' "$target"
    fi
}

doctor_runtime_dir_or_fail() {
    local check_name="${1:-}"
    local target
    target="$(doctor_runtime_dir)"
    if [[ -n "$target" ]]; then
        printf '%s' "$target"
        return 0
    fi

    if [[ "$doctor_runtime_missing_reported" != true ]]; then
        tui_error "Runtime payload missing (run ./setup install)"
        ((doctor_failed++)) || true
        doctor_runtime_missing_reported=true
    fi

    if [[ -n "$check_name" ]]; then
        tui_info "$check_name skipped (runtime payload missing)"
    fi

    return 1
}

check_critical_files() {
    local target
    target="$(doctor_runtime_dir)"
    if [[ -z "$target" ]]; then
        doctor_runtime_dir_or_fail "Critical files"
        return 0
    fi
    local critical=("shell.qml" "GlobalStates.qml" "modules/common/Config.qml" "services/NiriService.qml")
    local missing=0
    
    for file in "${critical[@]}"; do
        [[ ! -f "$target/$file" ]] && { doctor_fail "Missing: $file"; ((missing++)) || true; }
    done
    
    [[ $missing -eq 0 ]] && doctor_pass "Critical files present"
}

check_script_permissions() {
    local target
    target="$(doctor_runtime_dir)"
    if [[ -z "$target" ]]; then
        doctor_runtime_dir_or_fail "Script permissions"
        return 0
    fi
    target="${target}/scripts"
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
    local config="${DOTS_CORE_CONFDIR}/config.json"
    
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
    local dirs=("${XDG_STATE_HOME}/quickshell/user" "${XDG_CACHE_HOME}/quickshell" "${DOTS_CORE_CONFDIR}")
    local created=0
    
    for dir in "${dirs[@]}"; do
        [[ ! -d "$dir" ]] && { mkdir -p "$dir"; ((created++)) || true; }
    done
    
    [[ $created -gt 0 ]] && doctor_fix "Created $created directory(ies)" || doctor_pass "State directories exist"
}

check_python_packages() {
    local venv="${XDG_STATE_HOME}/quickshell/.venv"
    local req=""
    local runtime_dir
    local repo_root

    runtime_dir="$(doctor_runtime_dir)"
    if [[ -n "$runtime_dir" && -f "${runtime_dir}/sdata/uv/requirements.txt" ]]; then
        req="${runtime_dir}/sdata/uv/requirements.txt"
    else
        repo_root="$(doctor_repo_root || true)"
        if [[ -n "$repo_root" && -f "${repo_root}/sdata/uv/requirements.txt" ]]; then
            req="${repo_root}/sdata/uv/requirements.txt"
        else
            doctor_runtime_dir_or_fail "Python packages"
            doctor_pass "Python (no requirements.txt)"
            return 0
        fi
    fi
    
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

check_fonts() {
    # Font families required by the shell at runtime.
    # Derived from Appearance.qml font.family.* and Looks.qml font.family.*.
    #
    # Format: "fc-list query pattern : display name : criticality"
    #   criticality: critical  = shell UI is broken without it (icons unreadable)
    #                important = significant visual degradation
    #                optional  = nice-to-have, fallback acceptable

    local critical_fonts=(
        "Material Symbols Rounded:Material Symbols Rounded:critical"
        "JetBrainsMono Nerd:JetBrainsMono Nerd Font:critical"
    )

    local important_fonts=(
        "Roboto Flex:Roboto Flex:important"
        "Rubik:Rubik:important"
        "Space Grotesk:Space Grotesk:important"
        "Readex Pro:Readex Pro:important"
    )

    local optional_fonts=(
        "Material Symbols Outlined:Material Symbols Outlined:optional"
        "Gabarito:Gabarito:optional"
        "Geist:Geist:optional"
        "Oxanium:Oxanium:optional"
        "Noto Color Emoji:Noto Color Emoji:optional"
    )

    if ! command -v fc-list &>/dev/null; then
        doctor_fail "fontconfig not installed (cannot verify fonts)"
        return 1
    fi

    local fc_cache
    fc_cache="$(fc-list : family 2>/dev/null)"
    local user_font_dir="${XDG_DATA_HOME}/fonts"

    mkdir -p "$user_font_dir"

    local missing_critical=()
    local missing_important=()
    local missing_optional=()

    _font_installed() {
        echo "$fc_cache" | grep -qi "$1"
    }

    for entry in "${critical_fonts[@]}"; do
        local pattern="${entry%%:*}"
        local rest="${entry#*:}"
        local display="${rest%%:*}"
        _font_installed "$pattern" || missing_critical+=("$display")
    done

    for entry in "${important_fonts[@]}"; do
        local pattern="${entry%%:*}"
        local rest="${entry#*:}"
        local display="${rest%%:*}"
        _font_installed "$pattern" || missing_important+=("$display")
    done

    for entry in "${optional_fonts[@]}"; do
        local pattern="${entry%%:*}"
        local rest="${entry#*:}"
        local display="${rest%%:*}"
        _font_installed "$pattern" || missing_optional+=("$display")
    done

    local total_missing=$(( ${#missing_critical[@]} + ${#missing_important[@]} ))

    if [[ $total_missing -eq 0 && ${#missing_optional[@]} -eq 0 ]]; then
        doctor_pass "All fonts installed"
        return 0
    fi

    if [[ ${#missing_optional[@]} -gt 0 && $total_missing -eq 0 ]]; then
        tui_warn "Optional fonts missing: ${missing_optional[*]}"
        doctor_pass "Required fonts OK"
        return 0
    fi

    # Try to auto-fix before reporting failures
    local can_fix=false
    if declare -F _try_install_font_package &>/dev/null; then
        can_fix=true
    fi

    if $can_fix && [[ $total_missing -gt 0 ]]; then
        local fixed=0

        for font in "${missing_critical[@]}" "${missing_important[@]}"; do
            case "$font" in
                "Material Symbols Rounded")
                    _try_install_font_package "ttf-material-symbols-variable-git" "Material Symbols Rounded" && ((fixed++)) || true ;;
                "Material Symbols Outlined")
                    _try_install_font_package "ttf-material-symbols-variable-git" "Material Symbols Outlined" && ((fixed++)) || true ;;
                "JetBrainsMono Nerd Font")
                    _try_install_font_package "ttf-jetbrains-mono-nerd" "JetBrainsMono Nerd Font" && ((fixed++)) || true ;;
                "Roboto Flex")
                    _try_install_font_package "ttf-roboto-flex" "Roboto Flex" && ((fixed++)) || true ;;
                "Rubik")
                    _try_install_font_package "ttf-rubik" "Rubik" && ((fixed++)) || true ;;
                "Space Grotesk")
                    _try_install_font_package "ttf-space-grotesk" "Space Grotesk" && ((fixed++)) || true ;;
                "Readex Pro")
                    _try_install_font_package "ttf-readex-pro" "Readex Pro" && ((fixed++)) || true ;;
            esac
        done

        if [[ $fixed -gt 0 ]]; then
            fc-cache -f "$user_font_dir" 2>/dev/null || true
            fc-cache -f 2>/dev/null || true
            doctor_fix "Installed $fixed font(s)"
        fi
    fi

    # Re-check all fonts after fix attempt
    fc_cache="$(fc-list : family 2>/dev/null)"
    local still_critical=()
    local still_important=()

    for entry in "${critical_fonts[@]}"; do
        local pattern="${entry%%:*}"
        local rest="${entry#*:}"
        local display="${rest%%:*}"
        _font_installed "$pattern" || still_critical+=("$display")
    done

    for entry in "${important_fonts[@]}"; do
        local pattern="${entry%%:*}"
        local rest="${entry#*:}"
        local display="${rest%%:*}"
        _font_installed "$pattern" || still_important+=("$display")
    done

    if [[ ${#still_critical[@]} -gt 0 ]]; then
        doctor_fail "CRITICAL fonts missing: ${still_critical[*]}"
        echo -e "    ${STY_FAINT}Shell icons will be broken without these${STY_RST}"
    fi

    if [[ ${#still_important[@]} -gt 0 ]]; then
        doctor_fail "Important fonts missing: ${still_important[*]}"
        echo -e "    ${STY_FAINT}Install manually or run: ./setup install${STY_RST}"
    fi

    if [[ ${#still_critical[@]} -eq 0 && ${#still_important[@]} -eq 0 ]]; then
        doctor_pass "All required fonts OK"
    fi

    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        tui_warn "Optional fonts missing: ${missing_optional[*]}"
    fi
}

_try_install_font_package() {
    local pkg_name="$1"
    local display_name="$2"

    if [[ "${OS_GROUP_ID:-unknown}" == "arch" ]]; then
        local helper=""
        command -v yay &>/dev/null && helper="yay"
        command -v paru &>/dev/null && helper="paru"
        if [[ -n "$helper" ]]; then
            $helper -S --noconfirm --needed "$pkg_name" &>/dev/null && return 0
        fi
    fi

    local font_dir="${XDG_DATA_HOME}/fonts"
    mkdir -p "$font_dir"

    case "$display_name" in
        "Material Symbols Rounded")
            curl -fsSL -o "$font_dir/MaterialSymbolsRounded.ttf" \
                "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" 2>/dev/null && return 0
            ;;
        "Material Symbols Outlined")
            curl -fsSL -o "$font_dir/MaterialSymbolsOutlined.ttf" \
                "https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" 2>/dev/null && return 0
            ;;
        "JetBrainsMono Nerd Font")
            local tmp_nf="/tmp/nerdfonts-$$"
            mkdir -p "$tmp_nf"
            if curl -fsSL -o "$tmp_nf/JetBrainsMono.zip" \
                "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" 2>/dev/null; then
                unzip -o "$tmp_nf/JetBrainsMono.zip" -d "$font_dir" >/dev/null 2>&1
                rm -rf "$tmp_nf"
                return 0
            fi
            rm -rf "$tmp_nf"
            ;;
        "Roboto Flex")
            local tmp="/tmp/roboto-flex-$$"
            mkdir -p "$tmp"
            if curl -fsSL -o "$tmp/roboto-flex.zip" \
                "https://github.com/googlefonts/roboto-flex/releases/download/3.200/roboto-flex-fonts.zip" 2>/dev/null; then
                unzip -o -j "$tmp/roboto-flex.zip" "roboto-flex-fonts/fonts/variable/*.ttf" -d "$font_dir" >/dev/null 2>&1
                rm -rf "$tmp"
                return 0
            fi
            rm -rf "$tmp"
            ;;
        "Readex Pro")
            curl -fsSL -o "$font_dir/ReadexPro.ttf" \
                "https://github.com/google/fonts/raw/main/ofl/readexpro/ReadexPro%5BHEXP%2Cwght%5D.ttf" 2>/dev/null && return 0
            ;;
        "Space Grotesk")
            curl -fsSL -o "$font_dir/SpaceGrotesk.ttf" \
                "https://github.com/google/fonts/raw/main/ofl/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf" 2>/dev/null && return 0
            ;;
        "Rubik")
            curl -fsSL -o "$font_dir/Rubik.ttf" \
                "https://github.com/google/fonts/raw/main/ofl/rubik/Rubik%5Bwght%5D.ttf" 2>/dev/null && return 0
            ;;
        "Gabarito")
            curl -fsSL -o "$font_dir/Gabarito.ttf" \
                "https://github.com/google/fonts/raw/main/ofl/gabarito/Gabarito%5Bwght%5D.ttf" 2>/dev/null && return 0
            ;;
    esac

    return 1
}

check_niri_running() {
    if [[ -n "$NIRI_SOCKET" && -S "$NIRI_SOCKET" ]]; then
        doctor_pass "Niri compositor running"
    else
        doctor_fail "Niri not detected (run inside Niri session)"
    fi
}

check_version_tracking() {
    local version_file="${DOTS_CORE_CONFDIR}/version.json"
    local legacy_version_file="${XDG_CONFIG_HOME}/illogical-impulse/version.json"
    local runtime_version_file
    local installed_marker="${DOTS_CORE_CONFDIR}/installed_true"
    local repair_source=""
    runtime_version_file="$(get_runtime_version_file)"

    if [[ ! -f "$version_file" && -f "$legacy_version_file" ]]; then
        mkdir -p "${DOTS_CORE_CONFDIR}"
        cp "$legacy_version_file" "$version_file"
        doctor_fix "Migrated version tracking to active config directory"
    fi
    
    if [[ -f "$installed_marker" && -f "$version_file" ]] && ! version_file_has_core_metadata "$version_file"; then
        repair_source="incomplete"
    elif [[ -f "$installed_marker" && ! -f "$version_file" ]]; then
        repair_source="missing"
    fi

    if [[ -n "$repair_source" ]]; then
        if [[ -f "$runtime_version_file" ]] && version_file_has_core_metadata "$runtime_version_file"; then
            mkdir -p "$(dirname "$version_file")"
            cp "$runtime_version_file" "$version_file"
            if [[ "$repair_source" == "incomplete" ]]; then
                doctor_fix "Repaired version tracking from runtime metadata"
            else
                doctor_fix "Created version tracking from runtime metadata"
            fi
        else
            local repo_ver=$(get_repo_version 2>/dev/null || echo "unknown")
            local repo_commit=$(get_repo_commit 2>/dev/null || echo "unknown")
            set_installed_version "$repo_ver" "$repo_commit" "doctor"
            if [[ "$repair_source" == "incomplete" ]]; then
                doctor_fix "Repaired incomplete version tracking"
            else
                doctor_fix "Created version tracking"
            fi
        fi
    else
        doctor_pass "Version tracking OK"
    fi
}

check_manifest() {
    local target
    target="$(doctor_runtime_dir)"
    if [[ -z "$target" ]]; then
        doctor_runtime_dir_or_fail "File manifest"
        return 0
    fi
    local manifest="${target}/.inir-manifest"
    local installed_marker="${DOTS_CORE_CONFDIR}/installed_true"
    local installed_strategy
    installed_strategy=$(get_installed_update_strategy)

    if [[ "$installed_strategy" == "package-manager" ]]; then
        doctor_pass "File manifest not required for externally managed install"
        return 0
    fi
    
    if [[ -f "$installed_marker" && ! -f "$manifest" ]]; then
        # Generate manifest from current state
        if [[ -d "$target" ]]; then
            generate_manifest "$target" "$manifest" 2>/dev/null || true
            doctor_fix "Created file manifest"
        fi
    else
        doctor_pass "File manifest OK"
    fi
}

check_quickshell_abi() {
    # Quickshell uses Qt private APIs — any Qt minor version bump (e.g. 6.10→6.11)
    # breaks ABI and requires rebuilding quickshell. This is the #1 cause of
    # "quickshell crashes on any UI interaction" after system updates.
    # See: https://github.com/snowarch/iNiR/issues/93

    if ! command -v qs >/dev/null 2>&1; then
        # No qs binary — dependency check will catch this
        return 0
    fi

    # qs --version prints version info to stdout, but Qt ABI mismatch warnings
    # go to stderr at library load time before anything else runs
    local qs_stderr
    qs_stderr="$(qs --version 2>&1 >/dev/null || true)"

    # Also check combined output in case the warning format differs
    local qs_combined
    qs_combined="$(qs --version 2>&1 || true)"

    local mismatch_detected=false
    local mismatch_msg=""

    if echo "$qs_stderr" | grep -qiE "built against Qt|Qt.*mismatch|incompatible Qt"; then
        mismatch_detected=true
        mismatch_msg="$(echo "$qs_stderr" | grep -iE "built against Qt|Qt.*mismatch|incompatible Qt" | head -1)"
    elif echo "$qs_combined" | grep -qiE "built against Qt|Qt.*mismatch|incompatible Qt"; then
        mismatch_detected=true
        mismatch_msg="$(echo "$qs_combined" | grep -iE "built against Qt|Qt.*mismatch|incompatible Qt" | head -1)"
    fi

    # Secondary check: compare compile-time vs runtime Qt versions
    # ldd always shows the current system lib (not what qs was built against), so
    # we extract the compile-time Qt version from the qs binary via strings, and
    # the runtime Qt version from the libQt6Core.so symlink target.
    if ! $mismatch_detected; then
        local qs_path
        qs_path="$(command -v qs 2>/dev/null || true)"
        if [[ -n "$qs_path" ]]; then
            local buildtime_qt=""
            local runtime_qt=""

            # Compile-time Qt version embedded in qs binary
            if command -v strings >/dev/null 2>&1; then
                buildtime_qt="$(strings "$qs_path" 2>/dev/null | grep -P '^6\.\d+\.\d+$' | head -1 || true)"
            fi

            # Runtime Qt version from library symlink or pkg-config
            if [[ -L /usr/lib/libQt6Core.so.6 ]]; then
                runtime_qt="$(readlink -f /usr/lib/libQt6Core.so.6 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+$' || true)"
            fi
            if [[ -z "$runtime_qt" ]] && command -v pkg-config >/dev/null 2>&1; then
                runtime_qt="$(pkg-config --modversion Qt6Core 2>/dev/null || true)"
            fi

            if [[ -n "$buildtime_qt" && -n "$runtime_qt" ]]; then
                local build_minor="${buildtime_qt%.*}"
                local runtime_minor="${runtime_qt%.*}"
                if [[ "$build_minor" != "$runtime_minor" ]]; then
                    mismatch_detected=true
                    mismatch_msg="Quickshell built against Qt $buildtime_qt but system has Qt $runtime_qt"
                fi
            fi
        fi
    fi

    if $mismatch_detected; then
        doctor_fail "Qt/Quickshell ABI mismatch: $mismatch_msg"
        echo -e "  ${STY_YELLOW}Quickshell uses Qt private APIs that break on minor version bumps.${STY_RST}"
        echo -e "  ${STY_YELLOW}The shell will crash on any UI interaction until quickshell is rebuilt.${STY_RST}"

        # Attempt auto-fix on Arch
        local can_rebuild=false
        local rebuild_pkg=""
        local rebuild_helper=""

        if command -v pacman >/dev/null 2>&1; then
            if pacman -Qi quickshell-git &>/dev/null; then
                rebuild_pkg="quickshell-git"
            elif pacman -Qi quickshell-bin &>/dev/null; then
                rebuild_pkg="quickshell-bin"
            elif pacman -Qi quickshell &>/dev/null; then
                # Official package — should be rebuilt by maintainer, try reinstall
                rebuild_pkg="quickshell"
            fi

            if [[ -n "$rebuild_pkg" ]]; then
                for helper in yay paru; do
                    if command -v "$helper" >/dev/null 2>&1; then
                        rebuild_helper="$helper"
                        can_rebuild=true
                        break
                    fi
                done
            fi
        fi

        if $can_rebuild; then
            local do_rebuild=false
            if ! ${ask:-true}; then
                do_rebuild=true
            elif tui_confirm "Rebuild $rebuild_pkg to fix ABI mismatch?"; then
                do_rebuild=true
            fi

            # Determine the right rebuild command:
            # - Official repo (quickshell): sudo pacman -Syu
            # - Foreign/AUR package: --rebuild triggers source compilation
            # - Binary repo (CachyOS, chaotic-aur): -Sa forces AUR source build
            local rebuild_cmd=""
            if [[ "$rebuild_pkg" == "quickshell" ]]; then
                rebuild_cmd="sudo pacman -Syu"
            elif pacman -Qm "$rebuild_pkg" &>/dev/null; then
                rebuild_cmd="$rebuild_helper -S --rebuild --noconfirm $rebuild_pkg"
            else
                rebuild_cmd="$rebuild_helper -Sa --noconfirm $rebuild_pkg"
            fi

            if $do_rebuild; then
                echo -e "  ${STY_FAINT}Running: $rebuild_cmd${STY_RST}"
                if eval "$rebuild_cmd" 2>/dev/null; then
                    doctor_fix "Rebuilt $rebuild_pkg for current Qt version"
                    return 0
                else
                    echo -e "  ${STY_RED}Rebuild failed. Try manually: ${rebuild_cmd/--noconfirm /}${STY_RST}"
                fi
            else
                echo -e "  ${STY_YELLOW}To fix manually: ${rebuild_cmd/--noconfirm /}${STY_RST}"
            fi
        else
            echo -e "  ${STY_YELLOW}To fix: rebuild quickshell from source against the current Qt version.${STY_RST}"
            if command -v pacman >/dev/null 2>&1; then
                echo -e "  ${STY_YELLOW}On Arch: yay -Sa quickshell-git  (forces AUR source build)${STY_RST}"
            fi
        fi
        return 1
    fi

    doctor_pass "Quickshell/Qt ABI compatible"
    return 0
}

check_quickshell_loads() {
    local target
    local running_output
    target="$(doctor_runtime_dir)"
    if [[ -z "$target" ]]; then
        doctor_runtime_dir_or_fail "Quickshell"
        return 0
    fi

    # Skip if no graphical session
    if [[ -z "$WAYLAND_DISPLAY" && -z "$DISPLAY" && -z "$NIRI_SOCKET" ]]; then
        doctor_pass "Quickshell (skipped - no display)"
        return 0
    fi
    
    # If already running, just check it's responsive
    running_output="$(qs -p "$target" list 2>/dev/null || true)"
    if [[ -n "$running_output" && "$running_output" != No\ running\ instances* ]]; then
        doctor_pass "Quickshell running"
        return 0
    fi
    
    # Not running - try to start and check for errors
    echo -e "${STY_FAINT}Starting quickshell...${STY_RST}"
    
    # Start in background and capture initial output
    local logfile="/tmp/qs-doctor-$$.log"
    nohup qs -p "$target" >"$logfile" 2>&1 &
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
        
        # Check for ABI mismatch in crash output
        if echo "$output" | grep -qiE "built against Qt|Qt.*mismatch|incompatible Qt"; then
            doctor_fail "Quickshell crashed due to Qt ABI mismatch"
            echo -e "  ${STY_YELLOW}Run: inir doctor  (to auto-rebuild quickshell)${STY_RST}"
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
    local colors_json="${XDG_STATE_HOME}/quickshell/user/generated/colors.json"
    local colors_scss="${XDG_STATE_HOME}/quickshell/user/generated/material_colors.scss"
    local darkly_file="${XDG_DATA_HOME}/color-schemes/Darkly.colors"
    
    # Check if colors exist (colors.json is primary, scss is legacy)
    if [[ ! -f "$colors_json" && ! -f "$colors_scss" ]]; then
        # Try to auto-generate from current wallpaper
        local wallpaper=""
        local wallpaper_source="configured wallpaper"
        local config="${DOTS_CORE_CONFDIR}/config.json"
        if [[ -f "$config" ]] && command -v jq &>/dev/null; then
            wallpaper=$(jq -r '.background.wallpaperPath // empty' "$config" 2>/dev/null)
        fi

        if [[ -z "$wallpaper" || ! -f "$wallpaper" || ! -s "$wallpaper" ]]; then
            wallpaper="$(doctor_fallback_wallpaper || true)"
            [[ -n "$wallpaper" ]] && wallpaper_source="bundled fallback wallpaper"
        fi
        
        if [[ -n "$wallpaper" && -f "$wallpaper" && -s "$wallpaper" ]]; then
            local template_dir="${XDG_CONFIG_HOME}/matugen"

            local runtime_dir
            runtime_dir="$(doctor_runtime_dir)"
            local gen_material_script=""
            if [[ -n "$runtime_dir" && -f "${runtime_dir}/scripts/colors/generate_colors_material.py" ]]; then
                gen_material_script="${runtime_dir}/scripts/colors/generate_colors_material.py"
            else
                local repo_root
                repo_root="$(doctor_repo_root || true)"
                if [[ -n "$repo_root" && -f "${repo_root}/scripts/colors/generate_colors_material.py" ]]; then
                    gen_material_script="${repo_root}/scripts/colors/generate_colors_material.py"
                fi
            fi

            if [[ -n "$gen_material_script" ]]; then
                local python_cmd=""
                local venv_python="${XDG_STATE_HOME}/quickshell/.venv/bin/python3"
                if [[ -x "$venv_python" ]]; then
                    python_cmd="$venv_python"
                elif command -v python3 &>/dev/null; then
                    python_cmd="python3"
                fi

                if [[ -n "$python_cmd" ]]; then
                    mkdir -p "$(dirname "$colors_json")"
                    local _render_args=()
                    [[ -d "$template_dir" && -f "$template_dir/templates.json" ]] && _render_args+=(--render-templates "$template_dir")
                    "$python_cmd" "$gen_material_script" \
                        --path "$wallpaper" \
                        --mode dark \
                        --json-output "$colors_json" \
                        "${_render_args[@]}" \
                        >/dev/null 2>&1 || true
                fi
            fi

            if [[ -f "$colors_json" || -f "$colors_scss" ]]; then
                doctor_fix "Regenerated theme colors from ${wallpaper_source}"
            else
                doctor_fail "Theme colors regeneration failed"
                echo -e "    ${STY_FAINT}Python color generation failed — check venv${STY_RST}"
                return 1
            fi
        else
            doctor_fail "Theme colors not generated"
            echo -e "    ${STY_FAINT}Set a wallpaper via settings, then run: ./setup doctor${STY_RST}"
            return 1
        fi
    else
        doctor_pass "Theme colors generated"
    fi
    
    if [[ ! -f "$darkly_file" ]]; then
        # Try to regenerate Darkly colors
        local darkly_script
        local runtime_dir
        runtime_dir="$(doctor_runtime_dir)"
        darkly_script=""
        if [[ -n "$runtime_dir" && -f "${runtime_dir}/scripts/colors/apply-gtk-theme.sh" ]]; then
            darkly_script="${runtime_dir}/scripts/colors/apply-gtk-theme.sh"
        else
            local repo_root
            repo_root="$(doctor_repo_root || true)"
            if [[ -n "$repo_root" && -f "${repo_root}/scripts/colors/apply-gtk-theme.sh" ]]; then
                darkly_script="${repo_root}/scripts/colors/apply-gtk-theme.sh"
            else
                doctor_runtime_dir_or_fail "Darkly Qt colors"
                return 0
            fi
        fi

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
        for proc in "${running[@]}"; do
            pkill -x "$proc" 2>/dev/null
            systemctl --user disable --now "${proc}.service" 2>/dev/null || true
        done
        doctor_fix "Stopped conflicting: ${running[*]} (iNiR has built-in notifications, re-enable with: systemctl --user enable <service>)"
    else
        doctor_pass "No conflicting notification daemons"
    fi
}

check_wallpaper_health() {
    local wallpaper_dir
    wallpaper_dir="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Wallpapers"
    local assets_dir
    local runtime_dir
    runtime_dir="$(doctor_runtime_dir)"
    if [[ -n "$runtime_dir" ]]; then
        assets_dir="${runtime_dir}/assets/wallpapers"
    else
        local repo_root
        repo_root="$(doctor_repo_root || true)"
        if [[ -n "$repo_root" ]]; then
            assets_dir="${repo_root}/assets/wallpapers"
        else
            doctor_runtime_dir_or_fail "Wallpaper health"
            return 0
        fi
    fi
    
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
    
    # Check bash — look for INIR_VENV (canonical) or ILLOGICAL_IMPULSE_VIRTUAL_ENV (legacy)
    if [[ -f "$HOME/.bashrc" ]] && ! grep -q "INIR_VENV" "$HOME/.bashrc" 2>/dev/null; then
        cat >> "$HOME/.bashrc" << BEOF

# iNiR environment
export INIR_VENV="${venv_path}"
export ILLOGICAL_IMPULSE_VIRTUAL_ENV="\$INIR_VENV"
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
set -gx INIR_VENV "${venv_path}"
set -gx ILLOGICAL_IMPULSE_VIRTUAL_ENV "\$INIR_VENV"
FEOF
        ((fixed++)) || true
    fi
    
    # Check zsh
    if [[ -f "$HOME/.zshrc" ]] && ! grep -q "INIR_VENV" "$HOME/.zshrc" 2>/dev/null; then
        cat >> "$HOME/.zshrc" << ZEOF

# iNiR environment
export INIR_VENV="${venv_path}"
export ILLOGICAL_IMPULSE_VIRTUAL_ENV="\$INIR_VENV"
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
    
    # Try dynamic resolution first, then known paths as fallback
    local search_dirs=()
    if command -v qtpaths6 &>/dev/null; then
        local qt_plugin_dir
        qt_plugin_dir=$(qtpaths6 --plugin-dir 2>/dev/null || true)
        [[ -n "$qt_plugin_dir" ]] && search_dirs+=("${qt_plugin_dir}/platformthemes")
    elif command -v qtpaths &>/dev/null; then
        local qt_plugin_dir
        qt_plugin_dir=$(qtpaths --plugin-dir 2>/dev/null || true)
        [[ -n "$qt_plugin_dir" ]] && search_dirs+=("${qt_plugin_dir}/platformthemes")
    fi
    # Known fallback paths for common distros
    search_dirs+=(
        /usr/lib/qt6/plugins/platformthemes
        /usr/lib64/qt6/plugins/platformthemes
        /usr/lib/x86_64-linux-gnu/qt6/plugins/platformthemes
    )
    
    for plugindir in "${search_dirs[@]}"; do
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
    local style_dirs=()
    if command -v qtpaths6 &>/dev/null; then
        local qt_plugin_dir
        qt_plugin_dir=$(qtpaths6 --plugin-dir 2>/dev/null || true)
        [[ -n "$qt_plugin_dir" ]] && style_dirs+=("${qt_plugin_dir}/styles")
    elif command -v qtpaths &>/dev/null; then
        local qt_plugin_dir
        qt_plugin_dir=$(qtpaths --plugin-dir 2>/dev/null || true)
        [[ -n "$qt_plugin_dir" ]] && style_dirs+=("${qt_plugin_dir}/styles")
    fi
    style_dirs+=(
        /usr/lib/qt6/plugins/styles
        /usr/lib64/qt6/plugins/styles
        /usr/lib/x86_64-linux-gnu/qt6/plugins/styles
    )
    for styledir in "${style_dirs[@]}"; do
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
    local total_steps=18
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
    
    tui_step 2 $total_steps "Checking fonts"
    check_fonts
    
    tui_step 3 $total_steps "Checking critical files"
    check_critical_files
    
    tui_step 4 $total_steps "Checking script permissions"
    check_script_permissions
    
    tui_step 5 $total_steps "Checking user config"
    check_user_config
    
    tui_step 6 $total_steps "Checking state directories"
    check_state_directories
    
    tui_step 7 $total_steps "Checking version tracking"
    check_version_tracking
    
    tui_step 8 $total_steps "Checking file manifest"
    check_manifest
    
    tui_step 9 $total_steps "Checking Niri compositor"
    check_niri_running
    
    tui_step 10 $total_steps "Checking Python packages"
    check_python_packages
    
    tui_step 11 $total_steps "Checking Quickshell/Qt ABI"
    check_quickshell_abi
    
    tui_step 12 $total_steps "Checking Quickshell"
    check_quickshell_loads
    
    tui_step 13 $total_steps "Checking theme colors"
    check_matugen_colors
    
    tui_step 14 $total_steps "Checking Qt theming"
    check_qt_theming
    
    tui_step 15 $total_steps "Checking conflicting services"
    check_conflicting_services
    
    tui_step 16 $total_steps "Checking wallpaper health"
    check_wallpaper_health
    
    tui_step 17 $total_steps "Checking environment variables"
    check_environment_vars
    
    tui_step 18 $total_steps "Checking Niri config"
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
