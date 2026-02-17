import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root
    property string displayText
    property string url

    property real faviconSize: 20
    implicitHeight: 30
    leftPadding: (implicitHeight - faviconSize) / 2
    rightPadding: 10
    buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
    colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2 
        : Appearance.auroraEverywhere ? "transparent" : Appearance.colors.colSurfaceContainerHighest
    colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover 
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colSurfaceContainerHighestHover
    colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active 
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colSurfaceContainerHighestActive

    PointingHandInteraction {}
    onClicked: {
        if (url) {
            Qt.openUrlExternally(url)
            GlobalStates.sidebarLeftOpen = false
        }
    }

    contentItem: Item {
        anchors.centerIn: parent
        implicitWidth: rowLayout.implicitWidth
        implicitHeight: rowLayout.implicitHeight
        RowLayout {
            id: rowLayout
            anchors.fill: parent
            spacing: 5
            Favicon {
                url: root.url
                size: root.faviconSize
                displayText: root.displayText
            }
            StyledText {
                id: text
                horizontalAlignment: Text.AlignHCenter
                text: displayText
                color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.m3colors.m3onSurface
            }
        }
    }
}
