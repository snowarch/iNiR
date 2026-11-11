pragma ComponentBehavior: Bound

// The looks of GlyphArt as a grid of small live samples of the person's own picture, to choose one by eye. Each
// sample is drawn once; all share one glyph sheet and one copy of the picture. Colours and type come from whoever
// places it, so it wears any family's face.

import QtQuick
import "GlyphArt.js" as Glyphs

Item {
    id: root

    property string current: "signal"
    // The picture sampled; while there is none, a built-in subject stands in.
    property url sample
    property var theme: ["#3b37d6", "#7f8cff", "#e8ebff", "#63e6b4"]
    property color textColor: "white"       // literal: replaced by the page's text colour
    property color ringColor: "white"       // literal: replaced by the page's accent
    property real chipRadius: 10
    property string fontFamily: "sans-serif"
    property int fontPixelSize: 12
    property real chipWidth: 132
    // Says a look's name in the person's language.
    property var translate: function (text) { return text }
    signal picked(string look)

    implicitHeight: flow.implicitHeight

    GlyphAtlas { id: sheet }
    Image {
        id: picture
        width: 264
        height: 160
        source: root.sample
        sourceSize: Qt.size(264, 160)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }

    Flow {
        id: flow
        width: root.width
        spacing: 10
        Repeater {
            model: Glyphs.lookNames()
            delegate: Item {
                id: chip
                required property var modelData
                readonly property bool chosen: root.current === chip.modelData.value
                width: root.chipWidth
                height: art.height + name.implicitHeight + 6

                GlyphArt {
                    id: art
                    width: parent.width
                    height: Math.round(parent.width * 0.6)
                    picture: picture
                    hidePicture: true
                    source: picture.status === Image.Ready ? "picture" : "planet"
                    atlas: sheet
                    live: false
                    radius: root.chipRadius
                    theme: root.theme
                    settings: Object.assign({}, Glyphs.lookSettings(chip.modelData.value), { cell: 5, intro: "off" })
                }
                Rectangle {
                    anchors.fill: art
                    anchors.margins: -3
                    radius: root.chipRadius + 3
                    color: "transparent"
                    border.width: 2
                    border.color: root.ringColor
                    visible: chip.chosen || hover.hovered
                    opacity: chip.chosen ? 1 : 0.35
                }
                Text {
                    id: name
                    anchors.top: art.bottom
                    anchors.topMargin: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.translate(chip.modelData.label)
                    color: root.textColor
                    opacity: chip.chosen ? 1 : 0.72
                    font.family: root.fontFamily
                    font.pixelSize: root.fontPixelSize
                    font.weight: chip.chosen ? Font.DemiBold : Font.Normal
                }
                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler { onTapped: root.picked(chip.modelData.value) }
            }
        }
    }
}
