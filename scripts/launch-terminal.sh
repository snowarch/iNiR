#!/usr/bin/env bash
# Launch the configured terminal emulator
# Reads from iNiR config, falls back to kitty (project default)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/config-path.sh
source "$SCRIPT_DIR/lib/config-path.sh"

CONFIG_FILE="$(inir_config_file)"

if [[ -f "$CONFIG_FILE" ]]; then
    TERMINAL=$(grep -o '"terminal"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" \
        | head -1 \
        | sed 's/.*"terminal"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
fi

TERMINAL="${TERMINAL:-kitty}"

if command -v "$TERMINAL" &>/dev/null; then
    if command -v systemd-run &>/dev/null; then
        exec systemd-run --user --scope --quiet --collect --property="Description=iNiR Terminal" -- "$TERMINAL" "$@"
    else
        exec "$TERMINAL" "$@"
    fi
fi

# Fallback chain: project default first, then popular alternatives
for fallback in kitty foot ghostty alacritty wezterm konsole xterm; do
    if command -v "$fallback" &>/dev/null; then
        if command -v systemd-run &>/dev/null; then
            exec systemd-run --user --scope --quiet --collect --property="Description=iNiR Terminal" -- "$fallback" "$@"
        else
            exec "$fallback" "$@"
        fi
    fi
done

echo "No terminal emulator found" >&2
exit 1
