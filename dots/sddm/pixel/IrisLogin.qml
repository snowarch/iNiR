// iNiR SDDM, iRiS appearance: the iRiS lock screen (modules/iris/lock) as a login screen.
// Everything it shows comes from theme.conf, which sync-pixel-sddm.py writes from the iRiS lock's own
// options (layout, scene, type) and the iRiS palette, so the login screen wears what the lock wears.
// SDDM's Qt only: no Quickshell, no IrisStyle; the values those give the lock arrive here resolved.
import QtQuick 2.15
import QtQuick.Effects
import QtQuick.Shapes
import SddmComponents 2.0
import "."

Item {
    id: root
    focus: true

    // ── theme.conf ──────────────────────────────────────────────────────────
    function cfg(key, fallback) {
        const v = config[key]
        return (v === undefined || v === null || String(v).length === 0) ? fallback : v
    }
    function num(key, fallback) {
        const n = Number(root.cfg(key, fallback))
        return isNaN(n) ? fallback : n
    }
    function flag(key, fallback) {
        return String(root.cfg(key, fallback ? "true" : "false")).toLowerCase() === "true"
    }

    readonly property real d: Math.max(0.8, Math.min(2.5, root.height / 1080))
    readonly property real margin: Math.round(56 * root.d)
    readonly property real typeScale: Math.max(0.6, Math.min(1.6, root.num("irisTypeScale", 100) / 100))

    readonly property color onMedia: "#ffffff"
    readonly property color onMediaSecondary: Qt.rgba(1, 1, 1, 0.72)
    readonly property color onMediaFill: Qt.rgba(1, 1, 1, 0.2)
    readonly property color onMediaFillHover: Qt.rgba(1, 1, 1, 0.3)
    readonly property color mediaGlass: Qt.rgba(0, 0, 0, 0.16)
    readonly property color mediaHairline: Qt.rgba(1, 1, 1, 0.16)
    readonly property color danger: root.cfg("irisDanger", "#ff6961")
    readonly property color clockColour: root.cfg("irisClockColour", "#ffffff")
    // One accent for what acts or is alive (the sign-in button, the ring while signing in), the
    // highlight for the clock's separator: iRiS's clock grammar, the one warm mark on the field.
    readonly property color accent: root.cfg("irisAccent", "#a8c7fa")
    readonly property color onAccent: root.accent.hslLightness > 0.6 ? "#101012" : "#ffffff"
    readonly property color highlight: root.cfg("irisHighlight", "#ff9f0a")
    readonly property var expressive: [0.16, 1, 0.3, 1, 1, 1]
    property real entrance: 0
    Component.onCompleted: arrive.start()
    NumberAnimation { id: arrive; target: root; property: "entrance"; from: 0; to: 1; duration: 900; easing.type: Easing.BezierSpline; easing.bezierCurve: root.expressive }

    readonly property string fontMain: root.cfg("irisFontMain", "Inter")
    readonly property string fontClock: root.cfg("irisFontClock", "Rubik")

    // ── SDDM state ──────────────────────────────────────────────────────────
    // Qt.DisplayRole is undefined in sddm-greeter; these are SDDM's own roles (see ClassicLogin.qml).
    readonly property int nameRole: Qt.UserRole + 1
    readonly property int realNameRole: Qt.UserRole + 2
    readonly property int iconRole: Qt.UserRole + 4
    readonly property int sessionNameRole: Qt.UserRole + 4
    function modelText(model, index, role) {
        if (!model || model.count <= 0) return ""
        const v = model.data(model.index(index, 0), role)
        return (v === undefined || v === null) ? "" : String(v)
    }

    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    readonly property string userLogin: root.modelText(userModel, root.userIndex, root.nameRole) || userModel.lastUser || ""
    readonly property string userName: root.modelText(userModel, root.userIndex, root.realNameRole) || root.userLogin
    readonly property string userIcon: root.modelText(userModel, root.userIndex, root.iconRole)
    readonly property string sessionName: root.modelText(sessionModel, root.sessionIndex, root.sessionNameRole) || "Desktop"
    property bool signingIn: false
    property real release: 0
    property bool failed: false

    function signIn() {
        if (root.signingIn || password.text.length === 0) return
        root.signingIn = true
        root.failed = false
        sddm.login(root.userLogin, password.text, root.sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginSucceeded() { root.signingIn = true; leave.start() }
        function onLoginFailed() {
            root.signingIn = false
            root.failed = true
            password.text = ""
            shake.restart()
            password.forceActiveFocus()
        }
    }

    TextConstants { id: textConstants }
    FontLoader { id: symbols; source: "fonts/MaterialSymbolsRounded.ttf" }
    // One static file per weight (a variable font ignores font.weight); install-pixel-sddm.sh copies them from assets/fonts.
    FontLoader { source: "fonts/Rubik-Light.ttf" }
    FontLoader { source: "fonts/Rubik-Regular.ttf" }
    FontLoader { source: "fonts/Rubik-Medium.ttf" }
    FontLoader { source: "fonts/Rubik-SemiBold.ttf" }
    FontLoader { source: "fonts/Rubik-Bold.ttf" }
    FontLoader { source: "fonts/Rubik-ExtraBold.ttf" }
    FontLoader { source: "fonts/Rubik-Black.ttf" }
    FontLoader { source: "fonts/Inter-Regular.ttf" }
    FontLoader { source: "fonts/Inter-Medium.ttf" }
    FontLoader { source: "fonts/Inter-SemiBold.ttf" }
    FontLoader { source: "fonts/Inter-Bold.ttf" }
    readonly property string symbolFont: symbols.status === FontLoader.Ready ? symbols.name : ""

    // ── Scene: the picture, blurred and washed like the lock's ──────────────
    readonly property string sceneSource: String(root.cfg("irisSceneSource", "desktop"))
    readonly property real blurAmount: Math.max(0, Math.min(1, root.num("irisBlur", 100) / 100))
    readonly property real colourLeft: Math.max(0, Math.min(1, root.num("irisSaturation", 15) / 100))
    readonly property real dim: Math.max(0, Math.min(1, root.num("irisDim", 0) / 100))
    readonly property real vignette: Math.max(0, Math.min(1, root.num("irisVignette", 0) / 100))
    readonly property real scrimStrength: Math.max(0, Math.min(2, root.num("irisScrimStrength", 100) / 100))
    readonly property string scrimStyle: String(root.cfg("irisScrim", "gradient"))
    readonly property bool blurOn: picture.status === Image.Ready && root.blurAmount > 0.01

    Rectangle {
        anchors.fill: parent
        color: root.cfg("irisSurface", "#0b0b0c")
    }
    Image {
        id: picture
        anchors.fill: parent
        visible: !root.blurOn
        source: root.sceneSource === "colour" ? "" : root.cfg("irisPicture", config.background || "")
        fillMode: String(root.cfg("irisFit", "cover")) === "contain" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width, root.height)
        asynchronous: true
        cache: false
    }
    MultiEffect {
        anchors.fill: picture
        source: picture
        visible: root.blurOn
        // Like the lock's scenery: a blur darkens its own edges, so they sit just outside the screen.
        scale: 1.06
        blurEnabled: true
        blur: 1
        blurMax: Math.round(48 * root.blurAmount * (1 - root.release))
        // The lock's own mapping (IrisLockSurface): 0 leaves the colour, -1 is grey; it returns as the blur releases.
        saturation: (root.colourLeft - 1) * (1 - root.release)
    }
    Item {
        anchors.fill: parent
        visible: picture.status === Image.Ready
        // A light picture gets an even veil so white text keeps its contrast (measured by the sync).
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, Math.max(0, Math.min(0.5, root.num("irisLift", 0))))
        }
        Rectangle {
            anchors.fill: parent
            visible: root.scrimStyle === "gradient"
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.28 * root.scrimStrength) }
                GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.12 * root.scrimStrength) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.42 * root.scrimStrength) }
            }
        }
        Rectangle {
            anchors.fill: parent
            visible: root.scrimStyle === "flat"
            color: Qt.rgba(0, 0, 0, 0.32 * root.scrimStrength)
        }
    }
    Shape {
        anchors.fill: parent
        visible: root.vignette > 0.001
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: root.width / 2; centerY: root.height / 2
                centerRadius: Math.hypot(root.width, root.height) / 2
                focalX: root.width / 2; focalY: root.height / 2
                GradientStop { position: 0.45; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, root.vignette) }
            }
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: root.dim > 0.001
        color: Qt.rgba(0, 0, 0, root.dim)
    }

    // ── Blocks in the lock's zones; one zone holding both stacks the clock over the sign-in ──
    readonly property var zones: ["top", "center", "bottom", "topLeft", "topRight", "bottomLeft", "bottomRight", "left", "right"]
    readonly property string clockZone: String(root.cfg("irisClockZone", "top"))
    readonly property string sessionZone: String(root.cfg("irisSessionZone", "bottom"))
    readonly property bool clockShown: root.flag("irisClock", true)
    readonly property bool shareZone: root.clockShown && root.clockZone === root.sessionZone && root.zones.indexOf(root.clockZone) >= 0
    readonly property real blockGap: Math.round(24 * root.d)

    function anchorOf(zone) {
        const left = zone === "left" || zone.endsWith("Left")
        const right = zone === "right" || zone.endsWith("Right")
        return {
            x: left ? root.margin : right ? root.width - root.margin : root.width / 2,
            y: zone.startsWith("top") ? Math.round(root.height * 0.09)
                : zone.startsWith("bottom") ? Math.round(root.height * 0.89) : root.height / 2,
            align: left ? "left" : right ? "right" : "center",
            grow: zone.startsWith("bottom") ? "up" : zone.startsWith("top") ? "down" : "middle"
        }
    }
    function blockX(zone, fx, w) {
        if (root.zones.indexOf(zone) < 0) return Math.round(root.width * fx - w / 2)
        const at = root.anchorOf(zone)
        return Math.round(at.align === "left" ? at.x : at.align === "right" ? at.x - w : at.x - w / 2)
    }
    // Top of a zone's stack of `total` height; a free block is centred on its own point.
    function stackTop(zone, fy, total) {
        if (root.zones.indexOf(zone) < 0) return Math.round(root.height * fy - total / 2)
        const at = root.anchorOf(zone)
        return Math.round(at.grow === "down" ? at.y : at.grow === "up" ? at.y - total : at.y - total / 2)
    }
    readonly property real clockFx: root.num("irisClockFx", 0.5)
    readonly property real clockFy: root.num("irisClockFy", 0.4)
    readonly property real sessionFx: root.num("irisSessionFx", 0.5)
    readonly property real sessionFy: root.num("irisSessionFy", 0.6)
    readonly property real sharedTop: root.stackTop(root.clockZone, root.clockFy, clock.height + root.blockGap + session.height)

    Column {
        id: clock
        readonly property string style: String(root.cfg("irisClockStyle", "stack"))
        property date now: new Date()
        visible: root.clockShown
        opacity: root.entrance
        transform: Translate { y: Math.round((1 - root.entrance) * 18 * root.d) }
        spacing: -Math.round(6 * root.d)
        x: root.blockX(root.clockZone, root.clockFx, clock.width)
        y: root.shareZone ? root.sharedTop : root.stackTop(root.clockZone, root.clockFy, clock.height)
        Timer {
            interval: 1000; running: clock.visible; repeat: true
            onTriggered: clock.now = new Date()
        }
        Text {
            anchors.horizontalCenter: clock.horizontalCenter
            visible: root.flag("irisClockDate", true) && clock.style === "stack"
            text: {
                const style = String(root.cfg("irisDateFormat", "long"))
                if (style === "weekday") return Qt.locale().toString(clock.now, "dddd")
                if (style === "short") return Qt.locale().toString(clock.now, "ddd d MMM")
                if (style === "numeric") return Qt.locale().toString(clock.now, Locale.ShortFormat)
                return Qt.locale().toString(clock.now, "dddd, d MMMM")
            }
            color: root.onMedia
            font.family: root.fontMain
            font.pixelSize: Math.round(21 * root.typeScale * root.d)
            font.weight: Font.DemiBold
        }
        // Hours and minutes heavy, the separator in the highlight, seconds and AM/PM small and quiet.
        Row {
            id: time
            anchors.horizontalCenter: clock.horizontalCenter
            readonly property string wanted: String(root.cfg("irisClockFormat", "auto"))
            readonly property bool twelve: time.wanted === "12h"
                || (time.wanted === "auto" && /a/i.test(Qt.locale().timeFormat(Locale.ShortFormat)))
            readonly property real size: Math.round(Math.max(24, root.num("irisClockSize", 112)) * root.typeScale * root.d
                * (clock.style === "minimal" ? 0.45 : 1))
            readonly property int weight: Math.max(100, Math.min(900, root.num("irisClockWeight", 700)))
            component Figure: Text {
                color: root.clockColour
                font.family: root.fontClock
                font.features: ({ "tnum": 1 })
                font.pixelSize: time.size
                font.weight: time.weight
                font.letterSpacing: root.num("irisClockTracking", -2)
            }
            Figure { id: hours; text: Qt.formatDateTime(clock.now, time.twelve ? "h" : "HH") }
            Figure {
                text: ":"
                color: Qt.colorEqual(root.clockColour, "#ffffff") ? root.highlight : Qt.rgba(1, 1, 1, 0.55)
            }
            Figure { text: Qt.formatDateTime(clock.now, "mm") }
            Figure {
                visible: root.flag("irisClockSeconds", false) || time.twelve
                anchors.baseline: hours.baseline
                text: (root.flag("irisClockSeconds", false) ? Qt.formatDateTime(clock.now, ":ss") : "")
                    + (time.twelve ? " " + Qt.formatDateTime(clock.now, "AP") : "")
                opacity: 0.55
                font.pixelSize: Math.round(time.size * 0.58)
            }
        }
    }

    Column {
        id: session
        readonly property bool many: userModel.count > 1
        spacing: 0
        opacity: Math.max(0, Math.min(1, root.entrance * 1.25 - 0.25))
        transform: Translate { y: Math.round((1 - root.entrance) * 28 * root.d) }
        x: root.blockX(root.sessionZone, root.sessionFx, session.width)
        y: root.shareZone ? root.sharedTop + clock.height + root.blockGap
            : root.stackTop(root.sessionZone, root.sessionFy, session.height)

        Rectangle {
            id: avatarRing
            anchors.horizontalCenter: session.horizontalCenter
            visible: root.flag("irisAvatar", true)
            width: Math.round(92 * root.d)
            height: width
            radius: width / 2
            color: root.mediaGlass
            border.width: Math.max(1, Math.round(1.5 * root.d))
            border.color: root.mediaHairline
            Item {
                id: avatar
                anchors.centerIn: parent
                width: Math.round(84 * root.d)
                height: width
                property int sourceIndex: 0
                readonly property var sources: [root.userIcon, String(Qt.resolvedUrl("assets/user-face.png"))].filter(s => s.length > 0)
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: avatarMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                }
                Rectangle { anchors.fill: parent; color: root.onMediaFill }
                Image {
                    id: avatarImage
                    anchors.fill: parent
                    source: avatar.sources[avatar.sourceIndex] || ""
                    sourceSize: Qt.size(avatar.width * 2, avatar.height * 2)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    onStatusChanged: if (status === Image.Error && avatar.sourceIndex + 1 < avatar.sources.length) avatar.sourceIndex++
                }
                Text {
                    anchors.centerIn: parent
                    visible: avatarImage.status !== Image.Ready
                    text: (root.userName || "?").charAt(0).toUpperCase()
                    color: root.onMedia
                    font.family: root.fontMain
                    font.pixelSize: Math.round(34 * root.typeScale * root.d)
                    font.weight: Font.DemiBold
                }
            }
            Shape {
                anchors.fill: parent
                visible: root.signingIn
                RotationAnimation on rotation { running: root.signingIn; from: 0; to: 360; duration: 1100; loops: Animation.Infinite }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: root.accent
                    strokeWidth: Math.max(2, Math.round(2.5 * root.d))
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: avatarRing.width / 2; centerY: avatarRing.height / 2
                        radiusX: avatarRing.width / 2 - Math.max(1, Math.round(1.25 * root.d))
                        radiusY: radiusX
                        startAngle: -90; sweepAngle: 110
                    }
                }
            }
            Item {
                id: avatarMask
                anchors.fill: avatar
                layer.enabled: true
                visible: false
                Rectangle { anchors.fill: parent; radius: width / 2 }
            }
        }
        Item { width: 1; height: root.flag("irisAvatar", true) ? Math.round(12 * root.d) : 0 }

        // With more than one account, the name is the switch.
        Item {
            anchors.horizontalCenter: session.horizontalCenter
            visible: root.flag("irisName", true)
            width: nameRow.width
            height: nameRow.height
            Row {
                id: nameRow
                spacing: Math.round(4 * root.d)
                Text {
                    text: root.userName
                    color: root.onMedia
                    font.family: root.fontMain
                    font.pixelSize: Math.round(18 * root.typeScale * root.d)
                    font.weight: Font.DemiBold
                }
                MSymbol {
                    visible: session.many
                    anchors.verticalCenter: parent.verticalCenter
                    text: "unfold_more"
                    symFont: root.symbolFont
                    iconSize: Math.round(18 * root.d)
                    iconColor: root.onMediaSecondary
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: session.many
                cursorShape: session.many ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    root.userIndex = (root.userIndex + 1) % userModel.count
                    password.text = ""
                    password.forceActiveFocus()
                }
            }
        }
        Item { width: 1; height: Math.round(16 * root.d) }

        Item {
            id: capsule
            anchors.horizontalCenter: session.horizontalCenter
            width: Math.round(Math.max(160, root.num("irisSessionWidth", 248)) * root.d)
            height: Math.round(44 * root.d)
            transform: Translate { id: shakeOffset }

            // The lock's glass capsule: a cut edge that catches light, filled while you type.
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: password.activeFocus ? Qt.rgba(1, 1, 1, 0.1) : root.mediaGlass
                border.width: Math.max(1, Math.round((root.failed ? 1.5 : 1) * root.d))
                border.color: root.failed ? Qt.rgba(root.danger.r, root.danger.g, root.danger.b, 0.7)
                    : password.activeFocus ? Qt.rgba(1, 1, 1, 0.26) : root.mediaHairline
                Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
            TextInput {
                id: password
                objectName: "password"
                anchors.fill: parent
                anchors.leftMargin: Math.round(44 * root.d)
                anchors.rightMargin: Math.round(44 * root.d)
                verticalAlignment: TextInput.AlignVCenter
                // Empty, the caret waits at the start so it never cuts through the placeholder.
                horizontalAlignment: text.length > 0 ? TextInput.AlignHCenter : TextInput.AlignLeft
                echoMode: TextInput.Password
                passwordCharacter: "●"
                color: root.onMedia
                selectionColor: root.onMediaFillHover
                font.family: root.fontMain
                font.pixelSize: Math.round(14 * root.typeScale * root.d)
                font.letterSpacing: 1
                clip: true
                focus: true
                enabled: !root.signingIn
                onAccepted: root.signIn()
                onTextChanged: if (text.length > 0) root.failed = false
                Keys.onEscapePressed: text = ""
                Component.onCompleted: forceActiveFocus()
                Text {
                    anchors.centerIn: parent
                    visible: password.text.length === 0
                    text: textConstants.password
                    color: root.onMediaSecondary
                    font.family: root.fontMain
                    font.pixelSize: Math.round(13 * root.typeScale * root.d)
                }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: Math.round(6 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(32 * root.d)
                height: width
                radius: width / 2
                color: submitArea.containsMouse ? Qt.lighter(root.accent, 1.08) : root.accent
                opacity: password.text.length > 0 || root.signingIn ? 1 : 0
                scale: opacity > 0 ? 1 : 0.6
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: root.expressive } }
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                MSymbol {
                    anchors.centerIn: parent
                    text: root.signingIn ? "more_horiz" : "arrow_forward"
                    symFont: root.symbolFont
                    iconSize: Math.round(18 * root.d)
                    iconColor: root.onAccent
                }
                MouseArea {
                    id: submitArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.signIn()
                }
            }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: shakeOffset; property: "x"; to: -12 * root.d; duration: 45; easing.type: Easing.OutQuad }
                NumberAnimation { target: shakeOffset; property: "x"; to: 10 * root.d; duration: 70; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shakeOffset; property: "x"; to: -6 * root.d; duration: 60; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 55; easing.type: Easing.OutQuad }
            }
        }
        Item { width: 1; height: Math.round(10 * root.d) }
        Text {
            anchors.horizontalCenter: session.horizontalCenter
            visible: root.flag("irisHint", true)
            text: root.signingIn ? " "
                : root.failed ? textConstants.loginFailed
                : keyboard.capsLock ? textConstants.capslockWarning : " "
            color: root.failed ? root.danger : keyboard.capsLock ? root.highlight : root.onMediaSecondary
            font.family: root.fontMain
            font.pixelSize: Math.round(12 * root.typeScale * root.d)
        }
    }

    // ── Status corner: session, keyboard layout, power. Plain on the picture, filled on hover ──
    component StatusItem: Item {
        id: item
        property string glyph: ""
        property string label: ""
        signal activated()
        readonly property real pad: Math.round((item.label.length > 0 ? 12 : 7) * root.d)
        implicitWidth: itemRow.implicitWidth + 2 * item.pad
        implicitHeight: Math.round(32 * root.d)
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: itemArea.pressed ? root.onMediaFillHover : root.onMediaFill
            opacity: itemArea.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
        Row {
            id: itemRow
            anchors.centerIn: parent
            spacing: Math.round(6 * root.d)
            MSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: item.glyph
                symFont: root.symbolFont
                iconSize: Math.round(18 * root.d)
                iconColor: root.onMedia
            }
            Text {
                visible: item.label.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: item.label
                color: root.onMedia
                font.family: root.fontMain
                font.pixelSize: Math.round(13 * root.typeScale * root.d)
                font.weight: Font.Medium
            }
        }
        MouseArea {
            id: itemArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: item.activated()
        }
    }

    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Math.round(root.height * 0.09) - Math.round(16 * root.d)
        anchors.rightMargin: root.margin - Math.round(12 * root.d)
        spacing: Math.round(2 * root.d)
        StatusItem {
            visible: sessionModel.count > 1
            glyph: "desktop_windows"
            label: root.sessionName
            onActivated: root.sessionIndex = (root.sessionIndex + 1) % sessionModel.count
        }
        StatusItem {
            visible: keyboard.layouts.length > 1
            glyph: "keyboard"
            label: keyboard.layouts[keyboard.currentLayout] ? String(keyboard.layouts[keyboard.currentLayout].shortName).toUpperCase() : ""
            onActivated: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
        }
        StatusItem { visible: sddm.canSuspend; glyph: "bedtime"; onActivated: sddm.suspend() }
        StatusItem { visible: sddm.canReboot; glyph: "restart_alt"; onActivated: sddm.reboot() }
        StatusItem { visible: sddm.canPowerOff; glyph: "power_settings_new"; onActivated: sddm.powerOff() }
    }

    // Typing anywhere goes to the password.
    Keys.onPressed: event => {
        if (event.text.length === 1 && event.text.charCodeAt(0) >= 32 && !root.signingIn && !password.activeFocus) {
            password.forceActiveFocus()
            password.text += event.text
            event.accepted = true
        }
    }

    // Signing in reads like unlocking: the picture comes into focus as everything else steps away.
    ParallelAnimation {
        id: leave
        NumberAnimation { target: root; property: "release"; to: 1; duration: 520; easing.type: Easing.BezierSpline; easing.bezierCurve: root.expressive }
        NumberAnimation { target: root; property: "entrance"; to: 0; duration: 360; easing.type: Easing.InCubic }
    }
}
