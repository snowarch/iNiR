pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 4
    pageTitle: Translation.tr("Themes")
    pageIcon: "dark-theme"
    pageDescription: Translation.tr("Color themes and typography")
    
    WSettingsCard {
        title: Translation.tr("Color Theme")
        icon: "dark-theme"
        
        WText {
            Layout.fillWidth: true
            text: Translation.tr("Current theme: %1").arg(ThemePresets.getPreset(ThemeService.currentTheme).name)
            font.pixelSize: Looks.font.pixelSize.normal
            color: Looks.colors.subfg
        }

        // Theme grid
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
                model: ThemePresets.presets

                Rectangle {
                    id: themeCard
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    radius: Looks.radius.large
                    color: ThemeService.currentTheme === modelData.id
                        ? Looks.colors.accent
                        : (themeMouseArea.containsMouse ? Looks.colors.bg2Hover : Looks.colors.bg2)
                    border.width: ThemeService.currentTheme === modelData.id ? 2 : 1
                    border.color: ThemeService.currentTheme === modelData.id
                        ? Looks.colors.accent
                        : Looks.colors.bg2Border

                    MouseArea {
                        id: themeMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ThemeService.setTheme(themeCard.modelData.id)
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        // Color preview dots
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 4

                            Rectangle {
                                width: 16; height: 16
                                radius: 8
                                color: themeCard.modelData.colors?.m3primary ?? Looks.colors.accent
                            }
                            Rectangle {
                                width: 16; height: 16
                                radius: 8
                                color: themeCard.modelData.colors?.m3secondary ?? Looks.colors.bg2
                            }
                            Rectangle {
                                width: 16; height: 16
                                radius: 8
                                color: themeCard.modelData.colors?.m3tertiary ?? Looks.colors.bg1
                            }
                        }

                        WText {
                            Layout.alignment: Qt.AlignHCenter
                            text: themeCard.modelData.name
                            font.pixelSize: Looks.font.pixelSize.small
                            font.weight: ThemeService.currentTheme === themeCard.modelData.id
                                ? Looks.font.weight.regular
                                : Looks.font.weight.thin
                            color: ThemeService.currentTheme === themeCard.modelData.id
                                ? Looks.colors.accentFg
                                : Looks.colors.fg
                        }
                    }
                }
            }
        }
    }

    WSettingsCard {
        title: Translation.tr("Global Style")
        icon: "palette"

        id: globalStyleCard

        readonly property bool cardsEverywhere: (Config.options?.dock?.cardStyle ?? false) && (Config.options?.sidebar?.cardStyle ?? false) && (Config.options?.bar?.cornerStyle === 3)

        readonly property string derivedStyle: cardsEverywhere ? "cards" : "material"
        readonly property string currentStyle: (Config.options?.appearance?.globalStyle && Config.options.appearance.globalStyle.length > 0)
            ? Config.options.appearance.globalStyle
            : derivedStyle

        function _applyGlobalStyle(styleId) {
            console.log("[GlobalStyle] apply", styleId)
            if (styleId === "cards") {
                Config.setNestedValue("dock.cardStyle", true)
                Config.setNestedValue("sidebar.cardStyle", true)
                Config.setNestedValue("bar.cornerStyle", 3)
                Config.setNestedValue("appearance.transparency.enable", false)
                return;
            }

            if (styleId === "aurora") {
                Config.setNestedValue("dock.cardStyle", false)
                Config.setNestedValue("sidebar.cardStyle", false)
                if ((Config.options?.bar?.cornerStyle ?? 1) === 3) Config.setNestedValue("bar.cornerStyle", 1)
                Config.setNestedValue("appearance.transparency.enable", true)
                return;
            }

            // material
            Config.setNestedValue("dock.cardStyle", false)
            Config.setNestedValue("sidebar.cardStyle", false)
            if ((Config.options?.bar?.cornerStyle ?? 1) === 3) Config.setNestedValue("bar.cornerStyle", 1)
            Config.setNestedValue("appearance.transparency.enable", false)
        }

        WSettingsDropdown {
            label: Translation.tr("Style")
            icon: "options"
            description: Translation.tr("Choose between Material, Cards, and Aurora global styling")
            currentValue: globalStyleCard.currentStyle
            options: [
                { value: "material", displayName: Translation.tr("Material") },
                { value: "cards", displayName: Translation.tr("Cards") },
                { value: "aurora", displayName: Translation.tr("Aurora") }
            ]
            onSelected: newValue => {
                console.log("[GlobalStyle] selected", newValue)
                Config.setNestedValue("appearance.globalStyle", newValue)
                globalStyleCard._applyGlobalStyle(newValue)
            }
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Dark Mode")
        icon: "weather-moon"
        
        WSettingsDropdown {
            label: Translation.tr("Appearance")
            icon: "weather-moon"
            description: Translation.tr("Light or dark color scheme")
            currentValue: Appearance.m3colors.darkmode ? "dark" : "light"
            options: [
                { value: "light", displayName: Translation.tr("Light") },
                { value: "dark", displayName: Translation.tr("Dark") }
            ]
            onSelected: newValue => {
                const dark = newValue === "dark"
                ShellExec.execCmd(`${Directories.wallpaperSwitchScriptPath} --mode ${dark ? "dark" : "light"} --noswitch`)
            }
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Color Scheme")
        icon: "dark-theme"
        
        WSettingsDropdown {
            label: Translation.tr("Palette type")
            icon: "dark-theme"
            description: Translation.tr("How colors are generated from wallpaper")
            currentValue: Config.options?.appearance?.palette?.type ?? "auto"
            options: [
                { value: "auto", displayName: Translation.tr("Auto") },
                { value: "scheme-content", displayName: Translation.tr("Content") },
                { value: "scheme-expressive", displayName: Translation.tr("Expressive") },
                { value: "scheme-fidelity", displayName: Translation.tr("Fidelity") },
                { value: "scheme-fruit-salad", displayName: Translation.tr("Fruit Salad") },
                { value: "scheme-monochrome", displayName: Translation.tr("Monochrome") },
                { value: "scheme-neutral", displayName: Translation.tr("Neutral") },
                { value: "scheme-rainbow", displayName: Translation.tr("Rainbow") },
                { value: "scheme-tonal-spot", displayName: Translation.tr("Tonal Spot") }
            ]
            onSelected: newValue => {
                Config.setNestedValue("appearance.palette.type", newValue)
                ShellExec.execCmd(`${Directories.wallpaperSwitchScriptPath} --noswitch`)
            }
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Waffle Typography")
        icon: "options"
        
        WText {
            Layout.fillWidth: true
            text: Translation.tr("These settings only affect the Windows 11 (Waffle) style panels.")
            font.pixelSize: Looks.font.pixelSize.small
            color: Looks.colors.subfg
            wrapMode: Text.WordWrap
        }
        
        WSettingsDropdown {
            label: Translation.tr("Font family")
            icon: "options"
            description: Translation.tr("Font used in Waffle panels")
            currentValue: Config.options?.waffles?.theming?.font?.family ?? "Noto Sans"
            options: [
                { value: "Segoe UI Variable", displayName: "Segoe UI" },
                { value: "Inter", displayName: "Inter" },
                { value: "Roboto", displayName: "Roboto" },
                { value: "Noto Sans", displayName: "Noto Sans" },
                { value: "Ubuntu", displayName: "Ubuntu" }
            ]
            onSelected: newValue => Config.setNestedValue("waffles.theming.font.family", newValue)
        }
        
        WSettingsSpinBox {
            label: Translation.tr("Font scale")
            icon: "options"
            description: Translation.tr("Scale all text in Waffle panels")
            suffix: "%"
            from: 80; to: 150; stepSize: 5
            value: Math.round((Config.options?.waffles?.theming?.font?.scale ?? 1.0) * 100)
            onValueChanged: Config.setNestedValue("waffles.theming.font.scale", value / 100.0)
        }
    }
}
