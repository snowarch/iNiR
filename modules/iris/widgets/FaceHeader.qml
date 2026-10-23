pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets

RowLayout {
    id: root

    required property var face
    property string glyph: ""
    property string text: ""
    property string trailing: ""
    property color tint: root.face.accent

    spacing: root.face.dp(5)

    // Nothing's Label voice (DESIGN.md S2): mono caps in ink, no glyph; the header names the widget, it never colours it.
    readonly property bool label: root.face.nothing ?? false
    MaterialSymbol {
        visible: root.glyph.length > 0 && !root.label
        text: root.glyph
        fill: 1
        iconSize: root.face.px(15)
        color: root.tint
    }
    FaceText {
        face: root.face
        Layout.fillWidth: true
        text: root.label ? root.text.toUpperCase() : root.text
        color: root.label ? root.face.inkSecondary : root.tint
        size: root.label ? 10.5 : 12.5
        weight: root.label ? Font.Medium : Font.DemiBold
        font.family: root.label ? root.face.fontLabel : root.face.fontMain
        font.letterSpacing: root.label ? root.face.px(10.5) * 0.08 : 0
    }
    FaceText {
        face: root.face
        visible: root.trailing.length > 0
        text: root.label ? root.trailing.toUpperCase() : root.trailing
        color: root.face.inkTertiary
        size: root.label ? 10 : 11.5
        font.family: root.label ? root.face.fontLabel : root.face.fontMain
        font.letterSpacing: root.label ? root.face.px(10) * 0.08 : 0
    }
}
