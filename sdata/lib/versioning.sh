#!/bin/bash
# Versioning system for iNiR
# Tracks installed version, compares with remote, manages updates
# This script is meant to be sourced.

# shellcheck shell=bash

#####################################################################################
# Version Configuration
#####################################################################################
XDG_CONFIG_HOME_RESOLVED="${XDG_CONFIG_HOME:-$HOME/.config}"

CONFIG_DIR_NEW="${XDG_CONFIG_HOME_RESOLVED}/inir"
CONFIG_DIR_LEGACY="${XDG_CONFIG_HOME_RESOLVED}/illogical-impulse"

if [[ -L "$CONFIG_DIR_LEGACY" && -d "$CONFIG_DIR_NEW" ]]; then
    CONFIG_DIR="$CONFIG_DIR_NEW"
elif [[ -d "$CONFIG_DIR_LEGACY" ]]; then
    CONFIG_DIR="$CONFIG_DIR_LEGACY"
elif [[ -d "$CONFIG_DIR_NEW" ]]; then
    CONFIG_DIR="$CONFIG_DIR_NEW"
else
    CONFIG_DIR="$CONFIG_DIR_NEW"
fi

RUNTIME_DIR_USER="${XDG_CONFIG_HOME_RESOLVED}/quickshell/inir"
RUNTIME_DIR_SYSTEM_LOCAL="${INIR_SYSTEM_RUNTIME_DIR_LOCAL:-/usr/local/share/quickshell/inir}"
RUNTIME_DIR_SYSTEM="${INIR_SYSTEM_RUNTIME_DIR:-/usr/share/quickshell/inir}"
LEGACY_RUNTIME_DIR_USER="${XDG_CONFIG_HOME_RESOLVED}/quickshell/ii"
LEGACY_RUNTIME_DIR_SYSTEM_LOCAL="${INIR_LEGACY_SYSTEM_RUNTIME_DIR_LOCAL:-/usr/local/share/quickshell/ii}"
LEGACY_RUNTIME_DIR_SYSTEM="${INIR_LEGACY_SYSTEM_RUNTIME_DIR:-/usr/share/quickshell/ii}"
VERSION_FILE_LOCAL="${CONFIG_DIR}/version.json"
VERSION_FILE_RUNTIME_USER="${RUNTIME_DIR_USER}/version.json"
VERSION_FILE_RUNTIME_SYSTEM_LOCAL="${RUNTIME_DIR_SYSTEM_LOCAL}/version.json"
VERSION_FILE_RUNTIME_SYSTEM="${RUNTIME_DIR_SYSTEM}/version.json"
VERSION_FILE_REPO="${REPO_ROOT}/VERSION"
CHANGELOG_FILE="${REPO_ROOT}/CHANGELOG.md"
GITHUB_REPO="snowarch/inir"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}"

# Cache for remote version checks (avoid hammering GitHub)
VERSION_CACHE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/inir/version-cache.json"
VERSION_CACHE_TTL=3600  # 1 hour in seconds

get_runtime_shell_dir() {
    local override="${INIR_RUNTIME_DIR:-}"
    if [[ -n "$override" && -f "$override/shell.qml" ]]; then
        printf '%s' "$override"
        return
    fi

    local candidate
    for candidate in "$RUNTIME_DIR_USER" "$RUNTIME_DIR_SYSTEM_LOCAL" "$RUNTIME_DIR_SYSTEM"; do
        if [[ -n "$candidate" && -f "$candidate/shell.qml" ]]; then
            printf '%s' "$candidate"
            return
        fi
    done

    for candidate in "$LEGACY_RUNTIME_DIR_USER" "$LEGACY_RUNTIME_DIR_SYSTEM_LOCAL" "$LEGACY_RUNTIME_DIR_SYSTEM"; do
        if [[ -n "$candidate" && -f "$candidate/shell.qml" ]]; then
            printf '%s' "$candidate"
            return
        fi
    done

    printf '%s' ""
}

get_runtime_version_file() {
    local runtime_dir
    runtime_dir="$(get_runtime_shell_dir)"
    if [[ -n "$runtime_dir" ]]; then
        printf '%s/version.json' "$runtime_dir"
    else
        printf '%s' ""
    fi
}

