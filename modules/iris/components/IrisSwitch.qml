import QtQuick
import qs.modules.common.functions
import qs.modules.iris.style

Rectangle {
    id: root

    property bool on: false
    property string name: ""
    readonly property real d: IrisStyle.density
    // A Design may draw it its own way (AIRISU: O│I); the switch keeps the toggle, the keys and the name.
    readonly property bool skinned: skin.active
    // What a skin draws from: the pointer over it and the press.
    readonly property bool hovered: area.containsMouse
    readonly property bool pressed: area.pressed
    readonly property bool keyed: root.activeFocus
    // Set on a chosen row's plate in a plate Design: the skin prints it in the plate's reverse ink.
    property bool reversed: false
    property string voice: ""
    signal toggled()

    implicitWidth: Math.round((skin.item?.wantWidth ?? (root.skinned ? Number(IrisDesign.surface("switch", "width", 76)) : 38)) * root.d)
    implicitHeight: Math.round((skin.item?.wantHeight ?? (root.skinned ? Number(IrisDesign.surface("switch", "height", 26)) : 22)) * root.d)
    // Signal (DESIGN.md S4): off is a hairline ring with a hollow knob, on is an ink track with a paper knob. The knob
    // rides a spring and everything else follows it, so a quick double toggle turns back mid-way instead of restarting.
    IrisSpring {
        id: travel
        intent: "move"
        to: root.on ? 1 : 0
        animate: IrisStyle.motionEnabled && root.visible
    }
    Component.onCompleted: travel.jump()
    readonly property real lit: Math.max(0, Math.min(1, travel.value))
    readonly property real stroke: Math.max(1, Math.round(1.5 * root.d * 2) / 2)
    readonly property color ring: IrisStyle.ringInk
    radius: root.skinned ? 0 : height / 2
    color: root.skinned ? "transparent" : ColorUtils.applyAlpha(IrisStyle.accentFill, root.lit)
    border.width: root.skinned ? 0 : root.stroke
    border.color: ColorUtils.mix(IrisStyle.accentFill, root.ring, root.lit)
    Accessible.role: Accessible.CheckBox
    Accessible.name: root.name
    Accessible.checked: root.on
    activeFocusOnTab: visible
    Keys.onSpacePressed: root.toggled()
    Keys.onReturnPressed: root.toggled()

    IrisSkin { id: skin; part: "switch"; voice: root.voice }
    Rectangle {
        visible: root.activeFocus && !root.skinned
        anchors.fill: parent
        anchors.margins: -Math.round(3 * root.d)
        radius: height / 2
        color: "transparent"
        border.width: Math.max(1, Math.round(1.5 * root.d))
        border.color: IrisStyle.text
    }
    // Held, the knob stretches toward where it will travel, as a finger pressing a capsule does.
    Rectangle {
        id: knob
        visible: !root.skinned
        readonly property real size: Math.round((12 + root.lit) * root.d)
        readonly property real pad: Math.round(4 * root.d)
        y: Math.round((root.height - height) / 2)
        width: knob.size + (area.pressed ? Math.round(4 * root.d) : 0)
        height: knob.size
        x: knob.pad + (root.width - 2 * knob.pad - knob.width) * travel.value
        radius: IrisStyle.capsule(height)
        color: ColorUtils.applyAlpha(IrisStyle.inkOnAccentFill, root.lit)
        border.width: root.stroke * (1 - root.lit)
        border.color: root.ring
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
