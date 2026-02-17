import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import qs.modules.sidebarRight.notifications
import qs.modules.sidebarRight.volumeMixer
import Qt5Compat.GraphicalEffects as GE
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.normal
    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
         : Appearance.inirEverywhere ? Appearance.inir.colLayer1
         : Appearance.auroraEverywhere ? "transparent" 
         : Appearance.colors.colLayer1
    border.width: Appearance.angelEverywhere ? 0 : (Appearance.inirEverywhere ? 1 : 0)
    border.color: Appearance.angelEverywhere ? "transparent"
        : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"

    AngelPartialBorder { targetRadius: root.radius; coverage: 0.5 }

    NotificationList {
        anchors.fill: parent
        anchors.margins: 5
    }
}