is_package_managed_version_file() {
    local version_file="$1"

    [[ -n "$version_file" && -f "$version_file" ]] || return 1

    if command -v jq &>/dev/null; then
        local mode
        mode=$(jq -r '.installMode // .install_mode // empty' "$version_file" 2>/dev/null || true)
        [[ "$mode" == "package-managed" ]]
        return
    fi

    grep -Eq '"install(M|_m)ode"[[:space:]]*:[[:space:]]*"package-managed"' "$version_file" 2>/dev/null
}

#####################################################################################
# Local Version Management
#####################################################################################

# Get current repo version from VERSION file
get_repo_version() {
    if [[ -f "$VERSION_FILE_REPO" ]]; then
        head -1 "$VERSION_FILE_REPO" | tr -d '[:space:]'
    else
        echo "0.0.0"
    fi
}

# Get current git commit hash
get_repo_commit() {
    if command -v git &>/dev/null && [[ -d "${REPO_ROOT}/.git" ]]; then
        git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Get installed version info as JSON
get_installed_version_file() {
    local runtime_version_file
    runtime_version_file="$(get_runtime_version_file)"

    if [[ -n "${INIR_RUNTIME_DIR:-}" && -f "$runtime_version_file" ]]; then
        printf '%s' "$runtime_version_file"
    elif is_package_managed_version_file "$runtime_version_file"; then
        printf '%s' "$runtime_version_file"
    elif [[ -f "$VERSION_FILE_LOCAL" ]]; then
        printf '%s' "$VERSION_FILE_LOCAL"
    elif [[ -f "$VERSION_FILE_RUNTIME_USER" ]]; then
        printf '%s' "$VERSION_FILE_RUNTIME_USER"
    elif [[ -f "$VERSION_FILE_RUNTIME_SYSTEM_LOCAL" ]]; then
        printf '%s' "$VERSION_FILE_RUNTIME_SYSTEM_LOCAL"
    elif [[ -f "$VERSION_FILE_RUNTIME_SYSTEM" ]]; then
        printf '%s' "$VERSION_FILE_RUNTIME_SYSTEM"
    else
        printf '%s' ""
    fi
}

get_installed_version_json() {
    local version_file
    version_file="$(get_installed_version_file)"
    if [[ -n "$version_file" ]]; then
        cat "$version_file"
    else
        echo '{"version":"0.0.0","commit":"unknown","installed_at":"unknown","source":"unknown"}'
    fi
}

# Get just the version string
get_installed_version() {
    # For repo-link mode the runtime IS the repo — use live VERSION file,
    # not the stale value frozen in version.json at last ./setup update.
    if [[ "$(get_installed_install_mode)" == "repo-link" ]]; then
        local runtime_dir
        runtime_dir="$(get_runtime_shell_dir)"
        if [[ -n "$runtime_dir" && -f "$runtime_dir/VERSION" ]]; then
            head -1 "$runtime_dir/VERSION" | tr -d '[:space:]'
            return
        elif [[ -f "$VERSION_FILE_REPO" ]]; then
            get_repo_version
            return
        fi
    fi

    local version_file
    local value=""
    version_file="$(get_installed_version_file)"
    if [[ -n "$version_file" ]] && command -v jq &>/dev/null; then
        value=$(jq -r '.version // empty' "$version_file" 2>/dev/null || true)
        if [[ -n "$value" && "$value" != "null" ]]; then
            printf '%s\n' "$value"
            return
        fi
    fi

    if [[ -f "${CONFIG_DIR}/version" ]]; then
        # Fallback to old format
        cat "${CONFIG_DIR}/version"
    else
        echo "0.0.0"
    fi
}

# Get installed commit hash
get_installed_commit() {
    # For repo-link mode the runtime IS the repo — use live git HEAD,
    # not the stale commit frozen in version.json at last ./setup update.
    if [[ "$(get_installed_install_mode)" == "repo-link" ]]; then
        local runtime_dir
        runtime_dir="$(get_runtime_shell_dir)"
        if [[ -n "$runtime_dir" && -d "$runtime_dir/.git" ]]; then
            git -C "$runtime_dir" rev-parse --short HEAD 2>/dev/null || echo "unknown"
            return
        elif [[ -d "${REPO_ROOT}/.git" ]]; then
            get_repo_commit
            return
        fi
    fi

    local version_file
    local value=""
    version_file="$(get_installed_version_file)"
    if [[ -n "$version_file" ]] && command -v jq &>/dev/null; then
        value=$(jq -r '.commit // empty' "$version_file" 2>/dev/null || true)
        if [[ -n "$value" && "$value" != "null" ]]; then
            printf '%s\n' "$value"
            return
        fi
    fi

    echo "unknown"
}

version_file_has_core_metadata() {
    local version_file="$1"

    [[ -n "$version_file" && -f "$version_file" ]] || return 1

    if command -v jq &>/dev/null; then
        local version_value=""
        local commit_value=""
        version_value=$(jq -r '.version // empty' "$version_file" 2>/dev/null || true)
        commit_value=$(jq -r '.commit // empty' "$version_file" 2>/dev/null || true)
        [[ -n "$version_value" && "$version_value" != "null" && -n "$commit_value" && "$commit_value" != "null" ]]
        return
    fi

    grep -Eq '"version"[[:space:]]*:[[:space:]]*"[^"]+"' "$version_file" 2>/dev/null \
        && grep -Eq '"commit"[[:space:]]*:[[:space:]]*"[^"]+"' "$version_file" 2>/dev/null
}

read_installed_version_field() {
    local expr="$1"
    local default="${2:-}"
    local version_file
    version_file="$(get_installed_version_file)"

    if [[ -n "$version_file" ]] && command -v jq &>/dev/null; then
        local value
        value=$(jq -r "(${expr}) // empty" "$version_file" 2>/dev/null || true)
        if [[ -n "$value" && "$value" != "null" ]]; then
            printf '%s' "$value"
            return
        fi
    fi

    printf '%s' "$default"
}

get_stored_repo_path() {
    read_installed_version_field '.repoPath // .repo_path' ""
}

get_installed_package_manager() {
    local stored
    stored=$(read_installed_version_field '.packageManager // .package_manager' "")
    if [[ -n "$stored" ]]; then
        printf '%s' "$stored"
        return
    fi

    if declare -F get_package_manager >/dev/null; then
        get_package_manager
        return
    fi

    if command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v rpm-ostree &>/dev/null; then
        echo "rpm-ostree"
    elif command -v apt &>/dev/null; then
        echo "apt"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    elif command -v xbps-install &>/dev/null; then
        echo "xbps"
    elif command -v emerge &>/dev/null; then
        echo "emerge"
    elif command -v nixos-rebuild &>/dev/null || command -v nix &>/dev/null; then
        echo "nix"
    elif command -v apk &>/dev/null; then
        echo "apk"
    else
        echo "unknown"
    fi
}

get_installed_package_name() {
    read_installed_version_field '.packageName // .package_name' ""
}

get_default_package_update_hint() {
    case "$(get_installed_package_manager)" in
        pacman) echo "sudo pacman -Syu" ;;
        apt) echo "sudo apt update && sudo apt upgrade" ;;
        dnf) echo "sudo dnf upgrade" ;;
        rpm-ostree) echo "rpm-ostree upgrade" ;;
        zypper) echo "sudo zypper dup" ;;
        xbps) echo "sudo xbps-install -Su" ;;
        emerge) echo "sudo emerge --sync && sudo emerge -avuDN @world" ;;
        nix) echo "nixos-rebuild switch" ;;
        apk) echo "sudo apk upgrade" ;;
        *) echo "use your package manager to update iNiR" ;;
    esac
}

