pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.iris.style

Item {
    id: root
    visible: false
    width: 0
    height: 0

    property real to: 0
    property real value: 0
    property real velocity: 0
    property string intent: "auto"
    property string surface: ""
    property bool animate: true
    property real minimum: -1e9
    property real epsilon: 0.0005

    property bool running: false
    readonly property bool moving: root.running

    property real target: 0
    property var segments: []
    property real lastTime: 0
    property real startedAt: 0

    property real clock: 0
    NumberAnimation on clock {
        running: root.running
        from: 0
        to: 1
        duration: 1000
        loops: Animation.Infinite
    }

    // Resolving a spring reads the surface's own style and speed out of Config, so it is done
    // once per movement and not once per tick: the parameters cannot change mid-flight anyway.
    property var resolved: null
    function params(intent: string): var {
        const wanted = root.intent !== "auto" ? root.intent : intent
        const held = root.resolved
        if (held && held[wanted]) return held[wanted]
        const entry = IrisStyle.springFor(wanted, root.surface)
        root.resolved = Object.assign({}, held ?? {}, { [wanted]: entry })
        return entry
    }
    function forget(): void { root.resolved = null }
    readonly property var motionSignature: [IrisStyle.emergeSpring, IrisStyle.recedeSpring, IrisStyle.moveSpring,
        String(IrisStyle.appearance?.surfaces?.[root.surface]?.morph ?? ""),
        Number(IrisStyle.appearance?.surfaces?.[root.surface]?.speed ?? 100)]
    onMotionSignatureChanged: root.forget()
    onSurfaceChanged: root.forget()
    onIntentChanged: root.forget()
    function jump(): void {
        root.running = false
        root.segments = []
        root.velocity = 0
        root.target = root.to
        root.value = root.to
    }
    // The first tick steps at most one frame from the kick: the main thread may spend tens of milliseconds
    // between a retarget and its frame, and charged in full that wait made a morph start at its middle. A first
    // tick that stepped nothing started every motion a frame late.
    function start(): void {
        if (root.running) return
        root.lastTime = 0
        root.startedAt = Date.now()
        root.running = true
    }
    function kick(): void {
        const p = root.params(root.to >= root.value ? "emerge" : "recede")
        if (!root.animate || p.response <= 0) { root.jump(); return }
        if (Math.abs(root.value - root.to) < root.epsilon && Math.abs(root.velocity) < root.epsilon * 12) {
            root.jump()
            return
        }
        if (p.curve) {
            const delta = root.to - (root.segments.length > 0 ? root.target : root.value)
            root.target = root.to
            if (Math.abs(delta) >= root.epsilon)
                root.segments = root.segments.concat([{ delta: delta, age: 0, response: p.response, curve: p.curve }])
        } else {
            root.segments = []
            root.target = root.to
        }
        root.start()
    }
    onToChanged: root.kick()
    onAnimateChanged: if (!root.animate) root.jump()
    Component.onCompleted: { root.target = root.to; root.value = root.to }

    onClockChanged: {
        if (!root.running) return
        const now = Date.now()
        if (root.lastTime <= 0) root.lastTime = now - Math.min(16, now - root.startedAt)
        const dt = Math.min(0.034, Math.max(0, (now - root.lastTime) / 1000))
        root.lastTime = now
        if (dt <= 0) return
        const p = root.params(root.to >= root.value ? "emerge" : "recede")
        if (p.response <= 0) { root.jump(); return }

        if (root.segments.length > 0 || p.curve) {
            let offset = 0
            const alive = []
            for (const segment of root.segments) {
                segment.age += dt * 1000
                if (segment.age >= segment.response) continue
                offset += segment.delta * (1 - IrisStyle.cubicBezier(segment.curve, segment.age / segment.response))
                alive.push(segment)
            }
            root.segments = alive
            if (alive.length === 0 && !p.curve) {
                root.value = root.to - offset
            } else {
                if (alive.length === 0) { root.jump(); return }
                const next = Math.max(root.minimum, root.to - offset)
                root.velocity = (next - root.value) / dt
                root.value = next
                return
            }
        }

        const w = 2 * Math.PI / (p.response / 1000)
        const zeta = 1 - p.bounce
        const x0 = root.value - root.to
        const v0 = root.velocity
        let x, v
        if (zeta < 0.9999) {
            const wd = w * Math.sqrt(1 - zeta * zeta)
            const e = Math.exp(-zeta * w * dt)
            const b = (v0 + zeta * w * x0) / wd
            const c = Math.cos(wd * dt), s = Math.sin(wd * dt)
            x = e * (x0 * c + b * s)
            v = -zeta * w * x + e * (-x0 * wd * s + b * wd * c)
        } else {
            const e = Math.exp(-w * dt)
            const b = v0 + w * x0
            x = (x0 + b * dt) * e
            v = (b - w * (x0 + b * dt)) * e
        }
        let next = root.to + x
        if (next < root.minimum) { next = root.minimum; v = 0 }
        if (Math.abs(x) < root.epsilon && Math.abs(v) < root.epsilon * 12) {
            root.jump()
            return
        }
        root.velocity = v
        root.value = next
    }
}
