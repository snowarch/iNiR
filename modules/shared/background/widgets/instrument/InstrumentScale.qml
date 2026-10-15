pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions

// Linear measurement scale. The caller supplies a bounded value and semantic
// ink; open-ended counters must not manufacture a fraction to use this scale.
Item {
    id: root
    property real fraction: 0
    property color ink
    property color accent
    property bool vertical: false
    property int divisions: 24
    property bool animated: true
    readonly property int count: Math.max(2, divisions)
    readonly property real progress: Number.isFinite(fraction)
        ? Math.max(0, Math.min(1, fraction)) : 0
    property real displayedProgress: progress

    Behavior on displayedProgress {
        enabled: root.animated
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Easing.OutCubic
        }
    }

    // Whole-pixel pitch and mark: a fractional stride rounds into marks and gaps that alternate
    // between two widths, which reads as uneven spacing. `divisions` sets the pitch; as many marks
    // as fit at it fill the length, and the remainder (under one pitch) goes to both ends.
    readonly property real _length: root.vertical ? root.height : root.width
    readonly property real _depth: root.vertical ? root.width : root.height
    readonly property int _pitch: Math.max(2, Math.floor(root._length / root.count))
    readonly property int _mark: Math.max(1, Math.round(root._pitch * 0.4))
    readonly property int _marks: Math.max(2, Math.floor((root._length - root._mark) / root._pitch) + 1)
    readonly property int _start: Math.max(0, Math.floor((root._length - root._pitch * (root._marks - 1) - root._mark) / 2))

    Repeater {
        model: root._marks
        Rectangle {
            required property int index
            readonly property bool major: index % 4 === 0
            readonly property bool filled: (index + 0.5) / root._marks <= root.displayedProgress
            readonly property int along: root._start + index * root._pitch
            readonly property int across: Math.round(root._depth * (major ? 1 : 0.7))
            x: root.vertical ? 0 : along
            y: root.vertical ? Math.round(root.height) - along - root._mark : Math.round(root._depth) - across
            width: root.vertical ? across : root._mark
            height: root.vertical ? root._mark : across
            color: filled ? root.accent : ColorUtils.applyAlpha(root.ink, major ? 0.42 : 0.22)
            Behavior on color {
                enabled: root.animated
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
        }
    }
}
