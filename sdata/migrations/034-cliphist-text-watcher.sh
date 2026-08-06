#!/usr/bin/env bash
# Migration 034: Restore the clipboard text watcher
#
# Clipboard history needs two wl-paste watchers: one for images and one for
# text. Migration 032 rewrites the text one to route through
# clipboard-store.py, but it only fires when a text watcher line is present. A
# 50-startup.kdl that lost the line entirely — hand-edited, merged from an older
# template, or replaced wholesale — keeps storing images and silently stores no
# text at all. The clipboard panel still opens; it just never sees anything you
# copy, so it serves an ever older history.

MIGRATION_ID="034-cliphist-text-watcher"
MIGRATION_TITLE="Restore the clipboard text watcher"
MIGRATION_DESCRIPTION="Adds back the wl-paste text watcher when 50-startup.kdl only spawns the image one. Without it nothing you copy reaches the clipboard history and the panel shows a frozen list."
MIGRATION_TARGET_FILE="~/.config/niri/config.d/50-startup.kdl"
MIGRATION_REQUIRED=true

_cliphist_startup_file="${HOME}/.config/niri/config.d/50-startup.kdl"
_text_watcher='spawn-at-startup "bash" "-c" "wl-paste --type text --watch ~/.config/quickshell/inir/scripts/clipboard-store.py \&"'

migration_check() {
    [[ -f "$_cliphist_startup_file" ]] || return 1

    # Any text watcher at all means 032 owns this file, not us.
    if grep -q 'wl-paste --type text' "$_cliphist_startup_file" 2>/dev/null; then
        return 1
    fi

    # Only repair a file that is otherwise wired for clipboard history.
    grep -q 'wl-paste --type image' "$_cliphist_startup_file" 2>/dev/null
}

migration_preview() {
    echo -e "${STY_GREEN}+ wl-paste --type text --watch ~/.config/quickshell/inir/scripts/clipboard-store.py${STY_RST}"
    echo "  wl-paste --type image --watch cliphist store"
    echo ""
    echo "Only the image watcher is spawned, so copied text never reaches the"
    echo "clipboard history. Existing entries are left untouched."
}

migration_apply() {
    [[ -f "$_cliphist_startup_file" ]] || return 1

    sed -i -E "\|wl-paste --type image|i\\${_text_watcher}" "$_cliphist_startup_file"

    grep -q 'wl-paste --type text' "$_cliphist_startup_file"
}
