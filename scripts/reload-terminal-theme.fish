#!/usr/bin/env fish
# Script to reload kitty and fish themes when wallpaper/theme changes
# This should be called by the ii wallpaper theming system

# Function to reload kitty terminal colors
function reload_kitty
    # Try standard socket paths in order of preference
    if test -S /tmp/kitty-socket
        kitty @ --to unix:/tmp/kitty-socket load-config 2>/dev/null
        and echo "Kitty theme reloaded via /tmp/kitty-socket"
        or echo "Failed to reload kitty via /tmp/kitty-socket"
    else if test -S /tmp/kitty
        kitty @ --to unix:/tmp/kitty load-config 2>/dev/null
        and echo "Kitty theme reloaded via /tmp/kitty"
        or echo "Failed to reload kitty via /tmp/kitty"
    else
        # Try alternative socket locations
        set -l reloaded 0
        for socket in /tmp/kitty-*
            if test -S $socket
                kitty @ --to unix:$socket load-config 2>/dev/null
                and set reloaded 1
            end
        end
        if test $reloaded -eq 1
            echo "Kitty theme reloaded"
        else
            echo "No kitty instances found to reload"
        end
    end
end

# Function to signal fish shells to reload
function reload_fish_shells
    # Update the reload marker
    mkdir -p ~/.cache
    echo (date +%s) > ~/.cache/fish_theme_reload
    
    # Try to find and signal fish processes
    # Note: This is a best-effort approach
    echo "Fish theme reload signal sent"
end

# Main execution
echo "Reloading terminal themes..."
reload_kitty
reload_fish_shells
echo "Done!"
