import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Dashboard header strip: uptime chip on the left, quick actions on the
 * right (DND, settings, wallpapers, lock, session).
 */
RowLayout {
    id: root
    spacing: 8

    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere
    readonly property bool showPowerButtons: Config.options?.dashboard?.showPowerButtons ?? true
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnLayer0
    readonly property color colSubtext: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.colors.colSubtext

    component HeaderButton: RippleButton {
        id: headerButton
        property alias iconName: headerSymbol.text
        property string tooltip: ""
        implicitWidth: 38
        implicitHeight: 38
        buttonRadius: toggled ? Appearance.rounding.normal : Appearance.rounding.full
        colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
            : root.inirEverywhere ? Appearance.inir.colLayer1
            : root.auroraEverywhere ? Appearance.aurora.colSubSurface
            : Appearance.colors.colLayer1
        colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
            : root.inirEverywhere ? Appearance.inir.colLayer1Hover
            : root.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
            : Appearance.colors.colLayer1Hover
        colBackgroundToggled: Appearance.colors.colSecondaryContainer
        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
        Behavior on buttonRadius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        contentItem: MaterialSymbol {
            id: headerSymbol
            anchors.centerIn: parent
            iconSize: 20
            horizontalAlignment: Text.AlignHCenter
            color: headerButton.toggled ? Appearance.colors.colOnSecondaryContainer : root.colText
        }
        StyledToolTip { text: headerButton.tooltip }
    }

    // Uptime chip
    RowLayout {
        spacing: 8

        MaterialSymbol {
            text: "timelapse"
            iconSize: 20
            color: root.colSubtext
        }
        StyledText {
            text: Translation.tr("Uptime: %1").arg(DateTime.uptime)
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.colSubtext
        }
    }

    Item { Layout.fillWidth: true }

    HeaderButton {
        iconName: "notifications_paused"
        tooltip: Translation.tr("Do Not Disturb")
        toggled: Notifications.silent
        onClicked: Notifications.toggleSilent()
    }
    HeaderButton {
        iconName: "wallpaper"
        tooltip: Translation.tr("Wallpapers")
        onClicked: {
            GlobalStates.dashboardOpen = false
            GlobalStates.wallpaperSelectorOpen = true
        }
    }
    HeaderButton {
        iconName: "settings"
        tooltip: Translation.tr("Settings")
        onClicked: {
            GlobalStates.dashboardOpen = false
            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings"])
        }
    }
    HeaderButton {
        visible: root.showPowerButtons
        iconName: "lock"
        tooltip: Translation.tr("Lock")
        onClicked: {
            GlobalStates.dashboardOpen = false
            GlobalStates.screenLocked = true
        }
    }
    HeaderButton {
        visible: root.showPowerButtons
        iconName: "power_settings_new"
        tooltip: Translation.tr("Session")
        onClicked: {
            GlobalStates.dashboardOpen = false
            GlobalStates.sessionOpen = true
        }
    }
}
