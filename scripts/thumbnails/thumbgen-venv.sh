#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../lib/accel.sh"
[[ -x "$INIR_ACCEL" ]] || { echo "inir-accel is missing. Run: inir update" >&2; exit 127; }

has_usable_systemd_user_manager() {
    [[ -S "${XDG_RUNTIME_DIR:-}/systemd/private" ]] &&
        command -v systemctl >/dev/null 2>&1 &&
        command -v timeout >/dev/null 2>&1 &&
        timeout 3s systemctl --user show-environment >/dev/null 2>&1
}

# Thumbnailing can read gigabytes of image data. Keep its workers and page-cache
# accounting out of inir.service so desktop monitors report the shell itself,
# not a completed batch's reclaimable file cache. The scope forwards stdout,
# preserving QML's machine-progress parser.
if [[ -z "${INIR_THUMBGEN_SCOPED:-}" ]] &&
    has_usable_systemd_user_manager &&
    command -v systemd-run >/dev/null 2>&1; then
    exec systemd-run --user --scope --quiet --collect \
        --property="Description=iNiR wallpaper thumbnails" \
        --setenv=INIR_THUMBGEN_SCOPED=1 \
        --setenv=GIO_USE_VFS=local \
        -- "$INIR_ACCEL" thumbgen "$@"
fi

exec env GIO_USE_VFS=local "$INIR_ACCEL" thumbgen "$@"
