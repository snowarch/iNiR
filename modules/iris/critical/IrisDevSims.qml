import QtQuick
import Quickshell.Io
import qs
import qs.modules.iris.state

// Simulated hands for measuring iRiS: a bubble carried around the focused output, one dropped at a point, a Dock
// icon slid along. Never writes the config.
Item {
    id: root

    property string dragSlot: ""
    property int dragPerFrame: 1
    property real dragStart: 0
    property real dragUntil: 0
    FrameAnimation {
        id: dragSim
        running: false
        onTriggered: {
            const t = Date.now() - root.dragStart
            if (Date.now() >= root.dragUntil) { dragSim.stop(); IrisState.bubbleDrag = null; return }
            const screen = GlobalStates.focusedScreen
            const cx = (screen?.width ?? 1920) / 2, cy = (screen?.height ?? 1080) / 2
            for (let k = 0; k < root.dragPerFrame; k++) {
                const a = (t + k * 13 / root.dragPerFrame) / 400
                IrisState.bubbleDrag = { slot: root.dragSlot, kind: root.dragSlot.replace(/^extra-/, ""), screen: screen?.name ?? "",
                    x: cx + cx * 0.3 * Math.cos(a), y: cy + cy * 0.37 * Math.sin(a), size: 40, released: false }
            }
        }
    }

    IpcHandler {
        target: "irisDev"
        function dragSim(slot: string, perFrame: string): string {
            if (!GlobalStates.focusedScreen) return "error:no-screen"
            root.dragSlot = slot.length > 0 ? slot : "extra-clock"
            root.dragPerFrame = Math.max(1, Math.min(16, Number(perFrame) || 1))
            root.dragStart = Date.now()
            root.dragUntil = root.dragStart + 2500
            dragSim.restart()
            return "dragging:" + root.dragSlot + "x" + root.dragPerFrame
        }
        function dropBubble(slot: string, x: string, y: string): string {
            const screen = GlobalStates.focusedScreen
            if (!screen) return "error:no-screen"
            IrisState.bubbleDrag = { slot: slot, kind: slot.startsWith("app:") ? "app" : slot.replace(/^extra-/, ""),
                screen: screen.name, x: Number(x), y: Number(y), size: 40, released: false }
            dropRelease.restart()
            return "dropped:" + slot + "@" + x + "," + y
        }
        function dockSlide(appId: string, pixels: string): string {
            if (!GlobalStates.focusedScreen) return "error:no-screen"
            root.slideApp = appId.toLowerCase()
            root.slideDistance = Number(pixels) || 0
            root.slideStart = Date.now()
            slideSim.restart()
            return "sliding:" + root.slideApp + ":" + root.slideDistance
        }
    }
    Timer {
        id: dropRelease
        interval: 200
        onTriggered: if (IrisState.bubbleDrag) IrisState.bubbleDrag = Object.assign({}, IrisState.bubbleDrag, { released: true })
    }
    property string slideApp: ""
    property real slideDistance: 0
    property real slideStart: 0
    FrameAnimation {
        id: slideSim
        running: false
        onTriggered: {
            const t = Math.min(1, (Date.now() - root.slideStart) / 1000)
            const eased = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2
            IrisState.dockSlide = { appId: root.slideApp, along: root.slideDistance * eased, done: t >= 1 }
            if (t >= 1) { slideSim.stop(); IrisState.dockSlide = null }
        }
    }
}
