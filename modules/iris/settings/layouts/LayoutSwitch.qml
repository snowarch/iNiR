pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// The three layouts, one key each, in every layout's head: switching keeps the place and morphs the page.
// Folio sets it as a quiet word pill, Console as Nothing's white key on grey; `compact` leaves the glyphs alone.
Rectangle {
    id: root
    property Item host
    property string voice: "folio"
    property bool compact: false
    readonly property real d: IrisStyle.settingsDensity
    readonly property var keys: [
        { id: "folio", glyph: "article", name: Translation.tr("Folio") },
        { id: "deck", glyph: "view_carousel", name: Translation.tr("Deck") },
        { id: "console", glyph: "grid_view", name: Translation.tr("Console") }
    ]
    readonly property bool mono: root.voice === "console"
    implicitHeight: Math.round((root.mono ? 40 : 36) * root.d)
    implicitWidth: keyRow.implicitWidth + 6
    radius: height / 2
    color: root.mono ? IrisStyle.fillQuiet : "transparent"
    border.width: root.mono ? 0 : 1
    border.color: IrisStyle.hairline
    Accessible.role: Accessible.PageTabList
    Accessible.name: Translation.tr("Layout")

    Row {
        id: keyRow
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: root.keys.filter(entry => root.host?.layouts?.[entry.id] !== undefined)
            MouseArea {
                id: key
                required property var modelData
                readonly property bool on: String(root.host?.layout ?? "") === key.modelData.id
                width: keyContent.implicitWidth + Math.round((root.compact ? 18 : 26) * root.d)
                height: root.height - 6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.PageTab
                Accessible.name: key.modelData.name
                Accessible.checked: key.on
                onClicked: root.host.setLayout(key.modelData.id)
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: key.on ? (root.mono ? IrisStyle.text : IrisStyle.fill) : key.containsMouse ? IrisStyle.fillQuiet : "transparent"
                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                }
                Row {
                    id: keyContent
                    anchors.centerIn: parent
                    spacing: Math.round(6 * root.d)
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: key.modelData.glyph
                        iconSize: Math.round(16 * root.d)
                        fill: key.on ? 1 : 0
                        color: key.on && root.mono ? IrisStyle.surfaceOpaque : key.on ? IrisStyle.text : IrisStyle.muted
                    }
                    IrisText {
                        visible: !root.compact
                        anchors.verticalCenter: parent.verticalCenter
                        text: key.modelData.name
                        color: key.on && root.mono ? IrisStyle.surfaceOpaque : key.on ? IrisStyle.text : IrisStyle.muted
                        font.family: root.mono ? IrisStyle.fontMono : IrisStyle.fontMain
                        font.capitalization: root.mono ? Font.AllUppercase : Font.MixedCase
                        font.letterSpacing: root.mono ? Math.round(IrisStyle.typeCaption * 0.12) : 0
                        font.pixelSize: root.mono ? IrisStyle.typeCaption : IrisStyle.typeMeta
                        font.weight: Font.Medium
                    }
                }
            }
        }
    }
}
