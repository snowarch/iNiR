pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.functions

Item {
    id: root

    required property string axis
    required property color accentColor
    required property color surfaceColor
    required property real radius

    property bool active: false
    property bool animationsEnabled: true
    property bool dragging: handleDrag.active
    property bool _dragCanceled: false

    signal dragStarted(string axis, real x, real y)
    signal dragged(string axis, real x, real y)
    signal dragFinished(string axis, real x, real y)
    signal dragCanceled(string axis)

    visible: root.active
    enabled: root.active
    activeFocusOnTab: root.active

    Accessible.role: Accessible.Slider
    Accessible.name: qsTr("Resize shell surface")
    Accessible.description: qsTr("Drag to resize along the supported axis")
    Accessible.focusable: root.active

    readonly property bool _lit: root.dragging || handleHover.hovered

    Rectangle {
        id: handleTrack
        anchors.centerIn: parent
        width: root.axis === "horizontal" ? Math.min(parent.width, 10) : parent.width
        height: root.axis === "vertical" ? Math.min(parent.height, 10) : parent.height
        radius: root.radius
        color: ColorUtils.applyAlpha(root.surfaceColor, 0.94)
        border.width: 1
        border.color: ColorUtils.applyAlpha(root.accentColor, root._lit ? 0.86 : 0.36)

        Behavior on border.color {
            enabled: root.active && root.animationsEnabled
            ColorAnimation { duration: 140 }
        }

        Rectangle {
            id: handleGrip
            anchors.centerIn: parent
            width: root.axis === "horizontal" ? 3 : parent.width - 20
            height: root.axis === "vertical" ? 3 : parent.height - 20
            radius: 2
            color: ColorUtils.applyAlpha(root.accentColor, root._lit ? 0.95 : 0.68)

            Behavior on width {
                enabled: root.active && root.animationsEnabled
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1]
                }
            }
            Behavior on height {
                enabled: root.active && root.animationsEnabled
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.16, 1, 0.3, 1, 1, 1]
                }
            }
        }
    }

    HoverHandler {
        id: handleHover
        cursorShape: root.axis === "horizontal"
            ? Qt.SizeHorCursor : root.axis === "vertical"
                ? Qt.SizeVerCursor : Qt.SizeFDiagCursor
    }

    DragHandler {
        id: handleDrag
        target: null
        acceptedButtons: Qt.LeftButton
        onActiveChanged: {
            if (active) {
                root._dragCanceled = false
                root.dragStarted(root.axis, 0, 0)
            } else if (!root._dragCanceled) {
                root.dragFinished(root.axis, translation.x, translation.y)
            }
        }
        onTranslationChanged: {
            if (active)
                root.dragged(root.axis, translation.x, translation.y)
        }
        onCanceled: {
            root._dragCanceled = true
            root.dragCanceled(root.axis)
        }
    }

    Keys.onEscapePressed: event => {
        root.dragCanceled(root.axis)
        event.accepted = true
    }
}
