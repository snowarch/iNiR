import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    settingsPageIndex: 25
    settingsPageName: Translation.tr("Effects")

    readonly property var backendOptions: [
        { displayName: Translation.tr("Style default"), value: "auto" },
        { displayName: Translation.tr("Wallpaper glass"), value: "wallpaper" },
        { displayName: Translation.tr("Compositor blur"), value: "compositor" },
        { displayName: Translation.tr("Off"), value: "off" }
    ]
    readonly property var areaDescriptors: [
        { key: "bar", icon: "toast", label: Translation.tr("Bars") },
        { key: "dock", icon: "dock_to_bottom", label: Translation.tr("Dock") },
        { key: "panels", icon: "side_navigation", label: Translation.tr("Panels and popups") },
        { key: "islands", icon: "blur_on", label: Translation.tr("Islands and Ricelin") },
        { key: "widgets", icon: "widgets", label: Translation.tr("Desktop widgets") }
    ]

    SettingsCardSection {
        expanded: true
        icon: "blur_on"
        title: Translation.tr("Blur and glass")
        SettingsGroup {
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.spacingMedium
                MaterialSymbol { text: "auto_awesome"; iconSize: Appearance.font.pixelSize.larger }
                StyledText { Layout.fillWidth: true; text: Translation.tr("Default blur backend") }
                StyledComboBox {
                    Layout.preferredWidth: 210
                    model: root.backendOptions
                    textRole: "displayName"
                    currentIndex: Math.max(0, root.backendOptions.findIndex(o => o.value === (Config.options?.performance?.blurBackend ?? "auto")))
                    onActivated: index => Config.setNestedValue("performance.blurBackend", root.backendOptions[index].value)
                }
            }
            SettingsSwitch {
                visible: Appearance.nativeBlurSupported
                buttonIcon: "blur_on"
                text: Translation.tr("Allow compositor blur")
                checked: Config.options?.performance?.compositorBlur ?? true
                onCheckedChanged: Config.setNestedValue("performance.compositorBlur", checked)
            }
        }
    }

    SettingsCardSection {
        expanded: true
        icon: "tune"
        title: Translation.tr("Per-area overrides")
        SettingsGroup {
            Repeater {
                model: root.areaDescriptors
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Appearance.sizes.spacingMedium
                    MaterialSymbol { text: modelData.icon; iconSize: Appearance.font.pixelSize.larger }
                    StyledText { Layout.fillWidth: true; text: modelData.label }
                    StyledComboBox {
                        Layout.preferredWidth: 210
                        readonly property var options: [{ displayName: Translation.tr("Inherit"), value: "inherit" }].concat(root.backendOptions)
                        model: options
                        textRole: "displayName"
                        currentIndex: Math.max(0, options.findIndex(o => o.value === (Config.options?.performance?.blurAreas?.[modelData.key] ?? "inherit")))
                        onActivated: index => Config.setNestedValue("performance.blurAreas." + modelData.key, options[index].value)
                    }
                }
            }
        }
    }

    SettingsCardSection {
        expanded: true
        icon: "animation"
        title: Translation.tr("Motion and power")
        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "animation"
                text: Translation.tr("Reduce animations")
                checked: Config.options?.performance?.reduceAnimations ?? false
                onCheckedChanged: Config.setNestedValue("performance.reduceAnimations", checked)
            }
            SettingsSwitch {
                buttonIcon: "energy_savings_leaf"
                text: Translation.tr("Low power effects")
                checked: Config.options?.performance?.lowPower ?? false
                onCheckedChanged: Config.setNestedValue("performance.lowPower", checked)
            }
            SettingsSwitch {
                buttonIcon: "memory"
                text: Translation.tr("Notify when a restart would free memory")
                checked: Config.options?.performance?.memoryWarningNotification ?? false
                onCheckedChanged: Config.setNestedValue("performance.memoryWarningNotification", checked)
            }
        }
    }
}
