#!/usr/bin/env bash
# Hide xembedsniproxy's internal X11 window on Niri restarts.

MIGRATION_ID="035-hide-xembedsniproxy-window"
MIGRATION_TITLE="Hide the XEmbed tray bridge window"
MIGRATION_DESCRIPTION="Adds a Niri rule that keeps xembedsniproxy's internal X11 selection window transparent, floating, and unfocused so iNiR restarts no longer flash a black window."
MIGRATION_TARGET_FILE="~/.config/niri/config.d/30-window-rules.kdl"
MIGRATION_REQUIRED=true

_xembed_rules_file="${HOME}/.config/niri/config.d/30-window-rules.kdl"

migration_check() {
    [[ -f "$_xembed_rules_file" ]] || return 1
    ! grep -q 'xembedsniproxy' "$_xembed_rules_file" 2>/dev/null
}

migration_preview() {
    echo -e "${STY_GREEN}+ window-rule: xembedsniproxy → floating, opacity 0, no focus/border/shadow${STY_RST}"
    echo ""
    echo "This hides the proxy's internal X11 selection window without changing"
    echo "the proxy lifecycle or legacy tray compatibility."
}

migration_apply() {
    [[ -f "$_xembed_rules_file" ]] || return 1

    local tmp_file="${_xembed_rules_file}.inir-xembed.$$"
    awk '
        BEGIN { inserted = 0 }
        !inserted && /^\/\/ ── Privacy:/ {
            print "// KDE XEmbed-SNI bridge exposes a transient X11 window during tray"
            print "// watcher restarts. Keep it floating, transparent and unfocused."
            print "window-rule {"
            print "    match app-id=r#\"^xembedsniproxy$\"#"
            print "    open-floating true"
            print "    open-focused false"
            print "    opacity 0.0"
            print "    focus-ring { off; }"
            print "    border { off; }"
            print "    shadow { off; }"
            print "}"
            print ""
            inserted = 1
        }
        { print }
        END {
            if (!inserted) {
                print ""
                print "// KDE XEmbed-SNI bridge exposes a transient X11 window during tray"
                print "// watcher restarts. Keep it floating, transparent and unfocused."
                print "window-rule {"
                print "    match app-id=r#\"^xembedsniproxy$\"#"
                print "    open-floating true"
                print "    open-focused false"
                print "    opacity 0.0"
                print "    focus-ring { off; }"
                print "    border { off; }"
                print "    shadow { off; }"
                print "}"
            }
        }
    ' "$_xembed_rules_file" > "$tmp_file" || {
        rm -f "$tmp_file"
        return 1
    }

    mv "$tmp_file" "$_xembed_rules_file"
    grep -q 'xembedsniproxy' "$_xembed_rules_file"
}
