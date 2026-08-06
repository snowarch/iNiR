#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -n "${INIR_VENV:-}" ]]; then
    _ii_venv="$(eval echo "$INIR_VENV")"
elif [[ -n "${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-}" ]]; then
    _ii_venv="$(eval echo "$ILLOGICAL_IMPULSE_VIRTUAL_ENV")"
else
    _ii_venv="$HOME/.local/state/quickshell/.venv"
fi
source "$_ii_venv/bin/activate" 2>/dev/null || true

# Thumbnailing can read gigabytes of image data. Keep its workers and page-cache
# accounting out of inir.service so desktop monitors report the shell itself,
# not a completed batch's reclaimable file cache. The scope forwards stdout,
# preserving QML's machine-progress parser.
if [[ -z "${INIR_THUMBGEN_SCOPED:-}" ]] && command -v systemd-run >/dev/null 2>&1; then
    exec systemd-run --user --scope --quiet --collect \
        --property="Description=iNiR wallpaper thumbnails" \
        --setenv=INIR_THUMBGEN_SCOPED=1 \
        --setenv=GIO_USE_VFS=local \
        -- "$_ii_venv/bin/python3" "$SCRIPT_DIR/thumbgen.py" "$@"
fi

exec env GIO_USE_VFS=local "$_ii_venv/bin/python3" "$SCRIPT_DIR/thumbgen.py" "$@"
