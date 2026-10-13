import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// The record as it sits in a Japanese shop: the cover with its 帯 obi, the band wrapped round its left edge in music's
// pigment, the artist set up it. Square; `cover` is the artwork itself, so a surface can fly it (the Island's cover
// flight). A round cover is a disc and carries no obi. With no picture the sleeve is an empty slot: its die dashed, the
// note in the slot's quiet tone.
Item {
    id: root
    property url source
    property string artist
    property bool circular: false
    property bool empty: false
    property color obi: Airisu.vivid(Airisu.pigment("music"))
    property color obiInk: Airisu.inkOn(root.obi)
    // The empty slot's tone, from the surface the record sits on.
    property color tone: Airisu.inkThird
    readonly property alias cover: art
    readonly property real d: Airisu.d
    implicitWidth: Math.round(132 * root.d)
    implicitHeight: root.width

    IrisArtwork {
        id: art
        width: root.width
        height: root.height
        visible: !root.empty
        source: root.source
        circular: root.circular
        radius: root.circular ? width / 2 : 0
    }
    ADie {
        anchors.fill: parent
        visible: root.empty
        kind: "chamfer"
        stroke: root.tone
        strokeWidth: Airisu.hair
        dashed: true
        MaterialSymbol {
            anchors.centerIn: parent
            text: "music_note"
            fill: 1
            iconSize: Math.round(root.width * 0.3)
            color: root.tone
        }
    }
    Rectangle {
        id: band
        visible: !root.circular && !root.empty && root.artist.length > 0
        width: Math.round(root.width * 0.16)
        height: root.height
        color: root.obi
        AText {
            // Rotated about its own centre to read bottom to top, from the foot of the band.
            readonly property real room: band.height - Math.round(16 * root.d)
            width: Math.min(implicitWidth, room)
            x: Math.round((band.width - width) / 2)
            y: Math.round(band.height - Math.round(8 * root.d) - width / 2 - height / 2)
            rotation: -90
            size: band.width >= Math.round(26 * root.d) ? IrisStyle.typeLabel : IrisStyle.typeMeta
            font.weight: Font.Bold
            text: root.artist
            color: root.obiInk
        }
    }
}
