// What every iRiS login style shares: theme.conf, SDDM's accounts and sessions, signing in and its outcome.
// A style owns the pixels; this owns the state. SDDM's Qt only: no Quickshell, no IrisStyle; inir-accel sddm-sync
// writes the values those would give.
import QtQuick 2.15
import SddmComponents 2.0

QtObject {
    id: core

    // ── theme.conf ──
    function cfg(key, fallback) {
        const v = config[key]
        return (v === undefined || v === null || String(v).length === 0) ? fallback : v
    }
    function num(key, fallback) {
        const n = Number(core.cfg(key, fallback))
        return isNaN(n) ? fallback : n
    }
    function flag(key, fallback) {
        return String(core.cfg(key, fallback ? "true" : "false")).toLowerCase() === "true"
    }

    readonly property color accent: core.cfg("irisAccent", "#a8c7fa")
    // Thin strokes (a caret, a rule, a ring) need chroma to read as colour; the palette's accent is a pastel.
    readonly property color accentInk: Qt.hsla(core.accent.hslHue, Math.min(1, core.accent.hslSaturation * 1.1 + 0.1),
        Math.min(core.accent.hslLightness, 0.7), 1)
    readonly property color onAccent: core.accent.hslLightness > 0.6 ? "#101012" : "#ffffff"
    readonly property color highlight: core.cfg("irisHighlight", "#ff9f0a")
    readonly property color danger: core.cfg("irisDanger", "#ff6961")
    readonly property color surface: core.cfg("irisSurface", "#0b0b0c")
    readonly property string fontMain: core.cfg("irisFontMain", "Inter")
    readonly property string fontClock: core.cfg("irisFontClock", "Rubik")
    readonly property real typeScale: Math.max(0.8, Math.min(1.5, core.num("irisTypeScale", 100) / 100))
    readonly property string picture: String(core.cfg("irisSceneSource", "desktop")) === "colour" ? ""
        : core.cfg("irisPicture", config.background || "")
    // A light picture gets an even veil so white type keeps its contrast (the sync measures it).
    readonly property real lift: Math.max(0, Math.min(0.5, core.num("irisLift", 0)))
    readonly property bool showAvatar: core.flag("irisAvatar", true)
    readonly property bool showName: core.flag("irisName", true)
    readonly property bool showHint: core.flag("irisHint", true)

    // ── Time ──
    property date now: new Date()
    readonly property string wantedClock: String(core.cfg("irisClockFormat", "auto"))
    readonly property bool twelve: core.wantedClock === "12h"
        || (core.wantedClock === "auto" && /a/i.test(Qt.locale().timeFormat(Locale.ShortFormat)))
    readonly property string hours: Qt.formatDateTime(core.now, core.twelve ? "h" : "HH")
    readonly property string minutes: Qt.formatDateTime(core.now, "mm")
    readonly property string meridiem: core.twelve ? Qt.formatDateTime(core.now, "AP") : ""
    function sentence(s) { return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : s }
    readonly property string date: {
        const style = String(core.cfg("irisDateFormat", "long"))
        if (style === "weekday") return core.sentence(Qt.locale().toString(core.now, "dddd"))
        if (style === "short") return core.sentence(Qt.locale().toString(core.now, "ddd d MMM"))
        if (style === "numeric") return Qt.locale().toString(core.now, Locale.ShortFormat)
        return core.sentence(Qt.locale().toString(core.now, "dddd, d MMMM"))
    }
    readonly property string weekday: core.sentence(Qt.locale().toString(core.now, "dddd"))
    readonly property string dayMonth: Qt.locale().toString(core.now, "d MMMM")
    // Ticks on the minute, not every second: nothing on this screen shows seconds.
    property Timer ticker: Timer {
        interval: Math.max(1000, (60 - core.now.getSeconds()) * 1000)
        running: true; repeat: true
        onTriggered: core.now = new Date()
    }

    // ── Accounts and sessions ──
    // Qt.DisplayRole is undefined in sddm-greeter; these are SDDM's own roles.
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
    readonly property bool manyUsers: userModel.count > 1
    readonly property bool manySessions: sessionModel.count > 1
    readonly property bool manyLayouts: keyboard.layouts.length > 1
    readonly property string userLogin: core.modelText(userModel, core.userIndex, core.nameRole) || userModel.lastUser || ""
    readonly property string userName: core.modelText(userModel, core.userIndex, core.realNameRole) || core.userLogin
    readonly property string userIcon: core.modelText(userModel, core.userIndex, core.iconRole)
    readonly property string sessionName: core.modelText(sessionModel, core.sessionIndex, core.sessionNameRole) || "Desktop"
    readonly property string layoutName: keyboard.layouts[keyboard.currentLayout]
        ? String(keyboard.layouts[keyboard.currentLayout].shortName).toUpperCase() : ""
    function nextUser() {
        core.userIndex = (core.userIndex + 1) % userModel.count
        core.failed = false
        core.notice = ""
        if (core.field) { core.field.text = ""; core.field.forceActiveFocus() }
    }
    function nextSession() { core.sessionIndex = (core.sessionIndex + 1) % sessionModel.count }
    function nextLayout() { keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length }

    // ── Signing in ──
    property TextConstants text: TextConstants {}
    property Item field: null
    property bool signingIn: false
    property bool failed: false
    property bool succeeded: false
    // What PAM says besides yes or no ("password expired", a second factor's prompt).
    property string notice: ""
    signal rejected()
    signal granted()
    function signIn() {
        if (core.signingIn || !core.field) return
        core.signingIn = true
        core.failed = false
        sddm.login(core.userLogin, core.field.text, core.sessionIndex)
    }
    function typed() {
        if (core.field && core.field.text.length > 0) { core.failed = false; core.notice = "" }
    }
    property Connections link: Connections {
        target: sddm
        function onLoginSucceeded() { core.signingIn = true; core.succeeded = true; core.granted() }
        function onLoginFailed() {
            core.signingIn = false
            core.failed = true
            if (core.field) { core.field.text = ""; core.field.forceActiveFocus() }
            core.rejected()
        }
        function onInformationMessage(message) { core.notice = String(message || "") }
    }
    readonly property string hint: core.signingIn ? ""
        : core.notice.length > 0 ? core.notice
        : core.failed ? core.text.loginFailed
        : keyboard.capsLock ? core.text.capslockWarning : ""
    readonly property bool hintIsWarning: !core.signingIn && (core.failed || core.notice.length > 0)

    // ── Fonts: one static file per weight (a variable font ignores font.weight); the installer copies them ──
    property FontLoader symbols: FontLoader { source: "fonts/MaterialSymbolsRounded.ttf" }
    readonly property string symbolFont: core.symbols.status === FontLoader.Ready ? core.symbols.name : ""
    property list<QtObject> faces: [
        FontLoader { source: "fonts/Rubik-Light.ttf" },
        FontLoader { source: "fonts/Rubik-Regular.ttf" },
        FontLoader { source: "fonts/Rubik-Medium.ttf" },
        FontLoader { source: "fonts/Rubik-SemiBold.ttf" },
        FontLoader { source: "fonts/Rubik-Bold.ttf" },
        FontLoader { source: "fonts/Rubik-ExtraBold.ttf" },
        FontLoader { source: "fonts/Rubik-Black.ttf" },
        FontLoader { source: "fonts/Inter-Regular.ttf" },
        FontLoader { source: "fonts/Inter-Medium.ttf" },
        FontLoader { source: "fonts/Inter-SemiBold.ttf" },
        FontLoader { source: "fonts/Inter-Bold.ttf" }
    ]
}
