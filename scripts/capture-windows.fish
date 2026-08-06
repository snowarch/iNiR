#!/usr/bin/env fish
# Compatibility entry point. Bash owns capture, clipboard and cleanup policy so
# the two launch paths cannot drift into different races.

exec /usr/bin/bash (status dirname)/capture-windows.sh $argv
