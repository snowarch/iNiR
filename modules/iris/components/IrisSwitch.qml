import QtQuick
import QtQuick.Effects
import qs.modules.iris.style

Rectangle {
    id: root

    property bool on: false
    property string name: ""
    readonly property real d: IrisStyle.density
    signal toggled()

    implicitWidth: Math.round(40 * root.d)
    implicitHeight: Math.round(24 * root.d)
    radius: height / 2
    color: root.on ? IrisStyle.accent : IrisStyle.fillHover
    Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
    Accessible.role: Accessible.CheckBox
    Accessible.name: root.name
    Accessible.checked: root.on
    activeFocusOnTab: visible
    border.width: activeFocus ? 2 : 0
    border.color: IrisStyle.text
    Keys.onSpacePressed: root.toggled()
    Keys.onReturnPressed: root.toggled()

    // Held, the thumb stretches toward where it will travel, as a finger pressing a capsule does.
    RectangularShadow {
        anchors.fill: thumb
        radius: thumb.radius
        offset.y: root.d
        blur: 3 * root.d
        color: IrisStyle.shadow
    }
    Rectangle {
        id: thumb
        readonly property real size: root.height - 4 * root.d
        y: 2 * root.d
        x: root.on ? root.width - width - 2 * root.d : 2 * root.d
        width: thumb.size * (area.pressed ? 1.28 : 1)
        height: thumb.size
        radius: height / 2
        color: IrisStyle.onTint
        Behavior on x { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
        Behavior on width { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6 * root.d
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
