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
                    Config.setNestedValue("appearance.wallpaperTheming.enableAppsAndShell", checked)
                    colorRegenTimer.restart()
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
                    Config.setNestedValue("appearance.wallpaperTheming.enableQtApps", checked)
                    colorRegenTimer.restart()
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
                    Config.setNestedValue("appearance.wallpaperTheming.enableTerminal", checked)
                    colorRegenTimer.restart()
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
                    Config.setNestedValue("appearance.wallpaperTheming.enableVesktop", checked)
                    colorRegenTimer.restart()
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
                    Config.setNestedValue("appearance.wallpaperTheming.enableSpicetify", checked)
                    colorRegenTimer.restart()
                }
                StyledToolTip {
                    text: Translation.tr("Generate and apply a Spicetify theme from wallpaper colors")
                }
            }
            SettingsSwitch {
                buttonIcon: "sports_esports"
                text: Translation.tr("Steam (Adwaita for Steam)")
                checked: Config.options?.appearance?.wallpaperTheming?.enableAdwSteam ?? false
                onCheckedChanged: {
                    Config.setNestedValue("appearance.wallpaperTheming.enableAdwSteam", checked)
                    colorRegenTimer.restart()
                }
                StyledToolTip {
                    text: Translation.tr("Apply Material You colors to Steam via Adwaita for Steam (requires AdwSteamGtk)")
                }
            }
            SettingsSwitch {
                buttonIcon: "code"
                text: Translation.tr("Zed editor")
                checked: Config.options?.appearance?.wallpaperTheming?.enableZed ?? true
                onCheckedChanged: {
                    Config.setNestedValue("appearance.wallpaperTheming.enableZed", checked)
                    colorRegenTimer.restart()
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
                    Config.setNestedValue("appearance.wallpaperTheming.enableVSCode", checked)
                    colorRegenTimer.restart()
                }
                StyledToolTip {
                    text: Translation.tr("Generate theme for VSCode and its forks from wallpaper colors")
                }
            }
            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "dark_mode"
                    text: Translation.tr("Force dark mode in terminal")
                    checked: Config.options?.appearance?.wallpaperTheming?.terminalGenerationProps?.forceDarkMode ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("appearance.wallpaperTheming.terminalGenerationProps.forceDarkMode", checked)
                        colorRegenTimer.restart()
                    }
                    StyledToolTip {
                        text: Translation.tr("Always use dark background for terminal regardless of wallpaper")
                    }
                }
            }

            ConfigSpinBox {
                icon: "invert_colors"
                text: Translation.tr("Terminal: Harmony (%)")
                value: Math.round((Config.options?.appearance?.wallpaperTheming?.terminalGenerationProps?.harmony ?? 0.4) * 100)
                from: 0
                to: 100
                stepSize: 10
                onValueChanged: {
                    Config.setNestedValue("appearance.wallpaperTheming.terminalGenerationProps.harmony", value / 100)
                    colorRegenTimer.restart()
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
                    Config.setNestedValue("appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold", value)
                    colorRegenTimer.restart()
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
                    Config.setNestedValue("appearance.wallpaperTheming.terminalGenerationProps.termFgBoost", value / 100)
                    colorRegenTimer.restart()
                }
                StyledToolTip {
                    text: Translation.tr("Increase contrast of terminal foreground colors")
                }
            }

        }
    }

}
