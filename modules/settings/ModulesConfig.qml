import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: modulesPage
    settingsPageIndex: 9
    settingsPageName: Translation.tr("Modules")

    readonly property bool isWaffle: Config.options.panelFamily === "waffle"

    readonly property var defaultPanels: ({
        "inir": [
            "inirBar", "inirBackground", "inirBackdrop", "inirCheatsheet", "inirControlPanel", "inirDock", "inirLock", 
            "inirMediaControls", "inirNotificationPopup", "inirOnScreenDisplay", "inirOnScreenKeyboard", 
            "inirOverlay", "inirOverview", "inirPolkit", "inirRegionSelector", "inirScreenCorners", 
            "inirSessionScreen", "inirSidebarLeft", "inirSidebarRight", "inirVerticalBar", 
            "inirWallpaperSelector", "inirAltSwitcher", "inirClipboard"
        ],
        "waffle": [
            "wBar", "wBackground", "wStartMenu", "wActionCenter", "wNotificationCenter", "wNotificationPopup", "wOnScreenDisplay", "wWidgets", "wLock", "wPolkit", "wSessionScreen",
            "inirBackdrop", "inirCheatsheet", "inirControlPanel", "inirLock", "inirOnScreenKeyboard", "inirOverlay", "inirOverview", "inirPolkit", 
            "inirRegionSelector", "inirSessionScreen", "inirWallpaperSelector", "inirAltSwitcher", "inirClipboard"
        ]
    })

    function isPanelEnabled(panelId: string): bool {
        return Config.options.enabledPanels.includes(panelId)
    }

    function setPanelEnabled(panelId: string, enabled: bool) {
        let panels = [...Config.options.enabledPanels]
        const idx = panels.indexOf(panelId)
        
        if (enabled && idx === -1) {
            panels.push(panelId)
        } else if (!enabled && idx !== -1) {
            panels.splice(idx, 1)
        }
        
        Config.options.enabledPanels = panels
    }

    function resetToDefaults() {
        const family = Config.options.panelFamily || "inir"
        Config.options.enabledPanels = [...defaultPanels[family]]
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
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer1
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple: Appearance.colors.colLayer1Active

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        MaterialSymbol {
                            text: "restart_alt"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.m3colors.m3onSurface
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
        expanded: true
        icon: "style"
        title: Translation.tr("Panel Style")

        SettingsGroup {
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    buttonRadius: Appearance.rounding.small
                    colBackground: !modulesPage.isWaffle ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1
                    colBackgroundHover: !modulesPage.isWaffle ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer1Hover
                    colRipple: !modulesPage.isWaffle ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer1Active

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "dashboard"
                            iconSize: Appearance.font.pixelSize.larger
                            color: !modulesPage.isWaffle ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurface
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Material (inir)"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: !modulesPage.isWaffle ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurface
                        }
                    }

                    onClicked: {
                        Config.options.panelFamily = "inir"
                        Config.options.enabledPanels = [...modulesPage.defaultPanels["inir"]]
                    }
                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    buttonRadius: Appearance.rounding.small
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
                            color: modulesPage.isWaffle ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurface
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Windows 11 (Waffle)"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: modulesPage.isWaffle ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurface
                        }
                    }

                    onClicked: {
                        Config.options.panelFamily = "waffle"
                        Config.options.enabledPanels = [...modulesPage.defaultPanels["waffle"]]
                    }
                }
            }
        }
    }

    // ==================== DEFAULT TERMINAL ====================
    SettingsCardSection {
        id: terminalSection
        expanded: true
        icon: "terminal"
        title: Translation.tr("Default Terminal")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Terminal used by shell actions, tools, keybinds, and update commands.")
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
                    buttonRadius: Appearance.rounding.small
                    readonly property bool isSelected: (Config.options?.apps?.terminal ?? "kitty") === "foot"
                    colBackground: isSelected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1
                    colBackgroundHover: isSelected ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer1Hover
                    colRipple: isSelected ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer1Active
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "terminal"
                            iconSize: Appearance.font.pixelSize.larger
                            color: parent.parent.isSelected ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurface
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Foot"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: parent.parent.isSelected ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurface
                        }
                    }
                    onClicked: {
                        Config.setNestedValue("apps.terminal", "foot")
                        Config.setNestedValue("apps.update", "foot -e sudo pacman -Syu")
                    }
                }

                // Kitty
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    buttonRadius: Appearance.rounding.small
                    readonly property bool isSelected: (Config.options?.apps?.terminal ?? "kitty") === "kitty"
                    colBackground: isSelected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1
                    colBackgroundHover: isSelected ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer1Hover
                    colRipple: isSelected ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer1Active
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "terminal"
                            iconSize: Appearance.font.pixelSize.larger
                            color: parent.parent.isSelected ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurface
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Kitty"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: parent.parent.isSelected ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurface
                        }
                    }
                    onClicked: {
                        Config.setNestedValue("apps.terminal", "kitty")
                        Config.setNestedValue("apps.update", "kitty -e sudo pacman -Syu")
                    }
                }

                // Ghostty
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    buttonRadius: Appearance.rounding.small
                    readonly property bool isSelected: (Config.options?.apps?.terminal ?? "kitty") === "ghostty"
                    colBackground: isSelected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1
                    colBackgroundHover: isSelected ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer1Hover
                    colRipple: isSelected ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer1Active
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "terminal"
                            iconSize: Appearance.font.pixelSize.larger
                            color: parent.parent.isSelected ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurface
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Ghostty"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: parent.parent.isSelected ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurface
                        }
                    }
                    onClicked: {
                        Config.setNestedValue("apps.terminal", "ghostty")
                        Config.setNestedValue("apps.update", "ghostty -e sudo pacman -Syu")
                    }
                }

                // Alacritty
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    buttonRadius: Appearance.rounding.small
                    readonly property bool isSelected: (Config.options?.apps?.terminal ?? "kitty") === "alacritty"
                    colBackground: isSelected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1
                    colBackgroundHover: isSelected ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer1Hover
                    colRipple: isSelected ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer1Active
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "terminal"
                            iconSize: Appearance.font.pixelSize.larger
                            color: parent.parent.isSelected ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurface
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Alacritty"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: parent.parent.isSelected ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurface
                        }
                    }
                    onClicked: {
                        Config.setNestedValue("apps.terminal", "alacritty")
                        Config.setNestedValue("apps.update", "alacritty -e sudo pacman -Syu")
                    }
                }

                // WezTerm
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    buttonRadius: Appearance.rounding.small
                    readonly property bool isSelected: (Config.options?.apps?.terminal ?? "kitty") === "wezterm"
                    colBackground: isSelected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1
                    colBackgroundHover: isSelected ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer1Hover
                    colRipple: isSelected ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer1Active
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "terminal"
                            iconSize: Appearance.font.pixelSize.larger
                            color: parent.parent.isSelected ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurface
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "WezTerm"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: parent.parent.isSelected ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurface
                        }
                    }
                    onClicked: {
                        Config.setNestedValue("apps.terminal", "wezterm")
                        Config.setNestedValue("apps.update", "wezterm -e sudo pacman -Syu")
                    }
                }

                // Konsole
                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    buttonRadius: Appearance.rounding.small
                    readonly property bool isSelected: (Config.options?.apps?.terminal ?? "kitty") === "konsole"
                    colBackground: isSelected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1
                    colBackgroundHover: isSelected ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer1Hover
                    colRipple: isSelected ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer1Active
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "terminal"
                            iconSize: Appearance.font.pixelSize.larger
                            color: parent.parent.isSelected ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurface
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Konsole"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: parent.parent.isSelected ? Appearance.m3colors.m3onPrimaryContainer : Appearance.m3colors.m3onSurface
                        }
                    }
                    onClicked: {
                        Config.setNestedValue("apps.terminal", "konsole")
                        Config.setNestedValue("apps.update", "konsole -e sudo pacman -Syu")
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

    // ==================== MATERIAL INIR ====================
    SettingsCardSection {
        visible: !modulesPage.isWaffle
        expanded: true
        icon: "dashboard"
        title: Translation.tr("Core")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "toolbar"
                text: Translation.tr("Bar")
                checked: modulesPage.isPanelEnabled("inirBar")
                onCheckedChanged: modulesPage.setPanelEnabled("inirBar", checked)
                StyledToolTip { text: Translation.tr("Horizontal bar with clock, workspaces, system tray and utilities") }
            }

            SettingsSwitch {
                buttonIcon: "view_column"
                text: Translation.tr("Vertical Bar")
                checked: modulesPage.isPanelEnabled("inirVerticalBar")
                onCheckedChanged: modulesPage.setPanelEnabled("inirVerticalBar", checked)
                StyledToolTip { text: Translation.tr("Vertical bar layout (alternative to horizontal bar)") }
            }

            SettingsSwitch {
                buttonIcon: "wallpaper"
                text: Translation.tr("Background")
                checked: modulesPage.isPanelEnabled("inirBackground")
                onCheckedChanged: modulesPage.setPanelEnabled("inirBackground", checked)
                StyledToolTip { text: Translation.tr("Desktop wallpaper with parallax effect and widgets") }
            }

            SettingsSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Niri Overview Backdrop")
                checked: modulesPage.isPanelEnabled("inirBackdrop")
                onCheckedChanged: modulesPage.setPanelEnabled("inirBackdrop", checked)
                StyledToolTip { text: Translation.tr("Blurred wallpaper shown in Niri's native overview (Mod+Tab)") }
            }

            SettingsSwitch {
                buttonIcon: "search"
                text: Translation.tr("Overview")
                checked: modulesPage.isPanelEnabled("inirOverview")
                onCheckedChanged: modulesPage.setPanelEnabled("inirOverview", checked)
                StyledToolTip { text: Translation.tr("App launcher, search and workspace grid (Super+Space)") }
            }

            SettingsSwitch {
                buttonIcon: "widgets"
                text: Translation.tr("Overlay")
                checked: modulesPage.isPanelEnabled("inirOverlay")
                onCheckedChanged: modulesPage.setPanelEnabled("inirOverlay", checked)
                StyledToolTip { text: Translation.tr("Floating image and widgets panel (Super+G)") }
            }

            SettingsSwitch {
                buttonIcon: "left_panel_open"
                text: Translation.tr("Left Sidebar")
                checked: modulesPage.isPanelEnabled("inirSidebarLeft")
                onCheckedChanged: modulesPage.setPanelEnabled("inirSidebarLeft", checked)
                StyledToolTip { text: Translation.tr("AI assistant, translator, image browser") }
            }

            SettingsSwitch {
                buttonIcon: "right_panel_open"
                text: Translation.tr("Right Sidebar")
                checked: modulesPage.isPanelEnabled("inirSidebarRight")
                onCheckedChanged: modulesPage.setPanelEnabled("inirSidebarRight", checked)
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
                checked: modulesPage.isPanelEnabled("inirNotificationPopup")
                onCheckedChanged: modulesPage.setPanelEnabled("inirNotificationPopup", checked)
                StyledToolTip { text: Translation.tr("Toast notifications that appear on screen") }
            }

            SettingsSwitch {
                buttonIcon: "volume_up"
                text: Translation.tr("OSD")
                checked: modulesPage.isPanelEnabled("inirOnScreenDisplay")
                onCheckedChanged: modulesPage.setPanelEnabled("inirOnScreenDisplay", checked)
                StyledToolTip { text: Translation.tr("On-screen display for volume and brightness changes") }
            }

            SettingsSwitch {
                buttonIcon: "music_note"
                text: Translation.tr("Media Controls")
                checked: modulesPage.isPanelEnabled("inirMediaControls")
                onCheckedChanged: modulesPage.setPanelEnabled("inirMediaControls", checked)
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
                checked: modulesPage.isPanelEnabled("inirLock")
                onCheckedChanged: modulesPage.setPanelEnabled("inirLock", checked)
                StyledToolTip { text: Translation.tr("Custom lock screen with clock and password input") }
            }

            SettingsSwitch {
                buttonIcon: "power_settings_new"
                text: Translation.tr("Session Screen")
                checked: modulesPage.isPanelEnabled("inirSessionScreen")
                onCheckedChanged: modulesPage.setPanelEnabled("inirSessionScreen", checked)
                StyledToolTip { text: Translation.tr("Power menu: lock, logout, suspend, reboot, shutdown") }
            }

            SettingsSwitch {
                buttonIcon: "admin_panel_settings"
                text: Translation.tr("Polkit Agent")
                checked: modulesPage.isPanelEnabled("inirPolkit")
                onCheckedChanged: modulesPage.setPanelEnabled("inirPolkit", checked)
                StyledToolTip { text: Translation.tr("Password prompt for administrative actions") }
            }

            SettingsSwitch {
                buttonIcon: "screenshot_region"
                text: Translation.tr("Region Selector")
                checked: modulesPage.isPanelEnabled("inirRegionSelector")
                onCheckedChanged: modulesPage.setPanelEnabled("inirRegionSelector", checked)
                StyledToolTip { text: Translation.tr("Screen capture, OCR text extraction, color picker") }
            }

            SettingsSwitch {
                buttonIcon: "image"
                text: Translation.tr("Wallpaper Selector")
                checked: modulesPage.isPanelEnabled("inirWallpaperSelector")
                onCheckedChanged: modulesPage.setPanelEnabled("inirWallpaperSelector", checked)
                StyledToolTip { text: Translation.tr("File picker for changing wallpaper") }
            }

            SettingsSwitch {
                buttonIcon: "keyboard"
                text: Translation.tr("Cheatsheet")
                checked: modulesPage.isPanelEnabled("inirCheatsheet")
                onCheckedChanged: modulesPage.setPanelEnabled("inirCheatsheet", checked)
                StyledToolTip { text: Translation.tr("Keyboard shortcuts reference overlay") }
            }

            SettingsSwitch {
                buttonIcon: "keyboard_alt"
                text: Translation.tr("On-Screen Keyboard")
                checked: modulesPage.isPanelEnabled("inirOnScreenKeyboard")
                onCheckedChanged: modulesPage.setPanelEnabled("inirOnScreenKeyboard", checked)
                StyledToolTip { text: Translation.tr("Virtual keyboard for touch input") }
            }

            SettingsSwitch {
                buttonIcon: "tab"
                text: Translation.tr("Alt-Tab Switcher")
                checked: modulesPage.isPanelEnabled("inirAltSwitcher")
                onCheckedChanged: modulesPage.setPanelEnabled("inirAltSwitcher", checked)
                StyledToolTip { text: Translation.tr("Window switcher popup") }
            }

            SettingsSwitch {
                buttonIcon: "content_paste"
                text: Translation.tr("Clipboard History")
                checked: modulesPage.isPanelEnabled("inirClipboard")
                onCheckedChanged: modulesPage.setPanelEnabled("inirClipboard", checked)
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
                checked: modulesPage.isPanelEnabled("inirDock")
                onCheckedChanged: modulesPage.setPanelEnabled("inirDock", checked)
                StyledToolTip { text: Translation.tr("macOS-style dock with pinned and running apps") }
            }

            SettingsSwitch {
                buttonIcon: "rounded_corner"
                text: Translation.tr("Screen Corners")
                checked: modulesPage.isPanelEnabled("inirScreenCorners")
                onCheckedChanged: modulesPage.setPanelEnabled("inirScreenCorners", checked)
                StyledToolTip { text: Translation.tr("Rounded corner overlays for screens without hardware rounding") }
            }

            SettingsSwitch {
                buttonIcon: "center_focus_strong"
                text: Translation.tr("Crosshair")
                checked: modulesPage.isPanelEnabled("inirCrosshair")
                onCheckedChanged: modulesPage.setPanelEnabled("inirCrosshair", checked)
                StyledToolTip { text: Translation.tr("Gaming crosshair overlay for games without built-in crosshair") }
            }
        }
    }

    // ==================== WAFFLE ====================
    SettingsCardSection {
        visible: modulesPage.isWaffle
        expanded: true
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
                text: Translation.tr("Modules shared with Material inir style")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }

            SettingsSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Niri Overview Backdrop")
                checked: modulesPage.isPanelEnabled("inirBackdrop")
                onCheckedChanged: modulesPage.setPanelEnabled("inirBackdrop", checked)
                StyledToolTip { text: Translation.tr("Blurred wallpaper shown in Niri's native overview (Mod+Tab)") }
            }

            SettingsSwitch {
                buttonIcon: "search"
                text: Translation.tr("Overview")
                checked: modulesPage.isPanelEnabled("inirOverview")
                onCheckedChanged: modulesPage.setPanelEnabled("inirOverview", checked)
                StyledToolTip { text: Translation.tr("Workspace grid (used by Start Menu)") }
            }

            SettingsSwitch {
                buttonIcon: "widgets"
                text: Translation.tr("Overlay")
                checked: modulesPage.isPanelEnabled("inirOverlay")
                onCheckedChanged: modulesPage.setPanelEnabled("inirOverlay", checked)
                StyledToolTip { text: Translation.tr("Floating image and widgets panel (Super+G)") }
            }

            SettingsSwitch {
                buttonIcon: "lock"
                text: Translation.tr("Lock Screen")
                checked: modulesPage.isPanelEnabled("inirLock")
                onCheckedChanged: modulesPage.setPanelEnabled("inirLock", checked)
                StyledToolTip { text: Translation.tr("Custom lock screen with clock and password input") }
            }

            SettingsSwitch {
                buttonIcon: "power_settings_new"
                text: Translation.tr("Session Screen")
                checked: modulesPage.isPanelEnabled("inirSessionScreen")
                onCheckedChanged: modulesPage.setPanelEnabled("inirSessionScreen", checked)
                StyledToolTip { text: Translation.tr("Power menu: lock, logout, suspend, reboot, shutdown") }
            }

            SettingsSwitch {
                buttonIcon: "admin_panel_settings"
                text: Translation.tr("Polkit Agent")
                checked: modulesPage.isPanelEnabled("inirPolkit")
                onCheckedChanged: modulesPage.setPanelEnabled("inirPolkit", checked)
                StyledToolTip { text: Translation.tr("Password prompt for administrative actions") }
            }

            SettingsSwitch {
                buttonIcon: "screenshot_region"
                text: Translation.tr("Region Selector")
                checked: modulesPage.isPanelEnabled("inirRegionSelector")
                onCheckedChanged: modulesPage.setPanelEnabled("inirRegionSelector", checked)
                StyledToolTip { text: Translation.tr("Screen capture, OCR text extraction, color picker") }
            }

            SettingsSwitch {
                buttonIcon: "image"
                text: Translation.tr("Wallpaper Selector")
                checked: modulesPage.isPanelEnabled("inirWallpaperSelector")
                onCheckedChanged: modulesPage.setPanelEnabled("inirWallpaperSelector", checked)
                StyledToolTip { text: Translation.tr("File picker for changing wallpaper") }
            }

            SettingsSwitch {
                buttonIcon: "keyboard"
                text: Translation.tr("Cheatsheet")
                checked: modulesPage.isPanelEnabled("inirCheatsheet")
                onCheckedChanged: modulesPage.setPanelEnabled("inirCheatsheet", checked)
                StyledToolTip { text: Translation.tr("Keyboard shortcuts reference overlay") }
            }

            SettingsSwitch {
                buttonIcon: "keyboard_alt"
                text: Translation.tr("On-Screen Keyboard")
                checked: modulesPage.isPanelEnabled("inirOnScreenKeyboard")
                onCheckedChanged: modulesPage.setPanelEnabled("inirOnScreenKeyboard", checked)
                StyledToolTip { text: Translation.tr("Virtual keyboard for touch input") }
            }

            SettingsSwitch {
                buttonIcon: "tab"
                text: Translation.tr("Alt-Tab Switcher")
                checked: modulesPage.isPanelEnabled("inirAltSwitcher")
                onCheckedChanged: modulesPage.setPanelEnabled("inirAltSwitcher", checked)
                StyledToolTip { text: Translation.tr("Window switcher popup") }
            }

            SettingsSwitch {
                buttonIcon: "content_paste"
                text: Translation.tr("Clipboard History")
                checked: modulesPage.isPanelEnabled("inirClipboard")
                onCheckedChanged: modulesPage.setPanelEnabled("inirClipboard", checked)
                StyledToolTip { text: Translation.tr("Clipboard manager with history") }
            }

            SettingsSwitch {
                buttonIcon: "center_focus_strong"
                text: Translation.tr("Crosshair")
                checked: modulesPage.isPanelEnabled("inirCrosshair")
                onCheckedChanged: modulesPage.setPanelEnabled("inirCrosshair", checked)
                StyledToolTip { text: Translation.tr("Gaming crosshair overlay") }
            }
        }
    }
}
