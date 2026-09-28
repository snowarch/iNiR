pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.common

Item {
    id: root
    property bool emphasized: false
    property bool vertical: false
    property real inset: 16
    property color color: Appearance.editorial.accent
    readonly property real extent: Math.max(0, (vertical ? height : width) - inset * 2)
    readonly property real markLength: Math.min(extent, emphasized ? 48 : 24)
    visible: Appearance.editorialEverywhere

    Rectangle {
        x: root.vertical ? 0 : Math.min(root.inset, root.width / 2)
        y: root.vertical ? Math.min(root.inset, root.height / 2) : 0
        width: root.vertical ? 2 : root.markLength
        height: root.vertical ? root.markLength : 2
        radius: 1
        color: root.color
        Behavior on width {
            enabled: Appearance.animationsEnabled && root.visible
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            enabled: Appearance.animationsEnabled && root.visible
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic }
        }
    }
}
