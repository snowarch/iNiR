pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.mediaControls.components
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.frame
import qs.modules.iris.pieces
import qs.modules.iris.bar.island
import qs.modules.iris.control

Item {
    id: root

    property var targetScreen
    property real availableWidth: 800
    property real availableAcross: 800
    property real compactHeight: 42
    // Spotlight opened as the Island is drawn by the same field: the Island hands it its face and folds its satellites.
    // Only Spotlight opened as the Island takes its place; a floating one leaves the Island as it is.
    property real spotlightYield: String(Config.options?.iris?.palette?.opens ?? "floating") === "island"
        && (IrisFrame.placeBodies["spotlight"]?.screen ?? "") === (root.targetScreen?.name ?? "-") ? 1 : 0
    Behavior on spotlightYield { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
    property bool expanded: false
    property bool pinned: false
    property string page: ""

    readonly property real d: IrisStyle.density
    readonly property var options: Config.options?.iris?.bar ?? ({})
    readonly property real clockScale: Math.max(0.8, Math.min(1.5, Number(root.options?.clockScale ?? 100) / 100))
    readonly property real breathing: Math.max(0.5, Math.min(2.5, Number(root.options?.padding ?? 100) / 100))
    readonly property string clockAccentName: String(root.options?.clockAccent ?? "highlight")
    readonly property color clockAccent: root.clockAccentName === "accent" ? IrisStyle.accent
        : root.clockAccentName === "plain" ? IrisStyle.text : IrisStyle.secondaryAccent
    readonly property real satelliteScale: Math.max(0.7, Math.min(1, Number(root.options?.satelliteScale ?? 100) / 100))

    readonly property var desktopBlockKinds: ["profile", "context", "forecast", "agenda", "vitals", "modules"]
    readonly property var desktopBlocks: Array.from(root.options?.desktopBlocks ?? root.desktopBlockKinds)
        .filter(kind => root.desktopBlockKinds.includes(kind))
    function desktopBlockLabel(kind: string): string {
        return ({ profile: Translation.tr("Profile"), context: Translation.tr("Current app"),
            forecast: Translation.tr("Forecast"), agenda: Translation.tr("Up next"),
            vitals: Translation.tr("Vitals"), modules: Translation.tr("Modules") })[kind] ?? kind
    }
    function setDesktopBlock(kind: string, on: bool): void {
        const next = root.desktopBlocks.filter(entry => entry !== kind)
        if (on) next.push(kind)
        Config.setNestedValue("iris.bar.desktopBlocks", next)
    }
    function desktopBlockGlyph(kind: string): string {
        return ({ profile: "account_circle", context: "select_window", forecast: "partly_cloudy_day",
            agenda: "event_upcoming", vitals: "monitor_heart", modules: "widgets" })[kind] ?? "add"
    }
    function moveDesktopBlock(kind: string, step: int): void {
        const next = root.desktopBlocks.slice()
        const from = next.indexOf(kind)
        const to = Math.max(0, Math.min(next.length - 1, from + step))
        if (from < 0 || to === from) return
        next.splice(to, 0, next.splice(from, 1)[0])
        Config.setNestedValue("iris.bar.desktopBlocks", next)
    }
    readonly property real studioHandlesWidth: Math.round(40 * root.d)
    property string arrangeKind: ""
    property real arrangeTravel: 0
    property int arrangeSteps: 0
    property real arrangeSpan: 0
    readonly property bool studio: GlobalStates.irisArrange && root.focusedOutput && root.visualExpanded
        && root.effectivePage === "desktop"
    Connections {
        target: root
        function onVisualExpandedChanged(): void { if (!root.visualExpanded && root.focusedOutput) GlobalStates.irisArrange = false }
    }
    readonly property bool notch: root.options?.notch ?? false
    readonly property alias notchness: notchSpring.value
    IrisSpring { id: notchSpring; surface: "island"; intent: "move"; to: root.notch ? 1 : 0; minimum: 0 }
    property string edge: "top"
    readonly property bool bottomEdge: root.edge === "bottom"
    readonly property bool rightEdge: root.edge === "right"
    readonly property bool vertical: root.edge === "left" || root.rightEdge

    readonly property var player: MprisController.activePlayer
    readonly property bool hasMedia: root.player !== null && root.player !== undefined
        && String(root.player.trackTitle ?? "").length > 0
    readonly property bool ytMusic: root.hasMedia && MprisController._isYtMusicMpv(root.player)
    readonly property string title: root.ytMusic ? YtMusic.currentTitle : String(root.player?.trackTitle ?? "")
    readonly property bool playing: root.hasMedia && (root.ytMusic ? YtMusic.isPlaying : (root.player?.isPlaying ?? false))
    readonly property real effectivePosition: root.ytMusic ? YtMusic.currentPosition : MprisController.positionOf(root.player)
    readonly property real effectiveLength: root.ytMusic ? YtMusic.currentDuration : MprisController.lengthOf(root.player)
    readonly property real trackProgress: root.effectiveLength > 0
        ? Math.max(0, Math.min(1, root.effectivePosition / root.effectiveLength)) : 0

    readonly property bool recording: RecorderStatus.isRecording
    readonly property string timerKind: TimerService.pomodoroRunning ? "pomodoro"
        : TimerService.countdownRunning ? "countdown"
        : TimerService.stopwatchRunning ? "stopwatch" : ""
    readonly property bool timerPaused: root.timerKind === "pomodoro" ? TimerService.pomodoroPaused
        : root.timerKind === "countdown" ? TimerService.countdownPaused
        : TimerService.stopwatchPaused
    readonly property int timerSeconds: root.timerKind === "pomodoro" ? TimerService.pomodoroSecondsLeft
        : root.timerKind === "countdown" ? TimerService.countdownSecondsLeft
        : Math.floor(TimerService.stopwatchTime / 100)
    readonly property real timerProgress: root.timerKind === "pomodoro"
        ? 1 - TimerService.pomodoroSecondsLeft / Math.max(1, TimerService.pomodoroLapDuration)
        : root.timerKind === "countdown"
            ? 1 - TimerService.countdownSecondsLeft / Math.max(1, TimerService.countdownDuration) : 0
    readonly property string timerLabel: root.timerKind === "pomodoro"
        ? (TimerService.pomodoroLongBreak ? Translation.tr("Long break")
            : TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus"))
        : root.timerKind === "countdown" ? Translation.tr("Timer") : Translation.tr("Stopwatch")
    readonly property string timerGlyph: root.timerKind === "pomodoro" && TimerService.pomodoroBreak ? "coffee"
        : root.timerKind === "stopwatch" ? "timer" : "hourglass_top"

    readonly property var task: LiveActivities.latest
    readonly property color taskTint: IrisStyle.identityColor(String(root.task?.tint ?? "lavender"))
    readonly property var activities: {
        const list = []
        if (root.recording) list.push("record")
        if (root.timerKind.length > 0) list.push("timer")
        if (root.task) list.push("task")
        if (root.hasMedia) list.push("media")
        return list
    }
    readonly property string primary: root.activities[0] ?? "idle"
    readonly property string secondary: root.activities[1] ?? ""
    readonly property bool hasSystemActivity: root.recording || root.timerKind.length > 0 || root.task !== null

    function pageFor(kind: string): string {
        return kind === "media" ? "media" : kind === "idle" || kind === "" ? "desktop" : "activity"
    }
    readonly property string effectivePage: {
        const requested = root.page.length > 0 ? root.page : root.pageFor(root.primary)
        if (requested === "media" && !root.hasMedia) return root.pageFor(root.primary)
        if (requested === "activity" && !root.hasSystemActivity) return root.pageFor(root.primary)
        return requested
    }

    readonly property var navKinds: ["media", "activity", "desktop", "tray", "tools", "focus", "today", "controls", "settings"]
    readonly property var navItems: {
        const chosen = Array.from(IrisStyle.structuralValue("bar.navItems", root.navKinds))
            .filter(kind => root.navKinds.includes(kind))
        return chosen.length > 0 ? chosen : root.navKinds
    }
    function navAvailable(kind: string): bool {
        if (kind === "media") return root.hasMedia
        if (kind === "activity") return root.hasSystemActivity
        if (kind === "focus") return Config.options?.iris?.sidebars?.left?.enable ?? true
        if (kind === "today") return Config.options?.iris?.sidebars?.right?.enable ?? true
        return true
    }
    function navPageOf(kind: string): string {
        if (kind === "controls") return root.controlsInIsland ? "controls" : ""
        return ["media", "activity", "desktop", "tray", "tools"].includes(kind) ? kind : ""
    }
    readonly property var navEntries: {
        const glyphs = { media: "music_note", activity: root.recording ? "radio_button_checked"
                : root.timerKind.length > 0 ? root.timerGlyph : String(root.task?.glyph ?? "bolt"),
            desktop: "space_dashboard", tray: "apps", tools: "timer", focus: "left_panel_open",
            today: "right_panel_open", controls: "tune", settings: "settings" }
        const labels = { media: "Now playing", activity: "Live activities", desktop: "Desktop", tray: "Tray",
            tools: "Timers", focus: "Focus panel", today: "Today panel", controls: "Quick controls", settings: "Settings" }
        const visible = root.navItems.filter(kind => root.navAvailable(kind))
        const out = []
        let pages = true
        for (const kind of visible) {
            const page = root.navPageOf(kind)
            if (pages && page.length === 0 && out.length > 0) out.push({ kind: "|" })
            if (page.length === 0) pages = false
            out.push({ kind: kind, page: page, glyph: glyphs[kind], label: labels[kind] })
        }
        return out
    }
    readonly property var pageCycle: root.navEntries.filter(entry => (entry.page ?? "").length > 0).map(entry => entry.page)
    function activateNav(kind: string): void {
        const page = root.navPageOf(kind)
        if (kind === "controls") {
            if (!root.controlsInIsland) root.openControlCenterFrom(chassis)
            else if (root.focusedOutput) GlobalStates.controlPanelOpen = true
            return
        }
        if (page.length > 0) { root.page = page; root.pinned = true; return }
        if (kind === "focus") { root.expanded = false; GlobalStates.openSidebarLeft(root.targetScreen?.name ?? "") }
        else if (kind === "today") { root.expanded = false; GlobalStates.openSidebarRight(root.targetScreen?.name ?? "") }
        else if (kind === "settings") root.openSettingsFrom(chassis)
    }
    function stepPage(steps: int): bool {
        const cycle = root.pageCycle
        if (cycle.length === 0 || steps === 0) return false
        const at = Math.max(0, cycle.indexOf(root.effectivePage))
        const next = cycle[Math.max(0, Math.min(cycle.length - 1, at + steps))]
        if (!root.expanded) { root.openPage(next, true, null); return true }
        if (next === root.effectivePage) return false
        if (next === "controls" && root.focusedOutput) GlobalStates.controlPanelOpen = true
        else root.page = next
        root.pinned = true
        return true
    }
    property real pageWheel: 0
    function wheelPages(event, vertical: bool): void {
        const dx = event.angleDelta.x !== 0 ? event.angleDelta.x : event.pixelDelta.x * 4
        const dy = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y * 4
        const across = Math.abs(dx) > Math.abs(dy)
        if (!across && !vertical) return
        event.accepted = true
        root.pageWheel += across ? -dx : -dy
        const steps = Math.trunc(root.pageWheel / 120)
        if (steps === 0) return
        root.pageWheel -= steps * 120
        root.stepPage(steps)
    }

    function openPage(nextPage: string, pin: bool, origin): void {
        root.page = nextPage
        root.pageOrigin = origin ?? null
        if (origin) { root.pageOriginX = -1; root.pageOriginY = -1 }
        if (pin) root.pinned = true
        root.expanded = true
    }
    property real pageOriginX: -1
    property real pageOriginY: -1

    property real screenOffsetY: 0
    function chassisBody(): var {
        const p = chassis.mapToItem(null, chassis.leftInset, chassis.topInset)
        return { x: p.x, y: p.y, width: root.vertical ? chassis.across : chassis.width,
            height: root.vertical ? chassis.height : chassis.bodyHeight }
    }
    function partRect(part): var {
        if (part === chassis) return root.chassisBody()
        const p = part.mapToItem(null, 0, 0)
        return { x: p.x, y: p.y, width: part.width * part.scale, height: part.height * part.scale }
    }
    function publishOrigin(part): void {
        if (root.targetScreen?.name !== GlobalStates.focusedScreen?.name) return
        if (root.suppressed || !part?.visible) { GlobalStates.irisMorphOrigin = null; return }
        const isChassis = part === chassis
        const r = root.partRect(part)
        GlobalStates.irisMorphOrigin = {
            x: r.x, y: r.y + root.screenOffsetY,
            width: r.width, height: r.height,
            radius: isChassis ? chassis.radius : IrisStyle.pieceRadius(Math.min(r.width, r.height)),
            screen: root.targetScreen?.name ?? ""
        }
    }

    // A Place that the Island collapses for (the gallery, Spotlight, Settings) grows out of where the Island
    // comes to rest, not out of the page it is leaving: the page is gone by the time the Place starts.
    function publishRestOrigin(): void {
        if (root.targetScreen?.name !== GlobalStates.focusedScreen?.name) return
        const rest = GlobalStates.irisIslandGeometry?.[root.targetScreen?.name ?? ""] ?? null
        if (!root.expanded || !rest || !(rest.width > 0) || root.suppressed) { root.publishOrigin(chassis); return }
        GlobalStates.irisMorphOrigin = { x: rest.x, y: rest.y, width: rest.width, height: rest.height,
            radius: Math.min(rest.width, rest.height) / 2, screen: root.targetScreen?.name ?? "" }
    }
    property Item controlMorphPart: null
    property Item settingsMorphPart: null
    property bool controlOriginPrepared: false
    property bool settingsOriginPrepared: false
    property bool settingsIntent: false
    property string pageIntent: ""

    readonly property bool controlsInIsland: String(Config.options?.iris?.controlCenter?.opens ?? "island") === "island"
    function openControlCenterFrom(part): void {
        if (root.controlsInIsland) {
            root.openPage("controls", true, part ?? null)
            if (root.focusedOutput) GlobalStates.controlPanelOpen = true
            return
        }
        root.controlMorphPart = part ?? chassis
        root.publishOrigin(root.controlMorphPart)
        root.controlOriginPrepared = true
        root.expanded = false
        GlobalStates.controlPanelOpen = true
    }

    function openSettingsFrom(part): void {
        root.settingsMorphPart = part ?? chassis
        root.publishOrigin(root.settingsMorphPart)
        root.settingsOriginPrepared = true
        root.expanded = false
        GlobalStates.openSettings()
    }

    function chooseAvatar(): void {
        root.expanded = false
        avatarDialog.open()
    }
    FileDialog {
        id: avatarDialog
        title: Translation.tr("Profile picture")
        fileMode: FileDialog.OpenFile
        nameFilters: [Translation.tr("Images") + " (*.png *.jpg *.jpeg *.webp *.bmp *.avif)"]
        onAccepted: {
            setAvatar.command = [Quickshell.shellPath("scripts/accounts/set-avatar.sh"), FileUtils.trimFileProtocol(String(selectedFile))]
            setAvatar.running = true
        }
    }
    Process {
        id: setAvatar
        onExited: exitCode => { if (exitCode === 0) Directories.userAvatarRevision++ }
    }

    function clockText(total: real): string {
        const s = Math.max(0, Math.floor(total))
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        const sec = s % 60
        const pad = n => n < 10 ? "0" + n : String(n)
        return h > 0 ? h + ":" + pad(m) + ":" + pad(sec) : m + ":" + pad(sec)
    }

    property string feedbackKind: "volume"
    property bool wheelHold: false
    readonly property bool feedback: (feedbackTimer.running || root.wheelHold) && !root.expanded && !root.fullscreenCovered
    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(root.targetScreen)
    readonly property real feedbackValue: root.feedbackKind === "brightness"
        ? (root.brightnessMonitor?.brightness ?? 0)
        : root.feedbackKind === "mic" ? (Audio.micVolume ?? 0) : (Audio.value ?? 0)
    readonly property bool feedbackMuted: root.feedbackKind === "mic" ? Audio.micMuted
        : root.feedbackKind === "volume" ? (Audio.sink?.audio?.muted ?? false) : false
    readonly property string feedbackIcon: root.feedbackKind === "brightness" ? "light_mode"
        : root.feedbackKind === "mic" ? (Audio.micMuted ? "mic_off" : "mic")
        : root.feedbackMuted ? "volume_off"
        : root.feedbackValue < 0.34 ? "volume_mute"
        : root.feedbackValue < 0.67 ? "volume_down" : "volume_up"

    readonly property var osdPrefs: Config.options?.iris?.osd
    readonly property string osdGameRule: GameMode.active ? String(root.osdPrefs?.fullscreen ?? "show") : "show"
    readonly property string osdMediaMode: String(root.osdPrefs?.media ?? "yours")
    readonly property string levelStyle: String(root.osdPrefs?.style ?? "capsule")
    readonly property bool levelFigure: root.osdPrefs?.figure ?? true
    readonly property bool osdKeyboard: (root.osdPrefs?.keyboard ?? true) && root.osdGameRule === "show"
    function showFeedback(kind: string, requested = false): void {
        if (Date.now() < GlobalStates.irisLevelQuietUntil) return
        if (!(Config.options?.iris?.modules?.osd ?? true) || root.expanded || root.fullscreenCovered
            || root.osdGameRule === "hide" || root.targetScreen?.name !== GlobalStates.focusedScreen?.name) return
        const mode = String(root.osdPrefs?.levels ?? "yours")
        const touched = kind === "brightness" ? Brightness.lastUserChange : Audio.lastUserChange
        if (!requested && (mode === "off" || (mode === "yours" && Date.now() - touched > 1200))) return
        root.feedbackKind = kind
        feedbackTimer.restart()
    }

    readonly property bool eventsEnabled: root.options?.events ?? true
    property var event: ({ icon: "", tint: IrisStyle.text, title: "", detail: "", value: -1 })
    readonly property bool eventShown: eventTimer.running && !root.expanded && !root.feedback
    function showEvent(icon: string, tint: color, title: string, detail: string, value: real): void {
        if (!root.eventsEnabled || !eventsWarm.ready || root.expanded || root.fullscreenCovered
            || root.targetScreen?.name !== GlobalStates.focusedScreen?.name) return
        root.event = { icon: icon, tint: tint, title: title, detail: detail, value: value }
        eventTimer.restart()
    }
    Timer { id: eventTimer; interval: 2600; onTriggered: root.clearOsdRequests() }
    // The Island answers these requests, so it owns clearing them: a flag left
    // set is never seen again by the OSD fallback on another output.
    function clearOsdRequests(): void {
        GlobalStates.osdVolumeOpen = false
        GlobalStates.osdBrightnessOpen = false
        GlobalStates.osdMicOpen = false
        GlobalStates.osdMediaOpen = false
        GlobalStates.osdKeyboardLayoutOpen = false
    }
    Connections {
        target: GameMode
        function onManuallyActivatedChanged(): void {
            root.showEvent("sports_esports", GameMode.manuallyActivated ? IrisStyle.identity.green : IrisStyle.textSecondary,
                GameMode.manuallyActivated ? Translation.tr("Game mode on") : Translation.tr("Game mode off"),
                GameMode.manuallyActivated ? Translation.tr("Effects and notifications held back") : Translation.tr("Everything is back"), -1)
        }
    }
    property bool niriConfigBroken: false
    Connections {
        target: CompositorService.isNiri ? NiriService : null
        function onConfigLoadFinished(ok: bool, error: string): void {
            if (!ok) {
                const line = String(error ?? "").split("\n").map(part => part.trim()).find(part => part.length > 0) ?? ""
                root.showEvent("error", IrisStyle.danger, Translation.tr("Niri config has an error"),
                    line.length > 0 ? line : Translation.tr("The previous config is still in use"), -1)
            } else if (root.niriConfigBroken) {
                root.showEvent("check_circle", IrisStyle.success, Translation.tr("Niri config loaded"),
                    Translation.tr("The error is fixed"), -1)
            }
            root.niriConfigBroken = !ok
        }
    }
    Connections {
        target: LiveActivities
        function onFinished(activity: var): void {
            root.showEvent("check_circle", IrisStyle.identityColor(String(activity?.tint ?? "lavender")),
                String(activity?.title ?? ""), String(activity?.detail ?? "").length > 0 ? String(activity.detail) : Translation.tr("Done"), -1)
        }
    }
    property var badge: ({ icon: "", tint: IrisStyle.text, text: "" })
    function showBadge(icon: string, tint: color, text: string): void {
        if (!root.eventsEnabled || !eventsWarm.ready || root.fullscreenCovered
            || root.targetScreen?.name !== GlobalStates.focusedScreen?.name) return
        root.badge = { icon: icon, tint: tint, text: text }
        badgeTimer.restart()
    }
    Timer { id: badgeTimer; interval: 1600; onTriggered: root.clearOsdRequests() }
    Timer { id: eventsWarm; property bool ready: false; interval: 4000; running: true; onTriggered: ready = true }
    Connections {
        target: root.eventsEnabled && Battery.available ? Battery : null
        function onIsLowAndNotChargingChanged(): void {
            if (Battery.isLowAndNotCharging)
                root.showEvent("battery_alert", IrisStyle.danger, Translation.tr("Low battery"), Translation.tr("Plug in soon"), Battery.percentage)
        }
    }
    Connections {
        target: root.eventsEnabled ? DeviceEvents : null
        function onHappened(event: var): void {
            const tint = event.tone === "warn" ? IrisStyle.identity.orange
                : event.tone === "off" ? IrisStyle.subtext
                : ({ network: IrisStyle.identity.blue, internet: IrisStyle.identity.teal, bluetooth: IrisStyle.identity.blue, usb: IrisStyle.identity.sky,
                     power: IrisStyle.success, audio: IrisStyle.accent, displays: IrisStyle.identity.indigo,
                     drives: IrisStyle.identity.orange })[event.kind] ?? IrisStyle.accent
            root.showEvent(event.icon, tint, event.title, event.detail, event.value >= 0 ? event.value / 100 : -1)
        }
    }
    Connections {
        target: root.eventsEnabled ? Notifications : null
        function onSilentChanged(): void {
            root.showEvent(Notifications.silent ? "do_not_disturb_on" : "notifications_active",
                Notifications.silent ? IrisStyle.identity.lavender : IrisStyle.text, Translation.tr("Do not disturb"),
                Notifications.silent ? Translation.tr("On") : Translation.tr("Off"), -1)
        }
    }
    Connections {
        target: root.eventsEnabled ? TimerService : null
        function onCountdownRunningChanged(): void {
            if (!TimerService.countdownRunning && TimerService.countdownSecondsLeft <= 0)
                root.showEvent("alarm", IrisStyle.secondaryAccent, Translation.tr("Time's up"),
                    Translation.tr("%1 timer").arg(root.durationText(TimerService.countdownDuration)), -1)
        }
        function onPomodoroBreakChanged(): void {
            if (!TimerService.pomodoroRunning) return
            root.showEvent(TimerService.pomodoroBreak ? "coffee" : "self_improvement", IrisStyle.secondaryAccent,
                TimerService.pomodoroBreak ? (TimerService.pomodoroLongBreak ? Translation.tr("Long break") : Translation.tr("Break"))
                    : Translation.tr("Focus"),
                root.durationText(TimerService.pomodoroLapDuration), -1)
        }
    }
    property int lastRecordingSeconds: 0
    onRecordingChanged: {
        if (root.recording) root.lastRecordingSeconds = 0
        else if (root.eventsEnabled && root.lastRecordingSeconds > 0)
            root.showEvent("stop_circle", IrisStyle.danger, Translation.tr("Recording saved"), root.clockText(root.lastRecordingSeconds), -1)
    }
    Connections {
        target: root.recording ? RecorderStatus : null
        function onElapsedSecondsChanged(): void {
            if (RecorderStatus.elapsedSeconds > 0) root.lastRecordingSeconds = RecorderStatus.elapsedSeconds
        }
    }
    Connections {
        target: root.eventsEnabled ? Audio : null
        function onSinkProtectionTriggered(reason: string): void {
            root.showEvent("volume_off", IrisStyle.danger, Translation.tr("Volume held back"), reason, -1)
        }
    }
    Connections {
        target: root.eventsEnabled ? GlobalStates : null
        function onOsdMediaActionTriggered(action: string): void {
            if (root.osdMediaMode !== "off") root.showTrack(action)
        }
    }
    Connections {
        target: root.eventsEnabled && root.osdMediaMode === "every" ? MprisController : null
        function onTrackChanged(reverse: bool): void {
            if (root.eventShown || root.title.length === 0) return
            root.showTrack("")
        }
    }
    function showTrack(action: string): void {
        if (!root.hasMedia || root.primary === "media" || root.osdGameRule !== "show") return
        const title = StringUtils.cleanMusicTitle(root.title)
        root.showEvent(action === "next" ? "skip_next" : action === "previous" ? "skip_previous"
            : action === "pause" ? "pause" : action === "play" ? "play_arrow" : "music_note", IrisStyle.accent,
            title.length > 0 ? title : Translation.tr("Now playing"),
            root.ytMusic ? YtMusic.currentArtist : String(root.player?.trackArtist ?? ""), -1)
    }
    Connections {
        target: root.eventsEnabled ? KeyboardIndicators : null
        function onPopupSequenceChanged(): void {
            if (!KeyboardIndicators.ready || !root.osdKeyboard) return
            const kind = KeyboardIndicators.popupKind
            const active = KeyboardIndicators.popupActive
            root.showBadge(KeyboardIndicators.popupMaterialIcon,
                kind === "layout" ? IrisStyle.accent : active ? IrisStyle.secondaryAccent : IrisStyle.subtext,
                kind === "layout"
                    ? (KeyboardIndicators.currentLayoutCodeInline || KeyboardIndicators.popupText)
                    : KeyboardIndicators.popupText)
        }
    }
    function durationText(seconds: real): string {
        const m = Math.round(seconds / 60)
        return m >= 60 ? Math.floor(m / 60) + " h " + (m % 60) + " min" : m + " min"
    }

    ColorQuantizer {
        id: tintQuantizer
        source: root.hasMedia ? MediaArtwork.displaySource : ""
        depth: 2
        rescaleSize: 48
    }
    readonly property color artTint: {
        const colors = tintQuantizer.colors ?? []
        let best = null
        let bestScore = -1
        for (let i = 0; i < colors.length; i++) {
            const c = colors[i]
            const score = Math.max(0, c.hslSaturation) * (1 - Math.abs(c.hslLightness - 0.5))
            if (score > bestScore) { bestScore = score; best = c }
        }
        if (!best || best.hslSaturation < 0.14 || best.hslHue < 0) return IrisStyle.text
        return Qt.hsla(best.hslHue, Math.max(0.5, best.hslSaturation),
            Math.max(0.64, Math.min(0.76, best.hslLightness + 0.22)), 1)
    }

    readonly property bool visualExpanded: root.expanded && details.status === Loader.Ready
    readonly property real bubble: root.compactHeight
    readonly property real satelliteGap: Math.round(Math.max(0, Math.min(24, Number(Config.options?.iris?.bar?.satelliteGap ?? 6))) * root.d)
    readonly property real satelliteOffset: root.satelliteGap + Math.round(IrisStyle.fuseEdge / 4 * root.notchness)
    readonly property real fillet: Math.round(chassis.radius * 0.62 * root.notchness)
    readonly property real expandedWidth: Math.min(root.vertical ? root.availableAcross : root.availableWidth - 2 * (root.bubble + root.satelliteGap),
        root.effectivePage === "controls" ? (Math.max(340, Number(Config.options?.iris?.controlCenter?.width ?? 360))
            + (GlobalStates.irisControlEdit ? IrisControlOptions.editorExtra : 0)) * root.d + 2 * root.padding
            : (root.effectivePage === "activity" ? root.pageWidth * 384 / 440 : root.pageWidth) * root.d)
    readonly property real pageWidth: Math.max(360, Math.min(600, Number(root.options?.pageWidth ?? 440)))
    readonly property real padding: Math.round(20 * root.d)
    readonly property bool editingDesktop: GlobalStates.widgetEditMode
        && root.targetScreen?.name === GlobalStates.focusedScreen?.name
    readonly property string compactMode: root.feedback && !root.anchored ? "feedback"
        : root.eventShown && !root.anchored ? "event"
        : root.editingDesktop ? "edit"
        : IrisStyle.cluster && !root.zoned ? "clock" : root.primary
    readonly property string layout: String(root.options?.layout ?? "island")
    // Menu bar: a thin strip across the edge with the heart hanging from its middle as a notch.
    readonly property bool menubar: root.layout === "menubar" && !root.vertical
    readonly property bool fullWidth: root.layout === "full" || root.menubar
    // A clear menu bar leaves its items on the wallpaper (macOS): the notch is the only body on the edge.
    readonly property bool clearStrip: root.menubar && String(root.options?.strip ?? "clear") === "clear"
    readonly property bool fromHeart: root.zoned && root.heartShown && root.extensionRole === "page"
        && !(root.extensionOrigin?.visible ?? false)
    readonly property real heartSwell: Math.round(8 * root.d)
    // A page from a bar's heart is the Island growing: one body from the screen edge over the heart, its own
    // corners past the edge, so one material and one light run from the edge down; the heart row fades under it.
    readonly property bool grownPage: root.zoned && root.fromHeart
    readonly property real grownInset: root.grownPage ? Math.ceil(extension.targetRadius) : 0
    readonly property real heartUncovered: root.grownPage ? Math.max(0, 1 - 2.5 * extension.presentation) : 1
    // The heart's lip is the notch gesture: a bar with the notch off keeps one straight edge.
    readonly property bool swellsHeart: root.layout === "full" && !root.vertical && root.heartShown && root.notch
    readonly property real stripHeight: root.menubar ? Math.max(Math.round(24 * root.d), Math.round(root.compactHeight * 0.72)) : root.compactHeight
    readonly property real notchX: chassis.x + barZones.heartAlong
    readonly property rect notchArea: root.menubar && root.heartShown
        ? Qt.rect(root.notchX, root.bottomEdge ? root.height - root.compactHeight : 0, root.heartLength, root.compactHeight)
        : Qt.rect(0, 0, 0, 0)
    function zoneArea(rect: rect): rect {
        void (root.x + root.y + chassis.x + chassis.y + barZones.x + barZones.y)
        if (!root.menubar || rect.width <= 0 || rect.height <= 0) return Qt.rect(0, 0, 0, 0)
        const at = barZones.mapToItem(root, rect.x, rect.y)
        return Qt.rect(at.x, at.y, rect.width, rect.height)
    }
    readonly property rect menuStartArea: root.zoneArea(barZones.startArea)
    readonly property rect menuEndArea: root.zoneArea(barZones.endArea)
    readonly property bool zoned: root.fullWidth
    readonly property bool heartShown: !root.zoned || root.compactMode !== "idle" || !barZones.hasTime
    readonly property real heartTarget: !root.heartShown ? 0
        : Math.max(root.compactFloor, Math.min(root.compactCeiling, root.compactContentWidth + Math.round(29 * root.d * root.breathing)))
    readonly property alias heartLength: heartSpring.value
    IrisSpring { id: heartSpring; surface: "island"; intent: "move"; to: root.heartTarget; minimum: 0; epsilon: 0.25 }
    readonly property real fullChassisWidth: Math.max(0,
        root.availableWidth - 2 * Math.max(root.sideReserveTarget, root.fillet))
    readonly property bool anchored: root.fullWidth || root.vertical
    // A page is the Island itself growing, on every edge; only a full bar hangs its page beside the strip. On a
    // side edge compact activities (a level, an event) still ride beside the upright capsule.
    readonly property bool inlinePages: !root.fullWidth
    // The page is built synchronously (~90 ms): starting the shape before it is
    // ready spends the first frames of the morph inside that build.
    readonly property bool pageReady: !root.expanded || details.status === Loader.Ready
    readonly property bool inlineExpanded: root.visualExpanded && root.inlinePages && root.pageReady
    readonly property bool compactSizeClass: root.compactMode === "feedback" || root.compactMode === "event"
    readonly property bool spanning: root.fullWidth
    readonly property var compactRows: ({ idle: idleRow, media: mediaRow, record: recordRow,
        timer: timerRow, task: taskRow, clock: clockRow, edit: editRow, event: eventRow, feedback: feedbackRow })
    readonly property real compactContentWidth: root.vertical ? compactColumn.implicitHeight
        : root.compactRows[root.compactMode]?.implicitWidth ?? 0
    readonly property real compactFloor: root.compactHeight * 2.1
    readonly property real compactCeiling: Math.min(root.availableWidth,
        (root.compactMode === "media" ? 380 : root.compactMode === "event" ? 330 : 320) * root.d)
    readonly property real compactTargetWidth: root.spanning ? root.fullChassisWidth
        : Math.max(root.compactFloor, Math.min(root.compactCeiling,
            root.compactContentWidth + Math.round(29 * root.d * root.breathing) + root.barPieceReserve))
    readonly property real chassisTargetWidth: root.inlineExpanded ? root.expandedWidth : root.compactTargetWidth
    readonly property string clockStyle: {
        const style = String(IrisStyle.structuralValue("bar.clockStyle", "dateTime"))
        // A bar that already carries the calendar or the weather piece does not say it twice beside the time.
        if (root.zoned && style === "dateTime" && barZones.itemFor("calendar")) return "time"
        if (root.zoned && style === "weather" && barZones.itemFor("weather")) return "time"
        return style === "weather" && !(Weather.enabled && !String(Weather.data?.temp ?? "--").startsWith("--")) ? "time" : style
    }
    readonly property string trailing: String(IrisStyle.structuralValue("bar.trailing", "controls"))
    readonly property string trailingKind: root.trailing === "notifications" && (Notifications.list?.length ?? 0) === 0 ? "none" : root.trailing
    readonly property bool leftSatelliteShown: root.leftSatelliteRest && !root.inlineExpanded
    readonly property bool leftSatelliteRest: IrisStyle.cluster && !root.zoned && !root.feedback && !root.eventShown
        && !root.floatingSlots.includes("left")
        && root.primary !== "idle"
    readonly property bool rightSatelliteShown: root.rightSatelliteRest && !root.inlineExpanded
    function floatsAlone(kind: string): bool { return IrisPieces.floats(Config.options?.iris?.bubbles, kind) }
    readonly property bool rightSatelliteRest: !root.zoned && !root.feedback && !root.eventShown
        && !root.floatingSlots.includes("right") && !(IrisStyle.cluster && root.floatsAlone(root.trailingKind))
        && (IrisStyle.cluster ? root.trailingKind !== "none" : root.secondary.length > 0)

    readonly property var trayItems: SystemTray.items.values.filter(item => item && item.id
        && (!(Config.options?.iris?.tray?.hidePassive ?? false) || item.status !== Status.Passive))
    readonly property string auxiliary: String(IrisStyle.structuralValue("bar.auxiliary", "tray"))
    readonly property int auxiliarySlot: (IrisStyle.cluster ? root.trailingKind !== "none" && !root.floatsAlone(root.trailingKind) : root.secondary.length > 0)
        && !root.floatingSlots.includes("right") ? 2 : 1
    readonly property bool auxiliaryShown: root.auxiliaryRest && !root.inlineExpanded
    readonly property bool auxiliaryRest: !root.zoned && !root.feedback && !root.eventShown && root.auxiliary !== "none"
        && !root.floatsAlone(root.auxiliary)
        && !root.floatingSlots.includes("utility")
        && (root.auxiliary !== "tray" || (root.trayItems.length > 0 && !root.trayAppsFace))
    readonly property bool trayAppsFace: String(Config.options?.iris?.tray?.face ?? "apps") === "apps"
    readonly property string trayMenuToward: root.edge === "bottom" ? "up" : root.edge === "left" ? "right"
        : root.edge === "right" ? "left" : "down"
    readonly property var absorbed: GlobalStates.irisAbsorbed?.[root.targetScreen?.name ?? ""] ?? ({})
    readonly property var absorbedPieces: Array.from(root.absorbed?.island ?? [])
    readonly property var absorbedStart: Array.from(root.absorbed?.islandStart ?? [])
    function pieceTaken(kind: string): bool {
        if (root.absorbedPieces.includes(kind)) return false
        if (root.floatsAlone(kind)) return true
        if (root.auxiliaryRest && root.auxiliary === kind) return true
        if (root.rightSatelliteRest && IrisStyle.cluster && root.trailingKind === kind) return true
        return root.leftSatelliteRest && kind === "media"
    }
    readonly property var barPieces: {
        const carried = Array.from(IrisStyle.structuralValue("bar.pieces", []))
        for (const kind of root.absorbedPieces) if (!carried.includes(kind)) carried.push(kind)
        if (root.auxiliary === "tray" && root.trayAppsFace && !root.floatsAlone("tray")
                && !root.floatingSlots.includes("utility") && !carried.includes("tray"))
            carried.push("tray")
        return carried.filter(kind => IrisPieces.extraIds.includes(kind) && IrisPieces.available(kind) && !root.pieceTaken(kind))
    }
    readonly property real barPieceSize: Math.round(root.compactHeight - 10 * root.d)
    readonly property real barPieceGap: Math.round(6 * root.d)
    readonly property bool piecesAtStart: String(root.options?.piecesSide ?? "end") === "start"
    readonly property real trayStripGap: Math.round(4 * root.d)
    function barPieceAlong(kind: string): real {
        if (kind !== "tray" || !root.trayAppsFace) return root.barPieceSize
        const count = Math.max(1, root.trayItems.length)
        return count * root.barPieceSize + (count - 1) * root.trayStripGap
    }
    readonly property real barPieceReserve: root.zoned || root.barPieces.length === 0 ? 0
        : root.barPieces.reduce((sum, kind) => sum + root.barPieceAlong(kind), 0)
            + (root.barPieces.length - 1) * root.barPieceGap + Math.round(13 * root.d)

    readonly property real sideReserveTarget: root.auxiliaryShown
        ? root.auxiliarySlot * (root.bubble + root.satelliteOffset)
        : root.leftSatelliteShown || root.rightSatelliteShown ? root.bubble + root.satelliteOffset : root.fillet
    property real sideReserve: root.sideReserveTarget
    Behavior on sideReserve { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }

    property Item pageOrigin: null
    property string extensionRole: "page"
    readonly property string wantedRole: root.visualExpanded ? "page"
        : root.feedback ? "feedback"
        : root.eventShown ? "event" : ""
    onWantedRoleChanged: if (root.wantedRole.length > 0) root.extensionRole = root.wantedRole
    readonly property bool extensionOpen: root.anchored && root.wantedRole.length > 0
        && !(root.inlinePages && root.wantedRole === "page")
    readonly property real joinFillet: Math.round(root.compactHeight * 0.6)
    readonly property real floatGap: Math.round(6 * root.d)
    readonly property Item extensionOrigin: root.extensionRole === "page" ? root.pageOrigin
        : root.extensionRole === "feedback"
            ? root.pieceItem(root.feedbackKind === "mic" ? "mic" : root.feedbackKind === "brightness" ? "tools" : "sound")
        : null
    readonly property real originWidth: root.extensionOrigin?.visible
        ? (root.vertical ? root.extensionOrigin.height : root.extensionOrigin.width)
        : root.fromHeart && root.heartLength > 1 ? root.heartLength
        : Math.round(40 * root.d)
    readonly property real originCenterX: {
        const part = root.extensionOrigin
        if (part && part.visible) return part.mapToItem(root, part.width / 2, 0).x
        if (!root.zoned && root.extensionRole === "page" && root.pageOriginX >= 0) return root.pageOriginX
        if (root.zoned && root.heartShown) return chassis.x + barZones.heartAlong + root.heartLength / 2
        return chassis.x + chassis.width / 2
    }
    function extensionX(width: real): real {
        const inset = chassis.radius + root.joinFillet
        const min = chassis.x + inset
        const max = chassis.x + chassis.width - inset - width
        return Math.round(Math.max(min, Math.min(max, root.originCenterX - width / 2)))
    }
    readonly property real originCenterY: {
        const part = root.extensionOrigin
        if (part && part.visible) return part.mapToItem(root, 0, part.height / 2).y
        if (!root.zoned && root.extensionRole === "page" && root.pageOriginY >= 0) return root.pageOriginY
        if (root.zoned && root.heartShown) return chassis.y + barZones.heartAlong + root.heartLength / 2
        return chassis.y + chassis.height / 2
    }
    function extensionY(height: real): real {
        if (root.fullWidth) {
            const inset = chassis.radius + root.joinFillet
            return Math.round(Math.max(chassis.y + inset, Math.min(chassis.y + chassis.height - inset - height, root.originCenterY - height / 2)))
        }
        const sceneY = root.parent?.y ?? 0
        const screenH = root.Window.window?.height ?? root.targetScreen?.height ?? 1080
        const min = IrisFrame.safeInset("top") + Math.round(8 * root.d) - sceneY
        const max = screenH - IrisFrame.safeInset("bottom") - Math.round(8 * root.d) - sceneY - height
        return Math.round(Math.max(min, Math.min(max, root.originCenterY - height / 2)))
    }

    implicitWidth: root.vertical ? chassis.across + (extension.anchoredShape ? extension.reach : 0)
        : chassis.width + 2 * Math.max(root.sideReserve, root.fillet)
    implicitHeight: root.vertical ? chassis.height + 2 * Math.max(root.sideReserve, root.fillet)
        : chassis.bodyHeight + (root.anchored ? extension.reach : 0)
    readonly property rect extensionArea: root.anchored && extension.reach > 0.5
        ? Qt.rect(extension.x, extension.y, extension.width, extension.height)
        : Qt.rect(0, 0, 0, 0)
    // The input region is a Wayland commit: while a shape is under way it only
    // grows, so a collapsing Island does not hand the compositor a region a frame.
    readonly property bool morphing: (chassis.presentation > 0.002 && chassis.presentation < 0.998)
        || (extension.presentation > 0.002 && extension.presentation < 0.998)
    readonly property real inputWidthLive: root.vertical ? Math.max(root.implicitWidth, root.inlineExpanded ? root.expandedWidth : 0)
        : Math.max(root.implicitWidth, root.chassisTargetWidth + 2 * Math.max(root.sideReserveTarget, root.fillet))
    readonly property real inputHeightLive: root.vertical ? Math.max(root.implicitHeight,
        (root.inlineExpanded ? chassis.openHeightTarget : root.compactTargetWidth) + 2 * Math.max(root.sideReserveTarget, root.fillet))
        : Math.max(chassis.bodyHeight, chassis.bodyHeightTarget)
    property real inputWidthHeld: 0
    property real inputHeightHeld: 0
    function holdInput(): void {
        root.inputWidthHeld = root.morphing ? Math.max(root.inputWidthHeld, root.inputWidthLive) : root.inputWidthLive
        root.inputHeightHeld = root.morphing ? Math.max(root.inputHeightHeld, root.inputHeightLive) : root.inputHeightLive
    }
    onInputWidthLiveChanged: root.holdInput()
    onInputHeightLiveChanged: root.holdInput()
    onMorphingChanged: { root.holdInput(); if (!root.morphing) geometrySettle.restart() }
    readonly property real inputWidth: Math.max(root.inputWidthLive, root.inputWidthHeld)
    readonly property real inputHeight: Math.max(root.inputHeightLive, root.inputHeightHeld)

    Accessible.role: Accessible.Grouping
    Accessible.name: Translation.tr("Dynamic Island")

    property real paintNudge: 1
    Timer {
        interval: 420
        running: true
        onTriggered: { root.paintNudge = 0.999; nudgeBack.restart() }
    }
    Timer { id: nudgeBack; interval: 40; onTriggered: root.paintNudge = 1 }

    readonly property bool pointerOnIsland: chassisHover.hovered || extensionHover.hovered
        || leftSatellite.hovered || rightSatellite.hovered || auxiliarySatellite.hovered
    property point dwellAnchor: Qt.point(-1000, -1000)
    property bool pointerHeld: false
    onPointerHeldChanged: if (!root.pointerHeld && !root.pointerOnIsland && root.expanded && !root.pinned) leaveDelay.restart()

    readonly property bool fullscreenCovered: CompositorService.isNiri
        && GameMode.hasFullscreenOnOutput(root.targetScreen?.name ?? "")
        && !NiriService.inOverview
    readonly property bool suppressed: root.fullscreenCovered && !root.feedback && !root.expanded
    opacity: root.suppressed ? 0 : 1
    // Opacity only, on the whole Island: toggling visible or animating the chassis opacity leaves it unpainted.
    Behavior on opacity {
        NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing }
    }

    property point pointerScene: Qt.point(-1000, -1000)
    function trackDwell(position: point): void {
        root.pointerScene = position
        if (root.feedback || root.editingDesktop || wheelQuiet.running) { hoverDelay.stop(); return }
        if (Math.abs(position.x - root.dwellAnchor.x) + Math.abs(position.y - root.dwellAnchor.y) < 4) return
        root.dwellAnchor = position
        if ((root.options?.hoverExpand ?? true) && root.hoverArmed && !root.fullWidth && !root.expanded
                && root.pointerOnIsland && !root.pieceHovered)
            hoverDelay.restart()
    }

    // Pieces carried on the Island answer to taps and to being carried away. Peeking
    // on hover would move them out from under the pointer before either can happen.
    property int hoveredPieces: 0
    readonly property bool pieceHovered: root.hoveredPieces > 0 || leftSatellite.hovered
        || rightSatellite.hovered || auxiliarySatellite.hovered

    property bool hoverArmed: true
    onPointerOnIslandChanged: {
        if (root.pointerOnIsland) {
            leaveDelay.stop()
        } else {
            root.hoverArmed = true
            hoverDelay.stop()
            if (root.wheelHold) { root.wheelHold = false; feedbackTimer.restart() }
            if (root.expanded && !root.pinned && !root.pointerHeld) leaveDelay.restart()
        }
    }
    Timer {
        id: hoverDelay
        interval: Math.max(120, Number(root.options?.hoverDelay ?? 300))
        onTriggered: {
            if (!root.hoverArmed || !root.pointerOnIsland || root.expanded || root.feedback || root.editingDesktop || wheelQuiet.running) return
            if (root.pieceHovered) return
            const page = IrisStyle.cluster ? "desktop" : root.pageFor(root.primary)
            if (page === "desktop") root.openPage(page, false, null)
        }
    }
    Timer { id: wheelQuiet; interval: 900 }
    Timer { id: leaveDelay; interval: 450; onTriggered: { if (!root.pointerOnIsland && !root.pointerHeld && !root.pinned) root.expanded = false } }
    Timer { id: pageIntentExpiry; interval: 1800; onTriggered: root.pageIntent = "" }

    Binding {
        target: GlobalStates
        property: "irisControlsWarm"
        value: !root.controlsInIsland && (root.pointerOnIsland || root.expanded)
        when: root.targetScreen?.name === GlobalStates.focusedScreen?.name
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: GlobalStates
        property: "irisSettingsWarm"
        value: root.settingsIntent
        when: root.targetScreen?.name === GlobalStates.focusedScreen?.name
        restoreMode: Binding.RestoreNone
    }

    property real wheelAccumulator: 0
    function wheelSteps(event): int {
        root.wheelAccumulator += event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y * 4
        const steps = Math.trunc(root.wheelAccumulator / 120)
        root.wheelAccumulator -= steps * 120
        return steps
    }
    function stepLevel(level: string, steps: int): void {
        if (level === "brightness") {
            if (root.brightnessMonitor)
                root.brightnessMonitor.setBrightness(Math.max(0, Math.min(1, root.brightnessMonitor.brightness + steps * 0.05)))
        } else if (level === "mic") {
            Audio.setSourceVolume(Math.max(0, Math.min(1, (Audio.micVolume ?? 0) + steps * 0.05)))
        } else {
            Audio.setSinkVolume(Math.max(0, Math.min(Math.max(1, Audio.ceiling), (Audio.value ?? 0) + steps * 0.05)))
        }
    }
    function applyWheel(event): void {
        if (root.expanded) { root.wheelPages(event, false); return }
        const action = String(root.options?.scrollAction ?? "volume")
        if (action === "none") return
        hoverDelay.stop()
        wheelQuiet.restart()
        root.dwellAnchor = root.pointerScene
        const steps = root.wheelSteps(event)
        if (steps === 0) return
        const level = event.modifiers & Qt.ControlModifier ? "mic"
            : (action === "brightness") !== Boolean(event.modifiers & Qt.ShiftModifier) ? "brightness" : "volume"
        root.wheelHold = root.pointerOnIsland
        root.stepLevel(level, steps)
    }
    function applySatelliteWheel(event, satellite): void {
        hoverDelay.stop()
        wheelQuiet.restart()
        const steps = root.wheelSteps(event)
        if (steps === 0) return
        const level = satellite.kind === "mic" || (satellite.kind !== "sound" && (event.modifiers & Qt.ControlModifier)) ? "mic" : "sound"
        satellite.showLevel(level)
        GlobalStates.quietIrisLevels()
        root.stepLevel(level === "mic" ? "mic" : "volume", steps)
    }
    readonly property var cardKinds: IrisPieces.cardIds
    readonly property bool opensCards: String(Config.options?.iris?.bubbles?.opens ?? "card") === "card"
    function toggleBubbleCard(kind: string, part, source: string): void {
        if (GlobalStates.irisBubbleCard?.source === source) { GlobalStates.irisBubbleCard = null; return }
        const isChassis = part === chassis
        const r = root.partRect(part)
        const band = root.chassisBody()
        GlobalStates.irisBubbleCard = {
            kind: kind, source: source, screen: root.targetScreen?.name ?? "", edge: root.edge,
            x: r.x, y: r.y + root.screenOffsetY,
            width: r.width, height: r.height,
            radius: isChassis ? chassis.radius : IrisStyle.pieceRadius(Math.min(r.width, r.height)),
            bandX: band.x, bandWidth: band.width,
            bandY: band.y + root.screenOffsetY, bandHeight: band.height
        }
    }
    Connections {
        target: GlobalStates
        function onIrisBubbleCardRequestChanged(): void {
            if (GlobalStates.irisBubbleCardRequest.length === 0 || !root.focusedOutput) return
            Qt.callLater(() => {
                const kind = GlobalStates.irisBubbleCardRequest
                if (kind.length === 0) return
                GlobalStates.irisBubbleCardRequest = ""
                if (!root.cardKinds.includes(kind)) return
                root.expanded = false
                const piece = root.pieceItem(kind)
                if (piece) { root.toggleBubbleCard(kind, piece, "island-piece-" + kind); return }
                const part = [leftSatellite, rightSatellite, auxiliarySatellite].find(s => s.visible && s.kind === kind)
                root.toggleBubbleCard(kind, part ?? chassis, part ? "island-" + part.slot : "island-chassis")
            })
        }
    }
    function pieceItem(kind: string): var {
        if (root.zoned) return barZones.itemFor(kind)
        if (!root.barPieces.includes(kind)) return null
        const row = barPieceRow.children
        for (let i = 0; i < row.length; i++) {
            if (row[i] && row[i].visible && String(row[i].modelData ?? "") === kind) return row[i]
        }
        return null
    }
    // A piece the Island carries is still the stage's piece: what it opens, and where
    // that body grows from, is the same as when it floats.
    signal pieceActivated(string slot, string kind, var rect)
    function pieceOpen(kind: string, part): bool {
        const card = GlobalStates.irisBubbleCard
        if (card && card.source === "island-piece-" + kind && card.screen === (root.targetScreen?.name ?? "")) return true
        if (part && root.expanded && root.pageOrigin === part) return true
        return kind === "controls" && root.focusedOutput && GlobalStates.controlPanelOpen && !root.expanded
    }
    function activatePiece(kind: string, part): void {
        if (root.opensCards && root.cardKinds.includes(kind) && part) {
            root.toggleBubbleCard(kind, part, "island-piece-" + kind)
            return
        }
        const r = part ? root.partRect(part) : root.chassisBody()
        root.pieceActivated("extra-" + kind, kind, { x: r.x, y: r.y + root.screenOffsetY,
            size: Math.min(r.width, r.height), source: "island-piece-" + kind })
    }
    function activateBubble(kind: string, part): void {
        if (root.opensCards && root.cardKinds.includes(kind) && part) root.toggleBubbleCard(kind, part, "island-" + part.slot)
        else if (kind === "sound") Audio.toggleMute()
        else if (kind === "mic") Audio.toggleMicMute()
        else if (kind === "notifications" || kind === "calendar") GlobalStates.openSidebarRight(root.targetScreen?.name ?? "")
        else if (kind === "focus") Notifications.silent = !Notifications.silent
        else if (kind === "weather" || kind === "clock") root.openPage("desktop", true, part)
        else if (kind === "tray" || kind === "tools") root.openPage(kind, true, part)
        else root.openControlCenterFrom(part)
    }

    onPageChanged: if (root.controlsInIsland && root.page !== "controls" && root.focusedOutput
        && GlobalStates.controlPanelOpen && GlobalStates.irisMorphOwner !== "stage") GlobalStates.controlPanelOpen = false
    onExpandedChanged: {
        if (!root.expanded && root.page === "controls" && root.focusedOutput && GlobalStates.irisMorphOwner !== "stage")
            GlobalStates.controlPanelOpen = false
        if (!root.expanded) {
            root.pinned = false
            root.settingsIntent = false
            root.pageIntent = ""
            pageIntentExpiry.stop()
            if (root.pointerOnIsland) root.hoverArmed = false
        }
        else root.wheelHold = false
        if (root.expanded && root.focusedOutput) GlobalStates.irisBubbleCard = null
    }
    onVisualExpandedChanged: root.flyParts()
    readonly property real heroDecodeWidth: Math.round(Math.min(root.availableWidth - 2 * (root.bubble + root.satelliteGap), root.pageWidth * root.d) * 1.5)
    Image {
        id: heroPreload
        visible: false
        source: String(root.options?.desktopBanner ?? "wallpaper") === "wallpaper"
            ? WallpaperListener.wallpaperUrlForScreen(root.targetScreen) : ""
        asynchronous: true
        cache: true
        sourceSize.width: root.heroDecodeWidth
    }
    property Item pageCover: null
    readonly property Item coverFlightItem: coverFlight
    readonly property Item clockFlightItem: clockFlight
    readonly property Item chassisItem: chassis
    readonly property Item extensionItem: extension
    readonly property Item heroPreloadItem: heroPreload
    property Item heroClock: null
    readonly property Item restingCover: IrisStyle.cluster && leftSatellite.shown
        ? (root.primary === "media" ? leftSatellite.artwork : null)
        : (root.compactMode === "media" && !root.vertical ? compactCover : null)
    readonly property Item restingClock: root.vertical ? null : root.compactMode === "clock" ? clusterClock
        : root.compactMode === "idle" ? idleClock : null
    function flyParts(): void {
        // Only the arrival flies: closing, the part rides the shape home, and a
        // copy crossing a page that is still opaque read as a second design.
        if (!root.visualExpanded) { coverFlight.stop(); clockFlight.stop(); return }
        const cover = root.effectivePage === "media" ? root.pageCover : null
        const clock = root.effectivePage === "desktop" ? root.heroClock : null
        if (cover && root.restingCover) coverFlight.launch(root.restingCover, cover)
        else coverFlight.stop()
        if (clock && root.restingClock) clockFlight.launch(root.restingClock, clock)
        else clockFlight.stop()
    }
    onEffectivePageChanged: if (root.visualExpanded) { coverFlight.stop(); clockFlight.stop() }
    Binding {
        target: GlobalStates
        property: "irisIslandShape"
        value: root.expanded ? "expanded" : root.compactMode
        when: root.targetScreen?.name === GlobalStates.focusedScreen?.name
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: GlobalStates
        property: "irisIslandExpanded"
        value: root.expanded
        when: root.targetScreen?.name === GlobalStates.focusedScreen?.name
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: GlobalStates
        property: "irisIslandPage"
        value: root.expanded ? root.effectivePage : ""
        when: root.targetScreen?.name === GlobalStates.focusedScreen?.name
        restoreMode: Binding.RestoreNone
    }

    Timer {
        id: feedbackTimer
        interval: Math.max(800, Math.min(5000, Number(root.osdPrefs?.duration ?? 1500))) + 300
        onTriggered: root.clearOsdRequests()
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.playing && !root.ytMusic
        onTriggered: root.player?.positionChanged()
    }
    Connections {
        target: Audio.sink?.audio ?? null
        function onVolumeChanged(): void { root.showFeedback("volume") }
        function onMutedChanged(): void { root.showFeedback("volume") }
    }
    Connections {
        target: Audio
        function onMicVolumeChanged(): void { root.showFeedback("mic") }
        function onMicMutedChanged(): void { root.showFeedback("mic") }
    }
    Connections {
        target: Brightness
        function onBrightnessChanged(): void { root.showFeedback("brightness") }
    }
    Connections {
        target: Notifications
        function onPopupListChanged(): void {
            if ((Notifications.popupList?.length ?? 0) > 0 && !root.pinned) root.expanded = false
        }
    }
    Connections {
        target: GlobalStates
        function onOsdVolumeOpenChanged(): void { if (GlobalStates.osdVolumeOpen) root.showFeedback("volume", true) }
        function onOsdBrightnessOpenChanged(): void { if (GlobalStates.osdBrightnessOpen) root.showFeedback("brightness", true) }
        function onOsdMicOpenChanged(): void { if (GlobalStates.osdMicOpen) root.showFeedback("mic", true) }
        function onOsdKeyboardLayoutOpenChanged(): void {
            if (!GlobalStates.osdKeyboardLayoutOpen || !root.osdKeyboard) return
            root.showBadge("language", IrisStyle.accent,
                KeyboardIndicators.currentLayoutCodeInline || KeyboardIndicators.currentLayoutName)
        }
        function onWallpaperSelectorOpenChanged(): void {
            root.publishRestOrigin()
            if (GlobalStates.wallpaperSelectorOpen) root.expanded = false
        }
        function onSearchOpenChanged(): void {
            root.publishRestOrigin()
            if (GlobalStates.searchOpen) root.expanded = false
        }
        function onControlPanelOpenChanged(): void {
            if (GlobalStates.irisMorphOwner === "stage") return
            if (root.controlsInIsland) {
                if (!root.focusedOutput) return
                if (GlobalStates.controlPanelOpen && !(root.expanded && root.page === "controls")) root.openPage("controls", true, null)
                else if (!GlobalStates.controlPanelOpen && root.expanded && root.page === "controls") root.expanded = false
                return
            }
            if (GlobalStates.controlPanelOpen) {
                if (!root.controlOriginPrepared) {
                    root.controlMorphPart = IrisStyle.cluster && rightSatellite.shown ? rightSatellite : chassis
                    root.publishOrigin(root.controlMorphPart)
                    root.expanded = false
                }
                root.controlOriginPrepared = false
                return
            }
            const part = root.controlMorphPart && root.controlMorphPart.visible ? root.controlMorphPart : chassis
            root.publishOrigin(part)
        }
        function onSettingsOverlayOpenChanged(): void {
            if (GlobalStates.irisMorphOwner === "control" && !GlobalStates.settingsOverlayOpen) {
                GlobalStates.irisMorphOwner = ""
                root.settingsMorphPart = chassis
            } else if (GlobalStates.irisMorphOwner !== "") { root.settingsOriginPrepared = false; return }
            if (GlobalStates.settingsOverlayOpen) {
                if (!root.settingsOriginPrepared) {
                    root.settingsMorphPart = chassis
                    root.publishRestOrigin()
                    root.expanded = false
                }
                root.settingsOriginPrepared = false
                return
            }
            const part = root.settingsMorphPart && root.settingsMorphPart.visible ? root.settingsMorphPart : chassis
            root.publishOrigin(part)
        }
    }

    component Flight: Item {
        id: flight
        property Item from: null
        property Item to: null
        property real t: 1
        property rect fromRect: Qt.rect(0, 0, 0, 0)
        property rect toRect: Qt.rect(0, 0, 0, 0)
        // Read at launch: a closing page is unloaded before the copy lands.
        property real fromRadius: 0
        property real fromPixelSize: 0
        property bool active: false
        readonly property bool flying: flight.active && flight.t < 1
        z: 10
        visible: flight.flying
        x: flight.fromRect.x + (flight.toRect.x - flight.fromRect.x) * flight.t
        y: flight.fromRect.y + (flight.toRect.y - flight.fromRect.y) * flight.t
        width: flight.fromRect.width + (flight.toRect.width - flight.fromRect.width) * flight.t
        height: flight.fromRect.height + (flight.toRect.height - flight.fromRect.height) * flight.t

        function rectOf(item: Item): rect {
            if (!item) return Qt.rect(0, 0, 0, 0)
            const a = item.mapToItem(root, 0, 0)
            const b = item.mapToItem(root, item.width, item.height)
            return Qt.rect(a.x, a.y, b.x - a.x, b.y - a.y)
        }
        function hides(item: Item): bool {
            return flight.flying && (item === flight.from || item === flight.to)
        }
        function launch(source: Item, target: Item): void {
            if (!source || !target || IrisStyle.duration(240) <= 0) { flight.stop(); return }
            const midway = flight.flying
            const mix = (a, b) => a + (b - a) * flight.t
            flight.fromRect = midway ? Qt.rect(flight.x, flight.y, flight.width, flight.height) : flight.rectOf(source)
            flight.fromRadius = midway ? mix(flight.fromRadius, flight.to?.radius ?? flight.fromRadius) : (source.radius ?? 0)
            flight.fromPixelSize = midway ? mix(flight.fromPixelSize, flight.to?.pixelSize ?? flight.fromPixelSize) : (source.pixelSize ?? 0)
            flight.from = source
            flight.active = true
            flight.to = target
            flight.toRect = flight.rectOf(target)
            travel.restart()
        }
        function stop(): void {
            travel.stop()
            flight.t = 1
            flight.active = false
            flight.from = null
            flight.to = null
        }

        NumberAnimation {
            id: travel
            target: flight
            property: "t"
            from: 0
            to: 1
            duration: IrisStyle.settleDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: IrisStyle.emergeCurve
            onStopped: if (flight.t >= 1) { flight.active = false; flight.from = null; flight.to = null }
        }
        FrameAnimation {
            running: flight.flying
            onTriggered: if (flight.to) flight.toRect = flight.rectOf(flight.to)
        }
    }

    component Satellite: Item {
        id: satellite
        property string kind: ""
        property string slot: ""
        property bool shown: false
        property bool resting: false
        property bool leftSide: false
        property int slotIndex: 1
        readonly property alias hovered: satelliteHover.hovered
        readonly property alias artwork: face.artwork
        signal activated()
        property string levelKind: ""
        function showLevel(level: string): void {
            if (satellite.kind === "sound" || satellite.kind === "mic") return
            satellite.levelKind = level
            levelLinger.restart()
        }
        Timer { id: levelLinger; interval: 1400; onTriggered: satellite.levelKind = "" }

        readonly property real emerge: emergeSpring.value * Math.max(0, 1 - chassis.presentation / 0.5) * (1 - root.spotlightYield)
        IrisSpring {
            id: emergeSpring
            surface: "island"
            intent: "move"
            to: satellite.resting ? 1 : 0
            minimum: 0
        }

        width: Math.round((root.bubble - Math.round(8 * root.d) * root.notchness) * root.satelliteScale)
        height: width
        z: -1
        readonly property real acrossCentre: root.rightEdge ? chassis.x + root.compactHeight / 2
            : chassis.x + chassis.leftInset + root.compactHeight / 2
        y: root.vertical ? (satellite.leftSide
                ? chassis.y + (-root.satelliteOffset - height) * satellite.emerge
                : chassis.y + chassis.height - height + (root.satelliteOffset + height) * satellite.slotIndex * satellite.emerge)
            : root.bottomEdge ? root.height - (root.bubble + height) / 2 : (root.bubble - height) / 2
        x: root.vertical ? Math.round(satellite.acrossCentre - width / 2)
            : satellite.leftSide
            ? chassis.x + (-root.satelliteOffset - width) * satellite.emerge
            : chassis.x + chassis.width - width + (root.satelliteOffset + width) * satellite.slotIndex * satellite.emerge
        // Kept in the scene while the Island is open: a satellite's face carries
        // Shapes, and dropping their nodes on every open meant re-triangulating
        // them on the frame that starts the close (measured: one 88 ms frame).
        visible: satellite.emerge > 0.01 || root.expanded || chassis.presentation > 0.002
        readonly property bool lifted: root.draggedSlot === satellite.slot
        opacity: satellite.lifted ? 0 : 1
        scale: 0.86 + 0.14 * satellite.emerge

        IrisBubbleFace {
            id: face
            bodyless: true
            screenName: root.targetScreen?.name ?? ""
            opacity: Math.max(0, Math.min(1, (satellite.emerge - 0.45) / 0.4))
            anchors.fill: parent
            kind: satellite.levelKind.length > 0 ? satellite.levelKind : satellite.kind
            tint: root.artTint
            playing: root.playing
            mediaProgress: root.trackProgress
            trayCount: root.trayItems.length
            coverHidden: coverFlight.hides(face.artwork)
            pressed: bubblePointer.pressed && !bubblePointer.lifting
            hovered: satelliteHover.hovered
        }
        HoverHandler {
            id: satelliteHover
            cursorShape: Qt.PointingHandCursor
            onPointChanged: root.trackDwell(point.scenePosition)
        }
        WheelHandler {
            enabled: satellite.kind === "sound" || satellite.kind === "mic" || (root.options?.scrollBubbles ?? true)
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => root.applySatelliteWheel(event, satellite)
        }
        IrisBubbleGrip {
            id: bubblePointer
            anchors.fill: parent
            slot: satellite.slot
            kind: satellite.kind
            screenName: root.targetScreen?.name ?? ""
            screenOffsetY: root.screenOffsetY
            holdLifts: !GlobalStates.irisEdit
            pullDistance: GlobalStates.irisEdit ? 6 * root.d : 0
            onTapped: {
                if (GlobalStates.irisEdit) {
                    GlobalStates.irisEditTarget = ""
                    GlobalStates.irisEditSelection = GlobalStates.irisEditSelection === satellite.slot ? "" : satellite.slot
                    return
                }
                satellite.activated()
            }
        }
        Accessible.role: Accessible.Button
        Accessible.name: face.Accessible.name
    }

    Satellite {
        id: leftSatellite
        slot: "left"
        leftSide: true
        kind: root.primary
        shown: root.leftSatelliteShown
        resting: root.leftSatelliteRest
        onActivated: {
            if (root.mediaBubbleCard) root.toggleBubbleCard("media", leftSatellite, "island-left")
            else root.openPage(root.pageFor(root.primary), true, leftSatellite)
        }
    }
    readonly property bool mediaBubbleCard: IrisStyle.cluster && root.primary === "media"
        && String(Config.options?.iris?.player?.bubbleOpens ?? "card") === "card"
    readonly property bool focusedOutput: root.targetScreen?.name === GlobalStates.focusedScreen?.name
    Connections {
        target: GlobalStates
        function onIrisIslandPageRequestChanged(): void {
            const page = GlobalStates.irisIslandPageRequest
            if (page.length === 0 || !root.focusedOutput) return
            GlobalStates.irisIslandPageRequest = ""
            root.openPage(page, true, null)
        }
    }
    readonly property var bubbleKinds: ({
        left: IrisStyle.cluster && root.primary !== "idle" ? root.primary : "",
        right: IrisStyle.cluster ? (root.trailingKind !== "none" && !root.floatsAlone(root.trailingKind) ? root.trailingKind : "") : root.secondary,
        utility: root.auxiliary !== "none" && !root.floatsAlone(root.auxiliary)
            && (root.auxiliary !== "tray" || root.trayItems.length > 0) ? root.auxiliary : ""
    })
    readonly property var fieldShapes: {
        void (root.x + root.y + (root.parent?.x ?? 0) + (root.parent?.y ?? 0)
            + chassis.x + chassis.width + chassis.bodyHeight + chassis.radius
            + extension.x + extension.y + extension.width + extension.height
            + leftSatellite.x + rightSatellite.x + auxiliarySatellite.x + leftSatellite.width
            + badgePill.x + badgePill.y + badgePill.bodyWidth + (badgePill.visible ? 1 : 0)
            + compactColumn.y + compactColumn.height)
        const out = []
        if (root.suppressed || root.opacity <= 0.01) return out
        const melt = Math.min(1, Math.max(0, root.notchness))
        if ((melt > 0.01 || root.clearStrip) && !IrisFrame.framed) {
            const window = root.Window.window
            const wide = (window?.width ?? 0) + 4 * IrisStyle.fuseDeep
            const deep = Math.max(8, IrisStyle.fuseDeep * 2)
            const top = root.bottomEdge ? (window?.height ?? 0) + 1 : -deep - 1
            const tall = (window?.height ?? 0) + 4 * IrisStyle.fuseDeep
            out.push(root.vertical
                ? { x: root.rightEdge ? (window?.width ?? 0) + 1 : -deep - 1, y: -2 * IrisStyle.fuseDeep, width: deep, height: tall,
                    radius: 0, paints: true, fuse: IrisStyle.fuseDeep, id: "edge" }
                : { x: -2 * IrisStyle.fuseDeep, y: top, width: wide, height: deep,
                    radius: 0, paints: true, fuse: IrisStyle.fuseDeep, id: "edge" })
        }
        const body = root.chassisBody()
        const strip = root.menubar ? root.stripHeight : body.height
        const across = root.fullWidth && !root.vertical ? root.Window.window?.width ?? body.x + body.width : 0
        const bandInset = IrisFrame.framed ? IrisFrame.band : 0
        const edgeJoin = IrisFrame.framed ? "frame" : "edge"
        if (!root.clearStrip) out.push({ x: across > 0 ? bandInset : body.x,
            y: root.menubar && root.bottomEdge ? body.y + body.height - strip : body.y,
            width: across > 0 ? across - bandInset * 2 : body.width, height: strip,
            radius: across > 0 ? 0 : root.menubar ? strip / 2 : chassis.radius, paints: true,
            fuse: across > 0 ? Math.round(16 * root.d) : IrisStyle.fuse + (IrisStyle.fuseEdge - IrisStyle.fuse) * melt, id: "island",
            joins: melt <= 0.01 ? "" : IrisFrame.framed ? "frame" : "edge" })
        // On its side, the heart of a full bar swells inward out of the bar: the same gesture as a menu bar's notch.
        if (root.vertical && root.zoned && root.notch && root.heartShown && compactColumn.height > 1) {
            const at = compactColumn.mapToItem(null, 0, 0)
            const wide = body.width + root.heartSwell
            out.push({ x: root.rightEdge ? body.x - root.heartSwell : body.x, y: at.y, width: wide, height: compactColumn.height,
                radius: wide / 2, paints: true, fuse: IrisStyle.fuseEdge, id: "islandheart", joins: "island" })
        }
        // Across the top or bottom the heart of a full bar swells out of it the same way.
        if (root.swellsHeart && root.heartLength > 1) {
            const at = chassis.mapToItem(null, barZones.heartAlong, 0)
            const tall = body.height + root.heartSwell
            out.push({ x: at.x, y: root.bottomEdge ? body.y - root.heartSwell : body.y, width: root.heartLength, height: tall,
                radius: Math.min(Math.round(12 * root.d), IrisStyle.radius), paints: true, fuse: Math.round(16 * root.d), id: "islandheart", joins: "island" })
        }
        if (root.menubar && root.heartShown && root.heartLength > 1) {
            const at = chassis.mapToItem(null, barZones.heartAlong, 0)
            out.push({ x: at.x, y: body.y, width: root.heartLength, height: body.height, radius: root.compactHeight / 2,
                paints: true, fuse: root.clearStrip ? IrisStyle.fuseEdge : Math.round(32 * root.d), id: "islandnotch",
                joins: root.clearStrip ? edgeJoin : "island" })
        }
        if (extension.visible && extension.width > 1 && extension.height > 1) {
            const page = extension.mapToItem(null, 0, 0)
            const floating = root.zoned && !root.vertical && !root.fromHeart
            const grown = root.grownPage
            const sink = grown ? 0 : root.fullWidth && !floating ? Math.min(extension.radius, root.compactHeight) : 0
            out.push({ x: page.x - (root.vertical && !root.rightEdge ? sink : 0), y: page.y - (!root.vertical && !root.bottomEdge ? sink : 0),
                width: extension.width + (root.vertical ? sink : 0), height: extension.height + (root.vertical ? 0 : sink),
                radius: extension.radius, paints: true, fuse: grown ? IrisStyle.fuseEdge : IrisStyle.fuseDeep,
                // Inline, the page is the chassis rectangle itself: a smooth union of two equal shapes swells the contour by fuse / 4.
                joins: !extension.anchoredShape || floating ? "" : grown && root.clearStrip ? (IrisFrame.framed ? "frame" : "edge")
                    : root.clearStrip ? "islandnotch" : "island" })
        }
        if (badgePill.visible) {
            const at = badgePill.mapToItem(null, (badgePill.width - badgePill.bodyWidth) / 2, 0)
            out.push({ x: at.x, y: at.y, width: badgePill.bodyWidth, height: badgePill.height, radius: badgePill.height / 2,
                paints: false, id: "badge", joins: "island", fuse: IrisStyle.fuseDeep * (1 - badgePill.reveal) })
        }
        for (const satellite of [leftSatellite, rightSatellite, auxiliarySatellite]) {
            if (!satellite.visible || satellite.emerge <= 0.01) continue
            const size = satellite.width * satellite.scale
            const centre = satellite.mapToItem(null, satellite.width / 2, satellite.height / 2)
            // Leaving, a satellite passes behind the Island: it melts into it only once it is out.
            const joined = IrisStyle.fuse * IrisStyle.ramp(satellite.emerge, 0.85, 0.15)
            out.push({ x: centre.x - size / 2, y: centre.y - size / 2, width: size, height: size,
                radius: IrisStyle.pieceRadius(size), paints: true, fuse: joined, satellite: true, id: "satellite:" + satellite.slot,
                joins: "island" })
        }
        return out
    }
    readonly property var islandGeometry: {
        void (root.x + (root.parent?.x ?? 0) + (root.parent?.y ?? 0) + chassis.x + chassis.y + chassis.width + chassis.height + chassis.bodyHeight)
        const p = root.chassisBody()
        return {
            x: p.x, y: p.y + root.screenOffsetY, width: p.width, height: p.height,
            bubble: leftSatellite.width, gap: root.satelliteOffset, bottomEdge: root.bottomEdge,
            edge: root.edge, vertical: root.vertical,
            auxiliarySlot: root.auxiliarySlot, resting: !root.expanded,
            fullWidth: root.spanning
        }
    }
    function publishBubbleKinds(): void {
        const name = root.targetScreen?.name ?? ""
        if (name.length === 0) return
        const kinds = Object.assign({}, GlobalStates.irisBubbleKinds ?? {})
        kinds[name] = root.bubbleKinds
        GlobalStates.irisBubbleKinds = kinds
    }
    property string publishedGeometry: ""
    function publishIslandGeometry(): void {
        const name = root.targetScreen?.name ?? ""
        // Only the resting shape fans out: it feeds every piece, card and mask,
        // so a collapsing chassis must not publish a new one every frame — and a
        // shape that came back to where it was must not publish at all. Writing
        // this map rebuilds every piece, plate, hit rect and field shape on the
        // output: measured at one 87 ms frame, right as the Island settled.
        if (name.length === 0 || root.expanded || root.morphing) return
        const next = root.islandGeometry
        const key = JSON.stringify(next)
        if (key === root.publishedGeometry) return
        root.publishedGeometry = key
        const geometry = Object.assign({}, GlobalStates.irisIslandGeometry ?? {})
        geometry[name] = next
        GlobalStates.irisIslandGeometry = geometry
    }
    onBubbleKindsChanged: root.publishBubbleKinds()
    onIslandGeometryChanged: geometrySettle.restart()
    // Resting reshapes (width, notch, placement) change the geometry every frame; one fan-out per frame drops the output to ~14 fps.
    Timer { id: geometrySettle; interval: 60; onTriggered: root.publishIslandGeometry() }
    Component.onCompleted: { root.publishBubbleKinds(); root.publishIslandGeometry() }
    readonly property var floatingSlots: ["left", "right", "utility"]
        .filter(slot => String(Config.options?.iris?.bubbles?.[slot]?.place ?? "island") !== "island"
            && !(root.absorbed?.islandSlots ?? []).includes(slot))
    readonly property string draggedSlot: GlobalStates.irisBubbleDrag && GlobalStates.irisBubbleDrag.screen === (root.targetScreen?.name ?? "")
        ? String(GlobalStates.irisBubbleDrag.slot) : ""
    Satellite {
        id: rightSatellite
        slot: "right"
        kind: IrisStyle.cluster ? root.trailingKind : root.secondary
        shown: root.rightSatelliteShown
        resting: root.rightSatelliteRest
        onActivated: {
            if (!IrisStyle.cluster) root.openPage(root.pageFor(root.secondary), true, rightSatellite)
            else root.activateBubble(root.trailingKind, rightSatellite)
        }
    }

    Satellite {
        id: auxiliarySatellite
        slot: "utility"
        kind: root.auxiliary
        slotIndex: root.auxiliarySlot
        shown: root.auxiliaryShown
        resting: root.auxiliaryRest
        onActivated: root.activateBubble(root.auxiliary, auxiliarySatellite)
    }

    Flight {
        id: coverFlight
        IrisArtwork {
            anchors.fill: parent
            source: MediaArtwork.displaySource
            decodeSize: Math.ceil(68 * root.d * 2)
            circular: false
            radius: coverFlight.fromRadius + ((coverFlight.to?.radius ?? coverFlight.fromRadius) - coverFlight.fromRadius) * coverFlight.t
        }
    }
    Flight {
        id: clockFlight
        IrisClock {
            readonly property real fromSize: Math.max(1, clockFlight.fromPixelSize)
            readonly property real toSize: Math.max(1, clockFlight.to?.pixelSize ?? clockFlight.fromPixelSize)
            pixelSize: Math.max(fromSize, toSize)
            transformOrigin: Item.TopLeft
            scale: (fromSize + (toSize - fromSize) * clockFlight.t) / pixelSize
        }
    }

    Item {
        id: badgePill
        readonly property bool shown: badgeTimer.running
        property real reveal: badgePill.shown ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: IrisStyle.emergeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.emergeCurve } }
        readonly property real gap: Math.round(8 * root.d)
        width: badgeRow.implicitWidth + Math.round(22 * root.d)
        height: Math.round(28 * root.d)
        x: !root.vertical ? (root.width - width) / 2
            : root.rightEdge ? chassis.x - (width + gap) * badgePill.reveal + width * (1 - badgePill.reveal)
            : chassis.x + chassis.width - width + (width + gap) * badgePill.reveal
        y: root.vertical ? Math.round(chassis.y + (chassis.height - height) / 2)
            : root.bottomEdge ? -(height + gap) * badgePill.reveal + height * (1 - badgePill.reveal)
            : chassis.bodyHeight - height + (height + gap) * badgePill.reveal
        z: -2
        visible: badgePill.reveal > 0.01
        // The body is the field's (a drop out of the Island that stretches into the pill); only the words live here.
        readonly property real bodyWidth: badgePill.height + (badgePill.width - badgePill.height) * badgePill.reveal
        Row {
            id: badgeRow
            anchors.centerIn: parent
            opacity: IrisStyle.contentAt(badgePill.reveal)
            spacing: 6 * root.d
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: root.badge.icon
                iconSize: 15 * root.d
                color: root.badge.tint
            }
            IrisText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.badge.text
                font.pixelSize: IrisStyle.typeMeta
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
        }
    }

    ClippingRectangle {
        id: chassis
        // ClippingRectangle does not re-mask when per-corner radii change live.
        readonly property real restWidth: root.compactTargetWidth
        readonly property real restHeight: root.compactHeight
        readonly property real restRadius: root.notch ? root.compactHeight / 2 : IrisStyle.pieceRadius(root.compactHeight)
        readonly property real openWidthTarget: root.expandedWidth
        readonly property real openHeightLive: (details.item?.implicitHeight ?? 0) + root.padding * 2
        property real openHeightHeld: 0
        onOpenHeightLiveChanged: if (root.inlineExpanded && chassis.openHeightLive > root.padding * 2)
            chassis.openHeightHeld = chassis.openHeightLive
        readonly property real openHeightTarget: root.inlineExpanded || chassis.openHeightHeld <= 0
            ? chassis.openHeightLive : chassis.openHeightHeld
        readonly property real openRadius: Math.max(IrisStyle.radius, 30 * root.d)
        readonly property alias restW: restWidthSpring.value
        readonly property alias openW: openWidthSpring.value
        readonly property alias openH: openHeightSpring.value
        IrisSpring { id: restWidthSpring; surface: "island"; to: chassis.restWidth; intent: "move"; epsilon: 0.25 }
        IrisSpring { id: openWidthSpring; surface: "island"; to: chassis.openWidthTarget; intent: "move"; epsilon: 0.25; animate: chassis.presentation > 0.01 }
        IrisSpring { id: openHeightSpring; surface: "island"; to: chassis.openHeightTarget; intent: "move"; epsilon: 0.25; animate: chassis.presentation > 0.01 }
        readonly property alias presentation: chassisSpring.value
        IrisSpring { id: chassisSpring; surface: "island"; to: root.inlineExpanded ? 1 : 0; minimum: 0 }
        function lerp(a: real, b: real): real { return a + (b - a) * chassis.presentation }
        readonly property real bodyHeightTarget: root.inlineExpanded ? chassis.openHeightTarget : chassis.restHeight
        readonly property real bodyHeight: Math.round(chassis.lerp(chassis.restHeight, chassis.openH))
        // Whole pixels: the chassis draws its content through a texture and a half-pixel offset softens it.
        readonly property real edgeInset: Math.ceil(chassis.radius * root.notchness)
        readonly property real topInset: root.edge === "top" ? chassis.edgeInset : 0
        readonly property real bottomInset: root.bottomEdge ? chassis.edgeInset : 0
        readonly property real leftInset: root.edge === "left" ? chassis.edgeInset : 0
        readonly property real rightInset: root.rightEdge ? chassis.edgeInset : 0
        // Upright on a side edge it grows out of its band like it grows down from the top: across, from the
        // capsule's thickness to the page's width, and along, from the capsule's length to the page's height.
        readonly property real across: Math.round(chassis.lerp(root.compactHeight, chassis.openW))
        x: !root.vertical ? Math.round((root.width - width) / 2)
            : root.rightEdge ? root.width - chassis.across : -chassis.leftInset
        y: root.vertical ? Math.round((root.height - chassis.height) / 2)
            : root.bottomEdge ? root.height - chassis.bodyHeight : -chassis.topInset
        width: root.vertical ? chassis.across + chassis.leftInset + chassis.rightInset
            : Math.round(chassis.lerp(chassis.restW, chassis.openW))
        height: root.vertical ? Math.round(chassis.lerp(chassis.restW, chassis.openH)) : chassis.bodyHeight + chassis.topInset + chassis.bottomInset
        // Opaque: a transparent ClippingRectangle past the screen edge stops painting its children.
        color: IrisStyle.bodyClip
        radius: Math.min((root.vertical ? Math.min(chassis.across, chassis.height) : chassis.width) / 2, chassis.restRadius
            + (chassis.openRadius - chassis.restRadius) * Math.min(1, chassis.presentation))

        HoverHandler {
            id: chassisHover
            onPointChanged: root.trackDwell(point.scenePosition)
        }
        PointHandler {
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onActiveChanged: if (active && root.expanded) root.pinned = true
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => root.applyWheel(event)
        }

        Item {
            id: islandResize
            z: 20
            visible: GlobalStates.irisEdit && !root.expanded
            width: Math.round((root.vertical ? 14 : 44) * root.d)
            height: Math.round((root.vertical ? 44 : 14) * root.d)
            x: !root.vertical ? Math.round((chassis.width - width) / 2) : root.rightEdge ? 0 : chassis.width - width
            y: root.vertical ? Math.round((chassis.height - height) / 2) : root.bottomEdge ? 0 : chassis.height - height
            Rectangle {
                anchors.centerIn: parent
                width: root.vertical ? Math.max(2, Math.round(3 * root.d)) : Math.round(24 * root.d)
                height: root.vertical ? Math.round(24 * root.d) : Math.max(2, Math.round(3 * root.d))
                radius: Math.min(width, height) / 2
                color: resizeHover.hovered || resizeDrag.active ? IrisStyle.accent : IrisStyle.textTertiary
            }
            HoverHandler { id: resizeHover; cursorShape: root.vertical ? Qt.SizeHorCursor : Qt.SizeVerCursor }
            DragHandler {
                id: resizeDrag
                target: null
                xAxis.enabled: root.vertical
                yAxis.enabled: !root.vertical
                property real startHeight: 42
                property IrisConfigDrag write: IrisConfigDrag { path: "iris.bar.height" }
                onActiveChanged: {
                    if (active) resizeDrag.startHeight = Number(Config.options?.iris?.bar?.height ?? 42)
                    else resizeDrag.write.flush()
                }
                onTranslationChanged: {
                    if (!active) return
                    const outward = root.vertical ? (root.rightEdge ? -translation.x : translation.x)
                        : (root.bottomEdge ? -translation.y : translation.y)
                    const delta = outward / Math.max(0.01, root.d)
                    resizeDrag.write.push(Math.round(Math.max(32, Math.min(64, resizeDrag.startHeight + delta))))
                }
            }
        }

        Item {
            id: compactLayer
            x: root.vertical ? (root.rightEdge ? chassis.width - chassis.rightInset - width : chassis.leftInset) : 0
            y: root.vertical ? Math.round((chassis.height - height) / 2)
                : root.bottomEdge ? chassis.height - chassis.bottomInset - height : chassis.topInset
            width: root.vertical ? root.compactHeight : chassis.width
            height: root.vertical ? Math.round(chassis.restW) : root.compactHeight
            readonly property real fall: Math.min(1, chassis.presentation / Math.max(0.02, IrisStyle.contentFall))
            opacity: root.paintNudge * Math.max(0, 1 - compactLayer.fall) * IrisStyle.recompose * (1 - root.spotlightYield)
            transform: Scale {
                origin.x: compactLayer.width / 2
                origin.y: compactLayer.height / 2
                xScale: IrisStyle.revealFades ? 1 : (1 - 0.1 * compactLayer.fall) * (0.96 + 0.04 * IrisStyle.recompose)
                yScale: IrisStyle.revealFades ? 1 : (1 - 0.1 * compactLayer.fall) * (0.96 + 0.04 * IrisStyle.recompose)
            }
            // Never transform the ClippingRectangle live: it can stop painting.
            scale: compactPress.pressed && !root.zoned ? IrisStyle.pressScale(0.93) : 1
            Behavior on scale { NumberAnimation { duration: IrisStyle.duration(compactPress.pressed ? 80 : 200); easing.type: IrisStyle.feedbackEasing } }
            // Kept in the scene across a morph: its rows carry the clock, glyphs and
            // figures, and rebuilding their nodes as the shape came back cost one
            // 95 ms frame near the end of every close.
            visible: opacity > 0 || root.expanded || chassis.presentation > 0.002

            component CompactRow: RowLayout {
                id: compactRow
                property string mode: ""
                property real lead: 0
                readonly property bool current: root.compactMode === compactRow.mode
                property real laidWidth: 0
                // Laid at the width of its own size class: relaying the row out per
                // frame so it rides the shape measured 2.4x the cost of every morph.
                Binding on laidWidth { when: compactRow.current; value: root.zoned ? root.heartTarget : root.compactTargetWidth; restoreMode: Binding.RestoreNone }
                readonly property real leadMargin: compactRow.lead > 0
                    ? Math.round((root.compactHeight - compactRow.lead) / 2) : 14 * root.d
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                x: (root.zoned ? Math.round(barZones.heartAlong + (root.heartLength - compactRow.laidWidth) / 2)
                    : Math.round((parent.width - compactRow.laidWidth) / 2)) + compactRow.leadMargin
                    + (root.piecesAtStart ? root.barPieceReserve : 0)
                width: Math.max(0, compactRow.laidWidth - compactRow.leadMargin - 15 * root.d - root.barPieceReserve)
                spacing: 9 * root.d
                opacity: (root.compactMode === compactRow.mode && root.heartShown && !root.vertical ? 1 : 0) * root.heartUncovered
                scale: root.zoned && compactPress.pressed ? IrisStyle.pressScale(0.93) : 1
                Behavior on scale { NumberAnimation { duration: IrisStyle.duration(compactPress.pressed ? 80 : 200); easing.type: IrisStyle.feedbackEasing } }
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
            }

            CompactRow {
                id: idleRow
                mode: "idle"
                Glyph {
                    visible: root.clockStyle === "weather"
                    text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                    iconSize: 16 * root.d
                    color: IrisStyle.subtext
                }
                IrisText {
                    visible: root.clockStyle === "weather"
                    text: String(Weather.data?.temp ?? "").replace(/[CF]$/, "")
                    role: IrisText.Meta
                    font.pixelSize: IrisStyle.typeMeta
                    font.weight: IrisStyle.weight(Font.Medium)
                }
                DateMark {
                    visible: root.clockStyle === "dateTime"
                    Layout.alignment: Qt.AlignVCenter
                    pixelSize: 12 * IrisStyle.typeScale * root.clockScale
                    dayColor: root.clockAccent
                }
                Item { Layout.fillWidth: true }
                IrisClock {
                    id: idleClock
                    Layout.alignment: Qt.AlignVCenter
                    pixelSize: 15 * IrisStyle.typeScale * root.clockScale
                    separatorColor: root.clockAccent
                    opacity: clockFlight.hides(idleClock) ? 0 : 1
                }
            }

            CompactRow {
                id: mediaRow
                mode: "media"
                lead: (root.zoned ? 28 : 24) * root.d
                IrisArtwork {
                    id: compactCover
                    opacity: coverFlight.hides(compactCover) ? 0 : 1
                    Layout.preferredWidth: (root.zoned ? 28 : 24) * root.d
                    Layout.preferredHeight: (root.zoned ? 28 : 24) * root.d
                    source: MediaArtwork.displaySource
                    circular: Config.options?.iris?.player?.roundCover ?? false
                    radius: circular ? width / 2 : 6 * root.d
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: (root.zoned ? 1.5 : 3) * root.d
                    IrisText {
                        Layout.fillWidth: true
                        text: root.title
                        font.pixelSize: (root.zoned ? 14 : 13) * IrisStyle.typeScale
                        font.weight: IrisStyle.weight(Font.DemiBold)
                        elide: Text.ElideRight
                    }
                    IrisText {
                        Layout.fillWidth: true
                        visible: root.zoned && text.length > 0
                        text: root.ytMusic ? YtMusic.currentArtist : String(root.player?.trackArtist ?? "")
                        color: IrisStyle.subtext
                        font.pixelSize: IrisStyle.typeFootnote
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        visible: root.effectiveLength > 0
                        implicitHeight: (root.zoned ? 3 : 2.5) * root.d
                        radius: height / 2
                        color: IrisStyle.fillHover
                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            color: root.artTint
                            width: parent.width * root.trackProgress
                        }
                    }
                }
                Tabular {
                    text: DateTime.timeDisplay
                    color: IrisStyle.subtext
                    font.pixelSize: (root.zoned ? 13 : 12) * IrisStyle.typeScale
                    font.weight: IrisStyle.weight(Font.Medium)
                }
                Waveform {
                    running: root.playing && root.compactMode === "media" && !root.visualExpanded
                    tint: root.artTint
                    barHeight: (root.zoned ? 18 : 15) * root.d
                }
            }

            CompactRow {
                id: recordRow
                mode: "record"
                RecordDot { Layout.alignment: Qt.AlignVCenter }
                IrisText {
                    Layout.fillWidth: true
                    text: Translation.tr("Recording")
                    font.pixelSize: IrisStyle.typeLabel
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    elide: Text.ElideRight
                }
                IrisNumber {
                    text: root.clockText(RecorderStatus.elapsedSeconds)
                    color: IrisStyle.danger
                    pixelSize: IrisStyle.typeLabel
                    weight: Font.DemiBold
                }
            }

            CompactRow {
                id: timerRow
                mode: "timer"
                Glyph {
                    text: root.timerPaused ? "pause" : root.timerGlyph
                    iconSize: 17 * root.d
                    color: IrisStyle.secondaryAccent
                }
                IrisText {
                    Layout.fillWidth: true
                    text: root.timerLabel
                    font.pixelSize: IrisStyle.typeMeta
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    elide: Text.ElideRight
                }
                IrisNumber {
                    text: root.clockText(root.timerSeconds)
                    countDown: root.timerKind !== "stopwatch"
                    color: root.timerPaused ? IrisStyle.subtext : IrisStyle.secondaryAccent
                    pixelSize: IrisStyle.typeLabel
                    weight: Font.DemiBold
                }
            }

            CompactRow {
                id: taskRow
                mode: "task"
                Glyph {
                    text: String(root.task?.glyph ?? "bolt")
                    iconSize: 17 * root.d
                    color: root.taskTint
                }
                IrisText {
                    Layout.fillWidth: true
                    Layout.maximumWidth: Math.round(190 * root.d)
                    text: String(root.task?.title ?? "")
                    font.pixelSize: IrisStyle.typeMeta
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    elide: Text.ElideRight
                }
                IrisNumber {
                    visible: Number(root.task?.progress ?? -1) >= 0
                    text: Math.round(Number(root.task?.progress ?? 0) * 100) + "%"
                    color: root.taskTint
                    pixelSize: IrisStyle.typeLabel
                    weight: Font.DemiBold
                }
                RecordDot {
                    visible: Number(root.task?.progress ?? -1) < 0
                    Layout.alignment: Qt.AlignVCenter
                    color: root.taskTint
                }
            }

            CompactRow {
                id: clockRow
                mode: "clock"
                Item { Layout.fillWidth: true }
                DateMark {
                    visible: root.clockStyle === "dateTime"
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 2 * root.d
                    pixelSize: 12 * IrisStyle.typeScale * root.clockScale
                    dayColor: root.clockAccent
                }
                Glyph {
                    visible: root.clockStyle === "weather"
                    text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                    iconSize: 16 * root.d
                    color: IrisStyle.subtext
                }
                Tabular {
                    visible: root.clockStyle === "weather"
                    text: String(Weather.data?.temp ?? "").replace(/[CF]$/, "")
                    color: IrisStyle.subtext
                    font.pixelSize: IrisStyle.typeMeta
                    font.weight: IrisStyle.weight(Font.Medium)
                }
                IrisClock {
                    id: clusterClock
                    Layout.alignment: Qt.AlignVCenter
                    pixelSize: 15 * IrisStyle.typeScale * root.clockScale
                    separatorColor: root.clockAccent
                    opacity: clockFlight.hides(clusterClock) ? 0 : 1
                }
                Item { Layout.fillWidth: true }
            }

            CompactRow {
                id: editRow
                mode: "edit"
                anchors.rightMargin: 5 * root.d
                Rectangle {
                    Layout.preferredWidth: Math.round(26 * root.d)
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    color: IrisStyle.tintFill(IrisStyle.accent)
                    Glyph {
                        anchors.centerIn: parent
                        text: "edit"
                        iconSize: 15 * root.d
                        color: IrisStyle.accent
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -1 * root.d
                    IrisText {
                        Layout.fillWidth: true
                        text: Translation.tr("Editing desktop")
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.DemiBold)
                        elide: Text.ElideRight
                    }
                    IrisText {
                        Layout.fillWidth: true
                        text: Translation.tr("Drag widgets to arrange")
                        color: IrisStyle.muted
                        font.pixelSize: IrisStyle.typeFootnote
                        elide: Text.ElideRight
                    }
                }
                Rectangle {
                    Layout.preferredHeight: root.compactHeight - Math.round(10 * root.d)
                    Layout.preferredWidth: doneLabel.implicitWidth + Math.round(24 * root.d)
                    radius: height / 2
                    color: compactPress.containsMouse ? Qt.lighter(IrisStyle.accent, 1.08) : IrisStyle.accent
                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                    IrisText {
                        id: doneLabel
                        anchors.centerIn: parent
                        text: Translation.tr("Done")
                        color: IrisStyle.onAccent
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.Bold)
                    }
                }
            }

            CompactRow {
                id: eventRow
                mode: "event"
                anchors.leftMargin: 6 * root.d
                Rectangle {
                    Layout.preferredWidth: root.compactHeight - Math.round(12 * root.d)
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    color: IrisStyle.tintFill(root.event.tint)
                    Glyph {
                        anchors.centerIn: parent
                        text: root.event.icon
                        iconSize: 16 * root.d
                        color: root.event.tint
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -1 * root.d
                    IrisText {
                        Layout.fillWidth: true
                        text: root.event.title
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.DemiBold)
                        elide: Text.ElideRight
                    }
                    IrisText {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: root.event.detail
                        color: IrisStyle.muted
                        font.pixelSize: IrisStyle.typeFootnote
                        elide: Text.ElideRight
                    }
                }
                Metric {
                    visible: root.event.value >= 0
                    Layout.alignment: Qt.AlignVCenter
                    value: Math.round(root.event.value * 100)
                    unit: "%"
                    pixelSize: IrisStyle.typeBody
                    weight: Font.Bold
                    color: root.event.tint
                }
                ProgressRing {
                    visible: root.event.value >= 0
                    Layout.preferredWidth: Math.round(20 * root.d)
                    Layout.preferredHeight: Layout.preferredWidth
                    progress: Math.max(0, root.event.value)
                    tint: root.event.tint
                }
            }

            CompactRow {
                id: feedbackRow
                mode: "feedback"
                LevelFace {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    glyph: root.feedbackIcon
                    value: root.feedbackValue
                    muted: root.feedbackMuted
                    style: root.levelStyle
                    showValue: root.levelFigure
                }
            }

            Grid {
                id: barPieceRow
                z: 1
                columns: root.vertical ? 1 : Math.max(1, root.barPieces.length)
                x: root.vertical ? Math.round((parent.width - width) / 2)
                    : root.piecesAtStart ? Math.round(12 * root.d) : parent.width - width - Math.round(12 * root.d)
                y: !root.vertical ? Math.round((parent.height - height) / 2)
                    : root.piecesAtStart ? Math.round(12 * root.d) : parent.height - height - Math.round(12 * root.d)
                spacing: root.barPieceGap
                visible: root.barPieces.length > 0 && !root.inlineExpanded && !root.zoned
                Repeater {
                    model: root.barPieces
                    delegate: Item {
                        id: barPiece
                        required property string modelData
                        readonly property bool strip: barPiece.modelData === "tray" && root.trayAppsFace
                        width: barPiece.strip && !root.vertical ? traySlot.width : root.barPieceSize
                        height: barPiece.strip && root.vertical ? traySlot.height : root.barPieceSize
                        readonly property bool lifted: root.draggedSlot === "extra-" + barPiece.modelData
                        opacity: barPiece.lifted ? 0 : 1
                        IrisTrayStrip {
                            id: traySlot
                            visible: barPiece.strip
                            cellSize: root.barPieceSize
                            spacing: root.trayStripGap
                            vertical: root.vertical
                            screenName: root.targetScreen?.name ?? ""
                            screenOffsetY: root.screenOffsetY
                            menuToward: root.trayMenuToward
                            draggable: true
                            onCellHover: on => root.hoveredPieces += on ? 1 : -1
                        }
                        IrisBubbleFace {
                            visible: !barPiece.strip
                            anchors.fill: parent
                            screenName: root.targetScreen?.name ?? ""
                            kind: barPiece.modelData
                            plated: true
                            hovered: pieceHover.hovered
                            pressed: pieceGrip.pressed
                        }
                        HoverHandler {
                            id: pieceHover
                            enabled: !barPiece.strip
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: root.hoveredPieces += pieceHover.hovered ? 1 : -1
                        }
                        Component.onDestruction: if (pieceHover.hovered) root.hoveredPieces -= 1
                        IrisBubbleGrip {
                            id: pieceGrip
                            anchors.fill: parent
                            visible: !barPiece.strip
                            slot: "extra-" + barPiece.modelData
                            kind: barPiece.modelData
                            screenName: root.targetScreen?.name ?? ""
                            screenOffsetY: root.screenOffsetY
                            holdLifts: !GlobalStates.irisEdit
                            pullDistance: GlobalStates.irisEdit ? 6 * root.d : 0
                            onTapped: {
                                if (GlobalStates.irisEdit) {
                                    GlobalStates.irisEditSelection = ""
                                    GlobalStates.irisEditTarget = "pieces"
                                    return
                                }
                                root.activatePiece(barPiece.modelData, barPiece)
                            }
                        }
                        WheelHandler {
                            enabled: barPiece.modelData === "sound" || barPiece.modelData === "mic"
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => {
                                const steps = root.wheelSteps(event)
                                if (steps === 0) return
                                GlobalStates.quietIrisLevels()
                                root.stepLevel(barPiece.modelData === "mic" ? "mic" : "volume", steps)
                            }
                        }
                    }
                }
            }

            IslandCompactColumn {
                id: compactColumn
                opacity: root.heartUncovered
                visible: root.vertical && root.heartShown
                island: root
                mode: root.compactMode
                thickness: root.compactHeight
                clockScale: root.clockScale
                clockAccent: root.clockAccent
                clockStyle: root.clockStyle
                x: root.zoned && root.notch ? (root.rightEdge ? -root.heartSwell / 2 : root.heartSwell / 2) : 0
                width: parent.width
                height: root.zoned ? Math.round(root.heartLength) : parent.height - root.barPieceReserve
                y: root.zoned ? Math.round(barZones.heartAlong) : root.piecesAtStart ? root.barPieceReserve : 0
            }

            IslandBarZones {
                id: barZones
                anchors.fill: parent
                visible: root.zoned
                vertical: root.vertical
                island: root
                thickness: root.stripHeight
                // A clear strip has no body of its own: its items share the notch's line, as a status bar shares the island's.
                laneTop: root.menubar && root.bottomEdge && !root.clearStrip ? root.compactHeight - root.stripHeight : 0
                lane: root.clearStrip ? root.compactHeight : root.stripHeight
                clear: root.clearStrip
                bottomEdge: root.bottomEdge
                heartLength: root.heartLength
                start: root.zoned ? Array.from(IrisStyle.structuralValue("bar.fullStart", ["workspaces", "window"])).concat(root.absorbedStart.length > 0 ? ["|"] : [], root.absorbedStart) : []
                center: root.zoned ? IrisStyle.structuralValue("bar.fullCenter", ["island"]) : []
                end: root.zoned ? Array.from(IrisStyle.structuralValue("bar.fullEnd", ["tray", "notifications", "sound", "controls"]))
                    .concat(Array.from(IrisStyle.structuralValue("bar.pieces", [])).map(String).filter(kind => kind !== "media"))
                    .concat(root.absorbedPieces.some(kind => !root.absorbedStart.includes(kind)) ? ["|"] : [],
                        root.absorbedPieces.filter(kind => !root.absorbedStart.includes(kind))) : []
                absorbed: root.absorbedPieces
                screenName: root.targetScreen?.name ?? ""
                clockStyle: root.clockStyle
                clockScale: root.clockScale
                clockAccent: root.clockAccent
            }

            MouseArea {
                id: compactPress
                x: root.zoned && !root.vertical ? Math.round(barZones.heartAlong) : 0
                y: root.zoned && root.vertical ? Math.round(barZones.heartAlong) : 0
                width: root.zoned && !root.vertical ? Math.round(root.heartLength) : parent.width
                height: root.zoned && root.vertical ? Math.round(root.heartLength) : parent.height
                enabled: !root.inlineExpanded && (!root.zoned || root.heartShown)
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                hoverEnabled: root.compactMode === "edit"
                cursorShape: islandGrip.carrying ? Qt.ClosedHandCursor
                    : GlobalStates.irisEdit ? Qt.OpenHandCursor : Qt.PointingHandCursor
                preventStealing: true
                Accessible.role: Accessible.Button
                Accessible.name: GlobalStates.irisEdit ? Translation.tr("Edit Dynamic Island")
                    : root.expanded ? Translation.tr("Collapse island") : Translation.tr("Expand island")
                pressAndHoldInterval: 380
                QtObject {
                    id: islandGrip
                    property bool carrying: false
                    property bool endedEdit: false
                    property point pressAt: Qt.point(0, 0)
                    function publish(mouse, released: bool): void {
                        const p = compactPress.mapToItem(null, mouse.x, mouse.y)
                        GlobalStates.irisBubbleDrag = {
                            slot: "island", kind: "island", screen: root.targetScreen?.name ?? "",
                            x: p.x, y: p.y + root.screenOffsetY,
                            size: root.compactHeight, width: chassis.width, released: released
                        }
                    }
                }
                onPressed: mouse => { islandGrip.pressAt = Qt.point(mouse.x, mouse.y); islandGrip.endedEdit = false }
                onPressAndHold: mouse => {
                    if (mouse.button !== Qt.LeftButton || root.compactMode === "edit") return
                    islandGrip.carrying = true
                    islandGrip.publish(mouse, false)
                }
                onPositionChanged: mouse => {
                    if (!islandGrip.carrying && GlobalStates.irisEdit && (mouse.buttons & Qt.LeftButton)
                            && Math.hypot(mouse.x - islandGrip.pressAt.x, mouse.y - islandGrip.pressAt.y) > 6 * root.d) {
                        islandGrip.carrying = true
                    }
                    if (islandGrip.carrying) islandGrip.publish(mouse, false)
                }
                onReleased: mouse => {
                    // A hold past pressAndHoldInterval swallows onClicked; the edit row's Done ends on
                    // release so a slow press still leaves arranging.
                    if (!islandGrip.carrying && root.compactMode === "edit" && mouse.button === Qt.LeftButton
                            && compactPress.containsMouse) {
                        islandGrip.endedEdit = true
                        GlobalStates.setWidgetEditMode(false)
                        return
                    }
                    if (!islandGrip.carrying) return
                    islandGrip.publish(mouse, true)
                    Qt.callLater(() => islandGrip.carrying = false)
                }
                onCanceled: {
                    if (islandGrip.carrying && GlobalStates.irisBubbleDrag) {
                        GlobalStates.irisBubbleDrag = Object.assign({}, GlobalStates.irisBubbleDrag, { released: true })
                    }
                    islandGrip.carrying = false
                }
                onClicked: mouse => {
                    if (islandGrip.endedEdit) { islandGrip.endedEdit = false; return }
                    if (islandGrip.carrying) return
                    if (mouse.button === Qt.MiddleButton) {
                        if (root.hasMedia) MprisController.togglePlaying()
                        return
                    }
                    if (GlobalStates.irisEdit) {
                        GlobalStates.irisEditSelection = ""
                        GlobalStates.irisEditTarget = "island"
                        return
                    }
                    if (root.compactMode === "edit") { GlobalStates.setWidgetEditMode(false); return }
                    if (root.pinned) root.expanded = false
                    else {
                        const at = compactPress.mapToItem(root, mouse.x, mouse.y)
                        root.pageOriginX = at.x
                        root.pageOriginY = at.y
                        root.openPage(IrisStyle.cluster ? "desktop" : root.pageFor(root.primary), true, null)
                    }
                }
            }
        }

    }

    ClippingRectangle {
        id: extension
        readonly property real targetWidth: root.extensionRole === "page" ? root.expandedWidth
            : Math.round(320 * root.d)
        readonly property real targetHeight: root.extensionRole === "page"
            ? (details.item?.implicitHeight ?? 0) + root.padding * 2
            : root.compactHeight
        readonly property real targetRadius: root.extensionRole === "page"
            ? Math.max(IrisStyle.radius, 30 * root.d) : root.compactHeight / 2
        readonly property alias presentation: extensionSpring.value
        IrisSpring { id: extensionSpring; surface: "island"; to: root.extensionOpen ? 1 : 0; minimum: 0 }
        readonly property real reach: Math.round((root.vertical ? extension.targetWidth : extension.targetHeight) * extension.presentation)
        readonly property real liveWidth: Math.round(root.originWidth
            + ((root.vertical ? extension.targetHeight : extension.targetWidth) - root.originWidth) * extension.presentation)
        x: !extension.anchoredShape ? chassis.x
            : root.grownPage && root.vertical ? (root.rightEdge ? root.width - extension.reach : -root.grownInset)
            : root.vertical ? (root.rightEdge ? chassis.x - extension.reach : chassis.x + chassis.width)
            : root.extensionX(root.originWidth) + (root.extensionX(extension.targetWidth)
                - root.extensionX(root.originWidth)) * extension.presentation
        y: !extension.anchoredShape ? chassis.y
            : root.vertical ? root.extensionY(root.originWidth) + (root.extensionY(extension.targetHeight)
                - root.extensionY(root.originWidth)) * extension.presentation
            : root.zoned && !root.vertical && !root.fromHeart
                ? (root.bottomEdge ? root.height - root.stripHeight - root.floatGap - extension.reach : root.stripHeight + root.floatGap)
            : root.grownPage ? (root.bottomEdge ? root.height - extension.reach : -root.grownInset)
            : root.bottomEdge ? root.height - chassis.bodyHeight - extension.reach : chassis.bodyHeight
        width: !extension.anchoredShape ? chassis.width : root.vertical ? extension.reach + root.grownInset : extension.liveWidth
        height: !extension.anchoredShape ? chassis.height : root.vertical ? extension.liveWidth : extension.reach + root.grownInset
        radius: extension.anchoredShape
            ? root.originWidth / 2 + (extension.targetRadius - root.originWidth / 2) * extension.presentation
            : chassis.radius
        color: IrisStyle.bodyClip
        readonly property bool anchoredShape: root.anchored && !(root.inlinePages && root.extensionRole === "page")
        HoverHandler { id: extensionHover }
        WheelHandler {
            enabled: root.expanded
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => root.wheelPages(event, false)
        }
        PointHandler {
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onActiveChanged: if (active && root.expanded) root.pinned = true
        }
        visible: extension.anchoredShape ? extension.presentation > 0
            : (details.opacity > 0 || artBackdrop.opacity > 0)

        Loader {
            id: artBackdrop
            anchors.fill: parent
            property real shown: root.effectivePage === "media" ? 1 : 0
            Behavior on shown {
                enabled: root.visualExpanded && details.opacity >= 1
                NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve }
            }
            active: details.active && (root.effectivePage === "media" || artBackdrop.shown > 0)
                && (Config.options?.iris?.player?.artworkBackground ?? true) && !IrisStyle.glassy
                && MediaArtwork.displaySource.length > 0
            opacity: details.opacity * artBackdrop.shown
            layer.enabled: true
            sourceComponent: IrisMediaBackdrop {
                source: MediaArtwork.displaySource
                edgeTop: !root.anchored && chassis.topInset > 0 ? (chassis.topInset + root.fillet + 4 * root.d) / 0.45 : 0
                edgeBottom: !root.anchored && chassis.bottomInset > 0 ? (chassis.bottomInset + root.fillet + 4 * root.d) / 0.45 : 0
            }
        }
        Loader {
            id: details
            // Upright, the page is revealed from its middle as the body grows along the edge.
            y: extension.anchoredShape ? root.padding + (root.vertical || root.bottomEdge ? 0 : root.grownInset)
                : root.vertical ? root.padding - Math.round((chassis.openH - chassis.height) / 2)
                : root.padding + chassis.topInset - (root.bottomEdge ? 0 : Math.round(Math.max(0, chassis.openH - chassis.bodyHeight)))
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: root.vertical && !extension.anchoredShape ? (chassis.leftInset - chassis.rightInset) / 2
                : root.vertical && root.grownPage ? (root.rightEdge ? -root.grownInset / 2 : root.grownInset / 2) : 0
            width: Math.max(0, root.expandedWidth - root.padding * 2)
            // Incubated: the chassis spring still waits for Loader.Ready, so nothing moves before the page exists.
            active: root.expanded || details.opacity > 0.004 || details.warm
            asynchronous: true
            property bool warm: false
            Timer { id: pageWarmth; interval: 20000; onTriggered: details.warm = false }
            Connections {
                target: root
                function onPointerOnIslandChanged(): void {
                    if (!root.pointerOnIsland) return
                    details.warm = true
                    pageWarmth.stop()
                }
                function onExpandedChanged(): void {
                    if (root.expanded) { details.warm = true; pageWarmth.stop() }
                    else pageWarmth.restart()
                }
            }
            onActiveChanged: { if (!active) root.page = "" }
            readonly property real presentation: extension.anchoredShape ? extension.presentation : chassis.presentation
            opacity: (root.anchored && root.extensionRole !== "page" ? 0 : 1) * IrisStyle.recompose * (IrisStyle.revealDrops
                ? IrisStyle.ramp(details.presentation, IrisStyle.dropRise, IrisStyle.dropSpan)
                : IrisStyle.contentAt(details.presentation))
            scale: IrisStyle.revealInflates
                ? Math.max(0.35, Math.min(1, (extension.anchoredShape ? extension.height : root.vertical ? chassis.height : chassis.bodyHeight)
                    / Math.max(1, extension.anchoredShape ? extension.targetHeight : chassis.openH)))
                : IrisStyle.revealFades ? 1 : 0.96 + 0.04 * details.opacity
            transformOrigin: root.bottomEdge ? Item.Bottom : Item.Top
            // Kept in the scene while warm: hiding it drops its render nodes, and
            // the first frame of the next open pays for building them all again.
            visible: opacity > 0 || details.warm
            enabled: root.expanded

            sourceComponent: GridLayout {
                id: expandedContent
                columns: 1
                rowSpacing: 14 * root.d

                component Page: ColumnLayout {
                    id: pageItem
                    property string name: ""
                    property bool bleeds: false
                    readonly property bool current: root.effectivePage === pageItem.name
                    readonly property bool resident: pageItem.current || pageItem.opacity > 0.004
                        || root.pageIntent === pageItem.name
                    readonly property bool switching: root.visualExpanded && details.opacity >= 1
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    opacity: pageItem.current ? 1 : 0
                    scale: pageItem.current || pageItem.bleeds ? 1 : 0.97
                    transformOrigin: root.bottomEdge ? Item.Bottom : Item.Top
                    visible: opacity > 0
                    enabled: pageItem.current
                    Behavior on opacity {
                        id: pageFade
                        enabled: pageItem.switching
                        SequentialAnimation {
                            PauseAnimation { duration: pageFade.targetValue > 0 ? IrisStyle.duration(50) : 0 }
                            NumberAnimation {
                                duration: IrisStyle.duration(pageFade.targetValue > 0 ? 170 : 80)
                                easing.type: IrisStyle.feedbackEasing
                            }
                        }
                    }
                    Behavior on scale {
                        enabled: pageItem.switching
                        NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
                    }
                }

                Item {
                    id: pageStack
                    Layout.row: root.bottomEdge ? 0 : 1
                    Layout.fillWidth: true
                    implicitHeight: root.effectivePage === "controls" ? controlsPage.implicitHeight
                        : root.effectivePage === "media" ? mediaPage.implicitHeight
                        : root.effectivePage === "activity" ? activityPage.implicitHeight
                        : root.effectivePage === "tray" ? trayPage.implicitHeight
                        : root.effectivePage === "tools" ? toolsPage.implicitHeight
                        : desktopPage.implicitHeight

                    Page {
                        id: trayPage
                        name: "tray"
                        Loader {
                            id: trayLoader
                            Layout.fillWidth: true
                            Layout.preferredHeight: item?.implicitHeight ?? 0
                            active: trayPage.resident
                            asynchronous: !trayPage.current
                            sourceComponent: Flickable {
                                id: trayView
                                width: trayLoader.width
                                implicitHeight: Math.min(300 * root.d, trayContent.implicitHeight)
                                contentHeight: trayContent.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                IrisTray { id: trayContent; width: parent.width; bottomEdge: root.bottomEdge; items: root.trayItems }
                            }
                        }
                    }
                    Page {
                        id: controlsPage
                        name: "controls"
                        Loader {
                            id: controlsLoader
                            Layout.fillWidth: true
                            Layout.preferredHeight: item?.implicitHeight ?? 0
                            active: controlsPage.resident
                            asynchronous: !controlsPage.current
                            visible: active
                            sourceComponent: IrisQuickPanel { width: controlsLoader.width; targetScreen: root.targetScreen }
                        }
                    }
                    Page {
                        id: toolsPage
                        name: "tools"
                        Loader {
                            id: toolsLoader
                            Layout.fillWidth: true
                            Layout.preferredHeight: item?.implicitHeight ?? 0
                            active: toolsPage.resident
                            asynchronous: !toolsPage.current
                            sourceComponent: IrisTools {
                                width: toolsLoader.width
                                onActivityRequested: root.page = "activity"
                            }
                        }
                    }

                    Page {
                        id: mediaPage
                        name: "media"
                        spacing: 14 * root.d
                        Loader {
                            id: mediaLoader
                            Layout.fillWidth: true
                            Layout.preferredHeight: item?.implicitHeight ?? 0
                            active: mediaPage.resident
                            asynchronous: !mediaPage.current
                            sourceComponent: IslandMediaPage { width: mediaLoader.width; island: root }
                        }
                    }

                    Page {
                        id: activityPage
                        name: "activity"
                        spacing: 12 * root.d
                        Loader {
                            id: activityLoader
                            Layout.fillWidth: true
                            Layout.preferredHeight: item?.implicitHeight ?? 0
                            active: activityPage.resident
                            asynchronous: !activityPage.current
                            sourceComponent: IslandActivityPage { width: activityLoader.width; island: root }
                        }
                    }

                    Page {
                        id: desktopPage
                        name: "desktop"
                        bleeds: desktopLoader.item?.showBanner ?? false
                        spacing: 14 * root.d
                        Loader {
                            id: desktopLoader
                            Layout.fillWidth: true
                            Layout.preferredHeight: item?.implicitHeight ?? 0
                            active: desktopPage.resident
                            asynchronous: !desktopPage.current
                            sourceComponent: IslandDesktopPage {
                                width: desktopLoader.width
                                island: root
                                navOffset: navRow.height + expandedContent.rowSpacing
                            }
                        }
                    }
                }

                RowLayout {
                    id: navRow
                    Layout.row: root.bottomEdge ? 1 : 0
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4 * root.d

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => root.wheelPages(event, true)
                    }

                    Repeater {
                        model: root.navEntries
                        delegate: Item {
                            id: navSlot
                            required property var modelData
                            implicitWidth: navSlot.modelData.kind === "|" ? Math.round(9 * root.d) : navButton.implicitWidth
                            implicitHeight: navButton.implicitHeight
                            Rectangle {
                                visible: navSlot.modelData.kind === "|"
                                anchors.centerIn: parent
                                width: 1
                                height: Math.round(14 * root.d)
                                color: IrisStyle.fill
                            }
                            IrisButton {
                                id: navButton
                                visible: navSlot.modelData.kind !== "|"
                                readonly property string target: navSlot.modelData.page ?? ""
                                selected: navButton.target.length > 0 && root.effectivePage === navButton.target
                                quiet: !navButton.selected
                                implicitWidth: Math.round(36 * root.d)
                                implicitHeight: Math.round(30 * root.d)
                                buttonRadius: height / 2
                                buttonRadiusPressed: height / 2
                                colBackgroundHover: IrisStyle.fillHover
                                Accessible.name: Translation.tr(navSlot.modelData.label ?? "")
                                onHoveredChanged: {
                                    if (navButton.target.length > 0) {
                                        if (navButton.hovered) {
                                            pageIntentExpiry.stop()
                                            root.pageIntent = navButton.target
                                        } else if (root.pageIntent === navButton.target) {
                                            pageIntentExpiry.restart()
                                        }
                                    }
                                    if (navSlot.modelData.kind === "settings" && root.focusedOutput)
                                        root.settingsIntent = navButton.hovered
                                }
                                onClicked: root.activateNav(navSlot.modelData.kind)
                                Glyph {
                                    anchors.centerIn: parent
                                    text: navSlot.modelData.glyph ?? ""
                                    fill: navButton.selected ? 1 : 0
                                    iconSize: 18 * root.d
                                    color: navButton.selected ? IrisStyle.accent
                                        : navButton.hovered ? IrisStyle.text : IrisStyle.textSecondary
                                }
                            }
                        }
                    }
                }
            }
        }
        RowLayout {
            id: hudRow
            anchors.fill: parent
            anchors.leftMargin: 16 * root.d
            anchors.rightMargin: 17 * root.d
            spacing: 11 * root.d
            opacity: extension.anchoredShape && root.extensionRole === "feedback" && root.extensionOpen ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }

            LevelFace {
                Layout.fillWidth: true
                Layout.fillHeight: true
                glyph: root.feedbackIcon
                value: root.feedbackValue
                muted: root.feedbackMuted
                style: root.levelStyle
                showValue: root.levelFigure
                barFill: IrisStyle.text
            }
        }
        RowLayout {
            id: hudEventRow
            anchors.fill: parent
            anchors.leftMargin: 6 * root.d
            anchors.rightMargin: 14 * root.d
            spacing: 9 * root.d
            opacity: extension.anchoredShape && root.extensionRole === "event" && root.extensionOpen ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
            Rectangle {
                Layout.preferredWidth: root.compactHeight - Math.round(12 * root.d)
                Layout.preferredHeight: Layout.preferredWidth
                radius: width / 2
                color: IrisStyle.tintFill(root.event.tint)
                Glyph {
                    anchors.centerIn: parent
                    text: root.event.icon
                    iconSize: 16 * root.d
                    color: root.event.tint
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: -1 * root.d
                IrisText {
                    Layout.fillWidth: true
                    text: root.event.title
                    font.pixelSize: IrisStyle.typeLabel
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    elide: Text.ElideRight
                }
                IrisText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.event.detail
                    color: IrisStyle.muted
                    font.pixelSize: IrisStyle.typeFootnote
                    elide: Text.ElideRight
                }
            }
            Metric {
                visible: root.event.value >= 0
                Layout.alignment: Qt.AlignVCenter
                value: Math.round(root.event.value * 100)
                unit: "%"
                pixelSize: IrisStyle.typeBody
                weight: Font.Bold
                color: root.event.tint
            }
        }
    }
}
