pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.functions
import qs.modules.iris.style

// IrisDotStrip bent round a bubble (Nothing's Glyph ring): dots clockwise from twelve o'clock, filled = value, the
// fill spreads dot by dot (12 ms apart), indeterminate is one dot running round. `cut` lays them along a chamfered
// square instead (AIRISU's bubbles), from its upper left corner.
Item {
    id: root

    property real value: 0
    property bool indeterminate: false
    property int count: 16
    property real dotSize: Math.max(2, Math.round(3 * IrisStyle.density))
    property real cut: 0
    property color fillColor: IrisStyle.text
    property color emptyColor: IrisStyle.dotEmpty

    readonly property real shown: Math.max(0, Math.min(1, Number.isFinite(root.value) ? root.value : 0))
    property real _from: 0
    property real _last: 0
    onShownChanged: { root._from = root._last; root._last = root.shown }
    Component.onCompleted: { root._from = root.shown; root._last = root.shown }

    // Centres of the dots, inset by half a dot so none hangs past the edge.
    readonly property var points: {
        const n = Math.max(3, root.count), h = root.dotSize / 2
        const w = root.width - root.dotSize, ht = root.height - root.dotSize
        const out = []
        if (root.cut <= 0) {
            for (let i = 0; i < n; i++) {
                const a = -Math.PI / 2 + 2 * Math.PI * i / n
                out.push(Qt.point(h + w / 2 + Math.cos(a) * w / 2, h + ht / 2 + Math.sin(a) * ht / 2))
            }
            return out
        }
        const c = Math.min(root.cut, w / 3)
        const path = [Qt.point(h, h), Qt.point(h + w - c, h), Qt.point(h + w, h + c), Qt.point(h + w, h + ht),
            Qt.point(h + c, h + ht), Qt.point(h, h + ht - c), Qt.point(h, h)]
        let total = 0
        for (let i = 1; i < path.length; i++) total += Math.hypot(path[i].x - path[i - 1].x, path[i].y - path[i - 1].y)
        for (let i = 0; i < n; i++) {
            let left = total * i / n
            for (let j = 1; j < path.length; j++) {
                const a = path[j - 1], b = path[j], len = Math.hypot(b.x - a.x, b.y - a.y)
                if (left > len) { left -= len; continue }
                out.push(Qt.point(a.x + (b.x - a.x) * left / Math.max(1e-6, len), a.y + (b.y - a.y) * left / Math.max(1e-6, len)))
                break
            }
        }
        return out
    }

    property real head: 0
    NumberAnimation on head {
        running: root.indeterminate && root.visible && IrisStyle.motionEnabled
        from: 0; to: root.count
        duration: Math.max(700, root.count * 55)
        loops: Animation.Infinite
    }

    Repeater {
        model: root.points.length
        Rectangle {
            id: dot
            required property int index
            readonly property point at: root.points[dot.index] ?? Qt.point(0, 0)
            readonly property bool filled: !root.indeterminate && root.shown > 0 && (dot.index + 1) / root.points.length <= root.shown + 0.0001
            // Distance behind the running head, wrapping round.
            readonly property real behind: (root.head - dot.index + root.count) % root.count
            readonly property real glow: root.indeterminate ? Math.max(0, 1 - dot.behind / 3) : 0
            x: Math.round(dot.at.x - width / 2)
            y: Math.round(dot.at.y - height / 2)
            width: root.dotSize
            height: root.dotSize
            radius: width / 2
            color: root.indeterminate ? ColorUtils.mix(root.fillColor, root.emptyColor, dot.glow)
                : dot.filled ? root.fillColor : root.emptyColor
            readonly property int delay: root.indeterminate ? 0
                : Math.min(24, Math.abs(dot.index - Math.round(root._from * root.points.length))) * 12
            Behavior on color {
                enabled: !root.indeterminate && IrisStyle.motionEnabled && root.visible
                SequentialAnimation {
                    PauseAnimation { duration: IrisStyle.duration(dot.delay) }
                    ColorAnimation { duration: IrisStyle.duration(70); easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
