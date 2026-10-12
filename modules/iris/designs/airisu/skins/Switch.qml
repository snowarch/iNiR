import QtQuick
import qs.services
import qs.modules.iris.style
import "../components"

// AIRISU's switch (board Components): a mechanical selector, OFF│ON in mono, never a sliding knob. The lit cell is the
// state: ON in the vermilion seal, OFF on the gofun plate. It snaps across in 90 ms with one pixel of throw.
Item {
    id: root
    property Item host
    readonly property bool on: root.host?.on ?? false
    readonly property real cell: Math.round(width / 2)

    Rectangle { anchors.fill: parent; color: Airisu.sumi }
    Rectangle {
        id: lit
        width: root.cell
        height: root.height
        x: root.on ? root.width - width : 0
        color: root.on ? Airisu.seal : Airisu.gofun
        Behavior on x { enabled: IrisStyle.motionEnabled; NumberAnimation { duration: Airisu.shift; easing.type: Easing.OutBack; easing.overshoot: 0.6 } }
        Behavior on color { enabled: IrisStyle.motionEnabled; ColorAnimation { duration: Airisu.shift } }
    }
    Repeater {
        model: ["OFF", "ON"]
        AText {
            required property string modelData
            required property int index
            readonly property bool lit: (index === 1) === root.on
            x: index * root.cell
            width: root.cell
            height: root.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            voice: "mono"
            font.weight: Font.Bold
            text: modelData
            color: lit ? (root.on ? Airisu.inkOnSeal : Airisu.inkOnGofun) : Airisu.quiet
        }
    }
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: root.host?.activeFocus ? 2 : 0
        border.color: Airisu.gofun
    }
}
