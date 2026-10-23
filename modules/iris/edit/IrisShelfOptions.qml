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

// One area's everyday options on the shelf, two rows of inline tiles that scroll sideways (S4): each says its name and
// holds its control beside it, a switch, a short choice or a scrubber with its value. The card above shows each change
// as it lands; the rest of the area is one tap away in Settings.
Flickable {
    id: root

    required property string section
    // One group of the area when the shelf wants only it (Look = Desktop › Widgets).
    property string group: ""
    readonly property real d: IrisStyle.density
    readonly property real gap: Math.round(8 * root.d)
    readonly property real unit: Math.floor((root.height - root.gap) / 2)
    readonly property real inner: Math.round(12 * root.d)

    function shape(spec: var): string {
        if (spec.kind === "switch") return "switch"
        if (spec.kind === "range" && Number.isFinite(Number(spec.min)) && Number.isFinite(Number(spec.max))) return "range"
        if (spec.kind === "choice" && !spec.cards) {
            const choices = IrisOptions.choicesOf(spec)
            if (choices.length >= 2 && choices.length <= 4 && choices.every(entry => Translation.tr(String(entry.label ?? "")).length <= 11))
                return "choice"
        }
        return ""
    }
    readonly property var specs: {
        Config.revision
        return IrisOptions.settings.filter(spec => spec.section === root.section && (root.group.length === 0 || spec.group === root.group)
            && !spec.mirror && IrisOptions.shown(spec)
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
    FontMetrics { id: choiceMetrics; font.family: IrisStyle.fontMain; font.pixelSize: IrisStyle.typeMeta; font.weight: IrisStyle.weight(Font.DemiBold) }
    readonly property real switchWidth: Math.round(40 * root.d)
    readonly property real scrubWidth: Math.round(120 * root.d)
    function choiceTrack(spec: var): real {
        const choices = IrisOptions.choicesOf(spec)
        const widest = Math.max(...choices.map(entry => choiceMetrics.advanceWidth(Translation.tr(String(entry.label ?? "")))))
        return Math.ceil(choices.length * (widest + Math.round(26 * root.d)) + 6)
    }
    // Each tile as wide as its name and its control, laid in two rows that stay even: the next goes on the shorter one.
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
            // A few pixels over the measure: the name's own text rounds up and "Outline" read "Outl…".
            const said = Math.min(Math.round(200 * root.d), Math.ceil(nameMetrics.advanceWidth(name)) + Math.round(6 * root.d))
            const control = kind === "switch" ? root.switchWidth
                : kind === "range" ? root.scrubWidth + Math.round(44 * root.d) : root.choiceTrack(spec)
            lay(Math.ceil(root.inner + said + Math.round(12 * root.d) + control + root.inner * 0.75), { spec: spec, kind: kind, name: name })
        }
        lay(Math.round(118 * root.d), { spec: null, kind: "more", name: "" })
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
                onLoaded: {
                    cell.item.spec = cell.modelData.spec
                    if (cell.modelData.kind !== "more") cell.item.name = cell.modelData.name
                }
            }
        }
    }

    // A tile: its name on the left, its control on the right, one line.
    component Plate: Rectangle {
        id: plate
        property var spec: null
        property string name: ""
        property real controlWidth: 0
        default property alias control: holder.data
        property bool tappable: false
        signal tapped()
        radius: IrisStyle.fieldChamfer ? 0 : Math.min(IrisStyle.radiusTile, height / 2)
        color: plateHover.hovered ? IrisStyle.fillActive : IrisStyle.fillQuiet
        Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
        HoverHandler { id: plateHover }
        MouseArea {
            anchors.fill: parent
            enabled: plate.tappable
            cursorShape: Qt.PointingHandCursor
            onClicked: plate.tapped()
        }
        IrisText {
            x: root.inner
            anchors.verticalCenter: parent.verticalCenter
            width: plate.width - x - plate.controlWidth - Math.round(12 * root.d) - root.inner * 0.75
            elide: Text.ElideRight
            text: plate.name
            role: IrisText.Name
            font.pixelSize: IrisStyle.typeMeta
            font.weight: IrisStyle.weight(Font.DemiBold)
        }
        Item {
            id: holder
            anchors.right: parent.right
            anchors.rightMargin: Math.round(root.inner * 0.75)
            anchors.verticalCenter: parent.verticalCenter
            width: plate.controlWidth
            height: plate.height
        }
    }

    // The rest of the area, in Settings.
    Component {
        id: moreTile
        Plate {
            property var spec: null
            name: Translation.tr("More")
            controlWidth: Math.round(18 * root.d)
            tappable: true
            onTapped: GlobalStates.openSettingsAt("iris", root.group.length > 0 ? root.section + "/" + root.group : root.section)
            MaterialSymbol {
                anchors.centerIn: parent
                text: "arrow_outward"
                iconSize: Math.round(16 * root.d)
                color: IrisStyle.textSecondary
            }
        }
    }

    Component {
        id: switchTile
        Plate {
            id: sw
            readonly property bool lit: { Config.revision; const v = !!IrisOptions.currentValue(sw.spec ?? {}); return sw.spec?.invert ? !v : v }
            controlWidth: root.switchWidth
            tappable: true
            onTapped: IrisOptions.commit(sw.spec, sw.spec.invert ? sw.lit : !sw.lit)
            IrisSwitch {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                on: sw.lit
                name: sw.name
                onToggled: IrisOptions.commit(sw.spec, sw.spec.invert ? sw.lit : !sw.lit)
            }
        }
    }

    Component {
        id: rangeTile
        Plate {
            id: range
            readonly property real lo: Number(range.spec?.min ?? 0)
            readonly property real hi: Number(range.spec?.max ?? 1)
            readonly property real step: Number(range.spec?.step ?? 1)
            property real dragged: NaN
            readonly property real value: { Config.revision; return Number.isFinite(range.dragged) ? range.dragged : Number(IrisOptions.currentValue(range.spec ?? {})) }
            controlWidth: root.scrubWidth + Math.round(44 * root.d)
            function snap(raw: real): real {
                const snapped = range.lo + Math.round((raw - range.lo) / range.step) * range.step
                return Number(Math.max(range.lo, Math.min(range.hi, snapped)).toFixed(4))
            }
            IrisSlider {
                id: slider
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: root.scrubWidth
                height: Math.min(implicitHeight, range.height)
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
            IrisLabel {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(38 * root.d)
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                text: range.spec ? Translation.tr(IrisOptions.rangeText(range.spec, range.value)) : ""
            }
        }
    }
    Component {
        id: choiceTile
        Plate {
            id: choice
            readonly property var options: IrisOptions.choicesOf(choice.spec ?? {})
            readonly property var now: { Config.revision; return IrisOptions.currentValue(choice.spec ?? {}) }
            controlWidth: root.choiceTrack(choice.spec ?? {})
            IrisSegmented {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: Math.min(implicitHeight, choice.height - Math.round(6 * root.d))
                accessibleName: Translation.tr(String(choice.spec?.label ?? ""))
                options: choice.options.map(entry => ({ label: Translation.tr(String(entry.label ?? "")), value: entry.value }))
                current: choice.now
                onPicked: value => IrisOptions.commit(choice.spec, value)
            }
        }
    }
}
