# Robust update system for iNiR
# This script is meant to be sourced.

# shellcheck shell=bash

#####################################################################################
# Configuration
#####################################################################################
II_TARGET="${XDG_CONFIG_HOME}/quickshell/inir"
II_BACKUP_DIR="${XDG_STATE_HOME}/quickshell/backups"
II_MANIFEST_FILE="${II_TARGET}/.inir-manifest"

#####################################################################################
# Manifest Management
#####################################################################################

# Generate manifest of all files that should exist in the installation
# v2 format includes checksums for code files to detect user modifications
generate_manifest() {
    local repo_root="$1"
    local manifest_file="$2"
    local commit
    commit=$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    local entries
    entries=$(mktemp) || return
    if ! python3 "$repo_root/sdata/lib/runtime-payload.py" manifest --root "$repo_root" > "$entries"; then
        rm -f "$entries"
        return 1
    fi
    {
        echo "# inir-manifest v2"
        echo "# generated: $(date -Iseconds)"
        echo "# commit: $commit"
        cat "$entries"
    } > "$manifest_file"
    local result=$?
    rm -f "$entries"
    return "$result"
}

# Get list of files that exist in target but not in manifest (orphans)
# Handles both v1 (path only) and v2 (path:checksum) manifest formats
get_orphan_files() {
    local target_dir="$1"
    local manifest_file="$2"
    local runtime_root_manifest="${REPO_ROOT}/sdata/runtime-root-files.txt"
    local runtime_dirs_manifest="${REPO_ROOT}/sdata/runtime-payload-dirs.txt"

    if [[ ! -f "$manifest_file" ]]; then
        return 0
    fi

    # Get current files in target (excluding hidden, backups, and non-tracked dirs)
    local current_files
    current_files=$(mktemp) || return

    if ! (
      set -o pipefail
      {
        # Root QML files
        find "$target_dir" -maxdepth 1 -name "*.qml" -type f -printf "%f\n" 2>/dev/null

        if [[ -f "$runtime_root_manifest" ]]; then
            while IFS= read -r runtime_file; do
                [[ -n "$runtime_file" ]] || continue
                [[ -f "$target_dir/$runtime_file" ]] && echo "$runtime_file"
            done < "$runtime_root_manifest"
        fi

        if [[ -f "$runtime_dirs_manifest" ]]; then
            while IFS= read -r dir; do
                [[ -n "$dir" ]] || continue
                if [[ -d "$target_dir/$dir" ]]; then
                    find "$target_dir/$dir" -type f ! -name 'AGENTS.md' -printf "$dir/%P\n" 2>/dev/null
                fi
            done < "$runtime_dirs_manifest"
        fi

    } | python3 "$REPO_ROOT/sdata/lib/runtime-payload.py" filter-installed --root "$REPO_ROOT" | sort -u > "$current_files"
    ); then
        rm -f "$current_files"
        return 1
    fi

    # Extract just paths from manifest (handles both v1 and v2 formats)
    local manifest_paths
    manifest_paths=$(mktemp)
    grep -v "^#" "$manifest_file" | cut -d: -f1 | sort -u > "$manifest_paths"

    # Find files in current but not in manifest
    comm -23 "$current_files" "$manifest_paths"

    rm -f "$current_files" "$manifest_paths"
}

#####################################################################################
#####################################################################################

create_update_backup() {
    local target_dir="$1"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_path="${II_BACKUP_DIR}/pre-update-${timestamp}"

    mkdir -p "$backup_path"

    # Only backup QML code, not user configs
    rsync -a --exclude='.inir-manifest' "$target_dir/" "$backup_path/" 2>/dev/null

    echo "$backup_path" > "${II_BACKUP_DIR}/.last-backup"
    cleanup_old_backups "$II_BACKUP_DIR" 5

    echo "$backup_path"
}

cleanup_old_backups() {
    local backup_dir="$1"
    local keep_count="${2:-5}"
    local old
    [[ -d "$backup_dir" ]] || return 0
    ls -1dt "$backup_dir"/pre-update-* 2>/dev/null | tail -n +$((keep_count + 1)) | while IFS= read -r old; do
        rm -rf "$old"
    done
}

#####################################################################################
# Verification
#####################################################################################

# Restart inir.service and confirm from its own log that the new files loaded: 0 loaded, 1 failed (errors printed), 2 not confirmed.
# Quickshell 0.3 logs "Configuration Loaded", or "Failed to load configuration" followed by "error in …" / "caused by …" lines.
# The service owns the shell: it is never killed by hand or started twice (KillMode=process keeps this script alive).
restart_shell_and_verify() {
    local timeout="${1:-30}" since out deadline
    command -v systemctl >/dev/null 2>&1 && systemctl --user cat inir.service >/dev/null 2>&1 || return 2
    since=$(date +%s)
    systemctl --user restart inir.service >/dev/null 2>&1 || return 2
    command -v journalctl >/dev/null 2>&1 || return 2
    deadline=$((SECONDS + timeout))
    while (( SECONDS < deadline )); do
        out=$(journalctl --user -u inir.service --since "@${since}" -o cat --no-pager 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')
        if grep -q "Failed to load configuration" <<<"$out"; then
            grep -E "(error in|caused by) " <<<"$out" | sed 's/^[[:space:]]*[A-Z]*:[[:space:]]*/  /' | head -5
            return 1
        fi
        grep -q "Configuration Loaded" <<<"$out" && return 0
        sleep 1
    done
    return 2
}

#####################################################################################
# Orphan Cleanup
#####################################################################################

# Remove orphan files (files that no longer exist in repo)
cleanup_orphans() {
    local target_dir="$1"
    local manifest_file="$2"
    local dry_run="${3:-false}"

    local orphans
    orphans=$(get_orphan_files "$target_dir" "$manifest_file") || return 1

    if [[ -z "$orphans" ]]; then
        log_info "No orphan files found"
        return 0
    fi

    local count
    count=$(echo "$orphans" | wc -l)

    if [[ "$dry_run" == "true" ]]; then
        log_info "Would remove $count orphan file(s):"
        echo "$orphans" | while read -r file; do
            echo "  - $file"
        done
    else
        log_info "Removing $count orphan file(s)..."
        echo "$orphans" | while read -r file; do
            local full_path="$target_dir/$file"
            if [[ -f "$full_path" ]]; then
                rm -f "$full_path"
                log_info "  Removed: $file"
            fi
        done

        # Clean up empty directories
        find "$target_dir/modules" "$target_dir/services" "$target_dir/scripts" \
            -type d -empty -delete 2>/dev/null || true
    fi

    return 0
}
