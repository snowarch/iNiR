pragma ComponentBehavior: Bound
import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// Ledger's page buttons: glyphs, and the page you are on says its name in a plate that opens round it.
Item {
    id: root
    property var island: null
    readonly property real d: IrisStyle.density
    readonly property real key: Math.round(30 * root.d)
    readonly property var names: ({ media: "Music", activity: "Live", desktop: "Home", weather: "Weather", calendar: "Days",
        vitals: "System", tray: "Tray", tools: "Timers" })
    implicitHeight: Math.round(36 * root.d)

    Row {
        anchors.centerIn: parent
        spacing: Math.round(2 * root.d)
        Repeater {
            model: root.island?.navEntries ?? []
            delegate: Item {
                id: entry
                required property var modelData
                readonly property bool divider: entry.modelData.kind === "|"
                readonly property string page: entry.modelData.page ?? ""
                readonly property bool lit: !entry.divider && entry.page.length > 0 && root.island?.effectivePage === entry.page
                readonly property string name: Translation.tr(root.names[entry.modelData.kind] ?? "")
                width: entry.divider ? Math.round(11 * root.d) : plate.width
                height: root.height

                Rectangle {
                    visible: entry.divider
                    anchors.centerIn: parent
                    width: 1
                    height: Math.round(14 * root.d)
                    color: IrisStyle.hairline
                }
                Rectangle {
                    id: plate
                    visible: !entry.divider
                    anchors.centerIn: parent
                    height: root.key
                    width: entry.lit ? label.implicitWidth + root.key + Math.round(6 * root.d) : root.key
                    radius: height / 2
                    color: entry.lit ? IrisStyle.selectionFill : hover.hovered ? IrisStyle.fillHoverOf(IrisStyle.text) : "transparent"
                    Behavior on width { NumberAnimation { duration: IrisStyle.duration(220); easing.type: IrisStyle.feedbackEasing } }
                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                    clip: true
                    MaterialSymbol {
                        x: Math.round((root.key - width) / 2)
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.glyph ?? ""
                        iconSize: Math.round(17 * root.d)
                        fill: entry.lit ? 1 : 0
                        color: entry.lit ? IrisStyle.selectionLabel : hover.hovered ? IrisStyle.text : IrisStyle.subtext
                    }
                    IrisText {
                        id: label
                        x: root.key - Math.round(3 * root.d)
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.name
                        opacity: entry.lit ? 1 : 0
                        font.pixelSize: IrisStyle.typeMeta
                        font.weight: IrisStyle.weight(Font.DemiBold)
                        color: IrisStyle.selectionLabel
                        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                    }
                }
                HoverHandler {
                    id: hover
                    enabled: !entry.divider
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: root.island?.hoverNav(entry.modelData.kind, entry.page, hover.hovered)
                }
                TapHandler {
                    enabled: !entry.divider
                    onTapped: root.island?.activateNav(entry.modelData.kind)
                }
                Accessible.role: Accessible.Button
                Accessible.name: Translation.tr(entry.modelData.label ?? "")
            }
        }
    }
}
