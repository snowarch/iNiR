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
XDG_BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"

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

doctor_detect_compositor_service() {
    if ! command -v systemctl >/dev/null 2>&1; then
        return 1
    fi

    if systemctl --user cat niri.service &>/dev/null; then
        printf 'niri.service'
        return 0
    fi

    if systemctl --user cat 'wayland-wm@Hyprland.service' &>/dev/null; then
        printf 'wayland-wm@Hyprland.service'
        return 0
    fi

    return 1
}

###############################################################################
# Checks
###############################################################################

check_dependencies() {
    local missing=()
    local missing_cmds=()
    
    # Commands to check (command:friendly_name)
    # These are distro-agnostic - we check for the command, not the package
    # ALL dependencies are required — optional features still need their tools
    # installed to avoid user confusion when things silently don't work.
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
        "awww-daemon:awww"
        "hyprpicker:hyprpicker"
        "playerctl:playerctl"
        "notify-send:libnotify"
        "flock:util-linux"
        "go:go"
        "wlsunset:wlsunset"
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
    
    if [[ ${#missing[@]} -eq 0 ]]; then
        doctor_missing_deps=()
        doctor_pass "All dependencies available"
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

check_repo_checkout_state() {
    local installed_strategy
    installed_strategy="$(get_installed_update_strategy)"

    if [[ "$installed_strategy" == "package-manager" ]]; then
        doctor_pass "Repo checkout state not required for package-managed installs"
        return 0
    fi

    if [[ ! -d "${REPO_ROOT}/.git" ]]; then
        doctor_fail "Repo checkout is missing git metadata"
        echo -e "    ${STY_FAINT}Run setup from a real iNiR checkout, not a random copy${STY_RST}"
        return 1
    fi

    local branch tracked_branch update_rc=0
    branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
    tracked_branch="$(get_update_tracking_branch 2>/dev/null || echo "main")"

    if [[ "$branch" == "HEAD" ]]; then
        doctor_fail "Repo checkout is detached HEAD"
        echo -e "    ${STY_FAINT}setup update cannot pull automatically until you check out a branch${STY_RST}"
        return 1
    fi

    if declare -F check_remote_updates >/dev/null 2>&1; then
        check_remote_updates || update_rc=$?
        case "$update_rc" in
            0)
                doctor_pass "Repo checkout behind origin/${tracked_branch} (update available)"
                echo -e "    ${STY_FAINT}Run: ./setup update${STY_RST}"
                ;;
            1)
                doctor_pass "Repo checkout tracks origin/${tracked_branch}"
                ;;
            2)
                doctor_pass "Repo remote check skipped"
                ;;
            3)
                doctor_pass "Repo checkout has local commits ahead of origin/${tracked_branch}"
                ;;
            4)
                doctor_fail "Repo checkout diverged from origin/${tracked_branch}"
                echo -e "    ${STY_FAINT}If that rewrite was intentional, realign manually before updating${STY_RST}"
                ;;
        esac
    else
        doctor_pass "Repo remote check unavailable in this context"
    fi

    if [[ "$branch" != "main" && "$branch" != "master" ]]; then
        tui_warn "Tracking non-release branch: ${branch}"
    fi
}

