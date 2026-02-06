#!/bin/bash
# Launch the configured terminal emulator
# Reads from Quickshell config, falls back to kitty

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json"

if [[ -f "$CONFIG_FILE" ]]; then
    TERMINAL=$(grep -o '"terminal"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | head -1 | sed 's/.*"terminal"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
fi

TERMINAL="${TERMINAL:-kitty}"

if command -v "$TERMINAL" &>/dev/null; then
    exec "$TERMINAL" "$@"
else
    for fallback in kitty foot ghostty alacritty wezterm konsole gnome-terminal xterm; do
        if command -v "$fallback" &>/dev/null; then
            exec "$fallback" "$@"
        fi
    done
fi

echo "No terminal emulator found" >&2
exit 1
