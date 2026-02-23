#!/bin/bash
# Close window - tries QS first (for confirm dialog), falls back to niri
#
# Race condition protection:
# 1. Script checks if QS process exists before attempting IPC
# 2. QS has a 2-second startup grace period where it ignores closeConfirm triggers
# 3. If IPC fails/times out, we fall back to niri's native close-window

# Quick check if quickshell process exists
if ! pgrep -x quickshell >/dev/null 2>&1; then
    niri msg action close-window
    exit 0
fi

# Try IPC - QS will ignore if in startup grace period
if timeout 0.2 qs -c inir ipc call closeConfirm trigger 2>/dev/null; then
    exit 0
fi

# Fallback
niri msg action close-window
