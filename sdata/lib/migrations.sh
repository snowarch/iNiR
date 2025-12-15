# Migration system for ii-niri
# Respects user configs - never modifies without explicit consent
# This script is meant to be sourced.

# shellcheck shell=bash

#####################################################################################
# Migration System Configuration
#####################################################################################
MIGRATIONS_DIR="${REPO_ROOT}/sdata/migrations"
MIGRATIONS_STATE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/migrations.json"
MIGRATIONS_BACKUP_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/backups"

#####################################################################################
# Migration State Management
#####################################################################################
init_migrations_state() {
    mkdir -p "$(dirname "$MIGRATIONS_STATE_FILE")"

    if [[ -f "$MIGRATIONS_STATE_FILE" ]] && command -v jq &>/dev/null; then
        if ! jq empty "$MIGRATIONS_STATE_FILE" &>/dev/null; then
            echo '{"applied": [], "skipped": []}' > "$MIGRATIONS_STATE_FILE"
        fi
        return 0
    fi

    if [[ ! -f "$MIGRATIONS_STATE_FILE" ]]; then
        echo '{"applied": [], "skipped": []}' > "$MIGRATIONS_STATE_FILE"
    fi
}

is_migration_applied() {
    local migration_id="$1"
    init_migrations_state
    if command -v jq &>/dev/null; then
        jq -e ".applied | index(\"$migration_id\")" "$MIGRATIONS_STATE_FILE" &>/dev/null
    else
        grep -q "\"$migration_id\"" "$MIGRATIONS_STATE_FILE" 2>/dev/null
    fi
}

is_migration_skipped() {
    local migration_id="$1"
    init_migrations_state
    if command -v jq &>/dev/null; then
        jq -e ".skipped | index(\"$migration_id\")" "$MIGRATIONS_STATE_FILE" &>/dev/null
    else
        false
    fi
}

mark_migration_applied() {
    local migration_id="$1"
    init_migrations_state
    if command -v jq &>/dev/null; then
        local tmp=$(mktemp)
        jq ".applied += [\"$migration_id\"] | .applied |= unique" "$MIGRATIONS_STATE_FILE" > "$tmp"
        mv "$tmp" "$MIGRATIONS_STATE_FILE"
    fi
}

mark_migration_skipped() {
    local migration_id="$1"
    init_migrations_state
    if command -v jq &>/dev/null; then
        local tmp=$(mktemp)
        jq ".skipped += [\"$migration_id\"] | .skipped |= unique" "$MIGRATIONS_STATE_FILE" > "$tmp"
        mv "$tmp" "$MIGRATIONS_STATE_FILE"
    fi
}

#####################################################################################
# Backup System
#####################################################################################
create_backup() {
    local file="$1"
    local backup_name="$2"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    local timestamp=$(date +%Y-%m-%d-%H%M%S)
    local backup_dir="${MIGRATIONS_BACKUP_DIR}/${timestamp}"
    mkdir -p "$backup_dir"
    
    local filename=$(basename "$file")
    cp "$file" "${backup_dir}/${backup_name:-$filename}"
    
    echo "$backup_dir"
}

