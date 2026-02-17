import QtQuick
import qs.modules.common
import qs.modules.common.functions

// Angel partial accent border — top and/or left accent bars that animate on hover/active.
// Top bar: 3px primary line that scales X from 0 to 1 on hover.
// Left bar: 3px primary line that scales Y from 0 to 1 on active.
// Only visible when angel global style is active.
//
// Usage: place INSIDE the target container as a child.
//
// Example:
//   Rectangle {
//       AngelAccentBar { showTop: true; active: mouseArea.containsMouse }
//   }
//
Item {
    id: root

    anchors.fill: parent

    // Control which bars to show
    property bool showTop: true
    property bool showLeft: false

    // State triggers
    property bool hovered: false
    property bool active: false

    // Customizable dimensions
    property int topBarHeight: Appearance.angel.accentBarHeight
    property int leftBarWidth: Appearance.angel.accentBarWidth
    property color barColor: Appearance.angel.colAccentBar

    visible: Appearance.angelEverywhere

    // Top accent bar — scaleX animates on hover
    Rectangle {
        id: topBar
        visible: root.showTop
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.topBarHeight
        color: root.barColor
        transformOrigin: Item.Left
        scale: root.hovered || root.active ? 1.0 : 0.0

        Behavior on scale {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
    }

    // Left accent bar — scaleY animates on active
    Rectangle {
        id: leftBar
        visible: root.showLeft
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: root.leftBarWidth
        color: root.barColor
        transformOrigin: Item.Bottom
        scale: root.active ? 1.0 : 0.0

        Behavior on scale {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }
}
