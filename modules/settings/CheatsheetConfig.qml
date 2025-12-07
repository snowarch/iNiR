import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ContentPage {
    id: root
    forceWidth: true
    settingsPageIndex: 8
    settingsPageName: Translation.tr("Shortcuts")

    readonly property var keybinds: CompositorService.isNiri ? NiriKeybinds.keybinds : HyprlandKeybinds.keybinds
    readonly property var categories: keybinds?.children ?? []
    
    property var keySubstitutions: ({
        "Super": "󰖳", "Slash": "/", "Return": "↵", "Escape": "Esc",
        "Comma": ",", "Period": ".", "BracketLeft": "[", "BracketRight": "]",
        "Left": "←", "Right": "→", "Up": "↑", "Down": "↓",
        "Page_Up": "PgUp", "Page_Down": "PgDn", "Home": "Home", "End": "End"
    })

    // Status section
    ContentSection {
        icon: NiriKeybinds.loaded ? "check_circle" : "info"
        title: NiriKeybinds.loaded 
            ? Translation.tr("Keybinds loaded from config")
            : Translation.tr("Using default keybinds")
        visible: CompositorService.isNiri

        StyledText {
            Layout.fillWidth: true
            text: NiriKeybinds.loaded 
                ? NiriKeybinds.configPath
                : Translation.tr("Could not parse niri config, showing defaults")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
            wrapMode: Text.WordWrap
        }
    }

    // Categories
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 16

        Repeater {
            model: root.categories

            delegate: ContentSection {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                
                readonly property var categoryKeybinds: modelData.children?.[0]?.keybinds ?? []
                
                icon: root.getCategoryIcon(modelData.name)
                title: modelData.name
                
                // Register keybinds for global search
                enableSettingsSearch: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Repeater {
                        model: categoryKeybinds

                        delegate: KeybindRow {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            mods: modelData.mods ?? []
                            keyName: modelData.key ?? ""
                            action: modelData.comment ?? ""
                            showDivider: index < categoryKeybinds.length - 1
                        }
                    }
                }
            }
        }
    }

    Item { Layout.preferredHeight: 20 }

    function getCategoryIcon(name: string): string {
        const icons = {
            "System": "settings_power",
            "ii Shell": "auto_awesome",
            "Window Switcher": "swap_horiz",
            "Screenshots": "screenshot_region",
            "Applications": "apps",
            "Window Management": "web_asset",
            "Focus": "center_focus_strong",
            "Move Windows": "open_with",
            "Workspaces": "grid_view",
            "Media": "volume_up",
            "Brightness": "light_mode",
            "Other": "more_horiz"
        }
        return icons[name] ?? "keyboard"
    }

    // Keybind row component
    component KeybindRow: Item {
        id: kbRow
        property var mods: []
        property string keyName: ""
        property string action: ""
        property bool showDivider: true
        
        implicitHeight: 36

        Rectangle {
            anchors.fill: parent
            color: rowMouse.containsMouse ? Appearance.colors.colLayer1Hover : "transparent"
            radius: Appearance.rounding.small
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 12

            // Keys
            Row {
                Layout.preferredWidth: 200
                Layout.minimumWidth: 150
                spacing: 4

                Repeater {
                    model: kbRow.mods
                    delegate: KeyBadge {
                        required property var modelData
                        keyText: root.keySubstitutions[modelData] ?? modelData
                    }
                }

                StyledText {
                    visible: kbRow.mods.length > 0 && kbRow.keyName.length > 0
                    text: "+"
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                    anchors.verticalCenter: parent.verticalCenter
                }

                KeyBadge {
                    visible: kbRow.keyName.length > 0
                    keyText: root.keySubstitutions[kbRow.keyName] ?? kbRow.keyName
                }
            }

            // Action
            StyledText {
                Layout.fillWidth: true
                text: kbRow.action
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                elide: Text.ElideRight
            }
        }

        // Divider
        Rectangle {
            visible: kbRow.showDivider
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            height: 1
            color: Appearance.colors.colOutlineVariant
            opacity: 0.3
        }
    }

    // Key badge component
    component KeyBadge: Rectangle {
        property string keyText: ""
        
        implicitWidth: Math.max(keyLabel.implicitWidth + 10, 26)
        implicitHeight: 22
        radius: Appearance.rounding.small
        color: Appearance.colors.colSurfaceContainerHigh ?? Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.m3colors.m3outlineVariant ?? ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.85)

        StyledText {
            id: keyLabel
            anchors.centerIn: parent
            text: keyText
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.family: Appearance.font.family.monospace
            color: Appearance.colors.colOnLayer1
        }
    }
}
