#!/bin/bash
# Close window with fallback
# Tries Quickshell IPC first (with timeout), falls back to native Niri close-window

# Try QS with 1 second timeout
if timeout 1 qs -c ii ipc call closeConfirm trigger 2>/dev/null; then
    exit 0
fi

# Fallback: Quickshell not running or hung, use native Niri
niri msg action close-window
