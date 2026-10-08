pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services

// Hands the shell's own surface and accent to the colour pipeline, so terminals and apps match the shell.
Item {
    id: root
    visible: false

    readonly property string path: `${Directories.stateUserPath}/generated/iris-surface.json`
    // The wallpaper colour theme only: a preset is its own palette. The Theme material reads the scheme's own background
    // from iris-seeds.json (IrisWashi), not the paper handed over here, so it wears the person's choices like any other.
    readonly property bool wanted: ThemeService.irisMaterialApps && ThemeService.isAutoTheme
    readonly property string seed: root.wanted ? root.hex(IrisStyle.appsSurface) : ""
    readonly property bool accentWanted: ThemeService.panelFamily === "iris" && ThemeService.isAutoTheme && IrisStyle.appsShareAccent
    readonly property string accent: root.accentWanted ? root.hex(IrisStyle.appsAccent) : ""
    // The palette's own app roles (IrisWashi): with them the apps wear the shell's paper, ink and accent exactly.
    readonly property string roles: root.wanted ? JSON.stringify(IrisStyle.washi?.apps ?? ({})) : "{}"
    readonly property string key: root.seed + "|" + root.accent + "|" + root.roles
    // Glass waits for the wallpaper to be read: until then the seed is only the bare material.
    readonly property bool ready: !root.wanted || IrisStyle.appsSurfaceReady
    property string applied: ""
    property bool loaded: false

    function hex(c: color): string {
        const part = v => ("0" + Math.round(v * 255).toString(16)).slice(-2)
        return "#" + part(c.r) + part(c.g) + part(c.b)
    }

    // A slider or a scheme switch settles before the pipeline runs once: the apps are recoloured by a full generation.
    Timer {
        id: settle
        interval: 350
        onTriggered: root.push()
    }
    function push(): void {
        if (!root.loaded || !root.ready || root.key === root.applied) return
        root.applied = root.key
        const body = JSON.stringify({ seed: root.seed, accent: root.accent, roles: JSON.parse(root.roles) })
        Quickshell.execDetached(["/usr/bin/bash", "-c", 'mkdir -p "$(dirname "$1")" && printf \'%s\\n\' "$2" > "$1"',
            "iris-surface", root.path, body])
        ThemeService.regenerateAutoTheme()
    }
    onKeyChanged: if (root.loaded) settle.restart()
    onReadyChanged: if (root.loaded && root.ready) settle.restart()
    // What the apps wait for (MaterialThemeLoader holds them until a generation carries it); "pending" never matches.
    Binding { target: ThemeService; property: "appsSurfaceSeed"; value: root.ready ? root.seed : "pending" }

    FileView {
        path: root.path
        printErrors: false
        onLoaded: {
            try {
                const saved = JSON.parse(text())
                root.applied = String(saved.seed ?? "") + "|" + String(saved.accent ?? "") + "|" + JSON.stringify(saved.roles ?? {})
            } catch (e) { root.applied = "" }
            root.loaded = true
            if (root.key !== root.applied) settle.restart()
        }
        onLoadFailed: {
            root.applied = ""
            root.loaded = true
            if (root.key !== "||{}") settle.restart()
        }
    }
}
