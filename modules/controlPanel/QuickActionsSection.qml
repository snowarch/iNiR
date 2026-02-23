pragma ComponentBehavior: Bound
import qs
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Rectangle {
    id: root
    Layout.fillWidth: true
    implicitHeight: actionsGrid.implicitHeight + 16
    
    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere

    radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
         : inirEverywhere ? Appearance.inir.colLayer1
         : auroraEverywhere ? Appearance.aurora.colSubSurface
         : Appearance.colors.colLayer1
    border.width: Appearance.angelEverywhere ? 0 : (inirEverywhere ? 1 : 0)
    border.color: Appearance.angelEverywhere ? "transparent"
        : inirEverywhere ? Appearance.inir.colBorder : "transparent"

    AngelPartialBorder { targetRadius: parent.radius; coverage: 0.45 }

    GridLayout {
        id: actionsGrid
        anchors.fill: parent
        anchors.margins: 8
        columns: 4
        rowSpacing: 6
        columnSpacing: 6

        // Row 1: Audio
        ActionTile {
            icon: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
            active: !(Audio.sink?.audio?.muted ?? false)
            onClicked: Audio.sink?.audio?.toggleMute()
        }

        ActionTile {
            icon: Audio.source?.audio?.muted ? "mic_off" : "mic"
            active: !(Audio.source?.audio?.muted ?? false)
            onClicked: Audio.source?.audio?.toggleMute()
        }

        ActionTile {
            icon: "notifications"
            active: !Notifications.silent
            onClicked: Notifications.silent = !Notifications.silent
        }

        ActionTile {
            icon: "dark_mode"
            active: Appearance.m3colors.darkmode
            onClicked: Appearance.toggleDarkMode()
        }

        // Row 2: Connectivity & System
        ActionTile {
            icon: Network.wifiEnabled ? "wifi" : "wifi_off"
            active: Network.wifiEnabled
            onClicked: Network.toggleWifi()
        }

        ActionTile {
            visible: BluetoothStatus.available
            icon: BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
            active: BluetoothStatus.enabled
            onClicked: BluetoothStatus.toggle()
        }

        ActionTile {
            icon: "coffee"
            active: Idle.inhibit
            onClicked: Idle.toggleInhibit()
        }

        ActionTile {
            icon: "sports_esports"
            active: GameMode.active
            onClicked: GameMode.toggle()
        }

        // Row 3: Tools
        ActionTile {
            icon: "screenshot_monitor"
            onClicked: {
                GlobalStates.controlPanelOpen = false
                GlobalStates.regionSelectorOpen = true
            }
        }

        ActionTile {
            icon: "settings"
            onClicked: {
                GlobalStates.controlPanelOpen = false
                Quickshell.execDetached(["/usr/bin/qs", "-c", "inir", "ipc", "call", "settings", "open"])
            }
        }

        ActionTile {
            icon: "lock"
            onClicked: {
                GlobalStates.controlPanelOpen = false
                Quickshell.execDetached(["/usr/bin/qs", "-c", "inir", "ipc", "call", "lock", "activate"])
            }
        }

        ActionTile {
            icon: "power_settings_new"
            iconColor: Appearance.angelEverywhere ? Appearance.m3colors.m3error
                     : root.inirEverywhere ? Appearance.inir.colError
                     : root.auroraEverywhere ? Appearance.m3colors.m3error
                     : Appearance.colors.colError
            onClicked: {
                GlobalStates.controlPanelOpen = false
                GlobalStates.sessionOpen = true
            }
        }
    }

    component ActionTile: Rectangle {
        id: tile
        property string icon
        property bool active: false
        property color iconColor: active 
            ? (Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
             : root.inirEverywhere ? Appearance.inir.colOnPrimary 
             : root.auroraEverywhere ? Appearance.m3colors.m3onPrimary
             : Appearance.colors.colOnPrimary)
            : (Appearance.angelEverywhere ? Appearance.angel.colText
             : root.inirEverywhere ? Appearance.inir.colText 
             : root.auroraEverywhere ? Appearance.m3colors.m3onSurface
             : Appearance.colors.colOnLayer1)
        signal clicked()

        Layout.fillWidth: true
        implicitHeight: 36
        radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
            : root.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
        
        color: tileMouseArea.containsMouse 
            ? (active 
                ? (Appearance.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colPrimaryHover, 0.35)
                 : root.inirEverywhere ? Appearance.inir.colPrimaryHover 
                 : root.auroraEverywhere ? Appearance.colors.colPrimaryHover
                 : Appearance.colors.colPrimaryHover)
                : (Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                 : root.inirEverywhere ? Appearance.inir.colLayer2Hover 
                 : root.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
                 : Appearance.colors.colLayer2Hover))
            : (active 
                ? (Appearance.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colPrimary, 0.45)
                 : root.inirEverywhere ? Appearance.inir.colPrimary 
                 : root.auroraEverywhere ? Appearance.m3colors.m3primary
                 : Appearance.colors.colPrimary)
                : (Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                 : root.inirEverywhere ? Appearance.inir.colLayer2 
                 : root.auroraEverywhere ? Appearance.aurora.colSubSurface
                 : Appearance.colors.colLayer2))

        border.width: Appearance.angelEverywhere ? 0 : (root.inirEverywhere ? 1 : 0)
        border.color: Appearance.angelEverywhere ? "transparent"
            : root.inirEverywhere ? (active ? Appearance.inir.colPrimary : Appearance.inir.colBorderSubtle) : "transparent"

        AngelPartialBorder { targetRadius: parent.radius; coverage: 0.4; borderColor: active ? Appearance.angel.colPrimary : Appearance.angel.colBorderSubtle }

        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: tile.icon
            iconSize: 18
            color: tile.iconColor

            Behavior on color {
                enabled: Appearance.animationsEnabled
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }

        MouseArea {
            id: tileMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
    }
}
