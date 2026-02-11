pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.waffle.looks
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 3
    pageTitle: Translation.tr("Background")
    pageIcon: "image"
    pageDescription: Translation.tr("Wallpaper effects and backdrop settings for Waffle")
    
    // Shorthand for waffle background config
    readonly property var wBg: Config.options?.waffles?.background ?? {}
    readonly property var wEffects: wBg.effects ?? {}
    readonly property var wBackdrop: wBg.backdrop ?? {}
    
    WSettingsCard {
        title: Translation.tr("Wallpaper")
        icon: "image"
        
        WSettingsSwitch {
            label: Translation.tr("Use Material ii wallpaper")
            icon: "image"
            description: Translation.tr("Share wallpaper with Material ii family")
            checked: root.wBg.useMainWallpaper ?? true
            onCheckedChanged: Config.setNestedValue("waffles.background.useMainWallpaper", checked)
        }
        
        WSettingsButton {
            visible: !(root.wBg.useMainWallpaper ?? true)
            label: Translation.tr("Waffle wallpaper")
            icon: "image"
            buttonText: Translation.tr("Change")
            onButtonClicked: {
                Config.setNestedValue("wallpaperSelector.selectionTarget", "waffle")
                Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggle"])
            }
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Wallpaper Effects")
        icon: "image"

        WSettingsSwitch {
            label: Translation.tr("Enable animated wallpapers (videos/GIFs)")
            icon: "play"
            description: Translation.tr("Play videos and GIFs as wallpaper. When disabled, shows thumbnail instead")
            checked: root.wBg.enableAnimation ?? true
            onCheckedChanged: Config.setNestedValue("waffles.background.enableAnimation", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Enable blur")
            icon: "eye"
            description: Translation.tr("Blur wallpaper when windows are open")
            checked: root.wEffects.enableBlur ?? false
            onCheckedChanged: Config.setNestedValue("waffles.background.effects.enableBlur", checked)
        }

        WSettingsSwitch {
            visible: root.wBg.enableAnimation ?? true
            label: Translation.tr("Blur animated wallpapers (videos/GIFs)")
            icon: "eye"
            description: Translation.tr("Apply blur to animated wallpapers. Independent from window blur. May significantly impact performance.")
            checked: root.wEffects.enableAnimatedBlur ?? false
            onCheckedChanged: Config.setNestedValue("waffles.background.effects.enableAnimatedBlur", checked)
        }

        WSettingsSpinBox {
            visible: root.wEffects.enableBlur ?? false
            label: Translation.tr("Blur radius")
            icon: "eye"
            description: Translation.tr("Amount of blur applied to wallpaper")
            from: 0; to: 100; stepSize: 5
            value: root.wEffects.blurRadius ?? 32
            onValueChanged: Config.setNestedValue("waffles.background.effects.blurRadius", value)
        }

        WSettingsSpinBox {
            visible: root.wEffects.enableAnimatedBlur ?? false
            label: Translation.tr("Animated blur strength")
            icon: "eye"
            description: Translation.tr("Blur intensity for animated wallpapers (0-100%)")
            suffix: "%"
            from: 0; to: 100; stepSize: 5
            value: root.wEffects.thumbnailBlurStrength ?? 70
            onValueChanged: Config.setNestedValue("waffles.background.effects.thumbnailBlurStrength", value)
        }
        
        WSettingsSpinBox {
            label: Translation.tr("Dim overlay")
            icon: "dark-theme"
            description: Translation.tr("Darken the wallpaper")
            suffix: "%"
            from: 0; to: 100; stepSize: 5
            value: root.wEffects.dim ?? 0
            onValueChanged: Config.setNestedValue("waffles.background.effects.dim", value)
        }
        
        WSettingsSpinBox {
            label: Translation.tr("Extra dim with windows")
            icon: "dark-theme"
            description: Translation.tr("Additional dim when windows are present")
            suffix: "%"
            from: 0; to: 100; stepSize: 5
            value: root.wEffects.dynamicDim ?? 0
            onValueChanged: Config.setNestedValue("waffles.background.effects.dynamicDim", value)
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Backdrop (Overview)")
        icon: "desktop"
        
        WSettingsSwitch {
            label: Translation.tr("Enable backdrop")
            icon: "desktop"
            description: Translation.tr("Show backdrop layer for overview")
            checked: root.wBackdrop.enable ?? true
            onCheckedChanged: Config.setNestedValue("waffles.background.backdrop.enable", checked)
        }
        
        WSettingsSwitch {
            visible: root.wBackdrop.enable ?? true
            label: Translation.tr("Enable animated wallpapers (videos/GIFs)")
            icon: "play"
            description: Translation.tr("Play videos and GIFs in backdrop (may impact performance)")
            checked: root.wBackdrop.enableAnimation ?? false
            onCheckedChanged: Config.setNestedValue("waffles.background.backdrop.enableAnimation", checked)
        }

        WSettingsSwitch {
            visible: (root.wBackdrop.enable ?? true) && (root.wBackdrop.enableAnimation ?? false)
            label: Translation.tr("Blur animated wallpapers (videos/GIFs)")
            icon: "eye"
            description: Translation.tr("Apply blur to animated wallpapers in backdrop. May significantly impact performance.")
            checked: root.wBackdrop.enableAnimatedBlur ?? false
            onCheckedChanged: Config.setNestedValue("waffles.background.backdrop.enableAnimatedBlur", checked)
        }

        WSettingsSwitch {
            visible: root.wBackdrop.enable ?? true
            label: Translation.tr("Use separate wallpaper")
            icon: "image"
            description: Translation.tr("Use a different wallpaper for backdrop")
            checked: !(root.wBackdrop.useMainWallpaper ?? true)
            onCheckedChanged: Config.setNestedValue("waffles.background.backdrop.useMainWallpaper", !checked)
        }
        
        WSettingsButton {
            visible: (root.wBackdrop.enable ?? true) && !(root.wBackdrop.useMainWallpaper ?? true)
            label: Translation.tr("Backdrop wallpaper")
            icon: "image"
            buttonText: Translation.tr("Change")
            onButtonClicked: {
                Config.setNestedValue("wallpaperSelector.selectionTarget", "waffle-backdrop")
                Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggle"])
            }
        }
        
        WSettingsSwitch {
            visible: root.wBackdrop.enable ?? true
            label: Translation.tr("Hide main wallpaper")
            icon: "eye-off"
            description: Translation.tr("Show only backdrop, hide main wallpaper")
            checked: root.wBackdrop.hideWallpaper ?? false
            onCheckedChanged: Config.setNestedValue("waffles.background.backdrop.hideWallpaper", checked)
        }
        
        WSettingsSpinBox {
            visible: root.wBackdrop.enable ?? true
            label: Translation.tr("Backdrop blur")
            icon: "eye"
            description: Translation.tr("Amount of blur for backdrop layer")
            from: 0; to: 100; stepSize: 5
            value: root.wBackdrop.blurRadius ?? 64
            onValueChanged: Config.setNestedValue("waffles.background.backdrop.blurRadius", value)
        }
        
        WSettingsSpinBox {
            visible: root.wBackdrop.enable ?? true
            label: Translation.tr("Backdrop dim")
            icon: "dark-theme"
            description: Translation.tr("Darken the backdrop layer")
            suffix: "%"
            from: 0; to: 100; stepSize: 5
            value: root.wBackdrop.dim ?? 20
            onValueChanged: Config.setNestedValue("waffles.background.backdrop.dim", value)
        }
        
        WSettingsSpinBox {
            visible: root.wBackdrop.enable ?? true
            label: Translation.tr("Backdrop saturation")
            icon: "eyedropper"
            description: Translation.tr("Increase color intensity")
            suffix: "%"
            from: -100; to: 100; stepSize: 10
            value: root.wBackdrop.saturation ?? 0
            onValueChanged: Config.setNestedValue("waffles.background.backdrop.saturation", value)
        }
        
        WSettingsSpinBox {
            visible: root.wBackdrop.enable ?? true
            label: Translation.tr("Backdrop contrast")
            icon: "auto"
            description: Translation.tr("Increase light/dark difference")
            suffix: "%"
            from: -100; to: 100; stepSize: 10
            value: root.wBackdrop.contrast ?? 0
            onValueChanged: Config.setNestedValue("waffles.background.backdrop.contrast", value)
        }
    }
}
