import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    required property string text
    property bool shown: false
    property string position: "bottom" // "bottom", "top", "left", "right"
    property real horizontalPadding: 10
    property real verticalPadding: 5
    property alias font: tooltipTextObject.font
    implicitWidth: tooltipTextObject.implicitWidth + 2 * root.horizontalPadding
    implicitHeight: tooltipTextObject.implicitHeight + 2 * root.verticalPadding

    property bool isVisible: backgroundRectangle.implicitHeight > 0

    Rectangle {
        id: backgroundRectangle
        // Grow from the edge nearest to the anchor
        x: root.position === "left" ? root.implicitWidth - implicitWidth
         : root.position === "right" ? 0
         : (root.implicitWidth - implicitWidth) / 2
        y: root.position === "top" ? root.implicitHeight - implicitHeight
         : root.position === "bottom" ? 0
         : (root.implicitHeight - implicitHeight) / 2
        color: Appearance.regaliaEverywhere ? "transparent"
             : Appearance.angelEverywhere ? Appearance.angel.colGlassTooltip
             : Appearance.inirEverywhere ? Appearance.inir.colLayer2
             : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipSurface
             : Appearance.colors.colLayer3
        radius: Appearance.regaliaEverywhere ? Appearance.regalia.roundSmall
             : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
             : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
             : Appearance.rounding.verysmall
        border.width: Appearance.regaliaEverywhere ? 0
             : Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
        border.color: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
                    : Appearance.inirEverywhere ? Appearance.inir.colBorder
                    : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder
                    : Appearance.colors.colLayer3Hover
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.94
        transformOrigin: root.position === "top" ? Item.Bottom
                       : root.position === "left" ? Item.Right
                       : root.position === "right" ? Item.Left
                       : Item.Top
        implicitWidth: shown ? (tooltipTextObject.implicitWidth + 2 * root.horizontalPadding) : 0
        implicitHeight: shown ? (tooltipTextObject.implicitHeight + 2 * root.verticalPadding) : 0
        clip: true

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on scale {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on implicitWidth {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on implicitHeight {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        RegaliaPlate {
            anchors.fill: parent
            visible: Appearance.regaliaEverywhere
            fillColor: Appearance.regalia.bg3
            radius: backgroundRectangle.radius
            inset: Appearance.regalia.controlInset
            elevated: true
        }

        AngelPartialBorder {
            targetRadius: backgroundRectangle.radius
            coverage: 0.45
        }

        StyledText {
            id: tooltipTextObject
            anchors.centerIn: parent
            text: root.text
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.hintingPreference: Font.PreferNoHinting // Prevent shaky text
            color: Appearance.regaliaEverywhere ? Appearance.regalia.onColor
                : Appearance.angelEverywhere ? Appearance.angel.colText
                : Appearance.inirEverywhere ? Appearance.inir.colText
                : Appearance.colors.colOnLayer3
            wrapMode: Text.Wrap
        }
    }   
}

