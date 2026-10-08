pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.iris.frame

QtObject {
    id: root

    readonly property var zones: ["top-left", "top-right", "left", "right", "bottom-left", "bottom-right"]
    function zoneChoices(withIsland: bool): var {
        const labels = { "top-left": "Top left", "top-right": "Top right", "left": "Left",
            "right": "Right", "bottom-left": "Bottom left", "bottom-right": "Bottom right" }
        const choices = withIsland ? [{ label: "Island", value: "island" }] : []
        for (const zone of root.zones) choices.push({ label: labels[zone], value: zone })
        choices.push({ label: "Free", value: "free" })
        return choices
    }

    readonly property var slots: [
        { id: "left", label: "Activity bubble", description: "Media, a timer or a recording beside the clock (Cluster)." },
        { id: "right", label: "Trailing bubble", description: "Controls, notifications, weather or a level after the clock." },
        { id: "utility", label: "Utility bubble", description: "Tray, timers, sound or microphone at the end of the Island." }
    ]
    readonly property var extras: [
        { id: "weather", label: "Weather", description: "The sky now; its card holds the details.", card: true },
        { id: "notifications", label: "Notifications", description: "A count of unread notifications; its card lists them.", card: true },
        { id: "controls", label: "Controls", description: "Opens the Control Center out of the bubble.", card: false },
        { id: "sound", label: "Sound", description: "Output level as a ring; scroll to change it. Its card holds devices and apps.", card: true },
        { id: "mic", label: "Microphone", description: "Input level as a ring; scroll to change it. Its card holds the inputs.", card: true },
        { id: "tools", label: "Timers", description: "Countdown presets, Focus and the stopwatch.", card: true },
        { id: "media", label: "Now playing", description: "The cover while something plays; opens its card.", card: true },
        { id: "visualizer", label: "Visualizer", description: "What plays, drawn as it sounds: capsules, a rising equalizer, dots, a wave or a ring. Its look is in Now Playing; it opens the player's card.", card: true,
            keywords: ["visualizer", "visualiser", "cava", "spectrum", "equalizer", "ecualizador", "bars", "barras", "wave", "onda", "audio", "music", "musica"] },
        { id: "tray", label: "Tray", description: "The apps running in the tray, as their icons or a count.", card: true },
        { id: "calendar", label: "Calendar", description: "Today's weekday over the date; its card holds the month and what is coming up.", card: true },
        { id: "clock", label: "Clock", description: "An analog face; opens the Desktop page.", card: false },
        { id: "battery", label: "Battery", description: "Charge as a ring that turns orange and red as it runs low; a bolt while charging.", card: false },
        { id: "focus", label: "Do Not Disturb", description: "A moon that silences notifications with a tap.", card: false },
        { id: "network", label: "Network", description: "The link you are on as a signal arc; its card holds the networks.", card: true },
        { id: "bluetooth", label: "Bluetooth", description: "What is connected; its card holds the devices.", card: true },
        { id: "vitals", label: "Vitals", description: "The load as a ring; its card holds processor, memory, heat and disk.", card: true },
        { id: "workspaces", label: "Workspaces", description: "This output's workspaces; tap for Overview or a workspace card.", card: true },
        { id: "updates", label: "Updates", description: "How many packages are waiting; its card checks and opens them.", card: true },
        { id: "vpn", label: "VPN", description: "Whether you are on a VPN, as a shield that fills when you are. Its card lists your NetworkManager profiles and Tailscale, and turns any of them on or off.", card: true },
        { id: "shellUpdate", label: "New iNiR", description: "Shows up on its own when there is a new iNiR upstream, and goes away once you update. Its card says what changed and updates from there.", card: true },
        { id: "anime", label: "Airing", description: "The anime episode airing next, as its cover art and the time left. Its card lists what is coming and follows the shows you tap.", card: true,
            keywords: ["anime", "weeb", "otaku", "airing", "japanese", "japones", "tracker", "following", "siguiendo", "episodes", "episodios", "episodio", "schedule", "calendario", "ver", "ani-cli", "ani cli"] },
        { id: "watching", label: "Continue", description: "Watch anime without a terminal: search, pick an episode and pick up where you stopped. ani-cli finds it; iRiS plays it.", card: true,
            keywords: ["anime", "weeb", "otaku", "continue", "continuar", "resume", "reanudar", "watching", "viendo", "seguir viendo", "history", "historial", "episode", "episodio", "ani-cli", "ani cli", "jerry", "curd", "last watched", "ver", "watch anime", "mirar anime", "ver anime", "search", "buscar", "player", "reproductor", "mpv", "dub", "subtitles"] }
    ]
    readonly property var slotIds: root.slots.map(piece => piece.id)
    readonly property var extraIds: root.extras.map(piece => piece.id)
    readonly property var availableExtras: root.extraIds.filter(id => root.available(id))
    readonly property Binding frameFeed: Binding { target: IrisFrame; property: "availableExtras"; value: root.availableExtras }
    readonly property var cardIds: root.extras.filter(piece => piece.card).map(piece => piece.id)
    readonly property string defaultPlace: "right"
    function labelOf(id: string): string {
        return root.slots.concat(root.extras).find(piece => piece.id === id)?.label ?? id
    }

    readonly property bool hasPlayer: String(MprisController.titleOf(MprisController.activePlayer) ?? "").length > 0

    // The music app an empty player offers to open, so "nothing playing" has a next step: the one you use most, from
    // what stays on this machine. First the time each app has played (MPRIS, never a browser or a video player, kept
    // in music-listening.json), then how long each was in front (Screen Time, when it is on), then the players people
    // use most, in that order.
    readonly property var knownMusicApps: ["spotify", "com.github.th-ch.youtube-music", "tidal-hifi", "cider",
        "feishin", "io.bassi.Amberol", "org.gnome.Rhythmbox3", "org.kde.elisa", "org.strawberrymusicplayer.strawberry",
        "org.gnome.Lollypop", "com.spotify.Client"]
    // A music app: one of those, or a player for sound (Music, Audio or Player, or "music" in its name); never a browser
    // or a video player, which "nothing playing" cannot hand anything to.
    function isMusicApp(entry): bool {
        if (!entry) return false
        const kinds = Array.from(entry.categories ?? [])
        if (kinds.includes("WebBrowser") || kinds.includes("Video")) return false
        return root.knownMusicApps.includes(String(entry.id ?? "")) || kinds.includes("Music") || kinds.includes("Audio")
            || kinds.includes("Player") || /music/i.test(String(entry.name ?? ""))
    }
    function musicEntry(appId: string): var {
        const entry = appId.length > 0 ? AppSearch.lookupDesktopEntry(appId) : null
        return root.isMusicApp(entry) ? entry : null
    }
    property var listening: ({})
    readonly property FileView listeningStore: FileView {
        path: Directories.stateUserPath + "/music-listening.json"
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }
    readonly property string playingApp: MprisController.activePlayer?.isPlaying
        ? String(root.musicEntry(String(MprisController.activePlayer?.desktopEntry ?? ""))?.id ?? "") : ""
    readonly property Timer listeningTick: Timer {
        interval: 120000
        repeat: true
        running: root.playingApp.length > 0
        onTriggered: {
            const next = Object.assign({}, root.listening)
            next[root.playingApp] = (next[root.playingApp] || 0) + 120
            root.listening = next
            root.listeningStore.setText(JSON.stringify(next))
        }
    }
    // Screen Time keeps a file per day; the last month is read once, just after start, and kept.
    property var focusTime: ({})
    readonly property Connections focusSeen: Connections {
        target: ScreenTime
        function onRangeLoaded(days: int, data: var): void {
            if (days !== 30) return
            const seconds = {}
            for (const app of ScreenTime.getAppList(30)) {
                const id = String(root.musicEntry(String(app.originalId ?? ""))?.id ?? "")
                if (id.length > 0) seconds[id] = (seconds[id] || 0) + Number(app.seconds || 0)
            }
            root.focusTime = seconds
        }
    }
    readonly property Timer focusRead: Timer {
        interval: 3000
        running: ScreenTime.enabled
        onTriggered: ScreenTime.requestDays(30)
    }
    readonly property var musicApp: {
        void AppSearch.list
        const known = root.knownMusicApps
        const candidates = {}
        for (const id of known.concat(Object.keys(root.listening), Object.keys(root.focusTime))) {
            const entry = DesktopEntries.byId(id)
            if (root.isMusicApp(entry)) candidates[String(entry.id)] = entry
        }
        for (const entry of AppSearch.list ?? [])
            if (root.isMusicApp(entry)) candidates[String(entry.id)] = entry
        const rank = id => [root.listening[id] || 0, root.focusTime[id] || 0, -(known.indexOf(id) < 0 ? known.length : known.indexOf(id))]
        let best = null
        for (const id in candidates) {
            if (!best) { best = id; continue }
            const a = rank(id), b = rank(best)
            if (a[0] > b[0] || (a[0] === b[0] && (a[1] > b[1] || (a[1] === b[1] && a[2] > b[2])))) best = id
        }
        return best ? candidates[best] : null
    }
    // AppImage launchers add the version to the name ("limusic (1.1.0)"); the person knows the app, not the build.
    function appName(entry): string { return String(entry?.name ?? "").replace(/\s*\(v?\d[\w.+-]*\)\s*$/, "") }
    readonly property string musicAppName: root.appName(root.musicApp)
    readonly property string musicAppIcon: String(root.musicApp?.icon ?? "")

    // Opening says so, and says when the app never came: an app that dies at launch otherwise looks like a dead tap.
    property string musicLaunch: ""          // "", "opening" or "failed"
    property string musicLaunchName: ""
    property string musicLaunchId: ""
    function openMusic(): bool {
        const entry = root.musicApp
        if (!entry || root.musicLaunch === "opening") return false
        root.musicLaunchId = String(entry.id ?? "")
        root.musicLaunchName = root.appName(entry)
        root.musicLaunch = "opening"
        root.musicLaunchLimit.restart()
        return AppSearch.launchEntry(entry)
    }
    function musicAppCame(): bool {
        if (MprisController.activePlayer) return true
        for (const window of NiriService.windows ?? [])
            if (String(AppSearch.lookupDesktopEntry(String(window?.app_id ?? ""))?.id ?? "") === root.musicLaunchId) return true
        return false
    }
    readonly property Timer musicLaunchLimit: Timer {
        interval: 12000
        onTriggered: root.musicLaunch = root.musicAppCame() ? "" : "failed"
    }
    readonly property Timer musicLaunchWatch: Timer {
        interval: 500
        repeat: true
        running: root.musicLaunch === "opening"
        onTriggered: if (root.musicAppCame()) { root.musicLaunchLimit.stop(); root.musicLaunch = "" }
    }
    readonly property Timer musicFailureFades: Timer {
        interval: 8000
        running: root.musicLaunch === "failed"
        onTriggered: root.musicLaunch = ""
    }
    // What an empty player says under "Not playing": the next step, what it is doing, or why it did not happen.
    readonly property string musicDetail: root.musicLaunch === "opening" ? Translation.tr("Opening %1…").arg(root.musicLaunchName)
        : root.musicLaunch === "failed" ? Translation.tr("%1 didn't open").arg(root.musicLaunchName)
        : root.musicAppName.length > 0 ? Translation.tr("Open %1").arg(root.musicAppName)
        : Translation.tr("Your music appears here")
    Component.onCompleted: {
        try { root.listening = JSON.parse(root.listeningStore.text() || "{}") } catch (e) { root.listening = ({}) }
    }

    readonly property int trayCount: SystemTray.items.values.filter(item => item && item.id).length
    function available(id: string): bool {
        if (id === "media" || id === "visualizer") return root.hasPlayer
        if (id === "tray") return root.trayCount > 0
        if (id === "battery") return Battery.available
        if (id === "bluetooth") return BluetoothStatus.available
        if (id === "updates") return Updates.available
        if (id === "shellUpdate") return ShellUpdates.showUpdate || ShellUpdates.isUpdating
        if (id === "vpn") return Vpn.available
        if (id === "watching") return AnimeWatch.available
        return root.extraIds.includes(id)
    }
    // What a piece needs from outside iNiR, as one line for the moment its
    // backend is missing: the capability stays visible without its tool.
    readonly property var dependencyHints: ({ watching: "Install ani-cli to search and watch anime from here." })
    function dependencyHint(id: string): string {
        if (id === "watching" && !(AnimeWatch.enabled && AnimeWatch.detected)) return ""
        return root.available(id) ? "" : String(root.dependencyHints[id] ?? "")
    }

    // Pieces whose resting face is a glyph, so it can be chosen. Pieces that draw a
    // figure, a ring or a count (clock, battery, sound, network strength…) are left
    // out: their face carries state, not an affordance.
    readonly property var iconKinds: ["controls", "tools", "focus", "notifications", "bluetooth", "updates", "anime", "watching"]
    readonly property var icons: Config.options?.iris?.pieces?.icons ?? []
    function defaultGlyph(kind: string): string {
        if (kind === "controls") return Network.wifiEnabled ? "wifi" : "tune"
        if (kind === "tools") return "timer"
        if (kind === "focus") return "bedtime"
        if (kind === "notifications") return "notifications"
        if (kind === "bluetooth") return "bluetooth"
        if (kind === "updates") return "task_alt"
        if (kind === "anime") return "live_tv"
        if (kind === "watching") return "resume"
        return ""
    }
    // stateGlyph is the piece's own variant for the state it is in; a chosen glyph
    // replaces it, since the state stays legible in the fill, tint or count beside it.
    function chosenGlyph(kind: string): string {
        return String(root.icons.find(entry => entry && entry.kind === kind)?.glyph ?? "")
    }
    function glyphOf(kind: string, stateGlyph: string): string {
        const chosen = root.chosenGlyph(kind)
        if (chosen.length > 0) return chosen
        const state = String(stateGlyph ?? "")
        return state.length > 0 ? state : root.defaultGlyph(kind)
    }
    function setGlyph(kind: string, glyph: string): void {
        if (!root.iconKinds.includes(kind)) return
        const next = root.icons.filter(entry => entry && entry.kind && entry.kind !== kind)
            .map(entry => Object.assign({}, entry))
        const value = String(glyph ?? "").trim()
        if (value.length > 0) next.push({ kind: kind, glyph: value })
        Config.setNestedValue("iris.pieces.icons", next)
    }

    // What is airing next, newest first. Bound to the shared clock so a show that has
    // already aired drops off on the next minute instead of lingering until a refetch.
    readonly property var animeUpcoming: {
        const now = DateTime.clock.date.getTime() / 1000
        return (AnimeService.topAiring ?? [])
            .filter(entry => entry && Number(entry.airingAt ?? 0) > now)
            .sort((a, b) => Number(a.airingAt) - Number(b.airingAt))
    }
    readonly property var animeFollowing: (Config.options?.iris?.anime?.following ?? []).map(id => Number(id))
    function animeFollows(id: real): bool { return root.animeFollowing.includes(Number(id)) }
    function animeToggleFollow(id: real): void {
        const value = Number(id)
        const next = root.animeFollows(value)
            ? root.animeFollowing.filter(entry => entry !== value)
            : root.animeFollowing.concat([value])
        Config.setNestedValue("iris.anime.following", next)
    }
    // What you follow comes first; with nothing followed the piece falls back to
    // whatever airs next, so it says something useful before you have taught it anything.
    readonly property var animeFollowed: root.animeUpcoming.filter(entry => root.animeFollows(entry.id))
    readonly property var animeNext: root.animeFollowed[0] ?? root.animeUpcoming[0] ?? null
    function animeWait(airingAt: real): string {
        const left = Number(airingAt) - DateTime.clock.date.getTime() / 1000
        if (left <= 0) return "now"
        if (left < 3600) return Math.max(1, Math.round(left / 60)) + "m"
        const hours = Math.round(left / 3600)
        if (hours < 24) return hours + "h"
        return Math.max(1, Math.round(left / 86400)) + "d"
    }
    // How close the next episode is, as a share of the gap it is crossing: a weekly
    // show fills its ring over the week, a daily one over the day. The ring is how a
    // piece carries a quantity; the exact wait is text, and text belongs in the card.
    readonly property int animeWeek: 7 * 86400
    function animeApproach(airingAt: real): real {
        const left = Number(airingAt) - DateTime.clock.date.getTime() / 1000
        if (left <= 0) return 1
        const span = left > root.animeWeek ? left : root.animeWeek
        return Math.max(0, Math.min(1, 1 - left / span))
    }

    readonly property string appPrefix: "app:"
    readonly property int maxApps: 8
    readonly property var apps: Config.options?.iris?.bubbles?.apps ?? []
    function isApp(id: string): bool { return id.startsWith(root.appPrefix) }
    function appIdOf(id: string): string { return id.slice(root.appPrefix.length) }
    function appPieceId(appId: string): string { return root.appPrefix + appId }
    function appIcon(appId: string): string {
        const id = String(appId ?? "")
        const entry = AppSearch.lookupDesktopEntry(id)
        const icon = entry?.icon || AppSearch.guessIcon(id)
        return IconThemeService.smartIconName(icon, id)
    }
    function appEntry(appId: string): var { return root.apps.find(entry => entry && entry.appId === appId) ?? null }
    function appPieceIds(): var {
        return root.apps.filter(entry => entry && String(entry.appId ?? "").length > 0)
            .slice(0, root.maxApps).map(entry => root.appPrefix + entry.appId)
    }
    function appFloating(appId: string): bool { return root.appEntry(appId) !== null }
    function writeApps(next: var): void { Config.setNestedValue("iris.bubbles.apps", next) }
    function placeApp(appId: string, place: string, fx: real, fy: real): void {
        if (String(appId ?? "").length === 0) return
        const next = root.apps.filter(entry => entry && entry.appId).map(entry => Object.assign({}, entry))
        const found = next.find(entry => entry.appId === appId)
        const value = { appId: appId, place: place, fx: fx, fy: fy }
        if (found) Object.assign(found, value)
        else if (next.length < root.maxApps) next.push(value)
        else return
        root.writeApps(next)
    }
    function removeApp(appId: string): void {
        root.writeApps(root.apps.filter(entry => entry && entry.appId && entry.appId !== appId)
            .map(entry => Object.assign({}, entry)))
    }

    function configPath(id: string): string {
        return root.extraIds.includes(id) ? "iris.bubbles.extras." + id : "iris.bubbles." + id
    }
    // An extra floats while it is on and placed off the Island; on with place "island" it rides the Island, as the stage reads it.
    // One piece, one place. The Island's own list (Settings › Island › Bubbles in the Island) wins over a
    // floating switch left on: a piece listed there is carried by the Island and its floating bubble is not drawn
    // (a list and a switch both on had left three pieces on the frame while Settings showed them in the Island).
    function listedOnIsland(id: string): bool {
        return Array.from(Config.options?.iris?.bar?.pieces ?? []).map(entry => String(entry)).includes(id)
    }
    function floats(options: var, id: string): bool {
        const extra = options?.extras?.[id]
        return IrisFrame.extraOn(options?.extras, id) && String(extra?.place ?? root.defaultPlace) !== "island" && !root.listedOnIsland(id)
    }
    // What the Island carries: its own list, and any extra switched on whose place is the Island (a Settings switch
    // can turn one on there without adding it to the list; it must not vanish).
    function carriedBy(options: var, listed: var): var {
        const out = Array.from(listed ?? []).map(String)
        for (const id of root.extraIds) {
            const extra = options?.extras?.[id]
            if (IrisFrame.extraOn(options?.extras, id) && String(extra?.place ?? root.defaultPlace) === "island" && !out.includes(id)) out.push(id)
        }
        return out
    }
    function anyFloating(options: var): bool {
        return root.slotIds.some(id => String(options?.[id]?.place ?? "island") !== "island")
            || root.extraIds.some(id => root.floats(options, id))
            || (options?.apps ?? []).some(entry => entry && String(entry.appId ?? "").length > 0)
    }
}
