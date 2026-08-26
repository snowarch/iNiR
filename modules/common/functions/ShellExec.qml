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

    // Restore session environment from systemd manager before launching apps
    readonly property string _envRestoreScript: `
        manager_env=""
        if [ -x /usr/bin/systemctl ]; then
            if [ -x /usr/bin/timeout ]; then
                manager_env="$(/usr/bin/timeout 1s /usr/bin/systemctl --user show-environment 2>/dev/null || true)"
            else
                manager_env="$(/usr/bin/systemctl --user show-environment 2>/dev/null || true)"
            fi
        fi

        declare -A _mgr_map
        if [ -n "$manager_env" ]; then
            while IFS='=' read -r _k _v; do
                [ -n "$_k" ] && _mgr_map["$_k"]="$_v"
            done <<< "$manager_env"
        fi

        manager_value() {
            printf '%s' "\${_mgr_map[\$1]:-}"
        }

        restore_from_manager() {
            local _name="$1"
            if [[ -v _mgr_map["$_name"] ]]; then
                export "$_name=\${_mgr_map[\$_name]}"
            else
                unset "$_name"
            fi
        }

        import_if_missing() {
            local _name="$1"
            [[ -v $_name ]] && return 0
            [[ -v _mgr_map["$_name"] ]] && export "$_name=\${_mgr_map[\$_name]}"
        }

        for _var in \
            QT_SCALE_FACTOR QT_SCALE_FACTOR_ROUNDING_POLICY \
            QT_WAYLAND_FORCE_DPI QT_FONT_DPI QT_AUTO_SCREEN_SCALE_FACTOR \
            QT_SCREEN_SCALE_FACTORS GDK_SCALE GDK_DPI_SCALE \
            QSG_ATLAS_WIDTH QSG_ATLAS_HEIGHT QT_LOGGING_RULES \
            QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE QS_DISABLE_CRASH_HANDLER; do
            restore_from_manager "$_var"
        done

        for _var in $INIR_SHELL_GPU_POLICY_VARS; do
            restore_from_manager "$_var"
        done
        unset INIR_SHELL_GPU_POLICY_VARS INIR_DISABLE_HOT_RELOAD

        for _var in \
            XDG_RUNTIME_DIR XDG_SESSION_TYPE XDG_CURRENT_DESKTOP \
            XDG_SESSION_DESKTOP DESKTOP_SESSION XCURSOR_THEME XCURSOR_SIZE \
            LANG LC_ALL XDG_MENU_PREFIX GDK_BACKEND XAUTHORITY \
            DBUS_SESSION_BUS_ADDRESS SSH_AUTH_SOCK ELECTRON_OZONE_PLATFORM_HINT; do
            import_if_missing "$_var"
        done
        [ -n "$WAYLAND_DISPLAY" ] && [ -z "$ELECTRON_OZONE_PLATFORM_HINT" ] && export ELECTRON_OZONE_PLATFORM_HINT=auto

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

        valid_display() {
            local _disp="$1"
            [ -n "$_disp" ] || return 1
            case "$_disp" in
                :*)
                    local _xnum="\${_disp%%.*}"
                    _xnum="\${_xnum#:}"
                    case "$_xnum" in
                        ''|*[!0-9]*) return 1 ;;
                    esac
                    local _xsock="/tmp/.X11-unix/X$_xnum"
                    [ -S "$_xsock" ] && [ -O "$_xsock" ]
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
                [ -S "$_x" ] && [ -O "$_x" ] || continue
                local _xfile="\${_x##*/}"
                export DISPLAY=":\${_xfile#X}"
                break
            done
        fi

        valid_wayland_display() {
            local _wdisp="$1"
            [ -n "$_wdisp" ] || return 1
            case "$_wdisp" in
                /*) [ -S "$_wdisp" ] ;;
                *) [ -n "$XDG_RUNTIME_DIR" ] && [ -S "$XDG_RUNTIME_DIR/$_wdisp" ] ;;
            esac
        }

        _manager_wayland="$(manager_value WAYLAND_DISPLAY)"
        if valid_wayland_display "$_manager_wayland"; then
            export WAYLAND_DISPLAY="$_manager_wayland"
        elif ! valid_wayland_display "$WAYLAND_DISPLAY"; then
            unset WAYLAND_DISPLAY
            for _wayland in "$XDG_RUNTIME_DIR"/wayland-[0-9]*; do
                [ -S "$_wayland" ] || continue
                export WAYLAND_DISPLAY="\${_wayland##*/}"
                break
            done
        fi

        import_if_missing _JAVA_AWT_WM_NONREPARENTING
        if valid_display "$DISPLAY" && [ -z "$_JAVA_AWT_WM_NONREPARENTING" ]; then
            export _JAVA_AWT_WM_NONREPARENTING=1
        fi
    `

    // Run command in a transient systemd user scope
    function launch(opts: var): void {
        const program = String(opts?.program ?? "").trim()
        const args = Array.from(opts?.args ?? []).map(arg => String(arg ?? "")).filter(arg => arg.length > 0)
        if (program.length === 0) return

        const scopeName = String(opts?.scope ?? "app").trim().toLowerCase().replace(/[^a-z0-9_.-]/g, "-")
        const description = String(opts?.description ?? "").trim()
        const desc = description.length > 0 ? description : scopeName
        const workDir = String(opts?.workingDirectory ?? "").trim()
        const unitPrefix = `inir-${scopeName}`

        const script = root._envRestoreScript + `
            systemd_run="$1"
            desc="$2"
            unit_prefix="$3"
            workdir="$4"
            shift 4
            unit="\${unit_prefix}-\$\$"

            if [ -n "$workdir" ] && [ -d "$workdir" ]; then
                cd -- "$workdir" || true
            fi

            if [ -x "$systemd_run" ] && [ -S "$XDG_RUNTIME_DIR/systemd/private" ]; then
                exec "$systemd_run" --user --quiet --collect --same-dir --scope \
                    --unit="$unit" --description="$desc" -- "$@"
            fi
            exec "$@"
        `
        Quickshell.execDetached([root.bashPath, "-c", script, "inir-scope", root.systemdRunPath, desc, unitPrefix, workDir, program, ...args])
        console.debug(`[launcher] scope=${scopeName} cmd=${program} args=[${args.join(", ")}]`)
    }

    // Run foreground daemon in a transient systemd service
    function launchDaemon(opts: var): void {
        const program = String(opts?.program ?? "").trim()
        const args = Array.from(opts?.args ?? []).map(arg => String(arg ?? "")).filter(arg => arg.length > 0)
        if (program.length === 0) return

        const scopeName = String(opts?.scope ?? "app").trim().toLowerCase().replace(/[^a-z0-9_.-]/g, "-")
        const description = String(opts?.description ?? "").trim()
        const desc = description.length > 0 ? description : scopeName
        const restart = String(opts?.restart ?? "").trim()
        const ifActive = String(opts?.ifActive ?? "replace").trim() || "replace"
        const unitName = `inir-${scopeName}`

        const script = root._envRestoreScript + `
            systemd_run="$1"; desc="$2"; unit="$3"; restart_prop="$4"; if_active="$5"; program="$6"; shift 6

            if [[ "$program" = /* ]]; then
                bin_path="$program"
            else
                bin_path="$(type -P "$program" 2>/dev/null || command -v "$program" 2>/dev/null || true)"
            fi

            if [ -z "$bin_path" ] || [ ! -x "$bin_path" ]; then
                echo "[launcher] binary '$program' not found or not executable" >&2
                exit 127
            fi

            if ! command -v systemctl >/dev/null 2>&1 || ! command -v "$systemd_run" >/dev/null 2>&1 || [ ! -S "$XDG_RUNTIME_DIR/systemd/private" ]; then
                exec "$bin_path" "$@"
            fi

            if systemctl --user is-active --quiet "$unit" 2>/dev/null; then
                if [ "$if_active" = "reuse" ]; then
                    exit 0
                fi
                systemctl --user stop "$unit" >/dev/null 2>&1 || true
            fi

            # Clear failed unit state
            systemctl --user reset-failed "$unit" >/dev/null 2>&1 || true

            extra_args=(
                -E "PATH=$PATH"
                -E "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
                -E "DISPLAY=$DISPLAY"
                -E "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
            )
            if [ -n "$restart_prop" ]; then
                extra_args+=(--property="Restart=$restart_prop")
            fi

            output=$("$systemd_run" --user --quiet --collect --unit="$unit" --description="$desc" \
                    "\${extra_args[@]}" -- "$bin_path" "$@" 2>&1)
            status=$?

            if [ $status -eq 0 ]; then
                exit 0
            fi

            if systemctl --user is-active --quiet "$unit" 2>/dev/null; then
                exit 0
            fi

            echo "[launcher] systemd-run failed to start service $unit: $output" >&2
            exit 1
        `
        Quickshell.execDetached([root.bashPath, "-c", script, "inir-daemon", root.systemdRunPath, desc, unitName, restart, ifActive, program, ...args])
        console.debug(`[launcher] daemon=${scopeName} cmd=${program} args=[${args.join(", ")}]`)
    }

    readonly property var _privilegedGuiTable: [
        { basename: "gparted", wrap: true, injectQt5: false, prefix: false },
        { basename: "ventoygui", wrap: true, injectQt5: true, prefix: true }
    ]

    function privilegedGuiArgv(command: var): var {
        const argv = Array.from(command ?? []).map(arg => String(arg ?? "")).filter(arg => arg.length > 0)
        if (argv.length === 0) return argv
        const base = argv[0].split("/").pop().toLowerCase()
        let match = null
        for (let i = 0; i < root._privilegedGuiTable.length; i++) {
            const row = root._privilegedGuiTable[i]
            if (base === row.basename || (row.prefix && base.startsWith(row.basename + "."))) {
                match = row
                break
            }
        }
        if (!match || !match.wrap) return argv
        let graphical = argv
        if (match.injectQt5) {
            const hasFrontend = argv.slice(1).some(arg => /^--(gtk[234]|qt[456])$/.test(arg.toLowerCase()))
            if (!hasFrontend)
                graphical = [argv[0], "--qt5", ...argv.slice(1)]
        }
        return [`${Directories.scriptsPath}/launch-privileged-gui.sh`, ...graphical]
    }

    function execDetachedArgs(args, description = "", workingDirectory = ""): void {
        const argv = Array.from(args ?? []).map(arg => String(arg ?? "")).filter(arg => arg.length > 0)
        if (argv.length === 0) return
        root.launch({
            program: argv[0],
            args: argv.slice(1),
            scope: "app",
            description,
            workingDirectory
        })
    }

    function execCmd(cmd: string, workingDirectory = ""): void {
        const c = String(cmd ?? "").trim()
        if (c.length === 0) return

        if (supportsFish()) {
            root.launch({ program: root.fishPath, args: ["-c", c], scope: "app", workingDirectory })
            return
        }

        root.launch({ program: root.bashPath, args: ["-lc", c], scope: "app", workingDirectory })
    }

    function execFishOrBashOneLiner(fishCmd: string, bashCmd: string): void {
        const f = String(fishCmd ?? "").trim()
        const b = String(bashCmd ?? "").trim()
        const useFish = supportsFish()
        const cmd = useFish ? f : b
        if (cmd.length === 0) return

        root.launch({
            program: useFish ? root.fishPath : root.bashPath,
            args: [useFish ? "-c" : "-lc", cmd],
            scope: "app"
        })
    }

    function launchDesktopEntry(desktopId: string, description = ""): bool {
        const id = String(desktopId ?? "").trim().replace(/\.desktop$/, "")
        if (id.length === 0) return false
        root.launch({ program: root.gtkLaunchPath, args: [id], scope: "app", description: description.length > 0 ? description : `Launch ${id}` })
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
