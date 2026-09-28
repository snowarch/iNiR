pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.pieces

// Every piece iRiS can place, one tile each. A tile carries its own state: lit when the piece is on
// screen. Tap to add or take it away; carry it on screen to place it.
ColumnLayout {
    id: root

    readonly property real d: IrisStyle.density
    readonly property var extras: IrisPieces.extras
    readonly property int onCount: {
        Config.revision
        return root.extras.filter(extra => root.isOn(extra.id)).length
    }
    function isOn(id: string): bool {
        return Config.options?.iris?.bubbles?.extras?.[id]?.enable ?? false
    }
    function toggle(id: string): void {
        Config.setNestedValue("iris.bubbles.extras." + id + ".enable", !root.isOn(id))
    }
    function glyphOf(kind: string): string {
        const chosen = IrisPieces.chosenGlyph(kind)
        if (chosen.length > 0) return chosen
        return ({ weather: "wb_sunny", notifications: "notifications", controls: "tune", sound: "volume_up", mic: "mic",
            tools: "timer", media: "play_circle", tray: "widgets", calendar: "calendar_month", clock: "schedule",
            battery: "battery_full", focus: "bedtime", network: "wifi", bluetooth: "bluetooth", vitals: "monitoring",
            workspaces: "grid_view", updates: "deployed_code_update", shellUpdate: "rocket_launch", vpn: "vpn_lock",
            anime: IrisPieces.glyphOf("anime", ""), watching: IrisPieces.glyphOf("watching", "") })[kind] ?? "circle"
    }

    spacing: Math.round(10 * root.d)

    IrisText {
        Layout.fillWidth: true
        text: root.onCount === 1 ? Translation.tr("1 piece on screen. Tap one to add it or take it away; carry it on screen to place it.")
            : Translation.tr("%1 pieces on screen. Tap one to add it or take it away; carry it on screen to place it.").arg(root.onCount)
        color: IrisStyle.textSecondary
        font.pixelSize: IrisStyle.typeMeta
        wrapMode: Text.WordWrap
    }

    GridLayout {
        id: grid
        Layout.fillWidth: true
        readonly property real cell: Math.round(70 * root.d)
        columns: Math.max(4, Math.floor((width + columnSpacing) / (grid.cell + columnSpacing)))
        columnSpacing: Math.round(4 * root.d)
        rowSpacing: Math.round(8 * root.d)

        Repeater {
            model: root.extras
            Item {
                id: tile
                required property var modelData
                readonly property bool on: { Config.revision; return root.isOn(tile.modelData.id) }
                readonly property bool ready: IrisPieces.available(tile.modelData.id)
                Layout.fillWidth: true
                Layout.preferredHeight: face.height + name.implicitHeight + Math.round(6 * root.d)
                opacity: tile.ready ? 1 : 0.45

                Rectangle {
                    id: face
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.round(42 * root.d)
                    height: width
                    radius: IrisStyle.iconRadius(width)
                    color: tile.on ? IrisStyle.tintFill(IrisStyle.accent)
                        : area.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet
                    border.width: tile.on ? 1 : 0
                    border.color: IrisStyle.tintBorder(IrisStyle.accent)
                    scale: area.pressed ? IrisStyle.pressScale(0.9) : area.containsMouse ? 1.04 : 1
                    Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                    Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.glyphOf(tile.modelData.id)
                        fill: tile.on ? 1 : 0
                        iconSize: Math.round(20 * root.d)
                        color: tile.on ? IrisStyle.accent : IrisStyle.text
                    }
                }
                IrisText {
                    id: name
                    anchors.top: face.bottom
                    anchors.topMargin: Math.round(5 * root.d)
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.tr(tile.modelData.label)
                    color: tile.on ? IrisStyle.text : IrisStyle.muted
                    font.pixelSize: IrisStyle.typeFootnote
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: tile.ready
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.CheckBox
                    Accessible.name: tile.modelData.label
                    Accessible.checked: tile.on
                    onClicked: root.toggle(tile.modelData.id)
                }
            }
        }
    }
}
