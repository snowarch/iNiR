#!/usr/bin/env bash

# Library file: intended to be sourced by other scripts.
# Do not set shell options here; callers own execution mode.

inir_exec_scoped() {
    local prefix="${1:-inir-app}"
    shift
    if [[ -n "${INVOCATION_ID:-}" ]]; then
        exec "$@"
    fi
    if command -v systemd-run >/dev/null 2>&1 && [[ -S "${XDG_RUNTIME_DIR:-}/systemd/private" ]]; then
        exec systemd-run --user --quiet --collect --same-dir --scope \
            --unit="${prefix}-$$" --description="$prefix" -- "$@"
    fi
    exec "$@"
}
