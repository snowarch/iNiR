pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style
import qs.modules.iris.equalizer

// One effect module: a tappable header row (glyph, name, state detail,
// switch) over a simple-first body. The switch flips bypass through
// IrisAudio.toggleModule — instant, no preset reload, same as every other
// control in this panel except the band-count selector.
//
// Body controls are generated from IrisEqSpec tables (simple rows first,
// the rest behind a disclosure). Sliders write through setParam and read
// back from the live modules map, so if EasyEffects clamps a value the
// panel re-syncs instead of arguing.
//
// Outside a drag, each row's `value` is a binding to that live map, which is
// only correct because setParam paints the optimistic value flat, into the
// same field the snapshot writes. While a drag lasts the row reads its own
// last committed step instead (IrisEqSliderRow.dragging), so a snapshot that
// lands mid-drag can no longer yank the handle out from under the finger; it
// takes over again when the drag settles, which by then is the same number
// the optimistic write already published.
//
// Nothing in the body may take its height from a value. The readout is in a
// fixed-width field for exactly that reason, and every label here is NoWrap:
// a card that changes height when a number changes moves the whole panel.
ColumnLayout {
    id: root

    property string moduleId: ""
    property bool engineReady: false
    property bool expanded: false

    spacing: 0

    readonly property real d: IrisStyle.density
    readonly property var meta: IrisEqSpec.moduleMeta(root.moduleId)
    readonly property var entry: (IrisAudio.modules ?? {})[root.moduleId] ?? {}
    // Through IrisEqSpec.moduleActive, not `entry.active ?? false`. The engine
    // sends no `active`: it sends `bypass`, and the service derives `active`
    // from it. Reading the raw field means a module the engine is still running
    // paints itself bypassed, and every body control below, which is gated on
    // root.active, greys out with it.
    readonly property bool active: IrisEqSpec.moduleActive(IrisAudio.modules, root.moduleId)
    readonly property var table: IrisEqSpec.params[root.moduleId] ?? ({ simple: [], advanced: [] })
    readonly property var simpleRows: root.table.simple ?? []
    readonly property var advancedRows: root.table.advanced ?? []
    readonly property var presets: IrisEqSpec.factoryPresets[root.moduleId] ?? []

    function param(key: string, fallback: var): var {
        return IrisEqSpec.paramOf(IrisAudio.modules, root.moduleId, key, fallback)
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: headRow.implicitHeight + Math.round(16 * root.d)
        radius: IrisStyle.radiusCard
        color: root.active ? IrisStyle.tintFill(IrisStyle.accent) : IrisStyle.readingCard
        Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }

        RowLayout {
            id: headRow
            anchors.fill: parent
            anchors.leftMargin: Math.round(12 * root.d)
            anchors.rightMargin: Math.round(12 * root.d)
            anchors.topMargin: Math.round(8 * root.d)
            anchors.bottomMargin: Math.round(8 * root.d)
            spacing: Math.round(10 * root.d)

            Rectangle {
                implicitWidth: Math.round(30 * root.d)
                implicitHeight: implicitWidth
                radius: height / 2
                color: root.active ? IrisStyle.accent : IrisStyle.fill
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.meta.glyph
                    fill: root.active ? 1 : 0
                    iconSize: Math.round(17 * root.d)
                    color: root.active ? IrisStyle.onTintFor(IrisStyle.accent) : IrisStyle.text
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                IrisText {
                    Layout.fillWidth: true
                    text: root.meta.label
                    font.pixelSize: IrisStyle.typeLabel
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    elide: Text.ElideRight
                }
                IrisText {
                    Layout.fillWidth: true
                    text: !root.engineReady ? Translation.tr("Waiting for engine") : root.active ? root.meta.detail : Translation.tr("Bypassed — tap to bring back")
                    color: root.active ? IrisStyle.textSecondary : IrisStyle.muted
                    font.pixelSize: IrisStyle.typeFootnote
                    elide: Text.ElideRight
                }
            }

            MaterialSymbol {
                visible: root.simpleRows.length > 0
                text: root.expanded ? "expand_less" : "expand_more"
                iconSize: Math.round(18 * root.d)
                color: IrisStyle.muted
            }

            IrisSwitch {
                on: root.active
                name: root.meta.label
                enabled: false
            }
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: eventPoint => {
                if (!root.engineReady) return
                if (eventPoint.pressPosition.x < width - Math.round(64 * root.d)) root.expanded = !root.expanded
                else IrisAudio.toggleModule(root.moduleId)
            }
        }
        Accessible.role: Accessible.CheckBox
        Accessible.name: root.meta.label
        Accessible.checked: root.active
    }

    // -- body ------------------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.expanded
        spacing: Math.round(8 * root.d)

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(6 * root.d)
            Layout.rightMargin: Math.round(6 * root.d)
            Layout.topMargin: Math.round(8 * root.d)
            spacing: Math.round(6 * root.d)

            Repeater {
                model: root.simpleRows
                ParamRow {
                    required property var modelData
                    Layout.fillWidth: true
                    spec: modelData
                }
            }

            // Advanced disclosure.
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.advancedRows.length > 0
                spacing: Math.round(6 * root.d)

                IrisButton {
                    Layout.alignment: Qt.AlignLeft
                    quiet: true
                    buttonRadius: height / 2
                    text: root.showAdvanced ? Translation.tr("Fewer controls") : Translation.tr("More controls")
                    onClicked: root.showAdvanced = !root.showAdvanced
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.showAdvanced
                    spacing: Math.round(6 * root.d)
                    Repeater {
                        model: root.advancedRows
                        ParamRow {
                            required property var modelData
                            Layout.fillWidth: true
                            spec: modelData
                        }
                    }
                }
            }

            // Per-module factory presets.
            Flow {
                Layout.fillWidth: true
                visible: root.presets.length > 0
                spacing: Math.round(6 * root.d)
                Repeater {
                    model: root.presets
                    IrisChip {
                        required property var modelData
                        label: modelData.name
                        glyph: "auto_fix_high"
                        onClicked: root.applyFactory(modelData)
                    }
                }
            }
        }
    }

    property bool showAdvanced: false

    function applyFactory(preset: var): void {
        const params = preset.params ?? {}
        for (const key of Object.keys(params)) IrisAudio.setParam(root.moduleId, key, params[key])
    }

    // -- one generated parameter row --------------------------------------
    component ParamRow: ColumnLayout {
        id: row
        required property var spec
        Layout.fillWidth: true
        spacing: Math.round(4 * root.d)

        readonly property string key: String(row.spec.key ?? "")
        readonly property string kind: String(row.spec.kind ?? "slider")
        readonly property var fallback: row.spec.def ?? 0

        IrisEqSliderRow {
            Layout.fillWidth: true
            visible: row.kind === "slider" || row.kind === "int"
            label: String(row.spec.label ?? row.key)
            unit: String(row.spec.unit ?? "")
            minimum: Number(row.spec.min ?? 0)
            maximum: Number(row.spec.max ?? 1)
            integer: row.kind === "int"
            value: Number(root.param(row.key, row.fallback))
            enabled: root.engineReady && root.active
            onCommit: next => IrisAudio.setParam(root.moduleId, row.key, next)
        }

        RowLayout {
            Layout.fillWidth: true
            visible: row.kind === "bool"
            spacing: Math.round(10 * root.d)
            IrisText {
                Layout.fillWidth: true
                text: String(row.spec.label ?? row.key)
                color: IrisStyle.subtext
                font.pixelSize: IrisStyle.typeMeta
                elide: Text.ElideRight
            }
            IrisSwitch {
                on: Boolean(root.param(row.key, row.fallback))
                name: String(row.spec.label ?? row.key)
                enabled: root.engineReady && root.active
                onToggled: IrisAudio.setParam(root.moduleId, row.key, !Boolean(root.param(row.key, row.fallback)))
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: row.kind === "enum"
            spacing: Math.round(6 * root.d)
            IrisText {
                Layout.fillWidth: true
                text: String(row.spec.label ?? row.key)
                color: IrisStyle.subtext
                font.pixelSize: IrisStyle.typeMeta
                elide: Text.ElideRight
            }
            Flow {
                Layout.fillWidth: true
                spacing: Math.round(6 * root.d)
                Repeater {
                    model: row.spec.options ?? []
                    IrisChip {
                        required property var modelData
                        label: String(modelData)
                        selected: String(root.param(row.key, row.fallback)) === String(modelData)
                        enabled: root.engineReady && root.active
                        onClicked: IrisAudio.setParam(root.moduleId, row.key, String(modelData))
                    }
                }
            }
        }
    }
}
