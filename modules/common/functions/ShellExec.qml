pragma Singleton

import QtQml

import Quickshell
import Quickshell.Io

import qs.modules.common
import qs.services

Singleton {
    id: root

    readonly property string fishPath: "fish"
    readonly property string bashPath: "bash"
    readonly property string systemdRunPath: "systemd-run"
    readonly property string gtkLaunchPath: "gtk-launch"

    // -1 unknown, 0 no, 1 yes
    property int _fishAvailable: -1

    Process {
        id: fishCheckProc
        command: ["sh", "-c", "command -v fish >/dev/null"]
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

    // A standalone window (Settings, the welcome) is a process of its own holding some of the shell's services: its
    // calls must reach the shell, never that window's copy of a handler.
    readonly property bool _inShell: Quickshell.env("INIR_STANDALONE_WINDOW") !== "1"

    // `inir TARGET FUNCTION ARGS...`, the shell calling one of its own IpcHandlers. In the shell on qs-rs it runs in
    // process (Ipc.call): no process, no socket. Elsewhere the binary makes the call (`inir ipc`, which no command
    // name shadows).
    function ipc(target: string, fn: string, args = []): void {
        const words = Array.from(args ?? []).map(String)
        if (root._inShell && SystemInfo.runtimeHas(["ipc-call"]) && Ipc.call(target, fn, words))
            return
        Quickshell.execDetached([Directories.inir, "ipc", target, fn, ...words])
    }

    // `inir COMMAND ARGS...`, a command of the inir binary (settings-window, hub, service, kill-dialog...).
    function inir(args): void {
        Quickshell.execDetached([Directories.inir, ...Array.from(args ?? []).map(String)])
    }

    function execDetachedArgs(args, description = "", workingDirectory = ""): void {
        const argv = Array.from(args ?? []).map(arg => String(arg ?? "")).filter(arg => arg.length > 0)
        if (argv.length === 0) return

        const desc = String(description ?? "").trim()
        const workDir = String(workingDirectory ?? "").trim()

        // The compositor (Niri or Umbriel) starts it, exactly as it starts a keybind's command: from the session's
        // own environment (never the shell's Qt scaling, allocator or GPU policy), in the compositor's transient
        // scope, with an activation token. The shell writes one line to the socket it already holds: no shell, no
        // environment rebuild and no systemd-run round trip before the app runs (~60 ms a launch before). Neither
        // compositor takes a working directory, so a Path= entry goes through a one-line sh.
        const command = workDir.length > 0
            ? ["sh", "-c", 'cd -- "$1" 2>/dev/null; shift; exec "$@"', "inir-launch", workDir, ...argv]
            : argv
        // Java (AWT) apps on xwayland-satellite draw blank windows without it. The compositor's environment carries it
        // on fresh installs (the launcher mirrors Niri's into the shell); an older config lacks it, so the launch adds it.
        const spawned = String(Quickshell.env("_JAVA_AWT_WM_NONREPARENTING") ?? "").length > 0
            ? command
            : ["env", "_JAVA_AWT_WM_NONREPARENTING=1", ...command]
        if (NiriService.spawn(spawned))
            return

        // No compositor socket is open (another compositor, or it is still connecting): start it from here.
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
            # The socket exists only while the user manager runs: a probe that
            # times out means a busy manager, still systemd, and an app left out
            # of its scope would die with the shell's own unit.
            manager_env=""
            systemd_user_manager_usable=false
            if [ -S "\${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/systemd/private" ] &&
               command -v systemctl >/dev/null && command -v timeout >/dev/null; then
                manager_env="$(timeout 3s systemctl --user show-environment 2>/dev/null)"
                case $? in 0|124) systemd_user_manager_usable=true ;; esac
            fi

            # One pass over the manager's environment into a table that every
            # lookup below reads in place (a subshell per variable cost ~30 ms).
            declare -A manager=()
            while IFS='=' read -r _key _entry_value; do
                [ -n "$_key" ] && manager[$_key]="$_entry_value"
            done <<< "$manager_env"

            restore_from_manager() {
                if [ -n "\${manager[$1]-}" ]; then
                    export "$1=\${manager[$1]}"
                else
                    unset "$1"
                fi
            }

            import_if_missing() {
                [[ -v $1 ]] && return 0
                [ -n "\${manager[$1]-}" ] && export "$1=\${manager[$1]}"
            }

            # apply_shell_scale()/apply_qt_runtime_env() own these for iNiR's
            # process only. Never leak them into launched applications.
            for _var in \
                QT_SCALE_FACTOR QT_SCALE_FACTOR_ROUNDING_POLICY \
                QT_WAYLAND_FORCE_DPI QT_FONT_DPI QT_AUTO_SCREEN_SCALE_FACTOR \
                QT_SCREEN_SCALE_FACTORS GDK_SCALE GDK_DPI_SCALE \
                QSG_ATLAS_WIDTH QSG_ATLAS_HEIGHT QT_LOGGING_RULES \
                QS_DISABLE_CRASH_HANDLER MALLOC_CONF mesa_glthread DRIRC_CONFIGDIR; do
                restore_from_manager "$_var"
            done

            # These are application/session policy, not Quickshell-private
            # tuning. The iNiR launcher mirrors the effective Niri config into
            # Quickshell before startup; only fill a missing value from the
            # manager and never override Niri's authoritative app policy.
            for _var in QT_QPA_PLATFORM QT_QPA_PLATFORMTHEME QT_STYLE_OVERRIDE \
                        ELECTRON_OZONE_PLATFORM_HINT; do
                import_if_missing "$_var"
            done

            # The launcher marks exactly which GPU variables iNiR injected for
            # the shell. Restore user values (or unset them) before games/apps.
            for _var in $INIR_SHELL_GPU_POLICY_VARS; do
                restore_from_manager "$_var"
            done
            unset INIR_SHELL_GPU_POLICY_VARS INIR_DISABLE_HOT_RELOAD INIR_CLI INIR_BASH_LAUNCHER

            # Fill missing user/session values from the live user manager rather
            # than trusting Quickshell's process snapshot.
            for _var in \
                XDG_RUNTIME_DIR XDG_SESSION_TYPE XDG_CURRENT_DESKTOP \
                XDG_SESSION_DESKTOP DESKTOP_SESSION XCURSOR_THEME XCURSOR_SIZE \
                LANG LC_ALL XDG_MENU_PREFIX GDK_BACKEND XAUTHORITY \
                DBUS_SESSION_BUS_ADDRESS SSH_AUTH_SOCK; do
                import_if_missing "$_var"
            done

            _manager_path="\${manager[PATH]-}"
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

            # The compositor (Niri or Umbriel) owns this environment. Prefer the values it
            # published to the user manager, but preserve an inherited value
            # for manual invocations where the manager has no session snapshot.
            for _var in DISPLAY WAYLAND_DISPLAY NIRI_SOCKET UMBRIEL_SOCKET; do
                [ -n "\${manager[$_var]-}" ] && export "$_var=\${manager[$_var]}"
            done

            # The shell on its own Qt (qs-rs) runs without the session's Qt plugin and QML paths, built for another
            # Qt (Nix sets them): apps get the session's back.
            for _var in QT_PLUGIN_PATH QML2_IMPORT_PATH QML_IMPORT_PATH; do
                [ -n "\${manager[$_var]-}" ] && export "$_var=\${manager[$_var]}"
            done

            # Recommended by xwayland-satellite for Java/AWT clients. Keep an
            # explicit user value authoritative.
            import_if_missing _JAVA_AWT_WM_NONREPARENTING
            if [ -n "$DISPLAY" ] && [ -z "$_JAVA_AWT_WM_NONREPARENTING" ]; then
                export _JAVA_AWT_WM_NONREPARENTING=1
            fi
            systemd_run="$1"
            desc="$2"
            workdir="$3"
            shift 3

            if [ -n "$workdir" ] && [ -d "$workdir" ]; then
                cd -- "$workdir" || true
            fi

            if command -v "$systemd_run" >/dev/null && [ "$systemd_user_manager_usable" = true ]; then
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

    function openDirectory(path: string, description: string): void {
        const target = String(path ?? "").trim()
        if (target.length === 0) return

        const script = `
            target="$1"
            desktop_id="$(xdg-mime query default inode/directory 2>/dev/null || true)"
            case "$desktop_id" in
                ""|kitty-open*|*terminal*|foot*|alacritty*|konsole*|xterm*|wezterm*)
                    desktop_id=""
                    for candidate in org.gnome.Nautilus org.kde.dolphin thunar nemo pcmanfm-qt; do
                        if [ -f "/usr/share/applications/$candidate.desktop" ]; then
                            desktop_id="$candidate"
                            break
                        fi
                    done
                    ;;
                *) desktop_id="\${desktop_id%.desktop}" ;;
            esac

            if [ -n "$desktop_id" ] && command -v gtk-launch >/dev/null 2>&1; then
                exec gtk-launch "$desktop_id" "$target"
            fi
            exec xdg-open "$target"
        `
        root.execDetachedArgs([root.bashPath, "-lc", script, "inir-open-directory", target], description)
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
