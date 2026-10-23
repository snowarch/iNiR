pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.iris.style

// A level, a progress or a range as a row of dots (DESIGN.md S4, S5): filled dots are the value, a change fills dot
// by dot (12 ms apart, the family's only stagger), indeterminate is one dot travelling with a short tail, and a range
// may carry a larger knob dot at its value. Vertical fills bottom-up. Nothing animates while it is hidden.
ShaderEffect {
    id: root

    property real value: 0
    property bool vertical: false
    property bool indeterminate: false
    property real dotSize: Math.max(3, Math.round(4 * IrisStyle.density))
    property real gap: Math.max(2, Math.round(3 * IrisStyle.density))
    // 0 lays as many dots as fit; a meter of a fixed resolution (a battery's 10 cells) sets its own.
    property int count: 0
    // A larger dot at the value (a range's handle); 0 for a meter.
    property real knobSize: 0
    property color fillColor: IrisStyle.text
    property color emptyColor: IrisStyle.dotEmpty
    property color knobColor: root.fillColor
    // Off while a finger drags: the dots under it follow at once instead of trailing behind.
    property bool stagger: true

    readonly property real span: root.vertical ? root.height : root.width
    // Dot centres run from `start` to the far end less `start`: the knob never hangs past the strip's ends.
    readonly property real start: Math.max(root.knobSize, root.dotSize) / 2
    readonly property real lane: Math.max(0, root.span - 2 * root.start)
    readonly property int dots: root.count > 0 ? root.count
        : Math.max(2, Math.floor(root.lane / Math.max(1, root.dotSize + root.gap)) + 1)
    readonly property real shown: Math.max(0, Math.min(1, Number.isFinite(root.value) ? root.value : 0))
    readonly property real pitch: root.dots > 1 ? root.lane / (root.dots - 1) : 0
    // How many dots are lit; `level` walks there 12 ms a dot (the stagger as one number, not a timer per dot).
    readonly property int lit: root.indeterminate || root.shown <= 0 ? 0
        : root.dots > 1 ? Math.floor(root.shown * (root.dots - 1) + 0.0001) + 1 : 1
    property real level: 0
    onLitChanged: {
        fillWalk.stop()
        if (!root.stagger || !root.visible || !IrisStyle.motionEnabled) { root.level = root.lit; return }
        fillWalk.from = root.level
        fillWalk.to = root.lit
        fillWalk.duration = IrisStyle.duration(Math.min(24, Math.abs(root.lit - root.level)) * 12 + 70)
        fillWalk.start()
    }
    onVisibleChanged: if (!root.visible) { fillWalk.stop(); root.level = root.lit }
    Component.onCompleted: root.level = root.lit
    NumberAnimation { id: fillWalk; target: root; property: "level"; easing.type: Easing.Linear }

    implicitWidth: root.vertical ? Math.max(root.dotSize, root.knobSize) : 160
    implicitHeight: root.vertical ? 160 : Math.max(root.dotSize, root.knobSize)

    property real head: 0
    NumberAnimation on head {
        running: root.indeterminate && root.visible && IrisStyle.motionEnabled
        from: -2; to: root.dots + 2
        duration: Math.max(600, root.dots * 45)
        loops: Animation.Infinite
    }

    blending: true
    fragmentShader: Qt.resolvedUrl("IrisDotStrip.frag.qsb")
    readonly property color fill: root.fillColor
    readonly property color empty: root.emptyColor
    readonly property color knobFill: root.knobColor
    readonly property bool knobShown: root.knobSize > 0 && !root.indeterminate
    readonly property vector4d box: Qt.vector4d(Math.max(1, width), Math.max(1, height), root.vertical ? 1 : 0,
        IrisStyle.capsule(2) > 0 ? 1 : 0)
    readonly property vector4d grid: Qt.vector4d(root.dots, root.start, root.pitch, root.dotSize)
    // The knob covers the dots it sits on; one peeking past its rim reads as a smudge.
    readonly property vector4d phase: Qt.vector4d(root.level, root.knobShown ? root.knobSize : 0,
        root.vertical ? root.span - (root.start + root.shown * root.lane) : root.start + root.shown * root.lane,
        root.indeterminate ? root.head : -1000)
}
