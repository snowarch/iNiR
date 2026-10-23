pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.settings

// One area's everyday options on the shelf as quick tiles (S4): a switch 1x1, a range or a short choice 2x1, two rows
// that scroll sideways. The card above shows each change as it lands; the rest of the area is one tap away in Settings.
Flickable {
    id: root

    required property string section
    readonly property real d: IrisStyle.density
    readonly property real gap: Math.round(8 * root.d)
    readonly property real unit: Math.floor((root.height - root.gap) / 2)

    function shape(spec: var): string {
        if (spec.kind === "switch") return "switch"
        if (spec.kind === "range" && Number.isFinite(Number(spec.min)) && Number.isFinite(Number(spec.max))) return "range"
        if (spec.kind === "choice" && !spec.cards) {
            const choices = IrisOptions.choicesOf(spec)
            if (choices.length >= 2 && choices.length <= 4 && choices.every(entry => Translation.tr(String(entry.label ?? "")).length <= 9))
                return "choice"
        }
        return ""
    }
    readonly property var specs: {
        Config.revision
        return IrisOptions.settings.filter(spec => spec.section === root.section && !spec.mirror && IrisOptions.shown(spec)
            && !IrisOptions.fineTune(spec) && root.shape(spec) !== "")
    }
    // A name two rows share says whose it is: "Island · Light".
    function nameOf(spec: var): string {
        const label = Translation.tr(String(spec.label ?? ""))
        const twins = root.specs.filter(other => Translation.tr(String(other.label ?? "")) === label).length
        const group = Translation.tr(String(spec.group ?? ""))
        return twins > 1 && group.length > 0 && group !== label ? group + " · " + label : label
    }
    FontMetrics { id: nameMetrics; font.family: IrisStyle.fontMain; font.pixelSize: IrisStyle.typeMeta; font.weight: IrisStyle.weight(Font.DemiBold) }
    // Each tile as wide as what it says, laid in two rows that stay even: the next one goes on the shorter row.
    readonly property var placed: {
        const rows = [0, 0], out = []
        const lay = (w, item) => {
            const r = rows[0] <= rows[1] ? 0 : 1
            out.push(Object.assign({ x: rows[r], y: r * (root.unit + root.gap), w: w }, item))
            rows[r] += w + root.gap
        }
        for (const spec of root.specs) {
            const kind = root.shape(spec)
            const name = root.nameOf(spec)
            const said = nameMetrics.advanceWidth(name)
            let w = 0
            if (kind === "switch") w = Math.min(Math.round(280 * root.d), Math.max(Math.round(132 * root.d), said + Math.round(34 * root.d)))
            else if (kind === "range") w = Math.max(Math.round(240 * root.d), said + Math.round(90 * root.d))
            else {
                const widest = Math.max(...IrisOptions.choicesOf(spec).map(entry => nameMetrics.advanceWidth(Translation.tr(String(entry.label ?? "")))))
                const track = IrisOptions.choicesOf(spec).length * (widest + Math.round(24 * root.d)) + 4
                w = Math.min(Math.round(440 * root.d), Math.max(Math.round(200 * root.d), track + Math.round(16 * root.d), said + Math.round(24 * root.d)))
            }
            lay(Math.ceil(w), { spec: spec, kind: kind, name: name })
        }
        lay(Math.round(132 * root.d), { spec: null, kind: "more", name: "" })
        return out
    }

    contentWidth: board.width
    contentHeight: height
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) ? event.angleDelta.x : event.angleDelta.y
            root.contentX = Math.max(0, Math.min(root.contentWidth - root.width, root.contentX - delta / 120 * Math.round(180 * root.d)))
        }
    }

    Item {
        id: board
        width: Math.max(0, ...root.placed.map(cell => cell.x + cell.w))
        height: root.height
        Repeater {
            model: ScriptModel { values: root.placed; objectProp: "name" }
            Loader {
                id: cell
                required property var modelData
                x: cell.modelData.x
                y: cell.modelData.y
                width: cell.modelData.w
                height: root.unit
                sourceComponent: cell.modelData.kind === "switch" ? switchTile : cell.modelData.kind === "range" ? rangeTile
                    : cell.modelData.kind === "choice" ? choiceTile : moreTile
                onLoaded: { cell.item.spec = cell.modelData.spec; cell.item.name = cell.modelData.name }
            }
        }
    }

    // The rest of the area, in Settings.
    Component {
        id: moreTile
        IrisTile {
            property var spec: null
            property string name: ""
            unit: root.unit
            glyph: "tune"
            title: Translation.tr("More")
            label: Translation.tr("Settings")
            onClicked: GlobalStates.openSettingsAt("iris", root.section)
        }
    }

    Component {
        id: switchTile
        IrisTile {
            id: sw
            property var spec: null
            property string name: ""
            readonly property bool lit: { Config.revision; const v = !!IrisOptions.currentValue(sw.spec ?? {}); return sw.spec?.invert ? !v : v }
            unit: root.unit
            on: sw.lit
            wide: true
            title: sw.name
            label: sw.lit ? Translation.tr("On") : Translation.tr("Off")
            onClicked: IrisOptions.commit(sw.spec, sw.spec.invert ? sw.lit : !sw.lit)
        }
    }

    component WidePlate: Rectangle {
        id: plate
        property var spec: null
        property string name: ""
        property string said: ""
        radius: IrisStyle.radiusTile
        color: IrisStyle.fill
        IrisText {
            x: Math.round(12 * root.d)
            y: Math.round(10 * root.d)
            width: plate.width - x - (sayText.visible ? sayText.width + Math.round(20 * root.d) : Math.round(12 * root.d))
            elide: Text.ElideRight
            text: plate.name
            role: IrisText.Name
            font.pixelSize: IrisStyle.typeMeta
            font.weight: IrisStyle.weight(Font.DemiBold)
        }
        IrisLabel {
            id: sayText
            anchors.right: parent.right
            anchors.rightMargin: Math.round(12 * root.d)
            y: Math.round(11 * root.d)
            visible: plate.said.length > 0
            text: plate.said
        }
    }
    Component {
        id: rangeTile
        WidePlate {
            id: range
            readonly property real lo: Number(range.spec?.min ?? 0)
            readonly property real hi: Number(range.spec?.max ?? 1)
            readonly property real step: Number(range.spec?.step ?? 1)
            property real dragged: NaN
            readonly property real value: { Config.revision; return Number.isFinite(range.dragged) ? range.dragged : Number(IrisOptions.currentValue(range.spec ?? {})) }
            said: range.spec ? Translation.tr(IrisOptions.rangeText(range.spec, range.value)) : ""
            function snap(raw: real): real {
                const snapped = range.lo + Math.round((raw - range.lo) / range.step) * range.step
                return Number(Math.max(range.lo, Math.min(range.hi, snapped)).toFixed(4))
            }
            IrisSlider {
                id: slider
                x: Math.round(10 * root.d)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(6 * root.d)
                width: parent.width - 2 * x
                value: range.hi > range.lo ? (range.value - range.lo) / (range.hi - range.lo) : 0
                // A drag is seen live in memory and written once, on release, as Settings does.
                onMoved: next => {
                    const v = range.snap(range.lo + next * (range.hi - range.lo))
                    if (!slider.pressed) { IrisOptions.commit(range.spec, v); return }
                    range.dragged = v
                    if (range.spec.path && !range.spec.set) Config.previewNestedValue(range.spec.path, v)
                }
                onPressedChanged: if (!slider.pressed && Number.isFinite(range.dragged)) {
                    const v = range.dragged
                    range.dragged = NaN
                    IrisOptions.commit(range.spec, v)
                }
            }
        }
    }
    Component {
        id: choiceTile
        WidePlate {
            id: choice
            readonly property var options: IrisOptions.choicesOf(choice.spec ?? {})
            readonly property var now: { Config.revision; return IrisOptions.currentValue(choice.spec ?? {}) }
            IrisSegmented {
                x: Math.round(8 * root.d)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(8 * root.d)
                width: parent.width - 2 * x
                accessibleName: Translation.tr(String(choice.spec?.label ?? ""))
                options: choice.options.map(entry => ({ label: Translation.tr(String(entry.label ?? "")), value: entry.value }))
                current: choice.now
                onPicked: value => IrisOptions.commit(choice.spec, value)
            }
        }
    }
}
