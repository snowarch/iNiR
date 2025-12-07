pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 8
    pageTitle: Translation.tr("Shortcuts")
    pageIcon: "keyboard"
    pageDescription: Translation.tr("Keyboard shortcuts from Niri config")
    
    readonly property var keybinds: CompositorService.isNiri ? NiriKeybinds.keybinds : null
    readonly property var categories: keybinds?.children ?? []
    
    property var keySubstitutions: ({
        "Super": "󰖳", "Slash": "/", "Return": "↵", "Escape": "Esc",
        "Comma": ",", "Period": ".", "BracketLeft": "[", "BracketRight": "]",
        "Left": "←", "Right": "→", "Up": "↑", "Down": "↓",
        "Page_Up": "PgUp", "Page_Down": "PgDn", "Home": "Home", "End": "End"
    })
    
    // Status card
    WSettingsCard {
        visible: CompositorService.isNiri
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            
            FluentIcon {
                icon: NiriKeybinds.loaded ? "checkmark-circle" : "info"
                implicitSize: 20
                color: NiriKeybinds.loaded ? Looks.colors.accent : Looks.colors.subfg
            }
            
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                
                WText {
                    text: NiriKeybinds.loaded 
                        ? Translation.tr("Keybinds loaded from config")
                        : Translation.tr("Using default keybinds")
                    font.pixelSize: Looks.font.pixelSize.normal
                }
                
                WText {
                    visible: NiriKeybinds.loaded
                    text: NiriKeybinds.configPath
                    font.pixelSize: Looks.font.pixelSize.small
                    color: Looks.colors.subfg
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }
        }
    }
    
    // Not Niri warning
    WSettingsCard {
        visible: !CompositorService.isNiri
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            
            FluentIcon {
                icon: "warning"
                implicitSize: 24
                color: Looks.colors.accent
            }
            
            WText {
                Layout.fillWidth: true
                text: Translation.tr("Shortcuts are only available when running on Niri compositor.")
                wrapMode: Text.WordWrap
                color: Looks.colors.subfg
            }
        }
    }
    
    // Categories
    Repeater {
        model: root.categories
        
        delegate: WSettingsCard {
            id: categoryCard
            required property var modelData
            required property int index
            
            readonly property var categoryKeybinds: modelData.children?.[0]?.keybinds ?? []
            
            title: modelData.name
            icon: root.getCategoryIcon(modelData.name)
            
            // Register each keybind for search
            Repeater {
                model: categoryCard.categoryKeybinds
                
                delegate: WKeybindRow {
                    required property var modelData
                    required property int index
                    
                    Layout.fillWidth: true
                    mods: modelData.mods ?? []
                    keyName: modelData.key ?? ""
                    action: modelData.comment ?? ""
                    showDivider: index < categoryCard.categoryKeybinds.length - 1
                    keySubstitutions: root.keySubstitutions
                    
                    // Search registration
                    settingsPageIndex: root.settingsPageIndex
                    settingsPageName: root.pageTitle
                    settingsSection: categoryCard.modelData.name
                }
            }
        }
    }
    
    function getCategoryIcon(name: string): string {
        const icons = {
            "System": "power",
            "ii Shell": "wand",
            "Window Switcher": "arrow-swap",
            "Screenshots": "screenshot",
            "Applications": "apps",
            "Window Management": "window",
            "Focus": "target",
            "Move Windows": "arrow-move",
            "Workspaces": "grid",
            "Media": "speaker-2-filled",
            "Brightness": "brightness-high",
            "Other": "options"
        }
        return icons[name] ?? "keyboard"
    }
}
