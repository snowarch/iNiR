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
    settingsPageIndex: 9
    pageTitle: Translation.tr("About")
    pageIcon: "info"
    pageDescription: Translation.tr("Information about ii-niri")
    
    WSettingsCard {
        // Logo and title
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            
            Rectangle {
                implicitWidth: 64
                implicitHeight: 64
                radius: Looks.radius.large
                color: Looks.colors.accent
                
                WText {
                    anchors.centerIn: parent
                    text: "ii"
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    color: Looks.colors.accentFg
                }
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                
                WText {
                    text: "illogical-impulse"
                    font.pixelSize: Looks.font.pixelSize.larger + 2
                    font.weight: Looks.font.weight.strong
                }
                
                WText {
                    text: Translation.tr("Quickshell desktop shell for Niri")
                    font.pixelSize: Looks.font.pixelSize.normal
                    color: Looks.colors.subfg
                }
            }
        }
        
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Looks.colors.bg2Border
        }
        
        WSettingsRow {
            label: Translation.tr("Version")
            description: "2.0.0-niri"
        }
        
        WSettingsRow {
            label: Translation.tr("Framework")
            description: "Quickshell + Qt 6"
        }
        
        WSettingsRow {
            label: Translation.tr("Compositor")
            description: CompositorService.isNiri ? "Niri" : (CompositorService.isHyprland ? "Hyprland" : "Unknown")
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Links")
        icon: "open"
        
        WSettingsButton {
            label: Translation.tr("GitHub Repository")
            icon: "open"
            buttonText: Translation.tr("Open")
            onButtonClicked: Qt.openUrlExternally("https://github.com/snowarch/quickshell-ii-niri")
        }
        
        WSettingsButton {
            label: Translation.tr("Original Project (end-4)")
            icon: "open"
            buttonText: Translation.tr("Open")
            onButtonClicked: Qt.openUrlExternally("https://github.com/end-4/dots-hyprland")
        }
        
        WSettingsButton {
            label: Translation.tr("Quickshell Documentation")
            icon: "open"
            buttonText: Translation.tr("Open")
            onButtonClicked: Qt.openUrlExternally("https://quickshell.outfoxxed.me")
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Credits")
        icon: "people-filled"
        
        WText {
            Layout.fillWidth: true
            text: Translation.tr("Based on illogical-impulse by end-4, adapted for Niri compositor.")
            wrapMode: Text.WordWrap
            color: Looks.colors.subfg
        }
        
        WText {
            Layout.fillWidth: true
            Layout.topMargin: 8
            text: Translation.tr("Special thanks to the Quickshell and Niri communities.")
            wrapMode: Text.WordWrap
            color: Looks.colors.subfg
        }
    }
    
    WSettingsCard {
        title: Translation.tr("System Info")
        icon: "desktop-filled"
        
        WSettingsRow {
            label: Translation.tr("Config path")
            description: FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/`)
        }
        
        WSettingsRow {
            label: Translation.tr("Shell path")
            description: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/ii/`)
        }
        
        WSettingsRow {
            label: Translation.tr("Panel family")
            description: Config.options?.panelFamily === "waffle" ? "Waffle (Windows 11)" : "ii (Material)"
        }
    }
}
