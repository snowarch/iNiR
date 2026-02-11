import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    id: root
    settingsPageIndex: 10
    settingsPageName: Translation.tr("Waffle Style")

    property bool isWaffleActive: Config.options?.panelFamily === "waffle"

    // Helper to check if a module is enabled
    function isPanelEnabled(panelId: string): bool {
        return Config.options?.enabledPanels?.includes(panelId) ?? false
    }

    SettingsCardSection {
        visible: !root.isWaffleActive
        expanded: true
        icon: "info"
        title: Translation.tr("Not Active")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("These settings only apply when using the Windows 11 (Waffle) panel style. Go to Modules → Panel Style to enable it.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }
        }
    }

    // Wallpaper section
    // Wallpaper section
    SettingsCardSection {
        visible: root.isWaffleActive && root.isPanelEnabled("wBackground")
        expanded: true
        icon: "wallpaper"
        title: Translation.tr("Wallpaper")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "link"
                text: Translation.tr("Use main wallpaper")
                checked: Config.options?.waffles?.background?.useMainWallpaper ?? true
                onCheckedChanged: {
                    Config.setNestedValue("waffles.background.useMainWallpaper", checked);
                    if (checked) Config.setNestedValue("waffles.background.wallpaperPath", "");
                }
                StyledToolTip { text: Translation.tr("Share wallpaper with Material ii style") }
            }

            RippleButtonWithIcon {
                visible: Config.options?.waffles?.background?.useMainWallpaper ?? true
                Layout.fillWidth: true
                buttonRadius: Appearance.rounding.small
                materialIcon: "wallpaper"
                mainText: Translation.tr("Pick main wallpaper")
                onClicked: {
                    Config.options.wallpaperSelector.selectionTarget = "main";
                    Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggle"]);
                }
            }

            RippleButtonWithIcon {
                visible: !(Config.options?.waffles?.background?.useMainWallpaper ?? true)
                Layout.fillWidth: true
                buttonRadius: Appearance.rounding.small
                materialIcon: "wallpaper"
                mainText: Translation.tr("Pick Waffle wallpaper")
                onClicked: {
                    Config.options.wallpaperSelector.selectionTarget = "waffle";
                    Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggle"]);
                }
            }

            SettingsSwitch {
                buttonIcon: "fullscreen_exit"
                text: Translation.tr("Hide when fullscreen")
                checked: Config.options?.waffles?.background?.hideWhenFullscreen ?? true
                onCheckedChanged: Config.setNestedValue("waffles.background.hideWhenFullscreen", checked)
            }
            
            SettingsSwitch {
                buttonIcon: "play_circle"
                text: Translation.tr("Enable animated wallpapers (videos/GIFs)")
                checked: Config.options?.waffles?.background?.enableAnimation ?? true
                onCheckedChanged: {
                    Config.setNestedValue("waffles.background.enableAnimation", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Play videos and GIFs as wallpaper. When disabled, shows thumbnail instead (better performance)")
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isWaffleActive && root.isPanelEnabled("wBackground")
        expanded: false
        icon: "auto_awesome"
        title: Translation.tr("Wallpaper Effects")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Enable blur")
                checked: Config.options?.waffles?.background?.effects?.enableBlur ?? false
                onCheckedChanged: Config.setNestedValue("waffles.background.effects.enableBlur", checked)
            }

            ConfigSpinBox {
                visible: Config.options?.waffles?.background?.effects?.enableBlur ?? false
                icon: "blur_medium"
                text: Translation.tr("Blur radius")
                from: 0; to: 64; stepSize: 2
                value: Config.options?.waffles?.background?.effects?.blurRadius ?? 32
                onValueChanged: Config.setNestedValue("waffles.background.effects.blurRadius", value)
            }

            ConfigSpinBox {
                visible: Config.options?.waffles?.background?.effects?.enableBlur ?? false
                icon: "blur_circular"
                text: Translation.tr("Static blur (%)")
                from: 0; to: 100; stepSize: 5
                value: Config.options?.waffles?.background?.effects?.blurStatic ?? 0
                onValueChanged: Config.setNestedValue("waffles.background.effects.blurStatic", value)
                StyledToolTip { text: Translation.tr("Always-on blur percentage. Dynamic blur adds on top when windows are present.") }
            }

            ConfigSpinBox {
                icon: "brightness_5"
                text: Translation.tr("Dim (%)")
                from: 0; to: 100; stepSize: 5
                value: Config.options?.waffles?.background?.effects?.dim ?? 0
                onValueChanged: Config.setNestedValue("waffles.background.effects.dim", value)
            }

            ConfigSpinBox {
                icon: "brightness_auto"
                text: Translation.tr("Dynamic dim (%)")
                from: 0; to: 100; stepSize: 5
                value: Config.options?.waffles?.background?.effects?.dynamicDim ?? 0
                onValueChanged: Config.setNestedValue("waffles.background.effects.dynamicDim", value)
                StyledToolTip { text: Translation.tr("Extra dim when windows are present on current workspace") }
            }
        }
    }

    SettingsCardSection {
        visible: root.isWaffleActive
        expanded: false
        icon: "layers"
        title: Translation.tr("Backdrop (Niri Overview)")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Backdrop is the wallpaper shown during Niri's native overview (Mod+Tab). It's always rendered in the background layer.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            SettingsSwitch {
                buttonIcon: "texture"
                text: Translation.tr("Enable backdrop layer for overview")
                checked: Config.options?.waffles?.background?.backdrop?.enable ?? true
                onCheckedChanged: {
                    Config.options.waffles.background.backdrop.enable = checked;
                }
            }

            SettingsSwitch {
                visible: Config.options?.waffles?.background?.backdrop?.enable ?? true
                buttonIcon: "play_circle"
                text: Translation.tr("Enable animated wallpapers (videos/GIFs)")
                checked: Config.options?.waffles?.background?.backdrop?.enableAnimation ?? false
                onCheckedChanged: {
                    Config.setNestedValue("waffles.background.backdrop.enableAnimation", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Play videos and GIFs in backdrop (may impact performance)")
                }
            }

            SettingsSwitch {
                visible: Config.options?.waffles?.background?.backdrop?.enable ?? true
                buttonIcon: "visibility_off"
                text: Translation.tr("Hide main wallpaper (show only backdrop)")
                checked: Config.options?.waffles?.background?.backdrop?.hideWallpaper ?? false
                onCheckedChanged: {
                    Config.options.waffles.background.backdrop.hideWallpaper = checked;
                }
                StyledToolTip { text: Translation.tr("Hides the desktop wallpaper, showing only the backdrop during Niri's overview") }
            }

            SettingsSwitch {
                visible: Config.options?.waffles?.background?.backdrop?.enable ?? true
                buttonIcon: "link"
                text: Translation.tr("Use main wallpaper")
                checked: Config.options?.waffles?.background?.backdrop?.useMainWallpaper ?? true
                onCheckedChanged: {
                    Config.options.waffles.background.backdrop.useMainWallpaper = checked;
                    if (checked) Config.options.waffles.background.backdrop.wallpaperPath = "";
                }
            }

            RippleButtonWithIcon {
                visible: (Config.options?.waffles?.background?.backdrop?.enable ?? true) && !(Config.options?.waffles?.background?.backdrop?.useMainWallpaper ?? true)
                Layout.fillWidth: true
                buttonRadius: Appearance.rounding.small
                materialIcon: "wallpaper"
                mainText: Translation.tr("Pick backdrop wallpaper")
                onClicked: {
                    Config.options.wallpaperSelector.selectionTarget = "waffle-backdrop";
                    Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggle"]);
                }
            }

            ConfigSpinBox {
                visible: Config.options?.waffles?.background?.backdrop?.enable ?? true
                icon: "blur_on"
                text: Translation.tr("Blur radius")
                from: 0; to: 100; stepSize: 5
                value: Config.options?.waffles?.background?.backdrop?.blurRadius ?? 32
                onValueChanged: Config.options.waffles.background.backdrop.blurRadius = value
            }

            ConfigSpinBox {
                visible: Config.options?.waffles?.background?.backdrop?.enable ?? true
                icon: "brightness_5"
                text: Translation.tr("Dim (%)")
                from: 0; to: 100; stepSize: 5
                value: Config.options?.waffles?.background?.backdrop?.dim ?? 35
                onValueChanged: Config.options.waffles.background.backdrop.dim = value
            }

            ConfigSpinBox {
                visible: Config.options?.waffles?.background?.backdrop?.enable ?? true
                icon: "contrast"
                text: Translation.tr("Saturation")
                from: 0; to: 200; stepSize: 10
                value: Math.round((Config.options?.waffles?.background?.backdrop?.saturation ?? 1.0) * 100)
                onValueChanged: Config.options.waffles.background.backdrop.saturation = value / 100.0
            }

            ConfigSpinBox {
                visible: Config.options?.waffles?.background?.backdrop?.enable ?? true
                icon: "exposure"
                text: Translation.tr("Contrast")
                from: 0; to: 200; stepSize: 10
                value: Math.round((Config.options?.waffles?.background?.backdrop?.contrast ?? 1.0) * 100)
                onValueChanged: Config.options.waffles.background.backdrop.contrast = value / 100.0
            }

            SettingsSwitch {
                visible: Config.options?.waffles?.background?.backdrop?.enable ?? true
                buttonIcon: "vignette"
                text: Translation.tr("Vignette")
                checked: Config.options?.waffles?.background?.backdrop?.vignetteEnabled ?? false
                onCheckedChanged: Config.options.waffles.background.backdrop.vignetteEnabled = checked
            }

            ConfigSpinBox {
                visible: (Config.options?.waffles?.background?.backdrop?.enable ?? true) && (Config.options?.waffles?.background?.backdrop?.vignetteEnabled ?? false)
                icon: "opacity"
                text: Translation.tr("Vignette intensity")
                from: 0; to: 100; stepSize: 5
                value: Math.round((Config.options?.waffles?.background?.backdrop?.vignetteIntensity ?? 0.5) * 100)
                onValueChanged: Config.options.waffles.background.backdrop.vignetteIntensity = value / 100.0
            }
        }
    }

    SettingsCardSection {
        visible: root.isWaffleActive && root.isPanelEnabled("wBar")
        expanded: false
        icon: "toolbar"
        title: Translation.tr("Taskbar")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "vertical_align_bottom"
                text: Translation.tr("Bottom position")
                checked: Config.options?.waffles?.bar?.bottom ?? true
                onCheckedChanged: Config.options.waffles.bar.bottom = checked
            }

            SettingsSwitch {
                buttonIcon: "format_align_left"
                text: Translation.tr("Left-align apps")
                checked: Config.options?.waffles?.bar?.leftAlignApps ?? false
                onCheckedChanged: Config.options.waffles.bar.leftAlignApps = checked
            }

            SettingsSwitch {
                buttonIcon: "palette"
                text: Translation.tr("Tint app icons")
                checked: Config.options?.waffles?.bar?.monochromeIcons ?? false
                onCheckedChanged: Config.options.waffles.bar.monochromeIcons = checked
            }

            SettingsSwitch {
                buttonIcon: "palette"
                text: Translation.tr("Tint tray icons")
                checked: Config.options?.waffles?.bar?.tintTrayIcons ?? false
                onCheckedChanged: Config.options.waffles.bar.tintTrayIcons = checked
            }
        }
    }

    SettingsCardSection {
        id: themingSection
        visible: root.isWaffleActive
        expanded: false
        icon: "palette"
        title: Translation.tr("Theming")

        property string currentFontFamily: Config.options?.waffles?.theming?.font?.family ?? "Noto Sans"
        property string defaultFont: "Noto Sans"

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "format_color_fill"
                text: Translation.tr("Use Material colors")
                checked: Config.options?.waffles?.theming?.useMaterialColors ?? false
                onCheckedChanged: Config.options.waffles.theming.useMaterialColors = checked
                StyledToolTip { text: Translation.tr("Apply the Material ii color scheme instead of Windows 11 grey") }
            }

            ConfigSelectionArray {
                options: [
                    { displayName: "Segoe UI", icon: "window", value: "Segoe UI Variable" },
                    { displayName: "Inter", icon: "text_fields", value: "Inter" },
                    { displayName: "Roboto", icon: "android", value: "Roboto" },
                    { displayName: "Noto Sans", icon: "translate", value: "Noto Sans" },
                    { displayName: "Ubuntu", icon: "terminal", value: "Ubuntu" }
                ]
                currentValue: themingSection.currentFontFamily
                onSelected: newValue => Config.setNestedValue("waffles.theming.font.family", newValue)
            }

            FontSelector {
                label: Translation.tr("Custom font")
                icon: "font_download"
                selectedFont: themingSection.currentFontFamily
                onSelectedFontChanged: Config.setNestedValue("waffles.theming.font.family", selectedFont)
            }

            ConfigSpinBox {
                icon: "format_size"
                text: Translation.tr("Font scale (%)")
                from: 80; to: 150; stepSize: 5
                value: Math.round((Config.options?.waffles?.theming?.font?.scale ?? 1.0) * 100)
                onValueChanged: Config.setNestedValue("waffles.theming.font.scale", value / 100.0)
                StyledToolTip { text: Translation.tr("Scale all Waffle UI text (80% - 150%)") }
            }

            RippleButton {
                visible: themingSection.currentFontFamily !== themingSection.defaultFont || (Config.options?.waffles?.theming?.font?.scale ?? 1.0) !== 1.0
                Layout.fillWidth: true
                implicitHeight: 36
                
                colBackground: Appearance.colors.colLayer1
                colBackgroundHover: Appearance.colors.colLayer1Hover
                colRipple: Appearance.colors.colLayer1Active

                contentItem: RowLayout {
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
                        color: Appearance.m3colors.m3onSurface
                    }
                }

                onClicked: {
                    Config.setNestedValue("waffles.theming.font.family", themingSection.defaultFont);
                    Config.setNestedValue("waffles.theming.font.scale", 1.0);
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isWaffleActive
        expanded: false
        icon: "widgets"
        title: Translation.tr("Behavior")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "stacks"
                text: Translation.tr("Allow multiple panels open")
                checked: Config.options?.waffles?.behavior?.allowMultiplePanels ?? false
                onCheckedChanged: Config.options.waffles.behavior.allowMultiplePanels = checked
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "swap_horiz"
        title: Translation.tr("Family Transition")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Settings for switching between Material ii and Waffle panel styles.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            SettingsSwitch {
                buttonIcon: "animation"
                text: Translation.tr("Animated transition")
                checked: Config.options?.familyTransitionAnimation ?? true
                onCheckedChanged: Config.options.familyTransitionAnimation = checked
                StyledToolTip { text: Translation.tr("Show a smooth animated overlay when switching between panel families") }
            }
        }
    }

    SettingsCardSection {
        visible: root.isWaffleActive && root.isPanelEnabled("wStartMenu")
        expanded: false
        icon: "grid_view"
        title: Translation.tr("Start Menu")

        SettingsGroup {
            ConfigSelectionArray {
                options: [
                    { displayName: Translation.tr("Mini"), icon: "crop_square", value: "mini" },
                    { displayName: Translation.tr("Compact"), icon: "view_compact", value: "compact" },
                    { displayName: Translation.tr("Normal"), icon: "grid_view", value: "normal" },
                    { displayName: Translation.tr("Large"), icon: "grid_on", value: "large" },
                    { displayName: Translation.tr("Wide"), icon: "view_week", value: "wide" }
                ]
                currentValue: Config.options?.waffles?.startMenu?.sizePreset ?? "normal"
                onSelected: (newValue) => Config.options.waffles.startMenu.sizePreset = newValue
            }

            ConfigSpinBox {
                icon: "format_size"
                text: Translation.tr("Text scale (%)")
                from: 80; to: 150; stepSize: 5
                value: Math.round((Config.options?.waffles?.startMenu?.scale ?? 1.0) * 100)
                onValueChanged: Config.setNestedValue("waffles.startMenu.scale", value / 100.0)
                StyledToolTip { text: Translation.tr("Scale text in the start menu (80% - 150%)") }
            }
        }
    }

    SettingsCardSection {
        visible: root.isWaffleActive
        expanded: false
        icon: "tune"
        title: Translation.tr("Tweaks")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "animation"
                text: Translation.tr("Smoother menu animations")
                checked: Config.options?.waffles?.tweaks?.smootherMenuAnimations ?? true
                onCheckedChanged: Config.options.waffles.tweaks.smootherMenuAnimations = checked
            }

            SettingsSwitch {
                buttonIcon: "toggle_on"
                text: Translation.tr("Switch handle position fix")
                checked: Config.options?.waffles?.tweaks?.switchHandlePositionFix ?? true
                onCheckedChanged: Config.options.waffles.tweaks.switchHandlePositionFix = checked
            }
        }
    }

    SettingsCardSection {
        visible: root.isWaffleActive && root.isPanelEnabled("wNotificationCenter")
        expanded: false
        icon: "calendar_month"
        title: Translation.tr("Calendar")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "calendar_today"
                text: Translation.tr("Force 2-character day of week")
                checked: Config.options?.waffles?.calendar?.force2CharDayOfWeek ?? true
                onCheckedChanged: Config.options.waffles.calendar.force2CharDayOfWeek = checked
            }
        }
    }

    SettingsCardSection {
        visible: root.isWaffleActive && root.isPanelEnabled("iiAltSwitcher")
        expanded: false
        icon: "swap_horiz"
        title: Translation.tr("Alt+Tab Switcher")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "visibility_off"
                text: Translation.tr("No visual UI (cycle windows only)")
                checked: Config.options?.waffles?.altSwitcher?.noVisualUi ?? false
                onCheckedChanged: Config.setNestedValue("waffles.altSwitcher.noVisualUi", checked)
                StyledToolTip { text: Translation.tr("Use Alt+Tab to switch windows without showing the switcher overlay") }
            }

            ConfigSelectionArray {
                options: [
                    { displayName: Translation.tr("Thumbnails"), icon: "grid_view", value: "thumbnails" },
                    { displayName: Translation.tr("Cards"), icon: "view_carousel", value: "cards" },
                    { displayName: Translation.tr("Compact"), icon: "view_module", value: "compact" },
                    { displayName: Translation.tr("List"), icon: "view_list", value: "list" },
                    { displayName: Translation.tr("None (no UI)"), icon: "visibility_off", value: "none" }
                ]
                currentValue: Config.options?.waffles?.altSwitcher?.preset ?? "thumbnails"
                onSelected: (newValue) => Config.setNestedValue("waffles.altSwitcher.preset", newValue)
            }

            SettingsSwitch {
                buttonIcon: "bolt"
                text: Translation.tr("Quick switch (Alt+Tab once to switch)")
                checked: Config.options?.waffles?.altSwitcher?.quickSwitch ?? true
                onCheckedChanged: Config.setNestedValue("waffles.altSwitcher.quickSwitch", checked)
                StyledToolTip { text: Translation.tr("Single Alt+Tab switches to previous window without showing the switcher") }
            }

            SettingsSwitch {
                buttonIcon: "timer"
                text: Translation.tr("Auto-hide after delay")
                checked: Config.options?.waffles?.altSwitcher?.autoHide ?? true
                onCheckedChanged: Config.setNestedValue("waffles.altSwitcher.autoHide", checked)
            }

            ConfigSpinBox {
                visible: Config.options?.waffles?.altSwitcher?.autoHide ?? true
                icon: "hourglass_empty"
                text: Translation.tr("Auto-hide delay (ms)")
                from: 100; to: 5000; stepSize: 100
                value: Config.options?.waffles?.altSwitcher?.autoHideDelayMs ?? 500
                onValueChanged: Config.setNestedValue("waffles.altSwitcher.autoHideDelayMs", value)
            }

            SettingsSwitch {
                buttonIcon: "close"
                text: Translation.tr("Close on window focus")
                checked: Config.options?.waffles?.altSwitcher?.closeOnFocus ?? true
                onCheckedChanged: Config.setNestedValue("waffles.altSwitcher.closeOnFocus", checked)
            }

            SettingsSwitch {
                buttonIcon: "history"
                text: Translation.tr("Most recent first")
                checked: Config.options?.waffles?.altSwitcher?.useMostRecentFirst ?? true
                onCheckedChanged: Config.setNestedValue("waffles.altSwitcher.useMostRecentFirst", checked)
            }

            ConfigSpinBox {
                visible: (Config.options?.waffles?.altSwitcher?.preset ?? "thumbnails") === "thumbnails"
                icon: "width"
                text: Translation.tr("Thumbnail width")
                from: 150; to: 500; stepSize: 20
                value: Config.options?.waffles?.altSwitcher?.thumbnailWidth ?? 280
                onValueChanged: Config.setNestedValue("waffles.altSwitcher.thumbnailWidth", value)
            }

            ConfigSpinBox {
                visible: (Config.options?.waffles?.altSwitcher?.preset ?? "thumbnails") === "thumbnails"
                icon: "height"
                text: Translation.tr("Thumbnail height")
                from: 100; to: 400; stepSize: 20
                value: Config.options?.waffles?.altSwitcher?.thumbnailHeight ?? 180
                onValueChanged: Config.setNestedValue("waffles.altSwitcher.thumbnailHeight", value)
            }

            // List width option disabled - WPane doesn't support dynamic width properly
            // ConfigSpinBox {
            //     visible: (Config.options?.waffles?.altSwitcher?.preset ?? "thumbnails") === "list"
            //     icon: "width"
            //     text: Translation.tr("List width")
            //     from: 350; to: 800; stepSize: 25
            //     value: Config.options?.waffles?.altSwitcher?.listWidth ?? 500
            //     onValueChanged: Config.options.waffles.altSwitcher.listWidth = value
            // }

            ConfigSpinBox {
                icon: "opacity"
                text: Translation.tr("Scrim opacity")
                from: 0; to: 100; stepSize: 5
                value: Math.round((Config.options?.waffles?.altSwitcher?.scrimOpacity ?? 0.4) * 100)
                onValueChanged: Config.setNestedValue("waffles.altSwitcher.scrimOpacity", value / 100.0)
            }

            SettingsSwitch {
                buttonIcon: "grid_view"
                text: Translation.tr("Show Niri overview while switching")
                checked: Config.options?.waffles?.altSwitcher?.showOverviewWhileSwitching ?? false
                onCheckedChanged: Config.setNestedValue("waffles.altSwitcher.showOverviewWhileSwitching", checked)
                StyledToolTip { text: Translation.tr("Opens Niri's native overview alongside the switcher for window previews") }
            }
        }
    }

    SettingsCardSection {
        visible: root.isWaffleActive && root.isPanelEnabled("wWidgets")
        expanded: false
        icon: "widgets"
        title: Translation.tr("Widgets Panel")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "schedule"
                text: Translation.tr("Date & Time")
                checked: Config.options?.waffles?.widgetsPanel?.showDateTime ?? true
                onCheckedChanged: Config.options.waffles.widgetsPanel.showDateTime = checked
            }

            SettingsSwitch {
                buttonIcon: "cloud"
                text: Translation.tr("Weather")
                checked: Config.options?.waffles?.widgetsPanel?.showWeather ?? true
                onCheckedChanged: Config.options.waffles.widgetsPanel.showWeather = checked
            }

            SettingsSwitch {
                buttonIcon: "memory"
                text: Translation.tr("System Resources")
                checked: Config.options?.waffles?.widgetsPanel?.showSystem ?? true
                onCheckedChanged: Config.options.waffles.widgetsPanel.showSystem = checked
            }

            SettingsSwitch {
                buttonIcon: "music_note"
                text: Translation.tr("Media Player")
                checked: Config.options?.waffles?.widgetsPanel?.showMedia ?? true
                onCheckedChanged: Config.options.waffles.widgetsPanel.showMedia = checked
            }

            SettingsSwitch {
                buttonIcon: "bolt"
                text: Translation.tr("Quick Actions")
                checked: Config.options?.waffles?.widgetsPanel?.showQuickActions ?? true
                onCheckedChanged: Config.options.waffles.widgetsPanel.showQuickActions = checked
            }
        }
    }
}
