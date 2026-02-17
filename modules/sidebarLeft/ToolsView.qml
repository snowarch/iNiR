pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import "root:"

Item {
    id: root

    // Local state for niri toggles
    property bool _debugTint: false
    property bool _showDamage: false
    property bool _opaqueRegions: false

    // Style tokens
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colTextSecondary: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colBg: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? "transparent"
        : Appearance.colors.colLayer1
    readonly property color colBgHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1Hover
    readonly property real radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.verysmall

    Flickable {
        id: flickable
        anchors.fill: parent
        anchors.margins: 8
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainColumn
            width: flickable.width
            spacing: 12

            // === Power Profiles ===
            CollapsibleSection {
                title: Translation.tr("Power Profile")
                icon: "bolt"
                expanded: true
                enableSettingsSearch: false

                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 4
                    spacing: 4

                    PowerProfileButton {
                        profile: PowerProfile.PowerSaver
                        profileIcon: "energy_savings_leaf"
                        label: Translation.tr("Saver")
                    }
                    PowerProfileButton {
                        profile: PowerProfile.Balanced
                        profileIcon: "balance"
                        label: Translation.tr("Balanced")
                    }
                    PowerProfileButton {
                        profile: PowerProfile.Performance
                        profileIcon: "local_fire_department"
                        label: Translation.tr("Performance")
                        enabled: PowerProfiles.hasPerformanceProfile
                    }
                }
            }

            // === Quick Toggles ===
            CollapsibleSection {
                title: Translation.tr("Quick Toggles")
                icon: "toggle_on"
                expanded: true
                enableSettingsSearch: false

                ConfigSwitch {
                    buttonIcon: "dark_mode"
                    text: Translation.tr("Dark mode")
                    checked: Appearance.m3colors?.darkmode ?? false
                    onCheckedChanged: {
                        const current = Config.options?.appearance?.customTheme?.darkmode ?? true
                        if (checked !== current) Config.setNestedValue("appearance.customTheme.darkmode", checked)
                    }
                }
                ConfigSwitch {
                    buttonIcon: "nightlight"
                    text: Translation.tr("Night light")
                    checked: Hyprsunset.active ?? false
                    onCheckedChanged: if (checked !== Hyprsunset.active) Hyprsunset.toggle()
                }
                ConfigSwitch {
                    buttonIcon: "coffee"
                    text: Translation.tr("Idle inhibitor")
                    checked: Idle.inhibit ?? false
                    onCheckedChanged: if (checked !== Idle.inhibit) Idle.toggleInhibit()
                }
                ConfigSwitch {
                    buttonIcon: "do_not_disturb_on"
                    text: Translation.tr("Do not disturb")
                    checked: Notifications.silent ?? false
                    onCheckedChanged: if (checked !== Notifications.silent) Notifications.toggleSilent()
                }
                ConfigSwitch {
                    buttonIcon: "sports_esports"
                    text: Translation.tr("Game mode")
                    checked: GameMode.active
                    onCheckedChanged: if (checked !== GameMode.active) GameMode.toggle()
                }
            }

            // === Capture ===
            CollapsibleSection {
                title: Translation.tr("Capture")
                icon: "screenshot"
                expanded: true
                enableSettingsSearch: false

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 4
                    columnSpacing: 4

                    ActionTile {
                        tileIcon: "screenshot"
                        label: Translation.tr("Screenshot")
                        onClicked: Quickshell.execDetached(["niri", "msg", "action", "screenshot"])
                    }
                    ActionTile {
                        tileIcon: "screenshot_region"
                        label: Translation.tr("Region")
                        onClicked: Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "region", "screenshot"])
                    }
                    ActionTile {
                        tileIcon: "videocam"
                        label: Translation.tr("Record")
                        onClicked: Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "region", "record"])
                    }
                    ActionTile {
                        tileIcon: "text_fields"
                        label: Translation.tr("OCR")
                        onClicked: Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "region", "ocr"])
                    }
                    ActionTile {
                        tileIcon: "colorize"
                        label: Translation.tr("Color")
                        onClicked: Quickshell.execDetached(["niri", "msg", "action", "pick-color"])
                    }
                    ActionTile {
                        tileIcon: "screenshot_monitor"
                        label: Translation.tr("Window")
                        onClicked: Quickshell.execDetached(["niri", "msg", "action", "screenshot-window"])
                    }
                }
            }

            // === Quick Launch ===
            CollapsibleSection {
                title: Translation.tr("Quick Launch")
                icon: "rocket_launch"
                expanded: false
                enableSettingsSearch: false

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    rowSpacing: 4
                    columnSpacing: 4

                    ActionTile {
                        tileIcon: "terminal"
                        label: Translation.tr("Terminal")
                        onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/launch-terminal.sh")])
                    }
                    ActionTile {
                        tileIcon: "folder"
                        label: Translation.tr("Files")
                        onClicked: Quickshell.execDetached(["/usr/bin/nautilus"])
                    }
                    ActionTile {
                        tileIcon: "settings"
                        label: Translation.tr("Settings")
                        onClicked: Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "settings", "open"])
                    }
                    ActionTile {
                        tileIcon: "tune"
                        label: Translation.tr("Audio")
                        onClicked: Quickshell.execDetached([Config.options?.apps?.volumeMixer ?? "/usr/bin/pavucontrol"])
                    }
                    ActionTile {
                        tileIcon: "language"
                        label: Translation.tr("Browser")
                        onClicked: Quickshell.execDetached([Config.options?.apps?.browser ?? "/usr/bin/firefox"])
                    }
                    ActionTile {
                        tileIcon: "code"
                        label: Translation.tr("Editor")
                        onClicked: Quickshell.execDetached([Config.options?.apps?.editor ?? "/usr/bin/code"])
                    }
                }
            }

            // === Clipboard ===
            CollapsibleSection {
                title: Translation.tr("Clipboard")
                icon: "content_paste"
                expanded: false
                enableSettingsSearch: false

                ActionButton {
                    btnIcon: "assignment"
                    label: Translation.tr("Open clipboard manager")
                    onClicked: GlobalStates.clipboardOpen = true
                }
                ActionButton {
                    btnIcon: "delete_sweep"
                    label: Translation.tr("Clear clipboard history")
                    onClicked: Cliphist.wipe()
                }
            }

            // === Niri Debug ===
            CollapsibleSection {
                title: Translation.tr("Niri Debug")
                icon: "bug_report"
                expanded: false
                enableSettingsSearch: false

                ConfigSwitch {
                    buttonIcon: "palette"
                    text: Translation.tr("Debug tint")
                    checked: root._debugTint
                    onCheckedChanged: {
                        if (root._debugTint !== checked) {
                            root._debugTint = checked
                            Quickshell.execDetached(["niri", "msg", "action", "toggle-debug-tint"])
                        }
                    }
                }
                ConfigSwitch {
                    buttonIcon: "broken_image"
                    text: Translation.tr("Show damage")
                    checked: root._showDamage
                    onCheckedChanged: {
                        if (root._showDamage !== checked) {
                            root._showDamage = checked
                            Quickshell.execDetached(["niri", "msg", "action", "debug-toggle-damage"])
                        }
                    }
                }
                ConfigSwitch {
                    buttonIcon: "select_all"
                    text: Translation.tr("Opaque regions")
                    checked: root._opaqueRegions
                    onCheckedChanged: {
                        if (root._opaqueRegions !== checked) {
                            root._opaqueRegions = checked
                            Quickshell.execDetached(["niri", "msg", "action", "debug-toggle-opaque-regions"])
                        }
                    }
                }
                ActionButton {
                    btnIcon: "refresh"
                    label: Translation.tr("Reload Niri config")
                    onClicked: Quickshell.execDetached(["niri", "msg", "action", "load-config-file"])
                }
            }

            // === Shell ===
            CollapsibleSection {
                title: Translation.tr("Shell")
                icon: "deployed_code"
                expanded: false
                enableSettingsSearch: false

                ActionButton {
                    btnIcon: "restart_alt"
                    label: Translation.tr("Restart shell")
                    onClicked: Quickshell.execDetached(["/usr/bin/fish", "-c", "qs kill -c ii; qs -c ii -d"])
                }
                ActionButton {
                    btnIcon: "lock"
                    label: Translation.tr("Lock screen")
                    onClicked: Session.lock()
                }
                ActionButton {
                    btnIcon: "logout"
                    label: Translation.tr("Session menu")
                    onClicked: GlobalStates.sessionOpen = true
                }
            }

            // === System ===
            CollapsibleSection {
                title: Translation.tr("System")
                icon: "computer"
                expanded: false
                enableSettingsSearch: false

                ActionButton {
                    btnIcon: "system_update"
                    label: Translation.tr("Check for updates")
                    onClicked: Quickshell.execDetached([Config.options?.apps?.terminal ?? "/usr/bin/kitty", "-e", "fish", "-c", "yay -Syu; read -P 'Press Enter to close...'"])
                }
                ActionButton {
                    btnIcon: "cleaning_services"
                    label: Translation.tr("Clean package cache")
                    onClicked: Quickshell.execDetached([Config.options?.apps?.terminal ?? "/usr/bin/kitty", "-e", "fish", "-c", "sudo paccache -rk1; read -P 'Press Enter to close...'"])
                }
                ActionButton {
                    btnIcon: "info"
                    label: Translation.tr("System info")
                    onClicked: Quickshell.execDetached([Config.options?.apps?.terminal ?? "/usr/bin/kitty", "-e", "fish", "-c", "fastfetch; read -P 'Press Enter to close...'"])
                }
            }

            Item { Layout.preferredHeight: 8 }
        }
    }

    // ═══════════════════════════════════════════
    // INLINE COMPONENTS
    // ═══════════════════════════════════════════

    component PowerProfileButton: RippleButton {
        required property int profile
        required property string profileIcon
        required property string label

        Layout.fillWidth: true
        implicitHeight: 56
        buttonRadius: root.radius

        readonly property bool isActive: PowerProfiles.profile === profile

        colBackground: isActive ? Appearance.colors.colPrimary : root.colBg
        colBackgroundHover: isActive ? Appearance.colors.colPrimaryHover : root.colBgHover

        onClicked: PowerProfiles.profile = profile

        contentItem: ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: profileIcon
                iconSize: 20
                fill: isActive ? 1 : 0
                color: isActive ? Appearance.colors.colOnPrimary : root.colText
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: label
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: isActive ? Appearance.colors.colOnPrimary : root.colTextSecondary
            }
        }

        StyledToolTip {
            text: label + (isActive ? " (" + Translation.tr("Active") + ")" : "")
        }
    }

    component ActionTile: RippleButton {
        property string tileIcon: ""
        property string label: ""

        Layout.fillWidth: true
        implicitHeight: 56
        buttonRadius: root.radius

        colBackground: root.colBg
        colBackgroundHover: root.colBgHover

        contentItem: ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: tileIcon
                iconSize: 20
                color: root.colText
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: label
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: root.colTextSecondary
                elide: Text.ElideRight
            }
        }
    }

    component ActionButton: RippleButton {
        property string btnIcon: ""
        property string label: ""

        Layout.fillWidth: true
        implicitHeight: 40
        buttonRadius: root.radius

        colBackground: "transparent"
        colBackgroundHover: root.colBgHover

        contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            MaterialSymbol {
                text: btnIcon
                iconSize: Appearance.font.pixelSize.normal
                color: root.colText
            }
            StyledText {
                text: label
                Layout.fillWidth: true
                color: root.colText
            }
            MaterialSymbol {
                text: "chevron_right"
                iconSize: Appearance.font.pixelSize.small
                color: root.colTextSecondary
            }
        }
    }
}
