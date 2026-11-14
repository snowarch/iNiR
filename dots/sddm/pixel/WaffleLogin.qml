// Waffle's login, as its lock screen draws it: the clock and date over your picture; a key or a click brings the
// sign-in (your face in the accent ring, your name, the password), the picture dimming behind it. It reads Waffle's
// lock (blur, dim, clock) and type through theme.conf; inir-accel sddm-sync writes them.
import QtQuick 2.15
import QtQuick.Effects
import "."

LoginSurface {
    id: root
    field: entry.input
    curtain: !root.signing

    // ── theme.conf (the palette is the shell's dark one; Waffle's accent is its primary) ──
    readonly property color accent: root.core.cfg("primaryColor", "#a8c7fa")
    readonly property bool accentDark: 0.2126 * root.accent.r + 0.7152 * root.accent.g + 0.0722 * root.accent.b < 0.5
    readonly property color accentFg: root.accentDark ? "#ffffff" : "#000000"
    readonly property color ink: root.core.cfg("onSurfaceColor", "#ffffff")
    readonly property color inkSoft: root.core.cfg("onSurfaceVariantColor", "#ced1d7")
    readonly property color base: root.core.cfg("backgroundColor", "#1c1c1c")
    readonly property color plate: root.core.cfg("surfaceContainerColor", "#2c2c2c")
    readonly property color danger: root.core.cfg("errorColor", "#ff6961")
    readonly property string font: root.core.cfg("waffleFont", "Noto Sans")
    readonly property real fontScale: Math.max(0.8, Math.min(1.5, root.core.num("waffleFontScale", 1)))
    readonly property bool blurred: root.core.flag("waffleBlur", true)
    readonly property real blurRadius: Math.max(0, Math.min(64, root.core.num("waffleBlurRadius", 100)))
    readonly property real dim: Math.max(0, Math.min(1, root.core.num("waffleDim", 0)))
    readonly property bool minimal: String(root.core.cfg("waffleClockStyle", "default")) === "minimal"
    readonly property string clockPosition: String(root.core.cfg("waffleClockPosition", "center"))
    function t(n) { return Math.round(n * root.d * root.fontScale) }

    // ── The curtain and the sign-in ──
    property bool signing: false
    property real shown: root.signing ? 1 : 0
    Behavior on shown { NumberAnimation { duration: 250; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0, 1, 1, 1] } }
    function reveal(text) {
        if (!root.primary || root.signing) return
        root.signing = true
        entry.input.forceActiveFocus()
        // The key that lifted the curtain is the password's first character; a bare space or a modifier only lifts it.
        if (text && text.length === 1 && text.charCodeAt(0) > 32) entry.input.insert(entry.input.cursorPosition, text)
    }
    function rest() {
        if (root.core.signingIn) return
        entry.input.text = ""
        root.core.failed = false
        root.core.notice = ""
        root.signing = false
        root.forceActiveFocus()
    }
    onKnocked: text => root.reveal(text)
    Component.onCompleted: root.forceActiveFocus()
    // Left alone with nothing typed, the sign-in goes back to the clock.
    Timer {
        interval: 30000
        running: root.signing && entry.count === 0 && !root.core.signingIn
        onTriggered: root.rest()
    }

    // ── The picture ──
    Rectangle { anchors.fill: parent; color: root.base }
    Image {
        id: picture
        anchors.fill: parent
        source: root.core.cfg("background", "")
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width, root.height)
        asynchronous: true
        cache: false
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: picture
        blurEnabled: root.blurred && root.blurRadius > 0
        blur: 0.8
        blurMax: Math.round(root.blurRadius)
        saturation: 0.5
        opacity: Math.min(1, root.entrance * 2)
    }
    // The lock's veils: its dim, a light one at the clock, the smoke behind the sign-in, and the lift a light picture needs.
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: root.dim }
    Rectangle {
        anchors.fill: parent
        color: root.base
        opacity: Math.min(0.9, 0.35 * (0.25 + 0.5 * root.shown) + 0.5 * root.shown + root.core.lift) * (1 - root.release)
    }

    // ── The clock ──
    MouseArea {
        anchors.fill: parent
        enabled: root.primary && !root.signing
        onClicked: root.reveal("")
    }
    Column {
        id: clock
        spacing: root.px(4)
        opacity: root.entrance * (1 - root.shown) * (1 - root.release)
        visible: opacity > 0
        transform: Translate { y: -root.px(40) * root.shown }
        readonly property bool centred: root.clockPosition !== "topLeft" && root.clockPosition !== "bottomLeft"
        x: clock.centred ? Math.round((root.width - width) / 2) : root.px(48)
        y: clock.centred ? Math.round((root.height - height) / 2) - root.px(60)
            : root.clockPosition === "topLeft" ? root.px(80) : root.height - height - root.px(140)
        LoginText {
            anchors.horizontalCenter: clock.centred ? parent.horizontalCenter : undefined
            text: root.core.hours + ":" + root.core.minutes + (root.core.meridiem.length > 0 ? " " + root.core.meridiem : "")
            color: root.ink
            font.family: root.font
            font.pixelSize: root.t(root.minimal ? 72 : 96)
            font.weight: Font.Normal
            font.features: ({ "tnum": 1 })
        }
        LoginText {
            anchors.horizontalCenter: clock.centred ? parent.horizontalCenter : undefined
            text: root.core.sentence(Qt.locale().toString(root.core.now, "dddd, MMMM d"))
            color: root.ink
            font.family: root.font
            font.pixelSize: root.t(root.minimal ? 14 : 20)
            font.weight: Font.Medium
        }
    }

    // ── The sign-in ──
    Item {
        id: signIn
        anchors.fill: parent
        visible: root.primary && opacity > 0
        enabled: root.signing
        opacity: root.shown * (1 - root.release)
        scale: 1.05 - 0.05 * root.shown

        Column {
            anchors.centerIn: parent
            spacing: root.px(16)

            Item {
                id: face
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.px(128)
                height: width
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.color: root.accent
                    border.width: Math.max(2, root.px(3))
                }
                LoginAvatar {
                    anchors.centerIn: parent
                    width: root.px(120)
                    height: width
                    icon: root.core.userIcon
                    name: root.core.userName
                    fontFamily: root.font
                    fill: root.accent
                    ink: root.accentFg
                }
            }
            LoginText {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: root.px(8)
                text: root.core.userName
                color: root.ink
                font.family: root.font
                font.pixelSize: root.t(24)
                font.weight: Font.Medium
            }
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.px(280)
                height: root.px(48)
                Rectangle {
                    id: box
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: root.px(40)
                    radius: root.px(4)
                    color: root.plate
                    border.color: entry.input.activeFocus ? root.accent : Qt.rgba(root.inkSoft.r, root.inkSoft.g, root.inkSoft.b, 0.6)
                    border.width: entry.input.activeFocus ? 2 : 1
                    transform: Translate { x: root.shakeX }
                    Behavior on border.color { ColorAnimation { duration: 70 } }

                    LoginEntry {
                        id: entry
                        anchors.fill: parent
                        anchors.leftMargin: root.px(12)
                        anchors.rightMargin: root.px(44)
                        d: root.d
                        marks: "dots"
                        busy: root.core.signingIn
                        markColour: root.ink
                        markSize: root.px(7)
                        markGap: root.px(5)
                        caretColour: root.accent
                        caretHeight: root.px(18)
                        placeholder: root.core.failed ? root.core.text.loginFailed : root.core.text.password
                        placeholderColour: root.core.failed ? root.danger : root.inkSoft
                        fontFamily: root.font
                        fontSize: root.t(13)
                        onSubmitted: root.core.signIn()
                        onEdited: root.core.typed()
                        onDismissed: root.rest()
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: root.px(6)
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.px(28)
                        height: width
                        radius: root.px(4)
                        color: go.pressed ? Qt.darker(root.accent, 1.15) : go.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent
                        FluentGlyph {
                            anchors.centerIn: parent
                            width: root.px(16)
                            height: width
                            icon: "chevron-right"
                            colour: root.accentFg
                        }
                        MouseArea {
                            id: go
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !root.core.signingIn
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.core.signIn()
                        }
                    }
                }
            }
            // Signing in: a short accent bar running under the field, as Waffle's lock shows it.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.px(120)
                height: root.px(4)
                clip: true
                visible: root.core.signingIn
                Rectangle {
                    width: parent.width * 0.4
                    height: parent.height
                    radius: height / 2
                    color: root.accent
                    NumberAnimation on x {
                        running: root.core.signingIn
                        loops: Animation.Infinite
                        from: -root.px(48); to: root.px(120)
                        duration: 1100
                        easing.type: Easing.InOutQuad
                    }
                }
            }
            // What PAM says besides a wrong password, or Caps Lock; a wrong password speaks in the field.
            LoginText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !root.core.signingIn
                width: Math.min(implicitWidth, root.px(360))
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                text: root.core.hint.length > 0 && root.core.hint !== root.core.text.loginFailed ? root.core.hint : " "
                color: root.inkSoft
                font.family: root.font
                font.pixelSize: root.t(11)
            }
        }

        // ── Bottom left: the other accounts, as Windows lists them ──
        Column {
            visible: root.core.manyUsers
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: root.px(24)
            spacing: root.px(4)
            Repeater {
                model: userModel
                Rectangle {
                    id: account
                    required property int index
                    required property string name
                    required property string realName
                    required property string icon
                    readonly property bool chosen: account.index === root.core.userIndex
                    width: root.px(240)
                    height: root.px(56)
                    radius: root.px(4)
                    color: account.chosen ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.14)
                        : pick.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) : "transparent"
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.px(8)
                        spacing: root.px(12)
                        LoginAvatar {
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.px(40)
                            height: width
                            icon: account.icon
                            name: account.realName || account.name
                            fontFamily: root.font
                            fill: root.accent
                            ink: root.accentFg
                        }
                        LoginText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.px(168)
                            elide: Text.ElideRight
                            text: account.realName || account.name
                            color: root.ink
                            font.family: root.font
                            font.pixelSize: root.t(13)
                        }
                    }
                    MouseArea {
                        id: pick
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.core.userIndex = account.index
                            root.core.failed = false
                            root.core.notice = ""
                            entry.input.text = ""
                            entry.input.forceActiveFocus()
                        }
                    }
                }
            }
        }

        // ── Bottom right: the session and the layout, then sleep, shut down, restart ──
        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: root.px(24)
            spacing: root.px(8)
            WaffleButton { visible: root.core.manySessions; icon: "desktop"; label: root.core.sessionName; onActivated: root.core.nextSession() }
            WaffleButton { visible: root.core.manyLayouts; icon: "keyboard"; label: root.core.layoutName; onActivated: root.core.nextLayout() }
            WaffleButton { visible: sddm.canSuspend; icon: "weather-moon"; onActivated: sddm.suspend() }
            WaffleButton { visible: sddm.canPowerOff; icon: "power"; onActivated: sddm.powerOff() }
            WaffleButton { visible: sddm.canReboot; icon: "arrow-counterclockwise"; onActivated: sddm.reboot() }
        }
    }

    // Waffle's lock button: a square of its layer with a hairline, rounded 4, a Fluent glyph.
    component WaffleButton: Rectangle {
        id: button
        property string icon: ""
        property string label: ""
        signal activated()
        width: button.label.length > 0 ? content.implicitWidth + root.px(28) : root.px(44)
        height: root.px(44)
        radius: root.px(4)
        color: press.pressed ? Qt.darker(root.plate, 1.1) : press.containsMouse ? Qt.lighter(root.plate, 1.25) : root.plate
        border.color: Qt.rgba(root.inkSoft.r, root.inkSoft.g, root.inkSoft.b, 0.22)
        border.width: 1
        Behavior on color { ColorAnimation { duration: 70 } }
        Row {
            id: content
            anchors.centerIn: parent
            spacing: root.px(8)
            FluentGlyph {
                anchors.verticalCenter: parent.verticalCenter
                width: root.px(20)
                height: width
                icon: button.icon
                colour: root.ink
            }
            LoginText {
                visible: button.label.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: button.label
                color: root.ink
                font.family: root.font
                font.pixelSize: root.t(13)
            }
        }
        MouseArea {
            id: press
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }
}
