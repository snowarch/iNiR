import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root
    property string query

    implicitHeight: 30
    leftPadding: 6
    rightPadding: 10
    buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.verysmall
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
        let url = Config.options.search.engineBaseUrl + root.query;
        for (let site of (Config?.options?.search.excludedSites ?? [])) {
            url += ` -site:${site}`;
        }
        Qt.openUrlExternally(url);
        GlobalStates.sidebarLeftOpen = false;
    }

    contentItem: Item {
        anchors.centerIn: parent
        implicitWidth: rowLayout.implicitWidth
        implicitHeight: rowLayout.implicitHeight
        RowLayout {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 5
            MaterialSymbol {
                text: "search"
                iconSize: 20
                color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.m3colors.m3onSurface
            }
            StyledText {
                id: text
                horizontalAlignment: Text.AlignHCenter
                text: root.query
                color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.m3colors.m3onSurface
            }
        }
    }
}