#####################################################################################
# Migration Discovery
#####################################################################################
list_available_migrations() {
    if [[ ! -d "$MIGRATIONS_DIR" ]]; then
        return
    fi
    
    for migration_file in "$MIGRATIONS_DIR"/*.sh; do
        if [[ -f "$migration_file" ]]; then
            basename "$migration_file" .sh
        fi
    done | sort -V
}

# Check if a migration is actually needed (runs the check function)
is_migration_needed() {
    local migration_id="$1"
    
    load_migration "$migration_id" 2>/dev/null || return 1
    
    if type migration_check &>/dev/null; then
        migration_check 2>/dev/null
        return $?
    fi
    
    # No check function = always needed
    return 0
}

# Get real status of a migration (checks actual config, not just JSON)
get_migration_real_status() {
    local migration_id="$1"
    
    # First check JSON state
    if is_migration_skipped "$migration_id"; then
        echo "skipped"
        return
    fi
    
    if is_migration_applied "$migration_id"; then
        echo "applied"
        return
    fi
    
    # Check if actually needed
    if is_migration_needed "$migration_id"; then
        echo "pending"
    else
        # Config already has the changes, auto-mark as applied
        mark_migration_applied "$migration_id"
        echo "auto-applied"
    fi
}

get_pending_migrations() {
    local pending=()
    
    for migration_id in $(list_available_migrations); do
        local status=$(get_migration_real_status "$migration_id")
        if [[ "$status" == "pending" ]]; then
            pending+=("$migration_id")
        fi
    done
    
    echo "${pending[@]}"
}

count_pending_migrations() {
    local count=0
    for migration_id in $(list_available_migrations); do
        local status=$(get_migration_real_status "$migration_id")
        if [[ "$status" == "pending" ]]; then
            ((count++))
        fi
    done
    echo "$count"
}

#####################################################################################
# Migration Execution
#####################################################################################
load_migration() {
    local migration_id="$1"
    local migration_file="${MIGRATIONS_DIR}/${migration_id}.sh"
    
    if [[ ! -f "$migration_file" ]]; then
        return 1
    fi
    
    # Reset migration variables
    MIGRATION_ID=""
    MIGRATION_TITLE=""
    MIGRATION_DESCRIPTION=""
    MIGRATION_TARGET_FILE=""
    MIGRATION_REQUIRED=false
    
    # Unset previous functions
    unset -f migration_check migration_preview migration_diff migration_apply 2>/dev/null
    
    source "$migration_file"
}

apply_migration() {
    local migration_id="$1"
    local force="${2:-false}"
    
    load_migration "$migration_id" || return 1
    
    # Check if already applied
    if is_migration_applied "$migration_id" && [[ "$force" != "true" ]]; then
        tui_check_ok "Already applied: $MIGRATION_TITLE"
        return 0
    fi
    
    # Check if target file exists
    local target_file="${MIGRATION_TARGET_FILE/#\~/$HOME}"
    if [[ -n "$target_file" && ! -f "$target_file" ]]; then
        tui_check_skip "Target file not found: $(basename "$target_file")"
        mark_migration_skipped "$migration_id"
        return 0
    fi
    
    # Create backup
    if [[ -n "$target_file" && -f "$target_file" ]]; then
        local backup_dir=$(create_backup "$target_file" "$(basename "$target_file")")
        tui_dim "    Backup: $backup_dir"
    fi
    
    # Apply migration
    if type migration_apply &>/dev/null; then
        if migration_apply; then
            mark_migration_applied "$migration_id"
            tui_check_ok "Applied: $MIGRATION_TITLE"
            return 0
        else
            tui_check_fail "Failed: $MIGRATION_TITLE"
            if [[ -n "$backup_dir" ]]; then
                tui_info "Restoring from backup..."
                cp "${backup_dir}/$(basename "$target_file")" "$target_file"
            fi
            return 1
        fi
    else
        tui_check_fail "No apply function: $migration_id"
        return 1
    fi
}

#####################################################################################
# Interactive Migration UI (Improved Design)
#####################################################################################
show_migration_card() {
    local migration_id="$1"
    
    load_migration "$migration_id" || return 1
    
    local target_short=$(basename "${MIGRATION_TARGET_FILE/#\~/$HOME}" 2>/dev/null || echo "N/A")
    
    echo ""
    if $HAS_GUM; then
        gum style \
            --border rounded \
            --border-foreground "$TUI_ACCENT_DIM" \
            --padding "0 2" \
            --margin "0 1" \
            "$(gum style --foreground "$TUI_ACCENT" --bold "$MIGRATION_TITLE")" \
            "" \
            "$(gum style --foreground "$TUI_MUTED" "Target: $target_short")" \
            "" \
            "$MIGRATION_DESCRIPTION"
        
        if type migration_preview &>/dev/null; then
            echo ""
            gum style --foreground "$TUI_MUTED" "  Changes:"
            migration_preview | while IFS= read -r line; do
                echo "    $line"
            done
        fi
    else
        echo -e "  ${STY_FAINT}╭────────────────────────────────────────────────────╮${STY_RST}"
        echo -e "  ${STY_FAINT}│${STY_RST} ${STY_PURPLE}${STY_BOLD}$MIGRATION_TITLE${STY_RST}"
        echo -e "  ${STY_FAINT}│${STY_RST}"
        echo -e "  ${STY_FAINT}│${STY_RST} ${STY_FAINT}Target:${STY_RST} $target_short"
        echo -e "  ${STY_FAINT}│${STY_RST}"
        # Word wrap description
        echo "$MIGRATION_DESCRIPTION" | fold -s -w 50 | while IFS= read -r line; do
            echo -e "  ${STY_FAINT}│${STY_RST} $line"
        done
        
        if type migration_preview &>/dev/null; then
            echo -e "  ${STY_FAINT}│${STY_RST}"
            echo -e "  ${STY_FAINT}│${STY_RST} ${STY_BOLD}Changes:${STY_RST}"
            migration_preview | while IFS= read -r line; do
                echo -e "  ${STY_FAINT}│${STY_RST}   $line"
            done
        fi
        echo -e "  ${STY_FAINT}╰────────────────────────────────────────────────────╯${STY_RST}"
    fi
}

run_migrations_interactive() {
    local pending=($(get_pending_migrations))
    
    if [[ ${#pending[@]} -eq 0 ]]; then
        tui_success "No pending migrations"
        return 0
    fi
    
    tui_title "Configuration Migrations"
    
    tui_info "${#pending[@]} migration(s) available"
    tui_subtitle "These update your config files to support new features."
    tui_subtitle "Original files are backed up automatically."
    
    for migration_id in "${pending[@]}"; do
        show_migration_card "$migration_id"
        
        echo ""
        local choice
        if $HAS_GUM; then
            choice=$(gum choose --header "Apply this migration?" \
                --header.foreground "$TUI_ACCENT" \
                --cursor.foreground "$TUI_ACCENT" \
                "Yes, apply" "No, skip" "View diff" "Apply all" "Quit")
        else
            echo -e "  ${STY_PURPLE}?${STY_RST} Apply this migration?"
            echo -e "    ${STY_FAINT}1)${STY_RST} Yes, apply"
            echo -e "    ${STY_FAINT}2)${STY_RST} No, skip (won't ask again)"
            echo -e "    ${STY_FAINT}3)${STY_RST} View diff"
            echo -e "    ${STY_FAINT}4)${STY_RST} Apply all remaining"
            echo -e "    ${STY_FAINT}5)${STY_RST} Quit"
            echo ""
            echo -ne "  ${STY_PURPLE}❯${STY_RST} "
            read -r selection
            case "$selection" in
                1|y|Y) choice="Yes, apply" ;;
                2|n|N) choice="No, skip" ;;
                3|v|V) choice="View diff" ;;
                4|a|A) choice="Apply all" ;;
                *) choice="Quit" ;;
            esac
        fi
        
        case "$choice" in
            "Yes, apply")
                apply_migration "$migration_id"
                ;;
            "No, skip")
                mark_migration_skipped "$migration_id"
                tui_check_skip "Skipped: $(load_migration "$migration_id" && echo "$MIGRATION_TITLE")"
                ;;
            "View diff")
                if type migration_diff &>/dev/null; then
                    load_migration "$migration_id"
                    echo ""
                    migration_diff
                    echo ""
                else
                    tui_warn "No diff available"
                fi
                # Re-show this migration
                show_migration_card "$migration_id"
                ;;
            "Apply all")
                apply_migration "$migration_id"
                for remaining in "${pending[@]}"; do
                    if ! is_migration_applied "$remaining" && ! is_migration_skipped "$remaining"; then
                        apply_migration "$remaining"
                    fi
                done
                break
                ;;
            *)
                tui_info "Migrations paused. Run './setup migrate' to continue."
                return 0
                ;;
        esac
    done
    
    echo ""
    tui_success "All migrations processed"
}

run_migrations_auto() {
    local pending=($(get_pending_migrations))
    
    for migration_id in "${pending[@]}"; do
        load_migration "$migration_id"
        if [[ "$MIGRATION_REQUIRED" == "true" ]]; then
            apply_migration "$migration_id"
        fi
    done
}

#####################################################################################
# Migration Status Display (Improved)
#####################################################################################
show_migrations_status() {
    tui_title "Migration Status"
    
    local applied=0
    local skipped=0
    local pending=0
    local auto_applied=0
    
    for migration_id in $(list_available_migrations); do
        local status=$(get_migration_real_status "$migration_id")
        load_migration "$migration_id" 2>/dev/null
        local title="${MIGRATION_TITLE:-$migration_id}"
        
        case "$status" in
            applied)
                tui_check_ok "$title"
                ((applied++))
                ;;
            auto-applied)
                tui_check_ok "$title ${STY_FAINT}(auto-detected)${STY_RST}"
                ((auto_applied++))
                ;;
            skipped)
                tui_check_skip "$title (skipped)"
                ((skipped++))
                ;;
            pending)
                tui_check_warn "$title (pending)"
                ((pending++))
                ;;
        esac
    done
    
    echo ""
    local total=$((applied + auto_applied))
    tui_key_value "Applied:" "$total"
    tui_key_value "Skipped:" "$skipped"
    tui_key_value "Pending:" "$pending"
}
