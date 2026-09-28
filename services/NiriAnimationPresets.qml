pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.services

/**
 * Niri animation presets. Shipped ones are read from the running iNiR
 * (defaults/niri-animation-presets.json), extra ones from
 * ~/.config/inir/niri-animation-presets.json. The truth is the animations block
 * of config.d/60-animations.kdl, which niri-config.py rewrites and matches back
 * to a preset ("" = custom).
 */
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/niri-config.py")
    readonly property string animationsFile: FileUtils.trimFileProtocol(`${Directories.config}/niri/config.d/60-animations.kdl`)
    readonly property string userPresetsFile: FileUtils.trimFileProtocol(`${Directories.shellConfig}/niri-animation-presets.json`)

    property bool wanted: false
    property bool loaded: false
    property bool applying: false
    property string error: ""
    property var presets: []
    property string activeId: ""
    property string defaultId: ""
    property string pendingId: ""

    readonly property var activePreset: presets.find(p => p.id === activeId) ?? null

    signal applied(string id)

    function ensure(): void {
        if (!CompositorService.isNiri) return
        wanted = true
        refresh()
    }

    function refresh(): void {
        if (!wanted) return
        if (listProcess.running) refreshDebounce.restart()
        else listProcess.running = true
    }

    function apply(id: string): bool {
        if (!CompositorService.isNiri || applying) return false
        if (loaded && !presets.some(p => p.id === id)) return false
        wanted = true
        error = ""
        pendingId = id
        applying = true
        applyProcess.command = ["python3", root.script, "apply-animation-preset", id]
        applyProcess.running = true
        return true
    }

    function preset(id: string): var {
        return presets.find(p => p.id === id) ?? null
    }

    // ── Preview math: the same curves and springs Niri runs ───────────────

    function curveValue(spec, x: real): real {
        const t = Math.max(0, Math.min(1, x))
        const curve = spec?.curve ?? "ease-out-expo"
        if (curve === "linear") return t
        if (curve === "ease-out-quad") return 1 - (1 - t) * (1 - t)
        if (curve === "ease-out-cubic") return 1 - Math.pow(1 - t, 3)
        if (curve === "cubic-bezier") return bezierValue(spec["curve-args"] ?? [0.25, 0.1, 0.25, 1], t)
        return t >= 1 ? 1 : 1 - Math.pow(2, -10 * t)
    }

    function bezierValue(args, x: real): real {
        const [x1, y1, x2, y2] = args
        const bx = s => 3 * (1 - s) * (1 - s) * s * x1 + 3 * (1 - s) * s * s * x2 + s * s * s
        let lo = 0, hi = 1, s = x
        for (let i = 0; i < 24; i++) {
            s = (lo + hi) / 2
            if (bx(s) < x) lo = s
            else hi = s
        }
        return 3 * (1 - s) * (1 - s) * s * y1 + 3 * (1 - s) * s * s * y2 + s * s * s
    }

    function springValue(spec, seconds: real): real {
        const [zeta, stiffness] = spec?.spring ?? [1, 800]
        const w = Math.sqrt(stiffness)
        const t = Math.max(0, seconds)
        if (zeta < 1) {
            const wd = w * Math.sqrt(1 - zeta * zeta)
            return 1 - Math.exp(-zeta * w * t) * (Math.cos(wd * t) + zeta * w / wd * Math.sin(wd * t))
        }
        if (zeta === 1) return 1 - (1 + w * t) * Math.exp(-w * t)
        const r = w * Math.sqrt(zeta * zeta - 1)
        const a = -zeta * w + r, b = -zeta * w - r
        return 1 - (b * Math.exp(a * t) - a * Math.exp(b * t)) / (b - a)
    }

    function springSeconds(spec): real {
        const epsilon = (spec?.spring ?? [])[2] ?? 0.0001
        for (let t = 0; t < 2; t += 0.004) {
            if (Math.abs(1 - springValue(spec, t)) < Math.max(epsilon, 0.002) && Math.abs(1 - springValue(spec, t + 0.05)) < Math.max(epsilon, 0.002))
                return t
        }
        return 2
    }

    function easingSeconds(spec): real {
        return (spec?.["duration-ms"] ?? 150) / 1000
    }

    // One demo loop: a window opens, slides one column over and back, closes.
    // Returns { opacity, scale, x (0..1 of travel), done }.
    function demoFrame(presetData, seconds: real): var {
        const types = presetData?.types ?? {}
        const open = types["window-open"], move = types["horizontal-view-movement"], close = types["window-close"]
        const openS = easingSeconds(open), moveS = Math.min(springSeconds(move), 1.2), closeS = easingSeconds(close)
        const hold = 0.35
        let t = seconds
        if (t < openS) {
            const p = curveValue(open, t / openS)
            return { opacity: Math.min(1, Math.max(0, p)), scale: 0.86 + 0.14 * p, x: 0, done: false }
        }
        t -= openS + hold
        if (t < 0) return { opacity: 1, scale: 1, x: 0, done: false }
        if (t < moveS) return { opacity: 1, scale: 1, x: springValue(move, t), done: false }
        t -= moveS + hold
        if (t < 0) return { opacity: 1, scale: 1, x: 1, done: false }
        if (t < moveS) return { opacity: 1, scale: 1, x: 1 - springValue(move, t), done: false }
        t -= moveS + hold
        if (t < 0) return { opacity: 1, scale: 1, x: 0, done: false }
        if (t < closeS) {
            const p = curveValue(close, t / closeS)
            return { opacity: 1 - p, scale: 1 - 0.06 * p, x: 0, done: false }
        }
        return { opacity: 0, scale: 0.94, x: 0, done: t - closeS > 0.4 }
    }

    // Time for the window to be 90 % there when it opens, in ms.
    function openFeelMs(presetData): int {
        const open = presetData?.types?.["window-open"]
        if (!open) return 0
        for (let i = 1; i <= 200; i++) {
            if (curveValue(open, i / 200) >= 0.9) return Math.round(easingSeconds(open) * 1000 * i / 200)
        }
        return Math.round(easingSeconds(open) * 1000)
    }

    Process {
        id: listProcess
        command: ["python3", root.script, "get-animation-presets"]
        stdout: StdioCollector {
            id: listOutput
            onStreamFinished: {
                try {
                    const data = JSON.parse(listOutput.text)
                    root.presets = data.presets ?? []
                    root.defaultId = data.default ?? ""
                    root.activeId = data.active ?? ""
                    root.loaded = true
                } catch (e) {
                    root.error = "Could not read animation presets"
                    console.warn("[NiriAnimationPresets] Bad preset list:", e)
                }
            }
        }
    }

    Process {
        id: applyProcess
        stdout: StdioCollector {
            id: applyOutput
            onStreamFinished: {
                let result = {}
                try { result = JSON.parse(applyOutput.text) } catch (e) {}
                root.applying = false
                if (result.success) {
                    root.activeId = root.pendingId
                    root.applied(root.pendingId)
                } else {
                    root.error = result.error ?? "Niri rejected the preset"
                    console.warn("[NiriAnimationPresets] Apply failed:", root.error)
                }
                root.refresh()
            }
        }
    }

    Timer {
        id: refreshDebounce
        interval: 250
        onTriggered: root.refresh()
    }

    FileView {
        path: root.wanted ? root.animationsFile : ""
        watchChanges: true
        onFileChanged: refreshDebounce.restart()
    }

    FileView {
        path: root.wanted ? root.userPresetsFile : ""
        watchChanges: true
        printErrors: false
        onFileChanged: refreshDebounce.restart()
    }

    IpcHandler {
        target: "niriAnimations"

        function list(): string {
            root.ensure()
            if (!root.loaded) return "loading, ask again"
            return root.presets.map(p => (p.id === root.activeId ? "* " : "  ") + p.id + "  " + p.name + " · " + p.description).join("\n")
        }
        function active(): string {
            root.ensure()
            if (!root.loaded) return "loading"
            return root.activeId.length > 0 ? root.activeId : "custom"
        }
        function apply(id: string): string {
            return root.apply(id) ? "applying " + id : "unknown or busy: " + id
        }
    }
}
