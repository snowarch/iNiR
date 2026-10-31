pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
// A value in a widget's quick controls: its name and figure on one line, the slider under it.
// `moved` fires while dragging (preview), `committed` once on release.
ColumnLayout {
    id: root

    property string title: ""
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property string unit: ""
    property var format: null
    signal moved(real value)
    signal committed(real value)

    readonly property var look: DesktopWidgetLook.look
    readonly property real d: root.look.density
    readonly property real span: Math.max(0.0001, root.to - root.from)
    property real live: NaN
    readonly property real shown: Number.isNaN(root.live) ? root.value : root.live

    function snap(v: real): real {
        const stepped = root.from + Math.round((v - root.from) / root.stepSize) * root.stepSize
        return Math.max(root.from, Math.min(root.to, Math.round(stepped * 1000) / 1000))
    }
    function label(v: real): string {
        return typeof root.format === "function" ? root.format(v) : Math.round(v) + root.unit
    }

    Layout.fillWidth: true
    spacing: Math.round(6 * root.d)

    RowLayout {
        Layout.fillWidth: true
        StyledText {
            Layout.fillWidth: true
            text: root.title
            elide: Text.ElideRight
            color: FamilyStyle.textSecondary
            font.family: FamilyStyle.fontMain
            font.pixelSize: root.look.metaSize
            font.weight: Font.DemiBold
            font.capitalization: root.look.metaCapitalization
            font.letterSpacing: root.look.metaSpacing
        }
        StyledText {
            text: root.label(root.shown)
            color: root.look.valueInk
            font.family: FamilyStyle.fontNumbers
            font.features: ({ "tnum": 1 })
            font.pixelSize: root.look.valueSize
        }
    }

    FamilyPart {
        id: familyScrubber
        visible: familyScrubber.url.length > 0
        Layout.fillWidth: true
        part: "control.scrubber"
        props: ({ knob: true, fillColor: FamilyStyle.accent, stepSize: root.stepSize / root.span, value: (root.value - root.from) / root.span })
        Connections {
            target: familyScrubber.item
            function onMoved(v: real): void {
                root.live = root.snap(root.from + v * root.span)
                root.moved(root.live)
            }
            function onSeekRequested(v: real): void {
                const committed = root.snap(root.from + v * root.span)
                root.live = NaN
                root.committed(committed)
            }
        }
    }

    StyledSlider {
        id: materialSlider
        visible: familyScrubber.url.length === 0
        Layout.fillWidth: true
        enableSettingsSearch: false
        configuration: StyledSlider.Configuration.XS
        stopIndicatorValues: []
        from: root.from
        to: root.to
        stepSize: root.stepSize
        value: root.value
        onMoved: {
            root.live = root.snap(materialSlider.value)
            root.moved(root.live)
        }
        onPressedChanged: {
            if (materialSlider.pressed)
                return
            const committed = root.snap(materialSlider.value)
            root.live = NaN
            root.committed(committed)
            materialSlider.value = Qt.binding(() => root.value)
        }
    }
}
