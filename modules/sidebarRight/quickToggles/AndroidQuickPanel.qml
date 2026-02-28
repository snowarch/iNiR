import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

import qs.modules.sidebarRight.quickToggles.androidStyle

AbstractQuickPanel {
    id: root
    property bool editMode: false
    Layout.fillWidth: true

    // Sizes
    implicitHeight: contentItem.implicitHeight + root.padding * 2
    Behavior on implicitHeight {
        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
    }
    property real spacing: 6
    property real padding: 6
    readonly property real baseCellWidth: {
        const availableWidth = root.width - (root.padding * 2) - (root.spacing * (root.columns - 1))
        return availableWidth / root.columns
    }
    readonly property real baseCellHeight: 56

    // Toggles
    readonly property list<string> availableToggleTypes: ["network", "bluetooth", "idleInhibitor", "easyEffects", "nightLight", "darkMode", "cloudflareWarp", "gameMode", "screenSnip", "colorPicker", "onScreenKeyboard", "mic", "audio", "notifications", "powerProfile", "musicRecognition", "voiceSearch", "antiFlashbang"]
    readonly property int columns: Config.options?.sidebar?.quickToggles?.android?.columns ?? 4
    readonly property list<var> toggles: Config.ready ? (Config.options?.sidebar?.quickToggles?.android?.toggles ?? []) : []
    readonly property list<var> toggleRows: toggleRowsForList(toggles)
    readonly property list<var> unusedToggles: {
        const types = availableToggleTypes.filter(type => !toggles.some(toggle => (toggle && toggle.type === type)))
        return types.map(type => { return { type: type, size: 1 } })
    }
    readonly property list<var> unusedToggleRows: toggleRowsForList(unusedToggles)

    function toggleRowsForList(togglesList) {
        var rows = [];
        var row = [];
        var totalSize = 0; // Total cols taken in current row
        for (var i = 0; i < togglesList.length; i++) {
            if (!togglesList[i]) continue;
            if (totalSize + togglesList[i].size > columns) {
                rows.push(row);
                row = [];
                totalSize = 0;
            }
            row.push(togglesList[i]);
            totalSize += togglesList[i].size;
        }
        if (row.length > 0) {
            rows.push(row);
        }
        return rows;
    }

    Column {
        id: contentItem
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: 12
        
        ScrollView {
            id: scrollView
            width: parent.width
            height: (root.editMode) ? usedRows.implicitHeight : Math.min(usedRows.implicitHeight, (root.baseCellHeight * 2.3) + (root.spacing * 2))
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            Column {
                id: usedRows
                width: parent.width
                spacing: root.spacing

                Repeater {
                    id: usedRowsRepeater
                    model: ScriptModel {
                        values: Array(root.toggleRows.length)
                    }
                    delegate: ButtonGroup {
                        id: toggleRow
                        required property int index
                        property var modelData: root.toggleRows[index]
                        property int startingIndex: {
                            const rows = root.toggleRows;
                            let sum = 0;
                            for (let i = 0; i < index; i++) {
                                sum += rows[i].length;
                            }
                            return sum;
                        }
                        spacing: root.spacing

                        Repeater {
                            model: ScriptModel {
                                values: toggleRow?.modelData ?? []
                                objectProp: "type"
                            }
                            delegate: AndroidToggleDelegateChooser {
                                startingIndex: toggleRow.startingIndex
                                editMode: root.editMode
                                baseCellWidth: root.baseCellWidth
                                baseCellHeight: root.baseCellHeight
                                spacing: root.spacing
                                onOpenAudioOutputDialog: root.openAudioOutputDialog()
                                onOpenAudioInputDialog: root.openAudioInputDialog()
                                onOpenBluetoothDialog: root.openBluetoothDialog()
                                onOpenNightLightDialog: root.openNightLightDialog()
                                onOpenWifiDialog: root.openWifiDialog()
                            }
                        }
                    }
                }
            }
        }

        FadeLoader {
            shown: root.editMode
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: root.baseCellHeight / 2
                rightMargin: root.baseCellHeight / 2
            }
            sourceComponent: Rectangle {
                implicitHeight: 1
                color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                    : Appearance.auroraEverywhere ? "transparent" : Appearance.colors.colOutlineVariant
            }
        }

        FadeLoader {
            shown: root.editMode
            sourceComponent: Column {
                id: unusedRows
                spacing: root.spacing

                Repeater {
                    model: ScriptModel {
                        values: Array(root.unusedToggleRows.length)
                    }
                    delegate: ButtonGroup {
                        id: unusedToggleRow
                        required property int index
                        property var modelData: root.unusedToggleRows[index]
                        spacing: root.spacing

                        Repeater {
                            model: ScriptModel {
                                values: unusedToggleRow?.modelData ?? []
                                objectProp: "type"
                            }
                            delegate: AndroidToggleDelegateChooser {
                                startingIndex: -1
                                editMode: root.editMode
                                baseCellWidth: root.baseCellWidth
                                baseCellHeight: root.baseCellHeight
                                spacing: root.spacing
                            }
                        }
                    }
                }
            }
        }
    }
}
