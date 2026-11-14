// The password as iRiS draws it: the characters never show, each one arrives as a mark (a dot, or one of the
// Material shapes); one caret in the accent; the prompt where the marks will be. Same size in every state.
import QtQuick 2.15
import "."

Item {
    id: entry
    property real d: 1
    property string marks: "dots"          // "dots" | "shapes"
    property bool centred: false
    property bool busy: false
    property color markColour: "#ffffff"
    property real markSize: 10
    property real markGap: 10
    property color caretColour: "#a8c7fa"
    property real caretHeight: 26
    property string placeholder: ""
    property color placeholderColour: Qt.rgba(1, 1, 1, 0.56)
    property string fontFamily: "Inter"
    property real fontSize: 18
    property int fontWeight: Font.Normal
    readonly property alias input: password
    readonly property int count: password.text.length
    signal submitted()
    signal edited()
    // Escape on an empty field: a style with a curtain goes back to it.
    signal dismissed()

    readonly property var expressive: [0.16, 1, 0.3, 1, 1, 1]
    clip: true

    TextInput {
        id: password
        objectName: "password"
        anchors.fill: parent
        echoMode: TextInput.Password
        color: "transparent"
        selectionColor: "transparent"
        selectedTextColor: "transparent"
        cursorVisible: false
        cursorDelegate: Item {}
        font.pixelSize: entry.fontSize
        focus: true
        enabled: !entry.busy
        onAccepted: entry.submitted()
        onTextChanged: entry.edited()
        Keys.onEscapePressed: {
            if (text.length === 0) entry.dismissed()
            text = ""
        }
        Component.onCompleted: forceActiveFocus()
    }

    readonly property real caretGap: Math.round(entry.markGap)
    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        // Centred while it fits, then the newest mark stays in view.
        x: Math.min(entry.centred ? Math.round((entry.width - width) / 2) : 0,
            entry.width - width - caret.width - entry.caretGap)
        spacing: entry.markGap
        Repeater {
            model: entry.count
            Item {
                id: mark
                required property int index
                width: entry.markSize
                height: entry.markSize
                scale: 0
                rotation: entry.marks === "shapes" ? -45 : 0
                Component.onCompleted: { grow.start(); turn.start() }
                NumberAnimation on scale { id: grow; running: false; to: 1; duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: entry.expressive }
                NumberAnimation on rotation { id: turn; running: false; to: 0; duration: 420; easing.type: Easing.BezierSpline; easing.bezierCurve: entry.expressive }
                Rectangle {
                    anchors.fill: parent
                    visible: entry.marks !== "shapes"
                    radius: width / 2
                    color: entry.markColour
                }
                Loader {
                    anchors.fill: parent
                    active: entry.marks === "shapes"
                    sourceComponent: PasswordCharsShape {
                        shapeIndex: mark.index
                        shapeColor: entry.markColour
                        implicitSize: entry.markSize
                    }
                }
            }
        }
    }
    Rectangle {
        id: caret
        x: entry.count > 0 ? row.x + row.width + entry.caretGap
            : entry.centred ? Math.round((entry.width - prompt.implicitWidth) / 2) - width - Math.round(10 * entry.d) : 0
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(2, Math.round(2.5 * entry.d))
        height: entry.caretHeight
        radius: width / 2
        color: entry.caretColour
        visible: password.activeFocus && !entry.busy
        opacity: blink.on ? 1 : 0
        Behavior on x { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        // Blinks while it waits; holds still while you type.
        Timer {
            id: blink
            property bool on: true
            interval: 560; repeat: true
            running: caret.visible && entry.count === 0
            onRunningChanged: blink.on = true
            onTriggered: blink.on = !blink.on
        }
    }
    LoginText {
        id: prompt
        anchors.verticalCenter: parent.verticalCenter
        x: entry.centred ? Math.round((entry.width - implicitWidth) / 2) : caret.width + Math.round(12 * entry.d)
        visible: entry.count === 0 && text.length > 0
        width: Math.min(implicitWidth, entry.width - x)
        elide: Text.ElideRight
        text: entry.placeholder
        color: entry.placeholderColour
        font.family: entry.fontFamily
        font.pixelSize: entry.fontSize
        font.weight: entry.fontWeight
    }
}
