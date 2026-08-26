#!/usr/bin/env bash
# Launch the configured terminal emulator
# Reads from iNiR config, falls back to kitty (project default)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/config-path.sh
source "$SCRIPT_DIR/lib/config-path.sh"
# shellcheck source=scripts/lib/exec-scoped.sh
source "$SCRIPT_DIR/lib/exec-scoped.sh"

CONFIG_FILE="$(inir_config_file)"

if [[ -f "$CONFIG_FILE" ]]; then
    TERMINAL=$(grep -o '"terminal"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" \
        | head -1 \
        | sed 's/.*"terminal"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
fi

TERMINAL="${TERMINAL:-kitty}"

exec_terminal_scoped() {
    inir_exec_scoped "inir-terminal" "$@"
}

launch_term() {
    local term="$1"
    shift
    if [[ $# -eq 0 ]]; then
        exec_terminal_scoped "$term"
    fi

    case "$1" in
        -e|start|--|-x)
            exec_terminal_scoped "$term" "$@"
            ;;
    esac

    case "$term" in
        wezterm)
            exec_terminal_scoped "$term" start --always-new-process -- "$@"
            ;;
        *)
            exec_terminal_scoped "$term" -e "$@"
            ;;
    esac
}

if command -v "$TERMINAL" &>/dev/null; then
    launch_term "$TERMINAL" "$@"
fi

# Fallback chain: project default first, then popular alternatives
for fallback in kitty foot ghostty alacritty wezterm konsole xterm; do
    if command -v "$fallback" &>/dev/null; then
        launch_term "$fallback" "$@"
    fi
done

echo "No terminal emulator found" >&2
exit 1
