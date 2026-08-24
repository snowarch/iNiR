import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root
    property bool embeddedInSystemIcons: false
    readonly property bool isMaterial: Config.options.bar.m3.cornerStyle === 3
    readonly property bool showUnreadCount: Config.options.bar.m3.indicators.notifications.showUnreadCount
    readonly property string iconName: Notifications.silent ? "notifications_paused" : "notifications"

    implicitWidth: root.embeddedInSystemIcons ? embeddedSymbol.implicitWidth : 32
    implicitHeight: root.embeddedInSystemIcons ? embeddedSymbol.implicitHeight : 32

    MaterialSymbol {
        id: embeddedSymbol
        anchors.centerIn: parent
        visible: root.embeddedInSystemIcons
        text: root.iconName
        iconSize: Appearance.font.pixelSize.larger
        color: root.isMaterial ? M3Palette.pillInk("systemIcons") : Appearance.colors.colOnLayer1
    }

    RippleButton {
        anchors.fill: parent
        visible: !root.embeddedInSystemIcons
        buttonRadius: Appearance.rounding.full
        colBackground: root.isMaterial ? M3Palette.primary : "transparent"
        colBackgroundHover: root.isMaterial
            ? ColorUtils.mix(M3Palette.primary, M3Palette.primaryForeground, 0.90)
            : Appearance.colors.colLayer1Hover
        colRipple: root.isMaterial
            ? ColorUtils.mix(M3Palette.primary, M3Palette.primaryForeground, 0.78)
            : Appearance.colors.colLayer1Active

        onPressed: {
            GlobalStates.toggleSidebarRight(root.QsWindow.window?.screen?.name ?? "")
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: !root.isMaterial
            text: root.iconName
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer0
        }

        MaterialShapeWrappedMaterialSymbol {
            anchors.centerIn: parent
            visible: root.isMaterial
            text: root.iconName
            iconSize: Appearance.font.pixelSize.normal
            color: M3Palette.primaryForeground
            colSymbol: M3Palette.primary
            shape: MaterialShape.Shape.Cookie12Sided
            padding: 2
        }
    }

    Rectangle {
        id: notifPing
        visible: !Notifications.silent && Notifications.unread > 0
        anchors {
            right: parent.right
            top: parent.top
            rightMargin: root.showUnreadCount ? 0 : 1
            topMargin: root.showUnreadCount ? 0 : 3
        }
        radius: Appearance.rounding.full
        color: root.isMaterial
            ? (root.embeddedInSystemIcons
                ? M3Palette.pillInk("systemIcons")
                : M3Palette.primaryForeground)
            : Appearance.colors.colOnLayer0
        z: 1
        implicitHeight: root.showUnreadCount ? Math.max(notificationCounterText.implicitWidth, notificationCounterText.implicitHeight) : 8
        implicitWidth: implicitHeight

        StyledText {
            id: notificationCounterText
            visible: root.showUnreadCount
            anchors.centerIn: parent
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: root.isMaterial
                ? (root.embeddedInSystemIcons
                    ? M3Palette.pillContainer("systemIcons")
                : M3Palette.primary)
                : Appearance.colors.colLayer0
            text: Notifications.unread
        }
    }
}
