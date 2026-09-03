#!/usr/bin/env bash
# Migration 038: keep internal Niri preview frames out of cliphist.

MIGRATION_ID="038-cliphist-preview-filter"
MIGRATION_TITLE="Filter internal window previews from clipboard history"
MIGRATION_DESCRIPTION="Routes the image clipboard watcher through iNiR's preview-aware store helper. Niri always publishes screenshot-window frames to the clipboard; without this filter Dock/Task View previews can appear in cliphist even when the user's clipboard is restored immediately afterward."
MIGRATION_TARGET_FILE="~/.config/niri/config.d/50-startup.kdl"
MIGRATION_REQUIRED=true

_startup_file="${HOME}/.config/niri/config.d/50-startup.kdl"
_old='wl-paste --type image --watch cliphist store'
_new='wl-paste --type image --watch ~/.config/quickshell/inir/scripts/clipboard-image-store.sh'

migration_check() {
    [[ -f "$_startup_file" ]] || return 1
    grep -Fq "$_old" "$_startup_file" 2>/dev/null
}

migration_preview() {
    echo -e "${STY_RED}- $_old${STY_RST}"
    echo -e "${STY_GREEN}+ $_new${STY_RST}"
    echo ""
    echo "Normal copied images still go to cliphist. Only compositor screenshots"
    echo "created internally for iNiR window previews are discarded."
}

migration_apply() {
    [[ -f "$_startup_file" ]] || return 1
    sed -i "s|$_old|$_new|g" "$_startup_file"
    grep -Fq "$_new" "$_startup_file"
}
