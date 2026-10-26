pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style

Rectangle {
    id: root

    required property var face
    property string glyph: ""
    property string name: ""
    property color tint: root.face.ink
    property bool danger: false
    // Its name beside the glyph whenever the key is wide enough to hold both.
    property bool worded: false
    readonly property bool namesItself: root.worded && root.name.length > 0
        && keyGlyph.implicitWidth + keyRow.spacing + keyName.implicitWidth + root.face.dp(20) <= root.width
    signal activated()

    implicitWidth: root.face.dp(32)
    implicitHeight: implicitWidth
    radius: IrisStyle.capsule(height)
    color: hover.hovered ? (root.danger ? IrisStyle.tintFill(root.face.danger) : root.face.fillHover) : root.face.fill
    scale: tap.pressed ? IrisStyle.pressScale(0.94) : 1
    Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
    Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }

    Row {
        id: keyRow
        anchors.centerIn: parent
        spacing: root.face.dp(6)
        MaterialSymbol {
            id: keyGlyph
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            fill: 1
            iconSize: root.face.px(17)
            color: hover.hovered && root.danger ? root.face.danger : root.tint
        }
        FaceText {
            id: keyName
            face: root.face
            visible: root.namesItself
            anchors.verticalCenter: parent.verticalCenter
            text: root.name
            color: hover.hovered && root.danger ? root.face.danger : root.tint
            size: 12.5
            weight: Font.DemiBold
        }
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; gesturePolicy: TapHandler.WithinBounds; onTapped: root.activated() }
    Accessible.role: Accessible.Button
    Accessible.name: root.name
}
