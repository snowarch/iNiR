pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    required property date currentDate
    property string orientation: "horizontal"
    property real scaleFactor: 1
    property color softColor: Appearance.colors.colPrimaryContainer
    property color boldColor: Appearance.colors.colPrimary
    property bool showShadow: true

    readonly property bool vertical: root.orientation === "vertical"
    readonly property real desiredImplicitWidth: Math.round((root.vertical ? 276 : 420) * root.scaleFactor)
    readonly property real desiredImplicitHeight: Math.round((root.vertical ? 252 : 150) * root.scaleFactor)
    implicitWidth: root.desiredImplicitWidth
    implicitHeight: root.desiredImplicitHeight

    readonly property string digits: Qt.formatDateTime(root.currentDate, "HHmm")
    readonly property string glyphTopLeft: root.digits.charAt(0)
    readonly property string glyphTopRight: root.digits.charAt(1)
    readonly property string glyphBottomLeft: root.digits.charAt(2)
    readonly property string glyphBottomRight: root.digits.charAt(3)

    // Keep the original composition geometry. The Pixel style deliberately
    // overlaps large glyphs; changing these coordinates to chase rasterization
    // artifacts visibly shifts the design.
    readonly property real tileW: root.vertical ? root.width * 0.66 : root.width * 0.30
    readonly property real tileH: root.vertical ? root.height * 0.66 : root.height * 0.9
    readonly property real glyphSize: root.vertical ? root.height * 0.66 : root.height * 0.85

    readonly property real pos0X: 0
    readonly property real pos1X: root.vertical ? root.width * 0.30 : root.width * 0.15
    readonly property real pos2X: root.vertical ? 0 : root.width * 0.46
    readonly property real pos3X: root.vertical ? root.width * 0.30 : root.width * 0.60
    readonly property real pos0Y: root.vertical ? root.height * -0.04 : root.height * 0.05
    readonly property real pos1Y: root.pos0Y
    readonly property real pos2Y: root.vertical ? root.height * 0.42 : root.height * 0.05
    readonly property real pos3Y: root.pos2Y
    readonly property real colonX: root.pos1X + root.tileW
        + (root.pos2X - (root.pos1X + root.tileW)) / 2 - root.width * 0.03
    readonly property real colonDotSize: root.height * 0.2
    readonly property real colonGap: root.height * 0.04

    Item {
        id: glyphStage
        anchors.fill: parent

        component GlyphTile: Text {
            width: root.tileW
            height: root.tileH
            font.family: "Google Sans Flex"
            font.weight: 1000
            font.pixelSize: root.glyphSize
            font.variableAxes: ({ "wght": 1000 })
            // Pixel is intentionally Qt-rendered. Native/subpixel rasterization
            // can show RGB fringes on these oversized overlapping glyphs.
            renderType: Text.QtRendering
            font.hintingPreference: Font.PreferDefaultHinting
            style: root.showShadow ? Text.Raised : Text.Normal
            styleColor: Appearance.colors.colShadow
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        // Compose interlocking digits directly. The old alpha knockout left
        // transparent antialiased seams between overlapping glyphs; those seams
        // showed the wallpaper color and looked like chromatic/pixel glitches.
        // Normal z-order keeps the same geometry without exposing the backdrop.
        GlyphTile {
            x: root.pos0X
            y: root.pos0Y
            text: root.glyphTopLeft
            color: root.softColor
            z: 0
        }
        GlyphTile {
            x: root.pos1X
            y: root.pos1Y
            text: root.glyphTopRight
            color: root.boldColor
            z: 1
        }
        GlyphTile {
            x: root.pos2X
            y: root.pos2Y
            text: root.glyphBottomLeft
            color: root.boldColor
            z: 2
        }
        GlyphTile {
            x: root.pos3X
            y: root.pos3Y
            text: root.glyphBottomRight
            color: root.softColor
            z: 3
        }

        Column {
            visible: !root.vertical
            x: root.colonX
            y: root.pos0Y + root.tileH / 2 - height / 2
            spacing: root.colonGap
            z: 4
            Rectangle { width: root.colonDotSize; height: width; radius: width / 2; color: root.boldColor; anchors.horizontalCenter: parent.horizontalCenter }
            Rectangle { width: root.colonDotSize; height: width; radius: width / 2; color: root.boldColor; anchors.horizontalCenter: parent.horizontalCenter }
        }
    }
}
