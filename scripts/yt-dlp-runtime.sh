#!/usr/bin/env bash

set -u

# iNiR's own yt-dlp first (setup keeps it current: distro packages fall behind YouTube), then the system one
own="${XDG_DATA_HOME:-$HOME/.local/share}/inir/yt-dlp/yt-dlp"
if [[ -x "$own" ]]; then
    exec "$own" "$@"
fi

if command -v yt-dlp >/dev/null 2>&1; then
    exec yt-dlp "$@"
fi

printf 'iNiR YT Music runtime: yt-dlp is unavailable\n' >&2
exit 127
