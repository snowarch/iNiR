pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame

Item {
    id: root

    property bool active: false
    readonly property var surround: Config.options?.iris?.surround ?? ({})
    readonly property string edges: String(root.surround?.musicEdges ?? "sides")
    readonly property real strength: Math.max(0.5, Math.min(3, Number(root.surround?.musicStrength ?? 160) / 100))
    readonly property real sensitivity: Math.max(0.5, Math.min(2.5, Number(root.surround?.musicSensitivity ?? 140) / 100))
    readonly property real speed: Math.max(0.4, Math.min(2, Number(root.surround?.musicSpeed ?? 100) / 100))
    readonly property real reach: 18 * IrisStyle.density * root.strength
    property real level: 0
    property real phase: 0
    readonly property real visibleLevel: root.active ? root.level : 0
    readonly property vector4d amplitudes: Qt.vector4d(
        root.edges !== "horizontal" ? root.visibleLevel * root.reach : 0,
        root.edges !== "sides" ? root.visibleLevel * root.reach : 0,
        root.edges !== "horizontal" ? root.visibleLevel * root.reach : 0,
        root.edges !== "sides" ? root.visibleLevel * root.reach : 0)
    onActiveChanged: {
        if (!root.active) {
            root.level = 0
            root.phase = 0
        }
    }

    CavaProcess {
        id: cava
        active: root.active && (MprisController.activePlayer?.isPlaying ?? false)
        sampleCount: 16
    }
    FrameAnimation {
        running: root.active && (cava.held || root.level > 0.002)
        onTriggered: {
            const points = cava.points ?? []
            let bass = 0
            const count = Math.min(4, points.length)
            for (let i = 0; i < count; ++i) bass += Number(points[i] ?? 0)
            bass = count > 0 ? Math.min(1, bass / count / Math.max(1, cava.normalizationCeiling)) : 0
            bass = Math.min(1, Math.sqrt(bass) * root.sensitivity)
            const step = Math.min(0.05, frameTime)
            const rate = bass > root.level ? 18 : 3.2
            root.level += (bass - root.level) * Math.min(1, rate * step)
            if (root.level < 0.002 && !cava.held) root.level = 0
            root.phase = (root.phase + step * (0.6 + 2.4 * root.level) * root.speed) % 6283.185
        }
    }
}
