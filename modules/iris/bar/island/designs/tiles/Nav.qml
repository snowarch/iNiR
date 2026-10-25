pragma ComponentBehavior: Bound
import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style

// Tiles' page buttons: the pages on one track with a thumb that slides to the one you are on; the panels and Settings
// stand apart, as round keys.
Item {
    id: root
    property var island: null
    readonly property real d: IrisStyle.density
    readonly property real key: Math.round(30 * root.d)
    readonly property var entries: root.island?.navEntries ?? []
    readonly property var pages: root.entries.filter(entry => (entry.page ?? "").length > 0)
    readonly property var actions: root.entries.filter(entry => entry.kind !== "|" && (entry.page ?? "").length === 0)
    readonly property int litIndex: root.pages.findIndex(entry => entry.page === root.island?.effectivePage)
    implicitHeight: Math.round(38 * root.d)

    component Key: Item {
        id: keyItem
        required property var modelData
        property bool lit: false
        width: root.key
        height: root.key
        MaterialSymbol {
            anchors.centerIn: parent
            text: keyItem.modelData.glyph ?? ""
            iconSize: Math.round(17 * root.d)
            fill: keyItem.lit ? 1 : 0
            color: keyItem.lit ? IrisStyle.selectionLabel : hover.hovered ? IrisStyle.text : IrisStyle.subtext
        }
        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: root.island?.hoverNav(keyItem.modelData.kind, keyItem.modelData.page ?? "", hover.hovered)
        }
        TapHandler { onTapped: root.island?.activateNav(keyItem.modelData.kind) }
        Accessible.role: Accessible.Button
        Accessible.name: Translation.tr(keyItem.modelData.label ?? "")
    }

    Row {
        anchors.centerIn: parent
        spacing: Math.round(8 * root.d)

        Rectangle {
            width: track.implicitWidth + Math.round(6 * root.d)
            height: root.key + Math.round(6 * root.d)
            radius: height / 2
            color: IrisStyle.fillQuiet
            Rectangle {
                visible: root.litIndex >= 0
                x: Math.round(3 * root.d) + Math.max(0, root.litIndex) * root.key
                y: Math.round(3 * root.d)
                width: root.key
                height: root.key
                radius: height / 2
                color: IrisStyle.selectionFill
                Behavior on x { NumberAnimation { duration: IrisStyle.duration(260); easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
            }
            Row {
                id: track
                x: Math.round(3 * root.d)
                y: Math.round(3 * root.d)
                Repeater {
                    model: root.pages
                    delegate: Key { required property int index; lit: index === root.litIndex }
                }
            }
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(2 * root.d)
            Repeater {
                model: root.actions
                delegate: Key {}
            }
        }
    }
}
