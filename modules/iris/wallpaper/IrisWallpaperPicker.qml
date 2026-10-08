pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.frame
import qs.modules.iris.style
import qs.modules.iris.components

// The gallery lives in the chassis window of its output, so its body, its content and the Island it grows
// from are one surface: drawn and moved in the same frame.
Item {
    id: root

    property var screen: null
    readonly property var targetScreen: {
        const name = GlobalStates.wallpaperSelectorTargetMonitor
        return (name ? Quickshell.screens.find(s => s.name === name) : null) ?? GlobalStates.focusedScreen
    }
    readonly property bool here: (root.screen?.name ?? "") === (root.targetScreen?.name ?? "")
    readonly property bool present: root.here && (root.morphOpen || surface.progress > 0)
    readonly property bool armed: root.morphOpen && surface.armed

    readonly property real d: IrisStyle.density
    readonly property bool morphOpen: root.here && GlobalStates.wallpaperSelectorOpen
    readonly property bool multiMonitor: Config.options?.background?.multiMonitor?.enable ?? false
    readonly property bool onlineEnabled: Config.options?.sidebar?.wallhaven?.enable ?? true
    readonly property var barOptions: Config.options?.iris?.bar ?? ({})
    readonly property bool barBottom: String(root.barOptions?.position ?? "top") === "bottom"
    readonly property var options: Config.options?.iris?.wallpaper ?? ({})
    readonly property string layoutName: ["strip", "showcase", "wall"].includes(String(root.options?.layout ?? "showcase"))
        ? String(root.options?.layout ?? "showcase") : "showcase"
    readonly property bool showcase: root.layoutName === "showcase"
    readonly property bool playMotion: (root.options?.motion ?? true) && root.morphOpen
    // Full-size images and video wait for the open to finish: decoded mid-motion they cost it 4-7 frames.
    readonly property bool opened: root.morphOpen && surface.settled
    property string targetMonitor: ""
    readonly property string selectionTarget: Wallpapers.currentSelectionTarget()
    readonly property bool overviewTargetable: (Config.options?.background?.backdrop?.enable ?? true)
        && (Config.options?.panelFamily ?? "ii") !== "waffle"
    readonly property bool targetsOverview: root.selectionTarget === "backdrop"
    function targetOverview(overview: bool): void {
        GlobalStates.wallpaperSelectionTarget = overview ? "backdrop" : "main"
        root.previewArmed = false
        Wallpapers.cancelWallpaperPreview()
    }
    readonly property string currentPath: Wallpapers.currentWallpaperPathForTarget(root.selectionTarget, root.targetMonitor)

    property string source: "library"
    readonly property bool online: root.source !== "library" && root.onlineEnabled
    readonly property string provider: root.source === "live" ? "motionbgs" : root.source
    readonly property var sourceCatalog: ({
        wallhaven: { id: "wallhaven", label: "Wallhaven", glyph: "travel_explore" },
        konachan: { id: "konachan", label: "Konachan", glyph: "landscape" },
        yandere: { id: "yandere", label: "yande.re", glyph: "landscape" },
        live: { id: "live", label: Translation.tr("Live"), glyph: "motion_photos_on" }
    })
    readonly property var onlineSources: !root.onlineEnabled ? []
        : Array.from(root.options?.sources ?? ["wallhaven", "live"]).map(id => root.sourceCatalog[String(id)]).filter(Boolean)
    readonly property var sources: [{ id: "library", label: Translation.tr("Library"), glyph: "photo_library" }].concat(root.onlineSources)
    function offered(id: string): bool { return root.sources.some(entry => entry.id === id) }
    onSourcesChanged: if (!root.offered(root.source)) root.setSource("library", "")

    // Off, online results keep to what anyone can have on screen: explicit art never shows (every source
    // asks for safe ratings), and fan service rated safe is filtered by its tags or title here.
    readonly property bool suggestive: root.options?.suggestive ?? false
    readonly property var wallhavenExclusions: ["-bikini", "-swimwear", "-lingerie", "-underwear", "-cleavage", "-ecchi",
        "-panties", "-ass", "-boobs", "-nude"]
    readonly property var suggestivePattern: /(^|[\s_,.-])(bikinis?|swimsuits?|swimwear|lingerie|panties|pantsu|underwear|bra|cleavage|breasts?|boobs?|nipples?|nude|naked|topless|bottomless|ecchi|thong|sideboob|underboob|see[_-]through|bunny[_ ]girl|undressing|towel|onsen|bathing|ass|butt|sexy|seductive|lewd|erotic|sensual)([\s_,.-]|$)/i
    function suggestiveImage(image): bool {
        return root.suggestivePattern.test(String(image?.tags ?? "") + " " + String(image?.title ?? "") + " " + String(image?.slug ?? ""))
    }
    onSuggestiveChanged: if (root.morphOpen && root.online) root.searchOnline(1, true)
    property int selectedIndex: 0
    readonly property string query: search.text.trim()

    property var libraryFolders: []
    property var libraryFiles: []
    function readFolder(): void {
        const model = Wallpapers.folderModel
        if (!Wallpapers.folderModelReady || !model) {
            if (root.morphOpen) folderRead.restart()
            return
        }
        const folders = []
        const files = []
        for (let i = 0; i < model.count; i++) {
            const modified = model.get(i, "fileModified")
            const entry = { path: String(model.get(i, "filePath") ?? ""), name: String(model.get(i, "fileName") ?? ""),
                time: modified ? Number(modified.getTime()) || 0 : 0 }
            if (entry.path.length === 0) continue
            if (model.get(i, "fileIsDir")) folders.push(entry)
            else files.push(entry)
        }
        folders.sort((a, b) => a.name.localeCompare(b.name))
        const same = (a, b) => a.length === b.length && a.every((entry, i) => entry.path === b[i].path)
        if (!same(folders, root.libraryFolders)) root.libraryFolders = folders
        if (!same(files, root.libraryFiles)) root.libraryFiles = files
        if (root.selectedIndex >= files.length) root.selectedIndex = Math.max(0, files.length - 1)
        if (root.morphOpen && !root.online && !root.previewArmed && root.query.length === 0) root.selectCurrent()
    }
    Connections {
        target: Wallpapers.folderModel
        function onCountChanged(): void { folderRead.restart() }
        function onStatusChanged(): void { folderRead.restart() }
    }
    Connections {
        target: Wallpapers
        function onFolderModelReadyChanged(): void { folderRead.restart() }
    }
    Timer { id: folderRead; interval: 40; onTriggered: root.readFolder() }
    // What the folder actually holds, so the filter only appears when there is
    // something to choose between.
    property string kind: "all"
    function kindOf(path: string): string {
        if (Wallpapers.isVideoFile(path)) return "live"
        return String(path).toLowerCase().endsWith(".gif") ? "gif" : "still"
    }
    readonly property var kindsPresent: {
        const found = root.libraryFiles.reduce((set, entry) => set.add(root.kindOf(entry.path)), new Set())
        const known = [{ id: "still", glyph: "image", label: "Stills" },
            { id: "live", glyph: "movie", label: "Live" },
            { id: "gif", glyph: "gif", label: "GIF" }]
        const present = known.filter(entry => found.has(entry.id))
        return present.length > 1 ? [{ id: "all", glyph: "grid_view", label: "Everything" }].concat(present) : []
    }
    readonly property string sortOrder: ["newest", "oldest", "name"].includes(String(root.options?.sort ?? "newest"))
        ? String(root.options?.sort ?? "newest") : "newest"
    readonly property string onlineOrder: ["top", "newest", "random"].includes(String(root.options?.onlineSort ?? "top"))
        ? String(root.options?.onlineSort ?? "top") : "top"
    readonly property string topRange: ["1d", "1w", "1M", "1y"].includes(String(root.options?.topRange ?? "1w"))
        ? String(root.options?.topRange ?? "1w") : "1w"
    readonly property string onlineSorting: root.onlineOrder === "top" ? "toplist:" + root.topRange
        : root.onlineOrder === "random" ? "random" : "date_added"
    readonly property bool onlineSortable: root.online && root.provider !== "motionbgs"
    function setOrder(value: string): void {
        Config.setNestedValue(root.online ? "iris.wallpaper.onlineSort" : "iris.wallpaper.sort", value)
    }
    readonly property var visibleFiles: {
        const list = root.kind === "all" ? root.libraryFiles.slice()
            : root.libraryFiles.filter(entry => root.kindOf(entry.path) === root.kind)
        if (root.sortOrder === "name") list.sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()))
        else list.sort((a, b) => root.sortOrder === "oldest" ? a.time - b.time : b.time - a.time)
        return list
    }
    onSortOrderChanged: if (root.morphOpen && !root.online) { root.selectedIndex = 0; grid.contentX = 0; root.selectCurrent() }
    onOnlineSortingChanged: if (root.morphOpen && root.onlineSortable) root.searchOnline(1, true)
    readonly property int libraryCount: (root.visibleFiles ?? []).length
    readonly property string libraryPath: !root.online ? String((root.visibleFiles ?? [])[root.selectedIndex]?.path ?? "") : ""

    readonly property string folderPath: Wallpapers.effectiveDirectory.replace(/\/+$/, "") || "/"
    readonly property string homePath: String(Quickshell.env("HOME") ?? "").replace(/\/+$/, "")
    readonly property string wallpapersHome: FileUtils.trimFileProtocol(String(Wallpapers.defaultFolder ?? "")).replace(/\/+$/, "")
    readonly property var crumbs: {
        const path = root.folderPath
        const underHome = root.homePath.length > 0 && (path === root.homePath || path.startsWith(root.homePath + "/"))
        const base = underHome ? root.homePath : ""
        const rest = path.slice(base.length).split("/").filter(part => part.length > 0)
        const list = [{ label: underHome ? Translation.tr("Home") : "/", path: underHome ? root.homePath : "/", home: true }]
        let walked = base
        for (const part of rest) {
            walked += "/" + part
            list.push({ label: part, path: walked, home: false })
        }
        return list.length > 5 ? [list[0], { label: "…", path: list[list.length - 4].path, home: false }].concat(list.slice(-3)) : list
    }
    readonly property bool canGoBack: (Wallpapers.folderModel?.currentFolderHistoryIndex ?? 0) > 0
    readonly property bool canGoForward: (Wallpapers.folderModel?.currentFolderHistoryIndex ?? 0) < (Wallpapers.folderModel?.folderHistory?.length ?? 0) - 1
    readonly property bool atWallpapersHome: root.folderPath === root.wallpapersHome
    onLibraryFilesChanged: if (!root.kindsPresent.some(entry => entry.id === root.kind)) root.kind = "all"
    function openFolder(path: string): void {
        root.kind = "all"
        if (!path || path === root.folderPath) return
        root.selectedIndex = 0
        grid.contentX = 0
        Wallpapers.setDirectory(path)
    }

    readonly property var pinnedFolders: Array.from(root.options?.pinned ?? []).map(path => String(path))
    readonly property bool pinned: root.pinnedFolders.includes(root.folderPath)
    function togglePin(): void {
        Config.setNestedValue("iris.wallpaper.pinned", root.pinned
            ? root.pinnedFolders.filter(path => path !== root.folderPath)
            : root.pinnedFolders.concat([root.folderPath]))
    }
    function standardPath(location: int): string {
        return FileUtils.trimFileProtocol(String(StandardPaths.standardLocations(location)[0] ?? "")).replace(/\/+$/, "")
    }
    readonly property var placeCandidates: [
        { path: root.wallpapersHome, label: Translation.tr("Wallpapers"), glyph: "wallpaper" },
        { path: root.standardPath(StandardPaths.PicturesLocation), label: Translation.tr("Pictures"), glyph: "image" },
        { path: root.standardPath(StandardPaths.MoviesLocation), label: Translation.tr("Videos"), glyph: "movie" },
        { path: root.standardPath(StandardPaths.DownloadLocation), label: Translation.tr("Downloads"), glyph: "download" },
        { path: root.homePath, label: Translation.tr("Home"), glyph: "home" }
    ].concat(root.pinnedFolders.map(path => ({ path: path, label: path.split("/").pop() || path, glyph: "push_pin", pinned: true })))
    property var existingPlaces: []
    readonly property var places: root.placeCandidates.filter((place, i) => place.path.length > 0
        && root.existingPlaces.includes(place.path)
        && root.placeCandidates.findIndex(other => other.path === place.path) === i)
    function checkPlaces(): void {
        placeCheck.running = false
        placeCheck.command = ["bash", "-c", 'for p; do [ -d "$p" ] && printf "%s\\n" "$p"; done', "_"].concat(root.placeCandidates.map(place => place.path))
        placeCheck.running = true
    }
    onPlaceCandidatesChanged: if (root.morphOpen) root.checkPlaces()
    Process {
        id: placeCheck
        stdout: StdioCollector {
            onStreamFinished: root.existingPlaces = text.split("\n").filter(line => line.length > 0)
        }
    }

    property var folderInfo: ({})
    function scanFolders(): void {
        folderScan.running = false
        folderScan.running = true
    }
    Timer { id: folderScanDelay; interval: 120; onTriggered: root.scanFolders() }
    Process {
        id: folderScan
        command: ["bash", "-c", 'find "$1" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -print0 2>/dev/null | while IFS= read -r -d "" d; do '
            + 'files=$(find "$d" -maxdepth 1 -type f \\( ' + Wallpapers.extensions.map(ext => "-iname '*." + ext + "'").join(" -o ") + ' \\) ! -name ".*" 2>/dev/null | sort); '
            + 'n=$(printf "%s" "$files" | grep -c .); printf "%s\\t%s\\t%s\\n" "$d" "$n" "$(printf "%s" "$files" | head -n1)"; done', "_", root.folderPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const info = {}
                for (const line of text.split("\n")) {
                    const [path, count, cover] = line.split("\t")
                    if (path) info[path] = { count: Number(count) || 0, cover: cover ?? "" }
                }
                root.folderInfo = info
            }
        }
    }
    readonly property bool pathMode: !root.online && /^[~\/]/.test(root.query)
    function jumpTo(text: string): void {
        const path = text.replace(/^~(?=\/|$)/, root.homePath).replace(/\/+$/, "") || "/"
        search.text = ""
        root.openFolder(path)
    }

    readonly property var onlineImages: (Wallhaven.responses ?? [])
        .filter(response => response && response.provider === root.provider)
        .reduce((all, response) => all.concat((response.images ?? []).filter(image => image && !image.is_nsfw && image.file_url
            && (root.suggestive || !root.suggestiveImage(image)))), [])
    readonly property string onlineMessage: {
        const messages = (Wallhaven.responses ?? []).filter(response => response && response.provider === root.provider && response.message)
        return messages.length > 0 ? String(messages[messages.length - 1].message) : ""
    }
    readonly property int onlinePage: {
        const pages = (Wallhaven.responses ?? []).filter(response => response && response.provider === root.provider).map(response => Number(response.page) || 1)
        return pages.length > 0 ? Math.max(...pages) : 0
    }
    readonly property bool onlineExhausted: (Wallhaven.responses ?? []).some(response => response && response.provider === root.provider
        && Number(response.page) > 1 && (response.images ?? []).length === 0)
    readonly property var selectedImage: root.online ? (root.onlineImages[root.selectedIndex] ?? null) : null

    readonly property var wallhavenDiscoveries: [
        { label: Translation.tr("Anime"), tags: [], category: "010" },
        { label: Translation.tr("Anime scenery"), tags: ["landscape"], category: "010" },
        { label: Translation.tr("Ricing"), tags: ["linux"], category: "111" },
        { label: Translation.tr("Pixel art"), tags: ["pixel art"], category: "111" },
        { label: Translation.tr("Cyberpunk"), tags: ["cyberpunk"], category: "111" },
        { label: Translation.tr("Minimal"), tags: ["minimal"], category: "111" },
        { label: Translation.tr("Dark"), tags: ["dark"], category: "111" },
        { label: Translation.tr("Nature"), tags: ["nature"], category: "100" },
        { label: Translation.tr("Space"), tags: ["space"], category: "100" },
        { label: Translation.tr("Abstract"), tags: ["abstract"], category: "111" }
    ]
    readonly property var konachanDiscoveries: [
        { label: Translation.tr("Anime"), tags: [] },
        { label: Translation.tr("Landscape"), tags: ["landscape"] },
        { label: Translation.tr("Sky"), tags: ["sky"] },
        { label: Translation.tr("City"), tags: ["city"] },
        { label: Translation.tr("Night"), tags: ["night"] }
    ]
    readonly property var yandereDiscoveries: [
        { label: Translation.tr("Landscape"), tags: ["landscape"] },
        { label: Translation.tr("Anime"), tags: [] }
    ]
    readonly property var liveDiscoveries: [
        { label: Translation.tr("Anime"), tags: ["tag:anime"] },
        { label: "Frieren", tags: ["tag:frieren"] },
        { label: "Genshin", tags: ["tag:genshin-impact"] },
        { label: "Star Rail", tags: ["tag:honkai-star-rail"] },
        { label: "Zenless", tags: ["tag:zenless-zone-zero"] },
        { label: "Wuthering Waves", tags: ["tag:wuthering-waves"] },
        { label: "Blue Archive", tags: ["tag:blue-archive"] },
        { label: "Jujutsu Kaisen", tags: ["tag:jujutsu-kaisen"] },
        { label: "Chainsaw Man", tags: ["tag:chainsaw-man"] },
        { label: "Demon Slayer", tags: ["tag:demon-slayer"] },
        { label: "Solo Leveling", tags: ["tag:solo-leveling"] },
        { label: "One Piece", tags: ["tag:one-piece"] },
        { label: "Miku", tags: ["tag:hatsune-miku"] },
        { label: "Ghibli", tags: ["tag:ghibli"] },
        { label: Translation.tr("Lofi"), tags: ["tag:lofi"] },
        { label: Translation.tr("Pixel"), tags: ["tag:pixel"] },
        { label: Translation.tr("Cyberpunk"), tags: ["tag:cyberpunk"] },
        { label: Translation.tr("Rain"), tags: ["tag:rain"] },
        { label: Translation.tr("Sakura"), tags: ["tag:sakura"] },
        { label: Translation.tr("Night"), tags: ["tag:night"] }
    ]
    readonly property var discoveries: root.source === "live" ? root.liveDiscoveries
        : root.source === "wallhaven" ? root.wallhavenDiscoveries
        : root.source === "yandere" ? root.yandereDiscoveries : root.konachanDiscoveries
    property int wallhavenDiscovery: 0
    property int konachanDiscovery: 0
    property int yandereDiscovery: 0
    property int liveDiscovery: 0
    readonly property int discovery: root.source === "live" ? root.liveDiscovery
        : root.source === "wallhaven" ? root.wallhavenDiscovery
        : root.source === "yandere" ? root.yandereDiscovery : root.konachanDiscovery
    function pickDiscovery(index: int): void {
        if (root.source === "live") root.liveDiscovery = index
        else if (root.source === "wallhaven") root.wallhavenDiscovery = index
        else if (root.source === "yandere") root.yandereDiscovery = index
        else root.konachanDiscovery = index
        root.series = null
        search.text = ""
        onlineSearchDelay.stop()
        root.searchOnline(1, true)
    }

    readonly property var airing: root.online ? (AnimeService.topAiring ?? []).slice(0, 16) : []
    property var series: null
    property var seriesQueries: []
    property int seriesAttempt: 0
    function seriesLabel(anime): string {
        return String(anime?.titleEnglish || anime?.title || "")
            .split(/\s[-–]\s|:\s| -/)[0]
            .replace(/\s+(season\s*\d+|\d+(st|nd|rd|th)\s+season|part\s*\d+|cour\s*\d+|[IVX]{1,4})$/i, "")
            .trim()
    }
    function pickSeries(anime): void {
        if (!anime) return
        if (root.series?.id === anime.id) { root.pickDiscovery(root.discovery); return }
        const english = root.seriesLabel(anime)
        const romaji = root.seriesLabel({ title: anime.titleRomaji ?? "" })
        const slug = english.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
        const booru = root.source === "konachan" || root.source === "yandere"
        const queries = root.source === "live"
            ? [["tag:" + slug], [english], [romaji]]
            : booru ? [[slug.replace(/-/g, "_")], [romaji.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "")]]
            : [[english], [romaji]]
        root.series = anime
        root.seriesQueries = queries.filter((entry, i) => String(entry[0]).replace(/^tag:/, "").length > 0
            && queries.findIndex(other => other[0] === entry[0]) === i)
        root.seriesAttempt = 0
        search.text = ""
        onlineSearchDelay.stop()
        root.searchOnline(1, true)
    }
    Connections {
        target: Wallhaven
        function onResponseFinished(): void {
            if (!root.online || root.series === null || root.onlineImages.length > 0 || Wallhaven.runningRequests > 0) return
            if (root.seriesAttempt + 1 >= root.seriesQueries.length) return
            root.seriesAttempt += 1
            root.searchOnline(1, true)
        }
    }

    property string downloadingId: ""
    readonly property int count: root.online ? root.onlineImages.length : root.libraryCount

    function entryFor(index: int): var {
        if (root.online) {
            const image = root.onlineImages[index]
            if (!image) return null
            const live = image.is_video === true
            const eyebrow = root.series ? String(root.series.titleJapanese || root.series.title || "") : ""
            const light = live && String(Config.options?.iris?.wallpaper?.liveQuality ?? "best") === "light"
            const facts = live ? [{ glyph: "motion_photos_on", label: Translation.tr("Live") }, { label: light ? "HD" : String(image.quality ?? "HD"), figure: true }]
                : [{ glyph: "image", label: Translation.tr("Picture") }]
            facts.push({ label: light ? "1920 × 1080" : image.width + " × " + image.height, figure: true })
            return {
                key: String(image.id),
                imageUrl: String(image.preview_url ?? ""),
                fullUrl: live ? "" : String(image.file_url ?? ""),
                motionSource: live ? String(image.motion_url ?? "") : "",
                video: live,
                eyebrow: eyebrow,
                facts: facts,
                current: false
            }
        }
        const file = (root.visibleFiles ?? [])[index]
        if (!file) return null
        const video = Wallpapers.isVideoFile(file.path)
        const extension = String(file.name.split(".").pop() ?? "").toUpperCase()
        return {
            key: file.path,
            filePath: file.path,
            fullUrl: video ? Wallpapers.stillUrlFor(file.path) : "file://" + file.path,
            motionSource: video ? file.path : "",
            video: video,
            eyebrow: "",
            facts: [video ? { glyph: "motion_photos_on", label: Translation.tr("Live") } : { glyph: "image", label: Translation.tr("Picture") },
                { label: extension, figure: true }].concat(file.time > 0
                ? [{ glyph: "calendar_today", label: Translation.locale.toString(new Date(file.time), "d MMM yyyy") }] : []),
            current: Wallpapers.isCurrentWallpaperPath(file.path, root.selectionTarget, root.targetMonitor)
        }
    }
    readonly property var selectedEntry: {
        void (root.onlineImages.length + root.visibleFiles.length + root.currentPath)
        return root.entryFor(root.selectedIndex)
    }
    readonly property bool searching: root.online && Wallhaven.runningRequests > 0
    readonly property string emptyGlyph: root.online ? "travel_explore"
        : root.pathMode ? "drive_file_move"
        : search.text.length > 0 ? "search_off"
        : root.libraryFolders.length > 0 ? "folder_open" : "hide_image"
    readonly property string emptyText: root.online && !Network.online ? Network.offlineReason
        : root.online
        ? (root.searching ? Translation.tr("Looking for wallpapers…") : (root.onlineMessage || Translation.tr("Nothing found")))
        : root.pathMode ? Translation.tr("Press Enter to open %1").arg(root.query)
        : search.text.length > 0 ? Translation.tr("No matches")
        : root.libraryFolders.length > 0 ? Translation.tr("Wallpapers live in the folders above")
        : Translation.tr("No wallpapers in this folder")

    property string hoverKey: ""
    property string motionKey: ""
    readonly property string motionCandidate: root.showcase || !root.playMotion ? ""
        : root.hoverKey.length > 0 ? root.hoverKey : String(root.selectedEntry?.key ?? "")
    onMotionCandidateChanged: {
        root.motionKey = ""
        if (root.motionCandidate.length > 0) motionDwell.restart()
        else motionDwell.stop()
    }
    Timer { id: motionDwell; interval: 360; onTriggered: root.motionKey = root.motionCandidate }
    function hoverTile(key: string, hovered: bool): void {
        if (hovered) root.hoverKey = key
        else if (root.hoverKey === key) root.hoverKey = ""
    }

    visible: root.present

    property bool prepared: false
    function prepare(): void {
        if (root.prepared) return
        root.prepared = true
        const gsTarget = GlobalStates.wallpaperSelectorTargetMonitor ?? ""
        root.targetMonitor = !root.multiMonitor ? ""
            : gsTarget.length > 0 ? gsTarget : (GlobalStates.focusedScreen?.name ?? "")
        root.source = "library"
        root.series = null
        root.hoverKey = ""
        Wallpapers.searchQuery = ""
        search.text = ""
        const jumping = GlobalStates.wallpaperSelectorSource === "library" && /^[~\/]/.test(GlobalStates.wallpaperSelectorQuery)
        const dir = FileUtils.parentDirectory(FileUtils.trimFileProtocol(String(root.currentPath ?? ""))).replace(/\/+$/, "")
        const inLibrary = root.wallpapersHome.length > 0 && (dir === root.wallpapersHome || dir.startsWith(root.wallpapersHome + "/"))
        const start = inLibrary ? dir : root.wallpapersHome
        if (!jumping && start.length > 0 && start !== root.folderPath) Wallpapers.setDirectory(start)
        Wallpapers.generateThumbnail("large")
        root.selectedIndex = 0
        root.previewArmed = false
        folderRead.restart()
        root.checkPlaces()
        folderScanDelay.restart()
        root.takeRequest()
        Qt.callLater(() => search.forceActiveFocus())
    }
    function selectCurrent(): void {
        const current = FileUtils.trimFileProtocol(String(root.currentPath ?? ""))
        const index = (root.visibleFiles ?? []).findIndex(entry => entry.path === current)
        if (index >= 0) {
            root.selectedIndex = index
            Qt.callLater(() => grid.positionViewAtIndex(index, GridView.Contain))
        }
    }
    Component.onCompleted: if (root.morphOpen) root.prepare()
    Connections {
        target: Wallpapers
        function onDirectoryChanged(): void {
            Wallpapers.generateThumbnail("large")
            if (!root.online) { root.selectedIndex = 0; grid.contentX = 0 }
            folderRead.restart()
            root.folderInfo = ({})
            if (root.morphOpen) folderScanDelay.restart()
        }
    }

    function setSource(next: string, text): void {
        const wanted = String(text ?? "")
        if (root.source === next && wanted.length === 0) return
        onlineSearchDelay.stop()
        root.series = null
        root.hoverKey = ""
        root.source = next
        search.text = wanted
        onlineSearchDelay.stop()
        root.selectedIndex = 0
        grid.contentX = 0
        if (root.online) {
            AnimeService.fetchTopAiring()
            root.searchOnline(1, true)
        }
    }
    function takeRequest(): void {
        const requested = GlobalStates.wallpaperSelectorSource
        const text = GlobalStates.wallpaperSelectorQuery
        if (requested.length === 0) return
        GlobalStates.wallpaperSelectorSource = ""
        GlobalStates.wallpaperSelectorQuery = ""
        const next = requested !== "library" && !root.offered(requested) ? "library" : requested
        const wantedSeries = GlobalStates.wallpaperSelectorSeries
        if (wantedSeries !== null) {
            GlobalStates.wallpaperSelectorSeries = null
            if (next !== "library") { root.setSource(next, ""); root.pickSeries(wantedSeries); return }
        }
        if (next === "library" && /^[~\/]/.test(text)) { root.setSource(next, ""); root.jumpTo(text); return }
        root.setSource(next, text)
    }
    Connections {
        target: GlobalStates
        function onWallpaperSelectorSourceChanged(): void { if (root.morphOpen) root.takeRequest() }
        function onWallpaperSelectorKindChanged(): void {
            const wanted = GlobalStates.wallpaperSelectorKind
            if (wanted.length === 0) return
            GlobalStates.wallpaperSelectorKind = ""
            root.kind = wanted
            root.selectedIndex = 0
        }
        function onWallpaperSelectorMoveRequested(step: int): void { if (root.morphOpen && !root.online) root.move(step) }
    }
    onKindChanged: GlobalStates.wallpaperSelectorKindActive = root.kind
    function cycleSource(step: int): void {
        const ids = root.sources.map(entry => entry.id)
        const at = Math.max(0, ids.indexOf(root.source))
        root.setSource(ids[(at + step + ids.length) % ids.length], "")
    }
    function searchOnline(page: int, replace: bool): void {
        if (!Network.online) return
        const option = root.discoveries[root.discovery] ?? root.discoveries[0]
        const live = root.provider === "motionbgs"
        const booru = root.provider === "konachan" || root.provider === "yandere"
        const tags = root.series !== null ? (root.seriesQueries[root.seriesAttempt] ?? [])
            : root.query.length > 0 ? (live ? [root.query] : booru ? root.query.toLowerCase().split(/\s+/).filter(Boolean) : root.query.split(/\s+/))
            : option.tags
        const asked = root.provider === "wallhaven" && !root.suggestive ? tags.concat(root.wallhavenExclusions) : tags
        if (replace) { Wallhaven.beginSearch(); root.selectedIndex = 0; grid.contentX = 0 }
        const screen = root.screen
        Wallhaven.makeRequest(asked, false, live ? 36 : (Config.options?.sidebar?.wallhaven?.limit ?? 24), page,
            live ? "111" : option.category, undefined, root.provider,
            live ? { mode: "any" }
                : { mode: "auto", width: screen?.width ?? 1920, height: screen?.height ?? 1080, ratioCode: "", aspect: (screen?.width ?? 16) / Math.max(1, screen?.height ?? 9) },
            live ? undefined : root.onlineSorting)
    }
    Connections {
        target: Network
        function onOnlineChanged(): void {
            if (Network.online && root.morphOpen && root.online && root.onlineImages.length === 0) root.searchOnline(1, true)
        }
    }
    Timer { id: onlineSearchDelay; interval: 450; onTriggered: { root.series = null; root.searchOnline(1, true) } }

    function apply(filePath: string, isDir: bool): void {
        if (!filePath || filePath.length === 0) return
        if (isDir) { root.openFolder(filePath); return }
        const target = root.selectionTarget
        root.committing = true
        Wallpapers.applySelectionTarget(FileUtils.trimFileProtocol(filePath), target,
            Appearance.m3colors.darkmode, root.targetMonitor)
        if (target === "backdrop" || target === "waffle-backdrop") Wallpapers.cancelWallpaperPreview()
        else Wallpapers.clearWallpaperPreview()
        root.finishSelection()
        Qt.callLater(() => root.committing = false)
    }

    readonly property bool livePreview: root.options?.livePreview ?? true
    property bool previewArmed: false
    property bool committing: false
    onSelectedIndexChanged: if (root.morphOpen && !root.online) previewDelay.restart()
    Timer {
        id: previewDelay
        interval: 180
        onTriggered: {
            if (!root.morphOpen || root.online || !root.livePreview || !root.previewArmed || root.targetsOverview) return
            const path = root.libraryPath
            if (!path || Wallpapers.isVideoFile(path) || path === FileUtils.trimFileProtocol(String(root.currentPath ?? ""))) Wallpapers.cancelWallpaperPreview()
            else Wallpapers.previewWallpaper(path, root.targetMonitor)
        }
    }
    function select(index: int): void {
        root.previewArmed = true
        root.selectedIndex = index
    }
    onMorphOpenChanged: {
        if (root.morphOpen) root.prepare()
        else {
            root.prepared = false
            if (!root.committing) Wallpapers.cancelWallpaperPreview()
        }
    }
    onLivePreviewChanged: if (!root.livePreview) Wallpapers.cancelWallpaperPreview()
    onOnlineChanged: if (root.online) Wallpapers.cancelWallpaperPreview()
    Component.onDestruction: if (!root.committing) Wallpapers.cancelWallpaperPreview()
    function finishSelection(): void {
        Config.setNestedValue("wallpaperSelector.selectionTarget", "main")
        Config.setNestedValue("wallpaperSelector.targetMonitor", "")
        GlobalStates.wallpaperSelectionTarget = "main"
        GlobalStates.wallpaperSelectorTargetMonitor = ""
        GlobalStates.wallpaperSelectorOpen = false
    }
    function applyOnline(image): void {
        if (!image || !image.file_url || download.running) return
        const folder = Directories.booruDownloads
        const live = image.is_video === true
        const sharp = live && String(image.file_url_4k ?? "").length > 0
            && String(Config.options?.iris?.wallpaper?.liveQuality ?? "best") !== "light"
        const name = live ? "motionbgs-" + String(image.slug ?? image.id) + (sharp ? "-4k" : "") + ".mp4"
            : root.provider + "-" + image.id + (image.file_ext ? "." + image.file_ext : "")
        download.localPath = folder + "/" + name
        root.downloadingId = String(image.id)
        download.total = 0
        download.received = 0
        download.command = ["/usr/bin/bash", "-c", 'mkdir -p "$1" && [ -s "$2" ] && exit 0; '
            + 'echo "total $(curl -sIL -A "$4" "$3" | tr -d "\\r" | awk \'tolower($1)=="content-length:" { n = $2 } END { print n + 0 }\')"; '
            + 'curl -fsSL -A "$4" "$3" -o "$2.part" && mv "$2.part" "$2"',
            "_", folder, download.localPath, sharp ? image.file_url_4k : image.file_url, Wallhaven.defaultUserAgent]
        download.running = true
    }
    Process {
        id: download
        property string localPath: ""
        property real total: 0
        property real received: 0
        readonly property real progress: download.total > 0 ? Math.min(1, download.received / download.total) : 0
        stdout: SplitParser {
            onRead: line => { if (line.startsWith("total ")) download.total = Number(line.slice(6)) || 0 }
        }
        onExited: exitCode => {
            root.downloadingId = ""
            if (exitCode === 0) root.apply(download.localPath, false)
        }
    }
    Timer {
        interval: 350
        repeat: true
        running: download.running && download.total > 0
        onTriggered: if (!downloadSize.running) downloadSize.running = true
    }
    Process {
        id: downloadSize
        command: ["stat", "-c", "%s", download.localPath + ".part"]
        stdout: StdioCollector { onStreamFinished: download.received = Number(text.trim()) || download.received }
    }
    function applySelected(): void {
        if (root.online) { root.applyOnline(root.selectedImage); return }
        if (root.libraryPath.length > 0) root.apply(root.libraryPath, false)
    }
    function move(step: int): void {
        if (root.count === 0) return
        root.select(Math.max(0, Math.min(root.count - 1, root.selectedIndex + step)))
        // The row glides to the chosen tile with the ring instead of jumping: ask the view where it would land, then travel.
        const from = grid.contentX
        grid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
        const to = grid.contentX
        if (!IrisStyle.motionEnabled || Math.abs(to - from) < 1) return
        grid.contentX = from
        glide.to = to
        glide.restart()
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -IrisFrame.band
        enabled: root.armed
        onClicked: GlobalStates.wallpaperSelectorOpen = false
    }
    Shortcut {
        sequence: "Escape"
        enabled: root.morphOpen
        onActivated: {
            if (search.text.length > 0) search.text = ""
            else GlobalStates.wallpaperSelectorOpen = false
        }
    }
    Shortcut { sequence: "Alt+Left"; enabled: root.morphOpen && !root.online && root.canGoBack; onActivated: Wallpapers.navigateBack() }
    Shortcut { sequence: "Alt+Right"; enabled: root.morphOpen && !root.online && root.canGoForward; onActivated: Wallpapers.navigateForward() }
    Shortcut { sequence: "Alt+Up"; enabled: root.morphOpen && !root.online; onActivated: Wallpapers.navigateUp() }


    RectangularShadow {
        x: surface.x + surface.lerp(surface.from.x, 0)
        y: surface.y + surface.lerp(surface.from.y, 0) + 8 * root.d * surface.progress
        width: surface.lerp(surface.from.width, surface.width)
        height: surface.lerp(surface.from.height, surface.height)
        radius: Math.min(width / 2, height / 2, surface.lerp(surface.fromRadius, surface.radius))
        blur: 32 * root.d
        spread: -6 * root.d
        color: IrisStyle.shadow
        opacity: IrisStyle.shadowAt(surface.progress)
    }

    IrisMorphSurface {
        motionSurface: "gallery"
        settles: true
        fieldBacked: true
        chassisKey: "gallery"
        id: surface
        compositorBlurred: true
        open: root.morphOpen
        radius: IrisStyle.surfaceRadius("gallery", IrisStyle.radiusPanel)
        light: IrisStyle.surfaceLight("gallery", IrisStyle.wallpaperLight)
        lightFrom: (Config.options?.iris?.bar?.position ?? "top") === "bottom" ? "bottom" : "top"
        readonly property real edgeGap: (Number(root.barOptions?.height ?? 42)
            + ((root.barOptions?.notch ?? false) ? 0 : Number(root.barOptions?.margin ?? 8) * 2)) * root.d + 10 * root.d
        readonly property real pad: Math.round(20 * root.d)
        width: Math.min(root.width - 48, Math.round(Math.max(640, Math.min(1400, root.options?.width ?? 960)) * root.d))
        height: layout.implicitHeight + 2 * surface.pad
        x: Math.round((root.width - width) / 2)
        y: root.barBottom ? root.height - height - edgeGap - IrisFrame.musicReach("bottom")
            : edgeGap + IrisFrame.musicReach("top")
        onClosed: { Wallpapers.searchQuery = ""; search.text = ""; root.motionKey = "" }
        onSettledChanged: if (surface.settled && surface.open) search.forceActiveFocus()

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: layout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: surface.pad
            spacing: Math.round(12 * root.d)

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(6 * root.d)

                WallpaperGlyphButton {
                    visible: !root.online
                    glyph: "chevron_left"
                    enabled: root.canGoBack
                    Accessible.name: Translation.tr("Back")
                    onClicked: Wallpapers.navigateBack()
                }
                WallpaperGlyphButton {
                    visible: !root.online
                    glyph: "chevron_right"
                    enabled: root.canGoForward
                    Accessible.name: Translation.tr("Forward")
                    onClicked: Wallpapers.navigateForward()
                }

                Flickable {
                    id: crumbFlick
                    visible: !root.online
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(34 * root.d)
                    contentWidth: crumbRow.implicitWidth
                    contentX: Math.max(0, crumbRow.implicitWidth - width)
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: crumbRow.implicitWidth > width
                    clip: true
                    Row {
                        id: crumbRow
                        height: parent.height
                        spacing: Math.round(2 * root.d)
                        Repeater {
                            model: root.crumbs
                            Row {
                                id: crumb
                                required property var modelData
                                required property int index
                                readonly property bool last: crumb.index === root.crumbs.length - 1
                                height: crumbRow.height
                                spacing: Math.round(2 * root.d)
                                MaterialSymbol {
                                    visible: crumb.index > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "chevron_right"
                                    iconSize: Math.round(15 * root.d)
                                    color: IrisStyle.muted
                                }
                                MouseArea {
                                    id: crumbArea
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: crumbContent.implicitWidth + Math.round(18 * root.d)
                                    height: Math.round(28 * root.d)
                                    hoverEnabled: true
                                    cursorShape: crumb.last ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    Accessible.role: Accessible.Button
                                    Accessible.name: crumb.modelData.label
                                    onClicked: root.openFolder(crumb.modelData.path)
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: height / 2
                                        color: (crumb.last ? IrisStyle.fill : crumbArea.containsMouse ? IrisStyle.fillQuiet : ColorUtils.applyAlpha(IrisStyle.text, 0))
                                        Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                                    }
                                    Row {
                                        id: crumbContent
                                        anchors.centerIn: parent
                                        spacing: Math.round(5 * root.d)
                                        MaterialSymbol {
                                            visible: crumb.modelData.home || (crumb.last && root.atWallpapersHome)
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: crumb.modelData.home ? "home" : "wallpaper"
                                            fill: 1
                                            iconSize: Math.round(15 * root.d)
                                            color: crumb.last ? IrisStyle.accent : IrisStyle.subtext
                                        }
                                        IrisText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: crumb.modelData.label
                                            width: Math.min(implicitWidth, Math.round((crumb.last ? 240 : 140) * root.d))
                                            elide: Text.ElideMiddle
                                            color: crumb.last ? IrisStyle.text : IrisStyle.subtext
                                            font.pixelSize: crumb.last ? IrisStyle.typeLabel : IrisStyle.typeMeta
                                            font.weight: IrisStyle.weight(crumb.last ? Font.DemiBold : Font.Medium)
                                        }
                                        IrisText {
                                            visible: crumb.last
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: String(root.libraryCount)
                                            color: IrisStyle.secondaryAccent
                                            font.family: IrisStyle.fontNumbers
                                            font.features: ({ "tnum": 1 })
                                            font.pixelSize: IrisStyle.typeMeta
                                            font.weight: IrisStyle.weight(Font.Bold)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                IrisText {
                    visible: root.online
                    Layout.fillWidth: true
                    Layout.leftMargin: Math.round(4 * root.d)
                    text: root.source === "live" ? Translation.tr("Live wallpapers")
                        : Translation.tr("Discover on %1").arg(root.sources.find(entry => entry.id === root.source)?.label ?? "Wallhaven")
                    font.pixelSize: IrisStyle.typeLabel
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    elide: Text.ElideRight
                }
                WallpaperGlyphButton {
                    visible: !root.online
                    glyph: "push_pin"
                    selected: root.pinned
                    Accessible.name: root.pinned ? Translation.tr("Unpin this folder") : Translation.tr("Pin this folder")
                    onClicked: root.togglePin()
                }

                IrisSegmented {
                    id: sourceSwitch
                    visible: root.sources.length > 1
                    Layout.preferredWidth: Math.round(84 * root.d) * root.sources.length + 2 * sourceSwitch.inset
                    Layout.preferredHeight: Math.round(34 * root.d)
                    accessibleName: Translation.tr("Source")
                    options: root.sources.map(entry => ({ value: entry.id, label: entry.label }))
                    current: root.source
                    onPicked: value => root.setSource(value, "")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(8 * root.d)

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(34 * root.d)
                    radius: height / 2
                    color: (search.activeFocus ? IrisStyle.fill : IrisStyle.fillQuiet)
                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                    MaterialSymbol {
                        id: searchGlyph
                        anchors.left: parent.left
                        anchors.leftMargin: Math.round(12 * root.d)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        iconSize: Math.round(16 * root.d)
                        color: search.text.length > 0 ? IrisStyle.accent : IrisStyle.subtext
                    }
                    TextInput {
                        id: search
                        anchors.left: searchGlyph.right
                        anchors.leftMargin: Math.round(8 * root.d)
                        anchors.right: countLabel.left
                        anchors.rightMargin: Math.round(8 * root.d)
                        anchors.verticalCenter: parent.verticalCenter
                        color: IrisStyle.text
                        selectionColor: IrisStyle.accentContainer
                        selectedTextColor: IrisStyle.inkOnAccentContainer
                        font.family: IrisStyle.fontMain
                        font.pixelSize: IrisStyle.typeLabel
                        clip: true
                        focus: true
                        onTextChanged: {
                            if (root.online) {
                                if (search.text.length > 0) root.series = null
                                onlineSearchDelay.restart()
                                return
                            }
                            Wallpapers.searchQuery = /^[~\/]/.test(text) ? "" : text
                            root.selectedIndex = 0
                        }
                        Keys.onPressed: event => {
                            const rows = grid.rows
                            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                root.cycleSource(event.key === Qt.Key_Backtab ? -1 : 1)
                                search.forceActiveFocus()
                            }
                            else if (event.modifiers & Qt.AltModifier) return
                            else if (event.key === Qt.Key_Right && search.text.length === 0) root.move(rows)
                            else if (event.key === Qt.Key_Left && search.text.length === 0) root.move(-rows)
                            else if (event.key === Qt.Key_Down) root.move(1)
                            else if (event.key === Qt.Key_Up) root.move(-1)
                            else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.pathMode) root.jumpTo(root.query)
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.applySelected()
                            else if (event.key === Qt.Key_Backspace && search.text.length === 0 && !root.online) Wallpapers.navigateUp()
                            else return
                            event.accepted = true
                        }
                        IrisText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: search.text.length === 0
                            text: root.source === "live" ? Translation.tr("Search live wallpapers")
                                : root.online ? Translation.tr("Search %1").arg(root.sources.find(entry => entry.id === root.source)?.label ?? "Wallhaven")
                                : Translation.tr("Search in %1, or type a path").arg(root.crumbs[root.crumbs.length - 1]?.label ?? "")
                            color: IrisStyle.muted
                            font.pixelSize: search.font.pixelSize
                        }
                    }
                    IrisText {
                        id: countLabel
                        anchors.right: parent.right
                        anchors.rightMargin: Math.round(14 * root.d)
                        anchors.verticalCenter: parent.verticalCenter
                        visible: (root.online || search.text.length > 0) && !root.pathMode
                        text: Wallhaven.runningRequests > 0 && root.online ? Translation.tr("Loading…") : String(root.count)
                        color: IrisStyle.secondaryAccent
                        font.family: IrisStyle.fontNumbers
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.Bold)
                    }
                }

                WallpaperKinds {
                    id: kindFilter
                    visible: !root.online && kindFilter.wanted
                    picker: root
                }
                IrisSegmented {
                    visible: !root.online || root.onlineSortable
                    glyphOnly: true
                    implicitHeight: Math.round(34 * root.d)
                    accessibleName: Translation.tr("Order")
                    options: root.online
                        ? [{ value: "top", label: Translation.tr("Top"), glyph: "trending_up" },
                            { value: "newest", label: Translation.tr("Newest"), glyph: "schedule" },
                            { value: "random", label: Translation.tr("Random"), glyph: "shuffle" }]
                        : [{ value: "newest", label: Translation.tr("Newest"), glyph: "schedule" },
                            { value: "oldest", label: Translation.tr("Oldest"), glyph: "history" },
                            { value: "name", label: Translation.tr("Name"), glyph: "sort_by_alpha" }]
                    current: root.online ? root.onlineOrder : root.sortOrder
                    onPicked: value => root.setOrder(value)
                }
                IrisSegmented {
                    visible: root.onlineSortable && root.onlineOrder === "top"
                    Layout.preferredWidth: Math.round(58 * root.d) * 4 + 2 * inset
                    Layout.preferredHeight: Math.round(34 * root.d)
                    accessibleName: Translation.tr("Top of the")
                    options: [{ value: "1d", label: Translation.tr("Day") }, { value: "1w", label: Translation.tr("Week") },
                        { value: "1M", label: Translation.tr("Month") }, { value: "1y", label: Translation.tr("Year") }]
                    current: root.topRange
                    onPicked: value => Config.setNestedValue("iris.wallpaper.topRange", value)
                }
                WallpaperGlyphButton {
                    visible: !root.online
                    glyph: "shuffle"
                    enabled: root.libraryCount > 0
                    Accessible.name: Translation.tr("Random wallpaper")
                    onClicked: {
                        const pick = root.visibleFiles[Math.floor(Math.random() * root.visibleFiles.length)]
                        if (pick) root.apply(pick.path, false)
                    }
                }
                WallpaperGlyphButton {
                    visible: root.online
                    glyph: "refresh"
                    Accessible.name: Translation.tr("Refresh")
                    onClicked: root.searchOnline(1, true)
                }
            }

            WallpaperFolders {
                Layout.fillWidth: true
                visible: !root.online && root.query.length === 0
                picker: root
            }

            WallpaperDiscovery {
                Layout.fillWidth: true
                visible: root.online
                picker: root
            }

            WallpaperShowcase {
                id: hero
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(Math.min(width * 0.4, root.height * 0.36))
                visible: root.showcase
                picker: root
                entry: root.showcase ? root.selectedEntry : null
                radius: Math.max(IrisStyle.radiusTile, surface.radius - surface.pad)
            }

            ScriptModel {
                id: onlineResultsModel
                objectProp: "id"
                values: root.onlineImages
            }
            ScriptModel {
                id: libraryModel
                objectProp: "path"
                values: root.visibleFiles
            }
            GridView {
                id: grid
                Layout.fillWidth: true
                readonly property int rows: root.layoutName === "wall" ? 3 : root.showcase ? 1 : 2
                readonly property real thumbWidth: Math.round(Math.max(150, Math.min(300, (root.options?.thumbnailSize ?? 228))) * root.d
                    * (root.showcase ? 0.78 : 1))
                Layout.preferredHeight: cellHeight * rows
                flow: GridView.FlowTopToBottom
                cellWidth: thumbWidth
                cellHeight: Math.round(thumbWidth * 0.625)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick
                cacheBuffer: Math.round(cellWidth * 4)
                model: root.online ? onlineResultsModel : libraryModel
                currentIndex: root.selectedIndex
                onContentXChanged: if (root.online && Wallhaven.runningRequests === 0 && root.onlinePage > 0 && !root.onlineExhausted
                    && contentX + width > contentWidth - cellWidth * 2) root.searchOnline(root.onlinePage + 1, false)
                Behavior on contentX {
                    enabled: wheelScroll.animating && !glide.running
                    NumberAnimation { duration: IrisStyle.duration(180); easing.type: IrisStyle.feedbackEasing }
                }
                NumberAnimation {
                    id: glide
                    target: grid
                    property: "contentX"
                    duration: IrisStyle.morphDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: IrisStyle.morphCurve
                }
                onMovementStarted: glide.stop()
                // One ring for the whole gallery, travelling from tile to tile on the morph curve (a ring per tile only
                // faded out on one and in on the next). Content coordinates: it scrolls with the tiles.
                highlightFollowsCurrentItem: false
                highlight: Item {
                    id: ring
                    readonly property Item at: grid.currentItem
                    readonly property bool travels: IrisStyle.motionEnabled && root.armed && ring.at !== null
                    z: 2
                    x: ring.at ? ring.at.x : 0
                    y: ring.at ? ring.at.y : 0
                    width: grid.cellWidth
                    height: grid.cellHeight
                    opacity: ring.at !== null && root.count > 0 ? 1 : 0
                    Behavior on x { enabled: ring.travels; NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                    Behavior on y { enabled: ring.travels; NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: Math.round(4 * root.d)
                        radius: IrisStyle.radiusCard
                        color: "transparent"
                        border.width: Math.max(2, Math.round(2.5 * root.d))
                        border.color: IrisStyle.accent
                    }
                }
                WheelHandler {
                    id: wheelScroll
                    property bool animating: false
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const delta = event.pixelDelta.x || event.pixelDelta.y || (event.angleDelta.y || event.angleDelta.x) / 120 * grid.cellWidth
                        animating = event.pixelDelta.x === 0 && event.pixelDelta.y === 0
                        grid.contentX = Math.max(0, Math.min(Math.max(0, grid.contentWidth - grid.width), grid.contentX - delta))
                    }
                }

                delegate: WallpaperTile {
                    id: slot
                    required property var modelData
                    readonly property string path: !root.online ? String(slot.modelData?.path ?? "") : ""
                    readonly property var image: root.online ? slot.modelData : null
                    readonly property bool liveImage: slot.image?.is_video === true
                    width: grid.cellWidth
                    height: grid.cellHeight
                    picker: root
                    key: root.online ? String(slot.image?.id ?? "") : slot.path
                    filePath: slot.path
                    imageUrl: root.online ? String(slot.image?.preview_url ?? "") : ""
                    video: root.online ? slot.liveImage : Wallpapers.isVideoFile(slot.path)
                    motionSource: !slot.video ? "" : root.online ? String(slot.image?.motion_url ?? "") : slot.path
                    quality: !slot.liveImage ? ""
                        : String(Config.options?.iris?.wallpaper?.liveQuality ?? "best") === "light" ? "HD" : String(slot.image?.quality ?? "")
                    label: root.online
                        ? (slot.liveImage ? String(slot.image?.title ?? "") : (slot.image ? slot.image.width + " × " + slot.image.height : ""))
                        : String(slot.modelData?.name ?? "").replace(/\.[^.]+$/, "")
                    selected: root.selectedIndex === slot.index
                    current: !root.online && Wallpapers.isCurrentWallpaperPath(slot.path, root.selectionTarget, root.targetMonitor)
                    busy: root.online && root.downloadingId.length > 0 && root.downloadingId === String(slot.image?.id ?? "")
                    onCommitted: root.online ? root.applyOnline(slot.image) : root.apply(slot.path, false)
                }

                WallpaperEmpty {
                    anchors.centerIn: parent
                    width: parent.width - 40 * root.d
                    visible: root.count === 0 && !root.showcase
                    picker: root
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10 * root.d
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    IrisText {
                        Layout.fillWidth: true
                        visible: root.downloadingId.length > 0
                        text: download.progress > 0 ? Translation.tr("Downloading… %1%").arg(Math.round(download.progress * 100))
                            : Translation.tr("Downloading…")
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.DemiBold)
                    }
                    IrisText {
                        Layout.fillWidth: true
                        text: root.online ? (root.selectedImage ? (root.selectedImage.is_video === true
                                ? Translation.tr("Plays on your desktop · saved to your wallpapers")
                                : Translation.tr("Saved to your wallpapers")) : "")
                            : root.pathMode ? Translation.tr("Press Enter to open %1").arg(root.query)
                            : root.targetsOverview ? Translation.tr("Sets the wallpaper behind the overview")
                            : Wallpapers.thumbnailGenerationRunning ? Translation.tr("Preparing previews…")
                            : root.livePreview && root.previewArmed && !(root.selectedEntry?.video ?? false) ? Translation.tr("Previewing on the desktop")
                            : ""
                        color: root.downloadingId.length === 0 ? IrisStyle.subtext : IrisStyle.muted
                        font.pixelSize: IrisStyle.typeMeta
                        elide: Text.ElideRight
                    }
                }
                IrisSegmented {
                    visible: root.overviewTargetable
                    Layout.preferredWidth: Math.round(96 * root.d) * 2 + 2 * inset
                    Layout.preferredHeight: Math.round(32 * root.d)
                    accessibleName: Translation.tr("Apply to")
                    options: [{ value: "main", label: Translation.tr("Desktop") }, { value: "backdrop", label: Translation.tr("Overview") }]
                    current: root.targetsOverview ? "backdrop" : "main"
                    onPicked: value => root.targetOverview(value === "backdrop")
                }
                Rectangle {
                    visible: root.multiMonitor
                    implicitHeight: Math.round(28 * root.d)
                    implicitWidth: targetRow.implicitWidth + Math.round(20 * root.d)
                    radius: height / 2
                    color: "transparent"
                    Row {
                        id: targetRow
                        anchors.centerIn: parent
                        spacing: Math.round(6 * root.d)
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.targetMonitor ? "desktop_windows" : "select_window"
                            iconSize: Math.round(14 * root.d)
                            color: IrisStyle.subtext
                        }
                        IrisText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.targetMonitor || Translation.tr("All displays")
                            color: IrisStyle.subtext
                            font.pixelSize: IrisStyle.typeMeta
                        }
                    }
                }
                IrisButton {
                    implicitHeight: Math.round(36 * root.d)
                    implicitWidth: Math.round(88 * root.d)
                    buttonRadius: height / 2
                    buttonRadiusPressed: height / 2
                    emphasized: true
                    text: Translation.tr("Apply")
                    enabled: (root.online ? root.selectedImage !== null : root.libraryPath.length > 0) && root.downloadingId.length === 0
                    onClicked: root.applySelected()
                }
            }
        }
    }
}
