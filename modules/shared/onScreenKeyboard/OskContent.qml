import qs.modules.common
import "layouts.js" as Layouts
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property var layouts: Layouts.byName
    readonly property string requestedLayout: Config.options?.osk?.layout ?? ""
    readonly property bool handMade: layouts.hasOwnProperty(requestedLayout)
    // Any other layout gets the US (or ISO) keys labelled by xkbcommon with what they really type.
    property var generatedLayout: null
    property var currentLayout: handMade ? layouts[requestedLayout]
        : (generatedLayout ?? layouts[Layouts.defaultLayout])
    // A family draws the keys its own way: it hands over a component with `required property var modelData`.
    property Component keyComponent: defaultKey
    property real keySpacing: 5

    function relabel(labels): var {
        const us = layouts[Layouts.defaultLayout]
        const base = labels.iso ? layouts["German"] : us
        // Control keys keep the English names whatever board the geometry comes from.
        const usByCode = {}
        us.keys.forEach(row => row.forEach(key => { if (key.keycode !== undefined) usByCode[key.keycode] = key }))
        return {
            name_short: labels.layout.toUpperCase(),
            keys: base.keys.map(row => row.map(key => {
                const pair = labels.keys[String(key.keycode)]
                if (key.keytype !== "normal" || !pair) {
                    const english = (key.keycode === undefined || key.keycode === 100) ? null : usByCode[key.keycode] // Alt Gr stays
                    return english ? Object.assign({}, key, {
                        label: english.label,
                        labelShift: english.labelShift,
                        labelCaps: english.labelCaps
                    }) : key
                }
                return Object.assign({}, key, {
                    label: pair[0] || pair[1],
                    labelShift: pair[1] || pair[0],
                    labelCaps: undefined,
                    labelAlt: undefined
                })
            }))
        }
    }

    onRequestedLayoutChanged: generate()
    Component.onCompleted: generate()
    function generate(): void {
        root.generatedLayout = null
        if (root.handMade || root.requestedLayout.length === 0)
            return
        labelProc.running = false
        labelProc.command = ["/usr/bin/env", "python3", Quickshell.shellPath("scripts/osk-layout-labels.py"), root.requestedLayout]
        labelProc.running = true
    }

    Process {
        id: labelProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length === 0)
                    return // stopped for a newer layout
                try {
                    const labels = JSON.parse(text)
                    if (labels.keys)
                        root.generatedLayout = root.relabel(labels)
                } catch (e) {
                    console.warn("[OSK] could not read key labels for", root.requestedLayout, e)
                }
            }
        }
    }

    Component {
        id: defaultKey
        OskKey {
            required property var modelData
            keyData: modelData
        }
    }

    implicitWidth: keyRows.implicitWidth
    implicitHeight: keyRows.implicitHeight

    ColumnLayout {
        id: keyRows
        anchors.fill: parent
        spacing: root.keySpacing

        Repeater {
            model: root.currentLayout.keys

            delegate: RowLayout {
                id: keyRow
                required property var modelData
                spacing: root.keySpacing

                Repeater {
                    model: modelData
                    // A normal key looks like this: {label: "a", labelShift: "A", shape: "normal", keycode: 30, type: "normal"}
                    delegate: root.keyComponent
                }
            }
        }
    }
}
