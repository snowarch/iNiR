import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's marks on a lock block while it is being arranged: the pointer draws the block's die, cut like every piece, in
// the media's ink; the block taken, the one the arrows move, has it in the accent. Its name hangs above it on a small die, the accent's
// lacquer once taken, with the key that shows or hides it beside.
Item {
    id: root
    property var host
    readonly property bool arranging: root.host?.arranging ?? false
    readonly property bool picked: root.host?.picked ?? false
    readonly property bool hovered: root.host?.hovered ?? false
    readonly property bool on: root.host?.on ?? true
    readonly property bool tagged: root.arranging && (root.picked || root.hovered || eyeArea.containsMouse)

    ADie {
        anchors.fill: parent
        anchors.margins: -Airisu.u(2)
        visible: root.arranging && (root.hovered || root.picked)
        kind: "chamfer"
        cut: Airisu.cutFor(height)
        stroke: root.picked ? Airisu.chosenOnMedia : IrisStyle.onMedia
        strokeWidth: root.picked ? Airisu.strong : Airisu.hair
    }

    Row {
        visible: root.tagged
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: Airisu.u(4)
        spacing: Airisu.u(1)
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: name.implicitWidth + Airisu.u(3)
            height: Airisu.u(6)
            ALacquer {
                anchors.fill: parent
                lacquer: root.picked ? Airisu.chosenOnMedia : IrisStyle.mediaScrim
            }
            AText {
                id: name
                anchors.centerIn: parent
                size: IrisStyle.typeFootnote
                font.weight: Font.Bold
                color: root.picked ? Airisu.inkOnSeal : IrisStyle.onMedia
                text: Translation.tr(root.host?.label ?? "")
            }
        }
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: Airisu.u(6)
            height: width
            ALacquer {
                anchors.fill: parent
                lacquer: eyeArea.containsMouse ? IrisStyle.onMediaFill : IrisStyle.mediaScrim
            }
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.on ? "visibility" : "visibility_off"
                iconSize: Math.round(14 * Airisu.d)
                color: root.on ? IrisStyle.onMedia : IrisStyle.onMediaSecondary
            }
            MouseArea {
                id: eyeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: Translation.tr("Show this block")
                onClicked: root.host?.toggle()
            }
        }
    }
}
