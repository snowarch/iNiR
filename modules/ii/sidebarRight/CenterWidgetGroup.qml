import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.ii.sidebarRight.notifications
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    readonly property bool cardStyle: Config.options?.sidebar?.cardStyle ?? false

    radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    color: cardStyle ? "transparent"
        :(Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1)

    border.width: Appearance.inirEverywhere?1:0
    border.color: Appearance.inir.colBorder

    NotificationList {
        anchors.fill: parent
        anchors.margins: 5
    }
}
