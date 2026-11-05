pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Every option a widget has (DesktopWidgetOptions, what Settings lists) as Material's quick controls: switches,
// choices, sliders and words. Reads and writes the same values Settings does.
ColumnLayout {
    id: root

    // The rows to draw, from `DesktopWidgetOptions.sheetRows`.
    property var specs: []
    function valueOf(spec: var): var {
        Config.revision
        return DesktopWidgetOptions.read(spec)
    }
    function label(text: var): string { return Translation.tr(String(text ?? "")) }

    spacing: 10

    Repeater {
        model: ScriptModel { objectProp: "path"; values: root.specs.filter(spec => ["switch", "choice", "range", "text"].includes(spec.kind)) }
        delegate: Loader {
            id: row
            required property var modelData
            Layout.fillWidth: true
            sourceComponent: row.modelData.kind === "switch" ? switchRow
                : row.modelData.kind === "choice" ? choiceRow
                : row.modelData.kind === "range" ? rangeRow : textRow
            onLoaded: row.item.spec = row.modelData
        }
    }

    Component {
        id: switchRow
        WidgetQuickToggle {
            property var spec: ({})
            iconName: String(spec.glyph ?? "")
            label: root.label(spec.label)
            checked: spec.invert ? !Boolean(root.valueOf(spec)) : Boolean(root.valueOf(spec))
            onToggled: DesktopWidgetOptions.write(spec, spec.invert ? checked : !checked)
        }
    }

    Component {
        id: choiceRow
        WidgetQuickSection {
            id: choice
            property var spec: ({})
            readonly property var picks: choice.spec.choicesFrom ? DesktopWidgetOptions.choicesFor(String(choice.spec.choicesFrom))
                : (choice.spec.choices ?? [])
            readonly property var current: root.valueOf(choice.spec)
            title: root.label(choice.spec.label)
            detail: root.label(choice.picks.find(pick => String(pick.value) === String(choice.current))?.label ?? "")
            WidgetQuickChoices {
                // A long name takes a wider cell: names fit, never cut.
                maxColumns: choice.picks.length === 4 || choice.picks.some(pick => root.label(pick.label).length > 13) ? 2 : 3
                current: choice.current
                isSelected: entry => String(entry.value) === String(choice.current)
                model: choice.picks.map(pick => ({ value: pick.value, label: root.label(pick.label), icon: pick.glyph ?? "" }))
                onPicked: value => DesktopWidgetOptions.write(choice.spec, value)
            }
        }
    }

    Component {
        id: rangeRow
        WidgetQuickSlider {
            id: range
            property var spec: ({})
            readonly property real scale: Number(range.spec.scale ?? 1)
            title: root.label(range.spec.label)
            from: Number(range.spec.min ?? 0) * range.scale
            to: Number(range.spec.max ?? 100) * range.scale
            stepSize: Number(range.spec.step ?? 1) * range.scale
            value: Number(root.valueOf(range.spec) ?? 0) * range.scale
            unit: String(range.spec.unit ?? "").replace(/^ %$/, "%")
            format: v => range.spec.lowLabel && v <= range.from ? root.label(range.spec.lowLabel)
                : range.spec.zeroLabel && Math.round(v) === 0 ? root.label(range.spec.zeroLabel)
                : Number(v.toFixed(range.stepSize < 1 ? 1 : 0)) + range.unit
            onCommitted: v => DesktopWidgetOptions.write(range.spec, v / range.scale)
        }
    }

    Component {
        id: textRow
        WidgetQuickSection {
            id: words
            property var spec: ({})
            title: root.label(words.spec.label)
            MaterialTextField {
                Layout.fillWidth: true
                text: String(root.valueOf(words.spec) ?? "")
                placeholderText: root.label(words.spec.placeholder ?? "")
                onEditingFinished: if (text !== String(root.valueOf(words.spec) ?? "")) DesktopWidgetOptions.write(words.spec, text)
            }
        }
    }
}
