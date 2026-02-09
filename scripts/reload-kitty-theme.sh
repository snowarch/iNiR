#!/bin/bash
# Script to reload kitty when theme changes
# Call this from your quickshell theme change hook

# Method 1: Reload config using the standard socket path
if [ -S /tmp/kitty-socket ]; then
    kitty @ --to unix:/tmp/kitty-socket load-config 2>/dev/null
    echo "Kitty theme reloaded via /tmp/kitty-socket"
elif [ -S /tmp/kitty ]; then
    kitty @ --to unix:/tmp/kitty load-config 2>/dev/null
    echo "Kitty theme reloaded via /tmp/kitty"
else
    # Try alternative socket locations
    for socket in /tmp/kitty-*; do
        if [ -S "$socket" ]; then
            kitty @ --to unix:$socket load-config 2>/dev/null
        fi
    done
    echo "Kitty theme reloaded via alternative sockets"
fi

# Method 2: Alternative - signal all kitty instances
# killall -SIGUSR1 kitty 2>/dev/null
