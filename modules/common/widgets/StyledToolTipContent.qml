import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    required property string text
    property bool shown: false
    property real horizontalPadding: 10
    property real verticalPadding: 5
    property alias font: tooltipTextObject.font
    implicitWidth: tooltipTextObject.implicitWidth + 2 * root.horizontalPadding
    implicitHeight: tooltipTextObject.implicitHeight + 2 * root.verticalPadding

    property bool isVisible: backgroundRectangle.implicitHeight > 0

    Rectangle {
        id: backgroundRectangle
        anchors {
            bottom: root.bottom
            horizontalCenter: root.horizontalCenter
        }
        color: Appearance.angelEverywhere ? Appearance.angel.colGlassTooltip
             : Appearance.inirEverywhere ? Appearance.inir.colLayer2
             : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipSurface
             : Appearance.colors.colLayer3
        radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
             : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
             : Appearance.rounding.verysmall
        border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
        border.color: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
                    : Appearance.inirEverywhere ? Appearance.inir.colBorder
                    : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder
                    : Appearance.colors.colLayer3Hover
        opacity: shown ? 1 : 0
        scale: shown ? 1.0 : 0.85
        transformOrigin: Item.Center
        implicitWidth: shown ? (tooltipTextObject.implicitWidth + 2 * root.horizontalPadding) : 0
        implicitHeight: shown ? (tooltipTextObject.implicitHeight + 2 * root.verticalPadding) : 0
        clip: true

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
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
            color: Appearance.angelEverywhere ? Appearance.angel.colText
                : Appearance.inirEverywhere ? Appearance.inir.colText
                : Appearance.colors.colOnLayer3
            wrapMode: Text.Wrap
        }
    }   
}

