pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 0
    pageTitle: Translation.tr("Quick Settings")
    pageIcon: "flash-on"
    pageDescription: Translation.tr("Frequently used settings and quick actions")
    
    // Wallpaper section
    WSettingsCard {
        title: Translation.tr("Wallpaper & Colors")
        icon: "image-filled"
        
        // Wallpaper preview
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            Layout.bottomMargin: 12
            
            Rectangle {
                anchors.fill: parent
                radius: Looks.radius.large
                color: Looks.colors.bg2
                clip: true
                
                Image {
                    id: wallpaperPreview
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: {
                        const useMain = Config.options?.waffles?.background?.useMainWallpaper ?? true
                        if (useMain) return Config.options?.background?.wallpaperPath ?? ""
                        return Config.options?.waffles?.background?.wallpaperPath ?? Config.options?.background?.wallpaperPath ?? ""
                    }
                    asynchronous: true
                    cache: false
                    
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: wallpaperPreview.width
                            height: wallpaperPreview.height
                            radius: Looks.radius.large
                        }
                    }
                }
                
                // Overlay buttons
                RowLayout {
                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                        margins: 12
                    }
                    spacing: 8
                    
                    WButton {
                        text: Translation.tr("Change wallpaper")
                        icon.name: "image"
                        onClicked: {
                            // Use waffle target if not sharing wallpaper with Material ii
                            const useMain = Config.options?.waffles?.background?.useMainWallpaper ?? true
                            Config.setNestedValue("wallpaperSelector.selectionTarget", useMain ? "main" : "waffle")
                            Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggle"])
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    WBorderlessButton {
                        implicitWidth: 36
                        implicitHeight: 36
                        
                        Rectangle {
                            anchors.fill: parent
                            radius: Looks.radius.medium
                            color: Appearance.m3colors.darkmode ? Looks.colors.bg2 : Looks.colors.bg1
                            opacity: 0.9
                        }
                        
                        contentItem: FluentIcon {
                            anchors.centerIn: parent
                            icon: Appearance.m3colors.darkmode ? "weather-moon" : "weather-sunny"
                            implicitSize: 18
                            color: Looks.colors.fg
                        }
                        
                        onClicked: {
                            const dark = !Appearance.m3colors.darkmode
                            Quickshell.execDetached(["fish", "-c", `${Directories.wallpaperSwitchScriptPath} --mode ${dark ? "dark" : "light"} --noswitch`])
                        }
                        
                        WToolTip {
                            visible: parent.hovered
                            text: Appearance.m3colors.darkmode ? Translation.tr("Switch to light mode") : Translation.tr("Switch to dark mode")
                        }
                    }
                }
            }
        }
        
        WSettingsDropdown {
            label: Translation.tr("Color scheme")
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
                Quickshell.execDetached(["fish", "-c", `${Directories.wallpaperSwitchScriptPath} --noswitch`])
            }
        }
        
        WSettingsSwitch {
            label: Translation.tr("Transparency")
            icon: "auto"
            description: Translation.tr("Enable transparent UI elements")
            checked: Config.options?.appearance?.transparency?.enable ?? false
            onCheckedChanged: Config.setNestedValue("appearance.transparency.enable", checked)
        }
    }
    
    // Taskbar section (waffle-specific)
    WSettingsCard {
        title: Translation.tr("Taskbar")
        icon: "desktop"
        
        WSettingsSwitch {
            label: Translation.tr("Left-align apps")
            icon: "options"
            description: Translation.tr("Align taskbar apps to the left instead of center")
            checked: Config.options?.waffles?.bar?.leftAlignApps ?? false
            onCheckedChanged: Config.setNestedValue("waffles.bar.leftAlignApps", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Tint app icons")
            icon: "dark-theme"
            description: Translation.tr("Apply accent color to taskbar icons")
            checked: Config.options?.waffles?.bar?.monochromeIcons ?? false
            onCheckedChanged: Config.setNestedValue("waffles.bar.monochromeIcons", checked)
        }
        
        WSettingsDropdown {
            label: Translation.tr("Screen rounding")
            icon: "desktop"
            description: Translation.tr("Fake rounded corners for flat screens")
            currentValue: Config.options?.appearance?.fakeScreenRounding ?? 0
            options: [
                { value: 0, displayName: Translation.tr("None") },
                { value: 1, displayName: Translation.tr("Always") },
                { value: 2, displayName: Translation.tr("When not fullscreen") }
            ]
            onSelected: newValue => Config.setNestedValue("appearance.fakeScreenRounding", newValue)
        }
    }
    
    // Quick Actions section
    WSettingsCard {
        title: Translation.tr("Quick Actions")
        icon: "flash-on"
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            WButton {
                Layout.fillWidth: true
                text: Translation.tr("Reload shell")
                icon.name: "arrow-sync"
                onClicked: Quickshell.execDetached(["fish", "-c", "qs kill -c ii; sleep 0.3; qs -c ii &"])
            }
            
            WButton {
                Layout.fillWidth: true
                text: Translation.tr("Open config")
                icon.name: "settings"
                onClicked: Qt.openUrlExternally(`${Directories.config}/illogical-impulse/config.json`)
            }
            
            WButton {
                Layout.fillWidth: true
                text: Translation.tr("Shortcuts")
                icon.name: "keyboard"
                onClicked: Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "cheatsheet", "toggle"])
            }
        }
        
        WSettingsSwitch {
            label: Translation.tr("Show reload notifications")
            icon: "alert"
            description: Translation.tr("Toast when Quickshell or Niri config reloads")
            checked: Config.options?.reloadToasts?.enable ?? true
            onCheckedChanged: Config.setNestedValue("reloadToasts.enable", checked)
        }
    }
}
