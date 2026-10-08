pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.iris.style
import qs.modules.iris.pieces

Rectangle {
    id: root

    property string place: "island"
    property real fx: 0.5
    property real fy: 0.5
    property bool hasIsland: false
    property string label: ""
    readonly property real d: IrisStyle.density

    signal placed(zone: string)
    signal placedFree(x: real, y: real)

    readonly property real inset: Math.round(9 * root.d)
    implicitWidth: Math.round(112 * root.d)
    implicitHeight: Math.round(64 * root.d)
    radius: IrisStyle.radiusChip
    color: IrisStyle.fillQuiet
    border.width: 1
    border.color: IrisStyle.border

    function zoneLabel(zone: string): string {
        return IrisPieces.zoneChoices(false).find(choice => choice.value === zone)?.label ?? zone
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.CrossCursor
        onClicked: mouse => root.placedFree(Math.max(0, Math.min(1, mouse.x / width)), Math.max(0, Math.min(1, mouse.y / height)))
    }

    Rectangle {
        visible: root.place === "free"
        width: Math.round(9 * root.d)
        height: width
        radius: width / 2
        x: Math.round(root.fx * root.width - width / 2)
        y: Math.round(root.fy * root.height - height / 2)
        color: IrisStyle.accent
    }

    MouseArea {
        id: islandMark
        enabled: root.hasIsland
        readonly property bool selected: root.place === "island"
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(4 * root.d)
        width: Math.round(34 * root.d)
        height: Math.round(12 * root.d)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        activeFocusOnTab: enabled
        Accessible.role: Accessible.RadioButton
        Accessible.name: root.label + ": " + Translation.tr("Island")
        Accessible.checked: islandMark.selected
        Keys.onSpacePressed: root.placed("island")
        onClicked: root.placed("island")
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 6 * root.d
            height: Math.round(6 * root.d)
            radius: height / 2
            color: islandMark.selected ? IrisStyle.accent
                : !islandMark.enabled ? IrisStyle.fillHover
                : islandMark.containsMouse || islandMark.activeFocus ? IrisStyle.text : IrisStyle.textTertiary
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
        }
    }

    Repeater {
        model: IrisPieces.zones
        MouseArea {
            id: marker
            required property string modelData
            readonly property bool selected: root.place === marker.modelData
            readonly property real px: marker.modelData.endsWith("left") ? 0 : 1
            readonly property real py: marker.modelData.startsWith("top") ? 0 : marker.modelData.startsWith("bottom") ? 1 : 0.5
            width: Math.round(18 * root.d)
            height: width
            x: Math.round(root.inset + marker.px * (root.width - root.inset * 2) - width / 2)
            y: Math.round(root.inset + marker.py * (root.height - root.inset * 2) - height / 2)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            activeFocusOnTab: true
            Accessible.role: Accessible.RadioButton
            Accessible.name: root.label + ": " + Translation.tr(root.zoneLabel(marker.modelData))
            Accessible.checked: marker.selected
            Keys.onSpacePressed: root.placed(marker.modelData)
            onClicked: root.placed(marker.modelData)
            Rectangle {
                anchors.centerIn: parent
                width: Math.round((marker.selected ? 9 : 6) * root.d)
                height: width
                radius: width / 2
                color: marker.selected ? IrisStyle.accent : marker.containsMouse || marker.activeFocus ? IrisStyle.text : IrisStyle.textTertiary
                Behavior on width { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
            }
        }
    }
}
