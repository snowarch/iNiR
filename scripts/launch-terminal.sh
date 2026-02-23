#!/usr/bin/env bash
# Launch the configured terminal emulator
# Reads from iNiR config, falls back to kitty (project default)

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/inir/config.json"

if [[ -f "$CONFIG_FILE" ]]; then
    TERMINAL=$(grep -o '"terminal"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" \
        | head -1 \
        | sed 's/.*"terminal"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
fi

TERMINAL="${TERMINAL:-kitty}"

if command -v "$TERMINAL" &>/dev/null; then
    exec "$TERMINAL" "$@"
fi

# Fallback chain: project default first, then popular alternatives
for fallback in kitty foot ghostty alacritty wezterm konsole xterm; do
    if command -v "$fallback" &>/dev/null; then
        exec "$fallback" "$@"
    fi
done

echo "No terminal emulator found" >&2
exit 1
