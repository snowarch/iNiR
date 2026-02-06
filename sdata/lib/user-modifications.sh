# User modification detection for iNiR
# Detects and preserves user changes before updates overwrite them
# This script is meant to be sourced.

# shellcheck shell=bash

USER_MODS_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user-mods"
MAX_USER_MODS=5

# File patterns to track for modifications (code files only)
TRACKED_PATTERNS=("*.qml" "*.js" "*.py" "*.sh" "*.fish")

###############################################################################
# Manifest v2 with checksums
###############################################################################

# Check if manifest has checksums (v2 format)
manifest_has_checksums() {
    local manifest_file="$1"
    [[ -f "$manifest_file" ]] || return 1
    # v2 manifests have "# ii-manifest v2" header
    head -1 "$manifest_file" | grep -q "ii-manifest v2" && return 0
    # Fallback: check if any line has path:checksum format (64 hex chars)
    grep -q "^[^#].*:[a-f0-9]\{64\}$" "$manifest_file" 2>/dev/null
}

###############################################################################
# Modification Detection
###############################################################################

# Detect files that user modified (checksum differs from manifest)
# Outputs list of modified file paths, one per line
detect_user_modifications() {
    local target_dir="$1"
    local manifest_file="$2"

    [[ -f "$manifest_file" ]] || return 0
    manifest_has_checksums "$manifest_file" || return 0

    # Read manifest and compare checksums directly
    while IFS=: read -r path checksum; do
        # Skip comments, empty lines, and entries without checksums
        [[ "$path" =~ ^# ]] && continue
        [[ -z "$path" ]] && continue
        [[ -z "$checksum" ]] && continue

        local full_path="${target_dir}/${path}"
        [[ -f "$full_path" ]] || continue

        local current_checksum
        current_checksum=$(sha256sum "$full_path" 2>/dev/null | cut -d' ' -f1)

        if [[ "$current_checksum" != "$checksum" ]]; then
            echo "$path"
        fi
    done < "$manifest_file"
}

# Detect files user added (exist in target but not in manifest)
# Only checks tracked patterns (QML, JS, etc.)
detect_user_additions() {
    local target_dir="$1"
    local manifest_file="$2"

    [[ -f "$manifest_file" ]] || return 0

    # Extract paths from manifest (works for both v1 and v2)
    local manifest_paths
    manifest_paths=$(mktemp)
    grep -v "^#" "$manifest_file" | cut -d: -f1 | sort -u > "$manifest_paths"

    # Find tracked files that aren't in manifest
    for pattern in "${TRACKED_PATTERNS[@]}"; do
        find "$target_dir" -type f -name "$pattern" 2>/dev/null | while read -r file; do
            local rel_path="${file#$target_dir/}"
            # Skip hidden files
            [[ "$rel_path" == .* ]] && continue

            if ! grep -qxF "$rel_path" "$manifest_paths"; then
                echo "$rel_path"
            fi
        done
    done

    rm -f "$manifest_paths"
}

###############################################################################
# Preservation
###############################################################################

# Preserve user modifications to a dedicated directory
# Args: target_dir, space-separated modified files, space-separated added files
# Outputs: path where modifications were saved
preserve_user_modifications() {
    local target_dir="$1"
    shift
    local mod_files_str="$1"
    shift
    local add_files_str="$1"

    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local preserve_dir="${USER_MODS_DIR}/${timestamp}"

    mkdir -p "$preserve_dir"

    local mod_count=0
    local add_count=0

    # Copy modified files
    if [[ -n "$mod_files_str" ]]; then
        while IFS= read -r path; do
            [[ -z "$path" ]] && continue
            local src="${target_dir}/${path}"
            local dst="${preserve_dir}/${path}"
            [[ -f "$src" ]] || continue
            mkdir -p "$(dirname "$dst")"
            cp "$src" "$dst"
            ((mod_count++))
        done <<< "$mod_files_str"
    fi

    # Copy user additions to _additions subdirectory
    if [[ -n "$add_files_str" ]]; then
        while IFS= read -r path; do
            [[ -z "$path" ]] && continue
            local src="${target_dir}/${path}"
            local dst="${preserve_dir}/_additions/${path}"
            [[ -f "$src" ]] || continue
            mkdir -p "$(dirname "$dst")"
            cp "$src" "$dst"
            ((add_count++))
        done <<< "$add_files_str"
    fi

    # Create metadata
    local from_commit
    from_commit=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")

    cat > "${preserve_dir}/metadata.json" << EOF
{
  "preserved_at": "$(date -Iseconds)",
  "from_commit": "${from_commit}",
  "modified_count": ${mod_count},
  "additions_count": ${add_count}
}
EOF

    # Cleanup old preservation directories
    cleanup_old_user_mods

    echo "$preserve_dir"
}

# Remove old user modification backups, keep only MAX_USER_MODS
cleanup_old_user_mods() {
    [[ -d "$USER_MODS_DIR" ]] || return 0

    local count
    count=$(find "$USER_MODS_DIR" -maxdepth 1 -type d ! -path "$USER_MODS_DIR" 2>/dev/null | wc -l)

    if [[ $count -gt $MAX_USER_MODS ]]; then
        # Remove oldest directories
        find "$USER_MODS_DIR" -maxdepth 1 -type d ! -path "$USER_MODS_DIR" -printf '%T+ %p\n' 2>/dev/null \
            | sort | head -n $((count - MAX_USER_MODS)) | cut -d' ' -f2- \
            | xargs rm -rf 2>/dev/null
    fi
}

###############################################################################
# TUI Interaction
###############################################################################

# Display modification summary
show_modification_summary() {
    local mod_files_str="$1"
    local add_files_str="$2"

    local mod_count=0
    local add_count=0

    if [[ -n "$mod_files_str" ]]; then
        mod_count=$(echo "$mod_files_str" | grep -c .)
        tui_subtitle "Modified files (${mod_count}):"
        echo "$mod_files_str" | head -8 | while read -r f; do
            [[ -n "$f" ]] && echo "    $f"
        done
        [[ $mod_count -gt 8 ]] && tui_dim "    ... and $((mod_count - 8)) more"
    fi

    if [[ -n "$add_files_str" ]]; then
        add_count=$(echo "$add_files_str" | grep -c .)
        echo ""
        tui_subtitle "Files you added (${add_count}):"
        echo "$add_files_str" | head -5 | while read -r f; do
            [[ -n "$f" ]] && echo "    $f"
        done
        [[ $add_count -gt 5 ]] && tui_dim "    ... and $((add_count - 5)) more"
    fi
}

# Show diff for a specific file (if snapshot available)
show_file_diff() {
    local target_dir="$1"
    local file_path="$2"
    local snapshot_dir="$3"

    local current="${target_dir}/${file_path}"
    local original="${snapshot_dir}/ii/${file_path}"

    if [[ -f "$original" ]] && [[ -f "$current" ]]; then
        echo ""
        tui_subtitle "Changes in: $file_path"
        if command -v delta &>/dev/null; then
            delta "$original" "$current" 2>/dev/null || diff -u "$original" "$current" 2>/dev/null || true
        else
            diff -u --color=auto "$original" "$current" 2>/dev/null || diff -u "$original" "$current" 2>/dev/null || true
        fi
    else
        tui_warn "Cannot show diff: original file not found in snapshot"
    fi
}

# Interactive handler for user modifications
# Returns: 0 = continue with update, 1 = cancel update
# Sets PRESERVED_MODS_DIR global variable if modifications were preserved
handle_user_modifications() {
    local mod_files_str="$1"
    local add_files_str="$2"

    local mod_count=0
    local add_count=0
    [[ -n "$mod_files_str" ]] && mod_count=$(echo "$mod_files_str" | grep -c . || echo 0)
    [[ -n "$add_files_str" ]] && add_count=$(echo "$add_files_str" | grep -c . || echo 0)

    local total=$((mod_count + add_count))
    [[ $total -eq 0 ]] && return 0

    PRESERVED_MODS_DIR=""

    echo ""
    tui_warn "Local modifications detected!"
    echo ""

    show_modification_summary "$mod_files_str" "$add_files_str"

    echo ""

    # Non-interactive mode: auto-preserve
    if ! $ask; then
        PRESERVED_MODS_DIR=$(preserve_user_modifications "$II_TARGET" "$mod_files_str" "$add_files_str")
        tui_success "Auto-preserved $total file(s) to: $PRESERVED_MODS_DIR"
        return 0
    fi

    while true; do
        local choice
        choice=$(tui_choose "How would you like to proceed?" \
            "Preserve & Continue" \
            "View Changes" \
            "Continue (overwrite)" \
            "Cancel Update")

        case "$choice" in
            "Preserve & Continue")
                PRESERVED_MODS_DIR=$(preserve_user_modifications "$II_TARGET" "$mod_files_str" "$add_files_str")
                echo ""
                tui_success "Modifications saved to:"
                tui_dim "    $PRESERVED_MODS_DIR"
                echo ""
                tui_info "To restore a file after update:"
                tui_dim "    cp $PRESERVED_MODS_DIR/<path> ~/.config/quickshell/ii/<path>"
                return 0
                ;;
            "View Changes")
                # Find latest snapshot for diff comparison
                local latest_snapshot
                latest_snapshot=$(ls -1t "$SNAPSHOTS_DIR" 2>/dev/null | head -1)

                if [[ -n "$latest_snapshot" ]] && [[ -d "${SNAPSHOTS_DIR}/${latest_snapshot}/ii" ]]; then
                    echo ""
                    local shown=0
                    while IFS= read -r f && [[ $shown -lt 3 ]]; do
                        [[ -z "$f" ]] && continue
                        show_file_diff "$II_TARGET" "$f" "${SNAPSHOTS_DIR}/${latest_snapshot}"
                        echo ""
                        ((shown++))
                    done <<< "$mod_files_str"
                    [[ $mod_count -gt 3 ]] && tui_dim "(Showing first 3 files only)"
                else
                    tui_warn "No snapshot available for comparison"
                fi
                echo ""
                read -rp "Press Enter to continue..."
                echo ""
                show_modification_summary "$mod_files_str" "$add_files_str"
                echo ""
                ;;
            "Continue (overwrite)")
                echo ""
                tui_warn "Your modifications will be overwritten"
                tui_info "A snapshot was created - you can rollback with: ./setup rollback"
                if tui_confirm "Are you sure?" "no"; then
                    return 0
                fi
                echo ""
                show_modification_summary "$mod_files_str" "$add_files_str"
                echo ""
                ;;
            "Cancel Update"|*)
                tui_info "Update cancelled"
                return 1
                ;;
        esac
    done
}

###############################################################################
# List preserved modifications (for user reference)
###############################################################################

list_user_mods() {
    [[ -d "$USER_MODS_DIR" ]] || { echo "No preserved modifications found."; return; }

    echo ""
    tui_title "Preserved User Modifications"
    echo ""

    for dir in $(ls -1t "$USER_MODS_DIR" 2>/dev/null); do
        local meta="${USER_MODS_DIR}/${dir}/metadata.json"
        if [[ -f "$meta" ]]; then
            local mod_count add_count
            mod_count=$(grep -o '"modified_count": [0-9]*' "$meta" 2>/dev/null | grep -o '[0-9]*' || echo 0)
            add_count=$(grep -o '"additions_count": [0-9]*' "$meta" 2>/dev/null | grep -o '[0-9]*' || echo 0)

            tui_key_value "$dir" "${mod_count:-0} modified, ${add_count:-0} added"
        fi
    done

    echo ""
    tui_info "Location: $USER_MODS_DIR"
}
