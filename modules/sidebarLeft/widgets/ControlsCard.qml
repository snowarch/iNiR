pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Item {
    id: root
    implicitHeight: row.implicitHeight

    function toggleDark(): void {
        const current = Config.options?.appearance?.customTheme?.darkmode ?? true
        Config.setNestedValue("appearance.customTheme.darkmode", !current)
    }

    function openSettings(): void {
        Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "settings", "open"])
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 0

        Item { Layout.fillWidth: true }

        // Toggles
        Toggle { 
            btnIcon: "dark_mode"
            tip: Translation.tr("Dark mode")
            active: Appearance.m3colors?.darkmode ?? false
            onClicked: root.toggleDark()
            visible: Config.options?.sidebar?.widgets?.controlsCard?.showDarkMode ?? true
        }
        Toggle { 
            btnIcon: "do_not_disturb_on"
            tip: Translation.tr("Do not disturb")
            active: Notifications.silent ?? false
            onClicked: Notifications.toggleSilent()
            visible: Config.options?.sidebar?.widgets?.controlsCard?.showDnd ?? true
        }
        Toggle { 
            btnIcon: "nightlight"
            tip: Translation.tr("Night light")
            active: Hyprsunset.active ?? false
            onClicked: Hyprsunset.toggle()
            visible: Config.options?.sidebar?.widgets?.controlsCard?.showNightLight ?? true
        }
        Toggle { 
            btnIcon: "sports_esports"
            tip: GameMode.active ? Translation.tr("Game mode (active)") : Translation.tr("Game mode")
            active: GameMode.active ?? false
            onClicked: GameMode.toggle()
            visible: Config.options?.sidebar?.widgets?.controlsCard?.showGameMode ?? true
        }

        Rectangle { 
            width: 1
            height: 24
            radius: 0.5
            color: Appearance.colors.colOutlineVariant
            opacity: 0.5
            Layout.leftMargin: 8
            Layout.rightMargin: 8
        }

        // Actions
        Action { btnIcon: "wifi"; tip: Translation.tr("Network"); onClicked: Quickshell.execDetached(["/usr/bin/nm-connection-editor"]); visible: Config.options?.sidebar?.widgets?.controlsCard?.showNetwork ?? true }
        Action { btnIcon: "bluetooth"; tip: Translation.tr("Bluetooth"); onClicked: Quickshell.execDetached(["/usr/bin/blueman-manager"]); visible: Config.options?.sidebar?.widgets?.controlsCard?.showBluetooth ?? true }
        Action { btnIcon: "settings"; tip: Translation.tr("Settings"); onClicked: root.openSettings(); visible: Config.options?.sidebar?.widgets?.controlsCard?.showSettings ?? true }
        Action { btnIcon: "lock"; tip: Translation.tr("Lock"); onClicked: Session.lock(); visible: Config.options?.sidebar?.widgets?.controlsCard?.showLock ?? true }

        Item { Layout.fillWidth: true }
    }

    component Toggle: RippleButton {
        property string btnIcon
        property string tip
        property bool active: false

        implicitWidth: 40
        implicitHeight: 40
        buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
        colBackground: Appearance.inirEverywhere 
            ? "transparent" 
            : (active ? Appearance.colors.colPrimaryContainer : "transparent")
        colBackgroundHover: Appearance.inirEverywhere 
            ? Appearance.inir.colLayer1Hover 
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
            : (active ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer1Hover)
        colRipple: Appearance.inirEverywhere 
            ? Appearance.inir.colLayer1Active 
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
            : (active ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer1Active)

        Behavior on colBackground {
            enabled: Appearance.animationsEnabled
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        contentItem: Item {
            MaterialSymbol {
                anchors.centerIn: parent
                text: btnIcon
                iconSize: 22
                fill: active ? 1 : 0
                color: Appearance.inirEverywhere 
                    ? (active ? Appearance.inir.colPrimary : Appearance.inir.colText) 
                    : (active ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer0)
                Behavior on fill { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                Behavior on color { enabled: Appearance.animationsEnabled; animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
            }
        }

        StyledToolTip { text: tip }
    }

    component Action: RippleButton {
        property string btnIcon
        property string tip

        implicitWidth: 40
        implicitHeight: 40
        buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
        colBackground: "transparent"
        colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover 
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer1Hover
        colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer1Active 
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer1Active

        contentItem: Item {
            MaterialSymbol {
                anchors.centerIn: parent
                text: btnIcon
                iconSize: 20
                color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
            }
        }

        StyledToolTip { text: tip }
    }
}
