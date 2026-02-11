import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    settingsPageIndex: 7
    settingsPageName: Translation.tr("Advanced")

    SettingsCardSection {
        expanded: true
        icon: "colors"
        title: Translation.tr("Color generation")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "hardware"
                text: Translation.tr("Shell & utilities")
                checked: Config.options.appearance.wallpaperTheming.enableAppsAndShell
                onCheckedChanged: {
                    Config.options.appearance.wallpaperTheming.enableAppsAndShell = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Generate colors for GTK apps, fuzzel, and other utilities from wallpaper")
                }
            }
            SettingsSwitch {
                buttonIcon: "tv_options_input_settings"
                text: Translation.tr("Qt apps")
                checked: Config.options.appearance.wallpaperTheming.enableQtApps
                onCheckedChanged: {
                    Config.options.appearance.wallpaperTheming.enableQtApps = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Generate colors for Qt/KDE apps (requires Shell & utilities)")
                }
            }
            SettingsSwitch {
                buttonIcon: "terminal"
                text: Translation.tr("Terminal")
                checked: Config.options.appearance.wallpaperTheming.enableTerminal
                onCheckedChanged: {
                    Config.options.appearance.wallpaperTheming.enableTerminal = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Generate terminal color scheme from wallpaper (requires Shell & utilities)")
                }
            }
            SettingsSwitch {
                buttonIcon: "chat"
                text: Translation.tr("Vesktop/Discord")
                checked: Config.options.appearance.wallpaperTheming.enableVesktop
                onCheckedChanged: {
                    Config.options.appearance.wallpaperTheming.enableVesktop = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Generate Discord theme from wallpaper colors (requires Vesktop with system24 theme)")
                }
            }
            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "dark_mode"
                    text: Translation.tr("Force dark mode in terminal")
                    checked: Config.options.appearance.wallpaperTheming.terminalGenerationProps.forceDarkMode
                    onCheckedChanged: {
                         Config.options.appearance.wallpaperTheming.terminalGenerationProps.forceDarkMode= checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Always use dark background for terminal regardless of wallpaper")
                    }
                }
            }

            ConfigSpinBox {
                icon: "invert_colors"
                text: Translation.tr("Terminal: Harmony (%)")
                value: Config.options.appearance.wallpaperTheming.terminalGenerationProps.harmony * 100
                from: 0
                to: 100
                stepSize: 10
                onValueChanged: {
                    Config.options.appearance.wallpaperTheming.terminalGenerationProps.harmony = value / 100;
                }
                StyledToolTip {
                    text: Translation.tr("How much to blend terminal colors with the wallpaper palette")
                }
            }
            ConfigSpinBox {
                icon: "gradient"
                text: Translation.tr("Terminal: Harmonize threshold")
                value: Config.options.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold
                from: 0
                to: 100
                stepSize: 10
                onValueChanged: {
                    Config.options.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold = value;
                }
                StyledToolTip {
                    text: Translation.tr("Minimum color difference before harmonization is applied")
                }
            }
            ConfigSpinBox {
                icon: "format_color_text"
                text: Translation.tr("Terminal: Foreground boost (%)")
                value: Config.options.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost * 100
                from: 0
                to: 100
                stepSize: 10
                onValueChanged: {
                    Config.options.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost = value / 100;
                }
                StyledToolTip {
                    text: Translation.tr("Increase contrast of terminal foreground colors")
                }
            }
        }
    }

}
