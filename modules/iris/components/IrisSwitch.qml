import QtQuick
import QtQuick.Effects
import qs.modules.iris.style

Rectangle {
    id: root

    property bool on: false
    property string name: ""
    readonly property real d: IrisStyle.density
    // A Design may draw it its own way (AIRISU: OFF│ON); the switch keeps the toggle, the keys and the name.
    readonly property bool skinned: skin.active
    // What a skin draws from: the pointer over it and the press.
    readonly property bool hovered: area.containsMouse
    readonly property bool pressed: area.pressed
    readonly property bool keyed: root.activeFocus
    signal toggled()

    implicitWidth: Math.round((root.skinned ? Number(IrisDesign.surface("switch", "width", 76)) : 40) * root.d)
    implicitHeight: Math.round((root.skinned ? Number(IrisDesign.surface("switch", "height", 26)) : 24) * root.d)
    radius: root.skinned ? 0 : height / 2
    color: root.skinned ? "transparent" : root.on ? IrisStyle.accent : IrisStyle.fillHover
    Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
    Accessible.role: Accessible.CheckBox
    Accessible.name: root.name
    Accessible.checked: root.on
    activeFocusOnTab: visible
    border.width: activeFocus && !root.skinned ? 2 : 0
    border.color: IrisStyle.text
    Keys.onSpacePressed: root.toggled()
    Keys.onReturnPressed: root.toggled()

    // Held, the thumb stretches toward where it will travel, as a finger pressing a capsule does.
    IrisSkin { id: skin; part: "switch" }
    RectangularShadow {
        visible: !root.skinned
        anchors.fill: thumb
        radius: thumb.radius
        offset.y: root.d
        blur: 3 * root.d
        color: IrisStyle.shadow
    }
    Rectangle {
        id: thumb
        visible: !root.skinned
        readonly property real size: root.height - 4 * root.d
        y: 2 * root.d
        x: root.on ? root.width - width - 2 * root.d : 2 * root.d
        width: thumb.size * (area.pressed ? 1.28 : 1)
        height: thumb.size
        radius: IrisStyle.capsule(height)
        color: IrisStyle.onTint
        Behavior on x { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
        Behavior on width { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6 * root.d
        hoverEnabled: root.skinned
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
