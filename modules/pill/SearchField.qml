import QtQuick
import QtQuick.Controls
import qs.modules.common

Item {
    id: root

    property real s: 1
    property string kanji: ""
    property string placeholder: ""
    property string counterText: ""

    /**
     * Map Left/Right to the moved() signal instead of text-cursor motion. For a
     * horizontal result strip the arrows should page the strip; without this the
     * field swallows them until the caret sits at a text boundary, so navigation
     * stalls mid-query.
     */
    property bool horizontalNav: false
    readonly property alias input: field
    property alias text: field.text
    default property alias rightContent: rightSlot.data

    signal moved(int delta)
    signal accepted()
    signal dismissed()
    signal keyPressed(var event)

    height: 30 * s

    Text {
        id: glyph
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        visible: PillTheme.showGlyphs
        width: PillTheme.showGlyphs ? implicitWidth : 0
        text: root.kanji
        color: PillTheme.dim
        font.family: PillTheme.fontJp
        font.weight: Font.Medium
        font.pixelSize: 16 * root.s
    }

    TextField {
        id: field
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: glyph.right
        anchors.leftMargin: PillTheme.showGlyphs ? 10 * root.s : 0
        anchors.right: counter.left
        anchors.rightMargin: 10 * root.s
        background: null
        padding: 0
        color: PillTheme.cream
        font.family: PillTheme.font
        font.pixelSize: 15 * root.s
        placeholderText: root.placeholder
        placeholderTextColor: PillTheme.faint
        selectByMouse: true
        selectionColor: PillTheme.verm
        cursorDelegate: Item {}
        Keys.onUpPressed: root.moved(-1)
        Keys.onDownPressed: root.moved(1)
        Keys.onPressed: (e) => {
            root.keyPressed(e);
            if (e.accepted)
                return;
            if (root.horizontalNav && (e.key === Qt.Key_Left || e.key === Qt.Key_Right)) {
                root.moved(e.key === Qt.Key_Right ? 1 : -1);
                e.accepted = true;
            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                root.accepted();
                e.accepted = true;
            } else if (e.key === Qt.Key_Escape) {
                root.dismissed();
                e.accepted = true;
            }
        }
    }

    Rectangle {
        anchors.left: field.left
        anchors.right: field.right
        anchors.top: field.bottom
        anchors.topMargin: 2 * root.s
        height: 1
        color: PillTheme.faint
        opacity: field.activeFocus ? 0.7 : 0
        Behavior on opacity { NumberAnimation { duration: PillMotion.standard; easing.type: PillMotion.easeStandard } }
    }

    Text {
        id: counter
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: rightSlot.left
        anchors.rightMargin: rightSlot.width > 0 ? 10 * root.s : 0
        text: root.counterText
        color: PillTheme.faint
        font.family: PillTheme.font
        font.pixelSize: 10.5 * root.s
        font.features: { "tnum": 1 }
    }

    Item {
        id: rightSlot
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        width: childrenRect.width
        height: parent.height
    }
}
