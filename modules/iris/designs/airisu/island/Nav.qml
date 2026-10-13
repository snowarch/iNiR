pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's page nav: the pages as quiet keys (AKey), the one you are on on the chosen plate with its mark cut out of it,
// the one under the pointer with its coat laid at 45°. A group is parted from the next by air. The engine (IrisIsland)
// owns the entries and what each does.
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

                AKey {
                    id: key
                    visible: !entry.divider
                    anchors.centerIn: parent
                    width: root.plate
                    height: root.plate
                    lacquer: entry.lit ? IrisStyle.selectionFill : "transparent"
                    hovered: hover.hovered && !entry.lit
                    pressed: tap.pressed
                    MaterialSymbol {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: key.shift
                        anchors.verticalCenterOffset: key.shift
                        text: entry.modelData.glyph ?? ""
                        iconSize: Math.round(18 * root.d)
                        fill: entry.lit ? 1 : 0
                        color: entry.lit ? IrisStyle.selectionLabel : hover.hovered ? Airisu.ink : Airisu.inkSecond
                    }
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
