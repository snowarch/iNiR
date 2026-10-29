// iRiS login, Frame ("Marco"): the picture hung like a work, sharp and untouched, in a mat of the desktop's own surface
// colour; everything you need sits on the mat's lower band, like the placard under a painting.
import QtQuick 2.15
import QtQuick.Effects
import "."

LoginSurface {
    id: root
    field: entry.input

    readonly property real pad: root.px(20)
    readonly property real band: root.px(148)
    readonly property real inset: root.px(34)
    // The Material palette the desktop wears, which inir-accel sddm-sync writes for the Classic look too.
    readonly property color mat: root.core.cfg("surfaceColor", "#1b1b1f")
    readonly property color ink: root.core.cfg("onSurfaceColor", "#e6e1e5")
    readonly property color inkSoft: root.core.cfg("onSurfaceVariantColor", "#cac4d0")
    readonly property color act: root.core.cfg("primaryColor", "#a8c7fa")
    readonly property color onAct: root.core.cfg("onPrimaryColor", "#0b1d36")
    readonly property color wrong: root.core.cfg("errorColor", "#ffb4ab")
    readonly property bool lightMat: root.mat.hslLightness > 0.5
    readonly property color well: root.lightMat ? Qt.rgba(0, 0, 0, 0.075) : Qt.rgba(1, 1, 1, 0.08)
    readonly property color wellHover: root.lightMat ? Qt.rgba(0, 0, 0, 0.11) : Qt.rgba(1, 1, 1, 0.13)

    Rectangle { anchors.fill: parent; color: root.mat }
    component Plain: LoginAction {
        d: root.d
        size: root.px(44)
        fontSize: root.type(16)
        fontFamily: root.core.fontMain
        symbolFont: root.core.symbolFont
        ink: root.ink
        hover: root.wellHover
    }

    // ── The work: on signing in the mat recedes and the picture fills the screen, like walking up to it ──
    Item {
        id: frame
        x: root.pad * (1 - root.release)
        y: root.pad * (1 - root.release)
        width: root.width - 2 * x
        height: (root.height - root.pad - root.band) + (root.pad + root.band) * root.release
        Image {
            id: picture
            anchors.fill: parent
            source: root.core.picture
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(root.width, root.height)
            asynchronous: true
            cache: false
            visible: false
        }
        Item {
            id: frameMask
            anchors.fill: parent
            layer.enabled: true
            visible: false
            Rectangle { anchors.fill: parent; radius: root.px(26) * (1 - root.release) }
        }
        MultiEffect {
            anchors.fill: parent
            source: picture
            maskEnabled: true
            maskSource: frameMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
            opacity: Math.min(1, root.entrance * 1.6)
        }
    }

    // ── The placard ──
    Item {
        id: placard
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.band
        opacity: root.entrance * (1 - root.release)
        transform: Translate { y: Math.round((1 - root.entrance) * 24 * root.d + root.release * 30 * root.d) }

        // Time and day, left, set like a caption.
        Row {
            x: root.pad + root.inset
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.px(22)
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.px(8)
                LoginText {
                    id: clock
                    text: root.core.hours + ":" + root.core.minutes
                    color: root.ink
                    font.family: root.core.fontClock
                    font.pixelSize: root.px(80)
                    font.weight: Font.Medium
                    font.features: ({ "tnum": 1 })
                    font.letterSpacing: -root.px(2)
                }
                LoginText {
                    visible: root.core.meridiem.length > 0
                    anchors.baseline: clock.baseline
                    text: root.core.meridiem
                    color: root.inkSoft
                    font.family: root.core.fontMain
                    font.pixelSize: root.type(20)
                    font.weight: Font.DemiBold
                }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(1, Math.round(1.5 * root.d))
                height: root.px(50)
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.2)
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.px(2)
                LoginText {
                    text: root.core.weekday
                    color: root.ink
                    font.family: root.core.fontMain
                    font.pixelSize: root.type(19)
                    font.weight: Font.DemiBold
                }
                LoginText {
                    text: root.core.dayMonth
                    color: root.inkSoft
                    font.family: root.core.fontMain
                    font.pixelSize: root.type(19)
                }
            }
        }

        // Who and the password: one bar, right, ahead of the quiet actions.
        Item {
            id: bar
            visible: root.primary
            anchors.right: actions.left
            anchors.rightMargin: actions.width > 0 ? root.px(20) : 0
            anchors.verticalCenter: parent.verticalCenter
            width: root.px(560)
            height: root.px(60)
            transform: Translate { x: root.shakeX }
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: root.well
            }
            // The ring is a state: it says where your typing goes, or that it was wrong.
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: "transparent"
                border.width: Math.max(1, root.px(2))
                border.color: root.core.failed ? root.wrong : root.act
                opacity: entry.input.activeFocus || root.core.failed ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
            LoginAvatar {
                id: avatar
                visible: root.core.showAvatar
                x: root.px(6)
                anchors.verticalCenter: parent.verticalCenter
                width: root.px(48)
                height: width
                icon: root.core.userIcon
                name: root.core.userName
                fontFamily: root.core.fontMain
                ink: root.ink
                fill: root.well
            }
            Row {
                id: who
                visible: root.core.showName
                anchors.left: avatar.visible ? avatar.right : parent.left
                anchors.leftMargin: root.px(avatar.visible ? 14 : 24)
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.px(3)
                LoginText {
                    text: root.core.userName
                    color: root.ink
                    font.family: root.core.fontMain
                    font.pixelSize: root.type(18)
                    font.weight: Font.DemiBold
                }
                MSymbol {
                    visible: root.core.manyUsers
                    anchors.verticalCenter: parent.verticalCenter
                    text: "unfold_more"
                    symFont: root.core.symbolFont
                    iconSize: root.px(18)
                    iconColor: root.inkSoft
                }
            }
            MouseArea {
                anchors.fill: who
                enabled: root.core.manyUsers
                cursorShape: Qt.PointingHandCursor
                onClicked: root.core.nextUser()
            }
            Rectangle {
                id: divider
                visible: who.visible
                anchors.left: who.right
                anchors.leftMargin: root.px(16)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(1, Math.round(1.5 * root.d))
                height: root.px(24)
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.2)
            }
            LoginEntry {
                id: entry
                anchors.left: divider.visible ? divider.right : avatar.visible ? avatar.right : parent.left
                anchors.leftMargin: root.px(divider.visible || avatar.visible ? 16 : 24)
                anchors.right: submit.left
                anchors.rightMargin: root.px(10)
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                d: root.d
                busy: root.core.signingIn
                markColour: root.ink
                markSize: root.px(10)
                markGap: root.px(8)
                caretColour: root.act
                caretHeight: root.px(24)
                // A wrong password says so where the password goes; the field is empty again by then.
                placeholder: root.core.failed ? root.core.text.loginFailed : root.core.text.password
                placeholderColour: root.core.failed ? root.wrong : root.inkSoft
                fontWeight: root.core.failed ? Font.Medium : Font.Normal
                fontFamily: root.core.fontMain
                fontSize: root.type(17)
                onSubmitted: root.core.signIn()
                onEdited: root.core.typed()
            }
            LoginSubmit {
                id: submit
                anchors.right: parent.right
                anchors.rightMargin: root.px(6)
                anchors.verticalCenter: parent.verticalCenter
                width: root.px(48)
                height: width
                d: root.d
                shown: entry.count > 0
                busy: root.core.signingIn
                fill: root.act
                ink: root.onAct
                symbolFont: root.core.symbolFont
                onActivated: root.core.signIn()
            }
            LoginText {
                anchors.top: parent.bottom
                anchors.topMargin: root.px(10)
                anchors.left: parent.left
                anchors.leftMargin: entry.x
                width: parent.width - entry.x
                visible: root.core.showHint && !root.core.failed
                elide: Text.ElideRight
                text: root.core.hint
                color: root.core.hintIsWarning ? root.wrong : root.inkSoft
                font.family: root.core.fontMain
                font.pixelSize: root.type(14)
                font.weight: Font.Medium
            }
        }

        Row {
            id: actions
            visible: root.primary
            anchors.right: parent.right
            anchors.rightMargin: root.pad + root.inset - root.px(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.px(2)
            Plain { visible: root.core.manySessions; glyph: "desktop_windows"; label: root.core.sessionName; onActivated: root.core.nextSession() }
            Plain { visible: root.core.manyLayouts; glyph: "keyboard"; label: root.core.layoutName; onActivated: root.core.nextLayout() }
            Plain { visible: sddm.canSuspend; glyph: "bedtime"; onActivated: sddm.suspend() }
            Plain { visible: sddm.canReboot; glyph: "restart_alt"; onActivated: sddm.reboot() }
            Plain { visible: sddm.canPowerOff; glyph: "power_settings_new"; onActivated: sddm.powerOff() }
        }
    }
}
