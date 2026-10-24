pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets
import qs.modules.iris.style

// What a face says when it has nothing to show: a mark in its colour, what is true, what comes next. Every face's
// empty, offline and error state is this one block, centred where its content would sit; a key can follow it.
ColumnLayout {
    id: blank
    // sized by its content: a nested layout fills its column by default and took the room meant for others
    Layout.fillHeight: false
    required property var face
    property string glyph: ""
    property bool glyphFill: false
    property string title: ""
    property string detail: ""
    property color tint: blank.face.accent
    spacing: blank.face.dp(4)

    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: blank.face.dp(blank.face.large ? 52 : blank.face.small ? 34 : 40)
        Layout.preferredHeight: Layout.preferredWidth
        Layout.bottomMargin: blank.face.dp(4)
        radius: IrisStyle.capsule(width)
        color: blank.face.nothing ? "transparent" : IrisStyle.tintFill(blank.tint)
        border.width: blank.face.nothing ? Math.max(1, blank.face.dp(1.5)) : 0
        border.color: blank.face.ink
        MaterialSymbol {
            anchors.centerIn: parent
            text: blank.glyph
            fill: blank.glyphFill ? 1 : 0
            iconSize: Math.round(parent.width * 0.5)
            color: blank.tint
        }
    }
    FaceText {
        face: blank.face
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: IrisFaceData.unwidowed(blank.title)
        size: blank.face.small ? 13 : 14
        weight: Font.DemiBold
        wrapMode: Text.Wrap
        maximumLineCount: 2
    }
    FaceText {
        face: blank.face
        visible: !blank.face.small && blank.detail.length > 0
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: IrisFaceData.unwidowed(blank.detail)
        color: blank.face.inkSecondary
        size: 12
        wrapMode: Text.Wrap
        maximumLineCount: 2
    }
}
