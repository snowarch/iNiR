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
    // Every face builds every kind's body; the live readings below feed only the kind that shows. A hidden body
    // that follows a reading still redraws the whole chassis on each change.
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
    // In a bar's lane a face with a figure reads on one line, glyph then figure, and sizes from both.
    property bool lane: false
    // A bar cell is its touch target; what it draws keeps the size of the bar's other marks.
    property real contentInset: 0
    readonly property bool inline: root.lane && ["notifications", "weather", "calendar", "updates"].includes(root.kind)
    readonly property real laneWidth: root.inline ? Math.max(root.height, inlineFace.implicitWidth + 2 * Math.round(8 * root.d)) : root.height
    // What this piece opened (its card, its page, the Control Center) is showing: the plate stays lit, as a menu bar item does.
    property bool open: false
    property color tint: root.ink
    property bool coverHidden: false
    readonly property alias artwork: cover

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
        property real stroke: Math.max(2, 2.5 * root.d)
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: IrisStyle.tintFill(ring.tint)
            strokeWidth: ring.stroke
            fillColor: "transparent"
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.width / 2 - ring.stroke / 2; radiusY: ring.width / 2 - ring.stroke / 2
                startAngle: 0; sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: ring.tint
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

    Rectangle {
        visible: root.plated || root.bodyless
        anchors.fill: parent
        radius: root.inline ? height / 2 : IrisStyle.pieceRadius(width)
        color: root.pressed || root.open ? IrisStyle.fillActiveOf(root.ink)
            : root.hovered ? IrisStyle.fillHoverOf(root.ink)
            : ColorUtils.applyAlpha(root.ink, 0)
        Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
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

        IrisArtwork {
            id: cover
            visible: root.kind === "media"
            opacity: root.coverHidden ? 0 : 1
            anchors.centerIn: parent
            width: parent.width - 12 * root.d - 2 * root.platedInset
            height: width
            source: MediaArtwork.displaySource
            circular: true
        }
        Rectangle {
            visible: root.kind === "media" && opacity > 0
            anchors.fill: cover
            radius: width / 2
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
            visible: root.kind === "media" || (root.kind === "timer" && root.timerKind !== "stopwatch")
            anchors.fill: parent
            anchors.margins: 2 * root.d + root.platedInset
            opacity: root.coverHidden ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
            tint: root.kind === "media" ? root.tint : root.highlight
            progress: root.kind === "media" ? root.mediaProgress : root.timerProgress
        }
        Glyph {
            visible: root.kind === "timer"
            anchors.centerIn: parent
            text: root.timerPaused ? "pause" : root.timerGlyph
            iconSize: 16 * root.d
            color: root.highlight
        }
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
        IrisPulse {
            visible: root.kind === "record"
            anchors.centerIn: parent
            width: 12 * root.d
            height: width
            color: root.dangerInk
        }
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
        SmartAppIcon {
            visible: root.kind === "app"
            anchors.centerIn: parent
            icon: IrisPieces.appIcon(root.appId)
            fallback: "application-x-executable"
            iconSize: Math.round(parent.width - (12 + 4 * root.absorb) * root.d)
        }
        Glyph {
            visible: root.kind === "controls"
            anchors.centerIn: parent
            text: IrisPieces.glyphOf("controls", "")
            fill: 0
            iconSize: 19 * root.d
        }
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
            font.pixelSize: 16 * IrisStyle.typeScale
            font.weight: IrisStyle.weight(Font.Bold)
            color: root.faceAccent
        }
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
                iconSize: (weatherFace.ready ? 13 : 19) * root.d
            }
            FaceText {
                visible: weatherFace.ready
                anchors.horizontalCenter: parent.horizontalCenter
                text: weatherFace.degrees
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
                font.pixelSize: IrisStyle.typeMeta
                font.weight: IrisStyle.weight(Font.Bold)
            }
        }
        Column {
            id: calendarFace
            visible: root.kind === "calendar" && !root.inline
            anchors.centerIn: parent
            spacing: -Math.round(3 * root.d)
            FaceText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Translation.locale.toString(DateTime.clock.date, "ddd")
                color: IrisStyle.identity.red
                font.pixelSize: 8.5 * IrisStyle.typeScale
                font.weight: IrisStyle.weight(Font.Bold)
            }
            FaceText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: DateTime.clock.date.getDate()
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
                font.pixelSize: 16 * IrisStyle.typeScale
                font.weight: IrisStyle.weight(Font.Bold)
            }
        }
        Item {
            id: clockFace
            visible: root.kind === "clock"
            anchors.fill: parent
            anchors.margins: 3 * root.d + root.platedInset
            readonly property var now: root.kind === "clock" ? DateTime.clock.date : new Date(0)
            readonly property real minutes: clockFace.now.getMinutes() + clockFace.now.getSeconds() / 60
            readonly property real hours: (clockFace.now.getHours() % 12) + clockFace.minutes / 60
            Repeater {
                model: 12
                Rectangle {
                    required property int index
                    readonly property bool major: index % 3 === 0
                    visible: major || clockFace.width >= 30 * root.d
                    x: clockFace.width / 2 - width / 2
                    y: 0
                    width: Math.max(1, (major ? 1.6 : 1) * root.d)
                    height: (major ? 3 : 2) * root.d
                    radius: width / 2
                    color: major ? root.ink : root.inkFaint
                    transform: Rotation { origin.x: width / 2; origin.y: clockFace.height / 2; angle: index * 30 }
                }
            }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: root.ink
                    strokeWidth: Math.max(2, 2.2 * root.d)
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    startX: clockFace.width / 2; startY: clockFace.height / 2
                    PathLine {
                        x: clockFace.width / 2 + Math.sin(clockFace.hours * Math.PI / 6) * Math.min(clockFace.width, clockFace.height) * 0.27
                        y: clockFace.height / 2 - Math.cos(clockFace.hours * Math.PI / 6) * Math.min(clockFace.width, clockFace.height) * 0.27
                    }
                }
                ShapePath {
                    strokeColor: root.ink
                    strokeWidth: Math.max(1.5, 1.6 * root.d)
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    startX: clockFace.width / 2; startY: clockFace.height / 2
                    PathLine {
                        x: clockFace.width / 2 + Math.sin(clockFace.minutes * Math.PI / 30) * Math.min(clockFace.width, clockFace.height) * 0.4
                        y: clockFace.height / 2 - Math.cos(clockFace.minutes * Math.PI / 30) * Math.min(clockFace.width, clockFace.height) * 0.4
                    }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 3.5 * root.d
                height: width
                radius: width / 2
                color: root.legible(IrisStyle.identity.orange, 3)
            }
        }
        Ring {
            id: batteryRing
            visible: root.kind === "battery"
            anchors.fill: parent
            anchors.margins: 3 * root.d + root.platedInset
            readonly property real level: root.kind === "battery" ? Math.max(0, Math.min(1, Battery.percentage)) : 0
            tint: Battery.isCharging ? root.legible(IrisStyle.identity.green, 3)
                : Battery.isCritical ? root.dangerInk
                : Battery.isLow ? root.highlight : root.ink
            progress: batteryRing.level
            Behavior on progress { enabled: batteryRing.visible; NumberAnimation { duration: IrisStyle.duration(220); easing.type: IrisStyle.feedbackEasing } }
        }
        Column {
            visible: root.kind === "battery"
            anchors.centerIn: parent
            spacing: -Math.round(3 * root.d)
            Glyph {
                visible: Battery.isCharging
                anchors.horizontalCenter: parent.horizontalCenter
                text: "bolt"
                fill: 1
                iconSize: 11 * root.d
                color: root.legible(IrisStyle.identity.green, 3)
            }
            FaceText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(batteryRing.level * 100)
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
                font.pixelSize: (Battery.isCharging ? 10.5 : 12.5) * IrisStyle.typeScale
                font.weight: IrisStyle.weight(Font.Bold)
                color: batteryRing.tint
            }
        }
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
        Item {
            id: networkFace
            visible: root.kind === "network"
            anchors.fill: parent
            readonly property bool wired: Network.ethernet
            readonly property bool linked: networkFace.wired || (Network.wifiEnabled && Network.networkName.length > 0)
            Glyph {
                anchors.centerIn: parent
                text: networkFace.wired ? "lan" : !Network.wifiEnabled ? "wifi_off" : Network.materialSymbol
                iconSize: 18 * root.d
                color: networkFace.linked ? root.ink : root.inkMuted
            }
        }
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
                    iconSize: (BluetoothStatus.activeDeviceCount > 0 ? 13 : 18) * root.d
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
                    font.pixelSize: IrisStyle.typeMeta
                    font.weight: IrisStyle.weight(Font.Bold)
                }
            }
        }
        Ring {
            id: vitalsRing
            visible: root.kind === "vitals"
            anchors.fill: parent
            anchors.margins: 3 * root.d + root.platedInset
            readonly property real load: root.kind === "vitals" ? Math.max(0, Math.min(1, ResourceUsage.cpuUsage)) : 0
            tint: vitalsRing.load > 0.85 ? root.dangerInk
                : vitalsRing.load > 0.6 ? root.highlight : root.legible(IrisStyle.identity.teal, 3)
            progress: vitalsRing.load
            Behavior on progress { enabled: vitalsRing.visible; NumberAnimation { duration: IrisStyle.duration(220); easing.type: IrisStyle.feedbackEasing } }
        }
        FaceText {
            visible: root.kind === "vitals"
            anchors.centerIn: parent
            text: Math.round(vitalsRing.load * 100)
            color: vitalsRing.tint
            font.family: IrisStyle.fontNumbers
            font.features: ({ "tnum": 1 })
            font.pixelSize: IrisStyle.typeLabel
            font.weight: IrisStyle.weight(Font.Bold)
        }
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
                font.pixelSize: IrisStyle.typeBody
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
                        radius: width / 2
                        color: entry?.is_active ? root.faceAccent : root.inkFaint
                    }
                }
            }
        }
        Column {
            id: updatesFace
            visible: root.kind === "updates" && !root.inline
            anchors.centerIn: parent
            spacing: Math.round(1.5 * root.d)
            readonly property int count: Updates.count
            Glyph {
                visible: updatesFace.count <= 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: IrisPieces.glyphOf("updates", "")
                iconSize: 18 * root.d
                color: root.identityInk(IrisStyle.identity.green)
            }
            FaceText {
                visible: updatesFace.count > 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: updatesFace.count > 99 ? "99+" : updatesFace.count
                color: root.highlight
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
                font.pixelSize: IrisStyle.typeHeadline
                font.weight: IrisStyle.weight(Font.Bold)
            }
            Rectangle {
                visible: updatesFace.count > 0
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(3, 3.5 * root.d)
                height: width
                radius: width / 2
                color: root.highlight
            }
        }
        Loader {
            anchors.fill: parent
            active: root.kind === "visualizer"
            sourceComponent: Item {
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
        Loader {
            anchors.fill: parent
            active: root.kind === "vpn"
            sourceComponent: Item {
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
        Item {
            id: shellUpdateFace
            visible: root.kind === "shellUpdate"
            anchors.fill: parent
            IrisMark {
                id: updateMark
                anchors.centerIn: parent
                implicitSize: Math.round(parent.width - (10 + 4 * root.absorb) * root.d)
                color: root.highlight
                orbiting: shellUpdateFace.visible
                SequentialAnimation on anchors.verticalCenterOffset {
                    running: shellUpdateFace.visible && IrisStyle.motionEnabled
                    loops: Animation.Infinite
                    NumberAnimation { to: -root.d; duration: 1900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: root.d; duration: 1900; easing.type: Easing.InOutSine }
                    onRunningChanged: if (!running) updateMark.anchors.verticalCenterOffset = 0
                }
            }
        }
        Loader {
            anchors.fill: parent
            active: root.kind === "anime"
            sourceComponent: Item {
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
        Loader {
            anchors.fill: parent
            active: root.kind === "watching"
            sourceComponent: Item {
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
                    font.pixelSize: 8 * IrisStyle.typeScale
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
                iconSize: (notificationFace.count > 0 ? 13 : 18) * root.d
            }
            FaceText {
                visible: notificationFace.count > 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: notificationFace.count > 99 ? "99+" : notificationFace.count
                color: root.alertInk
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
                font.pixelSize: IrisStyle.typeMeta
                font.weight: IrisStyle.weight(Font.Bold)
            }
        }
        Row {
            id: inlineFace
            visible: root.inline
            anchors.centerIn: parent
            spacing: Math.round(6 * root.d)
            readonly property int count: root.kind === "notifications" ? notificationFace.count
                : root.kind === "updates" ? updatesFace.count : 0
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
                readonly property string figure: root.kind === "weather" ? weatherFace.degrees
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
