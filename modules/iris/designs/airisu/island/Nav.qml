pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's page nav: the pages as marks on the sheet, the one you are on printed as a solid ink plate with its mark
// reversed out (the chosen box of a form), the one under the pointer with its crop marks. The plate stops on the next
// page in a detent; it never slides through the others. The engine (IrisIsland) owns the entries and what each does.
Item {
    id: root
    property var island: null
    readonly property real d: Airisu.d
    readonly property real slot: root.island?.navSlot ?? Math.round(34 * root.d)
    readonly property real plate: Math.min(root.slot - Airisu.u(1), Airisu.u(7))
    implicitHeight: Math.round(34 * root.d)

    Row {
        id: row
        anchors.centerIn: parent
        Repeater {
            model: root.island?.navEntries ?? []
            delegate: Item {
                id: entry
                required property var modelData
                readonly property bool divider: entry.modelData.kind === "|"
                readonly property string page: entry.modelData.page ?? ""
                readonly property bool lit: !entry.divider && entry.page.length > 0 && root.island?.effectivePage === entry.page
                width: entry.divider ? Airisu.u(3) : root.slot
                height: root.height

                Rectangle {
                    visible: entry.divider
                    anchors.centerIn: parent
                    width: Airisu.hair
                    height: Airisu.u(3.5)
                    color: Airisu.rule
                }
                APrint {
                    id: key
                    visible: !entry.divider
                    anchors.centerIn: parent
                    width: root.plate
                    height: root.plate
                    die: "rect"
                    pressed: tap.pressed
                    fill: entry.lit ? Airisu.ink : "transparent"
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: entry.modelData.glyph ?? ""
                        iconSize: Math.round(18 * root.d)
                        fill: entry.lit ? 1 : 0
                        color: entry.lit ? Airisu.reverse : hover.hovered ? Airisu.ink : Airisu.inkSecond
                    }
                }
                ATombo {
                    anchors.fill: key
                    shown: hover.hovered && !entry.lit && !tap.pressed
                }
                HoverHandler {
                    id: hover
                    enabled: !entry.divider
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: root.island?.hoverNav(entry.modelData.kind, entry.page, hover.hovered)
                }
                TapHandler {
                    id: tap
                    enabled: !entry.divider
                    onTapped: root.island?.activateNav(entry.modelData.kind)
                }
                Accessible.role: Accessible.Button
                Accessible.name: Translation.tr(entry.modelData.label ?? "")
            }
        }
    }
}
