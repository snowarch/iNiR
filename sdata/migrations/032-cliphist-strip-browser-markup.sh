#!/usr/bin/env bash
# Migration 032: Strip browser markup before storing clipboard text
#
# Migration 023 moved the watcher to `wl-paste --type text`, which fixed
# duplicate entries but not the content. `text` is a GENERIC type name: per
# wl-paste(1) it "automatically picks some offered MIME type that matches the
# given generic name". When a page offers text/plain, wl-paste picks it and all
# is well — but when it offers only text/html (copying an image, or rich content
# out of a contenteditable like ChatGPT's editor), text/html is the only match,
# so the raw markup is what gets stored:
#
#   <meta http-equiv="content-type" content="text/html; charset=utf-8">the text
#
# The list preview hides it, so the entry looks fine until you paste it.
#
# Switching to --type text/plain would drop those entries entirely, which is
# worse. Instead the watcher now pipes through scripts/clipboard-store.py, which
# strips the markup only when the payload carries the browser's meta prefix.

MIGRATION_ID="032-cliphist-strip-browser-markup"
MIGRATION_TITLE="Strip browser HTML markup from clipboard history"
MIGRATION_DESCRIPTION="Routes the cliphist text watcher through clipboard-store.py. Copying an image or rich text from a browser stored raw HTML markup (<meta http-equiv=...>) that the list preview hid but every paste carried."
MIGRATION_TARGET_FILE="~/.config/niri/config.d/50-startup.kdl"
MIGRATION_REQUIRED=true

_cliphist_startup_file="${HOME}/.config/niri/config.d/50-startup.kdl"
_store_filter="clipboard-store.py"

migration_check() {
    [[ -f "$_cliphist_startup_file" ]] || return 1

    # Already migrated
    if grep -q "$_store_filter" "$_cliphist_startup_file" 2>/dev/null; then
        return 1
    fi

    # Needs migration if a plain cliphist text watcher is present
    if grep -qE 'wl-paste --type text(/plain)? --watch cliphist store' "$_cliphist_startup_file" 2>/dev/null; then
        return 0
    fi

    return 1
}

migration_preview() {
    echo -e "${STY_RED}- wl-paste --type text --watch cliphist store${STY_RST}"
    echo -e "${STY_GREEN}+ wl-paste --type text --watch ~/.config/quickshell/inir/scripts/clipboard-store.py${STY_RST}"
    echo ""
    echo "Copying an image or rich text from a browser stored raw HTML markup."
    echo "The preview hid it, but every paste carried it."
    echo "Existing history is left untouched; new entries are stored clean."
}

migration_apply() {
    [[ -f "$_cliphist_startup_file" ]] || return 1

    # The image watcher keeps storing directly: `image` is generic too, but every
    # type it can match is an image, so there is no markup to strip.
    sed -i -E \
        "s|wl-paste --type text(/plain)? --watch cliphist store|wl-paste --type text --watch ~/.config/quickshell/inir/scripts/${_store_filter}|" \
        "$_cliphist_startup_file"

    grep -q "$_store_filter" "$_cliphist_startup_file"
}
