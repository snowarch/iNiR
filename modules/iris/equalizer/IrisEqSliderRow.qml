pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style
import qs.modules.iris.equalizer

// One labelled parameter row: name + tabular readout on top, an IrisSlider
// below. Values are normalised to the slider's 0..1; the engine call happens
// through `commit(real)` so the row never assumes who owns the write.
//
// Two things here are deliberately static while a value changes, because
// letting the layout derive them from the value moves the panel:
//
//  - The readout sits in a field as wide as the widest string this row can
//    ever print. A readout that grows with its digits is the only
//    value-dependent geometry in the row: it moves the label's elide boundary
//    on every step, and it is one wrapping label away from moving the row's
//    height, and with it everything below it in the panel.
//  - The drag is owned locally while it lasts, so the slider reads the finger
//    and not the live map. Once it settles the engine's answer takes over, and
//    it is already correct then because setParam paints the optimistic value
//    before the round-trip.
RowLayout {
    id: root

    property string label: ""
    property string unit: ""
    property real minimum: 0
    property real maximum: 1
    property real value: 0
    property bool integer: false
    property bool enabled: true
    property bool dragging: false
    property real dragValue: 0
    signal commit(real next)

    spacing: 0
    opacity: root.enabled ? 1 : 0.45

    // The field's bands are adjusted with the wheel, with up and down, and
    // with Shift for a finer step. The wheel already reached here through
    // IrisSlider, so this is the other half of that model: up and down move
    // the same distance the wheel does.
    //
    // Deliberately no `focus: true` on this row. Qt delivers a key to the item
    // holding focus and then walks up the parent chain, so the handlers below
    // already catch it while the slider inside has the focus — which is the
    // point: the arrows act on the slider you clicked. Asking for focus here
    // as well would be worse than useless, because the band field already takes
    // focus on click, and two items declaring it means the last one wins and
    // the field quietly stops responding to left and right.
    Keys.onUpPressed: event => root.nudge(1, event)
    Keys.onDownPressed: event => root.nudge(-1, event)

    // Dead space kept to the right of the track. The sliders sit across the
    // panel's scroll path, so a wheel gesture made anywhere over a card
    // landed on one and stepped its value without the pointer ever having
    // to be aimed at it. Holding the track back from the right edge means
    // most of the pointer's resting width during a scroll is over nothing.
    //
    // A fraction of the row rather than a fixed pad, because the row's width
    // comes from panelWidth, which spans 380..720 px with the screen. A fixed
    // pad would be a rounding error at the wide end and a different fraction
    // at the narrow one, which is the opposite of what a margin is for.
    //
    // This reduces how often a scroll can reach a slider. It cannot make it
    // impossible while the wheel still adjusts the value, so it is a margin
    // and not a lock.
    // Resolved once, the first time the row has a width, and then held.
    //
    // A live binding on root.width cannot work here. The margin is consumed as
    // Layout.rightMargin by the row's own layout, so every pass of the parent
    // re-dividing the width writes root.width, which re-derives the margin,
    // which dirties that layout again straight after Qt has just run it. Qt
    // gives up with "Detected recursive rearrange. Aborting after two
    // iterations", and a layout abandoned halfway is what makes the panel jump
    // whenever a value changes.
    //
    // The guard is what makes this converge: the write happens once, so there
    // is no cycle left to feed. The number is the same one the binding gave.
    // A later resize leaves the margin at the width the row was built for,
    // which is a few pixels at most and moves nothing until it is reopened.
    property real trackMargin: 0
    onWidthChanged: {
        if (root.trackMargin === 0 && width > 0)
            root.trackMargin = Math.round(width * 0.22)
    }

    // Long enough that a slow snapshot still lands while the finger is down,
    // short enough that letting go hands the row back to the engine at once.
    Timer {
        id: dragSettle
        interval: 180
        onTriggered: root.dragging = false
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Math.round(2 * IrisStyle.density)

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(8 * IrisStyle.density)
            IrisText {
                Layout.fillWidth: true
                text: root.label
                color: IrisStyle.subtext
                font.pixelSize: IrisStyle.typeMeta
                elide: Text.ElideRight
            }
            // Fixed field, readout pinned to its right edge: the label keeps one
            // width instead of one per digit count.
            Item {
                Layout.preferredWidth: Math.ceil(widest.implicitWidth)
                Layout.minimumWidth: Math.ceil(widest.implicitWidth)
                Layout.maximumWidth: Math.ceil(widest.implicitWidth)
                implicitHeight: readout.implicitHeight

                IrisNumber {
                    id: readout
                    anchors.right: parent.right
                    text: IrisEqSpec.formatValue(root.displayValue, root.unit)
                    pixelSize: IrisStyle.typeMeta
                    weight: IrisStyle.weight(Font.DemiBold)
                    color: IrisStyle.text
                }

                // Width probe: the widest string this row can print, measured
                // by the same component that draws the readout, so the pinned
                // width can never disagree with the glyphs it holds.
                IrisNumber {
                    id: widest
                    visible: false
                    text: root.widestText
                    pixelSize: IrisStyle.typeMeta
                    weight: IrisStyle.weight(Font.DemiBold)
                    color: IrisStyle.text
                }
            }
        }

        IrisSlider {
            Layout.fillWidth: true
            Layout.rightMargin: root.trackMargin
            enabled: root.enabled
            // Shift halves the wheel step here, the same way it does on the
            // bands. Off everywhere else, so the other sliders in the shell
            // keep the step they have always had.
            fineStep: true
            value: root.dragging ? root.dragValue : root.normalised
            onMoved: next => {
                const committed = root.fromSlider(next)
                root.dragValue = committed
                root.dragging = true
                dragSettle.restart()
                root.commit(committed)
            }
        }
    }

    readonly property real clamped: Math.max(root.minimum, Math.min(root.maximum, Number(root.value)))
    readonly property real normalised: root.maximum > root.minimum
        ? (root.clamped - root.minimum) / (root.maximum - root.minimum) : 0
    readonly property real displayValue: root.integer ? Math.round(root.clamped) : root.clamped

    // The widest string this row can print. formatValue owns every rule about
    // that string, so each candidate is produced by it rather than rebuilt
    // here. The two range extremes are not enough on their own: a value under
    // 100 keeps one decimal while a whole number loses it, so the widest one
    // is the peak just below the next power of ten ("-99.9" over "-100",
    // "19.9" over "20"), reached from either sign the range allows.
    readonly property real reach: Math.max(Math.abs(root.minimum), Math.abs(root.maximum))
    readonly property real decimalPeak: root.reach >= 100 ? 99.9 : Math.max(0.9, Math.floor(root.reach) - 0.1)
    readonly property var rawCandidates: [root.minimum, root.maximum, root.decimalPeak, -root.decimalPeak]
    readonly property var inRange: root.rawCandidates.filter(v => v >= root.minimum && v <= root.maximum)
    readonly property var rounded: root.inRange.map(v => root.integer ? Math.round(v) : v)
    readonly property var candidates: root.rounded.map(v => IrisEqSpec.formatValue(v, root.unit))
    readonly property string widestText: root.candidates.reduce((a, b) => b.length > a.length ? b : a, Translation.tr("—"))

    // A key press moves the value by the same fraction of the range the wheel
    // does. A band takes 0.5 dB over a 24 dB span, which is 2 % of the
    // range, and a fifth of that with Shift — so a row of 0..250 Hz moves 5 Hz
    // and a row of -12..12 dB moves 0.4 dB. Stated as a fraction of the
    // range rather than as a fixed amount, because the rows do not share a
    // unit and a fixed amount would mean something different on each.
    function nudge(dir: int, event: var): void {
        event.accepted = true
        const span = root.maximum - root.minimum
        if (!root.enabled || span <= 0) return
        const fine = (event.modifiers & Qt.ShiftModifier) !== 0
        const step = span * (fine ? 0.004 : 0.02)
        const committed = root.fromSlider((root.clamped + dir * step - root.minimum) / span)
        root.dragValue = committed
        root.dragging = true
        dragSettle.restart()
        root.commit(committed)
    }

    function fromSlider(next: real): real {
        const raw = root.minimum + Math.max(0, Math.min(1, next)) * (root.maximum - root.minimum)
        return root.integer ? Math.round(raw) : Math.round(raw * 10) / 10
    }
}
