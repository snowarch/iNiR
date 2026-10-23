import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets
import qs.modules.iris.style

StyledText {
    id: root
    required property var face
    property real size: 40
    // The figure's ink. While a change rolls, the text keeps its metrics and the cells below draw the glyphs.
    property color tone: face.ink
    // A changed digit rolls: the old one leaves upward as the new one rises into its place (Apple's numeric text,
    // Nothing's roll, DESIGN.md S5). Only on a face that is seen, never for the first value, one animation per figure,
    // and the cells exist only while it runs.
    property bool rolls: true
    property string _from: ""
    property string _shown: ""
    property bool _rolling: false
    property real _p: 1

    color: root._rolling ? "transparent" : root.tone
    onTextChanged: {
        const was = root._shown
        root._shown = root.text
        if (!root.rolls || was.length === 0 || was === root.text || !(root.face.moving ?? false)
                || root.wrapMode !== Text.NoWrap || !IrisStyle.motionEnabled)
            return
        root._from = was
        root._rolling = true
        roll.restart()
    }
    Component.onCompleted: root._shown = root.text
    NumberAnimation {
        id: roll
        target: root
        property: "_p"
        from: 0
        to: 1
        duration: 380
        easing.type: Easing.OutBack
        easing.overshoot: 1.1
        onFinished: root._rolling = false
    }
    Row {
        visible: root._rolling
        x: root.horizontalAlignment === Text.AlignRight ? root.width - width
            : root.horizontalAlignment === Text.AlignHCenter ? Math.round((root.width - width) / 2) : 0
        Repeater {
            model: root._rolling ? root.text.length : 0
            delegate: Item {
                id: cell
                required property int index
                // Digits pair from the right, so 9 -> 10 rolls the units and brings the tens in.
                readonly property int fromRight: root.text.length - 1 - cell.index
                readonly property string now: root.text.charAt(cell.index)
                readonly property string was: root._from.charAt(root._from.length - 1 - cell.fromRight)
                readonly property bool turns: cell.now !== cell.was
                readonly property real travel: root.height * 0.62
                width: nowText.implicitWidth
                height: root.height
                clip: cell.turns
                StyledText {
                    id: nowText
                    text: cell.now
                    font: root.font
                    color: root.tone
                    y: cell.turns ? (1 - root._p) * cell.travel : 0
                    opacity: cell.turns ? Math.min(1, Math.max(0, root._p * 1.4)) : 1
                }
                StyledText {
                    visible: cell.turns && cell.was.length > 0
                    text: cell.was
                    font: root.font
                    color: root.tone
                    y: -root._p * cell.travel
                    opacity: Math.max(0, 1 - root._p * 1.6)
                }
            }
        }
    }
    font.family: face.fontNumbers
    font.pixelSize: face.px(size)
    font.weight: face.figureWeight
    font.features: ({ "tnum": 1 })
    font.letterSpacing: Math.round(-face.px(size) * 0.03)
    maximumLineCount: 1
    // Whole-pixel size: a text's fractional natural size puts every neighbour after it off the pixel grid.
    width: Math.ceil(implicitWidth)
    height: root.wrapMode === Text.NoWrap ? Math.ceil(root.implicitHeight) : root.implicitHeight
    Layout.preferredWidth: Math.ceil(implicitWidth)
    Layout.preferredHeight: root.wrapMode === Text.NoWrap ? Math.ceil(root.implicitHeight) : -1
    transform: Translate { x: Math.round(root.x) - root.x; y: Math.round(root.y) - root.y }
}