get_installed_package_update_hint() {
    local stored
    stored=$(read_installed_version_field '.packageUpdateHint // .package_update_hint' "")
    if [[ -n "$stored" ]]; then
        printf '%s' "$stored"
        return
    fi

    if [[ "$(get_installed_update_strategy)" == "package-manager" ]]; then
        get_default_package_update_hint
        return
    fi

    printf '%s' ""
}

get_installed_install_mode() {
    local stored
    stored=$(read_installed_version_field '.installMode // .install_mode' "")
    if [[ -n "$stored" ]]; then
        printf '%s' "$stored"
        return
    fi

    local package_name
    package_name=$(get_installed_package_name)
    if [[ -n "$package_name" ]]; then
        echo "package-managed"
        return
    fi

    local stored_repo_path
    stored_repo_path="$(get_stored_repo_path)"

    local target
    local target_real=""
    local repo_real=""
    target="$(get_runtime_shell_dir)"
    target_real=$(realpath "$target" 2>/dev/null || printf '%s' "$target")

    if [[ -n "${REPO_ROOT:-}" ]]; then
        repo_real=$(realpath "$REPO_ROOT" 2>/dev/null || printf '%s' "$REPO_ROOT")
    fi

    if [[ -n "$repo_real" && -n "$target_real" && "$repo_real" == "$target_real" ]]; then
        echo "repo-link"
        return
    fi

    if [[ -n "$stored_repo_path" ]]; then
        echo "repo-copy"
        return
    fi

    echo "unknown"
}

