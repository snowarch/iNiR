pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.SystemTray
import qs.services
import qs.services.deferred
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.pieces

Item {
    id: root

    property string kind: ""
    property string appId: ""
    property var trayItem: null
    property string screenName: ""
    readonly property real d: IrisStyle.density

    readonly property var player: MprisController.activePlayer
    property bool playing: root.player?.isPlaying ?? false
    // The live readings below feed only the kind that shows.
    property real mediaProgress: root.kind === "media" && MprisController.lengthOf(root.player) > 0
        ? Math.max(0, Math.min(1, MprisController.positionOf(root.player) / MprisController.lengthOf(root.player))) : 0
    // Bare on the wallpaper (a clear menu bar), `backdrop` is Lume's reading under the face: the ink flips with
    // `lightBackdrop`, identity turns to ink as a template glyph does, and state colours keep their hue at a legible depth.
    property bool lightBackdrop: false
    property var backdrop: null
    readonly property bool bare: root.backdrop !== null
    readonly property color ink: root.lightBackdrop ? IrisStyle.inkOnLight : IrisStyle.text
    readonly property color inkMuted: root.lightBackdrop ? IrisStyle.inkOnLightMuted : IrisStyle.muted
    readonly property color inkFaint: root.lightBackdrop ? IrisStyle.inkOnLightFaint : IrisStyle.textTertiary
    readonly property color inkSoft: root.lightBackdrop ? IrisStyle.inkOnLightSoft : IrisStyle.subtext
    function legible(seed: color, contrast: real): color {
        return root.bare ? IrisStyle.markOn(seed, root.backdrop, root.lightBackdrop, contrast) : seed
    }
    function identityInk(seed: color): color { return root.bare ? root.ink : seed }
    readonly property color faceAccent: root.legible(IrisStyle.accent, 3)
    readonly property color highlight: root.legible(IrisStyle.secondaryAccent, 3)
    readonly property color alertInk: root.legible(IrisStyle.badgeInk, 4.5)
    readonly property color dangerInk: root.legible(IrisStyle.danger, 3)
    readonly property bool radialVisualizer: IrisStyle.visualizerStyle === "ring"
    // A Design whose rings run on the edge (AIRISU) traces a level along the cut outline of the piece, from its upper
    // left corner clockwise, instead of a circle; its covers stay square.
    readonly property bool edgeRings: IrisDesign.trait("rings") === "edge"
    // In a bar's lane a face with a figure reads on one line, glyph then figure, and sizes from both.
    property bool lane: false
    // A bar cell is its touch target; what it draws keeps the size of the bar's other marks.
    property real contentInset: 0
    readonly property bool inline: root.lane && ["notifications", "weather", "calendar", "updates"].includes(root.kind)
    readonly property real laneWidth: root.inline ? Math.max(root.height, (faceLoader.item?.implicitWidth ?? 0) + 2 * Math.round(8 * root.d)) : root.height
    // What this piece opened (its card, its page, the Control Center) is showing: the plate stays lit, as a menu bar item does.
    property bool open: false
    property color tint: root.ink
    property bool coverHidden: false
    // The cover a media face draws, for the surfaces that carry it; null on every other kind.
    readonly property Item artwork: root.kind === "media" ? (faceLoader.item?.cover ?? null) : null

    readonly property string timerKind: TimerService.pomodoroRunning ? "pomodoro"
        : TimerService.countdownRunning ? "countdown"
        : TimerService.stopwatchRunning ? "stopwatch" : ""
    readonly property bool timerPaused: root.timerKind === "pomodoro" ? TimerService.pomodoroPaused
        : root.timerKind === "countdown" ? TimerService.countdownPaused : TimerService.stopwatchPaused
    readonly property real timerProgress: root.kind !== "timer" ? 0 : root.timerKind === "pomodoro"
        ? 1 - TimerService.pomodoroSecondsLeft / Math.max(1, TimerService.pomodoroLapDuration)
        : root.timerKind === "countdown"
            ? 1 - TimerService.countdownSecondsLeft / Math.max(1, TimerService.countdownDuration) : 0
    readonly property string timerGlyph: root.timerKind === "pomodoro" && TimerService.pomodoroBreak ? "coffee"
        : root.timerKind === "stopwatch" ? "timer" : "hourglass_top"

    readonly property var trayItems: SystemTray.items.values.filter(item => item && item.id
        && (!(Config.options?.iris?.tray?.hidePassive ?? false) || item.status !== Status.Passive))
    property int trayCount: root.trayItems.length
    readonly property bool trayShowsApps: String(Config.options?.iris?.tray?.face ?? "apps") === "apps"
        && root.trayItems.length > 0

    property bool pressed: false
    property bool hovered: false
    readonly property bool scaled: root.hovered || root.pressed
    property bool plated: false
    property bool bodyless: false
    property real absorb: root.plated ? 1 : 0
    // Faces that stack a mark over a figure size both from the cell, so in a small cell (the frame's column) the stack
    // keeps clear of the rounded corners the hover plate draws.
    readonly property bool compactCell: Math.min(root.width, root.height) < 30 * root.d
    readonly property real stackGlyph: (root.compactCell ? 11 : 13) * root.d
    readonly property real figureSize: root.compactCell ? IrisStyle.typeCaption : IrisStyle.typeMeta
    readonly property real platedInset: 3 * root.d * root.absorb

    component Glyph: MaterialSymbol {
        fill: 1
        color: root.ink
    }
    // Native glyphs smear under the hover/press scale; curve-rendered ones rasterize at the scaled size.
    component FaceText: IrisText {
        color: root.ink
        renderType: root.scaled ? Text.CurveRendering : Text.NativeRendering
    }
    component Ring: Shape {
        id: ring
        property real progress: 0
        property color tint: root.ink
        property real stroke: Math.max(2, (root.edgeRings ? 2 : 2.5) * root.d)
        // The cut outline, inset by half the stroke: upper left → right → cut → down → cut → left → up.
        readonly property real cut: Math.min(IrisStyle.chamferCut, ring.width / 4)
        readonly property var outline: {
            const h = ring.stroke / 2, w = ring.width - h, b = ring.height - h, c = ring.cut
            return [Qt.point(h, h), Qt.point(w - c, h), Qt.point(w, h + c), Qt.point(w, b),
                Qt.point(h + c, b), Qt.point(h, b - c), Qt.point(h, h)]
        }
        function traced(progress: real): var {
            const pts = ring.outline
            let total = 0
            for (let i = 1; i < pts.length; i++) total += Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)
            let left = total * Math.max(0, Math.min(1, progress))
            const out = [pts[0]]
            for (let i = 1; i < pts.length && left > 0; i++) {
                const a = pts[i - 1], b = pts[i]
                const len = Math.hypot(b.x - a.x, b.y - a.y)
                if (len <= left) { out.push(b); left -= len; continue }
                out.push(Qt.point(a.x + (b.x - a.x) * left / len, a.y + (b.y - a.y) * left / len))
                left = 0
            }
            return out
        }
        preferredRendererType: Shape.CurveRenderer
        // Traced on the edge, the level alone: a resting outline would frame the bubble as a box.
        ShapePath {
            strokeColor: root.edgeRings && ring.progress > 0 ? ring.tint : "transparent"
            strokeWidth: root.edgeRings ? ring.stroke : 0
            fillColor: "transparent"
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap
            // An empty list reaches PathPolyline as no value at all and warns: a lone point draws nothing.
            PathPolyline { path: root.edgeRings && ring.progress > 0 ? ring.traced(ring.progress) : [Qt.point(0, 0)] }
        }
        ShapePath {
            strokeColor: root.edgeRings ? "transparent" : IrisStyle.trackOf(ring.tint)
            strokeWidth: ring.stroke
            fillColor: "transparent"
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.width / 2 - ring.stroke / 2; radiusY: ring.width / 2 - ring.stroke / 2
                startAngle: 0; sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: root.edgeRings ? "transparent"
                : IrisStyle.arcInk(ring.tint, Math.PI * (ring.width - ring.stroke) * Math.max(0, Math.min(1, ring.progress)), ring.stroke)
            strokeWidth: ring.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.width / 2 - ring.stroke / 2; radiusY: ring.width / 2 - ring.stroke / 2
                startAngle: -90
                sweepAngle: 360 * Math.max(0, Math.min(1, ring.progress))
            }
        }
    }

    // A gauge's dial: an open arc over the figure it reads, track first, the reading on top with round ends.
    component GaugeMark: Shape {
        id: gauge
        property real progress: 0
        property color tint: root.ink
        readonly property real stroke: Math.max(2, Math.round(2.6 * root.d))
        readonly property real radius: (gauge.width - gauge.stroke) / 2
        // 240° open at the bottom: the ends sit at sin(30°) of the radius below the centre.
        implicitWidth: Math.round(20 * root.d)
        implicitHeight: Math.ceil(gauge.radius * 1.5 + gauge.stroke)
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: IrisStyle.trackOf(gauge.tint)
            strokeWidth: gauge.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: gauge.width / 2; centerY: gauge.radius + gauge.stroke / 2
                radiusX: gauge.radius; radiusY: gauge.radius
                startAngle: 150; sweepAngle: 240
            }
        }
        ShapePath {
            strokeColor: IrisStyle.arcInk(gauge.tint, gauge.radius * Math.PI * 4 / 3 * Math.max(0, Math.min(1, gauge.progress)), gauge.stroke)
            strokeWidth: gauge.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: gauge.width / 2; centerY: gauge.radius + gauge.stroke / 2
                radiusX: gauge.radius; radiusY: gauge.radius
                startAngle: 150
                sweepAngle: 240 * Math.max(0, Math.min(1, gauge.progress))
            }
        }
    }

    readonly property color plateColor: root.pressed || root.open ? IrisStyle.fillActiveOf(root.ink)
        : root.hovered ? IrisStyle.fillHoverOf(root.ink)
        : ColorUtils.applyAlpha(root.ink, 0)
    Rectangle {
        visible: (root.plated || root.bodyless) && !IrisStyle.fieldChamfer
        anchors.fill: parent
        radius: root.inline ? height / 2 : IrisStyle.pieceRadius(width)
        color: root.plateColor
        Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
    }
    // In a chamfered Design the plate under the pointer is cut like the piece it lights.
    IrisCutPlate {
        visible: (root.plated || root.bodyless) && IrisStyle.fieldChamfer
        anchors.fill: parent
        color: root.plateColor
    }
    Rectangle {
        anchors.fill: parent
        radius: IrisStyle.pieceRadius(width)
        color: IrisStyle.bodySurface
        opacity: root.bodyless ? 0 : 1 - root.absorb
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
    }

    Item {
        anchors.fill: parent
        anchors.margins: root.contentInset
        scale: root.pressed ? IrisStyle.pressScale(0.88) : root.hovered ? 1.06 : 1
        Behavior on scale { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }

        // One body per face, the one its kind shows: every face built all twenty-odd bodies hidden (757 objects for
        // the handful of faces at rest), and each hidden one still followed its readings.
        Loader {
            id: faceLoader
            anchors.fill: parent
            sourceComponent: root.inline ? inlineBody : ({
                media: mediaBody, timer: timerBody, task: taskBody, record: recordBody, trayApp: trayAppBody,
                app: appBody, controls: controlsBody, tools: toolsBody, tray: trayBody, sound: soundBody, mic: soundBody,
                weather: weatherBody, calendar: calendarBody, clock: clockBody, battery: batteryBody, focus: focusBody,
                network: networkBody, bluetooth: bluetoothBody, vitals: vitalsBody, workspaces: workspacesBody,
                updates: updatesBody, visualizer: visualizerBody, vpn: vpnBody, shellUpdate: shellUpdateBody,
                anime: animeBody, watching: watchingBody, notifications: notificationsBody
            })[root.kind] ?? null
        }
        Component {
            id: mediaBody
            Item {
                property alias cover: cover
                IrisArtwork {
                    id: cover
                    visible: root.kind === "media"
                    opacity: root.coverHidden ? 0 : 1
                    anchors.centerIn: parent
                    width: parent.width - 12 * root.d - 2 * root.platedInset
                    height: width
                    source: MediaArtwork.displaySource
                    circular: !root.edgeRings
                    radius: root.edgeRings ? 0 : width / 2
                }
                Rectangle {
                    visible: root.kind === "media" && opacity > 0
                    anchors.fill: cover
                    radius: root.edgeRings ? 0 : width / 2
                    color: IrisStyle.veilStrong
                    opacity: !root.playing && !root.coverHidden ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                    Glyph {
                        anchors.centerIn: parent
                        text: "pause"
                        iconSize: 15 * root.d
                        color: IrisStyle.onMedia
                    }
                }
                Ring {
                    anchors.fill: parent
                    anchors.margins: 2 * root.d + root.platedInset
                    opacity: root.coverHidden ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                    tint: root.tint
                    progress: root.mediaProgress
                }
            }
        }
        Component {
            id: timerBody
            Item {
                Ring {
                    visible: root.timerKind !== "stopwatch"
                    anchors.fill: parent
                    anchors.margins: 2 * root.d + root.platedInset
                    opacity: root.coverHidden ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                    tint: root.highlight
                    progress: root.timerProgress
                }
                Glyph {
                    visible: root.kind === "timer"
                    anchors.centerIn: parent
                    text: root.timerPaused ? "pause" : root.timerGlyph
                    iconSize: 16 * root.d
                    color: root.highlight
                }
            }
        }
        Component {
            id: taskBody
            Item {
                Ring {
                    readonly property var task: LiveActivities.latest
                    visible: root.kind === "task" && Number(task?.progress ?? -1) >= 0
                    anchors.fill: parent
                    anchors.margins: 2 * root.d + root.platedInset
                    tint: IrisStyle.identityColor(String(task?.tint ?? "lavender"))
                    progress: Math.max(0, Number(task?.progress ?? 0))
                }
                Glyph {
                    readonly property var task: LiveActivities.latest
                    visible: root.kind === "task"
                    anchors.centerIn: parent
                    text: String(task?.glyph ?? "bolt")
                    iconSize: 16 * root.d
                    color: root.legible(IrisStyle.identityColor(String(task?.tint ?? "lavender")), 3)
                }
            }
        }
        Component {
            id: recordBody
            Item {
                IrisPulse {
                    visible: root.kind === "record"
                    anchors.centerIn: parent
                    width: 12 * root.d
                    height: width
                    color: root.dangerInk
                }
            }
        }
        Component {
            id: trayAppBody
            Item {
                IrisTrayIcon {
                    visible: root.kind === "trayApp"
                    anchors.centerIn: parent
                    implicitSize: Math.min(parent.width - 2 * root.platedInset, Math.max(Math.round(16 * root.d), Math.round((parent.width - 2 * root.platedInset) * 0.52)))
                    source: root.trayItem ? TrayService.getSafeIcon(root.trayItem) : ""
                }
                Rectangle {
                    visible: root.kind === "trayApp" && root.trayItem?.status === Status.NeedsAttention
                    readonly property real dot: Math.max(6, Math.round(parent.width * 0.16 / 2) * 2)
                    width: dot
                    height: dot
                    radius: dot / 2
                    x: Math.round(parent.width * 0.72 - dot / 2)
                    y: Math.round(parent.height * 0.18 - dot / 2)
                    color: root.dangerInk
                }
            }
        }
        Component {
            id: appBody
            Item {
                SmartAppIcon {
                    visible: root.kind === "app"
                    anchors.centerIn: parent
                    icon: IrisPieces.appIcon(root.appId)
                    fallback: "application-x-executable"
                    iconSize: Math.round(parent.width - (12 + 4 * root.absorb) * root.d)
                }
            }
        }
        Component {
            id: controlsBody
            Item {
                Glyph {
                    visible: root.kind === "controls"
                    anchors.centerIn: parent
                    text: IrisPieces.glyphOf("controls", "")
                    fill: 0
                    iconSize: 19 * root.d
                }
            }
        }
        Component {
            id: toolsBody
            Item {
                readonly property int toolsMinutesLeft: root.kind !== "tools" ? -1 : root.timerKind === "pomodoro" ? Math.ceil(TimerService.pomodoroSecondsLeft / 60)
                    : root.timerKind === "countdown" ? Math.ceil(TimerService.countdownSecondsLeft / 60) : -1
                Ring {
                    visible: root.kind === "tools" && parent.toolsMinutesLeft >= 0
                    anchors.fill: parent
                    anchors.margins: 3 * root.d + root.platedInset
                    tint: root.highlight
                    progress: root.timerProgress
                }
                Glyph {
                    visible: root.kind === "tools" && parent.toolsMinutesLeft < 0
                    anchors.centerIn: parent
                    text: IrisPieces.glyphOf("tools", "")
                    iconSize: 19 * root.d
                    color: root.highlight
                }
                FaceText {
                    visible: root.kind === "tools" && parent.toolsMinutesLeft >= 0
                    anchors.centerIn: parent
                    text: parent.toolsMinutesLeft
                    font.family: IrisStyle.fontNumbers
                    font.features: ({ "tnum": 1 })
                    font.pixelSize: IrisStyle.typeLabel
                    font.weight: IrisStyle.weight(Font.Bold)
                    color: root.highlight
                }
            }
        }
        Component {
            id: trayBody
            Item {
                Grid {
                    id: trayApps
                    visible: root.kind === "tray" && root.trayShowsApps
                    readonly property int total: root.trayItems.length
                    readonly property bool overflow: trayApps.total > 4
                    readonly property real inner: parent.width - 2 * root.platedInset
                    readonly property real cell: Math.round(trayApps.total <= 1 ? trayApps.inner * 0.52 : trayApps.inner * 0.3)
                    anchors.centerIn: parent
                    columns: trayApps.total <= 2 ? Math.max(1, trayApps.total) : 2
                    spacing: Math.round(trayApps.inner * 0.05)
                    Repeater {
                        model: trayApps.overflow ? root.trayItems.slice(0, 3) : root.trayItems.slice(0, 4)
                        IrisTrayIcon {
                            required property var modelData
                            implicitSize: trayApps.cell
                            source: modelData ? TrayService.getSafeIcon(modelData) : ""
                        }
                    }
                    Item {
                        visible: trayApps.overflow
                        width: trayApps.cell
                        height: trayApps.cell
                        FaceText {
                            anchors.centerIn: parent
                            text: "+" + (trayApps.total - 3)
                            font.family: IrisStyle.fontNumbers
                            font.features: ({ "tnum": 1 })
                            font.pixelSize: Math.max(8, Math.round(trayApps.cell * 0.72))
                            font.weight: IrisStyle.weight(Font.Bold)
                            color: root.faceAccent
                        }
                    }
                }
                FaceText {
                    visible: root.kind === "tray" && !root.trayShowsApps
                    anchors.centerIn: parent
                    text: root.trayCount
                    font.family: IrisStyle.fontNumbers
                    font.features: ({ "tnum": 1 })
                    font.pixelSize: root.compactCell ? IrisStyle.typeBody : 16 * IrisStyle.typeScale
                    font.weight: IrisStyle.weight(Font.Bold)
                    color: root.faceAccent
                }
            }
        }
        Component {
            id: soundBody
            Item {
                Ring {
                    id: soundRing
                    visible: root.kind === "sound" || root.kind === "mic"
                    anchors.fill: parent
                    anchors.margins: 3 * root.d + root.platedInset
                    readonly property bool muted: root.kind === "mic" ? Audio.micMuted : (Audio.sink?.audio?.muted ?? false)
                    tint: muted ? (root.kind === "mic" ? root.dangerInk : root.inkMuted) : root.ink
                    progress: muted || !soundRing.visible ? 0 : Math.min(1, root.kind === "mic" ? (Audio.micVolume ?? 0) : (Audio.value ?? 0))
                    Behavior on progress { enabled: soundRing.visible; NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                }
                Glyph {
                    visible: root.kind === "sound" || root.kind === "mic"
                    anchors.centerIn: parent
                    text: root.kind === "mic" ? (Audio.micMuted ? "mic_off" : "mic")
                        : (Audio.sink?.audio?.muted ?? false) ? "volume_off" : "volume_up"
                    iconSize: 15 * root.d
                    color: root.kind === "mic" && Audio.micMuted ? root.dangerInk : root.ink
                }
            }
        }
        Component {
            id: weatherBody
            Item {
                Column {
                    id: weatherFace
                    readonly property string raw: String(Weather.data?.temp ?? "")
                    readonly property bool ready: !weatherFace.raw.startsWith("--") && weatherFace.raw.length > 0
                    readonly property string degrees: {
                        const value = parseFloat(weatherFace.raw)
                        return isNaN(value) ? "" : Math.round(value) + "°"
                    }
                    visible: root.kind === "weather" && !root.inline
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: weatherFace.ready ? root.d : 0
                    spacing: -Math.round(2 * root.d)
                    Glyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                        iconSize: weatherFace.ready ? root.stackGlyph : 19 * root.d
                    }
                    FaceText {
                        visible: weatherFace.ready
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: weatherFace.degrees
                        font.family: IrisStyle.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: root.figureSize
                        font.weight: IrisStyle.weight(Font.Bold)
                    }
                }
            }
        }
        Component {
            id: calendarBody
            Item {
                Column {
                    id: calendarFace
                    visible: root.kind === "calendar" && !root.inline
                    anchors.centerIn: parent
                    spacing: -Math.round(3 * root.d)
                    FaceText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Translation.locale.toString(DateTime.clock.date, "ddd")
                        color: IrisStyle.identity.red
                        font.pixelSize: (root.compactCell ? 7.5 : 8.5) * IrisStyle.typeScale
                        font.weight: IrisStyle.weight(Font.Bold)
                    }
                    FaceText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: DateTime.clock.date.getDate()
                        font.family: IrisStyle.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: root.compactCell ? IrisStyle.typeBody : 16 * IrisStyle.typeScale
                        font.weight: IrisStyle.weight(Font.Bold)
                    }
                }
            }
        }
        Component {
            id: clockBody
            Item {
                Item {
                    id: clockFace
                    visible: root.kind === "clock"
                    anchors.fill: parent
                    anchors.margins: 3 * root.d + root.platedInset
                    readonly property var now: root.kind === "clock" ? DateTime.clock.date : new Date(0)
                    readonly property real minutes: clockFace.now.getMinutes() + clockFace.now.getSeconds() / 60
                    readonly property real hours: (clockFace.now.getHours() % 12) + clockFace.minutes / 60
                    // The clock as a system symbol draws it at bar size: a bezel, a short and a long hand with round ends, and
                    // the clock's orange at the pivot. Ticks at this size only add noise around the hands.
                    readonly property real dial: Math.min(clockFace.width, clockFace.height)
                    readonly property real bezel: Math.max(1.5, 1.6 * root.d)
                    readonly property real reach: clockFace.dial / 2 - clockFace.bezel
                    readonly property real cx: clockFace.width / 2
                    readonly property real cy: clockFace.height / 2
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: root.ink
                            strokeWidth: clockFace.bezel
                            fillColor: "transparent"
                            PathAngleArc {
                                centerX: clockFace.cx; centerY: clockFace.cy
                                radiusX: clockFace.dial / 2 - clockFace.bezel / 2; radiusY: radiusX
                                startAngle: 0; sweepAngle: 360
                            }
                        }
                        ShapePath {
                            strokeColor: root.ink
                            strokeWidth: Math.max(2, 2 * root.d)
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            startX: clockFace.cx; startY: clockFace.cy
                            PathLine {
                                x: clockFace.cx + Math.sin(clockFace.hours * Math.PI / 6) * clockFace.reach * 0.48
                                y: clockFace.cy - Math.cos(clockFace.hours * Math.PI / 6) * clockFace.reach * 0.48
                            }
                        }
                        ShapePath {
                            strokeColor: root.ink
                            strokeWidth: Math.max(1.5, 1.6 * root.d)
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            startX: clockFace.cx; startY: clockFace.cy
                            PathLine {
                                x: clockFace.cx + Math.sin(clockFace.minutes * Math.PI / 30) * clockFace.reach * 0.74
                                y: clockFace.cy - Math.cos(clockFace.minutes * Math.PI / 30) * clockFace.reach * 0.74
                            }
                        }
                    }
                    Rectangle {
                        x: clockFace.cx - width / 2
                        y: clockFace.cy - height / 2
                        width: Math.max(3, 3 * root.d)
                        height: width
                        radius: IrisStyle.capsule(width)
                        color: root.legible(IrisStyle.identity.orange, 3)
                    }
                }
            }
        }
        Component {
            id: batteryBody
            Item {
                Column {
                    id: batteryFace
                    visible: root.kind === "battery"
                    anchors.centerIn: parent
                    spacing: Math.round(2 * root.d)
                    readonly property real level: root.kind === "battery" ? Math.max(0, Math.min(1, Battery.percentage)) : 0
                    // On power and not charging: full, or held at a charge limit.
                    readonly property bool held: !Battery.onBattery && !Battery.isCharging
                    readonly property color state: Battery.isCharging ? root.legible(IrisStyle.identity.green, 3)
                        : Battery.isCritical ? root.dangerInk
                        : Battery.isLow ? root.legible(IrisStyle.warning, 3) : root.ink
                    IrisBatteryMark {
                        id: batteryMark
                        anchors.horizontalCenter: parent.horizontalCenter
                        // The body sits on the centre line the figure shares; the terminal hangs outside it.
                        anchors.horizontalCenterOffset: Math.round((batteryMark.terminal + batteryMark.line) / 2)
                        markHeight: Math.round((root.compactCell ? 7 : 9) * root.d)
                        level: batteryFace.level
                        tint: batteryFace.state
                        frame: root.inkFaint
                        Behavior on level { enabled: batteryFace.visible; NumberAnimation { duration: IrisStyle.duration(220); easing.type: IrisStyle.feedbackEasing } }
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 0
                        Glyph {
                            visible: Battery.isCharging || batteryFace.held
                            anchors.verticalCenter: parent.verticalCenter
                            text: Battery.isCharging ? "bolt" : "power"
                            iconSize: Math.round((root.compactCell ? 9 : 10) * root.d)
                            color: Battery.isCharging ? batteryFace.state : root.inkMuted
                        }
                        FaceText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(batteryFace.level * 100)
                            font.family: IrisStyle.fontNumbers
                            font.features: ({ "tnum": 1 })
                            font.pixelSize: root.figureSize
                            font.weight: IrisStyle.weight(Font.Bold)
                            color: Battery.isCharging || batteryFace.held ? root.ink : batteryFace.state
                        }
                    }
                }
            }
        }
        Component {
            id: focusBody
            Item {
                Rectangle {
                    visible: root.kind === "focus"
                    anchors.fill: parent
                    anchors.margins: 3 * root.d + root.platedInset
                    radius: Math.min(width / 2, Math.max(0, IrisStyle.pieceRadius(root.width) - anchors.margins))
                    color: Notifications.silent ? IrisStyle.identity.indigo : "transparent"
                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(180); easing.type: IrisStyle.feedbackEasing } }
                    Glyph {
                        anchors.centerIn: parent
                        text: IrisPieces.glyphOf("focus", "")
                        fill: Notifications.silent ? 1 : 0
                        iconSize: 17 * root.d
                        color: Notifications.silent ? IrisStyle.onTint : root.ink
                    }
                }
            }
        }
        Component {
            id: networkBody
            Item {
                Item {
                    id: networkFace
                    visible: root.kind === "network"
                    anchors.fill: parent
                    readonly property bool wired: Network.ethernet
                    readonly property bool linked: networkFace.wired || (Network.wifiEnabled && Network.networkName.length > 0)
                    Glyph {
                        anchors.centerIn: parent
                        text: networkFace.wired ? "settings_ethernet" : !Network.wifiEnabled ? "wifi_off" : Network.materialSymbol
                        iconSize: 18 * root.d
                        color: networkFace.linked ? root.ink : root.inkMuted
                    }
                }
            }
        }
        Component {
            id: bluetoothBody
            Item {
                Item {
                    id: bluetoothFace
                    visible: root.kind === "bluetooth"
                    anchors.fill: parent
                    Column {
                        anchors.centerIn: parent
                        spacing: -Math.round(2 * root.d)
                        Glyph {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: IrisPieces.glyphOf("bluetooth", !BluetoothStatus.enabled ? "bluetooth_disabled"
                                : BluetoothStatus.activeDeviceCount > 0 ? "bluetooth_connected" : "")
                            iconSize: BluetoothStatus.activeDeviceCount > 0 ? root.stackGlyph : 18 * root.d
                            color: !BluetoothStatus.enabled ? root.inkMuted
                                : BluetoothStatus.activeDeviceCount > 0 ? root.faceAccent : root.ink
                        }
                        FaceText {
                            visible: BluetoothStatus.activeDeviceCount > 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: BluetoothStatus.activeDeviceCount
                            color: root.faceAccent
                            font.family: IrisStyle.fontNumbers
                            font.features: ({ "tnum": 1 })
                            font.pixelSize: root.figureSize
                            font.weight: IrisStyle.weight(Font.Bold)
                        }
                    }
                }
            }
        }
        Component {
            id: vitalsBody
            Item {
                Column {
                    id: vitalsFace
                    visible: root.kind === "vitals"
                    anchors.centerIn: parent
                    spacing: 0
                    readonly property real load: root.kind === "vitals" ? Math.max(0, Math.min(1, ResourceUsage.cpuUsage)) : 0
                    readonly property color state: vitalsFace.load > 0.85 ? root.dangerInk
                        : vitalsFace.load > 0.6 ? root.highlight : root.faceAccent
                    GaugeMark {
                        anchors.horizontalCenter: parent.horizontalCenter
                        implicitWidth: Math.round((root.compactCell ? 15 : 18) * root.d)
                        tint: vitalsFace.state
                        progress: vitalsFace.load
                        Behavior on progress { enabled: vitalsFace.visible; NumberAnimation { duration: IrisStyle.duration(220); easing.type: IrisStyle.feedbackEasing } }
                    }
                    FaceText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Math.round(vitalsFace.load * 100)
                        color: vitalsFace.load > 0.6 ? vitalsFace.state : root.ink
                        font.family: IrisStyle.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: root.figureSize
                        font.weight: IrisStyle.weight(Font.Bold)
                    }
                }
            }
        }
        Component {
            id: workspacesBody
            Item {
                Column {
                    id: workspacesFace
                    visible: root.kind === "workspaces"
                    anchors.centerIn: parent
                    spacing: Math.round(2 * root.d)
                    readonly property var list: (NiriService.allWorkspaces ?? []).filter(ws => ws.output === root.screenName)
                    readonly property var active: workspacesFace.list.find(ws => ws.is_active) ?? null
                    FaceText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: workspacesFace.active ? workspacesFace.active.idx : "–"
                        font.family: IrisStyle.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: root.compactCell ? IrisStyle.typeLabel : IrisStyle.typeBody
                        font.weight: IrisStyle.weight(Font.Bold)
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Math.round(2 * root.d)
                        Repeater {
                            model: Math.min(5, workspacesFace.list.length)
                            Rectangle {
                                required property int index
                                readonly property var entry: workspacesFace.list[index]
                                width: Math.max(2, 3 * root.d)
                                height: width
                                radius: IrisStyle.capsule(width)
                                color: entry?.is_active ? root.faceAccent : root.inkFaint
                            }
                        }
                    }
                }
            }
        }
        Component {
            id: updatesBody
            Item {
                Column {
                    id: updatesFace
                    visible: root.kind === "updates" && !root.inline
                    anchors.centerIn: parent
                    spacing: -Math.round(2 * root.d)
                    readonly property int count: Updates.count
                    Glyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: IrisPieces.glyphOf("updates", "")
                        iconSize: updatesFace.count > 0 ? root.stackGlyph : 18 * root.d
                        color: updatesFace.count > 0 ? root.highlight : root.identityInk(IrisStyle.identity.green)
                    }
                    FaceText {
                        visible: updatesFace.count > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: updatesFace.count > 99 ? "99+" : updatesFace.count
                        color: root.highlight
                        font.family: IrisStyle.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: root.figureSize
                        font.weight: IrisStyle.weight(Font.Bold)
                    }
                }
            }
        }
        Component {
            id: shellUpdateBody
            Item {
                Item {
                    id: shellUpdateFace
                    visible: root.kind === "shellUpdate"
                    anchors.fill: parent
                    // An update can wait for days, and drawn in place this orbit held the whole chassis at the display rate
                    // all that time, over a fullscreen game too (the chassis rises to Overlay there and the Island only
                    // fades). It goes through LiveLayer like IrisPulse, and both motions come from the wall clock so the
                    // copy in place and the one in its own surface stay in phase.
                    readonly property bool moving: shellUpdateFace.visible && IrisStyle.motionEnabled
                        && !(root.QsWindow.window?.canvasSuppressed ?? false)
                    LiveLayer {
                        anchors.fill: parent
                        // The orbiting dot reaches past the mark's box and the mark floats ±d.
                        pad: Math.ceil(shellUpdateFace.width * 0.06 + root.d * 2)
                        live: shellUpdateFace.moving
                        content: updateMarkFace
                    }
                    Component {
                        id: updateMarkFace
                        Item {
                            id: markHost
                            property bool drawing: false
                            function place(): void {
                                const t = Date.now()
                                // The ring and the centre dot are round: turning the whole mark turns only its orbit.
                                updateMark.rotation = 360 * (t % 9000) / 9000
                                // Two InOutSine halves between +d and −d over 1.9 s each are exactly this cosine.
                                updateMark.anchors.verticalCenterOffset = root.d * Math.cos(2 * Math.PI * (t % 3800) / 3800)
                            }
                            IrisMark {
                                id: updateMark
                                anchors.centerIn: parent
                                implicitSize: Math.round(shellUpdateFace.width - (10 + 4 * root.absorb) * root.d)
                                color: root.highlight
                            }
                            FrameAnimation {
                                running: markHost.drawing && shellUpdateFace.moving
                                onTriggered: markHost.place()
                                onRunningChanged: if (running) markHost.place()
                                    else { updateMark.rotation = 0; updateMark.anchors.verticalCenterOffset = 0 }
                            }
                        }
                    }
                }
            }
        }
        Component {
            id: notificationsBody
            Item {
                Column {
                    id: notificationFace
                    readonly property int count: Notifications.list?.length ?? 0
                    visible: root.kind === "notifications" && !root.inline
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: notificationFace.count > 0 ? root.d : 0
                    spacing: -Math.round(2 * root.d)
                    Glyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: IrisPieces.glyphOf("notifications", notificationFace.count > 0 ? "notifications_active" : "")
                        iconSize: notificationFace.count > 0 ? root.stackGlyph : 18 * root.d
                    }
                    FaceText {
                        visible: notificationFace.count > 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: notificationFace.count > 99 ? "99+" : notificationFace.count
                        color: root.alertInk
                        font.family: IrisStyle.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: root.figureSize
                        font.weight: IrisStyle.weight(Font.Bold)
                    }
                }
            }
        }
        Component {
            id: visualizerBody
            Item {
                ColorQuantizer {
                    id: vizArt
                    source: IrisStyle.visualizerColour === "art" ? MediaArtwork.displaySource : ""
                    depth: 2
                    rescaleSize: 48
                }
                IrisVisualizer {
                    anchors.centerIn: parent
                    running: root.playing
                    // A ring fills the round face; a row sits in it at the height of the other marks.
                    barHeight: Math.round((root.radialVisualizer ? root.width - (8 + 4 * root.absorb) * root.d : 16 * root.d))
                    tint: root.legible(IrisStyle.visualizerTint(IrisStyle.artTintOf(vizArt.colors)), 3)
                    opacity: root.playing ? 1 : 0.55
                }
            }
        }
        Component {
            id: vpnBody
            Item {
                Component.onCompleted: Vpn.keepAlive()
                Component.onDestruction: Vpn.releaseKeepAlive()
                Glyph {
                    anchors.centerIn: parent
                    text: Vpn.connected ? "vpn_lock" : "vpn_key_off"
                    fill: Vpn.connected ? 1 : 0
                    iconSize: 18 * root.d
                    color: Vpn.connected ? root.legible(IrisStyle.identity.green, 3) : root.inkMuted
                }
            }
        }
        Component {
            id: animeBody
            Item {
                id: animeFace
                anchors.fill: parent
                readonly property var show: IrisPieces.animeNext
                readonly property string cover: String(animeFace.show?.imageSmall ?? animeFace.show?.image ?? "")
                readonly property real approach: animeFace.show ? IrisPieces.animeApproach(animeFace.show.airingAt) : 0
                Component.onCompleted: AnimeService.fetchTopAiring()
                Ring {
                    visible: animeFace.cover.length > 0
                    anchors.fill: parent
                    anchors.margins: 2 * root.d + root.platedInset
                    tint: root.legible(IrisStyle.identity.pink, 3)
                    progress: animeFace.approach
                }
                ClippingRectangle {
                    anchors.centerIn: parent
                    width: Math.round(parent.width - (14 + 4 * root.absorb) * root.d)
                    height: width
                    radius: IrisStyle.iconRadius(width)
                    color: IrisStyle.fillQuiet
                    visible: animeFace.cover.length > 0
                    IrisImage {
                        anchors.fill: parent
                        source: animeFace.cover
                    }
                }
                Glyph {
                    visible: animeFace.cover.length === 0
                    anchors.centerIn: parent
                    text: "live_tv"
                    iconSize: 18 * root.d
                    color: root.inkSoft
                }
            }
        }
        Component {
            id: watchingBody
            Item {
                id: watchingFace
                readonly property var entry: AnimeWatch.current
                readonly property var state: AnimeWatch.stateOf(watchingFace.entry)
                readonly property string episode: AnimeWatch.busy
                    ? AnimeWatch.busyEpisode : watchingFace.state.episode
                readonly property real watched: AnimeWatch.busy ? 0 : watchingFace.state.progress
                Component.onCompleted: AnimeWatch.reload()
                Ring {
                    visible: watchingFace.watched > 0
                    anchors.fill: parent
                    anchors.margins: 2 * root.d + root.platedInset
                    tint: root.legible(IrisStyle.identity.pink, 3)
                    progress: watchingFace.watched
                }
                Ring {
                    id: watchingSpinner
                    visible: AnimeWatch.busy
                    anchors.fill: parent
                    anchors.margins: 2 * root.d + root.platedInset
                    tint: root.legible(IrisStyle.identity.pink, 3)
                    progress: AnimeWatch.phase === "playing" ? 1 : 0.28
                    RotationAnimation on rotation {
                        running: watchingSpinner.visible && (AnimeWatch.phase === "launching" || (AnimeWatch.phase === "searching" && !AnimeWatch.choosing))
                        from: 0; to: 360
                        duration: IrisStyle.duration(1100)
                        loops: Animation.Infinite
                        onStopped: watchingSpinner.rotation = 0
                    }
                }
                FaceText {
                    id: watchingNumber
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: Math.round(1 * root.d)
                    anchors.verticalCenterOffset: Math.round(1 * root.d)
                    visible: watchingFace.episode.length > 0
                    text: watchingFace.episode
                    font.family: IrisStyle.fontNumbers
                    font.features: ({ "tnum": 1 })
                    font.pixelSize: (watchingFace.episode.length > 2 ? 13 : 18) * IrisStyle.typeScale
                    font.weight: IrisStyle.weight(Font.Bold)
                }
                FaceText {
                    x: watchingNumber.x - width * 0.55
                    y: watchingNumber.y - height * 0.2
                    visible: watchingNumber.visible
                    text: Translation.tr("EP")
                    color: root.legible(IrisStyle.identity.pink, 3)
                    style: Text.Outline
                    styleColor: IrisStyle.bodySurface
                    font.pixelSize: IrisStyle.typeCaption
                    font.weight: IrisStyle.weight(Font.Black)
                }
                Glyph {
                    anchors.centerIn: parent
                    visible: watchingFace.episode.length === 0
                    text: IrisPieces.glyphOf("watching", "")
                    iconSize: 18 * root.d
                    color: root.inkSoft
                }
            }
        }
        Component {
            id: inlineBody
            Item {
                id: inlineBodyItem
                implicitWidth: inlineFace.implicitWidth
                readonly property string degrees: {
                    const value = parseFloat(String(Weather.data?.temp ?? ""))
                    return isNaN(value) || String(Weather.data?.temp ?? "").startsWith("--") ? "" : Math.round(value) + "°"
                }
                Row {
                    id: inlineFace
                    visible: root.inline
                    anchors.centerIn: parent
                    spacing: Math.round(6 * root.d)
                    readonly property int count: root.kind === "notifications" ? (Notifications.list?.length ?? 0)
                        : root.kind === "updates" ? Updates.count : 0
                    Glyph {
                        visible: root.kind !== "calendar"
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.kind === "notifications" ? IrisPieces.glyphOf("notifications", inlineFace.count > 0 ? "notifications_active" : "")
                            : root.kind === "weather" ? (Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud")
                            : IrisPieces.glyphOf("updates", "")
                        fill: root.kind === "notifications" && inlineFace.count === 0 ? 0 : 1
                        iconSize: 17 * root.d
                    }
                    FaceText {
                        visible: root.kind === "calendar"
                        anchors.verticalCenter: parent.verticalCenter
                        text: Translation.locale.toString(DateTime.clock.date, "ddd").replace(/\.$/, "")
                        color: root.inkMuted
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.Medium)
                    }
                    FaceText {
                        readonly property string figure: root.kind === "weather" ? inlineBodyItem.degrees
                            : root.kind === "calendar" ? String(DateTime.clock.date.getDate())
                            : inlineFace.count > 99 ? "99+" : inlineFace.count > 0 ? String(inlineFace.count) : ""
                        visible: figure.length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: figure
                        color: root.kind === "notifications" ? root.alertInk : root.kind === "calendar" ? root.highlight : root.ink
                        font.family: IrisStyle.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.Bold)
                    }
                }
            }
        }
    }

    ResourceUsageMonitor { target: root; active: root.kind === "vitals" }

    Accessible.role: Accessible.Button
    Accessible.name: root.kind === "controls" ? Translation.tr("Quick controls")
        : root.kind === "notifications" ? Translation.tr("Notifications")
        : root.kind === "tray" ? Translation.tr("Tray")
        : root.kind === "trayApp" ? String(root.trayItem?.tooltipTitle || root.trayItem?.title || root.trayItem?.id || "")
        : root.kind === "calendar" ? Translation.tr("Calendar")
        : root.kind === "clock" ? Translation.tr("Clock")
        : root.kind === "battery" ? Translation.tr("Battery")
        : root.kind === "focus" ? Translation.tr("Do Not Disturb")
        : root.kind === "tools" ? Translation.tr("Timers")
        : root.kind === "weather" ? Translation.tr("Weather")
        : root.kind === "media" ? Translation.tr("Now playing")
        : root.kind === "visualizer" ? Translation.tr("Visualizer")
        : root.kind === "sound" ? Translation.tr("Sound")
        : root.kind === "mic" ? Translation.tr("Microphone")
        : root.kind === "network" ? Translation.tr("Network")
        : root.kind === "bluetooth" ? Translation.tr("Bluetooth")
        : root.kind === "vitals" ? Translation.tr("Vitals")
        : root.kind === "workspaces" ? Translation.tr("Workspaces")
        : root.kind === "updates" ? Translation.tr("Updates")
        : root.kind === "anime" ? Translation.tr("Airing")
        : root.kind === "watching" ? Translation.tr("Continue")
        : root.kind === "shellUpdate" ? Translation.tr("New iNiR")
        : root.kind === "vpn" ? Translation.tr("VPN")
        : root.kind === "record" ? Translation.tr("Screen recording") : Translation.tr("Timer")
}
