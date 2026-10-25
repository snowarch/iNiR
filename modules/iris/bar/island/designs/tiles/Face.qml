pragma ComponentBehavior: Bound
import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// Tiles: your link, Bluetooth and sound as quiet marks (full ink when up, faint when off), the time on a plate of its
// own and the day after it. Only the resting clock; the engine draws the rest.
Item {
    id: root
    property var island: null
    readonly property var modes: ["idle", "clock"]
    readonly property real d: IrisStyle.density
    readonly property real h: root.island?.compactHeight ?? 42
    readonly property real contentWidth: row.implicitWidth
    readonly property date now: DateTime.clock.date
    readonly property bool muted: Audio.sink?.audio?.muted ?? false
    readonly property var marks: [
        { glyph: Network.materialSymbol || "wifi", up: Network.ethernet || Network.wifiEnabled },
        { glyph: BluetoothStatus.connected ? "bluetooth_connected" : "bluetooth", up: BluetoothStatus.connected, shown: BluetoothStatus.available },
        { glyph: root.muted ? "volume_off" : "volume_up", up: !root.muted }
    ].filter(mark => mark.shown !== false)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Math.round(8 * root.d)

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(4 * root.d)
            Repeater {
                model: root.marks
                delegate: MaterialSymbol {
                    required property var modelData
                    text: modelData.glyph
                    iconSize: Math.round(14 * root.d)
                    fill: 1
                    color: modelData.up ? IrisStyle.text : IrisStyle.textTertiary
                }
            }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            height: Math.round(root.h - 12 * root.d)
            width: clock.implicitWidth + Math.round(16 * root.d)
            radius: Math.min(height / 2, IrisStyle.radiusRow)
            color: IrisStyle.fillQuiet
            IrisClock {
                id: clock
                anchors.centerIn: parent
                pixelSize: Math.round((root.island?.figureSize ?? IrisStyle.typeHeadline) * 0.92)
                family: root.island?.nothingLook ? IrisStyle.fontDot : IrisStyle.figureFace(pixelSize)
                separatorColor: root.island?.clockAccent ?? IrisStyle.accent
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            IrisText {
                text: Translation.locale.toString(root.now, "ddd").replace(/\.$/, "")
                font.pixelSize: Math.round(10 * root.d)
                font.weight: IrisStyle.weight(Font.Medium)
                color: IrisStyle.subtext
            }
            IrisText {
                text: Translation.locale.toString(root.now, "d")
                font.pixelSize: Math.round(13 * root.d)
                font.family: IrisStyle.fontNumbers
                font.weight: IrisStyle.weight(Font.Bold)
                font.features: ({ "tnum": 1 })
                color: root.island?.clockAccent ?? IrisStyle.accent
            }
        }
    }
}
