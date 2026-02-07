#!/bin/bash
# Versioning system for iNiR
# Tracks installed version, compares with remote, manages updates
# This script is meant to be sourced.

# shellcheck shell=bash

#####################################################################################
# Version Configuration
#####################################################################################
VERSION_FILE_LOCAL="${XDG_CONFIG_HOME}/illogical-impulse/version.json"
VERSION_FILE_REPO="${REPO_ROOT}/VERSION"
CHANGELOG_FILE="${REPO_ROOT}/CHANGELOG.md"
GITHUB_REPO="snowarch/inir"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}"

# Cache for remote version checks (avoid hammering GitHub)
VERSION_CACHE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/inir/version-cache.json"
VERSION_CACHE_TTL=3600  # 1 hour in seconds

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
get_installed_version_json() {
    if [[ -f "$VERSION_FILE_LOCAL" ]]; then
        cat "$VERSION_FILE_LOCAL"
    else
        echo '{"version":"0.0.0","commit":"unknown","installed_at":"unknown","source":"unknown"}'
    fi
}

# Get just the version string
get_installed_version() {
    if [[ -f "$VERSION_FILE_LOCAL" ]] && command -v jq &>/dev/null; then
        jq -r '.version // "0.0.0"' "$VERSION_FILE_LOCAL"
    elif [[ -f "${XDG_CONFIG_HOME}/illogical-impulse/version" ]]; then
        # Fallback to old format
        cat "${XDG_CONFIG_HOME}/illogical-impulse/version"
    else
        echo "0.0.0"
    fi
}

# Get installed commit hash
get_installed_commit() {
    if [[ -f "$VERSION_FILE_LOCAL" ]] && command -v jq &>/dev/null; then
        jq -r '.commit // "unknown"' "$VERSION_FILE_LOCAL"
    else
        echo "unknown"
    fi
}

# Save installed version info
set_installed_version() {
    local version="${1:-$(get_repo_version)}"
    local commit="${2:-$(get_repo_commit)}"
    local source="${3:-git}"
    local timestamp=$(date -Iseconds)
    local repo_path="${REPO_ROOT:-}"
    
    mkdir -p "$(dirname "$VERSION_FILE_LOCAL")"
    
    if command -v jq &>/dev/null; then
        jq -n \
            --arg v "$version" \
            --arg c "$commit" \
            --arg t "$timestamp" \
            --arg s "$source" \
            --arg r "$repo_path" \
            '{version: $v, commit: $c, installed_at: $t, source: $s, repo_path: $r}' > "$VERSION_FILE_LOCAL"
    else
        cat > "$VERSION_FILE_LOCAL" << EOF
{
  "version": "$version",
  "commit": "$commit",
  "installed_at": "$timestamp",
  "source": "$source",
  "repo_path": "$repo_path"
}
EOF
    fi
    
    # Also update old format for backwards compatibility
    echo "$version" > "${XDG_CONFIG_HOME}/illogical-impulse/version"
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
    local repo_version=$(get_repo_version)
    local repo_commit=$(get_repo_commit)
    
    echo ""
    echo -e "${STY_CYAN}${STY_BOLD}iNiR Version Status${STY_RST}"
    echo ""
    echo -e "  ${STY_BOLD}Installed:${STY_RST}  $installed (${installed_commit})"
    echo -e "  ${STY_BOLD}Repository:${STY_RST} $repo_version (${repo_commit})"
    
    # Check if local repo is ahead/behind
    if [[ "$installed" != "$repo_version" ]] || [[ "$installed_commit" != "$repo_commit" ]]; then
        echo ""
        echo -e "  ${STY_YELLOW}→ Repository has newer version${STY_RST}"
        echo -e "  ${STY_YELLOW}  Run: ./setup update${STY_RST}"
    else
        echo ""
        echo -e "  ${STY_GREEN}✓ Up to date${STY_RST}"
    fi
    
    # Check remote (optional, may fail without network)
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