get_installed_update_strategy() {
    local stored
    stored=$(read_installed_version_field '.updateStrategy // .update_strategy' "")
    if [[ -n "$stored" ]]; then
        printf '%s' "$stored"
        return
    fi

    case "$(get_installed_install_mode)" in
        repo-copy|repo-link) echo "repo-setup" ;;
        package-managed) echo "package-manager" ;;
        *) echo "unknown" ;;
    esac
}

get_installed_repo_path() {
    local stored
    stored="$(get_stored_repo_path)"
    if [[ -n "$stored" ]]; then
        printf '%s' "$stored"
        return
    fi

    printf '%s' ""
}

get_install_mode() {
    if [[ -n "${INIR_INSTALL_MODE:-}" ]]; then
        echo "$INIR_INSTALL_MODE"
        return
    fi

    local target="${XDG_CONFIG_HOME_RESOLVED}/quickshell/inir"
    local repo_real=""
    local target_real=""

    if [[ -n "${REPO_ROOT:-}" ]]; then
        repo_real=$(realpath "$REPO_ROOT" 2>/dev/null || printf '%s' "$REPO_ROOT")
    fi

    target_real=$(realpath "$target" 2>/dev/null || printf '%s' "$target")

    if [[ -n "$repo_real" && -n "$target_real" && "$repo_real" == "$target_real" ]]; then
        echo "repo-link"
        return
    fi

    if [[ -d "${REPO_ROOT:-}/.git" && -f "${REPO_ROOT:-}/setup" && -f "${REPO_ROOT:-}/shell.qml" ]]; then
        echo "repo-copy"
        return
    fi

    echo "unknown"
}

get_update_strategy() {
    if [[ -n "${INIR_UPDATE_STRATEGY:-}" ]]; then
        echo "$INIR_UPDATE_STRATEGY"
        return
    fi

    case "$(get_install_mode)" in
        repo-copy|repo-link) echo "repo-setup" ;;
        package-managed) echo "package-manager" ;;
        *) echo "unknown" ;;
    esac
}

get_version_repo_path() {
    if [[ -n "${INIR_REPO_PATH:-}" ]]; then
        printf '%s' "$INIR_REPO_PATH"
        return
    fi

    case "$(get_update_strategy)" in
        repo-setup) printf '%s' "${REPO_ROOT:-}" ;;
        *) printf '%s' "" ;;
    esac
}

write_version_info_json() {
    local file="$1"
    local version="$2"
    local commit="$3"
    local source="$4"
    local timestamp=$(date -Iseconds)
    local repo_path
    local install_mode
    local update_strategy
    local package_manager="${INIR_PACKAGE_MANAGER:-}"
    local package_name="${INIR_PACKAGE_NAME:-}"
    local package_update_hint="${INIR_PACKAGE_UPDATE_HINT:-}"

    repo_path="$(get_version_repo_path)"
    install_mode="$(get_install_mode)"
    update_strategy="$(get_update_strategy)"

    mkdir -p "$(dirname "$file")"

    if command -v jq &>/dev/null; then
        jq -n \
            --arg v "$version" \
            --arg c "$commit" \
            --arg t "$timestamp" \
            --arg s "$source" \
            --arg r "$repo_path" \
            --arg m "$install_mode" \
            --arg u "$update_strategy" \
            --arg pm "$package_manager" \
            --arg pn "$package_name" \
            --arg ph "$package_update_hint" \
            '{
                version: $v,
                commit: $c,
                installed_at: $t,
                installedAt: $t,
                source: $s,
                repo_path: $r,
                repoPath: $r,
                install_mode: $m,
                installMode: $m,
                update_strategy: $u,
                updateStrategy: $u,
                package_manager: $pm,
                packageManager: $pm,
                package_name: $pn,
                packageName: $pn,
                package_update_hint: $ph,
                packageUpdateHint: $ph
            }' > "$file"
    else
        cat > "$file" << EOF
{
  "version": "$version",
  "commit": "$commit",
  "installed_at": "$timestamp",
  "installedAt": "$timestamp",
  "source": "$source",
  "repo_path": "$repo_path",
  "repoPath": "$repo_path",
  "install_mode": "$install_mode",
  "installMode": "$install_mode",
  "update_strategy": "$update_strategy",
  "updateStrategy": "$update_strategy",
  "package_manager": "$package_manager",
  "packageManager": "$package_manager",
  "package_name": "$package_name",
  "packageName": "$package_name",
  "package_update_hint": "$package_update_hint",
  "packageUpdateHint": "$package_update_hint"
}
EOF
    fi
}

