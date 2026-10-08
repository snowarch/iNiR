#!/usr/bin/env bash

MIGRATION_ID="042-cliphist-no-synthetic-newline"
MIGRATION_TITLE="Stop duplicate clipboard history entries"
MIGRATION_DESCRIPTION="Adds wl-paste --no-newline so clipboard history round trips do not accumulate trailing newlines and bypass cliphist deduplication."
MIGRATION_TARGET_FILE="~/.config/niri/config.d/50-startup.kdl"
MIGRATION_REQUIRED=true

MIGRATION_SESSION_IMPACT=true
MIGRATION_SESSION_REFERENCE="Niri clipboard text watcher"
MIGRATION_SESSION_REASON="The corrected watcher is spawned by Niri at login, so the current wl-paste process keeps the old arguments until the session is restarted."
MIGRATION_SESSION_EFFECT="Clipboard history can keep accumulating visually duplicate text entries for the rest of the current login session."
MIGRATION_SESSION_ACTION="Log out and back in to restart the clipboard watcher with the corrected arguments."

_cliphist_startup_file="${HOME}/.config/niri/config.d/50-startup.kdl"

migration_check() {
    [[ -f "$_cliphist_startup_file" ]] || return 1

    grep -E '^[[:space:]]*spawn-at-startup .*wl-paste .*--type text(/plain)? .*--watch' \
        "$_cliphist_startup_file" 2>/dev/null \
        | grep -qv -- '--no-newline'
}

migration_preview() {
    echo -e "${STY_RED}- wl-paste --type text --watch ...${STY_RST}"
    echo -e "${STY_GREEN}+ wl-paste --no-newline --type text --watch ...${STY_RST}"
    echo ""
    echo "wl-paste otherwise appends a newline to text selections. Reusing a"
    echo "history entry adds another newline each time, so cliphist cannot dedupe it."
    echo "Existing history is left untouched; new entries keep their exact payload."
}

migration_apply() {
    [[ -f "$_cliphist_startup_file" ]] || return 1

    sed -i -E \
        '/^[[:space:]]*spawn-at-startup .*wl-paste .*--type text(\/plain)? .*--watch/ { /--no-newline/! s/wl-paste /wl-paste --no-newline /; }' \
        "$_cliphist_startup_file"

    ! grep -E '^[[:space:]]*spawn-at-startup .*wl-paste .*--type text(/plain)? .*--watch' \
        "$_cliphist_startup_file" 2>/dev/null \
        | grep -qv -- '--no-newline'
}
