pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.iris.style
import qs.modules.iris.frame

// Measures a Place's open, close and mid-way reversal from the frames the Place itself samples (`IrisMorphSurface` feeds `sample`).
// Driven by `inir iris motion <target>` and read back with `inir iris motioned`.
Singleton {
    id: root

    readonly property var targets: ({
        spotlight: { surface: "spotlight", open: () => GlobalStates.searchOpen = true, close: () => GlobalStates.searchOpen = false },
        orbit: { surface: "orbit", open: () => GlobalStates.irisOrbitOpen = true, close: () => GlobalStates.irisOrbitOpen = false },
        gallery: { surface: "gallery", open: () => GlobalStates.wallpaperSelectorOpen = true, close: () => GlobalStates.wallpaperSelectorOpen = false },
        settings: { surface: "settings", open: () => GlobalStates.openSettings(), close: () => GlobalStates.settingsOverlayOpen = false },
        focus: { surface: "panels", open: () => GlobalStates.openSidebarLeft(GlobalStates.focusedScreen?.name ?? ""), close: () => GlobalStates.closeSidebarLeft() },
        today: { surface: "panels", open: () => GlobalStates.openSidebarRight(GlobalStates.focusedScreen?.name ?? ""), close: () => GlobalStates.closeSidebarRight() },
        card: { surface: "cards", open: () => { GlobalStates.irisBubbleCardRequest = ""; GlobalStates.irisBubbleCardRequest = "media" }, close: () => GlobalStates.irisBubbleCard = null }
    })

    property string target: ""
    readonly property string surface: root.targets[root.target]?.surface ?? ""
    property string phase: ""
    property var runs: []
    property var current: null
    property var result: ({ state: "idle" })
    property real vblank: 1000 / 60
    property var chassisWindows: ({})

    function registerChassis(screen: string, window: var): void {
        const next = Object.assign({}, root.chassisWindows)
        if (window) next[screen] = window
        else delete next[screen]
        root.chassisWindows = next
    }
    function chassisOf(screen: string): var { return root.chassisWindows[screen] ?? null }

    function watching(surface: string): bool { return root.current !== null && surface === root.surface }

    // A step of the watched surface (armed, launched…), timed from the request.
    function mark(name: string): void {
        if (!root.current) return
        root.current.marks = Object.assign({}, root.current.marks ?? {}, { [name]: Date.now() - root.current.requested })
    }
    // One frame of the watched surface, as it was drawn.
    function sample(entry: var): void {
        if (!root.current) return
        root.lastSource = entry.source ?? root.lastSource
        if (entry.source) root.current.settles = entry.source.settles === true
        const frames = root.current.frames, now = Date.now(), last = frames[frames.length - 1]
        // A window can animate twice inside one refresh; the output shows at most one of those passes.
        if (last && now - last.t < root.vblank * 0.75) frames.pop()
        frames.push(Object.assign({ t: now }, entry, { source: undefined }))
    }

    Process {
        id: refresh
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const outputs = JSON.parse(text)
                    const output = outputs[GlobalStates.focusedScreen?.name ?? ""] ?? Object.values(outputs)[0]
                    const mode = output?.modes?.[output?.current_mode ?? 0]
                    if (mode?.refresh_rate > 0) root.vblank = 1000000 / mode.refresh_rate
                } catch (error) {}
            }
        }
    }

    function start(name: string): string {
        if (name.startsWith("idle")) return root.idle(Math.max(1000, Math.min(60000, Number(name.slice(5)) || 10000)))
        if (!root.targets[name]) return "Unknown target. One of: " + Object.keys(root.targets).join(", ") + ", idle:<ms>"
        if (root.phase.length > 0) return "Already measuring " + root.target
        root.target = name
        root.runs = []
        root.result = { state: "running", target: name }
        refresh.running = true
        root.targets[name].close()
        root.islandWasExpanded = GlobalStates.irisIslandExpanded
        GlobalStates.irisIslandPageRequest = "desktop"
        root.phase = "prepare"
        step.interval = 900
        step.restart()
        return "measuring:" + name
    }

    // What a panel grows from is its screen edge; everything else grows from the Island.
    function originFor(name: string): var {
        const screen = GlobalStates.focusedScreen
        if (!screen || (name !== "focus" && name !== "today")) return null
        const band = Math.max(2, IrisFrame.band) + 4
        return { x: name === "focus" ? 0 : screen.width - band, y: 0, width: band, height: screen.height }
    }
    property var lastSource: null
    property bool islandWasExpanded: false
    function begin(kind: string): void {
        root.current = { kind: kind, requested: Date.now(), frames: [], origin: root.originFor(root.target) }
    }
    function finish(): void {
        if (root.current) root.runs = root.runs.concat([root.current])
        root.current = null
    }

    // prepare → open (from the expanded Island) → close → reopen → reverse at mid-way → clean end.
    Timer {
        id: step
        onTriggered: {
            const t = root.targets[root.target]
            switch (root.phase) {
            case "prepare":
                root.begin("open")
                t.open()
                root.phase = "open"
                step.interval = 1400
                step.restart()
                break
            case "open":
                root.finish()
                root.begin("close")
                t.close()
                root.phase = "close"
                step.interval = 1200
                step.restart()
                break
            case "close":
                root.finish()
                root.begin("reverse")
                t.open()
                root.phase = "reverseOpen"
                reverseWatch.restart()
                step.interval = 2000
                step.restart()
                break
            case "reverseOpen":
            case "reverseClose":
                root.finish()
                root.phase = "clean"
                step.interval = 400
                step.restart()
                break
            case "clean":
                root.phase = ""
                root.result = root.report(t)
                if (!root.islandWasExpanded) GlobalStates.irisIslandPageRequest = "collapse"
                break
            }
        }
    }
    // Reverses once the reopening body is halfway.
    Timer {
        id: reverseWatch
        interval: 8
        repeat: true
        onTriggered: {
            const frames = root.current?.frames ?? []
            const last = frames[frames.length - 1]
            if (root.phase !== "reverseOpen") { stop(); return }
            if (last && last.presentation >= 0.5) {
                stop()
                root.current.reversedAt = Date.now()
                root.targets[root.target].close()
                root.phase = "reverseClose"
            }
        }
    }

    // The shell at rest: when frames are lost while nothing of iRiS moves.
    property var idleDrops: []
    property real idleUntil: 0
    FrameAnimation {
        id: idleWatch
        running: false
        onTriggered: {
            if (frameTime * 1000 > root.vblank * 1.5) root.idleDrops = root.idleDrops.concat([{ t: Date.now() % 100000, gap: Math.round(frameTime * 1000) }])
            if (Date.now() >= root.idleUntil) { stop(); root.result = { state: "done", target: "idle", vblank: root.vblank, drops: root.idleDrops } }
        }
    }
    function idle(ms: int): string {
        refresh.running = true
        root.idleDrops = []
        root.idleUntil = Date.now() + ms
        root.result = { state: "running", target: "idle" }
        idleWatch.restart()
        return "watching idle"
    }
    property var cleanProbe: null
    function contains(outer: var, inner: var, slack: real): bool {
        return outer && inner && inner.x >= outer.x - slack && inner.y >= outer.y - slack
            && inner.x + inner.width <= outer.x + outer.width + slack
            && inner.y + inner.height <= outer.y + outer.height + slack
    }
    function intersects(a: var, b: var): bool {
        return a && b && a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height
    }
    function area(r: var): real { return r ? Math.max(0, r.width) * Math.max(0, r.height) : 0 }

    function analyse(run: var): var {
        const frames = run.frames
        const out = { kind: run.kind, frames: frames.length, marks: run.marks ?? {} }
        if (frames.length < 2) return Object.assign(out, { error: "no frames" })
        const vb = root.vblank
        // 1. Pace: frame intervals while moving, and the time from the request to the first moved frame.
        const gaps = []
        for (let i = 1; i < frames.length; i++) {
            const settledBoth = frames[i].presentation >= 0.999 && frames[i - 1].presentation >= 0.999
            const goneBoth = frames[i].presentation <= 0.001 && frames[i - 1].presentation <= 0.001
            if (!settledBoth && !goneBoth) gaps.push(frames[i].dt ?? (frames[i].t - frames[i - 1].t))
        }
        const r0 = frames[0].rect
        const firstMoved = frames.find((f, i) => i > 0 && ["x", "y", "width", "height"].some(k => Math.abs(f.rect[k] - r0[k]) > 0.5))
        out.latency = firstMoved ? firstMoved.t - run.requested : -1
        out.gaps = gaps.slice(0, 8)
        out.maxGap = gaps.length ? Math.max(...gaps) : 0
        out.dropped = gaps.filter(g => g > vb * 1.5).length
        out.dropsAt = []
        for (let i = 1; i < frames.length; i++)
            if ((frames[i].dt ?? (frames[i].t - frames[i - 1].t)) > vb * 1.5 && !(frames[i].presentation >= 0.999 && frames[i - 1].presentation >= 0.999)
                    && !(frames[i].presentation <= 0.001 && frames[i - 1].presentation <= 0.001))
                out.dropsAt.push({ ms: frames[i].t - run.requested, gap: Math.round(frames[i].dt ?? (frames[i].t - frames[i - 1].t)),
                    from: Math.round(frames[i - 1].presentation * 1000) / 1000, to: Math.round(frames[i].presentation * 1000) / 1000 })
        out.pace = out.dropped === 0 && out.latency >= 0 && out.latency <= vb * 2 + vb * 0.5
        // 2. Continuity: no still frame mid-motion, no reversal of size against the direction.
        let stalls = 0, backwards = 0
        const opening = run.kind === "open"
        for (let i = 1; i < frames.length; i++) {
            const a = frames[i - 1], b = frames[i]
            const mid = b.presentation > 0.002 && b.presentation < 0.998
            if (mid && Math.abs(b.presentation - a.presentation) < 1e-4) stalls++
            if (run.kind !== "reverse") {
                const grew = root.area(b.rect) - root.area(a.rect)
                if (opening ? grew < -1 : grew > 1) backwards++
            }
        }
        out.stalls = stalls
        out.backwards = backwards
        out.continuity = stalls === 0 && backwards === 0
        // 3. Material: a visible body the compositor does not blur, or a blurred body fading.
        const glass = frames.some(f => f.wantsBlur)
        out.unblurred = glass ? frames.filter(f => f.opacity > 0.01 && f.rect.width > 1 && !f.blurred).length : 0
        out.blurredFading = glass ? frames.filter(f => f.blurred && f.opacity > 0.01 && f.opacity < 0.99).length : 0
        out.material = out.unblurred === 0 && out.blurredFading === 0
        // 4. One surface: the body and its content drawn by the same window.
        out.splitFrames = frames.filter(f => !f.sameWindow && f.opacity > 0.01).length
        out.surface = out.splitFrames === 0
        // 5. Origin: born inside what it grows from (the resting Island, or a side panel's own screen edge), ends
        // inside it, never over the Island.
        const island = run.origin ?? frames[0].island
        const visible = frames.filter(f => f.opacity > 0.01 && f.rect.width > 1)
        out.startsInOrigin = run.kind === "close" ? true : root.contains(island, visible[0]?.rect, 2)
        out.endsInOrigin = run.kind === "open" ? true : root.contains(island, visible[visible.length - 1]?.rect, 2)
        out.coversIsland = frames.filter(f => f.above && f.opacity > 0.01 && root.intersects(f.rect, f.island)).length
        out.origin = out.startsInOrigin && out.endsInOrigin && out.coversIsland === 0
        // A Place that settles in place grows from itself, not from the Island: origin is only that it never covers it.
        if (run.settles) out.origin = out.coversIsland === 0
        return out
    }

    function report(t: var): var {
        const runs = root.runs.map(run => root.analyse(run))
        // 6. Clean end: nothing of the Place left once it closed.
        const s = root.lastSource
        const clean = !s || (s.presentation <= 0.001 && !s.open && (s.blurShapes ?? []).length === 0
            && (s.chassisBodies ?? []).length === 0 && !(IrisFrame.placeShapesOn(GlobalStates.focusedScreen?.name ?? "").length > 0))
        const verdict = {
            pace: runs.every(r => r.pace),
            continuity: runs.every(r => r.continuity),
            material: runs.every(r => r.material),
            surface: runs.every(r => r.surface),
            origin: runs.every(r => r.origin),
            clean: clean
        }
        return { state: "done", target: root.target, vblank: Math.round(root.vblank * 100) / 100, verdict: verdict,
            passes: Object.values(verdict).every(Boolean), runs: runs }
    }
}
