pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.iris.style

// A set of choices laid out as even rows: every cell of a row has the same width and the last row
// shares the full width among what is left, so five choices read 3 + 2, never 2 + 2 + an orphan.
// Entries are { value, label, icon } (label and icon optional); `current` marks the chosen value,
// or `isSelected(entry)` decides for toggles and composite choices.
ColumnLayout {
    id: root

    property var model: []
    property var current: undefined
    property var isSelected: null
    property int maxColumns: 3
    signal picked(var value, var entry)

    readonly property bool iris: (Config.options?.panelFamily ?? "ii") === "iris"
    readonly property real gap: Math.round(4 * (root.iris ? IrisStyle.density : 1))
    readonly property var entries: Array.from(root.model ?? []).filter(entry => entry && entry.visible !== false)
    readonly property int columns: {
        const n = root.entries.length
        const cap = Math.max(1, root.maxColumns)
        if (n <= cap) return Math.max(1, n)
        return n === 4 ? 2 : cap
    }
    readonly property var rows: {
        const out = []
        for (let i = 0; i < root.entries.length; i += root.columns)
            out.push(root.entries.slice(i, i + root.columns))
        return out
    }

    // Every cell is as wide as the widest label needs, so the sheet grows to fit instead of eliding.
    property real widest: 0
    onEntriesChanged: root.widest = 0

    function selected(entry: var): bool {
        return typeof root.isSelected === "function" ? Boolean(root.isSelected(entry)) : entry.value === root.current
    }

    spacing: root.gap
    Layout.fillWidth: true

    Repeater {
        model: root.rows

        RowLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            spacing: root.gap

            Repeater {
                model: row.modelData

                WidgetQuickChoice {
                    id: choice
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: Math.max(1, root.widest)
                    Layout.maximumWidth: Number.POSITIVE_INFINITY
                    onImplicitWidthChanged: root.widest = Math.max(root.widest, choice.implicitWidth)
                    Component.onCompleted: root.widest = Math.max(root.widest, choice.implicitWidth)
                    iconName: modelData.icon ?? ""
                    label: modelData.label ?? ""
                    tooltip: modelData.tooltip ?? ""
                    danger: Boolean(modelData.danger)
                    selected: root.selected(modelData)
                    onClicked: root.picked(modelData.value, modelData)
                }
            }
        }
    }
}
