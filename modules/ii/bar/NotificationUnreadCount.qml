import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

MaterialSymbol {
    id: root
    readonly property bool showUnreadCount: Config.options.bar.indicators.notifications.showUnreadCount
    text: Notifications.silent ? "notifications_paused" : "notifications"
    iconSize: Appearance.font.pixelSize.larger
    color: rightSidebarButton.colText

    Rectangle {
        id: notifPing
        readonly property real badgeHeight: root.showUnreadCount ? Math.max(notificationCounterText.implicitHeight + 2, 8) : 8

        opacity: !Notifications.silent && Notifications.unread > 0 ? 1 : 0
        visible: opacity > 0
        anchors {
            right: parent.right
            top: parent.top
            rightMargin: root.showUnreadCount ? 0 : 1
            topMargin: root.showUnreadCount ? 0 : 3
        }
        radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Math.min(width, height) / 2
        color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colOnLayer0
        z: 1

        implicitHeight: badgeHeight
        implicitWidth: root.showUnreadCount ? Math.max(badgeHeight, notificationCounterText.implicitWidth + 6) : badgeHeight

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on implicitWidth {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
        }
        Behavior on implicitHeight {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
        }
        Behavior on anchors.rightMargin {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on anchors.topMargin {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        StyledText {
            id: notificationCounterText
            opacity: root.showUnreadCount ? 1 : 0
            visible: opacity > 0
            anchors.centerIn: parent
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colLayer0
            text: root.showUnreadCount ? Notifications.unread : ""

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }
    }
}
