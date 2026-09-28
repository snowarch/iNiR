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

    Repeater {
        model: root.count
        Rectangle {
            required property int index
            readonly property bool major: index % 4 === 0 || index === root.count - 1
            readonly property bool filled: (index + 0.5) / root.count <= root.displayedProgress
            readonly property real stride: (root.vertical ? root.height : root.width) / root.count
            x: root.vertical ? 0 : index * stride
            y: root.vertical ? root.height - (index + 1) * stride : (major ? 0 : root.height * 0.25)
            width: root.vertical ? root.width * (major ? 1 : 0.7) : Math.max(1, stride * 0.55)
            height: root.vertical ? Math.max(1, stride * 0.55) : root.height * (major ? 1 : 0.75)
            color: filled ? root.accent : ColorUtils.applyAlpha(root.ink, major ? 0.42 : 0.22)
            Behavior on color {
                enabled: root.animated
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
        }
    }
}
