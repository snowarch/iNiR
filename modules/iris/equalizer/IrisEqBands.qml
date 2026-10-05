pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
// For Config, the singleton that owns the spectrum preferences. The
// .widgets sub-module does not re-export it.
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style
import qs.modules.iris.equalizer

// Band EQ columns. Writes route commitGain(slot,v) -> engineIndexAt(slot)
// -> setBandGain; e is assigned BEFORE displayBands sorts, so display
// order never equals engine order. Gains clamp to the engine span.
ColumnLayout {
    id: root

    property bool engineReady: false
    signal requestAttention()

    spacing: Math.round(10 * IrisStyle.density)

    readonly property real d: IrisStyle.density
    readonly property int count: IrisAudio.bandCount
    readonly property var bands: IrisAudio.bands

    property bool range12: true
    readonly property real rangeDb: root.range12 ? 12 : 24
    readonly property real spanDb: root.rangeDb * 2

    // Column pitch follows how many bands are actually on this page, not how
    // many a page could hold. Ten bands divide the field and fill it; four
    // bands take four bands' worth of room and sit centred, instead of being
    // stretched across the whole field or bunched against one edge.
    //
    // Capped at maxColW, because "fill the field" has to stop somewhere: past
    // the natural pitch the frequency label drifts away from its own rail and
    // the row stops reading as a row.
    //
    // Depends on pageSlots, which depends on perPageCap and fieldUsable — never
    // the other way round, or the two bindings would loop.
    readonly property real colW: Math.min(root.maxColW, root.fieldUsable / Math.max(1, root.pageSlots.length))
    readonly property real trackH: Math.round(220 * root.d)
    readonly property real headH: Math.round((14 + 24 + 16 + 14 + 3 * 2 + 6) * root.d)
    readonly property real colsH: root.headH + root.trackH + Math.round(6 * root.d) + Math.round(18 * root.d)
    readonly property real fieldH: root.colsH

    // The spectrum behind the bands. Display only: it touches no audio, so
    // nothing here rebuilds the chain. The defaults mirror the house
    // visualizer, so with no configuration written at all the panel looks like
    // a panel with no spectrum settings, and a missing or unreadable key
    // degrades to that same look instead of breaking the field.
    //
readonly property var spectrumCfg: {
        // Deliberately reads Config.revision, not just Config.options.
        // Config.setNestedValue mutates the options object IN PLACE, so the
        // values do change — but a binding that only reads `Config.options` has
        // nothing that changes to re-evaluate against, because QML cannot see
        // inside a JS object. Reading `revision` (bumped on every write) gives
        // this binding a real dependency, so a change in Settings reaches the
        // panel with no reopen.
const _rev = Config.revision
return Config.options?.iris?.equalizer?.spectrum
}
      readonly property bool spectrumOn: root.spectrumCfg?.enabled !== false
      readonly property string spectrumStyle: String(root.spectrumCfg?.style ?? "capsules")
      readonly property real spectrumOpacity: {
          const asked = Number(root.spectrumCfg?.opacity)
          return isNaN(asked) ? 0.5 : Math.max(0, Math.min(1, asked))
      }

    // -- display order: sort, never trust engine order ---------------------
    // Entry: { e: engine index, f: frequency, g: gain, q: Q }, ascending
    // by f. THE INVARIANT: e is assigned BEFORE out.sort(); every gain
    // write routes commitGain(slot,v) -> engineIndexAt(slot) -> setBandGain.
    readonly property var displayBands: {
        const list = Array.isArray(root.bands) ? root.bands : []
        const out = []
        for (let i = 0; i < list.length; ++i) {
            const q = Number(list[i]?.q ?? IrisEqSpec.bandQDefault)
            out.push({
                e: i,
                f: Number(list[i]?.frequency ?? 0),
                g: Number(list[i]?.gain ?? 0),
                q: Number.isFinite(q) && q > 0 ? q : IrisEqSpec.bandQDefault
            })
        }
        out.sort((a, b) => a.f - b.f)
        return out
    }

    function engineIndexAt(slot: int): int {
        const entry = root.displayBands[slot]
        return entry ? Number(entry.e) : -1
    }
    function slotOfEngine(e: int): int {
        const bands = root.displayBands
        for (let i = 0; i < bands.length; ++i) {
            if (Number(bands[i].e) === Number(e)) return i
        }
        return -1
    }
    function commitGain(slot: int, value: real): void {
        const e = root.engineIndexAt(slot)
        if (e >= 0) IrisAudio.setBandGain(e, value)
    }
    function commitReset(slot: int): void {
        root.commitGain(slot, 0)
    }
    // Band type/mode, keyed by ENGINE index (same e as displayBands). Reads
    // prefer a live engine value, then a local mirror of our own writes
    // (the setters ride a parallel lane, so the echo may lag), then the
    // engine's own default: Bell / RLC (BT). Never render an empty chip.
    property var typeLocal: ({})
    property var modeLocal: ({})
    function bandTypeOf(e: int): string {
        const raw = (root.bands ?? [])[Number(e)]?.type
        if (typeof raw === "string" && IrisEqSpec.bandTypes.includes(raw)) return raw
        const local = root.typeLocal[String(Number(e))]
        if (typeof local === "string" && IrisEqSpec.bandTypes.includes(local)) return local
        return "Bell"
    }
    function bandModeOf(e: int): string {
        const raw = (root.bands ?? [])[Number(e)]?.mode
        if (typeof raw === "string" && IrisEqSpec.bandModes.includes(raw)) return raw
        const local = root.modeLocal[String(Number(e))]
        if (typeof local === "string" && IrisEqSpec.bandModes.includes(local)) return local
        return "RLC (BT)"
    }
    function gainInertFor(e: int): bool {
        return IrisEqSpec.bandGainInert(root.bandTypeOf(e))
    }
    function commitBandType(e: int, name: string): void {
        if (e < 0) return
        const next = Object.assign({}, root.typeLocal)
        next[String(e)] = name
        root.typeLocal = next
        if (typeof IrisAudio.setBandType === "function") IrisAudio.setBandType(e, name)
    }
    function commitBandMode(e: int, name: string): void {
        if (e < 0) return
        const next = Object.assign({}, root.modeLocal)
        next[String(e)] = name
        root.modeLocal = next
        if (typeof IrisAudio.setBandMode === "function") IrisAudio.setBandMode(e, name)
    }
    function nudgeGain(slot: int, delta: real): void {
        const entry = root.displayBands[slot]
        if (!entry) return
        const next = Math.max(-24, Math.min(24, Number(entry.g ?? 0) + Number(delta)))
        root.commitGain(slot, Math.round(next * 100) / 100)
    }
    function dragGain(startGain: real, pressY: real, y: real, H: real): real {
        const next = Number(startGain) + (Number(pressY) - Number(y)) / Math.max(1, Number(H)) * root.spanDb
        return Math.round(Math.max(-root.rangeDb, Math.min(root.rangeDb, next)) * 100) / 100
    }

    property int selectedSlot: -1
    property int popEngine: -1
    readonly property int popSlot: root.popEngine >= 0 ? root.slotOfEngine(root.popEngine) : -1
    function togglePop(slot: int): void {
        const e = root.engineIndexAt(slot)
        if (e < 0) return
        root.selectedSlot = slot
        const p = root.pageOf(slot)
        if (p >= 0) root.currentPage = p
        root.popEngine = root.popEngine === e ? -1 : e
    }
    function closePopover(): void {
        root.popEngine = -1
    }

    // Paging: greedy fill, so a page holds as many columns as fit and only
    // the last page is short. Rule: perPageCap = columns that fit (min 4,
    // max pageColumns), pages = ceil(n/perPageCap), page p starts at
    // p*perPageCap. Gives [10] / [10,6] / [10,10,10,2] for 10/16/32.
    property int currentPage: 0
    // Dead margin to both sides of the band row, so scrolling the panel with
    // the pointer near the edges lands on nothing instead of on a band.
    //
    // The field IS a scroll margin, and it has to be. The bands take the wheel
    // on purpose — a wheel over one nudges that band — so the whole width of
    // the field swallows the scroll and the panel will not move. The empty
    // strip either side is the only place left to scroll from, which is why
    // this cannot be trimmed to a pad: a few pixels give the pointer nowhere
    // to aim during a scroll, and the panel can only be scrolled after parking
    // the mouse somewhere else.
    //
    // It is a fraction of the field so it stays usable as the panel is resized,
    // and it is taken off both sides so rowX still centres the row: a strip on
    // one side only would push the bands off centre.
    //
    // minColW is how narrow a band may get before it stops being comfortable
    // to grab. maxColW is how wide one may get before its frequency label
    // drifts away from its own rail. Between them the row fills the field when
    // the bands can fill it, and takes only the room the bands need when they
    // cannot.
    //
    // rowX already centres the row, so a short page centres itself and needs
    // no geometry of its own for that.
    //
    // The wheel still nudges whichever band is under the pointer inside the
    // row. This is a margin, not a lock.
    readonly property real fieldMargin: Math.round(fieldRoot.width * 0.04)
    readonly property real fieldUsable: Math.max(1, fieldRoot.width - 2 * root.fieldMargin)
    readonly property real minColW: Math.round(56 * root.d)
    readonly property real maxColW: Math.round(84 * root.d)
    readonly property int pageColumns: 10
    readonly property int perPageCap: Math.max(4, Math.min(root.pageColumns, Math.floor(root.fieldUsable / Math.max(1, root.minColW))))
    readonly property int pageCount: {
        const n = root.displayBands.length
        if (n === 0) return 0
        return Math.max(1, Math.ceil(n / Math.min(n, root.perPageCap)))
    }
    function pageStartOf(p: int): int {
        const n = root.displayBands.length
        const pages = Math.max(1, root.pageCount)
        const pp = Math.max(0, Math.min(pages - 1, Number(p)))
        return Math.min(n, pp * root.perPageCap)
    }
    function pageSizeOf(p: int): int {
        const n = root.displayBands.length
        const pages = Math.max(1, root.pageCount)
        const pp = Math.max(0, Math.min(pages - 1, Number(p)))
        return Math.max(0, Math.min(root.perPageCap, n - root.pageStartOf(pp)))
    }
    function pageOf(slot: int): int {
        const n = root.displayBands.length
        for (let p = 0; p < root.pageCount; ++p) {
            if (slot >= root.pageStartOf(p) && slot < root.pageStartOf(p) + root.pageSizeOf(p)) return p
        }
        return n > 0 ? 0 : -1
    }
    readonly property var pageSlots: {
        const out = []
        const s = root.pageStartOf(root.currentPage)
        const e = Math.min(root.displayBands.length, s + root.pageSizeOf(root.currentPage))
        for (let i = s; i < e; ++i) out.push(i)
        return out
    }
    readonly property var pageOptions: {
        const out = []
        for (let p = 0; p < root.pageCount; ++p) {
            const s = root.pageStartOf(p)
            out.push({ value: p, label: Translation.tr("%1–%2").arg(s + 1).arg(s + root.pageSizeOf(p)) })
        }
        return out
    }
    readonly property real rowX: Math.max(0, (fieldRoot.width - root.pageSlots.length * root.colW) / 2)

    function yOfGain(g: real, H: real): real {
        const t = (root.rangeDb - Number(g)) / root.spanDb
        return Math.max(0, Math.min(H, t * Math.max(1, H)))
    }

    readonly property var gridGains: root.range12 ? [6, -6] : [18, 12, 6, -6, -12, -18]

    // Keyboard: arrows drive the selected band (Up/Down = gain, same
    // 0.5 / 0.1 dB steps as the wheel; Left/Right = move selection across
    // page boundaries, turning the page). The panel holds keyboard focus
    // while open, and niri binds arrows only with Mod, so bare arrows and
    // bare Shift+arrows reach us. Escape is never touched: close works.
    function arrowGain(event: var, dir: int): void {
        event.accepted = true
        if (root.selectedSlot < 0 || root.selectedSlot >= root.displayBands.length) {
            root.selectedSlot = 0
            return
        }
        if (root.gainInertFor(root.engineIndexAt(root.selectedSlot))) return
        const fine = (event.modifiers & Qt.ShiftModifier) !== 0
        root.nudgeGain(root.selectedSlot, dir * (fine ? 0.1 : 0.5))
    }
    function arrowStep(event: var, dir: int): void {
        event.accepted = true
        const n = root.displayBands.length
        if (n === 0) return
        const next = root.selectedSlot < 0 ? 0
            : Math.max(0, Math.min(n - 1, root.selectedSlot + dir))
        root.selectedSlot = next
        root.revealSlot(next)
    }
    function revealSlot(slot: int): void {
        const p = root.pageOf(slot)
        if (p >= 0) root.currentPage = p
    }
    property int pendingCount: -1
    readonly property bool rebuilding: root.pendingCount >= 0

    Connections {
        target: IrisAudio
        function onStateRefreshed(): void {
            if (root.pendingCount >= 0 && IrisAudio.bandCount === root.pendingCount) root.pendingCount = -1
        }
        function onBandsChanged(): void {
            if (root.pendingCount >= 0 && IrisAudio.bandCount === root.pendingCount) root.pendingCount = -1
        }
    }
    onCountChanged: {
        if (root.pendingCount >= 0 && root.count === root.pendingCount) root.pendingCount = -1
        root.selectedSlot = -1
        root.currentPage = 0
        root.typeLocal = ({})
        root.modeLocal = ({})
        root.closePopover()
    }
    onDisplayBandsChanged: {
        if (root.popEngine >= 0 && root.slotOfEngine(root.popEngine) < 0) root.closePopover()
        if (root.selectedSlot >= root.displayBands.length) root.selectedSlot = -1
        if (root.currentPage >= root.pageCount) root.currentPage = Math.max(0, root.pageCount - 1)
        if (root.popEngine >= 0) {
            const p = root.pageOf(root.popSlot)
            if (p >= 0 && p !== root.currentPage) root.currentPage = p
        }
    }

    // -- header: one symmetric row, BANDS left, SCALE right ----------------
    RowLayout {
        Layout.fillWidth: true
        spacing: 0
        Item { Layout.fillWidth: true }
        RowLayout {
            spacing: Math.round(8 * root.d)
            IrisText {
                text: Translation.tr("BANDS")
                role: IrisText.Eyebrow
            }
            SegCtl {
                options: [{ value: 10, label: "10" }, { value: 15, label: "15" }, { value: 32, label: "32" }]
                segW: Math.round(52 * root.d)
                current: root.rebuilding ? root.pendingCount : root.count
                enabled: root.engineReady && !root.rebuilding
                accessibleName: Translation.tr("Band count")
                onPicked: value => {
                    if (!root.engineReady) return
                    const wanted = Number(value)
                    if (wanted === IrisAudio.bandCount || wanted === root.pendingCount) return
                    root.pendingCount = wanted
                    IrisAudio.setBandCount(wanted)
                }
            }
        }
        Item { Layout.preferredWidth: Math.round(28 * root.d) }
        RowLayout {
            spacing: Math.round(8 * root.d)
            IrisText {
                text: Translation.tr("SCALE")
                role: IrisText.Eyebrow
            }
            SegCtl {
                options: [{ value: 12, label: Translation.tr("±12 dB") }, { value: 24, label: Translation.tr("±24 dB") }]
                segW: Math.round(68 * root.d)
                current: root.range12 ? 12 : 24
                enabled: root.engineReady && !root.rebuilding
                accessibleName: Translation.tr("Display range")
                onPicked: value => { root.range12 = Number(value) === 12 }
            }
        }
        Item { Layout.fillWidth: true }
    }

    // Page stepper: one segment per page, labelled with its 1-based slot
    // range. Always laid out (single disabled segment when everything
    // fits) so the row never pops in late and reflows the panel.
    RowLayout {
        Layout.fillWidth: true
        spacing: 0
        Item { Layout.fillWidth: true }
        RowLayout {
            spacing: Math.round(8 * root.d)
            IrisText {
                text: Translation.tr("EQUALIZER")
                role: IrisText.Eyebrow
            }
            IrisSwitch {
                on: !IrisAudio.equalizerBypass
                name: Translation.tr("Equalizer")
                enabled: root.engineReady && !root.rebuilding
                onToggled: IrisAudio.setEqualizerParam("bypass", !IrisAudio.equalizerBypass)
            }
            IrisText {
                text: !root.engineReady || IrisAudio.equalizerBypass ? Translation.tr("Off") : Translation.tr("On")
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeFootnote
            }
        }
        Item { Layout.preferredWidth: Math.round(28 * root.d) }
        RowLayout {
            spacing: Math.round(8 * root.d)
            IrisText {
                text: Translation.tr("PAGE")
                role: IrisText.Eyebrow
            }
            SegCtl {
                options: root.pageCount > 1 ? root.pageOptions
                    : [{ value: 0, label: root.displayBands.length > 0 ? Translation.tr("1–%1").arg(root.displayBands.length) : Translation.tr("–") }]
                segW: Math.round(64 * root.d)
                current: root.currentPage
                enabled: root.engineReady && !root.rebuilding && root.pageCount > 1
                accessibleName: Translation.tr("Band page")
                onPicked: value => { root.currentPage = Number(value) }
            }
        }
        Item { Layout.fillWidth: true }
    }

    // -- the field: paged columns on one surface, no chrome ----------------
    Item {
        id: fieldRoot
        objectName: "eqFieldCard"
        Layout.fillWidth: true
        Layout.preferredHeight: root.fieldH
        clip: true
        focus: true
        Keys.onUpPressed: event => root.arrowGain(event, +1)
        Keys.onDownPressed: event => root.arrowGain(event, -1)
        Keys.onLeftPressed: event => root.arrowStep(event, -1)
        Keys.onRightPressed: event => root.arrowStep(event, +1)

        // Background spectrum: one house IrisVisualizer behind the columns.
        //
        // It is never stretched to fill the field: stretching this item does
        // not spread its lanes, it just bunches them at the left edge. Width
        // therefore has to come from the lane count, and the house default is
        // too small to read at all — `IrisStyle.visualizerBars` is clamped to
        // max(3, min(9, …)) and 9 lanes of 3·d with 2·d gaps is 23·d wide,
        // which read as a dot floating in the middle of a row of 64·d columns.
        //
        // So the lanes are derived from the row they have to sit behind:
        // one lane per 5·d of band row, which is exactly the width the default
        // style gives a lane plus its gap. It follows the band count (10/15/32),
        // the page and the density without any of those being hardcoded here.
        // The floor keeps it sane when the engine is down and the row is empty.
        //
        // running rests with the engine, so cava and the live layer cost
        // nothing while the bands are missing or rebuilding.
        IrisVisualizer {
            id: eqSpectrum
            readonly property real rowW: root.pageSlots.length * root.colW
            // Left edge of the row, so the spectrum spans exactly the columns.
            // bars is floored to fit inside rowW, so starting at rowX lands the
            // last bar at or before the last column.
            x: Math.round(root.rowX)
            // Bottom of the band area, not floating in the middle of it: the lanes rise
            // from the floor of the track so they read as the ground the
            // columns stand on. Still inside the field and still painted before
            // the columns, so the sliders stay on top of it.
            y: Math.round(root.headH + root.trackH - height - Math.round(6 * root.d))
            running: root.engineReady && !root.rebuilding && root.pageSlots.length > 0
            visible: root.spectrumOn
            style: root.spectrumStyle
            opacity: root.spectrumOpacity
            tint: IrisStyle.textTertiary
            bars: Math.max(24, Math.floor((eqSpectrum.rowW + 2 * root.d) / (5 * root.d)))
            barHeight: Math.round(72 * root.d)
        }

        Repeater {
            model: root.engineReady ? root.pageSlots : []
            BandColumn {
                required property int modelData
                required property int index
                slot: modelData
                x: Math.round(root.rowX + index * root.colW)
                y: 0
            }
        }

        MouseArea {
            anchors.fill: parent
            z: 15
            visible: root.popEngine >= 0
            hoverEnabled: false
            cursorShape: Qt.ArrowCursor
            onPressed: mouse => {
                mouse.accepted = true
                root.closePopover()
            }
        }

        // Gear popover: Band / Frequency / Q.
        Rectangle {
            id: bandPop
            objectName: "eqBandPop"
            z: 20
            visible: root.popEngine >= 0 && root.popSlot >= 0
            readonly property real anchorCX: {
                const s = root.popSlot - root.pageStartOf(root.currentPage)
                return root.rowX + (s + 0.5) * root.colW
            }
            x: Math.max(4, Math.min(fieldRoot.width - width - 4, anchorCX - width / 2))
            y: Math.round(46 * root.d)
            width: Math.round(216 * root.d)
            height: popCol.implicitHeight + Math.round(20 * root.d)
            radius: Math.round(10 * root.d) // iris-literal: compact popover card floating over the band field; the type scale's radii are sized for panels and cards, not for a 216px card
            color: IrisStyle.surfaceHighestOpaque
            border.width: 1
            border.color: IrisStyle.hairline

            function popEntry(): var {
                return root.displayBands[root.popSlot] ?? null
            }
            function popEngineIndex(): int {
                const e = bandPop.popEntry()
                return e ? Number(e.e) : -1
            }

            ColumnLayout {
                id: popCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Math.round(10 * root.d)
                spacing: Math.round(6 * root.d)

                IrisText {
                    Layout.fillWidth: true
                    text: root.popSlot >= 0 ? Translation.tr("Band %1 · %2").arg(String(root.popSlot + 1).padStart(2, "0")).arg(root.bandTypeOf(bandPop.popEngineIndex())) : Translation.tr("Band")
                    color: IrisStyle.text
                    font.pixelSize: IrisStyle.typeLabel
                    font.weight: IrisStyle.weight(Font.DemiBold)
                }
                IrisText {
                    Layout.fillWidth: true
                    text: {
                        const e = bandPop.popEntry()
                        return e ? root.freqLabelFor(e) : ""
                    }
                    color: IrisStyle.muted
                    font.pixelSize: IrisStyle.typeFootnote
                    font.family: IrisStyle.fontNumbers
                    font.features: { "tnum": 1 }
                }
                IrisSlider {
                    Layout.fillWidth: true
                    enabled: root.engineReady
                    value: {
                        const e = bandPop.popEntry()
                        const f = e ? Number(e.f) : 0
                        if (!Number.isFinite(f) || f <= 0) return 0
                        return Math.max(0, Math.min(1, (Math.log(f) - Math.log(20)) / (Math.log(20000) - Math.log(20))))
                    }
                    onMoved: next => {
                        const e = bandPop.popEngineIndex()
                        if (e >= 0) IrisAudio.setBandFrequency(e, 20 * Math.pow(1000, Math.max(0, Math.min(1, next))))
                    }
                }
                IrisText {
                    Layout.fillWidth: true
                    text: {
                        const e = bandPop.popEntry()
                        return e ? Translation.tr("Q %1").arg(Number(e.q).toFixed(2)) : "Q"
                    }
                    color: IrisStyle.textTertiary
                    font.pixelSize: IrisStyle.typeFootnote
                    font.family: IrisStyle.fontNumbers
                    font.features: { "tnum": 1 }
                }
                IrisSlider {
                    Layout.fillWidth: true
                    enabled: root.engineReady
                    value: {
                        const e = bandPop.popEntry()
                        const q = e ? Number(e.q) : IrisEqSpec.bandQDefault
                        return Math.max(0, Math.min(1, (q - 0.5) / 9.5))
                    }
                    onMoved: next => {
                        const e = bandPop.popEngineIndex()
                        if (e >= 0) IrisAudio.setBandQ(e, Math.round((0.5 + Math.max(0, Math.min(1, next)) * 9.5) * 100) / 100)
                    }
                }
                IrisText {
                    Layout.fillWidth: true
                    Layout.topMargin: Math.round(4 * root.d)
                    text: Translation.tr("Type")
                    color: IrisStyle.textTertiary
                    font.pixelSize: IrisStyle.typeFootnote
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: Math.round(6 * root.d)
                    Repeater {
                        model: IrisEqSpec.bandTypes
                        IrisChip {
                            required property var modelData
                            label: String(modelData)
                            selected: root.bandTypeOf(bandPop.popEngineIndex()) === String(modelData)
                            enabled: root.engineReady
                            onClicked: root.commitBandType(bandPop.popEngineIndex(), String(modelData))
                        }
                    }
                }
                IrisText {
                    Layout.fillWidth: true
                    visible: root.gainInertFor(bandPop.popEngineIndex())
                    text: Translation.tr("Gain does nothing for this filter.")
                    color: IrisStyle.muted
                    font.pixelSize: IrisStyle.typeFootnote
                    wrapMode: Text.WordWrap
                }
                IrisText {
                    Layout.fillWidth: true
                    text: Translation.tr("Mode")
                    color: IrisStyle.textTertiary
                    font.pixelSize: IrisStyle.typeFootnote
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: Math.round(6 * root.d)
                    Repeater {
                        model: IrisEqSpec.bandModes
                        IrisChip {
                            required property var modelData
                            label: String(modelData)
                            selected: root.bandModeOf(bandPop.popEngineIndex()) === String(modelData)
                            enabled: root.engineReady && !IrisEqSpec.bandModeDisabled(root.bandTypeOf(bandPop.popEngineIndex()), String(modelData))
                            onClicked: root.commitBandMode(bandPop.popEngineIndex(), String(modelData))
                        }
                    }
                }
                IrisText {
                    Layout.fillWidth: true
                    visible: IrisEqSpec.bandModeNulled(root.bandTypeOf(bandPop.popEngineIndex()))
                    text: Translation.tr("BWC and LRX do not affect Resonance and Notch.")
                    color: IrisStyle.muted
                    font.pixelSize: IrisStyle.typeFootnote
                    wrapMode: Text.WordWrap
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: !root.engineReady
            radius: Math.round(12 * root.d) // iris-literal: empty-state card inset in the field, deliberately one step under the field's own card radius
            color: IrisStyle.surfaceHighOpaque
            ColumnLayout {
                anchors.centerIn: parent
                spacing: Math.round(6 * root.d)
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "graphic_eq"
                    iconSize: Math.round(28 * root.d)
                    color: IrisStyle.textTertiary
                }
                IrisText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("The bands appear when the engine answers")
                    color: IrisStyle.muted
                    font.pixelSize: IrisStyle.typeFootnote
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: root.engineReady && root.bands.length === 0
            radius: Math.round(12 * root.d) // iris-literal: sibling of the "bands appear" empty state above; the pair must share one radius or the swap reads as two different cards
            color: "transparent"
            ColumnLayout {
                anchors.centerIn: parent
                spacing: Math.round(8 * root.d)
                IrisText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("No bands arrived yet")
                    color: IrisStyle.text
                    font.pixelSize: IrisStyle.typeLabel
                    font.weight: IrisStyle.weight(Font.DemiBold)
                }
                IrisText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("The engine is up but sent no bands. Ask it again.")
                    color: IrisStyle.muted
                    font.pixelSize: IrisStyle.typeFootnote
                    wrapMode: Text.WordWrap
                }
                IrisButton {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Ask again")
                    buttonRadius: height / 2
                    onClicked: IrisAudio.refresh()
                }
            }
        }
    }

    IrisText {
        Layout.fillWidth: true
        visible: root.rebuilding
        text: Translation.tr("New band layout is loading — sound pauses for a moment, then returns.")
        color: IrisStyle.secondaryAccent
        font.pixelSize: IrisStyle.typeFootnote
        wrapMode: Text.WordWrap
    }

    // -- footer: flatten (text button) + explicit peak readout -----------
    // Flatten walks the ENGINE list in engine order — never the sorted
    // display copy — so every index it writes is already correct.
    RowLayout {
        Layout.fillWidth: true
        spacing: Math.round(10 * root.d)
        IrisButton {
            text: ""
            quiet: true
            buttonRadius: height / 2
            enabled: root.engineReady && !root.rebuilding
            Layout.preferredWidth: flatLabel.implicitWidth + Math.round(16 * root.d)
            Accessible.name: Translation.tr("Reset all band gains to zero")
            onClicked: {
                const list = IrisAudio.bands
                for (let i = 0; i < list.length; ++i) IrisAudio.setBandGain(i, 0)
            }
            IrisText {
                id: flatLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr("Flatten")
                color: parent.enabled ? IrisStyle.accent : IrisStyle.muted
                font.pixelSize: IrisStyle.typeLabel
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
        }
        Item { Layout.fillWidth: true }
        IrisText {
            text: root.peakHint
            color: IrisStyle.muted
            font.pixelSize: IrisStyle.typeFootnote
            font.family: IrisStyle.fontNumbers
            font.features: { "tnum": 1 }
        }
    }

    function peakFmt(v: real): string {
        const n = Number(v)
        return (n >= 0 ? "+" : "") + n.toFixed(1)
    }
    readonly property string peakHint: {
        if (!root.engineReady || root.bands.length === 0) return ""
        let hi = 0, lo = 0
        for (const band of root.bands) {
            const g = Number(band.gain ?? 0)
            hi = Math.max(hi, g)
            lo = Math.min(lo, g)
        }
        if (Math.abs(hi) < 0.05 && Math.abs(lo) < 0.05) return Translation.tr("Flat")
        return Translation.tr("Peak %1 / %2 dB").arg(root.peakFmt(hi)).arg(root.peakFmt(lo))
    }

    IrisEqSliderRow {
        Layout.fillWidth: true
        label: Translation.tr("Input gain")
        unit: "dB"
        minimum: -36
        maximum: 36
        value: root.inGain
        enabled: root.engineReady
        onCommit: next => { root.inGain = next; IrisAudio.setEqualizerParam("inputGain", next) }
    }
    IrisEqSliderRow {
        Layout.fillWidth: true
        label: Translation.tr("Output gain")
        unit: "dB"
        minimum: -36
        maximum: 36
        value: root.outGain
        enabled: root.engineReady
        onCommit: next => { root.outGain = next; IrisAudio.setEqualizerParam("outputGain", next) }
    }

    property real inGain: 0
    property real outGain: 0

    // Frequencies in one exact scheme, never mixed: "32 Hz", "250 Hz",
    // "1.0 kHz", "16.0 kHz". Tabular so columns never jitter.
    function freqLabelFor(entry: var): string {
        const hz = Number(entry?.f ?? 0)
        if (!Number.isFinite(hz) || hz <= 0) return Translation.tr("#%1").arg(Number(entry?.e ?? 0) + 1)
        if (hz >= 1000) return Translation.tr("%1 kHz").arg((hz / 1000).toFixed(1))
        return Translation.tr("%1 Hz").arg(Math.round(hz))
    }
    function valueFmt(g: real): string {
        const r = Math.round(Number(g) * 100) / 100
        return (r < 0 ? "-" : "+") + Math.abs(r).toFixed(2)
    }
    function chipFmt(g: real): string {
        const r = Math.round(Number(g) * 100) / 100
        return Translation.tr("%1 dB").arg((r < 0 ? "-" : "+") + Math.abs(r).toFixed(2))
    }

    // Local segmented control: quiet track, accent pill. Shared
    // IrisSegmented lifts a neutral thumb; the selectors here want the
    // active segment itself to be the accent pill.
    component SegCtl: Item {
        id: seg
        property var options: []
        property var current
        property bool enabled: true
        property real segW: 56
        property string accessibleName: ""
        signal picked(var value)

        readonly property int selectedIndex: {
            for (let i = 0; i < seg.options.length; ++i) {
                if (seg.options[i].value === seg.current) return i
            }
            return -1
        }
        implicitWidth: seg.options.length * seg.segW + Math.round(8 * IrisStyle.density)
        implicitHeight: Math.round(28 * IrisStyle.density)
        opacity: seg.enabled ? 1 : 0.45

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: IrisStyle.surfaceHighOpaque
            border.width: 1
            border.color: IrisStyle.hairline
        }
        Rectangle {
            visible: seg.selectedIndex >= 0
            x: Math.round(4 * IrisStyle.density) + Math.max(0, seg.selectedIndex) * seg.segW
            y: Math.round(4 * IrisStyle.density)
            width: seg.segW
            height: parent.height - Math.round(8 * IrisStyle.density)
            radius: height / 2
            color: seg.enabled ? IrisStyle.accent : IrisStyle.muted
            Behavior on x { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
        }
        Row {
            anchors.fill: parent
            anchors.margins: Math.round(4 * IrisStyle.density)
            Repeater {
                model: seg.options
                MouseArea {
                    required property var modelData
                    required property int index
                    width: seg.segW
                    height: parent.height
                    enabled: seg.enabled
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    activeFocusOnTab: true
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: (seg.accessibleName.length > 0 ? seg.accessibleName + ": " : "") + String(modelData.label ?? "")
                    Accessible.checked: seg.selectedIndex === index
                    Keys.onSpacePressed: seg.picked(modelData.value)
                    Keys.onReturnPressed: seg.picked(modelData.value)
                    onClicked: seg.picked(modelData.value)
                    IrisText {
                        anchors.centerIn: parent
                        text: String(parent.modelData.label ?? "")
                        color: seg.selectedIndex === parent.index ? IrisStyle.inkOnAccent : IrisStyle.muted
                        font.pixelSize: IrisStyle.typeFootnote
                        font.weight: IrisStyle.weight(Font.DemiBold)
                    }
                }
            }
        }
    }

    // -- one band column ---------------------------------------------------
    component BandColumn: Item {
        id: col
        objectName: "eqBandColumn"
        property int slot: -1

        readonly property var entry: root.displayBands[col.slot] ?? ({ e: -1, f: 0, g: 0, q: 4.36 })
        readonly property real gain: Number(col.entry.g ?? 0)
        readonly property real frequency: Number(col.entry.f ?? 0)
        readonly property int engineIndex: Number(col.entry.e ?? -1)
        readonly property string bandType: root.bandTypeOf(col.engineIndex)
        readonly property bool gainInert: IrisEqSpec.bandGainInert(col.bandType)
        readonly property bool bandOff: col.bandType === "Off"
        readonly property bool selected: root.selectedSlot === col.slot
        property bool held: false

        width: root.colW
        height: root.colsH

        IrisText {
            x: 0
            y: 0
            width: col.width
            height: Math.round(14 * root.d)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: String(col.slot + 1).padStart(2, "0")
            color: col.selected ? IrisStyle.accent : IrisStyle.textTertiary
            font.pixelSize: IrisStyle.typeFootnote
            font.family: IrisStyle.fontNumbers
            font.features: { "tnum": 1 }
        }
        Rectangle {
            x: Math.round((col.width - width) / 2)
            y: Math.round(16 * root.d)
            width: Math.round(24 * root.d)
            height: width
            radius: Math.round(6 * root.d) // iris-literal: 24px gear hit target; squarer than the type scale's small radii, so the hover fill reads as a button and not as a chip
            color: gearMouse.containsMouse ? IrisStyle.fillQuiet : "transparent"
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
            MaterialSymbol {
                anchors.centerIn: parent
                text: "settings"
                iconSize: Math.round(14 * root.d)
                color: gearMouse.containsMouse ? IrisStyle.subtext : IrisStyle.muted
            }
            MouseArea {
                id: gearMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.togglePop(col.slot)
            }
            Accessible.role: Accessible.Button
            Accessible.name: Translation.tr("Band %1 settings").arg(String(col.slot + 1).padStart(2, "0"))
        }
        IrisText {
            x: 0
            y: Math.round(42 * root.d)
            width: col.width
            height: Math.round(16 * root.d)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.freqLabelFor(col.entry)
            color: col.selected ? IrisStyle.text : IrisStyle.subtext
            font.pixelSize: IrisStyle.typeLabel
            font.weight: IrisStyle.weight(Font.Medium)
            font.family: IrisStyle.fontNumbers
            font.features: { "tnum": 1 }
            elide: Text.ElideNone
            clip: false
        }
        IrisText {
            x: 0
            y: Math.round(58 * root.d)
            width: col.width
            height: Math.round(14 * root.d)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: Translation.tr("Q %1").arg(Number(col.entry.q ?? IrisEqSpec.bandQDefault).toFixed(2))
            color: IrisStyle.textTertiary
            font.pixelSize: IrisStyle.typeFootnote
            font.family: IrisStyle.fontNumbers
            font.features: { "tnum": 1 }
            elide: Text.ElideNone
            clip: false
        }

        readonly property real trackTop: root.headH
        Item {
            id: trackZone
            x: 0
            y: col.trackTop
            width: col.width
            height: root.trackH
            opacity: col.gainInert ? 0.45 : 1

            Rectangle {
                x: Math.round((parent.width - width) / 2)
                y: 0
                width: Math.round(4 * root.d)
                height: parent.height
                radius: width / 2
                color: IrisStyle.accentContainer
            }
            Rectangle {
                readonly property real yZero: root.yOfGain(0, trackZone.height)
                readonly property real yVal: root.yOfGain(col.gain, trackZone.height)
                x: Math.round((parent.width - width) / 2)
                width: Math.round(4 * root.d)
                y: Math.min(yZero, yVal)
                height: Math.max(0, Math.abs(yVal - yZero))
                radius: width / 2
                color: col.gainInert ? IrisStyle.muted : IrisStyle.accent
            }
            Repeater {
                model: root.gridGains
                Rectangle {
                    required property int modelData
                    x: Math.round((trackZone.width - width) / 2)
                    width: Math.round(9 * root.d)
                    y: Math.round(root.yOfGain(modelData, trackZone.height))
                    height: 1
                    color: IrisStyle.subtext
                    opacity: 0.5
                }
            }
            Rectangle {
                x: Math.round((trackZone.width - width) / 2)
                width: Math.round(11 * root.d)
                y: Math.round(root.yOfGain(0, trackZone.height))
                height: 1
                color: IrisStyle.subtext
            }
            Rectangle {
                id: knob
                objectName: "eqKnob"
                readonly property real cy: Math.max(width / 2, Math.min(trackZone.height - width / 2,
                    root.yOfGain(col.gain, trackZone.height)))
                readonly property bool big: col.selected || col.held
                x: Math.round((trackZone.width - width) / 2)
                y: Math.round(cy - height / 2)
                width: Math.round((big ? 14 : 12) * root.d)
                height: width
                radius: width / 2
                color: col.gainInert ? IrisStyle.muted : IrisStyle.accent
                Behavior on width { NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
            }

            Rectangle {
                visible: col.held
                readonly property string chipText: root.chipFmt(col.gain)
                x: Math.max(0, Math.min(trackZone.width - width,
                    Math.round(knob.x + knob.width / 2 - width / 2)))
                y: Math.max(-Math.round(22 * root.d), knob.y - height - Math.round(4 * root.d))
                width: chipLabel.implicitWidth + Math.round(14 * root.d)
                height: Math.round(20 * root.d)
                radius: height / 2
                color: IrisStyle.surfaceHighestOpaque
                border.width: 1
                border.color: IrisStyle.borderStrong
                IrisText {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: parent.chipText
                    color: IrisStyle.text
                    font.pixelSize: IrisStyle.typeFootnote
                    font.family: IrisStyle.fontNumbers
                    font.features: { "tnum": 1 }
                }
            }

            MouseArea {
                id: dragMouse
                anchors.fill: parent
                enabled: !col.gainInert
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                property real pressY: 0
                property real pressGain: 0
                property bool moved: false
                onPressed: mouse => {
                    col.held = true
                    fieldRoot.forceActiveFocus()
                    dragMouse.pressY = mouse.y
                    dragMouse.pressGain = col.gain
                    dragMouse.moved = false
                }
                onPositionChanged: mouse => {
                    if (!pressed) return
                    if (Math.abs(mouse.y - dragMouse.pressY) > 3) dragMouse.moved = true
                    if (!dragMouse.moved) return
                    root.commitGain(col.slot, root.dragGain(dragMouse.pressGain, dragMouse.pressY, mouse.y, trackZone.height))
                }
                onReleased: {
                    col.held = false
                    if (!dragMouse.moved) root.selectedSlot = col.slot
                }
                onCanceled: {
                    col.held = false
                }
                onDoubleClicked: root.commitReset(col.slot)
            }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                enabled: !col.gainInert
                onWheel: event => {
                    const raw = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y * 4
                    if (raw === 0) return
                    const fine = (event.modifiers & Qt.ShiftModifier) !== 0
                    root.nudgeGain(col.slot, raw / 120 * (fine ? 0.1 : 0.5))
                    event.accepted = true
                }
            }
        }

        IrisText {
            x: 0
            y: col.trackTop + root.trackH + Math.round(6 * root.d)
            width: col.width
            height: Math.round(18 * root.d)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: col.bandOff ? Translation.tr("Off") : col.gainInert ? Translation.tr("—") : root.valueFmt(col.gain)
            color: col.gainInert ? IrisStyle.muted : col.selected ? IrisStyle.accent : IrisStyle.muted
            font.pixelSize: IrisStyle.typeLabel
            font.weight: IrisStyle.weight(Font.Medium)
            font.family: IrisStyle.fontNumbers
            font.features: { "tnum": 1 }
            elide: Text.ElideNone
            clip: false
        }
        Accessible.role: Accessible.Slider
        Accessible.name: col.bandOff ? Translation.tr("%1 band, off").arg(root.freqLabelFor(col.entry))
            : col.gainInert ? Translation.tr("%1 band, gain disabled for %2").arg(root.freqLabelFor(col.entry)).arg(col.bandType)
            : Translation.tr("%1 band").arg(root.freqLabelFor(col.entry))
    }
}
