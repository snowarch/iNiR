pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.preview.parts

PreviewScene {
    id: zonesRoot
    readonly property real naturalWidth: Math.round(680 * zonesRoot.d)
    readonly property real naturalHeight: Math.round(220 * zonesRoot.d)
    readonly property var names: ({ island: "Island", workspaces: "Workspaces", window: "Window", time: "Time", tray: "Tray",
        notifications: "Notifications", sound: "Sound", controls: "Controls", mic: "Mic", weather: "Weather", tools: "Tools", media: "Media" })
    function listOf(path: string, fallback: var): var { return Array.from(zonesRoot.opt(path, fallback) ?? []).map(kind => String(kind)) }
    readonly property var zones: [
        zonesRoot.listOf("iris.bar.fullStart", ["workspaces", "window"]),
        zonesRoot.listOf("iris.bar.fullCenter", ["island"]),
        zonesRoot.listOf("iris.bar.fullEnd", ["tray", "notifications", "sound", "controls"])
    ]
    readonly property real thick: IrisFrame.islandBand
    property real t: 0
    NumberAnimation on t { running: zonesRoot.playing; from: 0; to: 3; duration: IrisStyle.duration(5400); loops: Animation.Infinite }
    readonly property int lit: Math.min(2, Math.floor(zonesRoot.t))
    Rectangle {
        id: bar
        x: Math.round(16 * zonesRoot.d)
        y: Math.round(28 * zonesRoot.d)
        width: parent.width - 2 * x
        height: zonesRoot.thick
        radius: IrisStyle.radiusChip
        color: IrisStyle.bodySurface
        border.width: IrisStyle.rim.a > 0 ? 1 : 0
        border.color: IrisStyle.rim
        IrisGlassEdge { anchors.fill: parent; z: 10; visible: IrisStyle.edgeLit && shown; radius: parent.radius }
        Repeater {
            model: 3
            Row {
                id: zone
                required property int index
                readonly property var kinds: zonesRoot.zones[zone.index]
                spacing: Math.round(6 * zonesRoot.d)
                anchors.verticalCenter: parent.verticalCenter
                x: zone.index === 0 ? Math.round(8 * zonesRoot.d) : zone.index === 1 ? Math.round((bar.width - width) / 2) : bar.width - width - Math.round(8 * zonesRoot.d)
                Repeater {
                    model: zone.kinds
                    Rectangle {
                        required property string modelData
                        readonly property bool current: zonesRoot.lit === zone.index
                        implicitWidth: chipLabel.implicitWidth + Math.round(16 * zonesRoot.d)
                        implicitHeight: zonesRoot.thick - Math.round(10 * zonesRoot.d)
                        radius: height / 2
                        color: current ? IrisStyle.tintFill(IrisStyle.accent) : IrisStyle.fill
                        Behavior on color { ColorAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                        IrisText {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: modelData === "time" ? Qt.formatTime(new Date(), "hh:mm") : Translation.tr(zonesRoot.names[modelData] ?? modelData)
                            font.pixelSize: IrisStyle.typeMeta
                            color: parent.current ? IrisStyle.text : IrisStyle.subtext
                        }
                    }
                }
            }
        }
    }
    Caption {
        glyph: ["align_horizontal_left", "align_horizontal_center", "align_horizontal_right"][zonesRoot.lit]
        text: [Translation.tr("Start"), Translation.tr("Centre"), Translation.tr("End")][zonesRoot.lit] + ": "
            + (zonesRoot.zones[zonesRoot.lit].length > 0 ? zonesRoot.zones[zonesRoot.lit].map(kind => Translation.tr(zonesRoot.names[kind] ?? kind)).join(", ") : Translation.tr("empty"))
    }
}
