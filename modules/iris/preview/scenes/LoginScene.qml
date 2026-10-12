pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.lock
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// The login screen (the SDDM greeter) in miniature, so a style is seen before the next boot. Each style follows its file
// in dots/sddm/pixel (LoginCover, LoginFrame, LoginLens, ClassicLogin) with the same proportions: every length is the
// greeter's own pixel at 1080p times `s`, which is how LoginSurface scales it to a screen. SDDM draws with its own Qt and
// reads the palette sync-pixel-sddm.py wrote; here the same roles come from IrisStyle (the dark scheme's accent and
// highlight, white ink over the picture) and from the apps' palette for Frame's mat and Classic.
PreviewScene {
    id: login
    readonly property real naturalWidth: Math.round(560 * login.d)
    readonly property real naturalHeight: Math.round(280 * login.d)

    // ── What the rows say ──
    readonly property string screen: String(login.opt("lock.loginScreen", "auto")) === "classic" ? "classic" : "iris"
    readonly property string style: ["cover", "frame", "lens"].indexOf(String(login.opt("lock.loginStyle", "lens"))) >= 0
        ? String(login.opt("lock.loginStyle", "lens")) : "lens"
    readonly property string source: String(login.opt("iris.lock.scene.source", "desktop"))
    readonly property bool hasPicture: login.source !== "colour"
    readonly property bool custom: login.source === "custom"
    readonly property string customPath: String(login.opt("iris.lock.scene.path", ""))
    readonly property bool showAvatar: Boolean(login.opt("iris.lock.blocks.session.avatar", true))
    readonly property bool showName: Boolean(login.opt("iris.lock.blocks.session.name", true))
    readonly property real typeScale: Math.max(0.8, Math.min(1.5, Number(login.opt("iris.lock.type.scale", 100)) / 100))

    // ── The greeter's scale: 1 at 1920x1080, by height or width, whichever is tighter ──
    readonly property real s: Math.max(0.1, Math.min(login.height / 1080, login.width / 1600))
    function px(n: real): int { return Math.round(n * login.s) }
    function type(n: real): int { return Math.max(7, Math.round(n * login.s * login.typeScale)) }

    // ── The palette the greeter wears ──
    readonly property color ink: IrisStyle.onMedia
    readonly property color inkSoft: IrisStyle.onMediaSecondary
    readonly property color inkFaint: IrisStyle.onMediaTertiary
    readonly property color accent: IrisStyle.accentOnMedia
    // Thin strokes need chroma to read as colour (LoginCore.accentInk).
    readonly property color accentInk: Qt.hsla(login.accent.hslHue, Math.min(1, login.accent.hslSaturation * 1.1 + 0.1), Math.min(login.accent.hslLightness, 0.7), 1)
    // The greeter wears the dark scheme whatever the session's (sync-pixel-sddm.py reads schemes.dark).
    readonly property var apps: { login.rev; return IrisStyle.washiDark?.apps ?? IrisStyle.washi?.apps ?? ({}) }
    function app(key: string, fallback: color): color {
        const hex = login.apps[key]
        return hex ? Qt.color(String(hex)) : fallback
    }

    // ── Time, as the greeter sets it ──
    readonly property date now: DateTime.clock.date
    readonly property string wantedClock: String(login.opt("iris.lock.type.clockFormat", "auto"))
    readonly property bool twelve: login.wantedClock === "12h" || (login.wantedClock === "auto" && /a/i.test(Qt.locale().timeFormat(Locale.ShortFormat)))
    readonly property string hours: Qt.formatDateTime(login.now, login.twelve ? "h" : "HH")
    readonly property string minutes: Qt.formatDateTime(login.now, "mm")
    function sentence(text: string): string { return text.length > 0 ? text.charAt(0).toUpperCase() + text.slice(1) : text }
    // The greeter's own date styles (LoginCore.date, from Lock › Type).
    readonly property string date: {
        const style = String(login.opt("iris.lock.type.dateFormat", "long"))
        if (style === "weekday") return login.sentence(Qt.locale().toString(login.now, "dddd"))
        if (style === "short") return login.sentence(Qt.locale().toString(login.now, "ddd d MMM"))
        if (style === "numeric") return Qt.locale().toString(login.now, Locale.ShortFormat)
        return login.sentence(Qt.locale().toString(login.now, "dddd, d MMMM"))
    }
    readonly property string weekday: login.sentence(Qt.locale().toString(login.now, "dddd"))
    readonly property string dayMonth: Qt.locale().toString(login.now, "d MMMM")
    readonly property string person: SystemInfo.displayName || SystemInfo.username || Translation.tr("You")

    readonly property Item picture: login.custom ? customShot : login.wallpaperView

    // One face per look, cross-faded when the choice changes (only while the preview plays).
    component Face: Loader {
        id: face
        property bool lit: false
        anchors.fill: parent
        active: face.lit || face.opacity > 0
        opacity: face.lit ? 1 : 0
        Behavior on opacity {
            enabled: login.playing
            NumberAnimation { duration: IrisStyle.duration(IrisStyle.settleDuration); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.emergeCurve }
        }
    }
    component Figure: IrisText {
        font.features: ({ "tnum": 1 })
        renderType: Text.NativeRendering
    }
    // The big figures of a style: its clock face, size and weight.
    component Digits: Figure {
        id: digits
        property real size: 0
        property int weight: Font.Normal
        property real tracking: 0
        font.family: IrisLockOptions.clockFamily
        font.pixelSize: digits.size
        font.weight: IrisStyle.weight(digits.weight)
        font.letterSpacing: -Math.round(digits.size * digits.tracking)
    }
    component Glyph: MaterialSymbol {
        iconSize: Math.max(8, login.px(16))
    }
    // The person: their face in a circle, or their initial.
    component Avatar: ClippingRectangle {
        id: face
        property int sourceIndex: 0
        color: IrisStyle.onMediaFill
        radius: IrisStyle.capsule(width)
        IrisImage {
            id: faceImage
            anchors.fill: parent
            source: Directories.avatarSourceAt(face.sourceIndex)
            visible: faceImage.status === Image.Ready
            onStatusChanged: {
                if (faceImage.status === Image.Error && face.sourceIndex + 1 < Directories.userAvatarPaths.length)
                    Qt.callLater(() => face.sourceIndex++)
            }
        }
        IrisText {
            anchors.centerIn: parent
            visible: faceImage.status !== Image.Ready
            text: login.person.charAt(0).toUpperCase()
            color: IrisStyle.onMedia
            font.pixelSize: Math.round(face.height * 0.42)
            font.weight: IrisStyle.weight(Font.DemiBold)
        }
    }

    // A custom picture (Lock Screen › Scene) is the greeter's picture too; otherwise it is the desktop's.
    Rectangle { anchors.fill: parent; color: IrisStyle.surface; visible: !login.hasPicture }
    IrisWallpaperView {
        id: customShot
        anchors.fill: parent
        visible: login.custom
        active: login.custom && login.preview.visible
        live: false
        screen: GlobalStates.focusedScreen
        path: login.custom ? login.customPath : configuredPath
        provideTexture: true
        decodeSize: Qt.size(Math.round(login.width), 0)
    }

    Face { lit: login.screen === "iris" && login.style === "cover"; sourceComponent: coverFace }
    Face { lit: login.screen === "iris" && login.style === "frame"; sourceComponent: frameFace }
    Face { lit: login.screen === "iris" && login.style === "lens"; sourceComponent: lensFace }
    Face { lit: login.screen === "classic"; sourceComponent: classicFace }

    Caption {
        glyph: login.screen === "classic" ? "lock_clock" : login.style === "cover" ? "wallpaper" : login.style === "frame" ? "frame_inspect" : "blur_on"
        text: login.screen === "classic" ? Translation.tr("Classic: the clock, then your password")
            : login.style === "cover" ? Translation.tr("Cover: your picture, sharp")
            : login.style === "frame" ? Translation.tr("Frame: your picture, hung in a mat")
            : Translation.tr("Lens: the time cut out of your picture")
    }

    // ── Cover (LoginCover.qml): the picture as a cover; one editorial column, bottom left ──
    Component {
        id: coverFace
        Item {
            id: cover
            readonly property real mx: login.px(112)
            readonly property real my: login.px(92)
            readonly property real clockSize: login.px(296)
            readonly property real columnWidth: Math.max(login.px(560), Math.round(coverInk.tightBoundingRect.width))
            readonly property real signInY: cover.height - cover.my - login.px(34) - login.px(60)
            TextMetrics { id: coverInk; font: coverHours.font; text: login.hours + ":" + login.minutes }
            // Ink where the type sits and nowhere else.
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.height * 0.74
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 0.55; color: IrisStyle.veilLight }
                    GradientStop { position: 1; color: IrisStyle.veil }
                }
            }
            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeWidth: -1
                    fillGradient: RadialGradient {
                        centerX: 0; centerY: cover.height
                        centerRadius: cover.height * 1.25
                        focalX: 0; focalY: cover.height
                        GradientStop { position: 0; color: IrisStyle.veilHeavy }
                        GradientStop { position: 0.38; color: IrisStyle.veilStrong }
                        GradientStop { position: 0.7; color: IrisStyle.veilLight }
                        GradientStop { position: 1; color: "transparent" }
                    }
                    startX: 0; startY: 0
                    PathLine { x: cover.width; y: 0 }
                    PathLine { x: cover.width; y: cover.height }
                    PathLine { x: 0; y: cover.height }
                    PathLine { x: 0; y: 0 }
                }
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: parent.height * 0.22
                gradient: Gradient {
                    GradientStop { position: 0; color: IrisStyle.veil }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
            // Masthead: the machine on the left, session and power on the right.
            IrisText {
                x: cover.mx
                y: Math.round(cover.my * 0.62)
                text: SystemInfo.hostname
                color: login.ink
                font.pixelSize: login.type(17)
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: cover.mx - login.px(10)
                y: Math.round(cover.my * 0.62) - login.px(9)
                spacing: login.px(4)
                Repeater {
                    model: ["bedtime", "restart_alt", "power_settings_new"]
                    Item {
                        required property string modelData
                        width: login.px(38); height: width
                        Glyph { anchors.centerIn: parent; text: parent.modelData; color: login.ink }
                    }
                }
            }
            Item {
                x: cover.mx
                width: cover.columnWidth
                height: cover.height
                Row {
                    y: clockRow.y + coverHours.baselineOffset + Math.round(coverInk.tightBoundingRect.y) - login.px(44) - height
                    spacing: login.px(14)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: login.px(28); height: Math.max(1, login.px(4)); radius: height / 2
                        color: login.accentInk
                    }
                    IrisText {
                        text: login.date
                        color: login.ink
                        font.pixelSize: login.type(22)
                        font.weight: IrisStyle.weight(Font.DemiBold)
                    }
                }
                Row {
                    id: clockRow
                    x: -Math.round(coverInk.tightBoundingRect.x)
                    y: cover.signInY - login.px(52) - coverHours.baselineOffset
                    Digits { id: coverHours; text: login.hours; color: login.ink; size: cover.clockSize; weight: Font.Light; tracking: 0.035 }
                    Digits { text: ":"; color: login.ink; size: cover.clockSize; weight: Font.Light; tracking: 0.035 }
                    Digits { text: login.minutes; color: login.ink; size: cover.clockSize; weight: Font.Light; tracking: 0.035 }
                }
                // Who, then the password on the same baseline.
                Item {
                    id: coverSignIn
                    width: parent.width
                    height: login.px(60)
                    y: cover.signInY
                    Row {
                        id: coverWho
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: login.px(16)
                        Avatar { visible: login.showAvatar; anchors.verticalCenter: parent.verticalCenter; width: login.px(44); height: width }
                        IrisText {
                            visible: login.showName
                            anchors.verticalCenter: parent.verticalCenter
                            text: login.person
                            color: login.ink
                            font.pixelSize: login.type(22)
                            font.weight: IrisStyle.weight(Font.DemiBold)
                        }
                    }
                    Rectangle {
                        id: coverCaret
                        x: coverWho.x + coverWho.width + login.px(30)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(1, login.px(2.5)); height: login.px(28); radius: width / 2
                        color: login.accentInk
                    }
                    IrisText {
                        anchors.verticalCenter: parent.verticalCenter
                        x: coverCaret.x + coverCaret.width + login.px(12)
                        text: Translation.tr("Password")
                        color: login.inkFaint
                        font.pixelSize: login.type(20)
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: Math.max(1, login.px(3)); radius: height / 2
                        color: IrisStyle.onMediaFillHover
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width; height: Math.max(1, login.px(3)); radius: height / 2
                        color: login.accentInk
                    }
                }
            }
        }
    }

    // ── Frame (LoginFrame.qml): the picture hung in a mat of the desktop's surface; the placard below ──
    Component {
        id: frameFace
        Item {
            id: framed
            readonly property real pad: login.px(20)
            readonly property real band: login.px(148)
            readonly property real inset: login.px(34)
            readonly property color mat: login.app("surface", IrisStyle.surfaceOpaque)
            readonly property color matInk: login.app("onSurface", IrisStyle.text)
            readonly property color matSoft: login.app("onSurfaceVariant", IrisStyle.subtext)
            readonly property color act: login.app("primary", IrisStyle.accent)
            readonly property color well: Qt.rgba(framed.matInk.r, framed.matInk.g, framed.matInk.b, 0.08)
            readonly property color rule: login.app("outlineVariant", IrisStyle.border)
            Rectangle { anchors.fill: parent; color: framed.mat }
            ClippingRectangle {
                x: framed.pad; y: framed.pad
                width: framed.width - 2 * framed.pad
                height: framed.height - framed.pad - framed.band
                radius: login.px(26)
                color: IrisStyle.surface
                IrisWallpaperView {
                    anchors.fill: parent
                    visible: login.hasPicture
                    active: login.hasPicture && login.preview.visible
                    live: false
                    screen: GlobalStates.focusedScreen
                    path: login.custom ? login.customPath : configuredPath
                    decodeSize: Qt.size(Math.round(login.width), 0)
                }
            }
            // The placard: time and day on the left, who and the password on the right, then the quiet actions.
            Item {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: framed.band
                Row {
                    x: framed.pad + framed.inset
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: login.px(22)
                    Figure {
                        anchors.verticalCenter: parent.verticalCenter
                        text: login.hours + ":" + login.minutes
                        color: framed.matInk
                        font.family: IrisLockOptions.clockFamily
                        font.pixelSize: login.px(80)
                        font.weight: IrisStyle.weight(Font.Medium)
                        font.letterSpacing: -login.px(2)
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(1, login.px(1.5)); height: login.px(50)
                        color: framed.rule
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: login.px(2)
                        IrisText { text: login.weekday; color: framed.matInk; font.pixelSize: login.type(19); font.weight: IrisStyle.weight(Font.DemiBold) }
                        IrisText { text: login.dayMonth; color: framed.matSoft; font.pixelSize: login.type(19) }
                    }
                }
                Row {
                    id: frameActions
                    anchors.right: parent.right
                    anchors.rightMargin: framed.pad + framed.inset - login.px(10)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: login.px(2)
                    Repeater {
                        model: ["bedtime", "restart_alt", "power_settings_new"]
                        Item {
                            required property string modelData
                            width: login.px(44); height: width
                            Glyph { anchors.centerIn: parent; text: parent.modelData; color: framed.matInk }
                        }
                    }
                }
                Item {
                    id: frameBar
                    anchors.right: frameActions.left
                    anchors.rightMargin: login.px(20)
                    anchors.verticalCenter: parent.verticalCenter
                    width: login.px(560); height: login.px(60)
                    Rectangle { anchors.fill: parent; radius: height / 2; color: framed.well }
                    // The ring is a state: it says where your typing goes.
                    Rectangle {
                        anchors.fill: parent; radius: height / 2
                        color: "transparent"
                        border.width: Math.max(1, login.px(2)); border.color: framed.act
                    }
                    Avatar {
                        id: frameAvatar
                        visible: login.showAvatar
                        x: login.px(6); anchors.verticalCenter: parent.verticalCenter
                        width: login.px(48); height: width
                    }
                    IrisText {
                        id: frameWho
                        visible: login.showName
                        anchors.left: frameAvatar.visible ? frameAvatar.right : parent.left
                        anchors.leftMargin: login.px(frameAvatar.visible ? 14 : 24)
                        anchors.verticalCenter: parent.verticalCenter
                        text: login.person
                        color: framed.matInk
                        font.pixelSize: login.type(18)
                        font.weight: IrisStyle.weight(Font.DemiBold)
                    }
                    Rectangle {
                        id: frameDivider
                        anchors.left: frameWho.right
                        anchors.leftMargin: login.px(16)
                        anchors.verticalCenter: parent.verticalCenter
                        visible: frameWho.visible
                        width: Math.max(1, login.px(1.5)); height: login.px(24)
                        color: framed.rule
                    }
                    Rectangle {
                        id: frameCaret
                        anchors.left: frameDivider.visible ? frameDivider.right : frameAvatar.right
                        anchors.leftMargin: login.px(16)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(1, login.px(2.5)); height: login.px(24); radius: width / 2
                        color: framed.act
                    }
                    IrisText {
                        anchors.left: frameCaret.right
                        anchors.leftMargin: login.px(12)
                        anchors.verticalCenter: parent.verticalCenter
                        text: Translation.tr("Password")
                        color: framed.matSoft
                        font.pixelSize: login.type(17)
                    }
                }
            }
        }
    }

    // ── Lens (LoginLens.qml): the picture out of focus, the time cut out of it as a lens onto the sharp picture ──
    Component {
        id: lensFace
        Item {
            id: lens
            readonly property real clockSize: login.px(372)
            readonly property real clockCentreY: Math.round(lens.height * 0.4)
            // Out of focus and dimmed, a little richer than the picture so it never reads grey.
            MultiEffect {
                anchors.fill: parent
                visible: login.hasPicture
                source: login.picture.textureItem
                scale: 1.08
                blurEnabled: true
                blur: 1
                blurMax: Math.max(8, login.px(56))
                saturation: 0.12
                brightness: -0.04
                autoPaddingEnabled: false
            }
            Rectangle { anchors.fill: parent; color: IrisStyle.veil; opacity: 0.86 }
            Item {
                id: lensMask
                anchors.fill: parent
                layer.enabled: true
                visible: false
                Row {
                    id: lensRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: lens.clockCentreY - Math.round(height / 2)
                    Digits { text: login.hours; color: IrisStyle.onMedia; size: lens.clockSize; weight: Font.Bold; tracking: 0.03 }
                    Digits { text: ":"; color: IrisStyle.onMedia; size: lens.clockSize; weight: Font.Bold; tracking: 0.03 }
                    Digits { text: login.minutes; color: IrisStyle.onMedia; size: lens.clockSize; weight: Font.Bold; tracking: 0.03 }
                }
            }
            // A soft fall of shadow lifts the lens off the blur.
            MultiEffect {
                anchors.fill: parent
                transform: Translate { y: login.px(14) }
                source: lensMask
                blurEnabled: true
                blur: 1
                blurMax: Math.max(8, login.px(64))
                colorization: 1
                colorizationColor: IrisStyle.darkSurfaceOpaque
                opacity: 0.55
            }
            // A pale base under the lens: where the picture is dark, the figures still read lighter than the blur.
            MultiEffect { anchors.fill: parent; source: lensMask; opacity: 0.3 }
            MultiEffect {
                anchors.fill: parent
                visible: login.hasPicture
                source: login.picture.textureItem
                opacity: 0.9
                maskEnabled: true
                maskSource: lensMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
                brightness: 0.16
                saturation: 0.2
                autoPaddingEnabled: false
            }
            IrisText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: lens.clockCentreY + Math.round(lensRow.height * 0.36)
                text: login.date
                color: login.ink
                font.pixelSize: login.type(26)
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
            // Who, and the password.
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(lens.height * 0.72)
                spacing: login.px(18)
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: login.showAvatar || login.showName
                    spacing: login.px(12)
                    Avatar { visible: login.showAvatar; anchors.verticalCenter: parent.verticalCenter; width: login.px(38); height: width }
                    IrisText {
                        visible: login.showName
                        anchors.verticalCenter: parent.verticalCenter
                        text: login.person
                        color: login.ink
                        font.pixelSize: login.type(20)
                        font.weight: IrisStyle.weight(Font.DemiBold)
                    }
                }
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: login.px(460); height: login.px(64)
                    Rectangle { anchors.fill: parent; radius: height / 2; color: IrisStyle.veil; opacity: 0.7 }
                    Rectangle {
                        anchors.fill: parent; radius: height / 2
                        color: "transparent"
                        border.width: Math.max(1, login.px(2)); border.color: login.accentInk
                    }
                    IrisText {
                        id: lensPrompt
                        anchors.centerIn: parent
                        text: Translation.tr("Password")
                        color: login.inkFaint
                        font.pixelSize: login.type(18)
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: lensPrompt.x - width - login.px(10)
                        width: Math.max(1, login.px(2.5)); height: login.px(26); radius: width / 2
                        color: login.accentInk
                    }
                }
            }
            // Corners: session left, power right.
            Row {
                anchors { left: parent.left; bottom: parent.bottom; margins: login.px(40) }
                spacing: login.px(6)
                Glyph { anchors.verticalCenter: parent.verticalCenter; text: "desktop_windows"; color: login.ink }
                IrisText { anchors.verticalCenter: parent.verticalCenter; text: "Niri"; color: login.ink; font.pixelSize: login.type(16); font.weight: IrisStyle.weight(Font.Medium) }
            }
            Row {
                anchors { right: parent.right; bottom: parent.bottom; margins: login.px(40) }
                spacing: login.px(14)
                Repeater {
                    model: ["bedtime", "restart_alt", "power_settings_new"]
                    Glyph { required property string modelData; text: modelData; color: login.ink }
                }
            }
        }
    }

    // ── Classic (ClassicLogin.qml, a replica of the Material lock): the clock, the date, a line to start ──
    Component {
        id: classicFace
        Item {
            id: classic
            readonly property color ink: login.app("onSurface", IrisStyle.text)
            Rectangle {
                anchors.fill: parent
                opacity: 0.7
                gradient: Gradient {
                    GradientStop { position: 0; color: IrisStyle.veilLight }
                    GradientStop { position: 0.5; color: "transparent" }
                    GradientStop { position: 1; color: IrisStyle.veil }
                }
            }
            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -login.px(80)
                spacing: login.px(8)
                IrisText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(login.now, "hh:mm")
                    color: classic.ink
                    font.family: "Roboto"
                    font.pixelSize: login.px(108)
                    font.weight: IrisStyle.weight(Font.DemiBold)
                }
                IrisText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(login.now, "dddd, d MMMM")
                    color: classic.ink
                    font.family: "Roboto"
                    font.pixelSize: login.type(22)
                }
            }
            IrisText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: login.px(40)
                text: Translation.tr("Press any key or click to login")
                color: login.app("onSurfaceVariant", IrisStyle.subtext)
                font.family: "Roboto"
                font.pixelSize: login.type(15)
            }
        }
    }
}
