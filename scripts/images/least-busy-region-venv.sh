#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "${INIR_VIRTUAL_ENV:-}" ]]; then
    _inir_venv="$(eval echo "$INIR_VIRTUAL_ENV")"
else
    _inir_venv="$HOME/.local/state/quickshell/.venv"
fi
source "$_inir_venv/bin/activate" 2>/dev/null || true
"$_inir_venv/bin/python3" "$SCRIPT_DIR/least_busy_region.py" "$@"
deactivate 2>/dev/null || true
