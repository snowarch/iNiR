import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    settingsPageIndex: 8
    settingsPageName: Translation.tr("Advanced")

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
                text: Translation.tr("Cava")
                checked: Config.options?.appearance?.wallpaperTheming?.enableCava ?? false
                onCheckedChanged: {
                    Config.setNestedValue("appearance.wallpaperTheming.enableCava", checked);
                    colorRegenTimer.restart();
                }
                StyledToolTip {
                    text: Translation.tr("Apply Material You gradient colors to cava audio visualizer config")
                }
            }

            ContentSubsection {
                visible: cavaSwitch.checked
                title: Translation.tr("Cava options")

                ConfigSelectionArray {
                    currentValue: Config.options?.appearance?.cava?.colorSource ?? "theme"
                    onSelected: newValue => {
                        Config.setNestedValue("appearance.cava.colorSource", newValue);
                        colorRegenTimer.restart();
                    }
                    options: [
                        { displayName: Translation.tr("Theme palette"), value: "theme" },
                        { displayName: Translation.tr("Vibrant (saturated)"), value: "vibrant" },
                        { displayName: Translation.tr("Album cover"), value: "cover" }
                    ]
                }

                ConfigSpinBox {
                    icon: "gradient"
                    text: Translation.tr("Gradient colors")
                    value: Config.options?.appearance?.cava?.gradientCount ?? 8
                    from: 2
                    to: 8
                    onValueChanged: {
                        Config.setNestedValue("appearance.cava.gradientCount", value);
                        colorRegenTimer.restart();
                    }
                    StyledToolTip {
                        text: Translation.tr("Number of gradient stops in the visualizer (2-8)")
                    }
                }
                ConfigSpinBox {
                    icon: "hearing"
                    text: Translation.tr("Sensitivity")
                    value: Config.options?.appearance?.cava?.sensitivity ?? 100
                    from: 1
                    to: 500
                    stepSize: 10
                    onValueChanged: {
                        Config.setNestedValue("appearance.cava.sensitivity", value);
                    }
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
                    onValueChanged: {
                        Config.setNestedValue("appearance.cava.bars", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Number of bars (0 = auto based on terminal width)")
                    }
                }
                ConfigSpinBox {
                    icon: "speed"
                    text: Translation.tr("Framerate")
                    value: Config.options?.appearance?.cava?.framerate ?? 60
                    from: 30
                    to: 165
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("appearance.cava.framerate", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Target refresh rate for the visualizer")
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSpinBox {
                        icon: "width"
                        text: Translation.tr("Bar width")
                        value: Config.options?.appearance?.cava?.barWidth ?? 2
                        from: 1
                        to: 20
                        onValueChanged: {
                            Config.setNestedValue("appearance.cava.barWidth", value);
                        }
                    }
                    ConfigSpinBox {
                        icon: "space_bar"
                        text: Translation.tr("Bar spacing")
                        value: Config.options?.appearance?.cava?.barSpacing ?? 1
                        from: 0
                        to: 10
                        onValueChanged: {
                            Config.setNestedValue("appearance.cava.barSpacing", value);
                        }
                    }
                }
                SettingsSwitch {
                    buttonIcon: "headphones"
                    text: Translation.tr("Stereo")
                    checked: Config.options?.appearance?.cava?.stereo ?? true
                    onCheckedChanged: {
                        Config.setNestedValue("appearance.cava.stereo", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Split visualizer into left/right channels")
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
        expanded: true
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
