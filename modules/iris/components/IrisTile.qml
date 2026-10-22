import QtQuick
import qs.services
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style

// A quick-settings tile (DESIGN.md S4), Nothing's: 1x1 or 2x1. Off is a raised fill with an ink glyph, on is inverted
// (ink plate, paper glyph and words), live carries the signal dot in its top-right corner. A wide tile may hold one
// figure in the Dot voice.
Item {
    id: root

    property bool on: false
    property bool live: false
    property bool wide: false
    property string glyph: ""
    property string title: ""
    property string label: ""
    property string figure: ""
    property real unit: Math.round(64 * IrisStyle.density)
    readonly property real d: IrisStyle.density
    readonly property bool hovered: area.containsMouse
    signal clicked()
    signal pressAndHold()

    implicitWidth: root.wide ? 2 * root.unit + Math.round(8 * root.d) : root.unit
    implicitHeight: root.unit
    Accessible.role: Accessible.Button
    Accessible.name: Translation.tr(root.title || root.label)
    Accessible.checkable: true
    Accessible.checked: root.on
    activeFocusOnTab: true
    Keys.onSpacePressed: root.clicked()
    Keys.onReturnPressed: root.clicked()

    // The plate inverts as one move: fill, glyph and words cross together.
    property real lit: root.on ? 1 : 0
    Behavior on lit { NumberAnimation { duration: IrisStyle.duration(160); easing.type: Easing.OutCubic } }
    readonly property color ink: ColorUtils.mix(IrisStyle.inkOnAccentFill, IrisStyle.text, root.lit)
    readonly property color quiet: IrisStyle.secondaryOf(root.ink)

    Rectangle {
        id: plate
        anchors.fill: parent
        radius: IrisStyle.radiusTile
        color: ColorUtils.mix(IrisStyle.accentFill, area.containsMouse ? IrisStyle.fillHover : IrisStyle.fill, root.lit)
        scale: area.pressed ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
        border.width: root.activeFocus ? Math.max(1, Math.round(1.5 * root.d)) : 0
        border.color: IrisStyle.text

        MaterialSymbol {
            visible: root.glyph.length > 0
            x: Math.round(12 * root.d)
            y: Math.round(12 * root.d)
            text: root.glyph
            iconSize: Math.round(18 * root.d)
            fill: root.on ? 1 : 0
            color: root.ink
        }
        IrisText {
            visible: root.title.length > 0 && (root.wide || root.glyph.length === 0)
            x: root.glyph.length > 0 ? Math.round(38 * root.d) : Math.round(12 * root.d)
            y: Math.round(12 * root.d)
            width: Math.min(implicitWidth, plate.width - x - Math.round(22 * root.d))
            elide: Text.ElideRight
            text: Translation.tr(root.title)
            role: IrisText.Name
            font.weight: IrisStyle.weight(Font.DemiBold)
            font.pixelSize: IrisStyle.typeMeta
            color: root.ink
        }
        IrisDotText {
            visible: root.wide && root.figure.length > 0
            x: Math.round(12 * root.d)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(8 * root.d)
            text: root.figure
            pixelSize: IrisStyle.typeDotS
            color: root.ink
        }
        IrisLabel {
            visible: root.label.length > 0 && !(root.wide && root.figure.length > 0)
            x: Math.round(12 * root.d)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(10 * root.d)
            width: Math.min(implicitWidth, plate.width - Math.round(24 * root.d))
            text: Translation.tr(root.label)
            color: root.quiet
        }
        Rectangle {
            id: liveDot
            readonly property real size: Math.round(7 * root.d)
            x: plate.width - size - Math.round(11 * root.d)
            y: Math.round(11 * root.d)
            width: liveDot.size
            height: liveDot.size
            radius: IrisStyle.capsule(liveDot.size)
            color: IrisStyle.signal
            scale: root.live ? 1 : 0
            Behavior on scale { NumberAnimation { duration: IrisStyle.duration(220); easing.type: Easing.OutBack } }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onPressAndHold: root.pressAndHold()
    }
}
