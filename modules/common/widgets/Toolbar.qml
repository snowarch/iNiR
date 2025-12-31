import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * Material 3 expressive style toolbar.
 * https://m3.material.io/components/toolbars
 */
Item {
    id: root

    property bool enableShadow: true
    property real padding: 8
    property alias colBackground: background.color
    property alias spacing: toolbarLayout.spacing
    default property alias data: toolbarLayout.data
    implicitWidth: background.implicitWidth
    implicitHeight: background.implicitHeight
    property alias radius: background.radius

    Loader {
        active: root.enableShadow && !Appearance.inirEverywhere
        anchors.fill: background
        sourceComponent: StyledRectangularShadow {
            target: background
            anchors.fill: undefined
        }
    }

    GlassBackground {
        id: background
        anchors.fill: parent
        fallbackColor: Appearance.m3colors.m3surfaceContainer
        inirColor: Appearance.inir.colLayer2
        auroraTransparency: Appearance.aurora.tooltipTransparentize
        border.width: (Appearance.inirEverywhere || Appearance.auroraEverywhere) ? 1 : 0
        border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder 
            : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder : "transparent"
        implicitHeight: 56
        implicitWidth: toolbarLayout.implicitWidth + root.padding * 2
        radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : (height / 2)

        RowLayout {
            id: toolbarLayout
            spacing: 4
            anchors {
                fill: parent
                margins: root.padding
            }
        }
    }
}
