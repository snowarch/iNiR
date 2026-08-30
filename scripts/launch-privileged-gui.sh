#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
    printf 'Usage: %s PROGRAM [ARGUMENT ...]\n' "${0##*/}" >&2
    exit 2
fi

program="$1"
shift

if [[ "$program" == */* ]]; then
    if [[ ! -x "$program" ]]; then
        printf 'Cannot execute privileged graphical application: %s\n' "$program" >&2
        exit 127
    fi
else
    resolved_program="$(command -v -- "$program" 2>/dev/null || true)"
    if [[ -z "$resolved_program" ]]; then
        printf 'Privileged graphical application not found: %s\n' "$program" >&2
        exit 127
    fi
    program="$resolved_program"
fi

pkexec_path="$(command -v pkexec 2>/dev/null || true)"
env_path="$(command -v env 2>/dev/null || true)"
if [[ -z "$pkexec_path" || -z "$env_path" ]]; then
    printf 'Launching %s requires pkexec and env\n' "$program" >&2
    exit 127
fi

if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    printf 'No graphical display is available for %s\n' "$program" >&2
    exit 1
fi

graphical_env=()
for name in DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR XDG_SESSION_TYPE QT_QPA_PLATFORM GDK_BACKEND XAUTHORITY; do
    value="${!name:-}"
    [[ -n "$value" ]] && graphical_env+=("$name=$value")
done

exec "$pkexec_path" "$env_path" "${graphical_env[@]}" "$program" "$@"
