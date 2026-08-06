pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.functions

// One edge drop zone of the shell layout editor. Input serves the keyboard and
// click placement flow; during a pointer drag the origin window owns the grab.
Item {
    id: root

    required property string slot
    required property string label
    required property color accentColor
    required property color surfaceColor
    required property color textColor
    required property real radius
    required property string fontFamily
    required property int fontPixelSize
    required property int animationDuration

    property bool active: false
    property bool occupied: false
    property bool valid: true
    property bool previewed: false

    signal previewRequested(string slot)
    signal placementRequested(string slot)

    readonly property bool _horizontal: root.slot === "top" || root.slot === "bottom"
    readonly property color _accentLit: Qt.lighter(root.accentColor, 1.12)
    readonly property color _hair: ColorUtils.applyAlpha(root.textColor, 0.14)

    visible: root.active
    enabled: root.active && root.valid
    activeFocusOnTab: enabled

    Accessible.role: Accessible.Button
    Accessible.name: root.label
    Accessible.description: !root.valid
        ? qsTr("Unavailable placement target")
        : root.occupied ? qsTr("Occupied placement target")
        : qsTr("Available placement target")
    Accessible.focusable: enabled

    Rectangle {
        id: stripFill
        anchors.fill: parent
        radius: root.radius
        border.width: 1
        border.color: root.valid
            ? (root.previewed
                ? ColorUtils.applyAlpha(root._accentLit, 0.95)
                : targetInput.containsMouse
                    ? ColorUtils.applyAlpha(root.accentColor, 0.65)
                    : root._hair)
            : ColorUtils.applyAlpha(root.textColor, 0.16)
        opacity: root.valid ? 1 : 0.45
        color: root.previewed
            ? ColorUtils.applyAlpha(root.accentColor, 0.24)
            : ColorUtils.applyAlpha(root.surfaceColor,
                targetInput.containsMouse ? 0.54 : 0.30)

        Behavior on border.color {
            enabled: root.animationDuration > 0
            ColorAnimation { duration: root.animationDuration }
        }
        Behavior on opacity {
            enabled: root.animationDuration > 0
            NumberAnimation { duration: root.animationDuration }
        }

    }

    Rectangle {
        visible: root.previewed && root.valid
        anchors {
            top: root.slot === "top" ? stripFill.top : undefined
            bottom: root.slot === "bottom" ? stripFill.bottom : undefined
            left: root.slot === "left" ? stripFill.left : undefined
            right: root.slot === "right" ? stripFill.right : undefined
            horizontalCenter: root._horizontal ? stripFill.horizontalCenter : undefined
            verticalCenter: !root._horizontal ? stripFill.verticalCenter : undefined
        }
        width: root._horizontal ? stripFill.width - root.radius * 1.2 : 2.5
        height: root._horizontal ? 2.5 : stripFill.height - root.radius * 1.2
        radius: 1.25
        color: root.accentColor
    }

    Rectangle {
        id: labelPill
        anchors.centerIn: parent
        width: pillLabel.implicitWidth + 30
        height: pillLabel.implicitHeight + 14
        radius: height / 2
        border.width: 1
        border.color: root.previewed
            ? ColorUtils.applyAlpha(root._accentLit, 0.95)
            : root._hair
        color: root.surfaceColor
        Behavior on border.color {
            enabled: root.animationDuration > 0
            ColorAnimation { duration: root.animationDuration }
        }

        Text {
            id: pillLabel
            anchors.centerIn: parent
            text: root.label
            color: root.previewed ? root.accentColor : root.textColor
            font.family: root.fontFamily
            font.pixelSize: root.fontPixelSize
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            wrapMode: Text.NoWrap

            Behavior on color {
                enabled: root.animationDuration > 0
                ColorAnimation { duration: root.animationDuration }
            }
        }
    }

    Keys.onPressed: event => {
        if (!root.enabled)
            return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space) {
            root.placementRequested(root.slot)
            event.accepted = true
        }
    }

    MouseArea {
        id: targetInput
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        preventStealing: true
        cursorShape: root.valid ? Qt.PointingHandCursor : Qt.ForbiddenCursor
        onEntered: root.previewRequested(root.slot)
        onPressed: mouse => {
            root.forceActiveFocus()
            mouse.accepted = true
        }
        onClicked: mouse => {
            root.placementRequested(root.slot)
            mouse.accepted = true
        }
        onWheel: wheel => { wheel.accepted = true }
    }
}
