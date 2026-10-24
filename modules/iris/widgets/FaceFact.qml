pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets

// One fact under a hairline: its mark, its name, its value in the figure face (the Day's large list).
ColumnLayout {
    id: fact
    // sized by its content: a nested layout fills its column by default and took the room meant for others
    Layout.fillHeight: false
    required property var face
    property string glyph: ""
    property string label: ""
    property string value: ""
    property color tint: fact.face.accent
    property bool rule: true
    spacing: fact.face.dp(8)
    Rectangle {
        visible: fact.rule
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: fact.face.hairline
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: fact.face.dp(8)
        MaterialSymbol {
            visible: fact.glyph.length > 0 && !fact.face.nothing
            text: fact.glyph
            fill: 1
            iconSize: fact.face.px(15)
            color: fact.tint
        }
        FaceText {
            face: fact.face
            Layout.fillWidth: true
            text: fact.label
            color: fact.face.inkSecondary
            size: 13
        }
        FaceText {
            face: fact.face
            text: fact.value
            size: 13
            weight: Font.DemiBold
            font.family: fact.face.fontNumbers
            font.features: ({ "tnum": 1 })
        }
    }
}
