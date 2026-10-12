import QtQuick
import qs.modules.iris.style

// A switch tile of the panel: a title in Archivo and its state in mono. On is the gofun plate with lacquer ink
// (chosen, not alarm); `live` marks a state that is happening now (recording) with the seal on its status line.
Rectangle {
    id: root
    property string title
    property string status
    property bool on: false
    property bool live: false
    property bool available: true
    signal clicked()
    signal altClicked()

    implicitHeight: Math.round(76 * Airisu.d)
    color: root.on ? Airisu.gofun : hover.hovered ? IrisStyle.fillHover : "transparent"
    opacity: root.available ? 1 : 0.45
    Behavior on color { enabled: IrisStyle.motionEnabled; ColorAnimation { duration: Airisu.shift } }
    Accessible.role: Accessible.Button
    Accessible.name: root.title
    Accessible.checkable: true
    Accessible.checked: root.on

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Airisu.pad
        anchors.rightMargin: Airisu.gap
        spacing: Math.round(2 * Airisu.d)
        AText {
            width: parent.width
            text: root.title
            size: IrisStyle.typeHeadline
            font.weight: Font.Bold
            color: root.on ? Airisu.inkOnGofun : Airisu.gofun
        }
        AText {
            width: parent.width
            voice: "mono"
            text: (root.live ? "● " : "") + root.status
            color: root.live ? Airisu.sealText : root.on ? Airisu.inkOnGofun : Airisu.data
            opacity: root.on && !root.live ? 0.72 : 1 // iris-literal: lacquer ink at secondary strength on the gofun plate
        }
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { acceptedButtons: Qt.LeftButton; onTapped: if (root.available) root.clicked() }
    TapHandler { acceptedButtons: Qt.RightButton; onTapped: root.altClicked() }
}
