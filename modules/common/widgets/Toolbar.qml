import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

/**
 * Material 3 expressive style toolbar.
 * https://m3.material.io/components/toolbars
 */
Item {
    id: root

    property bool enableShadow: true
    property bool transparent: false  // When true, no background (for nested in panels with blur)
    property real padding: 8
    property alias colBackground: background.color
    property alias spacing: toolbarLayout.spacing
    default property alias contentData: toolbarLayout.data
    implicitWidth: background.implicitWidth
    implicitHeight: background.implicitHeight
    property alias radius: background.radius
    
    // Screen position for aurora blur alignment (set by parent if needed)
    property real screenX: 0
    property real screenY: 0

    Loader {
        active: root.enableShadow && !root.transparent && (Appearance.angelEverywhere || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere))
        anchors.fill: background
        sourceComponent: StyledRectangularShadow {
            target: background
            anchors.fill: undefined
        }
    }

    GlassBackground {
        id: background
        anchors.fill: parent
        visible: !root.transparent
        fallbackColor: Appearance.m3colors.m3surfaceContainer
        inirColor: Appearance.inir.colLayer2
        auroraTransparency: Appearance.aurora.overlayTransparentize
        screenX: root.screenX
        screenY: root.screenY
        screenWidth: Quickshell.screens[0]?.width ?? 1920
        screenHeight: Quickshell.screens[0]?.height ?? 1080
        border.width: (Appearance.angelEverywhere || Appearance.inirEverywhere || Appearance.auroraEverywhere) ? 1 : 0
        border.color: Appearance.angelEverywhere ? Appearance.angel.colBorder
            : Appearance.inirEverywhere ? Appearance.inir.colBorder 
            : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder : "transparent"
        implicitHeight: 56
        implicitWidth: toolbarLayout.implicitWidth + root.padding * 2
        radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
            : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : (height / 2)
    }

    RowLayout {
        id: toolbarLayout
        spacing: 4
        anchors {
            fill: parent
            margins: root.padding
        }
    }
}
