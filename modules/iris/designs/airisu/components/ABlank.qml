import QtQuick
import qs.modules.iris.style

// AIRISU's empty, offline and error state: printed at the foot of the lacquer the way the off state of Screen Time is,
// never iRiS's round block. What is true as a label, what comes next as one line in the text face, and a key when there
// is something to do about it (`action`). Set its width; it grows from the bottom up.
Column {
    id: root
    property var face
    // The AStock it is printed on, for its inks.
    property var stock
    property string label: ""
    property string line: ""
    property string action: ""
    signal activated()
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    spacing: root.dp(4)

    AText {
        width: parent.width
        visible: text.length > 0
        voice: "mono"
        size: IrisStyle.typeCaption
        wrapMode: Text.Wrap
        maximumLineCount: 2
        color: root.stock?.inkSecond ?? Airisu.inkSecond
        text: root.label
    }
    AText {
        width: parent.width
        visible: text.length > 0
        size: IrisStyle.typeLabel
        font.weight: Font.Bold
        wrapMode: Text.Wrap
        maximumLineCount: root.face?.small ? 3 : 2
        color: root.stock?.ink ?? Airisu.ink
        text: root.line
    }
    Item {
        visible: root.action.length > 0
        width: Math.min(parent.width, word.implicitWidth + root.dp(24))
        height: root.dp(32)
        AKey {
            id: plate
            y: root.dp(4)
            width: parent.width
            height: root.dp(28)
            lacquer: Airisu.seal
            hovered: hover.hovered
            pressed: tap.pressed
        }
        AText {
            id: word
            anchors.centerIn: plate
            anchors.horizontalCenterOffset: plate.shift
            anchors.verticalCenterOffset: plate.shift
            size: IrisStyle.typeLabel
            font.weight: Font.Bold
            color: Airisu.inkOnSeal
            text: root.action
        }
        Accessible.role: Accessible.Button
        Accessible.name: root.action
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: tap; onTapped: root.activated() }
    }
}
