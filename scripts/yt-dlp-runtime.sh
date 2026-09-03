#!/usr/bin/env bash

set -u

venv_dir="${INIR_VENV:-${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-$HOME/.local/state/quickshell/.venv}}"

# Setup-managed installs own a current yt-dlp in iNiR's venv. Prefer it so
# Debian/Ubuntu repository age cannot silently select an incompatible binary.
if [[ -x "$venv_dir/bin/yt-dlp" ]]; then
    exec "$venv_dir/bin/yt-dlp" "$@"
fi

# Package-managed Arch/Nix installations provide yt-dlp in the service PATH.
if command -v yt-dlp >/dev/null 2>&1; then
    exec yt-dlp "$@"
fi

printf 'iNiR YT Music runtime: yt-dlp is unavailable\n' >&2
exit 127
