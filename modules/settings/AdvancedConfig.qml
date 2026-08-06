import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    id: root
    settingsPageIndex: 8
    settingsPageName: Translation.tr("Advanced")

    property bool cavaControlsReady: false
    Component.onCompleted: Qt.callLater(() => root.cavaControlsReady = true)

    function setCavaValue(path, value, regenerateStandalone): void {
        if (!root.cavaControlsReady)
            return
        Config.setNestedValue(path, value)
        if (regenerateStandalone)
            colorRegenTimer.restart()
    }

    function resetCavaDefaults(): void {
        if (!root.cavaControlsReady)
            return
        Config.setNestedValues({
            "appearance.cava.colorSource": "theme",
            "appearance.cava.gradientCount": 8,
            "appearance.cava.sensitivity": 100,
            "appearance.cava.bars": 0,
            "appearance.cava.framerate": 60,
            "appearance.cava.stereo": true,
            "appearance.cava.waveOpacity": 30,
        })
        colorRegenTimer.restart()
    }

    Timer {
        id: colorRegenTimer
        interval: 500  // Reduced for faster terminal color previews
        onTriggered: Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch"])
    }

    SettingsCardSection {
        expanded: true
        icon: "colors"
        title: Translation.tr("Color generation")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "hardware"
                text: Translation.tr("Shell & utilities")
                checked: Config.options?.appearance?.wallpaperTheming?.enableAppsAndShell ?? true
                onCheckedChanged: {
                    Config.setNestedValue("appearance.wallpaperTheming.enableAppsAndShell", checked);
                    colorRegenTimer.restart();
                }
                StyledToolTip {
                    text: Translation.tr("Generate colors for GTK apps, fuzzel, and other utilities from wallpaper")
                }
            }
            SettingsSwitch {
                buttonIcon: "tv_options_input_settings"
                text: Translation.tr("Qt apps")
                checked: Config.options?.appearance?.wallpaperTheming?.enableQtApps ?? true
                onCheckedChanged: {
                    Config.setNestedValue("appearance.wallpaperTheming.enableQtApps", checked);
                    colorRegenTimer.restart();
                }
                StyledToolTip {
                    text: Translation.tr("Generate colors for Qt/KDE apps (requires Shell & utilities)")
                }
            }
            SettingsSwitch {
                buttonIcon: "terminal"
                text: Translation.tr("Terminal")
                checked: Config.options?.appearance?.wallpaperTheming?.enableTerminal ?? true
                onCheckedChanged: {
                    Config.setNestedValue("appearance.wallpaperTheming.enableTerminal", checked);
                    colorRegenTimer.restart();
                }
                StyledToolTip {
                    text: Translation.tr("Generate terminal color scheme from wallpaper (requires Shell & utilities)")
                }
            }
            SettingsSwitch {
                buttonIcon: "chat"
                text: Translation.tr("Vesktop/Discord")
                checked: Config.options?.appearance?.wallpaperTheming?.enableVesktop ?? true
                onCheckedChanged: {
                    Config.setNestedValue("appearance.wallpaperTheming.enableVesktop", checked);
                    colorRegenTimer.restart();
                }
                StyledToolTip {
                    text: Translation.tr("Generate Discord theme from wallpaper colors (requires Vesktop with system24 theme)")
                }
            }
            SettingsSwitch {
                buttonIcon: "music_note"
                text: Translation.tr("Spotify (Spicetify)")
                checked: Config.options?.appearance?.wallpaperTheming?.enableSpicetify ?? false
                onCheckedChanged: {
                    Config.setNestedValue("appearance.wallpaperTheming.enableSpicetify", checked);
                    colorRegenTimer.restart();
                }
                StyledToolTip {
                    text: Translation.tr("Generate and apply a Spicetify theme from wallpaper colors")
                }
            }
            SettingsSwitch {
                buttonIcon: "sports_esports"
                text: Translation.tr("Steam (Millennium)")
                checked: Config.options?.appearance?.wallpaperTheming?.enableSteam ?? false
                onCheckedChanged: {
                    Config.setNestedValue("appearance.wallpaperTheming.enableSteam", checked);
                    colorRegenTimer.restart();
                }
                StyledToolTip {
                    text: Translation.tr("Apply Material You colors to Steam via Millennium Material-Theme")
                }
            }
            SettingsSwitch {
                buttonIcon: "music_note"
                text: Translation.tr("Pear Desktop (YouTube Music)")
                checked: Config.options?.appearance?.wallpaperTheming?.enablePearDesktop ?? true
                onCheckedChanged: {
                    Config.setNestedValue("appearance.wallpaperTheming.enablePearDesktop", checked);
                    colorRegenTimer.restart();
                }
                StyledToolTip {
                    text: Translation.tr("Apply Material You colors to YouTube Music Desktop App")
                }
            }
            SettingsSwitch {
                buttonIcon: "code"
                text: Translation.tr("Zed editor")
                checked: Config.options?.appearance?.wallpaperTheming?.enableZed ?? true
                onCheckedChanged: {
                    Config.setNestedValue("appearance.wallpaperTheming.enableZed", checked);
                    colorRegenTimer.restart();
                }
                StyledToolTip {
                    text: Translation.tr("Generate Zed editor theme from wallpaper colors")
                }
            }
            SettingsSwitch {
                buttonIcon: "code"
                text: Translation.tr("VSCode editors")
                checked: Config.options?.appearance?.wallpaperTheming?.enableVSCode ?? true
                onCheckedChanged: {
                    Config.setNestedValue("appearance.wallpaperTheming.enableVSCode", checked);
                    colorRegenTimer.restart();
                }
                StyledToolTip {
                    text: Translation.tr("Generate theme for VSCode and its forks from wallpaper colors")
                }
            }
            SettingsSwitch {
                buttonIcon: "language"
                text: Translation.tr("Chrome / Chromium")
                checked: Config.options?.appearance?.wallpaperTheming?.enableChrome ?? true
                onCheckedChanged: {
                    Config.setNestedValue("appearance.wallpaperTheming.enableChrome", checked);
                    colorRegenTimer.restart();
                }
                StyledToolTip {
                    text: Translation.tr("Apply wallpaper-derived colors to Chrome and Chromium browser")
                }
            }
            SettingsSwitch {
                buttonIcon: "code"
                text: Translation.tr("OpenCode")
                checked: Config.options?.appearance?.wallpaperTheming?.enableOpenCode ?? false
                onCheckedChanged: {
                    Config.setNestedValue("appearance.wallpaperTheming.enableOpenCode", checked);
                    colorRegenTimer.restart();
                }
                StyledToolTip {
                    text: Translation.tr("Apply wallpaper-derived theme to OpenCode AI editor")
                }
            }
            SettingsSwitch {
                buttonIcon: "code"
                text: Translation.tr("Neovim / LazyVim")
                checked: Config.options?.appearance?.wallpaperTheming?.enableNeovim ?? false
                onCheckedChanged: {
                    Config.setNestedValue("appearance.wallpaperTheming.enableNeovim", checked);
                    colorRegenTimer.restart();
                }
                StyledToolTip {
                    text: Translation.tr("Generate aether.nvim theme plugin for Neovim/LazyVim from wallpaper colors (writes to ~/.config/nvim/lua/plugins/neovim.lua)")
                }
            }
            SettingsSwitch {
                id: cavaSwitch
                buttonIcon: "equalizer"
                text: Translation.tr("Theme standalone Cava")
                checked: Config.options?.appearance?.wallpaperTheming?.enableCava ?? false
                onCheckedChanged: root.setCavaValue(
                    "appearance.wallpaperTheming.enableCava", checked, true)
                StyledToolTip {
                    text: Translation.tr("Manage the external ~/.config/cava/config block. Internal iNiR visualizers use the options below whether this switch is on or off.")
                }
            }

            ContentSubsection {
                title: Translation.tr("Cava & spectrum options")

                ConfigSelectionArray {
                    currentValue: Config.options?.appearance?.cava?.colorSource ?? "theme"
                    onSelected: newValue => root.setCavaValue(
                        "appearance.cava.colorSource", newValue, true)
                    options: [
                        { displayName: Translation.tr("Theme palette"), value: "theme" },
                        { displayName: Translation.tr("Vibrant (saturated)"), value: "vibrant" },
                        { displayName: Translation.tr("Album cover"), value: "cover" },
                    ]
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Repeater {
                        model: CavaTheme.visualizerColors

                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 8
                            radius: height / 2
                            color: modelData
                        }
                    }
                }

                SettingsNote {
                    icon: (Config.options?.appearance?.cava?.colorSource ?? "theme") === "cover"
                        ? "album" : "palette"
                    text: {
                        const source = Config.options?.appearance?.cava?.colorSource ?? "theme"
                        if (source === "vibrant")
                            return Translation.tr("Internal visualizers use a higher-saturation palette with wider hue separation. Standalone cava is regenerated too.")
                        if (source === "cover")
                            return CavaTheme.coverPaletteAvailable
                                ? Translation.tr("Using colors extracted live from the active album artwork.")
                                : Translation.tr("Waiting for active album artwork; the theme palette is used as a safe fallback.")
                        return Translation.tr("Internal visualizers use the current primary, secondary and tertiary theme colors.")
                    }
                }

                ConfigSpinBox {
                    icon: "gradient"
                    text: Translation.tr("Gradient colors")
                    value: Config.options?.appearance?.cava?.gradientCount ?? 8
                    from: 1
                    to: 8
                    onValueChanged: root.setCavaValue(
                        "appearance.cava.gradientCount", value, true)
                    StyledToolTip {
                        text: Translation.tr("Use one color for a solid spectrum, or up to eight gradient stops")
                    }
                }

                ConfigSpinBox {
                    icon: "hearing"
                    text: Translation.tr("Sensitivity")
                    value: Config.options?.appearance?.cava?.sensitivity ?? 100
                    from: 1
                    to: 500
                    stepSize: 10
                    onValueChanged: root.setCavaValue(
                        "appearance.cava.sensitivity", value, true)
                    StyledToolTip {
                        text: Translation.tr("Audio sensitivity (higher = more reactive)")
                    }
                }
                ConfigSpinBox {
                    icon: "bar_chart"
                    text: Translation.tr("Bars")
                    value: Config.options?.appearance?.cava?.bars ?? 0
                    from: 0
                    to: 200
                    stepSize: 8
                    onValueChanged: root.setCavaValue(
                        "appearance.cava.bars", value, true)
                    StyledToolTip {
                        text: Translation.tr("Number of frequency data points (0 = auto)")
                    }
                }
                ConfigSpinBox {
                    icon: "speed"
                    text: Translation.tr("Framerate")
                    value: Config.options?.appearance?.cava?.framerate ?? 60
                    from: 30
                    to: 165
                    stepSize: 5
                    onValueChanged: root.setCavaValue(
                        "appearance.cava.framerate", value, true)
                    StyledToolTip {
                        text: Translation.tr("Target refresh rate for the visualizer")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "headphones"
                    text: Translation.tr("Standalone stereo")
                    checked: Config.options?.appearance?.cava?.stereo ?? true
                    onCheckedChanged: root.setCavaValue(
                        "appearance.cava.stereo", checked, true)
                    StyledToolTip {
                        text: Translation.tr("Only affects terminal Cava. The internal bar spectrum stays mono so it always fills the whole surface.")
                    }
                }
                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Wave opacity")
                    value: Config.options?.appearance?.cava?.waveOpacity ?? 30
                    from: 5
                    to: 100
                    stepSize: 5
                    onValueChanged: root.setCavaValue(
                        "appearance.cava.waveOpacity", value, false)
                    StyledToolTip {
                        text: Translation.tr("Default fill opacity for shared wave visualizers. The bar spectrum has its own opacity control.")
                    }
                }

                RippleButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: root.resetCavaDefaults()
                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 5
                        MaterialSymbol { text: "restart_alt"; iconSize: 15; color: Appearance.colors.colOnLayer1 }
                        StyledText { text: Translation.tr("Reset to defaults"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer1 }
                    }
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "dark_mode"
                    text: Translation.tr("Force dark mode in terminal")
                    checked: Config.options?.appearance?.wallpaperTheming?.terminalGenerationProps?.forceDarkMode ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("appearance.wallpaperTheming.terminalGenerationProps.forceDarkMode", checked);
                        colorRegenTimer.restart();
                    }
                    StyledToolTip {
                        text: Translation.tr("Always use dark background for terminal regardless of wallpaper")
                    }
                }
            }

            ConfigSpinBox {
                icon: "invert_colors"
                text: Translation.tr("Terminal: Harmony (%)")
                value: Math.round(((Config.options?.appearance?.wallpaperTheming?.terminalColorAdjustments?.harmony ?? Config.options?.appearance?.wallpaperTheming?.terminalGenerationProps?.harmony ?? 0.4) * 100))
                from: 0
                to: 100
                stepSize: 10
                onValueChanged: {
                    const nextValue = value / 100;
                    // Keep both keys in sync: terminalColorAdjustments is the active runtime source,
                    // terminalGenerationProps is retained for backwards-compatibility surfaces.
                    Config.setNestedValue("appearance.wallpaperTheming.terminalColorAdjustments.harmony", nextValue);
                    Config.setNestedValue("appearance.wallpaperTheming.terminalGenerationProps.harmony", nextValue);
                    colorRegenTimer.restart();
                }
                StyledToolTip {
                    text: Translation.tr("How much to blend terminal colors with the wallpaper palette")
                }
            }
            ConfigSpinBox {
                icon: "gradient"
                text: Translation.tr("Terminal: Harmonize threshold")
                value: Config.options?.appearance?.wallpaperTheming?.terminalGenerationProps?.harmonizeThreshold ?? 100
                from: 0
                to: 100
                stepSize: 10
                onValueChanged: {
                    Config.setNestedValue("appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold", value);
                    colorRegenTimer.restart();
                }
                StyledToolTip {
                    text: Translation.tr("Minimum color difference before harmonization is applied")
                }
            }
            ConfigSpinBox {
                icon: "format_color_text"
                text: Translation.tr("Terminal: Foreground boost (%)")
                value: Math.round((Config.options?.appearance?.wallpaperTheming?.terminalGenerationProps?.termFgBoost ?? 0) * 100)
                from: 0
                to: 100
                stepSize: 10
                onValueChanged: {
                    Config.setNestedValue("appearance.wallpaperTheming.terminalGenerationProps.termFgBoost", value / 100);
                    colorRegenTimer.restart();
                }
                StyledToolTip {
                    text: Translation.tr("Increase terminal ANSI foreground lightness/contrast (use moderate values to avoid washed colors)")
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "memory_alt"
        title: Translation.tr("Resource Monitor")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "memory_alt"
                text: Translation.tr("GPU monitoring")
                checked: Config.options?.resources?.monitorGpu ?? true
                onCheckedChanged: {
                    Config.setNestedValue("resources.monitorGpu", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Poll GPU usage and temperature. Disable on hybrid laptops to keep the dGPU asleep — also pins Qt to the iGPU on next restart.")
                }
            }
        }
    }
}