# Save installed version info
set_installed_version() {
    local version="${1:-$(get_repo_version)}"
    local commit="${2:-$(get_repo_commit)}"
    local source="${3:-git}"
    
    write_version_info_json "$VERSION_FILE_LOCAL" "$version" "$commit" "$source"

    # Also update old format for backwards compatibility
    echo "$version" > "${CONFIG_DIR}/version"
}

#####################################################################################
# Remote Version Checking
#####################################################################################

# Check if cache is still valid
is_cache_valid() {
    if [[ ! -f "$VERSION_CACHE_FILE" ]]; then
        return 1
    fi
    
    local cache_time
    if command -v jq &>/dev/null; then
        cache_time=$(jq -r '.cached_at // 0' "$VERSION_CACHE_FILE" 2>/dev/null)
    else
        return 1
    fi
    
    local now=$(date +%s)
    local age=$((now - cache_time))
    
    [[ $age -lt $VERSION_CACHE_TTL ]]
}

# Get remote version (with caching)
get_remote_version() {
    local force="${1:-false}"
    
    # Check cache first
    if [[ "$force" != "true" ]] && is_cache_valid; then
        if command -v jq &>/dev/null; then
            jq -r '.version // "unknown"' "$VERSION_CACHE_FILE"
            return 0
        fi
    fi
    
    # Fetch from GitHub
    if ! command -v curl &>/dev/null; then
        echo "unknown"
        return 1
    fi
    
    local response
    response=$(curl -sf --max-time 5 "${GITHUB_API}/releases/latest" 2>/dev/null)
    
    if [[ -n "$response" ]] && command -v jq &>/dev/null; then
        local version=$(echo "$response" | jq -r '.tag_name // "unknown"' | sed 's/^v//')
        local commit=$(echo "$response" | jq -r '.target_commitish // "unknown"')
        
        # Update cache
        mkdir -p "$(dirname "$VERSION_CACHE_FILE")"
        jq -n \
            --arg v "$version" \
            --arg c "$commit" \
            --argjson t "$(date +%s)" \
            '{version: $v, commit: $c, cached_at: $t}' > "$VERSION_CACHE_FILE"
        
        echo "$version"
        return 0
    fi
    
    # Fallback: check git remote
    if command -v git &>/dev/null && [[ -d "${REPO_ROOT}/.git" ]]; then
        git -C "$REPO_ROOT" fetch --tags --quiet 2>/dev/null
        local latest_tag=$(git -C "$REPO_ROOT" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
        if [[ -n "$latest_tag" ]]; then
            echo "$latest_tag"
            return 0
        fi
    fi
    
    echo "unknown"
    return 1
}

# Get latest commit from remote
get_remote_commit() {
    if ! command -v git &>/dev/null || [[ ! -d "${REPO_ROOT}/.git" ]]; then
        echo "unknown"
        return 1
    fi
    
    local branch=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)
    [[ -z "$branch" || "$branch" == "HEAD" ]] && branch="main"
    
    git -C "$REPO_ROOT" fetch --quiet 2>/dev/null
    git -C "$REPO_ROOT" rev-parse --short "origin/${branch}" 2>/dev/null || echo "unknown"
}

#####################################################################################
# Version Comparison
#####################################################################################

# Compare semantic versions (returns: -1, 0, 1)
compare_versions() {
    local v1="$1"
    local v2="$2"
    
    # Remove 'v' prefix if present
    v1="${v1#v}"
    v2="${v2#v}"
    
    if [[ "$v1" == "$v2" ]]; then
        echo 0
        return
    fi
    
    # Split into parts
    local IFS='.'
    read -ra V1 <<< "$v1"
    read -ra V2 <<< "$v2"
    
    for i in 0 1 2; do
        local n1="${V1[$i]:-0}"
        local n2="${V2[$i]:-0}"
        
        # Remove non-numeric suffixes for comparison
        n1="${n1%%[^0-9]*}"
        n2="${n2%%[^0-9]*}"
        
        if [[ "$n1" -lt "$n2" ]]; then
            echo -1
            return
        elif [[ "$n1" -gt "$n2" ]]; then
            echo 1
            return
        fi
    done
    
    echo 0
}

