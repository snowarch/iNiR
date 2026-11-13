import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// One way to capture, as a tile: the glyph in the record colour, what it does, and how it does it.
RippleButton {
    id: tile
    property string glyph
    property string label
    property string detail

    Layout.fillWidth: true
    Layout.fillHeight: true
    padding: 0
    rippleEnabled: !OverlayLook.own && !Appearance.regaliaEverywhere && !Appearance.editorialEverywhere
    buttonRadius: OverlayLook.roundingNormal
    colBackground: OverlayLook.colLayer2
    colBackgroundHover: OverlayLook.colLayer2Hover
    colRipple: OverlayLook.colLayer2Active
    Accessible.name: tile.label
    contentItem: Item {
        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Math.round(12 * OverlayLook.d)
            spacing: Math.round(1 * OverlayLook.d)
            MaterialSymbol {
                text: tile.glyph
                iconSize: Math.round(24 * OverlayLook.d)
                fill: 1
                color: OverlayLook.colError
            }
            Item { width: 1; height: Math.round(5 * OverlayLook.d) }
            StyledText {
                width: parent.width
                elide: Text.ElideRight
                text: tile.label
                color: OverlayLook.colOnLayer1
                font.family: OverlayLook.fontMain
                font.pixelSize: OverlayLook.typeBody
                font.weight: Font.DemiBold
            }
            StyledText {
                width: parent.width
                elide: Text.ElideRight
                visible: text.length > 0
                text: tile.detail
                color: OverlayLook.colSubtext
                font.family: OverlayLook.fontMain
                font.pixelSize: OverlayLook.typeMeta
            }
        }
    }
}
