import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: modulesPage
    settingsPageIndex: 10
    settingsPageName: Translation.tr("Modules")

    readonly property bool isWaffle: Config.options?.panelFamily === "waffle"

    readonly property var defaultPanels: ({
        "ii": [
            "iiBar", "iiBackground", "iiBackdrop", "iiCheatsheet", "iiControlPanel", "iiDock", "iiLock", 
            "iiMediaControls", "iiNotificationPopup", "iiOnScreenDisplay", "iiOnScreenKeyboard", 
            "iiOverlay", "iiOverview", "iiPolkit", "iiRegionSelector", "iiScreenCorners", 
            "iiSessionScreen", "iiSidebarLeft", "iiSidebarRight", "iiTilingOverlay", "iiVerticalBar", 
            "iiWallpaperSelector", "iiWallpaperLauncher", "iiCoverflowSelector", "iiClipboard", "iiShellUpdate"
        ],
        "waffle": [
            "wBar", "wBackground", "wBackdrop", "wStartMenu", "wActionCenter", "wNotificationCenter", "wNotificationPopup", "wOnScreenDisplay", "wWidgets", "wTaskView", "wLock", "wPolkit", "wSessionScreen",
            "iiCheatsheet", "iiOnScreenKeyboard", "iiOverlay", "iiOverview",
            "iiRegionSelector", "iiScreenCorners", "iiWallpaperSelector", "iiWallpaperLauncher", "iiCoverflowSelector", "iiClipboard"
        ]
    })

    function isPanelEnabled(panelId: string): bool {
        return (Config.options?.enabledPanels ?? []).includes(panelId)
    }

    function setPanelEnabled(panelId: string, enabled: bool) {
        let panels = [...(Config.options?.enabledPanels ?? [])]
        const idx = panels.indexOf(panelId)
        
        if (enabled && idx === -1) {
            panels.push(panelId)
        } else if (!enabled && idx !== -1) {
            panels.splice(idx, 1)
        }
        
        Config.setNestedValue("enabledPanels", panels)
    }

    function isIiBarEnabled(): bool {
        const panels = Config.options?.enabledPanels ?? []
        return panels.includes("iiBar") || panels.includes("iiVerticalBar")
    }

    function setIiBarEnabled(enabled: bool) {
        let panels = [...(Config.options?.enabledPanels ?? [])]

        const hasBar = panels.includes("iiBar")
        const hasVerticalBar = panels.includes("iiVerticalBar")

        if (enabled) {
            if (!hasBar) panels.push("iiBar")
            if (!hasVerticalBar) panels.push("iiVerticalBar")
        } else {
            panels = panels.filter(panel => panel !== "iiBar" && panel !== "iiVerticalBar")
        }

        Config.setNestedValue("enabledPanels", panels)
    }

    function resetToDefaults() {
        const family = Config.options?.panelFamily ?? "ii"
        Config.setNestedValue("enabledPanels", [...(defaultPanels[family] ?? [])])
    }

    SettingsCardSection {
        expanded: true
        icon: "extension"
        title: Translation.tr("Shell Modules")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Enable or disable shell modules. Changes apply live.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer1
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple: Appearance.colors.colLayer1Active

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        MaterialSymbol {
                            text: "restart_alt"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnSurface
                        }
                        StyledText {
                            text: Translation.tr("Reset to defaults")
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }

                    onClicked: modulesPage.resetToDefaults()
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "style"
        title: Translation.tr("Panel Style")

        SettingsGroup {
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.small
                    colBackground: !modulesPage.isWaffle
                        ? (Appearance.zzzEverywhere ? Appearance.zzz.sticker : Appearance.colors.colPrimaryContainer)
                        : Appearance.colors.colLayer1
                    colBackgroundHover: !modulesPage.isWaffle
                        ? (Appearance.zzzEverywhere ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimaryContainerHover)
                        : Appearance.colors.colLayer1Hover
                    colRipple: !modulesPage.isWaffle
                        ? (Appearance.zzzEverywhere ? Appearance.colors.colPrimaryActive : Appearance.colors.colPrimaryContainerActive)
                        : Appearance.colors.colLayer1Active

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "dashboard"
                            iconSize: Appearance.font.pixelSize.larger
                            color: !modulesPage.isWaffle
                                ? (Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimaryContainer)
                                : Appearance.colors.colOnSurface
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Material (ii)"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: !modulesPage.isWaffle
                                ? (Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimaryContainer)
                                : Appearance.colors.colOnSurface
                        }
                    }

                    onClicked: {
                        Config.setNestedValue("panelFamily", "ii")
                        Config.setNestedValue("enabledPanels", [...modulesPage.defaultPanels["ii"]])
                    }
                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.small
                    colBackground: modulesPage.isWaffle ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1
                    colBackgroundHover: modulesPage.isWaffle ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer1Hover
                    colRipple: modulesPage.isWaffle ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer1Active

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "window"
                            iconSize: Appearance.font.pixelSize.larger
                            color: modulesPage.isWaffle ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Windows 11 (Waffle)"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: modulesPage.isWaffle ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface
                        }
                    }

                    onClicked: {
                        Config.setNestedValue("panelFamily", "waffle")
                        Config.setNestedValue("enabledPanels", [...modulesPage.defaultPanels["waffle"]])
                    }
                }
            }
        }
    }

    // ==================== DEFAULT TERMINAL ====================
    SettingsCardSection {
        id: terminalSection
        expanded: false
        icon: "terminal"
        title: Translation.tr("Default Terminal")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Terminal used by shell actions, tools, keybinds, and package commands.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }

            readonly property var terminalOptions: [
                { name: "Foot", value: "foot" },
                { name: "Kitty", value: "kitty" },
                { name: "Ghostty", value: "ghostty" },
                { name: "Alacritty", value: "alacritty" },
                { name: "WezTerm", value: "wezterm" },
                { name: "Konsole", value: "konsole" },
            ]

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Foot
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.small
                    readonly property bool isSelected: (Config.options?.apps?.terminal ?? "kitty") === "foot"
                    colBackground: isSelected ? (Appearance.zzzEverywhere ? Appearance.zzz.sticker : Appearance.colors.colPrimaryContainer) : Appearance.colors.colLayer1
                    colBackgroundHover: isSelected ? (Appearance.zzzEverywhere ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimaryContainerHover) : Appearance.colors.colLayer1Hover
                    colRipple: isSelected ? (Appearance.zzzEverywhere ? Appearance.colors.colPrimaryActive : Appearance.colors.colPrimaryContainerActive) : Appearance.colors.colLayer1Active
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "terminal"
                            iconSize: Appearance.font.pixelSize.larger
                            color: parent.parent.isSelected ? (Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimaryContainer) : Appearance.colors.colOnSurface
                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Foot"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: parent.parent.isSelected ? (Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimaryContainer) : Appearance.colors.colOnSurface
                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                        }
                    }
                    onClicked: {
                        AppLauncher.applyPreset("terminal", "foot")
                    }
                }

                // Kitty
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.small
                    readonly property bool isSelected: (Config.options?.apps?.terminal ?? "kitty") === "kitty"
                    colBackground: isSelected ? (Appearance.zzzEverywhere ? Appearance.zzz.sticker : Appearance.colors.colPrimaryContainer) : Appearance.colors.colLayer1
                    colBackgroundHover: isSelected ? (Appearance.zzzEverywhere ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimaryContainerHover) : Appearance.colors.colLayer1Hover
                    colRipple: isSelected ? (Appearance.zzzEverywhere ? Appearance.colors.colPrimaryActive : Appearance.colors.colPrimaryContainerActive) : Appearance.colors.colLayer1Active
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "terminal"
                            iconSize: Appearance.font.pixelSize.larger
                            color: parent.parent.isSelected ? (Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimaryContainer) : Appearance.colors.colOnSurface
                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Kitty"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: parent.parent.isSelected ? (Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimaryContainer) : Appearance.colors.colOnSurface
                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                        }
                    }
                    onClicked: {
                        AppLauncher.applyPreset("terminal", "kitty")
                    }
                }

                // Ghostty
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.small
                    readonly property bool isSelected: (Config.options?.apps?.terminal ?? "kitty") === "ghostty"
                    colBackground: isSelected ? (Appearance.zzzEverywhere ? Appearance.zzz.sticker : Appearance.colors.colPrimaryContainer) : Appearance.colors.colLayer1
                    colBackgroundHover: isSelected ? (Appearance.zzzEverywhere ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimaryContainerHover) : Appearance.colors.colLayer1Hover
                    colRipple: isSelected ? (Appearance.zzzEverywhere ? Appearance.colors.colPrimaryActive : Appearance.colors.colPrimaryContainerActive) : Appearance.colors.colLayer1Active
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "terminal"
                            iconSize: Appearance.font.pixelSize.larger
                            color: parent.parent.isSelected ? (Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimaryContainer) : Appearance.colors.colOnSurface
                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Ghostty"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: parent.parent.isSelected ? (Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimaryContainer) : Appearance.colors.colOnSurface
                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                        }
                    }
                    onClicked: {
                        AppLauncher.applyPreset("terminal", "ghostty")
                    }
                }

                // Alacritty
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.small
                    readonly property bool isSelected: (Config.options?.apps?.terminal ?? "kitty") === "alacritty"
                    colBackground: isSelected ? (Appearance.zzzEverywhere ? Appearance.zzz.sticker : Appearance.colors.colPrimaryContainer) : Appearance.colors.colLayer1
                    colBackgroundHover: isSelected ? (Appearance.zzzEverywhere ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimaryContainerHover) : Appearance.colors.colLayer1Hover
                    colRipple: isSelected ? (Appearance.zzzEverywhere ? Appearance.colors.colPrimaryActive : Appearance.colors.colPrimaryContainerActive) : Appearance.colors.colLayer1Active
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "terminal"
                            iconSize: Appearance.font.pixelSize.larger
                            color: parent.parent.isSelected ? (Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimaryContainer) : Appearance.colors.colOnSurface
                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Alacritty"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: parent.parent.isSelected ? (Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimaryContainer) : Appearance.colors.colOnSurface
                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                        }
                    }
                    onClicked: {
                        AppLauncher.applyPreset("terminal", "alacritty")
                    }
                }

                // WezTerm
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.small
                    readonly property bool isSelected: (Config.options?.apps?.terminal ?? "kitty") === "wezterm"
                    colBackground: isSelected ? (Appearance.zzzEverywhere ? Appearance.zzz.sticker : Appearance.colors.colPrimaryContainer) : Appearance.colors.colLayer1
                    colBackgroundHover: isSelected ? (Appearance.zzzEverywhere ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimaryContainerHover) : Appearance.colors.colLayer1Hover
                    colRipple: isSelected ? (Appearance.zzzEverywhere ? Appearance.colors.colPrimaryActive : Appearance.colors.colPrimaryContainerActive) : Appearance.colors.colLayer1Active
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "terminal"
                            iconSize: Appearance.font.pixelSize.larger
                            color: parent.parent.isSelected ? (Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimaryContainer) : Appearance.colors.colOnSurface
                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "WezTerm"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: parent.parent.isSelected ? (Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimaryContainer) : Appearance.colors.colOnSurface
                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                        }
                    }
                    onClicked: {
                        AppLauncher.applyPreset("terminal", "wezterm")
                    }
                }

                // Konsole
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.small
                    readonly property bool isSelected: (Config.options?.apps?.terminal ?? "kitty") === "konsole"
                    colBackground: isSelected ? (Appearance.zzzEverywhere ? Appearance.zzz.sticker : Appearance.colors.colPrimaryContainer) : Appearance.colors.colLayer1
                    colBackgroundHover: isSelected ? (Appearance.zzzEverywhere ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimaryContainerHover) : Appearance.colors.colLayer1Hover
                    colRipple: isSelected ? (Appearance.zzzEverywhere ? Appearance.colors.colPrimaryActive : Appearance.colors.colPrimaryContainerActive) : Appearance.colors.colLayer1Active
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "terminal"
                            iconSize: Appearance.font.pixelSize.larger
                            color: parent.parent.isSelected ? (Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimaryContainer) : Appearance.colors.colOnSurface
                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Konsole"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: parent.parent.isSelected ? (Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimaryContainer) : Appearance.colors.colOnSurface
                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                        }
                    }
                    onClicked: {
                        AppLauncher.applyPreset("terminal", "konsole")
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 4
                text: Translation.tr("Mod+T and Mod+Return use this terminal. Run './setup update' to apply keybind migration.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.italic: true
                wrapMode: Text.WordWrap
            }
        }
    }

    // ==================== MATERIAL II ====================
    SettingsCardSection {
        visible: !modulesPage.isWaffle
        expanded: false
        icon: "dashboard"
        title: Translation.tr("Core")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "toolbar"
                text: Translation.tr("Bar")
                checked: modulesPage.isIiBarEnabled()
                onCheckedChanged: modulesPage.setIiBarEnabled(checked)
                StyledToolTip { text: Translation.tr("Main bar module. Orientation (horizontal/vertical) is configured in Bar settings.") }
            }

            SettingsSwitch {
                buttonIcon: "wallpaper"
                text: Translation.tr("Background")
                checked: modulesPage.isPanelEnabled("iiBackground")
                onCheckedChanged: modulesPage.setPanelEnabled("iiBackground", checked)
                StyledToolTip { text: Translation.tr("Desktop wallpaper with parallax effect and widgets") }
            }

            SettingsSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Niri Overview Backdrop")
                checked: modulesPage.isPanelEnabled("iiBackdrop")
                onCheckedChanged: modulesPage.setPanelEnabled("iiBackdrop", checked)
                StyledToolTip { text: Translation.tr("Blurred wallpaper shown in Niri's native overview (Mod+Tab)") }
            }

            SettingsSwitch {
                buttonIcon: "search"
                text: Translation.tr("Overview")
                checked: modulesPage.isPanelEnabled("iiOverview")
                onCheckedChanged: modulesPage.setPanelEnabled("iiOverview", checked)
                StyledToolTip { text: Translation.tr("App launcher, search and workspace grid (Super+Space)") }
            }

            SettingsSwitch {
                buttonIcon: "view_sidebar"
                text: Translation.tr("Workspace Strip")
                checked: modulesPage.isPanelEnabled("iiWorkspaceStrip")
                onCheckedChanged: modulesPage.setPanelEnabled("iiWorkspaceStrip", checked)
                StyledToolTip { text: Translation.tr("Hover a screen edge for visual workspace navigation") }
            }

            SettingsSwitch {
                buttonIcon: "widgets"
                text: Translation.tr("Floating tools (Super+G)")
                checked: modulesPage.isPanelEnabled("iiOverlay")
                onCheckedChanged: modulesPage.setPanelEnabled("iiOverlay", checked)
                StyledToolTip { text: Translation.tr("Floating image and widgets panel (Super+G)") }
            }

            SettingsSwitch {
                buttonIcon: "left_panel_open"
                text: Translation.tr("Left Sidebar")
                checked: modulesPage.isPanelEnabled("iiSidebarLeft")
                onCheckedChanged: modulesPage.setPanelEnabled("iiSidebarLeft", checked)
                StyledToolTip { text: Translation.tr("AI assistant, translator, image browser") }
            }

            SettingsSwitch {
                buttonIcon: "right_panel_open"
                text: Translation.tr("Right Sidebar")
                checked: modulesPage.isPanelEnabled("iiSidebarRight")
                onCheckedChanged: modulesPage.setPanelEnabled("iiSidebarRight", checked)
                StyledToolTip { text: Translation.tr("Quick settings, notifications, calendar, system info") }
            }
        }
    }

    SettingsCardSection {
        visible: !modulesPage.isWaffle
        expanded: false
        icon: "notifications"
        title: Translation.tr("Feedback")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "notifications"
                text: Translation.tr("Notification Popups")
                checked: modulesPage.isPanelEnabled("iiNotificationPopup")
                onCheckedChanged: modulesPage.setPanelEnabled("iiNotificationPopup", checked)
                StyledToolTip { text: Translation.tr("Toast notifications that appear on screen") }
            }

            SettingsSwitch {
                buttonIcon: "volume_up"
                text: Translation.tr("OSD")
                checked: modulesPage.isPanelEnabled("iiOnScreenDisplay")
                onCheckedChanged: modulesPage.setPanelEnabled("iiOnScreenDisplay", checked)
                StyledToolTip { text: Translation.tr("On-screen display for volume and brightness changes") }
            }

            SettingsSwitch {
                buttonIcon: "music_note"
                text: Translation.tr("Media Controls")
                checked: modulesPage.isPanelEnabled("iiMediaControls")
                onCheckedChanged: modulesPage.setPanelEnabled("iiMediaControls", checked)
                StyledToolTip { text: Translation.tr("Floating media player controls") }
            }
        }
    }

    SettingsCardSection {
        visible: !modulesPage.isWaffle
        expanded: false
        icon: "build"
        title: Translation.tr("Utilities")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "lock"
                text: Translation.tr("Lock Screen")
                checked: modulesPage.isPanelEnabled("iiLock")
                onCheckedChanged: modulesPage.setPanelEnabled("iiLock", checked)
                StyledToolTip { text: Translation.tr("Custom lock screen with clock and password input") }
            }

            SettingsSwitch {
                buttonIcon: "power_settings_new"
                text: Translation.tr("Session Screen")
                checked: modulesPage.isPanelEnabled("iiSessionScreen")
                onCheckedChanged: modulesPage.setPanelEnabled("iiSessionScreen", checked)
                StyledToolTip { text: Translation.tr("Power menu: lock, logout, suspend, reboot, shutdown") }
            }

            SettingsSwitch {
                buttonIcon: "admin_panel_settings"
                text: Translation.tr("Polkit Agent")
                checked: modulesPage.isPanelEnabled("iiPolkit")
                onCheckedChanged: modulesPage.setPanelEnabled("iiPolkit", checked)
                StyledToolTip { text: Translation.tr("Password prompt for administrative actions") }
            }

            SettingsSwitch {
                buttonIcon: "screenshot_region"
                text: Translation.tr("Region Selector")
                checked: modulesPage.isPanelEnabled("iiRegionSelector")
                onCheckedChanged: modulesPage.setPanelEnabled("iiRegionSelector", checked)
                StyledToolTip { text: Translation.tr("Screen capture, OCR text extraction, color picker") }
            }

            SettingsSwitch {
                buttonIcon: "image"
                text: Translation.tr("Wallpaper Selector")
                checked: modulesPage.isPanelEnabled("iiWallpaperSelector")
                onCheckedChanged: modulesPage.setPanelEnabled("iiWallpaperSelector", checked)
                StyledToolTip { text: Translation.tr("File picker for changing wallpaper") }
            }

            SettingsSwitch {
                buttonIcon: "keyboard"
                text: Translation.tr("Cheatsheet")
                checked: modulesPage.isPanelEnabled("iiCheatsheet")
                onCheckedChanged: modulesPage.setPanelEnabled("iiCheatsheet", checked)
                StyledToolTip { text: Translation.tr("Keyboard shortcuts reference overlay") }
            }

            SettingsSwitch {
                buttonIcon: "keyboard_alt"
                text: Translation.tr("On-Screen Keyboard")
                checked: modulesPage.isPanelEnabled("iiOnScreenKeyboard")
                onCheckedChanged: modulesPage.setPanelEnabled("iiOnScreenKeyboard", checked)
                StyledToolTip { text: Translation.tr("Virtual keyboard for touch input") }
            }

            SettingsSwitch {
                buttonIcon: "tab"
                text: Translation.tr("Alt-Tab Switcher")
                checked: false
                enabled: false
                StyledToolTip { text: Translation.tr("Window switcher popup") }
            }

            SettingsSwitch {
                buttonIcon: "content_paste"
                text: Translation.tr("Clipboard History")
                checked: modulesPage.isPanelEnabled("iiClipboard")
                onCheckedChanged: modulesPage.setPanelEnabled("iiClipboard", checked)
                StyledToolTip { text: Translation.tr("Clipboard manager with history") }
            }
        }
    }

    SettingsCardSection {
        visible: !modulesPage.isWaffle
        expanded: false
        icon: "more_horiz"
        title: Translation.tr("Optional")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "dock_to_bottom"
                text: Translation.tr("Dock")
                checked: modulesPage.isPanelEnabled("iiDock")
                onCheckedChanged: modulesPage.setPanelEnabled("iiDock", checked)
                StyledToolTip { text: Translation.tr("macOS-style dock with pinned and running apps") }
            }

            SettingsSwitch {
                buttonIcon: "rounded_corner"
                text: Translation.tr("Screen Corners")
                checked: modulesPage.isPanelEnabled("iiScreenCorners")
                onCheckedChanged: modulesPage.setPanelEnabled("iiScreenCorners", checked)
                StyledToolTip { text: Translation.tr("Rounded corner overlays for screens without hardware rounding") }
            }

            SettingsSwitch {
                buttonIcon: "center_focus_strong"
                text: Translation.tr("Crosshair")
                checked: false
                enabled: false
                StyledToolTip { text: Translation.tr("Gaming crosshair overlay for games without built-in crosshair") }
            }
        }
    }

    // ==================== WAFFLE ====================
    SettingsCardSection {
        visible: modulesPage.isWaffle
        expanded: false
        icon: "window"
        title: Translation.tr("Waffle Core")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "toolbar"
                text: Translation.tr("Taskbar")
                checked: modulesPage.isPanelEnabled("wBar")
                onCheckedChanged: modulesPage.setPanelEnabled("wBar", checked)
                StyledToolTip { text: Translation.tr("Windows 11 style taskbar with app icons and system tray") }
            }

            SettingsSwitch {
                buttonIcon: "wallpaper"
                text: Translation.tr("Background")
                checked: modulesPage.isPanelEnabled("wBackground")
                onCheckedChanged: modulesPage.setPanelEnabled("wBackground", checked)
                StyledToolTip { text: Translation.tr("Desktop wallpaper") }
            }

            SettingsSwitch {
                buttonIcon: "grid_view"
                text: Translation.tr("Start Menu")
                checked: modulesPage.isPanelEnabled("wStartMenu")
                onCheckedChanged: modulesPage.setPanelEnabled("wStartMenu", checked)
                StyledToolTip { text: Translation.tr("Windows 11 style start menu with search and pinned apps (Super+Space)") }
            }

            SettingsSwitch {
                buttonIcon: "toggle_on"
                text: Translation.tr("Action Center")
                checked: modulesPage.isPanelEnabled("wActionCenter")
                onCheckedChanged: modulesPage.setPanelEnabled("wActionCenter", checked)
                StyledToolTip { text: Translation.tr("Quick settings panel with toggles and sliders") }
            }

            SettingsSwitch {
                buttonIcon: "notifications"
                text: Translation.tr("Notification Center")
                checked: modulesPage.isPanelEnabled("wNotificationCenter")
                onCheckedChanged: modulesPage.setPanelEnabled("wNotificationCenter", checked)
                StyledToolTip { text: Translation.tr("Notification panel with calendar") }
            }

            SettingsSwitch {
                buttonIcon: "notifications_active"
                text: Translation.tr("Notification Popups")
                checked: modulesPage.isPanelEnabled("wNotificationPopup")
                onCheckedChanged: modulesPage.setPanelEnabled("wNotificationPopup", checked)
                StyledToolTip { text: Translation.tr("Toast notifications that appear on screen (Windows 11 style)") }
            }

            SettingsSwitch {
                buttonIcon: "volume_up"
                text: Translation.tr("OSD")
                checked: modulesPage.isPanelEnabled("wOnScreenDisplay")
                onCheckedChanged: modulesPage.setPanelEnabled("wOnScreenDisplay", checked)
                StyledToolTip { text: Translation.tr("On-screen display for volume and brightness") }
            }

            SettingsSwitch {
                buttonIcon: "widgets"
                text: Translation.tr("Widgets Panel")
                checked: modulesPage.isPanelEnabled("wWidgets")
                onCheckedChanged: modulesPage.setPanelEnabled("wWidgets", checked)
                StyledToolTip { text: Translation.tr("Windows 11 style widgets sidebar") }
            }
        }
    }

    SettingsCardSection {
        visible: modulesPage.isWaffle
        expanded: false
        icon: "share"
        title: Translation.tr("Shared Modules")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Supporting modules used alongside Waffle")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }

            SettingsSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Niri Overview Backdrop")
                checked: modulesPage.isPanelEnabled("iiBackdrop")
                onCheckedChanged: modulesPage.setPanelEnabled("iiBackdrop", checked)
                StyledToolTip { text: Translation.tr("Blurred wallpaper shown in Niri's native overview (Mod+Tab)") }
            }

            SettingsSwitch {
                buttonIcon: "search"
                text: Translation.tr("Overview")
                checked: modulesPage.isPanelEnabled("iiOverview")
                onCheckedChanged: modulesPage.setPanelEnabled("iiOverview", checked)
                StyledToolTip { text: Translation.tr("Workspace grid (used by Start Menu)") }
            }

            SettingsSwitch {
                buttonIcon: "widgets"
                text: Translation.tr("Floating tools (Super+G)")
                checked: modulesPage.isPanelEnabled("iiOverlay")
                onCheckedChanged: modulesPage.setPanelEnabled("iiOverlay", checked)
                StyledToolTip { text: Translation.tr("Floating image and widgets panel (Super+G)") }
            }

            SettingsSwitch {
                buttonIcon: "lock"
                text: Translation.tr("Lock Screen")
                checked: modulesPage.isPanelEnabled("wLock")
                onCheckedChanged: modulesPage.setPanelEnabled("wLock", checked)
                StyledToolTip { text: Translation.tr("Custom lock screen with clock and password input") }
            }

            SettingsSwitch {
                buttonIcon: "power_settings_new"
                text: Translation.tr("Session Screen")
                checked: modulesPage.isPanelEnabled("wSessionScreen")
                onCheckedChanged: modulesPage.setPanelEnabled("wSessionScreen", checked)
                StyledToolTip { text: Translation.tr("Power menu: lock, logout, suspend, reboot, shutdown") }
            }

            SettingsSwitch {
                buttonIcon: "admin_panel_settings"
                text: Translation.tr("Polkit Agent")
                checked: modulesPage.isPanelEnabled("wPolkit")
                onCheckedChanged: modulesPage.setPanelEnabled("wPolkit", checked)
                StyledToolTip { text: Translation.tr("Password prompt for administrative actions") }
            }

            SettingsSwitch {
                buttonIcon: "screenshot_region"
                text: Translation.tr("Region Selector")
                checked: modulesPage.isPanelEnabled("iiRegionSelector")
                onCheckedChanged: modulesPage.setPanelEnabled("iiRegionSelector", checked)
                StyledToolTip { text: Translation.tr("Screen capture, OCR text extraction, color picker") }
            }

            SettingsSwitch {
                buttonIcon: "image"
                text: Translation.tr("Wallpaper Selector")
                checked: modulesPage.isPanelEnabled("iiWallpaperSelector")
                onCheckedChanged: modulesPage.setPanelEnabled("iiWallpaperSelector", checked)
                StyledToolTip { text: Translation.tr("File picker for changing wallpaper") }
            }

            SettingsSwitch {
                buttonIcon: "keyboard"
                text: Translation.tr("Cheatsheet")
                checked: modulesPage.isPanelEnabled("iiCheatsheet")
                onCheckedChanged: modulesPage.setPanelEnabled("iiCheatsheet", checked)
                StyledToolTip { text: Translation.tr("Keyboard shortcuts reference overlay") }
            }

            SettingsSwitch {
                buttonIcon: "keyboard_alt"
                text: Translation.tr("On-Screen Keyboard")
                checked: modulesPage.isPanelEnabled("iiOnScreenKeyboard")
                onCheckedChanged: modulesPage.setPanelEnabled("iiOnScreenKeyboard", checked)
                StyledToolTip { text: Translation.tr("Virtual keyboard for touch input") }
            }

            SettingsSwitch {
                buttonIcon: "tab"
                text: Translation.tr("Alt-Tab Switcher")
                checked: false
                enabled: false
                StyledToolTip { text: Translation.tr("Window switcher popup") }
            }

            SettingsSwitch {
                buttonIcon: "content_paste"
                text: Translation.tr("Clipboard History")
                checked: modulesPage.isPanelEnabled("iiClipboard")
                onCheckedChanged: modulesPage.setPanelEnabled("iiClipboard", checked)
                StyledToolTip { text: Translation.tr("Clipboard manager with history") }
            }

            SettingsSwitch {
                buttonIcon: "center_focus_strong"
                text: Translation.tr("Crosshair")
                checked: false
                enabled: false
                StyledToolTip { text: Translation.tr("Gaming crosshair overlay") }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "aspect_ratio"
        title: Translation.tr("Display scaling")

        SettingsGroup {
            ConfigRow {
                uniform: true
                ConfigSpinBox {
                    icon: "zoom_in"
                    text: Translation.tr("UI scale (%)")
                    value: Math.round((Config.options?.appearance?.typography?.sizeScale ?? 1.0) * 100)
                    from: 50
                    to: 200
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("appearance.typography.sizeScale", value / 100)
                    }
                    StyledToolTip {
                        text: Translation.tr("Scale fonts and spacing throughout the shell. Takes effect immediately.")
                    }
                }
            }

            StyledText {
                Layout.leftMargin: 16
                text: Translation.tr("Current: %1%. Takes effect immediately.").arg(
                    Math.round((Config.options?.appearance?.typography?.sizeScale ?? 1.0) * 100))
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            RowLayout {
                Layout.topMargin: 4
                visible: Math.abs((Config.options?.appearance?.typography?.sizeScale ?? 1.0) - 1.0) > 0.01

                RippleButtonWithIcon {
                    materialIcon: "zoom_out"
                    mainText: Translation.tr("Reset to 100%")
                    onClicked: {
                        Config.setNestedValue("appearance.typography.sizeScale", 1.0)
                    }
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "wallpaper_slideshow"
        title: Translation.tr("Wallpaper selector")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Selector style")

                ConfigSelectionArray {
                    currentValue: Config.options?.wallpaperSelector?.style ?? "grid"
                    options: [
                        { displayName: Translation.tr("Grid"), icon: "grid_view", value: "grid" },
                        { displayName: Translation.tr("Coverflow"), icon: "view_carousel", value: "coverflow" },
                        { displayName: Translation.tr("Launcher"), icon: "wallpaper_slideshow", value: "launcher" }
                    ]
                    onSelected: value => Config.setNestedValue("wallpaperSelector.style", value)
                }

                SettingsSwitch {
                    visible: (Config.options?.wallpaperSelector?.style ?? "grid") === "coverflow"
                    buttonIcon: "view_array"
                    text: Translation.tr("Skew view (parallelogram cards)")
                    checked: (Config.options?.wallpaperSelector?.coverflowView ?? "gallery") === "skew"
                    onCheckedChanged: Config.setNestedValue("wallpaperSelector.coverflowView", checked ? "skew" : "gallery")
                    StyledToolTip {
                        text: Translation.tr("Use tilted parallelogram cards instead of the hero + filmstrip layout.\nYou can also switch between views from the toolbar inside the coverflow.")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Behavior")

                SettingsSwitch {
                    buttonIcon: "open_in_new"
                    text: Translation.tr("Use system file picker")
                    checked: Config.options?.wallpaperSelector?.useSystemFileDialog ?? false
                    onCheckedChanged: Config.setNestedValue("wallpaperSelector.useSystemFileDialog", checked)
                    StyledToolTip {
                        text: Translation.tr("Use your system's native file picker instead of the built-in one")
                    }
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "web_asset"
        title: Translation.tr("Settings UI")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Choose how the Settings window opens. Overlay mode renders settings as a layer on top of the shell, so you can see changes to the bar, sidebars, and background in real time.")
                color: Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            SettingsSwitch {
                buttonIcon: "school"
                text: Translation.tr("Easy mode (essentials only)")
                checked: Config.options?.settingsUi?.easyMode ?? false
                onCheckedChanged: Config.setNestedValue("settingsUi.easyMode", checked)
                StyledToolTip {
                    text: Translation.tr("Show a curated set of essential settings and hide the more advanced pages and sections. You can switch back to Advanced anytime from the title bar.")
                }
            }

            SettingsSwitch {
                buttonIcon: "layers"
                text: Translation.tr("Overlay mode (live preview)")
                checked: Config.options?.settingsUi?.overlayMode ?? false
                onCheckedChanged: Config.setNestedValue("settingsUi.overlayMode", checked)
                StyledToolTip {
                    text: Translation.tr("When enabled, Settings opens as a floating overlay inside the shell instead of a separate window. This lets you preview changes instantly.\nRequires a shell restart to take effect.")
                }
            }

            ContentSubsection {
                title: Translation.tr("Overlay layout")
                visible: Config.options?.settingsUi?.overlayMode ?? false

                ConfigSelectionArray {
                    currentValue: Config.options?.settingsUi?.overlayStyle ?? "rail"
                    options: [
                        { displayName: Translation.tr("Nav rail"), icon: "view_sidebar", value: "rail" },
                        { displayName: Translation.tr("Focus"), icon: "grid_view", value: "focus" }
                    ]
                    onSelected: value => Config.setNestedValue("settingsUi.overlayStyle", value)
                }

                StyledText {
                    Layout.fillWidth: true
                    text: (Config.options?.settingsUi?.overlayStyle ?? "rail") === "focus"
                        ? Translation.tr("One page at a time: a grid of every settings page, then the page you pick, full width. Escape steps back.")
                        : Translation.tr("A persistent category rail beside the page you are editing.")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }
            }

            ContentSubsection {
                title: Translation.tr("Overlay appearance")
                visible: Config.options?.settingsUi?.overlayMode ?? false

                ConfigSpinBox {
                    icon: "blur_on"
                    text: Translation.tr("Backdrop blur (%)")
                    value: Config.options?.settingsUi?.overlayAppearance?.backdropBlur ?? 0
                    from: 0
                    to: 100
                    stepSize: 10
                    onValueChanged: Config.setNestedValue("settingsUi.overlayAppearance.backdropBlur", value)
                    StyledToolTip {
                        text: Translation.tr("Blur the wallpaper behind the Settings overlay while it is open, using the same glass the rest of the shell paints. 0 turns it off and costs nothing.")
                    }
                }

                ConfigSpinBox {
                    icon: "water"
                    text: Translation.tr("Background dim (%)")
                    value: Config.options?.settingsUi?.overlayAppearance?.scrimDim ?? 35
                    from: 0
                    to: 80
                    stepSize: 5
                    onValueChanged: Config.setNestedValue("settingsUi.overlayAppearance.scrimDim", value)
                    StyledToolTip {
                        text: Translation.tr("How dark the backdrop behind the Settings panel should be (0 = transparent, 80 = very dark)")
                    }
                }

                // Floor is 60, not 20: the panel is a reading surface and the
                // solid styles carry no backdrop of their own, so anything lower
                // put the wallpaper straight behind the text. Both settings
                // hosts clamp on read too, so an older stored value cannot reach
                // the panel even if this page is never opened.
                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Panel background opacity (%)")
                    value: Math.round((Config.options?.settingsUi?.overlayAppearance?.backgroundOpacity ?? 1.0) * 100)
                    from: 60
                    to: 100
                    stepSize: 5
                    onValueChanged: Config.setNestedValue("settingsUi.overlayAppearance.backgroundOpacity", value / 100)
                    StyledToolTip {
                        text: Translation.tr("Opacity of the Settings panel background. Lower values let the shell show through; with a glass style it thins the frosted tint instead.")
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: modeHintRow.implicitHeight + 16
                radius: Appearance.zzzEverywhere ? Appearance.zzz.cardRadius : Appearance.rounding.small
                color: Appearance.zzzEverywhere ? "transparent" : Appearance.colors.colSurfaceContainerLow
                border.width: Appearance.zzzEverywhere ? 0 : 1
                border.color: Appearance.zzzEverywhere ? "transparent" : Appearance.colors.colLayer0Border
                Behavior on radius {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }
                Behavior on border.width {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }
                Behavior on border.color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }

                ZzzPlate {
                    anchors.fill: parent
                    visible: Appearance.zzzEverywhere
                    fillColor: Appearance.colors.colLayer1
                    strokeColor: Appearance.zzz.hairline
                    radius: Appearance.zzz.cardRadius
                    chamfer: Appearance.zzz.cutCorner * 0.45
                    chamferTopRight: !Appearance.zzz.round
                }

                RowLayout {
                    id: modeHintRow
                    anchors {
                        fill: parent
                        margins: 8
                    }
                    spacing: 8

                    MaterialSymbol {
                        text: (Config.options?.settingsUi?.overlayMode ?? false) ? "layers" : "open_in_new"
                        iconSize: Appearance.font.pixelSize.huge
                        color: Appearance.colors.colPrimary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            text: (Config.options?.settingsUi?.overlayMode ?? false)
                                ? Translation.tr("Overlay mode")
                                : Translation.tr("Window mode")
                            font {
                                pixelSize: Appearance.font.pixelSize.small
                                weight: Font.Medium
                            }
                            color: Appearance.colors.colOnSurface
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: (Config.options?.settingsUi?.overlayMode ?? false)
                                ? Translation.tr("Settings will open as a floating panel over the shell. Press Esc or click outside to close.")
                                : Translation.tr("Settings will open as a separate application window (current behavior).")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
