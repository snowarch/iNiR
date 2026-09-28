import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets

StyledText {
    id: root
    required property var face
    property real size: 40

    color: face.ink
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
