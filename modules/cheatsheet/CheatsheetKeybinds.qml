pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

StyledFlickable {
    id: root

    readonly property var keybinds: CompositorService.isNiri ? NiriKeybinds.keybinds : HyprlandKeybinds.keybinds
    readonly property var categories: keybinds?.children ?? []
    property string searchText: ""
    
    readonly property var allKeybinds: {
        let result = []
        for (let cat of categories) {
            const kbs = cat.children?.[0]?.keybinds ?? []
            for (let kb of kbs) {
                let item = Object.assign({}, kb)
                item.category = cat.name
                result.push(item)
            }
        }
        return result
    }
    
    readonly property var filteredKeybinds: {
        if (!searchText || searchText.trim().length === 0) return allKeybinds
        const q = searchText.toLowerCase().trim()
        return allKeybinds.filter(kb =>
            kb.key?.toLowerCase().includes(q) ||
            kb.mods?.some(m => m.toLowerCase().includes(q)) ||
            kb.comment?.toLowerCase().includes(q) ||
            kb.category?.toLowerCase().includes(q)
        )
    }
    
    readonly property bool hasResults: filteredKeybinds.length > 0
    
    property var keyBlacklist: ["Super_L"]
    property var keySubstitutions: ({
        "Super": "󰖳", "mouse_up": "Scroll ↓", "mouse_down": "Scroll ↑",
        "mouse:272": "LMB", "mouse:273": "RMB", "mouse:275": "MouseBack",
        "Slash": "/", "Hash": "#", "Return": "Enter",
    })
    
    clip: true
    contentHeight: contentColumn.implicitHeight + 40

    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: searchField.forceActiveFocus()
    }

    ColumnLayout {
        id: contentColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 16
        }
        spacing: 12
        
        // Header row
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            MaterialSymbol {
                text: "keyboard"
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colPrimary
            }
            
            StyledText {
                text: Translation.tr("Keybinds") + ` (${root.filteredKeybinds.length})`
                font.pixelSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer1
            }
            
            Item { Layout.fillWidth: true }
            
            ToolbarTextField {
                id: searchField
                Layout.preferredWidth: 250
                implicitHeight: 36
                text: root.searchText
                placeholderText: Translation.tr("Search (Ctrl+F)...")
                onTextChanged: root.searchText = text
                Keys.onEscapePressed: event => {
                    if (text.length > 0) {
                        text = ""
                        event.accepted = true
                    }
                }
            }
            
            RippleButton {
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: Appearance.rounding.full
                visible: searchField.text.length > 0
                onClicked: searchField.text = ""
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "backspace"
                    iconSize: 18
                }
            }
        }
        
        // No results message
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                 : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
            color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                 : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                 : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface 
                 : Appearance.colors.colLayer1
            border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                        : Appearance.inirEverywhere ? 1 : 0
            border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                        : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
            visible: !root.hasResults && root.searchText.length > 0

            CheatsheetNoResults {
                anchors.centerIn: parent
                onClearSearchRequested: searchField.text = ""
            }
        }
        
        // Keybinds list
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: keybindsColumn.implicitHeight + 16
            radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                 : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
            color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                 : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                 : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface 
                 : Appearance.colors.colLayer1
            border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                        : Appearance.inirEverywhere ? 1 : 0
            border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                        : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
            visible: root.hasResults

            Column {
                id: keybindsColumn
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 8
                }
                
                Repeater {
                    model: root.filteredKeybinds
                    
                    delegate: CheatsheetKeybindRow {
                        required property var modelData
                        required property int index
                        width: keybindsColumn.width
                        keybindData: modelData
                        keyBlacklist: root.keyBlacklist
                        keySubstitutions: root.keySubstitutions
                        showDivider: index < root.filteredKeybinds.length - 1
                    }
                }
            }
        }
    }
}
