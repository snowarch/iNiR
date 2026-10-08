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
    property string labelFamily: ""

    implicitHeight: Math.max(Math.round(30 * chip.d), Math.round(chipLabel.implicitHeight + 10 * chip.d))
    implicitWidth: chipLabel.lead + Math.min(chipLabel.implicitWidth, chip.labelCap) + chip.inset * 2
    buttonRadius: IrisStyle.controlPlated ? IrisStyle.pieceRadius(height) : height / 2
    buttonRadiusPressed: buttonRadius
    Accessible.name: chip.label

    Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: Math.round(5 * chip.d)
        IrisText {
            id: chipOrder
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
            id: chipArt
            visible: chip.artwork.length > 0
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(20 * chip.d)
            height: width
            radius: IrisStyle.iconRadius(width)
            source: chip.artwork
            decodeSize: width * 2
        }
        MaterialSymbol {
            id: chipGlyph
            visible: chip.glyph.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: chip.glyph
            fill: 1
            iconSize: 16 * chip.d
            color: chip.foreground
        }
        IrisText {
            id: chipLabel
            anchors.verticalCenter: parent.verticalCenter
            readonly property real lead: (chipOrder.visible ? chipOrder.implicitWidth + chipRow.spacing : 0)
                + (chipArt.visible ? chipArt.width + chipRow.spacing : 0)
                + (chipGlyph.visible ? chipGlyph.implicitWidth + chipRow.spacing : 0)
            width: Math.max(0, Math.min(implicitWidth, chip.labelCap, chip.width - chip.inset * 2 - lead))
            elide: Text.ElideRight
            text: chip.label
            color: chip.foreground
            font.family: chip.labelFamily.length > 0 ? chip.labelFamily : IrisStyle.fontMain
            font.pixelSize: IrisStyle.typeLabel
            font.weight: chip.selected || chip.emphasized ? IrisStyle.weight(Font.DemiBold) : IrisStyle.weight(Font.Medium)
        }
    }
}
