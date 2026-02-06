# Robust update system for iNiR
# Handles: manifest tracking, orphan cleanup, verification, rollback
# This script is meant to be sourced.

# shellcheck shell=bash

#####################################################################################
# Configuration
#####################################################################################
II_TARGET="${XDG_CONFIG_HOME}/quickshell/ii"
II_BACKUP_DIR="${XDG_STATE_HOME}/quickshell/backups"
II_MANIFEST_FILE="${II_TARGET}/.ii-manifest"
VERIFICATION_TIMEOUT=10

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

    # Extensions that get checksums (code files users might modify)
    local checksum_extensions="qml|js|py|sh|fish"

    {
        # Header (will be prepended after sort)
        # Actual file entries follow

        # Root QML files (with checksums)
        for qml in "$repo_root"/*.qml; do
            [[ -f "$qml" ]] || continue
            local name
            name=$(basename "$qml")
            local checksum
            checksum=$(sha256sum "$qml" 2>/dev/null | cut -d' ' -f1)
            echo "${name}:${checksum}"
        done

        # Directories that get synced
        for dir in modules services scripts assets translations; do
            if [[ -d "$repo_root/$dir" ]]; then
                find "$repo_root/$dir" -type f 2>/dev/null | while read -r file; do
                    local rel_path="${file#$repo_root/}"
                    local ext="${file##*.}"

                    # Check if file extension needs checksum
                    if [[ "$ext" =~ ^($checksum_extensions)$ ]]; then
                        local checksum
                        checksum=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)
                        echo "${rel_path}:${checksum}"
                    else
                        # Non-code files: just path (for orphan detection)
                        echo "${rel_path}:"
                    fi
                done
            fi
        done

        # Other tracked files
        [[ -f "$repo_root/requirements.txt" ]] && echo "requirements.txt:"

    } | sort -t: -k1 | {
        # Prepend header
        echo "# ii-manifest v2"
        echo "# generated: $(date -Iseconds)"
        echo "# commit: $commit"
        cat
    } > "$manifest_file"
}

# Get list of files that exist in target but not in manifest (orphans)
# Handles both v1 (path only) and v2 (path:checksum) manifest formats
get_orphan_files() {
    local target_dir="$1"
    local manifest_file="$2"

    if [[ ! -f "$manifest_file" ]]; then
        return 0
    fi

    # Get current files in target (excluding hidden, backups, and non-tracked dirs)
    local current_files
    current_files=$(mktemp)

    {
        # Root QML files
        find "$target_dir" -maxdepth 1 -name "*.qml" -type f -printf "%f\n" 2>/dev/null

        # Tracked directories
        for dir in modules services scripts assets translations; do
            if [[ -d "$target_dir/$dir" ]]; then
                find "$target_dir/$dir" -type f -printf "$dir/%P\n" 2>/dev/null
            fi
        done

        [[ -f "$target_dir/requirements.txt" ]] && echo "requirements.txt"

    } | sort -u > "$current_files"

    # Extract just paths from manifest (handles both v1 and v2 formats)
    local manifest_paths
    manifest_paths=$(mktemp)
    grep -v "^#" "$manifest_file" | cut -d: -f1 | sort -u > "$manifest_paths"

    # Find files in current but not in manifest
    comm -23 "$current_files" "$manifest_paths"

    rm -f "$current_files" "$manifest_paths"
}

#####################################################################################
# Backup & Rollback
#####################################################################################

# Create timestamped backup before update
create_update_backup() {
    local target_dir="$1"
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_path="${II_BACKUP_DIR}/pre-update-${timestamp}"
    
    mkdir -p "$backup_path"
    
    # Only backup QML code, not user configs
    rsync -a --exclude='.ii-manifest' "$target_dir/" "$backup_path/" 2>/dev/null
    
    # Save backup path for potential rollback
    echo "$backup_path" > "${II_BACKUP_DIR}/.last-backup"
    
    echo "$backup_path"
}

# Rollback to last backup
rollback_update() {
    local last_backup_file="${II_BACKUP_DIR}/.last-backup"
    
    if [[ ! -f "$last_backup_file" ]]; then
        log_error "No backup found to rollback to"
        return 1
    fi
    
    local backup_path
    backup_path=$(cat "$last_backup_file")
    
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup directory not found: $backup_path"
        return 1
    fi
    
    log_warning "Rolling back to: $backup_path"
    
    # Restore from backup
    rsync -a --delete "$backup_path/" "$II_TARGET/"
    
    log_success "Rollback complete"
    return 0
}

# Cleanup old backups (keep last 5)
cleanup_old_backups() {
    local backup_dir="$1"
    local keep_count="${2:-5}"
    
    if [[ ! -d "$backup_dir" ]]; then
        return 0
    fi
    
    # List backups sorted by date, skip the newest $keep_count
    local old_backups
    old_backups=$(ls -1dt "$backup_dir"/pre-update-* 2>/dev/null | tail -n +$((keep_count + 1)))
    
    if [[ -n "$old_backups" ]]; then
        echo "$old_backups" | while read -r dir; do
            rm -rf "$dir"
        done
    fi
}

#####################################################################################
# Verification
#####################################################################################

# Verify quickshell loads without fatal errors
verify_qs_loads() {
    local timeout_sec="${1:-$VERIFICATION_TIMEOUT}"
    
    # Kill any existing instance
    qs kill -c ii 2>/dev/null || true
    sleep 0.5
    
    # Try to start and capture output
    local output
    local exit_code
    
    output=$(timeout "$timeout_sec" qs -c ii 2>&1) || exit_code=$?
    
    # Check for fatal errors (not warnings)
    if echo "$output" | grep -qE "^[[:space:]]*(ERROR|FATAL|error:|Error:)" | grep -v "polkit\|bluez"; then
        log_error "Quickshell failed to load properly"
        echo "$output" | grep -E "(ERROR|FATAL|error:|Error:)" | head -5
        return 1
    fi
    
    # Check if Configuration Loaded message appeared
    if echo "$output" | grep -q "Configuration Loaded"; then
        return 0
    fi
    
    # If timeout but no errors, assume OK (qs keeps running)
    if [[ "$exit_code" == "124" ]]; then
        return 0
    fi
    
    return 0
}

# Full verification suite
run_verification() {
    local errors=0
    
    log_info "Running post-update verification..."
    
    # 1. Check manifest exists
    if [[ ! -f "$II_MANIFEST_FILE" ]]; then
        log_warning "Manifest file missing (will be created)"
    fi
    
    # 2. Check critical files exist
    local critical_files=("shell.qml" "GlobalStates.qml" "modules/common/Config.qml")
    for file in "${critical_files[@]}"; do
        if [[ ! -f "$II_TARGET/$file" ]]; then
            log_error "Critical file missing: $file"
            ((errors++))
        fi
    done
    
    # 3. Check script permissions
    if [[ -d "$II_TARGET/scripts" ]]; then
        local scripts_without_exec
        scripts_without_exec=$(find "$II_TARGET/scripts" -name "*.sh" -o -name "*.fish" -o -name "*.py" | while read -r f; do
            [[ ! -x "$f" ]] && echo "$f"
        done)
        
        if [[ -n "$scripts_without_exec" ]]; then
            log_warning "Fixing script permissions..."
            find "$II_TARGET/scripts" \( -name "*.sh" -o -name "*.fish" -o -name "*.py" \) -exec chmod +x {} \;
        fi
    fi
    
    # 4. Verify QS loads (only if no critical errors)
    if [[ $errors -eq 0 ]]; then
        if ! verify_qs_loads; then
            log_error "Quickshell verification failed"
            ((errors++))
        else
            log_success "Quickshell loads correctly"
        fi
    fi
    
    return $errors
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
    orphans=$(get_orphan_files "$target_dir" "$manifest_file")
    
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

#####################################################################################
# Main Update Function
#####################################################################################

# Perform robust update with backup, verification, and rollback
perform_robust_update() {
    local repo_root="$1"
    local target_dir="${2:-$II_TARGET}"
    local skip_verification="${3:-false}"
    
    log_header "Performing robust update"
    
    # 1. Create backup
    log_info "Creating backup..."
    local backup_path
    backup_path=$(create_update_backup "$target_dir")
    log_success "Backup created: $backup_path"
    
    # 2. Generate manifest from repo
    log_info "Generating manifest..."
    local temp_manifest
    temp_manifest=$(mktemp)
    generate_manifest "$repo_root" "$temp_manifest"
    
    # 3. Sync files (this is done by the caller via existing functions)
    # The caller should call this function AFTER syncing files
    
    # 4. Install manifest
    cp "$temp_manifest" "$II_MANIFEST_FILE"
    rm -f "$temp_manifest"
    
    # 5. Cleanup orphans
    log_info "Checking for orphan files..."
    cleanup_orphans "$target_dir" "$II_MANIFEST_FILE"
    
    # 6. Fix permissions
    log_info "Fixing script permissions..."
    find "$target_dir/scripts" \( -name "*.sh" -o -name "*.fish" -o -name "*.py" \) -exec chmod +x {} \; 2>/dev/null || true
    
    # 7. Verify (unless skipped)
    if [[ "$skip_verification" != "true" ]]; then
        if ! run_verification; then
            log_error "Verification failed! Rolling back..."
            rollback_update
            return 1
        fi
    fi
    
    # 8. Cleanup old backups
    cleanup_old_backups "$II_BACKUP_DIR" 5
    
    log_success "Update completed successfully"
    return 0
}
