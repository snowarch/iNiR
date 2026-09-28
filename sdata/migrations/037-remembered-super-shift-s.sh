#!/usr/bin/env bash
# Route Super+Shift+S through the unified snip menu so its remembered action
# (Shot/Edit/OCR/Search) is actually honored. Only replace the exact historical
# iNiR-managed bind; custom user bindings are left untouched.

MIGRATION_ID="037-remembered-super-shift-s"
MIGRATION_TITLE="Remember Super+Shift+S snip mode"
MIGRATION_DESCRIPTION="Changes the historical iNiR Super+Shift+S region-screenshot bind to the unified region menu. The menu restores the last non-recording action and selection shape when 'Remember last snip choice' is enabled."
MIGRATION_TARGET_FILE="~/.config/niri/config.d/70-binds.kdl"
MIGRATION_REQUIRED=true

migration_check() {
    local binds_file="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.d/70-binds.kdl"
    [[ -f "$binds_file" ]] || return 1
    grep -Eq 'Mod\+Shift\+S[[:space:]]*\{[^}]*region"[[:space:]]+"screenshot"' "$binds_file" 2>/dev/null
}

migration_preview() {
    echo -e "${STY_RED}- Super+Shift+S → region screenshot (always Shot)${STY_RST}"
    echo -e "${STY_GREEN}+ Super+Shift+S → unified region menu (remember last action)${STY_RST}"
}

migration_apply() {
    migration_check || return 0
    local binds_file="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.d/70-binds.kdl"
    sed -i -E '/Mod\+Shift\+S/ s/(region"[[:space:]]+)"screenshot"/\1"menu"/' "$binds_file"
    grep -Eq 'Mod\+Shift\+S[[:space:]]*\{[^}]*region"[[:space:]]+"menu"' "$binds_file"
}
