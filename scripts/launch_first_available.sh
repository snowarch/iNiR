#!/bin/bash

for cmd in "$@"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        exec "$cmd"
        exit 0
    fi
done

exit 1
