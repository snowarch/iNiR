import QtQuick
import Quickshell.Widgets
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's menu row (the desktop's, a bubble's, the tray's, the Dock's): a line of a parts list. Its number leads in the
// data face (the digit that takes it from the keyboard), its sign stands bare in the second ink (no tinted chip), its words in the ink, a detail in the data face's capitals at the end. The row under
// the pointer or the keyboard takes its crop marks, never a plate; a press prints the row's under plate. What is chosen
// carries the seal box stamped at the end; what opens further, a chevron. What would destroy keeps its words in the ink
// and only its sign in yamabuki. A row that cannot be taken is set in the third ink.
Item {
    id: root
    property var host
    readonly property var option: root.host?.skinData?.option ?? root.host?.option ?? ({})
    readonly property bool usable: root.option?.enabled !== false && (root.host?.enabled ?? true)
    readonly property bool lit: root.usable && (root.host?.lit ?? root.host?.hovered ?? false)
    readonly property bool pressed: root.usable && (root.host?.pressed ?? root.host?.down ?? false)
    readonly property bool danger: root.option?.danger === true
    readonly property bool marked: root.host?.marked ?? true
    readonly property bool compact: root.host?.compact ?? false
    readonly property int code: Number(root.host?.code ?? 0)
    readonly property real d: Airisu.d
    readonly property int glyphSize: Math.round((root.compact ? 15 : 17) * root.d)
    readonly property color ink: root.usable ? Airisu.ink : Airisu.inkThird
    readonly property int shift: root.pressed ? Airisu.hair : 0
    implicitWidth: row.implicitWidth + Airisu.u(6)

    ALacquer {
        anchors.fill: parent
        visible: root.pressed
        cut: Airisu.cutFor(height)
        lacquer: Airisu.underPlate(Airisu.ground)
        moving: false
    }
    Row {
        id: row
        x: Airisu.u(2.5) + root.shift
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.shift
        width: parent.width - Airisu.u(5)
        spacing: Airisu.u(2.5)
        AText {
            visible: root.code > 0
            anchors.verticalCenter: parent.verticalCenter
            width: Airisu.u(2)
            voice: "data"
            size: IrisStyle.typeCaption
            color: root.lit ? Airisu.sealText : Airisu.inkThird
            text: root.code
        }
        Item {
            visible: root.marked
            width: root.glyphSize
            height: root.glyphSize
            anchors.verticalCenter: parent.verticalCenter
            MaterialSymbol {
                anchors.centerIn: parent
                visible: String(root.option?.image ?? "").length === 0
                text: root.option?.iconName ?? ""
                iconSize: root.glyphSize
                color: root.danger && root.usable ? Airisu.caution : root.lit ? root.ink : Airisu.inkSecond
            }
            IconImage {
                anchors.centerIn: parent
                visible: String(root.option?.image ?? "").length > 0
                implicitSize: Math.round((root.compact ? 14 : 16) * root.d)
                source: String(root.option?.image ?? "")
            }
        }
        AText {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, row.width - (root.code > 0 ? Airisu.u(2) + row.spacing : 0) - (root.marked ? root.glyphSize + row.spacing : 0)
                - (tail.width > 0 ? tail.width + row.spacing : 0))
            size: IrisStyle.typeLabel
            font.weight: root.lit ? Font.DemiBold : Font.Medium
            font.family: String(root.option?.family ?? "").length > 0 ? root.option.family : Airisu.textFace
            color: root.ink
            text: String(root.option?.text ?? "")
        }
        Row {
            id: tail
            anchors.verticalCenter: parent.verticalCenter
            spacing: Airisu.u(1.5)
            AText {
                visible: text.length > 0
                anchors.verticalCenter: parent.verticalCenter
                voice: "mono"
                size: IrisStyle.typeCaption
                color: Airisu.inkThird
                text: String(root.option?.detail ?? "")
            }
            ASeal {
                visible: root.option?.checked === true
                anchors.verticalCenter: parent.verticalCenter
                width: Airisu.u(2.5)
                height: width
                stamped: true
                available: root.usable
            }
            MaterialSymbol {
                visible: root.option?.submenu === true
                anchors.verticalCenter: parent.verticalCenter
                text: "chevron_right"
                iconSize: Math.round(15 * root.d)
                color: Airisu.inkThird
            }
        }
    }
    AMarks {
        anchors.fill: parent
        shown: root.lit
        gap: Math.max(2, Math.round(Airisu.m / 2))
        arm: Math.max(3, Math.round(Airisu.m * 1.25))
    }
}