check_launcher_health() {
    local installed_strategy
    installed_strategy="$(get_installed_update_strategy)"

    local launcher_cmd expected_launcher repo_launcher runtime_launcher
    launcher_cmd="$(command -v inir 2>/dev/null || true)"
    expected_launcher="${XDG_BIN_HOME}/inir"
    repo_launcher="${REPO_ROOT}/scripts/inir"
    runtime_launcher="$(doctor_runtime_dir 2>/dev/null)/scripts/inir"

    if [[ "$installed_strategy" == "package-manager" ]]; then
        if [[ -n "$launcher_cmd" ]]; then
            doctor_pass "Launcher available"
        else
            doctor_fail "inir launcher not found in PATH"
            echo -e "    ${STY_FAINT}Run the package install flow again, or install the launcher manually${STY_RST}"
        fi
        return 0
    fi

    if [[ ! -f "$repo_launcher" ]]; then
        if [[ -n "$launcher_cmd" || -x "$runtime_launcher" ]]; then
            doctor_pass "Launcher available"
        else
            doctor_fail "Launcher missing"
        fi
        return 0
    fi

    if [[ ! -x "$expected_launcher" ]]; then
        if declare -F sync_launcher_from_repo >/dev/null 2>&1; then
            sync_launcher_from_repo >/dev/null 2>&1 || true
        fi
        if [[ -x "$expected_launcher" ]]; then
            doctor_fix "Installed launcher to ${expected_launcher}"
        else
            doctor_fail "Launcher missing: ${expected_launcher}"
            echo -e "    ${STY_FAINT}Run: ./setup install${STY_RST}"
            return 1
        fi
    fi

    if ! cmp -s "$repo_launcher" "$expected_launcher" 2>/dev/null; then
        if declare -F sync_launcher_from_repo >/dev/null 2>&1; then
            sync_launcher_from_repo >/dev/null 2>&1 || true
        fi
        if cmp -s "$repo_launcher" "$expected_launcher" 2>/dev/null; then
            doctor_fix "Refreshed launcher from repo"
        else
            doctor_fail "Launcher content differs from repo"
            echo -e "    ${STY_FAINT}Expected: ${expected_launcher}${STY_RST}"
            return 1
        fi
    fi

    if [[ -z "$launcher_cmd" ]]; then
        doctor_fail "Launcher not in PATH"
        echo -e "    ${STY_FAINT}Installed launcher exists at ${expected_launcher}${STY_RST}"
        return 1
    fi

    local launcher_real
    launcher_real="$(readlink -f "$launcher_cmd" 2>/dev/null || printf '%s' "$launcher_cmd")"
    if ! cmp -s "$repo_launcher" "$launcher_real" 2>/dev/null; then
        doctor_fail "PATH resolves an outdated launcher: ${launcher_cmd}"
        echo -e "    ${STY_FAINT}Expected launcher content from ${repo_launcher}${STY_RST}"
        return 1
    fi

    doctor_pass "Launcher current"
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
        "Gabarito:Gabarito:important"
    )

    local optional_fonts=(
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
                "Gabarito")
                    _try_install_font_package "ttf-gabarito" "Gabarito" && ((fixed++)) || true ;;
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

