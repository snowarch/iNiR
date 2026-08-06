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
    property bool collapsed: false
    implicitHeight: notificationList.implicitHeight + 10
    radius: Appearance.zzzEverywhere ? Appearance.zzz.cardRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.normal
    Behavior on radius {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    color: Appearance.zzzEverywhere ? "transparent"
         : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
         : Appearance.inirEverywhere ? Appearance.inir.colLayer1
         : Appearance.auroraEverywhere ? "transparent"
         : Appearance.colors.colLayer1
    Behavior on color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    border.width: Appearance.zzzEverywhere ? 0 : (Appearance.angelEverywhere ? 0 : (Appearance.inirEverywhere ? 1 : 0))
    Behavior on border.width {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    border.color: Appearance.zzzEverywhere ? "transparent"
        : Appearance.angelEverywhere ? "transparent"
        : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
    Behavior on border.color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    AngelPartialBorder { targetRadius: root.radius; coverage: 0.5 }

    NotificationList {
        id: notificationList
        anchors.fill: parent
        anchors.margins: 5
        collapsed: root.collapsed
    }
}
