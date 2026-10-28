#!/usr/bin/env bash
# Migration 048: The clipboard text watcher runs inir-accel
#
# clipboard-store.py (migrations 032 and 034) was Python; inir-accel's
# clipboard-store does the same job and the .py is gone, so a watcher still
# pointing at it would store nothing you copy.

MIGRATION_ID="048-cliphist-store-via-accel"
MIGRATION_TITLE="Clipboard history through inir-accel"
MIGRATION_DESCRIPTION="Points the wl-paste text watcher at inir-accel clipboard-store. The old clipboard-store.py is gone; without this, copied text would stop reaching the clipboard history."
MIGRATION_TARGET_FILE="~/.config/niri/config.d/50-startup.kdl"
MIGRATION_REQUIRED=true

_cliphist_startup_file="${HOME}/.config/niri/config.d/50-startup.kdl"

migration_check() {
    [[ -f "$_cliphist_startup_file" ]] && grep -q 'scripts/clipboard-store\.py' "$_cliphist_startup_file" 2>/dev/null
}

migration_preview() {
    echo -e "${STY_RED}- wl-paste ... --watch ~/.config/quickshell/inir/scripts/clipboard-store.py${STY_RST}"
    echo -e "${STY_GREEN}+ wl-paste ... --watch ~/.config/quickshell/inir/scripts/lib/accel-run clipboard-store${STY_RST}"
}

migration_apply() {
    [[ -f "$_cliphist_startup_file" ]] || return 1
    sed -i 's|scripts/clipboard-store\.py|scripts/lib/accel-run clipboard-store|g' "$_cliphist_startup_file"
    ! grep -q 'scripts/clipboard-store\.py' "$_cliphist_startup_file"
}
