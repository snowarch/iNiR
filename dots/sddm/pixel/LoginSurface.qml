// The frame every iRiS login style is drawn in: scale, arrival and leaving, the shake on a wrong password,
// typing anywhere reaching the password. A style sets `field` to its LoginEntry's input and draws the rest.
import QtQuick 2.15
import "."

Item {
    id: surface
    focus: true

    readonly property alias core: loginCore
    property Item field: null
    LoginCore { id: loginCore; field: surface.field }

    // 1 at 1920x1080; narrow and portrait screens scale by width so nothing overflows.
    readonly property real d: Math.max(0.75, Math.min(2.5, Math.min(surface.height / 1080, surface.width / 1600)))
    function type(px) { return Math.round(px * surface.d * loginCore.typeScale) }
    function px(n) { return Math.round(n * surface.d) }
    // SDDM draws one view per screen; only the primary one asks for the password.
    readonly property bool primary: typeof primaryScreen === "undefined" || primaryScreen !== false

    readonly property var expressive: [0.16, 1, 0.3, 1, 1, 1]
    property real entrance: 0
    property real release: 0
    property real shakeX: 0
    Component.onCompleted: arrive.start()
    NumberAnimation {
        id: arrive
        target: surface; property: "entrance"; from: 0; to: 1
        duration: 1100; easing.type: Easing.BezierSpline; easing.bezierCurve: surface.expressive
    }
    NumberAnimation {
        id: leave
        target: surface; property: "release"; to: 1
        duration: 620; easing.type: Easing.BezierSpline; easing.bezierCurve: surface.expressive
    }
    SequentialAnimation {
        id: shake
        NumberAnimation { target: surface; property: "shakeX"; to: -14 * surface.d; duration: 45; easing.type: Easing.OutQuad }
        NumberAnimation { target: surface; property: "shakeX"; to: 11 * surface.d; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: surface; property: "shakeX"; to: -6 * surface.d; duration: 60; easing.type: Easing.InOutQuad }
        NumberAnimation { target: surface; property: "shakeX"; to: 0; duration: 55; easing.type: Easing.OutQuad }
    }
    Connections {
        target: loginCore
        function onRejected() { shake.restart() }
        function onGranted() { leave.start() }
    }

    // A style with a curtain (Waffle's clock before the sign-in) takes the first key itself.
    property bool curtain: false
    signal knocked(string text)

    Keys.onPressed: event => {
        if (surface.curtain) {
            surface.knocked(event.text)
            event.accepted = true
            return
        }
        const f = surface.field
        if (!f || loginCore.signingIn || f.activeFocus) return
        if (event.text.length === 1 && event.text.charCodeAt(0) >= 32) {
            f.forceActiveFocus()
            f.insert(f.cursorPosition, event.text)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            loginCore.signIn()
            event.accepted = true
        }
    }
}
