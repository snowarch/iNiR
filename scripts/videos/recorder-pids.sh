#!/usr/bin/env bash
# Prints the PIDs of the wf-recorder processes capturing this session's screen, one per line.
# A wf-recorder talking to another compositor (a nested test session, another login) is not
# ours to show or to stop. Exits 1 when there is none.
set -u

socket_of() {
    local display="${1:-wayland-0}"
    [[ $display == /* ]] && printf '%s' "$display" || printf '%s/%s' "$2" "$display"
}

ours="$(socket_of "${WAYLAND_DISPLAY:-}" "${XDG_RUNTIME_DIR:-}")"
found=1
for pid in $(pgrep -x -u "$(id -u)" wf-recorder); do
    display="" runtime=""
    while IFS= read -r -d '' entry; do
        case $entry in
            WAYLAND_DISPLAY=*) display=${entry#*=} ;;
            XDG_RUNTIME_DIR=*) runtime=${entry#*=} ;;
        esac
    done 2>/dev/null < "/proc/$pid/environ" || continue
    [[ "$(socket_of "$display" "$runtime")" == "$ours" ]] || continue
    echo "$pid"
    found=0
done
exit "$found"
