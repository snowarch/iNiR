#!/usr/bin/env bash
# Stop Steam notification toasts from stealing focus.
# https://github.com/snowarch/iNiR/issues/223

MIGRATION_ID="036-steam-toast-no-focus"
MIGRATION_TITLE="Stop Steam notification toasts from stealing focus"
MIGRATION_DESCRIPTION="Adds open-floating true and open-focused false to the existing Steam notificationtoast window rule so toast windows no longer grab keyboard focus from the active application."
MIGRATION_TARGET_FILE="~/.config/niri/config.d/30-window-rules.kdl"
MIGRATION_REQUIRED=true

_steam_rules_file="${HOME}/.config/niri/config.d/30-window-rules.kdl"

migration_check() {
    [[ -f "$_steam_rules_file" ]] || return 1
    grep -q 'notificationtoasts_' "$_steam_rules_file" 2>/dev/null || return 1
    ! grep -A6 'notificationtoasts_' "$_steam_rules_file" 2>/dev/null | grep -q 'open-focused false'
}

migration_preview() {
    echo -e "${STY_GREEN}+ window-rule: steam notificationtoasts → open-floating true, open-focused false${STY_RST}"
    echo ""
    echo "Steam's notification toasts will no longer steal keyboard focus from"
    echo "the active application when they appear."
}

migration_apply() {
    [[ -f "$_steam_rules_file" ]] || return 1

    local tmp_file="${_steam_rules_file}.inir-steam.$$"
    awk '
        BEGIN { in_steam = 0; done = 0 }
        !done && /notificationtoasts_/ { in_steam = 1 }
        !done && in_steam && /default-floating-position/ {
            print "    open-floating true"
            print "    open-focused false"
            done = 1
            in_steam = 0
        }
        { print }
    ' "$_steam_rules_file" > "$tmp_file" || {
        rm -f "$tmp_file"
        return 1
    }

    # Fallback: append the complete rule block if the anchor was not found.
    if ! grep -A8 'notificationtoasts_' "$tmp_file" 2>/dev/null | grep -q 'open-focused false'; then
        {
            echo ""
            echo "// Steam notification toasts: floating, never steal focus"
            echo "window-rule {"
            echo "    match app-id=\"steam\" title=r#\"^notificationtoasts_\\d+_desktop$\"#"
            echo "    open-floating true"
            echo "    open-focused false"
            echo "    default-floating-position x=10 y=10 relative-to=\"bottom-right\""
            echo "}"
        } >> "$tmp_file"
    fi

    mv "$tmp_file" "$_steam_rules_file"
    grep -A8 'notificationtoasts_' "$_steam_rules_file" 2>/dev/null | grep -q 'open-focused false'
}