check_service_unit_health() {
    if ! command -v systemctl >/dev/null 2>&1; then
        doctor_pass "User service checks skipped (systemctl missing)"
        return 0
    fi

    local installed_strategy service_path expected_target
    installed_strategy="$(get_installed_update_strategy)"
    service_path="${XDG_CONFIG_HOME}/systemd/user/inir.service"
    expected_target="$(doctor_detect_compositor_service 2>/dev/null || true)"

    if [[ ! -f "$service_path" ]]; then
        if [[ "$installed_strategy" == "package-manager" ]]; then
            doctor_pass "User service not installed"
        else
            doctor_fail "User inir.service missing"
            echo -e "    ${STY_FAINT}Run: inir service install${STY_RST}"
        fi
        return 0
    fi

    if [[ "$installed_strategy" != "package-manager" ]] && declare -F sync_user_inir_service_from_repo_if_present >/dev/null 2>&1; then
        if sync_user_inir_service_from_repo_if_present >/dev/null 2>&1; then
            doctor_fix "Refreshed user inir.service from repo"
        fi
    fi

    local kill_mode fragment_path
    kill_mode="$(systemctl --user show -p KillMode inir.service 2>/dev/null | cut -d= -f2)"
    fragment_path="$(systemctl --user show -p FragmentPath inir.service 2>/dev/null | cut -d= -f2)"

    if [[ -n "$kill_mode" && "$kill_mode" != "process" ]]; then
        doctor_fail "inir.service KillMode is '${kill_mode}'"
        echo -e "    ${STY_FAINT}Run: inir service install${STY_RST}"
    else
        doctor_pass "User service file present"
    fi

    if [[ -n "$fragment_path" && "$fragment_path" != "$service_path" ]]; then
        tui_warn "systemd is loading inir.service from ${fragment_path}"
    fi

    local has_expected_link=false
    local stale_links=()
    local wants_dir
    for wants_dir in "${XDG_CONFIG_HOME}/systemd/user"/*.wants; do
        [[ -d "$wants_dir" ]] || continue
        [[ -e "$wants_dir/inir.service" || -L "$wants_dir/inir.service" ]] || continue
        local target_name
        target_name="$(basename "${wants_dir%.wants}")"
        if [[ -n "$expected_target" && "$target_name" == "$expected_target" ]]; then
            has_expected_link=true
        else
            stale_links+=("$target_name")
        fi
    done

    if [[ -n "$expected_target" && "$has_expected_link" == false ]]; then
        if [[ "$installed_strategy" != "package-manager" ]] && declare -F ensure_user_inir_service_enabled >/dev/null 2>&1 && ensure_user_inir_service_enabled >/dev/null 2>&1; then
            doctor_fix "Enabled inir.service for ${expected_target}"
        else
            doctor_fail "inir.service not wired to ${expected_target}"
            echo -e "    ${STY_FAINT}Run: inir service enable${STY_RST}"
        fi
    fi

    if [[ ${#stale_links[@]} -gt 0 ]]; then
        doctor_fail "Stale service links found: ${stale_links[*]}"
        echo -e "    ${STY_FAINT}Run: inir service disable && inir service enable${STY_RST}"
    fi

    if [[ -z "$expected_target" ]]; then
        tui_warn "No supported compositor service detected for enablement wiring"
    fi
}

check_stale_local_quickshell() {
    # Detect a stale quickshell binary in ~/.local/bin or /usr/local/bin that
    # shadows the system package. This is the #1 cause of "qs --version always
    # reports 0.2" even after the system package was updated.
    local qs_path
    qs_path="$(command -v qs 2>/dev/null || true)"
    [[ -z "$qs_path" ]] && { doctor_pass "No stale local quickshell"; return 0; }

    local qs_real
    qs_real="$(readlink -f "$qs_path" 2>/dev/null || printf '%s' "$qs_path")"

    # Only flag local builds
    case "$qs_real" in
        "$HOME"/.local/bin/*|/usr/local/bin/*) ;;
        *) doctor_pass "No stale local quickshell"; return 0 ;;
    esac

    # Check if a system quickshell also exists
    local system_qs=""
    if [[ -x /usr/bin/qs ]]; then
        system_qs="/usr/bin/qs"
    elif [[ -x /usr/bin/quickshell ]]; then
        system_qs="/usr/bin/quickshell"
    fi
    [[ -z "$system_qs" ]] && { doctor_pass "No stale local quickshell"; return 0; }

    # Compare versions
    if command -v strings >/dev/null 2>&1; then
        local local_ver system_ver
        local_ver="$(strings "$qs_real" 2>/dev/null | grep -oP '\b0\.\d+\.\d+\b' | head -1 || true)"
        system_ver="$(strings "$system_qs" 2>/dev/null | grep -oP '\b0\.\d+\.\d+\b' | head -1 || true)"
        if [[ -n "$local_ver" && -n "$system_ver" && "$local_ver" != "$system_ver" ]]; then
            doctor_fail "Stale local quickshell shadows system package"
            echo -e "  ${STY_YELLOW}Local:  $qs_real ($local_ver)${STY_RST}"
            echo -e "  ${STY_YELLOW}System: $system_qs ($system_ver)${STY_RST}"
            echo -e "  ${STY_FAINT}Fix: rm $qs_real${STY_RST}"
            if [[ -L "$qs_path" && "$qs_path" != "$qs_real" ]]; then
                echo -e "  ${STY_FAINT}Also: rm $qs_path${STY_RST}"
            fi
            return 1
        fi
    fi

    doctor_pass "No stale local quickshell"
}

# Pure ABI detection: returns 0 if compatible, 1 if mismatch.
# Sets globals: _doctor_abi_msg, _doctor_abi_buildtime, _doctor_abi_runtime
_doctor_abi_detect() {
    _doctor_abi_msg=""
    _doctor_abi_buildtime=""
    _doctor_abi_runtime=""

    if ! command -v qs >/dev/null 2>&1; then
        return 0
    fi

    local qs_stderr qs_combined mismatch_detected mismatch_msg
    # Use timeout + offscreen platform to prevent hangs when Qt tries to
    # initialize display plugins (Wayland/X11) during --version. Some systems
    # block indefinitely waiting for a display server that may not respond.
    qs_stderr="$(timeout 5 env QT_QPA_PLATFORM=offscreen qs --version 2>&1 >/dev/null || true)"
    qs_combined="$(timeout 5 env QT_QPA_PLATFORM=offscreen qs --version 2>&1 || true)"

    mismatch_detected=false
    mismatch_msg=""

    if echo "$qs_stderr" | grep -qiE "built against Qt|Qt.*mismatch|incompatible Qt"; then
        mismatch_detected=true
        mismatch_msg="$(echo "$qs_stderr" | grep -iE "built against Qt|Qt.*mismatch|incompatible Qt" | head -1)"
    elif echo "$qs_combined" | grep -qiE "built against Qt|Qt.*mismatch|incompatible Qt"; then
        mismatch_detected=true
        mismatch_msg="$(echo "$qs_combined" | grep -iE "built against Qt|Qt.*mismatch|incompatible Qt" | head -1)"
    fi

    if ! $mismatch_detected; then
        local qs_path buildtime_qt runtime_qt
        qs_path="$(command -v qs 2>/dev/null || true)"
        if [[ -n "$qs_path" ]]; then
            if command -v strings >/dev/null 2>&1; then
                buildtime_qt="$(strings "$qs_path" 2>/dev/null | grep -P '^6\.\d+\.\d+$' | head -1 || true)"
            fi
            if [[ -L /usr/lib/libQt6Core.so.6 ]]; then
                runtime_qt="$(readlink -f /usr/lib/libQt6Core.so.6 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+$' || true)"
            fi
            if [[ -z "$runtime_qt" ]] && command -v pkg-config >/dev/null 2>&1; then
                runtime_qt="$(pkg-config --modversion Qt6Core 2>/dev/null || true)"
            fi
            if [[ -n "$buildtime_qt" && -n "$runtime_qt" && "$buildtime_qt" != "$runtime_qt" ]]; then
                mismatch_detected=true
                mismatch_msg="Quickshell built against Qt $buildtime_qt but system has Qt $runtime_qt"
            fi
            _doctor_abi_buildtime="$buildtime_qt"
            _doctor_abi_runtime="$runtime_qt"
        fi
    fi

    if $mismatch_detected; then
        _doctor_abi_msg="$mismatch_msg"
        return 1
    fi
    return 0
}

# Pure rebuild command computation: echoes the command or nothing.
_doctor_abi_rebuild_cmd() {
    local install_kind="unknown" install_pkg="" rebuild_helper=""

    if command -v pacman >/dev/null 2>&1; then
        if pacman -Qi quickshell-bin &>/dev/null; then
            install_kind="arch-aur-bin"; install_pkg="quickshell-bin"
        elif pacman -Qi quickshell-git &>/dev/null; then
            install_pkg="quickshell-git"
            if pacman -Qm quickshell-git &>/dev/null; then
                install_kind="arch-aur-foreign"
            else
                install_kind="arch-repo-binary"
            fi
        elif pacman -Qi quickshell &>/dev/null; then
            install_pkg="quickshell"
            if pacman -Qm quickshell &>/dev/null; then
                install_kind="arch-aur-foreign"
            else
                install_kind="arch-repo-official"
            fi
        fi
    elif command -v rpm >/dev/null 2>&1; then
        local rpm_q
        rpm_q="$(rpm -qa 2>/dev/null | grep -E '^quickshell(-git)?-[0-9]' | head -1)"
        if [[ -n "$rpm_q" ]]; then
            install_kind="fedora-pkg"
            install_pkg="${rpm_q%%-[0-9]*}"
        fi
    elif [[ -d /etc/nixos ]] || [[ -L /run/current-system ]]; then
        install_kind="nixos"; install_pkg="quickshell"
    elif command -v dpkg >/dev/null 2>&1 && dpkg -s quickshell &>/dev/null; then
        install_kind="debian"; install_pkg="quickshell"
    elif [[ -x /usr/local/bin/quickshell || -x /usr/local/bin/qs ]]; then
        install_kind="source"
    fi

    if [[ "$install_kind" == arch-* ]]; then
        for h in paru yay; do
            if command -v "$h" >/dev/null 2>&1; then
                rebuild_helper="$h"; break
            fi
        done
    fi

    case "$install_kind" in
        arch-aur-foreign)
            if [[ -n "$rebuild_helper" ]]; then
                printf '%s -S --rebuild --noconfirm %s' "$rebuild_helper" "$install_pkg"
            fi
            ;;
        arch-repo-binary)
            if [[ -n "$rebuild_helper" ]]; then
                printf '%s -Sa --noconfirm --skipreview %s' "$rebuild_helper" "$install_pkg"
            fi
            ;;
        arch-repo-official)
            # pacman -Syu only works if the repo already has a fresh rebuild.
            # Most of the time it doesn't — switch to AUR quickshell-git for immediate fix.
            if [[ -n "$rebuild_helper" ]]; then
                printf 'sudo pacman -Rdd --noconfirm quickshell && %s -S --noconfirm quickshell-git' "$rebuild_helper"
            else
                printf 'sudo pacman -Syu'
            fi
            ;;
        arch-aur-bin)
            if [[ -n "$rebuild_helper" ]]; then
                printf '%s -Rdd --noconfirm quickshell-bin && %s -Sa --noconfirm --skipreview quickshell-git' "$rebuild_helper" "$rebuild_helper"
            fi
            ;;
        fedora-pkg)
            printf 'sudo dnf upgrade --refresh %s' "$install_pkg"
            ;;
        nixos)
            printf 'sudo nixos-rebuild switch --upgrade'
            ;;
    esac
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

    if _doctor_abi_detect; then
        doctor_pass "Quickshell/Qt ABI compatible"
        return 0
    fi

    doctor_fail "Qt/Quickshell ABI mismatch: $_doctor_abi_msg"
    echo -e "  ${STY_YELLOW}Quickshell uses Qt private APIs that break on every Qt update.${STY_RST}"
    echo -e "  ${STY_YELLOW}The shell will crash on any UI interaction until quickshell is rebuilt.${STY_RST}"

    local _rebuild_cmd
    _rebuild_cmd="$(_doctor_abi_rebuild_cmd)"
    if [[ -n "$_rebuild_cmd" ]]; then
        echo -e "  ${STY_YELLOW}To fix: ${_rebuild_cmd//--noconfirm /}${STY_RST}"
        echo -e "  ${STY_FAINT}Or run: inir doctor --fix-abi${STY_RST}"
    else
        echo -e "  ${STY_YELLOW}No automatic fix available for this install type.${STY_RST}"
        echo -e "  ${STY_FAINT}See: https://quickshell.org/docs/master/guide/install-setup${STY_RST}"
    fi
    return 1
}

check_quickshell_loads() {
    local target
    local running_output
    target="$(doctor_runtime_dir)"
    if [[ -z "$target" ]]; then
        doctor_runtime_dir_or_fail "Quickshell"
        return 0
    fi

    # Resolve symlinks — Quickshell stores the real path internally, so
    # `qs -p <symlink>` won't match the running instance.
    target="$(readlink -f "$target")"

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

check_conflicting_shells() {
    # Quickshell-based shells that conflict with iNiR at the package level.
    # These provide/replace quickshell or own overlapping config paths.
    local shell_pkgs=(
        "cachyos-niri-noctalia"
        "noctalia-shell"
        "noctalia-qs"
        "noctalia-qs-git"
        "dms-shell"
        "dms-shell-git"
        "caelestia-shell"
        "caelestia-shell-git"
        "bms-shell-bin"
    )
    local found=()

    if ! command -v pacman &>/dev/null; then
        doctor_pass "Conflicting shells (not Arch, skipped)"
        return 0
    fi

    for pkg in "${shell_pkgs[@]}"; do
        pacman -Qi "$pkg" &>/dev/null 2>&1 && found+=("$pkg")
    done

    if [[ ${#found[@]} -gt 0 ]]; then
        doctor_fail "Conflicting Quickshell shells installed: ${found[*]}"
        echo -e "    ${STY_FAINT}These must be removed for iNiR to work. Run: ./setup install${STY_RST}"
    else
        doctor_pass "No conflicting Quickshell shells"
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

    # Check kde-cli-tools when QT_QPA_PLATFORMTHEME=kde
    # Without it, Dolphin "Open With" and other KDE dialogs fail silently
    if $plugin_found; then
        if command -v keditfiletype &>/dev/null || command -v keditfiletype6 &>/dev/null; then
            doctor_pass "kde-cli-tools OK"
        else
            doctor_fail "kde-cli-tools not installed (Dolphin 'Open With' dialog won't work)"
            case "${OS_GROUP_ID:-unknown}" in
                arch) echo -e "    ${STY_FAINT}Run: sudo pacman -S kde-cli-tools${STY_RST}" ;;
                fedora) echo -e "    ${STY_FAINT}Run: sudo dnf install kde-cli-tools${STY_RST}" ;;
                debian|ubuntu) echo -e "    ${STY_FAINT}Run: sudo apt install kde-cli-tools${STY_RST}" ;;
                opensuse) echo -e "    ${STY_FAINT}Run: sudo zypper install kde-cli-tools6${STY_RST}" ;;
                *) echo -e "    ${STY_FAINT}Install kde-cli-tools using your package manager${STY_RST}" ;;
            esac
        fi
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

# Run a doctor check as an animated step. Output is buffered while the
# spinner runs. Single-result steps show the result inline on the step
# line; multi-result steps expand details below.
_doctor_run_step() {
    local step="$1" total="$2" desc="$3"; shift 3
    local tmpfile pre_failed pre_fixed
    tmpfile=$(mktemp)
    pre_failed=$doctor_failed
    pre_fixed=$doctor_fixed

    tui_step_start "$step" "$total" "$desc"
    "$@" > "$tmpfile" 2>&1

    local new_fails=$((doctor_failed - pre_failed))
    local new_fixes=$((doctor_fixed - pre_fixed))

    # Count non-empty output lines
    local lines=0
    [[ -s "$tmpfile" ]] && lines=$(grep -c '.' "$tmpfile" 2>/dev/null || true)

    # For single-result steps, extract the message for inline display
    local msg=""
    if [[ $lines -eq 1 ]]; then
        msg=$(sed 's/\x1b\[[0-9;]*m//g; s/^[[:space:]]*//; s/^[✓✗⚠→] //' "$tmpfile")
    fi

    if [[ $new_fails -gt 0 ]]; then
        tui_step_fail "${msg:-$desc}"
    elif [[ $new_fixes -gt 0 ]]; then
        tui_step_warn "${msg:-Fixed: $desc}"
    else
        tui_step_done "${msg:-$desc}"
    fi

    # Expand details for multi-result steps
    (( lines > 1 )) && sed 's/^/  /' "$tmpfile"
    rm -f "$tmpfile"
}