# Check if update is available
check_update_available() {
    local installed=$(get_installed_version)
    local remote=$(get_remote_version)
    local installed_commit=$(get_installed_commit)
    local remote_commit=$(get_remote_commit)
    
    # If versions differ, update available
    local cmp=$(compare_versions "$installed" "$remote")
    if [[ "$cmp" == "-1" ]]; then
        return 0  # Update available
    fi
    
    # If same version but different commit, update available
    if [[ "$installed_commit" != "unknown" && "$remote_commit" != "unknown" ]]; then
        if [[ "$installed_commit" != "$remote_commit" ]]; then
            return 0  # Update available
        fi
    fi
    
    return 1  # No update
}

#####################################################################################
# Display Functions
#####################################################################################

show_version_status() {
    local installed=$(get_installed_version)
    local installed_commit=$(get_installed_commit)
    local installed_mode=$(get_installed_install_mode)
    local installed_strategy=$(get_installed_update_strategy)
    local repo_version=$(get_repo_version)
    local repo_commit=$(get_repo_commit)
    
    echo ""
    echo -e "${STY_CYAN}${STY_BOLD}iNiR Version Status${STY_RST}"
    echo ""
    echo -e "  ${STY_BOLD}Installed:${STY_RST}  $installed (${installed_commit})"
    echo -e "  ${STY_BOLD}Mode:${STY_RST}      $installed_mode"
    echo -e "  ${STY_BOLD}Updates:${STY_RST}   $installed_strategy"

    if [[ "$installed_strategy" == "package-manager" ]]; then
        local hint
        hint=$(get_installed_package_update_hint)
        [[ -n "$hint" ]] && echo -e "  ${STY_BOLD}Command:${STY_RST}   $hint"
    elif [[ "$installed_mode" != "repo-link" ]]; then
        echo -e "  ${STY_BOLD}Repository:${STY_RST} $repo_version (${repo_commit})"
    fi
    
    # Check if local repo is ahead/behind (skip for repo-link: installed IS the repo)
    if [[ "$installed_strategy" != "package-manager" && "$installed_mode" != "repo-link" ]] && ([[ "$installed" != "$repo_version" ]] || [[ "$installed_commit" != "$repo_commit" ]]); then
        echo ""
        echo -e "  ${STY_YELLOW}→ Repository has newer version${STY_RST}"
        echo -e "  ${STY_YELLOW}  Run: ./setup update${STY_RST}"
    else
        echo ""
        echo -e "  ${STY_GREEN}✓ Up to date${STY_RST}"
    fi
    
    # Check remote (optional, may fail without network)
    if [[ "$installed_strategy" != "package-manager" ]]; then
        echo ""
        echo -e "${STY_FAINT}Checking remote...${STY_RST}"
        local remote
        remote=$(get_remote_version true 2>/dev/null) || true
        if [[ -n "$remote" && "$remote" != "unknown" ]]; then
            local cmp=$(compare_versions "$repo_version" "$remote")
            if [[ "$cmp" == "-1" ]]; then
                echo -e "  ${STY_YELLOW}${STY_BOLD}New release available:${STY_RST} v$remote"
                echo -e "  ${STY_YELLOW}Run: git pull && ./setup update${STY_RST}"
            else
                echo -e "  ${STY_GREEN}✓ Latest release: v$remote${STY_RST}"
            fi
        else
            echo -e "  ${STY_FAINT}Could not check remote (no network or no releases)${STY_RST}"
        fi
    fi
}

show_changelog() {
    local lines="${1:-20}"
    
    if [[ ! -f "$CHANGELOG_FILE" ]]; then
        echo -e "${STY_YELLOW}No changelog found.${STY_RST}"
        echo -e "Check commits: git log --oneline -20"
        return 1
    fi
    
    echo -e "${STY_CYAN}${STY_BOLD}iNiR Changelog${STY_RST}"
    echo ""
    head -n "$lines" "$CHANGELOG_FILE"
    
    local total_lines=$(wc -l < "$CHANGELOG_FILE")
    if [[ "$total_lines" -gt "$lines" ]]; then
        echo ""
        echo -e "${STY_FAINT}... showing first $lines lines. See CHANGELOG.md for full history.${STY_RST}"
    fi
}
