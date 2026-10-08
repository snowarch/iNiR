#!/usr/bin/env bash

inir_resolve_niri_service_environment() {
    INIR_RESOLVED_NIRI_SOCKET=""
    INIR_RESOLVED_WAYLAND_DISPLAY=""

    command -v systemctl >/dev/null 2>&1 || return 1
    systemctl --user is-active --quiet niri.service >/dev/null 2>&1 || return 1

    local main_pid runtime_dir candidate basename wayland_display found=0
    main_pid="$(systemctl --user show -p MainPID --value niri.service 2>/dev/null || true)"
    [[ "$main_pid" =~ ^[1-9][0-9]*$ ]] || return 1

    runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    for candidate in "$runtime_dir"/niri.*."$main_pid".sock; do
        [[ -S "$candidate" ]] || continue
        basename="${candidate##*/}"
        wayland_display="${basename#niri.}"
        wayland_display="${wayland_display%.${main_pid}.sock}"
        [[ "$wayland_display" == wayland-* ]] || continue
        [[ -S "$runtime_dir/$wayland_display" ]] || continue
        INIR_RESOLVED_NIRI_SOCKET="$candidate"
        INIR_RESOLVED_WAYLAND_DISPLAY="$wayland_display"
        ((found++)) || true
    done

    [[ "$found" -eq 1 ]]
}
