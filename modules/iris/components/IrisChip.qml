pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style

IrisButton {
    id: chip
    property string glyph: ""
    property string label: ""
    property int order: -1
    property string artwork: ""
    readonly property real d: IrisStyle.density
    readonly property real inset: Math.round(12 * chip.d)
    property real labelCap: Math.round(200 * chip.d)

    implicitHeight: Math.round(30 * chip.d)
    implicitWidth: chipRow.implicitWidth + chip.inset * 2
    buttonRadius: height / 2
    buttonRadiusPressed: height / 2
    Accessible.name: chip.label

    Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: Math.round(5 * chip.d)
        IrisText {
            visible: chip.order >= 0
            anchors.verticalCenter: parent.verticalCenter
            text: chip.order + 1
            color: chip.foreground
            font.family: IrisStyle.fontNumbers
            font.pixelSize: IrisStyle.typeLabel
            font.weight: IrisStyle.weight(Font.Bold)
            font.features: { "tnum": 1 }
        }
        IrisArtwork {
            visible: chip.artwork.length > 0
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(20 * chip.d)
            height: width
            radius: IrisStyle.iconRadius(width)
            source: chip.artwork
            decodeSize: width * 2
        }
        MaterialSymbol {
            visible: chip.glyph.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: chip.glyph
            fill: 1
            iconSize: 16 * chip.d
            color: chip.foreground
        }
        IrisText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, chip.labelCap)
            elide: Text.ElideRight
            text: chip.label
            color: chip.foreground
            font.pixelSize: IrisStyle.typeLabel
            font.weight: chip.selected || chip.emphasized ? IrisStyle.weight(Font.DemiBold) : IrisStyle.weight(Font.Medium)
        }
    }
}
