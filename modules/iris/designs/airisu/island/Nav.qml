pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's page nav: unlit marks on the lacquer and the page you are on lit, with the seal under it like the lamp of a
// selector. No plate, no buttons drawn at rest; the engine (IrisIsland) owns the entries and what each one does.
Item {
    id: root
    property var island: null
    readonly property real d: Airisu.d
    implicitHeight: Math.round(34 * root.d)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Math.round(2 * root.d)
        Repeater {
            model: root.island?.navEntries ?? []
            delegate: Item {
                id: slot
                required property var modelData
                readonly property bool divider: slot.modelData.kind === "|"
                readonly property string page: slot.modelData.page ?? ""
                readonly property bool lit: !slot.divider && slot.page.length > 0 && root.island?.effectivePage === slot.page
                width: slot.divider ? Math.round(13 * root.d) : Math.round(38 * root.d)
                height: root.height

                Rectangle {
                    visible: slot.divider
                    anchors.centerIn: parent
                    width: Airisu.line
                    height: Math.round(14 * root.d)
                    color: Airisu.fillet
                }
                MaterialSymbol {
                    visible: !slot.divider
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -Math.round(2 * root.d)
                    text: slot.modelData.glyph ?? ""
                    iconSize: Math.round(19 * root.d)
                    fill: 0
                    color: slot.lit ? Airisu.gofun : hover.hovered ? Airisu.data : Airisu.quiet
                    Behavior on color { enabled: IrisStyle.motionEnabled; ColorAnimation { duration: Airisu.shift } }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    width: slot.lit ? Math.round(16 * root.d) : 0
                    height: Math.max(2, Math.round(2 * root.d))
                    color: Airisu.seal
                    Behavior on width { enabled: IrisStyle.motionEnabled; NumberAnimation { duration: Airisu.shift; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
                }
                HoverHandler {
                    id: hover
                    enabled: !slot.divider
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: root.island?.hoverNav(slot.modelData.kind, slot.page, hover.hovered)
                }
                TapHandler {
                    enabled: !slot.divider
                    onTapped: root.island?.activateNav(slot.modelData.kind)
                }
                Accessible.role: Accessible.Button
                Accessible.name: Translation.tr(slot.modelData.label ?? "")
            }
        }
    }
}
