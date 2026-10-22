pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.functions
import qs.modules.iris.style

// A level, a progress or a range as a row of dots (DESIGN.md S4, S5): filled dots are the value, a change fills dot
// by dot (12 ms apart, the family's only stagger), indeterminate is one dot travelling with a short tail, and a range
// may carry a larger knob dot at its value. Vertical fills bottom-up. Nothing animates while it is hidden.
Item {
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
    // The dot nearest the value when it last changed: the fill spreads from there.
    property real _from: 0
    property real _last: 0
    onShownChanged: { root._from = root._last; root._last = root.shown }
    Component.onCompleted: { root._from = root.shown; root._last = root.shown }

    implicitWidth: root.vertical ? Math.max(root.dotSize, root.knobSize) : 160
    implicitHeight: root.vertical ? 160 : Math.max(root.dotSize, root.knobSize)

    function along(at: real): real { return root.vertical ? root.span - at : at }

    property real head: 0
    NumberAnimation on head {
        running: root.indeterminate && root.visible && IrisStyle.motionEnabled
        from: -2; to: root.dots + 2
        duration: Math.max(600, root.dots * 45)
        loops: Animation.Infinite
    }

    Repeater {
        model: root.dots
        Rectangle {
            id: dot
            required property int index
            readonly property real at: root.dots > 1 ? dot.index / (root.dots - 1) : 0
            readonly property bool filled: !root.indeterminate && root.shown > 0 && dot.at <= root.shown + 0.0001
            readonly property real glow: root.indeterminate ? Math.max(0, 1 - Math.abs(dot.index - root.head) / 2.5) : 0
            readonly property real pos: root.along(root.start + dot.index * root.pitch)
            width: root.dotSize
            height: root.dotSize
            radius: IrisStyle.capsule(root.dotSize)
            // The knob covers the dots it sits on; one peeking past its rim reads as a smudge.
            visible: !knob.visible || Math.abs(dot.pos - knob.pos) > (root.knobSize + root.dotSize) / 2 + 1
            x: root.vertical ? Math.round((root.width - width) / 2) : Math.round(dot.pos - width / 2)
            y: root.vertical ? Math.round(dot.pos - height / 2) : Math.round((root.height - height) / 2)
            color: root.indeterminate ? ColorUtils.mix(root.fillColor, root.emptyColor, dot.glow)
                : dot.filled ? root.fillColor : root.emptyColor
            readonly property int delay: root.stagger && !root.indeterminate
                ? Math.min(24, Math.abs(dot.index - Math.round(root._from * (root.dots - 1)))) * 12 : 0
            Behavior on color {
                enabled: !root.indeterminate && IrisStyle.motionEnabled && root.visible
                SequentialAnimation {
                    PauseAnimation { duration: IrisStyle.duration(dot.delay) }
                    ColorAnimation { duration: IrisStyle.duration(70); easing.type: Easing.OutCubic }
                }
            }
        }
    }

    Rectangle {
        id: knob
        visible: root.knobSize > 0 && !root.indeterminate
        width: root.knobSize
        height: root.knobSize
        radius: IrisStyle.capsule(root.knobSize)
        color: root.knobColor
        readonly property real pos: root.along(root.start + root.shown * root.lane)
        x: root.vertical ? Math.round((root.width - width) / 2) : Math.round(knob.pos - width / 2)
        y: root.vertical ? Math.round(knob.pos - height / 2) : Math.round((root.height - height) / 2)
    }
}
