pragma ComponentBehavior: Bound

import qs.services
import qs.services.deferred
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

    readonly property bool isSearching: searchText.trim().length > 0

    readonly property var filteredKeybinds: {
        if (!isSearching) return allKeybinds
        const q = searchText.toLowerCase().trim()
        return allKeybinds.filter(kb =>
            kb.key?.toLowerCase().includes(q) ||
            kb.mods?.some(m => m.toLowerCase().includes(q)) ||
            kb.comment?.toLowerCase().includes(q) ||
            kb.category?.toLowerCase().includes(q)
        )
    }
    
    readonly property bool hasResults: filteredKeybinds.length > 0

    // Category icon mapping
    function categoryIcon(name) {
        const icons = {
            "System": "settings_power",
            "ii Shell": "dashboard",
            "Window Switcher": "swap_horiz",
            "Region Tools": "screenshot_region",
            "Applications": "apps",
            "Window Management": "select_window",
            "Focus": "filter_center_focus",
            "Move Windows": "open_with",
            "Workspaces": "workspaces",
            "Screenshots": "screenshot_monitor",
            "Media": "music_note",
            "Brightness": "brightness_medium",
            "Layout": "view_quilt",
            "Resize": "aspect_ratio",
            "Monitors": "monitor",
            "Other": "more_horiz",
        }
        return icons[name] ?? "keyboard"
    }
    
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

        // Grouped by category (when not searching)
        Repeater {
            model: root.isSearching ? 0 : root.categories.length

            delegate: Rectangle {
                id: catCard
                required property int index
                readonly property var catData: root.categories[index]
                readonly property string catName: catData?.name ?? ""
                readonly property var catKeybinds: catData?.children?.[0]?.keybinds ?? []

                Layout.fillWidth: true
                Layout.preferredHeight: catColumn.implicitHeight + 8
                visible: catKeybinds.length > 0
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

                Column {
                    id: catColumn
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 4
                    }

                    // Category header
                    Item {
                        width: parent.width
                        height: 36

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 12
                                rightMargin: 12
                            }
                            spacing: 8

                            MaterialSymbol {
                                text: root.categoryIcon(catCard.catName)
                                iconSize: 18
                                color: Appearance.colors.colPrimary
                            }

                            StyledText {
                                text: catCard.catName
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colPrimary
                            }

                            Item { Layout.fillWidth: true }

                            // Count badge
                            Rectangle {
                                implicitWidth: countLabel.implicitWidth + 12
                                implicitHeight: 20
                                radius: Appearance.rounding.full
                                color: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                                     : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                                     : Appearance.colors.colLayer2
                                StyledText {
                                    id: countLabel
                                    anchors.centerIn: parent
                                    text: catCard.catKeybinds.length
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }
                    }

                    // Divider under header
                    Rectangle {
                        width: parent.width - 24
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 1
                        color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                             : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                             : Appearance.colors.colOutlineVariant
                        opacity: 0.4
                    }

                    // Keybind rows for this category
                    Repeater {
                        model: catCard.catKeybinds

                        delegate: CheatsheetKeybindRow {
                            required property var modelData
                            required property int index
                            width: catColumn.width
                            keybindData: Object.assign({category: catCard.catName}, modelData)
                            keyBlacklist: root.keyBlacklist
                            keySubstitutions: root.keySubstitutions
                            showDivider: index < catCard.catKeybinds.length - 1
                        }
                    }
                }
            }
        }

        // Flat filtered list (when searching)
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: searchColumn.implicitHeight + 16
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
            visible: root.isSearching && root.hasResults

            Column {
                id: searchColumn
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 8
                }

                Repeater {
                    model: root.isSearching ? root.filteredKeybinds : []

                    delegate: CheatsheetKeybindRow {
                        required property var modelData
                        required property int index
                        width: searchColumn.width
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
