pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import qs.modules.common
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 16
    pageTitle: Translation.tr("Effects")
    pageIcon: "eye"
    pageDescription: Translation.tr("Blur, glass, motion and rendering policy")

    readonly property var backendOptions: [
        { displayName: Translation.tr("Style default"), value: "auto" },
        { displayName: Translation.tr("Wallpaper glass"), value: "wallpaper" },
        { displayName: Translation.tr("Compositor blur"), value: "compositor" },
        { displayName: Translation.tr("Off"), value: "off" }
    ]
    readonly property var areaDescriptors: [
        { key: "bar", icon: "desktop", label: Translation.tr("Bars") },
        { key: "dock", icon: "apps", label: Translation.tr("Dock") },
        { key: "panels", icon: "apps", label: Translation.tr("Panels and popups") },
        { key: "islands", icon: "paint-bucket", label: Translation.tr("Islands and Ricelin") },
        { key: "widgets", icon: "apps", label: Translation.tr("Desktop widgets") }
    ]

    WSettingsCard {
        title: Translation.tr("Blur and glass")
        icon: "eye"
        WSettingsDropdown {
            label: Translation.tr("Default blur backend")
            icon: "eye"
            currentValue: Config.options?.performance?.blurBackend ?? "auto"
            options: root.backendOptions
            onSelected: value => Config.setNestedValue("performance.blurBackend", value)
        }
        WSettingsSwitch {
            visible: Appearance.nativeBlurSupported
            label: Translation.tr("Allow compositor blur")
            icon: "eye"
            checked: Config.options?.performance?.compositorBlur ?? true
            onCheckedChanged: Config.setNestedValue("performance.compositorBlur", checked)
        }
    }

    WSettingsCard {
        title: Translation.tr("Per-area overrides")
        icon: "settings-cog-multiple"
        Repeater {
            model: root.areaDescriptors
            delegate: WSettingsDropdown {
                required property var modelData
                label: modelData.label
                icon: modelData.icon
                currentValue: Config.options?.performance?.blurAreas?.[modelData.key] ?? "inherit"
                options: [{ displayName: Translation.tr("Inherit"), value: "inherit" }].concat(root.backendOptions)
                onSelected: value => Config.setNestedValue("performance.blurAreas." + modelData.key, value)
            }
        }
    }

    WSettingsCard {
        title: Translation.tr("Motion and power")
        icon: "settings-cog-multiple"
        WSettingsSwitch {
            label: Translation.tr("Reduce animations")
            icon: "eye-off"
            checked: Config.options?.performance?.reduceAnimations ?? false
            onCheckedChanged: Config.setNestedValue("performance.reduceAnimations", checked)
        }
        WSettingsSwitch {
            label: Translation.tr("Low power effects")
            icon: "eye-off"
            checked: Config.options?.performance?.lowPower ?? false
            onCheckedChanged: Config.setNestedValue("performance.lowPower", checked)
        }
        WSettingsSwitch {
            label: Translation.tr("Notify when a restart would free memory")
            icon: "alert"
            checked: Config.options?.performance?.memoryWarningNotification ?? false
            onCheckedChanged: Config.setNestedValue("performance.memoryWarningNotification", checked)
        }
    }
}
