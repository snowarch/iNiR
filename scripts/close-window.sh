#!/usr/bin/env bash
# Close window — tries QS first (for confirm dialog), falls back to niri.
#
# Race condition protection:
# 1. We capture the focused window ID immediately (before spawn latency can shift focus).
# 2. If IPC fails/times out, we close the *captured* window by ID — not whatever is
#    focused at fallback time.
# 3. Because both paths target the same window by ID, an accidental double-close is a
#    harmless no-op instead of killing a random window.

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
launcher_path="$script_dir/inir"

# Capture focused window JSON immediately — this is the window the user intended to close.
focused_window_json=$(niri msg -j focused-window 2>/dev/null)
focused_id=$(printf '%s' "$focused_window_json" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')
focused_app_id=$(printf '%s' "$focused_window_json" | grep -o '"app_id":"[^"]*"' | sed 's/"app_id":"\([^"]*\)"/\1/')

close_focused() {
    if [ "${focused_app_id,,}" = "spotify" ]; then
        # Keep Spotify running but hide its window from current workspace.
        if [ -n "$focused_id" ]; then
            niri msg action move-window-to-workspace --window-id "$focused_id" --focus false 99 >/dev/null 2>&1
            return 0
        fi
    fi

    if [ -n "$focused_id" ]; then
        niri msg action close-window --id "$focused_id"
    else
        niri msg action close-window
    fi
}

# If QS is not running, close directly using the captured ID.
if ! pgrep -x qs >/dev/null 2>&1 && ! pgrep -x quickshell >/dev/null 2>&1; then
    close_focused
    exit 0
fi

# QS is running — pass the snapshot through IPC so confirmation and fast-close
# use the same window that was focused when the keybind fired.
if [ -n "$focused_id" ]; then
    ipc_args=(closeConfirm triggerWindow "$focused_id" "$focused_app_id")
else
    ipc_args=(closeConfirm trigger)
fi
if timeout 1 "$launcher_path" "${ipc_args[@]}" 2>/dev/null; then
    exit 0
fi

# Fallback — IPC failed or timed out. Close the originally captured window.
# If QS already processed the trigger (timeout just killed the client), both
# paths target the same window by ID, so the second close is a no-op.
close_focused
