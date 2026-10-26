import QtQuick
import qs.modules.iris.style

// The Figure voice (DESIGN.md S2, S5): one figure in Archivo SemiExpanded. When it changes, each digit that changed rolls
// on its own (180 ms, up when the value grows, down when it falls); the ones that did not change stay put.
Item {
    id: root

    property string text: ""
    property int pixelSize: IrisStyle.typeDotM
    property color color: IrisStyle.text
    // Apple sets the figure in the numbers face, bold; the Dot face is Nothing's. Both roll per digit.
    readonly property bool nothing: IrisStyle.wearsNothing(root)
    property string family: root.nothing ? IrisStyle.fontDot : IrisStyle.figureFaceOf(root, root.pixelSize)
    // Synth's display face reads thin; Gel and Apple keep the figure weight.
    readonly property int figureWeight: root.nothing ? Font.Bold : root.family === IrisStyle.fontSynthFigure ? Font.Light : IrisStyle.figureWeight
    property int horizontalAlignment: Text.AlignLeft
    property bool roll: IrisStyle.motionEnabled && root.visible
    // -1 rolls down, 1 up, 0 decides from the value (a bigger number rolls up).
    property int direction: 0

    property string _previous: ""
    property int _sign: 1
    onTextChanged: {
        const before = parseFloat(root._previous.replace(/[^0-9.\-]/g, ""))
        const after = parseFloat(root.text.replace(/[^0-9.\-]/g, ""))
        root._sign = root.direction !== 0 ? root.direction : (isNaN(before) || isNaN(after) || after >= before ? 1 : -1)
        root._previous = root.text
    }
    // Digits that join after the first frame (9 -> 10) roll in; the ones built with the item just appear.
    property bool _ready: false
    Component.onCompleted: { root._previous = root.text; Qt.callLater(() => root._ready = true) }

    implicitWidth: Math.ceil(digits.implicitWidth)
    implicitHeight: Math.ceil(probe.implicitHeight)

    Text {
        id: probe
        visible: false
        text: "0"
        font.family: root.family
        font.pixelSize: Math.max(IrisStyle.typeDotS, root.pixelSize)
    }

    Row {
        id: digits
        x: root.horizontalAlignment === Text.AlignRight ? root.width - width
            : root.horizontalAlignment === Text.AlignHCenter ? Math.round((root.width - width) / 2) : 0
        height: root.height
        Repeater {
            model: root.text.length
            delegate: Item {
                id: slot
                required property int index
                readonly property string glyph: root.text.charAt(slot.index)
                property string shown: slot.glyph
                property string leaving: ""
                property real progress: 1
                property int sign: 1
                width: Math.max(now.implicitWidth, slot.progress < 1 ? was.implicitWidth : 0)
                height: probe.implicitHeight
                clip: slot.progress < 1
                onGlyphChanged: {
                    if (slot.glyph === slot.shown) return
                    slot.leaving = slot.shown
                    slot.shown = slot.glyph
                    slot.sign = root._sign
                    if (root.roll) rolling.restart()
                }
                Component.onCompleted: if (root.roll && root._ready) { slot.progress = 0; rolling.restart() }
                NumberAnimation {
                    id: rolling
                    target: slot; property: "progress"; from: 0; to: 1
                    duration: IrisStyle.duration(180); easing.type: Easing.OutCubic
                }
                Text {
                    id: was
                    text: slot.leaving
                    visible: slot.progress < 1
                    y: -slot.sign * slot.progress * slot.height
                    opacity: 1 - slot.progress
                    color: root.color
                    font.family: root.family
                    font.pixelSize: probe.font.pixelSize
                    font.letterSpacing: root.nothing ? IrisStyle.dotTracking(probe.font.pixelSize) : 0
                    font.weight: root.figureWeight
                    font.features: ({ "tnum": 1 })
                    renderType: Text.NativeRendering
                }
                Text {
                    id: now
                    text: slot.shown
                    y: slot.sign * (1 - slot.progress) * slot.height
                    opacity: slot.progress < 1 ? slot.progress : 1
                    // Native: Qt's distance fields antialias in subpixel colour here and fringe every dot.
                    renderType: Text.NativeRendering
                    color: root.color
                    font.family: root.family
                    font.pixelSize: probe.font.pixelSize
                    font.letterSpacing: root.nothing ? IrisStyle.dotTracking(probe.font.pixelSize) : 0
                    font.weight: root.figureWeight
                    font.features: ({ "tnum": 1 })
                }
            }
        }
    }
}
