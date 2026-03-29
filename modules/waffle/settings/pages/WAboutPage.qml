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
    pageDescription: Translation.tr("Project information and links")
    
    // Hero card — project identity
    WSettingsCard {
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            Layout.topMargin: 8
            Layout.bottomMargin: 4
            spacing: 18
            
            Rectangle {
                implicitWidth: 72
                implicitHeight: 72
                radius: Looks.radius.xLarge
                color: Looks.colors.accent
                
                WText {
                    anchors.centerIn: parent
                    text: "iN"
                    font.pixelSize: 30
                    font.weight: Font.Bold
                    color: Looks.colors.accentFg
                }
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                
                WText {
                    text: "iNiR"
                    font.pixelSize: Looks.font.pixelSize.xlarger * 1.4
                    font.weight: Looks.font.weight.stronger
                }
                
                WText {
                    text: Translation.tr("Quickshell desktop shell for Niri")
                    font.pixelSize: Looks.font.pixelSize.normal
                    color: Looks.colors.subfg
                }
                
                RowLayout {
                    spacing: 8
                    Layout.topMargin: 4
                    
                    // Version badge
                    Rectangle {
                        implicitWidth: versionLabel.implicitWidth + 16
                        implicitHeight: 24
                        radius: Looks.radius.small
                        color: Looks.colors.accent
                        
                        WText {
                            id: versionLabel
                            anchors.centerIn: parent
                            text: "v" + (ShellUpdates.localVersion || "?")
                            font.pixelSize: Looks.font.pixelSize.small
                            font.weight: Looks.font.weight.strong
                            color: Looks.colors.accentFg
                        }
                    }
                    
                    // Compositor badge
                    Rectangle {
                        implicitWidth: compLabel.implicitWidth + 16
                        implicitHeight: 24
                        radius: Looks.radius.small
                        color: Looks.colors.bg2
                        
                        WText {
                            id: compLabel
                            anchors.centerIn: parent
                            text: CompositorService.isNiri ? "Niri" : (CompositorService.isHyprland ? "Hyprland" : "Unknown")
                            font.pixelSize: Looks.font.pixelSize.small
                            color: Looks.colors.subfg
                        }
                    }
                    
                    // Framework badge
                    Rectangle {
                        implicitWidth: fwLabel.implicitWidth + 16
                        implicitHeight: 24
                        radius: Looks.radius.small
                        color: Looks.colors.bg2
                        
                        WText {
                            id: fwLabel
                            anchors.centerIn: parent
                            text: "Qt 6"
                            font.pixelSize: Looks.font.pixelSize.small
                            color: Looks.colors.subfg
                        }
                    }
                }
            }
        }
    }
    
    // Links
    WSettingsCard {
        title: Translation.tr("Links")
        icon: "open"
        
        WSettingsButton {
            label: Translation.tr("GitHub Repository")
            description: "github.com/snowarch/inir"
            icon: "globe-search"
            buttonText: Translation.tr("Open")
            onButtonClicked: Qt.openUrlExternally("https://github.com/snowarch/inir")
        }

        WSettingsButton {
            label: Translation.tr("Documentation")
            description: "snowarch.github.io/iNiR/docs"
            icon: "library"
            buttonText: Translation.tr("Open")
            onButtonClicked: Qt.openUrlExternally("https://snowarch.github.io/iNiR/docs/")
        }
        
        WSettingsButton {
            label: Translation.tr("Original Project (end-4)")
            description: "github.com/end-4/dots-hyprland"
            icon: "open"
            buttonText: Translation.tr("Open")
            onButtonClicked: Qt.openUrlExternally("https://github.com/end-4/dots-hyprland")
        }
        
        WSettingsButton {
            label: Translation.tr("Quickshell Documentation")
            description: "quickshell.outfoxxed.me"
            icon: "globe-search"
            buttonText: Translation.tr("Open")
            onButtonClicked: Qt.openUrlExternally("https://quickshell.outfoxxed.me")
        }
    }
    
    // Credits
    WSettingsCard {
        title: Translation.tr("Credits")
        icon: "people"
        
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 6
            spacing: 12
            
            WText {
                Layout.fillWidth: true
                text: Translation.tr("Based on illogical-impulse by end-4, adapted for the Niri compositor.")
                wrapMode: Text.WordWrap
                font.pixelSize: Looks.font.pixelSize.normal
                color: Looks.colors.subfg
                lineHeight: 1.3
            }
            
            WText {
                Layout.fillWidth: true
                text: Translation.tr("Special thanks to the Quickshell and Niri communities.")
                wrapMode: Text.WordWrap
                font.pixelSize: Looks.font.pixelSize.normal
                color: Looks.colors.subfg
                lineHeight: 1.3
            }
        }
    }
    
    // System Info
    WSettingsCard {
        title: Translation.tr("System Info")
        icon: "desktop"
        
        WSettingsRow {
            label: Translation.tr("Config path")
            description: FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/`)
            icon: "folder"
        }
        
        WSettingsRow {
            label: Translation.tr("Shell path")
            description: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/inir/`)
            icon: "folder"
        }
        
        WSettingsRow {
            label: Translation.tr("Panel family")
            description: Config.options?.panelFamily === "waffle" ? "Waffle (Windows 11)" : "ii (Material)"
            icon: "desktop"
        }
    }
}
