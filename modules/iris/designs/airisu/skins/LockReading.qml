import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import "../components"

// AIRISU's status reading on the lock, in small type: the keyboard layout on a key sunk into the picture (the key you
// would press to change it), the connection by its mark and its name, the battery by its level.
Item {
    id: root
    property var host
    readonly property real s: root.host?.typeScale ?? 1
    readonly property string kind: root.host?.kind ?? ""
    readonly property real battery: root.host?.battery ?? -1
    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(row.implicitHeight, Airisu.u(6))

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: Airisu.u(1.5)
        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.kind !== "keyboard" && (root.battery < 0 || root.host?.glyph === "bolt")
            text: root.host?.glyph ?? ""
            iconSize: Math.round(17 * Airisu.d)
            color: IrisStyle.onMediaSecondary
        }
        IrisBatteryMark {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.battery >= 0
            markHeight: Math.round(10 * Airisu.d)
            level: root.battery
            tint: IrisStyle.onMediaSecondary
            frame: IrisStyle.onMediaTertiary
        }
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: label.implicitWidth + (root.kind === "keyboard" ? Airisu.u(3) : 0)
            height: root.kind === "keyboard" ? Airisu.u(6) : label.implicitHeight
            ALacquer {
                anchors.fill: parent
                visible: root.kind === "keyboard"
                cut: Airisu.cutFor(height)
                lacquer: IrisStyle.mediaScrim
            }
            AText {
                id: label
                anchors.centerIn: parent
                size: Math.round(IrisStyle.typeMeta * root.s)
                font.weight: Font.Medium
                color: IrisStyle.onMediaSecondary
                text: root.host?.label ?? ""
            }
        }
    }
}
