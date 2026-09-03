#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${INIR_VENV:-${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-$HOME/.local/state/quickshell/.venv}}"

# Prefer iNiR's managed Python only when it actually has ytmusicapi. Arch,
# Fedora and newer Ubuntu releases can keep using their distro package through
# system Python; Debian stable falls back to the venv installed by setup.
if [[ -x "$VENV_DIR/bin/python" ]] \
    && "$VENV_DIR/bin/python" -c 'import ytmusicapi' >/dev/null 2>&1; then
  exec "$VENV_DIR/bin/python" "$SCRIPT_DIR/innertube.py" "$@"
fi

exec python3 "$SCRIPT_DIR/innertube.py" "$@"