run_doctor_with_fixes() {
    local total_steps=23
    local doctor_started_at=$SECONDS
    doctor_passed=0
    doctor_failed=0
    doctor_fixed=0

    # Step 1: Dependencies (special — may trigger interactive install)
    _doctor_run_step 1 $total_steps "Checking dependencies" check_dependencies

    if [[ ${#doctor_missing_deps[@]} -gt 0 ]]; then
        detect_distro
        case "$OS_GROUP_ID" in
            arch|fedora|debian|ubuntu)
                if ! $ask || tui_confirm "Install missing dependencies now?"; then
                    SKIP_SYSUPDATE=true
                    ONLY_MISSING_DEPS="${doctor_missing_deps[*]}"
                    source ./sdata/subcmd-install/1.deps-router.sh
                    # Re-check after install
                    doctor_passed=0; doctor_failed=0; doctor_fixed=0
                    _doctor_run_step 1 $total_steps "Re-checking dependencies" check_dependencies
                fi
                ;;
            *)
                echo -e "  ${STY_YELLOW}Automatic install not available for ${OS_GROUP_ID}. Install manually.${STY_RST}"
                ;;
        esac
    fi

    _doctor_run_step 2  $total_steps "Checking fonts"                check_fonts
    _doctor_run_step 3  $total_steps "Checking repo checkout"        check_repo_checkout_state
    _doctor_run_step 4  $total_steps "Checking critical files"       check_critical_files
    _doctor_run_step 5  $total_steps "Checking script permissions"   check_script_permissions
    _doctor_run_step 6  $total_steps "Checking launcher"             check_launcher_health
    _doctor_run_step 7  $total_steps "Checking user config"          check_user_config
    _doctor_run_step 8  $total_steps "Checking state directories"    check_state_directories
    _doctor_run_step 9  $total_steps "Checking version tracking"     check_version_tracking
    _doctor_run_step 10 $total_steps "Checking file manifest"        check_manifest
    _doctor_run_step 11 $total_steps "Checking user service"         check_service_unit_health
    _doctor_run_step 12 $total_steps "Checking Niri compositor"      check_niri_running
    _doctor_run_step 13 $total_steps "Checking Python packages"      check_python_packages
    _doctor_run_step 14 $total_steps "Checking stale local quickshell" check_stale_local_quickshell

    # Step 15 pre-check: detect ABI mismatch and offer a visible rebuild.
    # We do this OUTSIDE _doctor_run_step so the rebuild gets live TTY feedback
    # instead of being swallowed by the tempfile capture.
    if ! _doctor_abi_detect; then
        echo ""
        tui_error "Qt/Quickshell ABI mismatch detected"
        echo -e "  ${STY_YELLOW}$_doctor_abi_msg${STY_RST}"
        echo -e "  ${STY_YELLOW}Quickshell will crash on any UI interaction until rebuilt.${STY_RST}"

        local _rebuild_cmd
        _rebuild_cmd="$(_doctor_abi_rebuild_cmd)"
        if [[ -n "$_rebuild_cmd" ]] && $ask && [[ -t 0 && -t 1 ]]; then
            echo ""
            if tui_confirm "Rebuild quickshell to fix the ABI mismatch?"; then
                echo ""
                echo -e "  ${STY_FAINT}Rebuilding quickshell against the current Qt version...${STY_RST}"
                echo -e "  ${STY_FAINT}(This may take 2-5 minutes. timeout: 15 minutes)${STY_RST}"
                echo ""

                # Cache sudo credentials so the rebuild doesn't hang on a hidden prompt
                local _sudo_ok=true
                if [[ "$_rebuild_cmd" == *"sudo"* ]] || [[ "$_rebuild_cmd" == *"pacman"* ]] || [[ "$_rebuild_cmd" == *"dnf"* ]]; then
                    echo ""
                    echo -e "  ${STY_YELLOW}The rebuild requires sudo privileges.${STY_RST}"
                    echo -e "  ${STY_FAINT}If prompted, enter your sudo password below.${STY_RST}"
                    echo -e "  ${STY_FAINT}(timeout: 60 seconds)${STY_RST}"
                    echo ""
                    if ! timeout 60 sudo -v; then
                        echo -e "  ${STY_RED}Sudo authentication timed out or failed.${STY_RST}"
                        echo -e "  ${STY_YELLOW}Skipping automatic rebuild.${STY_RST}"
                        echo -e "  ${STY_FAINT}You can run manually: ${_rebuild_cmd//--noconfirm/}${STY_RST}"
                        _sudo_ok=false
                    fi
                fi

                if $_sudo_ok; then
                    local _rebuild_rc=0
                    if command -v timeout >/dev/null 2>&1; then
                        timeout 15m bash -c "${_rebuild_cmd//--noconfirm/}" || _rebuild_rc=$?
                    else
                        eval "${_rebuild_cmd//--noconfirm/}" || _rebuild_rc=$?
                    fi

                    if [[ $_rebuild_rc -eq 124 ]]; then
                        echo ""
                        echo -e "  ${STY_RED}Rebuild timed out after 15 minutes.${STY_RST}"
                    elif [[ $_rebuild_rc -ne 0 ]]; then
                        echo ""
                        echo -e "  ${STY_RED}Rebuild failed (exit $_rebuild_rc).${STY_RST}"
                    else
                        rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/inir/abi-check" 2>/dev/null
                        if _doctor_abi_detect; then
                            echo ""
                            echo -e "  ${STY_GREEN}Quickshell rebuilt successfully. ABI mismatch resolved.${STY_RST}"
                            doctor_fixed=$((doctor_fixed + 1))
                        else
                            echo ""
                            echo -e "  ${STY_YELLOW}Rebuild finished but mismatch persists.${STY_RST}"
                            echo -e "  ${STY_FAINT}A stale local binary may be shadowing the system package.${STY_RST}"
                        fi
                    fi
                fi
            fi
        fi
        echo ""
    fi

    _doctor_run_step 15 $total_steps "Checking Quickshell/Qt ABI"    check_quickshell_abi
    _doctor_run_step 16 $total_steps "Checking Quickshell"           check_quickshell_loads
    _doctor_run_step 17 $total_steps "Checking theme colors"         check_matugen_colors
    _doctor_run_step 18 $total_steps "Checking Qt theming"           check_qt_theming
    _doctor_run_step 19 $total_steps "Checking conflicting services" check_conflicting_services
    _doctor_run_step 20 $total_steps "Checking conflicting shells"   check_conflicting_shells
    _doctor_run_step 21 $total_steps "Checking wallpaper health"     check_wallpaper_health
    _doctor_run_step 22 $total_steps "Checking environment variables" check_environment_vars
    _doctor_run_step 23 $total_steps "Checking Niri config"          check_niri_config

    echo ""
    tui_divider
    echo ""

    # Summary
    tui_title "Summary"
    echo ""
    tui_badge_row \
        "Passed" "$doctor_passed" "success" \
        "Fixed" "$doctor_fixed" "warning" \
        "Failed" "$doctor_failed" "error" \
        "Time" "$(tui_elapsed "$doctor_started_at")" "muted"

    echo ""
    if [[ $doctor_failed -gt 0 ]]; then
        tui_error "Some issues need manual attention."
        tui_info "Start with: ./setup status"
        tui_info "Then read logs: inir logs"
        return 1
    elif [[ $doctor_fixed -gt 0 ]]; then
        tui_success "All issues fixed automatically."
        tui_info "Restart the shell to apply: inir restart"
    else
        tui_success "Everything looks good!"
    fi
}

# Legacy function name for compatibility
run_doctor() {
    run_doctor_with_fixes
}
