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

    function execDetachedArgs(args, description = ""): void {
        const argv = Array.from(args ?? []).map(arg => String(arg ?? "")).filter(arg => arg.length > 0)
        if (argv.length === 0) return

        const desc = String(description ?? "").trim()
        // A transient scope, never a service. Launchers like zeditor and
        // /usr/bin/code fork the real process and exit immediately; a service
        // treats that first exit as the unit finishing and kills the rest of
        // the cgroup, so the app dies the instant it starts. A scope lives as
        // long as any process in it. systemd-run is exec'd rather than tested
        // for success, because in scope mode it only returns once the app is
        // gone and a fallback there would relaunch it.
        const script = `
            systemd_run="$1"
            desc="$2"
            shift 2
            if [ -x "$systemd_run" ] && [ -S "$XDG_RUNTIME_DIR/systemd/private" ]; then
                if [ -n "$desc" ]; then
                    exec "$systemd_run" --user --quiet --collect --same-dir --scope \
                        --description="$desc" -- "$@"
                fi
                exec "$systemd_run" --user --quiet --collect --same-dir --scope -- "$@"
            fi
            exec "$@"
        `
        Quickshell.execDetached([root.bashPath, "-lc", script, "inir-scope", root.systemdRunPath, desc, ...argv])
    }

    function execCmd(cmd: string): void {
        const c = String(cmd ?? "").trim()
        if (c.length === 0) return

        if (supportsFish()) {
            root.execDetachedArgs([root.fishPath, "-c", c])
            return
        }

        root.execDetachedArgs([root.bashPath, "-lc", c])
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
