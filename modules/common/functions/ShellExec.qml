pragma Singleton

import QtQml

import Quickshell
import Quickshell.Io

import qs.modules.common

Singleton {
    id: root

    readonly property string fishPath: "/usr/bin/fish"
    readonly property string bashPath: "/usr/bin/bash"
    readonly property string systemdRunPath: "/usr/bin/systemd-run"
    readonly property string gtkLaunchPath: "/usr/bin/gtk-launch"

    // -1 unknown, 0 no, 1 yes
    property int _fishAvailable: -1

    Process {
        id: fishCheckProc
        command: ["/usr/bin/test", "-x", root.fishPath]
        onExited: (exitCode, exitStatus) => {
            root._fishAvailable = (exitCode === 0) ? 1 : 0
        }
    }

    Component.onCompleted: {
        fishCheckProc.running = true
    }

    function supportsFish(): bool {
        if (root._fishAvailable === -1) {
            // Trigger async check, but default to bash until we know.
            fishCheckProc.running = true
            return false
        }
        return root._fishAvailable === 1
    }

    function execDetachedArgs(args, description = "", workingDirectory = ""): void {
        const argv = Array.from(args ?? []).map(arg => String(arg ?? "")).filter(arg => arg.length > 0)
        if (argv.length === 0) return

        const desc = String(description ?? "").trim()
        const workDir = String(workingDirectory ?? "").trim()
        // A transient scope, never a service. Launchers like zeditor and
        // /usr/bin/code fork the real process and exit immediately; a service
        // treats that first exit as the unit finishing and kills the rest of
        // the cgroup, so the app dies the instant it starts. A scope lives as
        // long as any process in it. systemd-run is exec'd rather than tested
        // for success, because in scope mode it only returns once the app is
        // gone and a fallback there would relaunch it.
        const script = `
            # Rebuild the application-facing environment from the live user
            # session. Quickshell intentionally carries shell-only Qt scaling,
            # rendering and optional GPU policy that must not leak into apps.
            manager_env=""
            if [ -x /usr/bin/systemctl ]; then
                if [ -x /usr/bin/timeout ]; then
                    manager_env="$(/usr/bin/timeout 1s /usr/bin/systemctl --user show-environment 2>/dev/null || true)"
                else
                    manager_env="$(/usr/bin/systemctl --user show-environment 2>/dev/null || true)"
                fi
            fi

            manager_value() {
                [ -n "$manager_env" ] || return 0
                while IFS='=' read -r _key _entry_value; do
                    [ "$_key" = "$1" ] || continue
                    printf '%s' "$_entry_value"
                    return 0
                done <<< "$manager_env"
            }

            restore_from_manager() {
                _name="$1"
                _value="$(manager_value "$_name")"
                if [ -n "$_value" ]; then
                    export "$_name=$_value"
                else
                    unset "$_name"
                fi
            }

            import_if_missing() {
                _name="$1"
                [[ -v $_name ]] && return 0
                _value="$(manager_value "$_name")"
                [ -n "$_value" ] && export "$_name=$_value"
            }

            # apply_shell_scale()/apply_qt_runtime_env() own these for iNiR's
            # process only. Restore the user's session values for launched apps.
            for _var in \
                QT_SCALE_FACTOR QT_SCALE_FACTOR_ROUNDING_POLICY \
                QT_WAYLAND_FORCE_DPI QT_FONT_DPI QT_AUTO_SCREEN_SCALE_FACTOR \
                QT_SCREEN_SCALE_FACTORS GDK_SCALE GDK_DPI_SCALE \
                QSG_ATLAS_WIDTH QSG_ATLAS_HEIGHT QT_LOGGING_RULES \
                QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE QS_DISABLE_CRASH_HANDLER \
                ELECTRON_OZONE_PLATFORM_HINT; do
                restore_from_manager "$_var"
            done

            # The launcher marks exactly which GPU variables iNiR injected for
            # the shell. Restore user values (or unset them) before games/apps.
            for _var in $INIR_SHELL_GPU_POLICY_VARS; do
                restore_from_manager "$_var"
            done
            unset INIR_SHELL_GPU_POLICY_VARS INIR_DISABLE_HOT_RELOAD

            # If startup raced the compositor/session import, fill in the late
            # variables now rather than keeping Quickshell's frozen snapshot.
            for _var in \
                XDG_RUNTIME_DIR XDG_SESSION_TYPE XDG_CURRENT_DESKTOP \
                XDG_SESSION_DESKTOP DESKTOP_SESSION XCURSOR_THEME XCURSOR_SIZE \
                LANG LC_ALL XDG_MENU_PREFIX GDK_BACKEND XAUTHORITY \
                DBUS_SESSION_BUS_ADDRESS SSH_AUTH_SOCK; do
                import_if_missing "$_var"
            done

            _manager_path="$(manager_value PATH)"
            if [ -n "$_manager_path" ]; then
                _merged_path="$_manager_path"
                IFS=: read -r -a _path_parts <<< "$PATH"
                for _path_dir in "\${_path_parts[@]}"; do
                    [ -n "$_path_dir" ] || continue
                    case ":$_merged_path:" in
                        *":$_path_dir:"*) ;;
                        *) _merged_path="$_merged_path:$_path_dir" ;;
                    esac
                done
                export PATH="$_merged_path"
            fi

            # DISPLAY is not required to be :0. Display managers often own :0
            # while the user's Niri/xwayland-satellite session owns :1 or later.
            valid_display() {
                _display="$1"
                [ -n "$_display" ] || return 1
                case "$_display" in
                    :*)
                        _xnum="$(printf '%s' "$_display" | cut -d. -f1 | sed 's/^://')"
                        case "$_xnum" in
                            ''|*[!0-9]*) return 1 ;;
                        esac
                        _xsock="/tmp/.X11-unix/X$_xnum"
                        [ -S "$_xsock" ] || return 1
                        [ "$(stat -c %u "$_xsock" 2>/dev/null)" = "$(id -u)" ] || return 1
                        return 0
                        ;;
                    *) return 0 ;;
                esac
            }

            _manager_display="$(manager_value DISPLAY)"
            if valid_display "$_manager_display"; then
                export DISPLAY="$_manager_display"
            elif ! valid_display "$DISPLAY"; then
                unset DISPLAY
                for _x in /tmp/.X11-unix/X*; do
                    [ -S "$_x" ] || continue
                    [ "$(stat -c %u "$_x" 2>/dev/null)" = "$(id -u)" ] || continue
                    export DISPLAY=":$(basename "$_x" | sed 's/^X//')"
                    break
                done
            fi

            valid_wayland_display() {
                _wayland_display="$1"
                [ -n "$_wayland_display" ] || return 1
                case "$_wayland_display" in
                    /*) [ -S "$_wayland_display" ] ;;
                    *) [ -n "$XDG_RUNTIME_DIR" ] && [ -S "$XDG_RUNTIME_DIR/$_wayland_display" ] ;;
                esac
            }

            _manager_wayland="$(manager_value WAYLAND_DISPLAY)"
            if valid_wayland_display "$_manager_wayland"; then
                export WAYLAND_DISPLAY="$_manager_wayland"
            elif ! valid_wayland_display "$WAYLAND_DISPLAY"; then
                unset WAYLAND_DISPLAY
                for _wayland in "$XDG_RUNTIME_DIR"/wayland-[0-9]*; do
                    [ -S "$_wayland" ] || continue
                    export WAYLAND_DISPLAY="$(basename "$_wayland")"
                    break
                done
            fi

            # Recommended by xwayland-satellite for Java/AWT clients. Keep an
            # explicit user value authoritative.
            import_if_missing _JAVA_AWT_WM_NONREPARENTING
            if valid_display "$DISPLAY" && [ -z "$_JAVA_AWT_WM_NONREPARENTING" ]; then
                export _JAVA_AWT_WM_NONREPARENTING=1
            fi
            systemd_run="$1"
            desc="$2"
            workdir="$3"
            shift 3

            if [ -n "$workdir" ] && [ -d "$workdir" ]; then
                cd -- "$workdir" || true
            fi

            if [ -x "$systemd_run" ] && [ -S "$XDG_RUNTIME_DIR/systemd/private" ]; then
                if [ -n "$desc" ]; then
                    exec "$systemd_run" --user --quiet --collect --same-dir --scope \
                        --description="$desc" -- "$@"
                fi
                exec "$systemd_run" --user --quiet --collect --same-dir --scope -- "$@"
            fi
            exec "$@"
        `
        Quickshell.execDetached([root.bashPath, "-lc", script, "inir-scope", root.systemdRunPath, desc, workDir, ...argv])
    }

    function execCmd(cmd: string, workingDirectory = ""): void {
        const c = String(cmd ?? "").trim()
        if (c.length === 0) return

        if (supportsFish()) {
            root.execDetachedArgs([root.fishPath, "-c", c], "", workingDirectory)
            return
        }

        root.execDetachedArgs([root.bashPath, "-lc", c], "", workingDirectory)
    }

    function execFishOrBashOneLiner(fishCmd: string, bashCmd: string): void {
        const f = String(fishCmd ?? "").trim()
        const b = String(bashCmd ?? "").trim()

        if (supportsFish()) {
            if (f.length === 0) return
            root.execDetachedArgs([root.fishPath, "-c", f])
            return
        }

        if (b.length === 0) return
        root.execDetachedArgs([root.bashPath, "-lc", b])
    }

    function launchDesktopEntry(desktopId: string, description = ""): bool {
        const id = String(desktopId ?? "").trim().replace(/\.desktop$/, "")
        if (id.length === 0) return false
        root.execDetachedArgs([root.gtkLaunchPath, id], description.length > 0 ? description : `Launch ${id}`)
        return true
    }

    function writeFileViaShell(path: string, content: string): void {
        const p = String(path ?? "").trim()
        if (p.length === 0) return

        const escapedContent = StringUtils.shellSingleQuoteEscape(content ?? "")
        const escapedPath = StringUtils.shellSingleQuoteEscape(p)
        const bash = "printf '%s' '" + escapedContent + "' > '" + escapedPath + "'"

        if (supportsFish()) {
            Quickshell.execDetached([root.fishPath, "-c", bash])
            return
        }

        Quickshell.execDetached([root.bashPath, "-lc", bash])
    }
}
