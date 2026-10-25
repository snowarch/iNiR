pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.functions

// What the picker knows and does, whatever it looks like: the sources (folders, favourites, the web), one list of
// entries in a single shape for all of them, the selection, the web's filters and details, downloads and applying.
// A layout only draws `entries` and calls the verbs.
Item {
    id: root
    visible: false

    property var screen: null
    property bool open: false
    property bool opened: false
    // Drawn at all (opening, open or closing). Full pictures decode once it has opened and go when it is gone.
    property bool present: false
    property bool warm: false
    onOpenedChanged: if (root.opened) root.warm = true
    onPresentChanged: if (!root.present) root.warm = false
    property string targetMonitor: ""

    readonly property var options: Config.options?.iris?.wallpaper ?? ({})
    readonly property bool onlineEnabled: Config.options?.sidebar?.wallhaven?.enable ?? true
    readonly property bool playMotion: (root.options?.motion ?? true) && root.open

    // Sources
    property string source: "library"
    readonly property bool online: !["library", "favorites"].includes(root.source) && root.onlineEnabled
    readonly property bool local: !root.online
    readonly property string provider: root.source === "live" ? "motionbgs" : root.source
    readonly property var sourceCatalog: ({
        wallhaven: { id: "wallhaven", label: "Wallhaven", glyph: "travel_explore", web: true },
        konachan: { id: "konachan", label: "Konachan", glyph: "landscape", web: true },
        yandere: { id: "yandere", label: "yande.re", glyph: "photo_library", web: true },
        live: { id: "live", label: Translation.tr("Live"), glyph: "motion_photos_on", web: true }
    })
    readonly property var onlineSources: !root.onlineEnabled ? []
        : Array.from(root.options?.sources ?? ["wallhaven", "live"]).map(id => root.sourceCatalog[String(id)]).filter(Boolean)
    readonly property var sources: [
        { id: "library", label: Translation.tr("Library"), glyph: "wallpaper", web: false },
        { id: "favorites", label: Translation.tr("Favourites"), glyph: "favorite", web: false }
    ].concat(root.onlineSources)
    readonly property var sourceInfo: root.sources.find(entry => entry.id === root.source) ?? root.sources[0]
    function offered(id: string): bool { return root.sources.some(entry => entry.id === id) }
    onSourcesChanged: if (!root.offered(root.source)) root.setSource("library", "")

    // A new list (another source, folder, search or order) is dealt from its start; a list that only grew keeps its place.
    property int listGeneration: 0
    function restart(): void {
        root.selectedIndex = 0
        root.listGeneration += 1
    }

    property string query: ""
    property int selectedIndex: 0
    // The list moved under the selection: same wallpaper, another index.
    signal shifted(int delta)
    property bool previewArmed: false
    function select(index: int): void {
        if (root.count === 0) return
        root.previewArmed = true
        root.selectedIndex = Math.max(0, Math.min(root.count - 1, index))
    }
    function move(step: int): void { root.select(root.selectedIndex + step) }

    // ── Library ──────────────────────────────────────────────────────────
    property var libraryFolders: []
    property var libraryFiles: []
    function readFolder(): void {
        const model = Wallpapers.folderModel
        if (!Wallpapers.folderModelReady || !model) {
            if (root.open) folderRead.restart()
            return
        }
        const folders = []
        const files = []
        for (let i = 0; i < model.count; i++) {
            const modified = model.get(i, "fileModified")
            const entry = { path: String(model.get(i, "filePath") ?? ""), name: String(model.get(i, "fileName") ?? ""),
                time: modified ? Number(modified.getTime()) || 0 : 0, size: Number(model.get(i, "fileSize") ?? 0) }
            if (entry.path.length === 0) continue
            if (model.get(i, "fileIsDir")) folders.push(entry)
            else files.push(entry)
        }
        folders.sort((a, b) => a.name.localeCompare(b.name))
        const same = (a, b) => a.length === b.length && a.every((entry, i) => entry.path === b[i].path)
        if (!same(folders, root.libraryFolders)) root.libraryFolders = folders
        if (!same(files, root.libraryFiles)) {
            // The one you are on stays yours when the folder changes under it (a download, a file added).
            const held = root.source === "library" && root.previewArmed ? root.selectedKey : ""
            root.libraryFiles = files
            const at = held.length > 0 ? root.entries.findIndex(entry => entry.key === held) : -1
            if (at >= 0 && at !== root.selectedIndex) {
                const from = root.selectedIndex
                root.selectedIndex = at
                root.shifted(at - from)
            }
        }
        if (root.source === "library" && !root.previewArmed && root.query.length === 0) root.selectCurrent()
    }
    Connections {
        target: Wallpapers.folderModel
        function onCountChanged(): void { folderRead.restart() }
        function onStatusChanged(): void { folderRead.restart() }
    }
    Connections {
        target: Wallpapers
        function onFolderModelReadyChanged(): void { folderRead.restart() }
        function onDirectoryChanged(): void {
            Wallpapers.generateThumbnail("large")
            folderRead.restart()
            root.folderInfo = ({})
            if (root.source === "library") root.restart()
            if (root.open) folderScanDelay.restart()
        }
    }
    Timer { id: folderRead; interval: 40; onTriggered: root.readFolder() }

    property string kind: "all"
    function kindOf(path: string, video: bool): string {
        if (video || Wallpapers.isVideoFile(path)) return "live"
        return String(path).toLowerCase().endsWith(".gif") ? "gif" : "still"
    }
    readonly property var kindSpace: root.source === "favorites"
        ? Wallpapers.favorites.map(entry => entry.web && !entry.path ? (entry.video ? "live" : "web") : root.kindOf(entry.path, entry.video))
        : root.libraryFiles.map(entry => root.kindOf(entry.path, false))
    readonly property var kindsPresent: {
        const found = new Set(root.kindSpace)
        const known = [{ id: "still", glyph: "image", label: Translation.tr("Pictures") },
            { id: "live", glyph: "motion_photos_on", label: Translation.tr("Live") },
            { id: "gif", glyph: "gif_box", label: "GIF" },
            { id: "web", glyph: "public", label: Translation.tr("From the web") }]
        const present = known.filter(entry => found.has(entry.id))
        return present.length > 1 ? [{ id: "all", glyph: "apps", label: Translation.tr("All") }].concat(present) : []
    }
    onKindsPresentChanged: if (!root.kindsPresent.some(entry => entry.id === root.kind)) root.kind = "all"
    onKindChanged: { GlobalStates.wallpaperSelectorKindActive = root.kind; root.restart() }

    readonly property string sortOrder: ["newest", "oldest", "name"].includes(String(root.options?.sort ?? "newest"))
        ? String(root.options?.sort ?? "newest") : "newest"
    onSortOrderChanged: if (root.local) { root.restart(); root.selectCurrent() }

    readonly property string folderPath: Wallpapers.effectiveDirectory.replace(/\/+$/, "") || "/"
    readonly property string folderName: root.folderPath === root.wallpapersHome ? Translation.tr("Wallpapers")
        : root.folderPath === root.homePath ? Translation.tr("Home") : (root.folderPath.split("/").pop() || "/")
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
        return list.length > 4 ? [list[0], { label: "…", path: list[list.length - 3].path, home: false }].concat(list.slice(-2)) : list
    }
    readonly property bool canGoBack: (Wallpapers.folderModel?.currentFolderHistoryIndex ?? 0) > 0
    readonly property bool canGoForward: (Wallpapers.folderModel?.currentFolderHistoryIndex ?? 0) < (Wallpapers.folderModel?.folderHistory?.length ?? 0) - 1
    readonly property bool atWallpapersHome: root.folderPath === root.wallpapersHome
    function openFolder(path: string): void {
        if (root.source !== "library") root.setSource("library", "")
        root.kind = "all"
        if (!path || path === root.folderPath) return
        root.previewArmed = false
        Wallpapers.setDirectory(path)
    }
    function goBack(): void { if (root.canGoBack) Wallpapers.navigateBack() }
    function goForward(): void { if (root.canGoForward) Wallpapers.navigateForward() }
    function goUp(): void { if (root.source === "library") Wallpapers.navigateUp() }

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
    onPlaceCandidatesChanged: if (root.open) root.checkPlaces()
    Process {
        id: placeCheck
        stdout: StdioCollector { onStreamFinished: root.existingPlaces = text.split("\n").filter(line => line.length > 0) }
    }

    // Each subfolder's count and first picture, for its cover.
    property var folderInfo: ({})
    Timer { id: folderScanDelay; interval: 120; onTriggered: { folderScan.running = false; folderScan.running = true } }
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
    readonly property bool pathMode: root.local && /^[~\/]/.test(root.query)
    function jumpTo(text: string): void {
        const path = text.replace(/^~(?=\/|$)/, root.homePath).replace(/\/+$/, "") || "/"
        root.setQuery("")
        root.openFolder(path)
    }

    function fileEntry(file: var): var {
        const video = Wallpapers.isVideoFile(file.path)
        const name = String(file.name ?? file.path.split("/").pop())
        return {
            key: file.path, web: false, provider: "library", id: "", path: file.path,
            title: name.replace(/\.[^.]+$/, ""), ext: String(name.split(".").pop() ?? "").toUpperCase(),
            video: video, gif: name.toLowerCase().endsWith(".gif"), time: Number(file.time ?? 0), size: Number(file.size ?? 0),
            width: 0, height: 0, preview: "", sample: "", file: "", motion: video ? file.path : "",
            tags: [], colors: []
        }
    }
    readonly property var libraryEntries: {
        const list = root.libraryFiles.filter(entry => root.kind === "all" || root.kindOf(entry.path, false) === root.kind)
        if (root.sortOrder === "name") list.sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()))
        else list.sort((a, b) => root.sortOrder === "oldest" ? a.time - b.time : b.time - a.time)
        return list.map(file => root.fileEntry(file))
    }

    // ── Favourites ───────────────────────────────────────────────────────
    function favoriteEntry(saved: var): var {
        const local = String(saved.path ?? "").length > 0
        const entry = local ? root.fileEntry({ path: saved.path, time: Number(saved.added ?? 0) }) : {
            key: saved.key, web: true, provider: String(saved.provider ?? ""), id: String(saved.id ?? ""), path: "",
            title: String(saved.title ?? ""), ext: "", video: saved.video === true, gif: false, time: Number(saved.added ?? 0), size: 0,
            width: Number(saved.width ?? 0), height: Number(saved.height ?? 0), preview: String(saved.preview ?? ""),
            sample: String(saved.preview ?? ""), file: String(saved.file ?? ""), file4k: String(saved.file4k ?? ""),
            motion: String(saved.motion ?? ""), page: String(saved.page ?? ""), tags: [], colors: []
        }
        // A downloaded web favourite stays the same favourite: its key is the web one.
        return Object.assign(entry, { key: saved.key, favoriteOf: saved, added: Number(saved.added ?? 0), page: String(saved.page ?? ""),
            width: Number(saved.width ?? 0) || entry.width, height: Number(saved.height ?? 0) || entry.height,
            provider: saved.web ? String(saved.provider ?? "") : entry.provider, web: saved.web === true && !local })
    }
    readonly property var favoriteEntries: {
        const words = root.query.toLowerCase().split(/\s+/).filter(Boolean)
        return Wallpapers.favorites.map(saved => root.favoriteEntry(saved)).filter(entry => {
            const kind = entry.web ? (entry.video ? "live" : "web") : root.kindOf(entry.path, entry.video)
            if (root.kind !== "all" && kind !== root.kind) return false
            const hay = (entry.title + " " + entry.path + " " + entry.provider).toLowerCase()
            return words.every(word => hay.includes(word))
        })
    }

    // ── The web ──────────────────────────────────────────────────────────
    // Off, online results keep to what anyone can have on screen: explicit art never shows (every source asks for safe
    // ratings), and fan service rated safe is filtered by its tags or title here.
    readonly property bool suggestive: root.options?.suggestive ?? false
    readonly property var wallhavenExclusions: ["-bikini", "-swimwear", "-lingerie", "-underwear", "-cleavage", "-ecchi",
        "-panties", "-ass", "-boobs", "-nude"]
    readonly property var suggestivePattern: /(^|[\s_,.-])(bikinis?|swimsuits?|swimwear|lingerie|panties|pantsu|underwear|bra|cleavage|breasts?|boobs?|nipples?|nude|naked|topless|bottomless|ecchi|thong|sideboob|underboob|see[_-]through|bunny[_ ]girl|undressing|towel|onsen|bathing|ass|butt|sexy|seductive|lewd|erotic|sensual)([\s_,.-]|$)/i
    function suggestiveImage(image): bool {
        return root.suggestivePattern.test(String(image?.tags ?? "") + " " + String(image?.title ?? "") + " " + String(image?.slug ?? ""))
    }
    onSuggestiveChanged: if (root.open && root.online) root.searchOnline(1, true)

    readonly property var onlineResponses: (Wallhaven.responses ?? []).filter(response => response && response.provider === root.provider)
    readonly property var onlineImages: root.onlineResponses
        .reduce((all, response) => all.concat((response.images ?? []).filter(image => image && !image.is_nsfw && image.file_url
            && (root.suggestive || !root.suggestiveImage(image)))), [])
    readonly property string onlineMessage: {
        const messages = root.onlineResponses.filter(response => response.message)
        return messages.length > 0 ? String(messages[messages.length - 1].message) : ""
    }
    readonly property int onlinePage: root.onlineResponses.reduce((top, response) => Math.max(top, Number(response.page) || 1), 0)
    readonly property int onlineLastPage: root.onlineResponses.reduce((top, response) => Math.max(top, Number(response.lastPage) || 0), 0)
    readonly property int onlineTotal: root.onlineResponses.reduce((top, response) => Math.max(top, Number(response.total) || 0), 0)
    readonly property bool onlineExhausted: (root.onlineLastPage > 0 && root.onlinePage >= root.onlineLastPage)
        || root.onlineResponses.some(response => Number(response.page) > 1 && (response.images ?? []).length === 0)
    readonly property bool searching: root.online && Wallhaven.runningRequests > 0

    function webEntry(image: var): var {
        const live = image.is_video === true
        const light = live && String(root.options?.liveQuality ?? "best") === "light"
        const booru = root.provider === "konachan" || root.provider === "yandere"
        const tags = root.provider === "wallhaven" ? (Wallhaven.wallpaperDetails[String(image.id)]?.tags ?? []).map(tag => tag.name)
            : booru ? String(image.tags ?? "").split(/\s+/).filter(Boolean) : []
        return {
            key: root.provider + ":" + String(image.id), web: true, provider: root.provider, id: String(image.id), path: "",
            title: String(image.title ?? ""), ext: String(image.file_ext ?? image.file_type ?? "").replace(/^image\//, "").toUpperCase(),
            video: live, gif: false, time: image.created_at ? Date.parse(String(image.created_at).replace(" ", "T")) || 0 : 0,
            size: Number(image.file_size ?? 0), width: light ? 1920 : Number(image.width ?? 0), height: light ? 1080 : Number(image.height ?? 0),
            quality: live ? (light ? "HD" : String(image.quality ?? "HD")) : "",
            preview: String(image.preview_url ?? ""), sample: String(image.sample_url ?? image.preview_url ?? ""),
            file: String(image.file_url ?? ""), file4k: String(image.file_url_4k ?? ""), motion: live ? String(image.motion_url ?? "") : "",
            slug: String(image.slug ?? ""), page: String(image.page_url ?? image.source ?? ""), origin: String(image.origin_url ?? ""),
            views: Number(image.views ?? 0), favorites: Number(image.favorites ?? 0), score: Number(image.score ?? 0),
            author: String(image.author ?? ""), category: String(image.category ?? ""),
            colors: Array.from(image.colors ?? []).map(colour => String(colour)), tags: tags, image: image
        }
    }
    readonly property var webEntries: {
        void Wallhaven.wallpaperDetails
        return root.onlineImages.map(image => root.webEntry(image))
    }

    readonly property var entries: root.source === "library" ? root.libraryEntries
        : root.source === "favorites" ? root.favoriteEntries : root.online ? root.webEntries : []
    readonly property int count: root.entries.length
    readonly property var selected: root.entries[root.selectedIndex] ?? null
    function entryAt(index: int): var { return index >= 0 && index < root.count ? root.entries[index] : null }
    function isCurrent(entry: var): bool {
        return !!entry && entry.path.length > 0 && Wallpapers.isCurrentWallpaperPath(entry.path, root.selectionTarget, root.targetMonitor)
    }
    function isFavorite(entry: var): bool { return !!entry && Wallpapers.isFavorite(entry.key) }
    function toggleFavorite(entry: var): void {
        if (!entry) return
        Wallpapers.toggleFavorite({
            key: entry.key, web: entry.web, path: entry.path, provider: entry.provider, id: entry.id,
            title: entry.title || entry.slug || "", preview: entry.web ? (entry.sample || entry.preview) : "",
            file: entry.file, file4k: entry.file4k ?? "", motion: entry.motion, page: entry.page ?? "",
            width: entry.width, height: entry.height, video: entry.video
        })
    }

    // Order and filters of the web, remembered.
    readonly property string onlineOrder: {
        const wanted = String(root.options?.onlineSort ?? "top")
        const offered = root.orderChoices.map(entry => entry.value)
        return offered.includes(wanted) ? wanted : (offered[0] ?? "top")
    }
    readonly property var orderChoices: root.provider === "motionbgs" ? []
        : root.provider === "wallhaven"
        ? [{ value: "top", label: Translation.tr("Top rated"), glyph: "trending_up" }, { value: "hot", label: Translation.tr("Trending"), glyph: "local_fire_department" },
            { value: "newest", label: Translation.tr("Newest"), glyph: "schedule" }, { value: "views", label: Translation.tr("Most viewed"), glyph: "visibility" },
            { value: "favorites", label: Translation.tr("Most liked"), glyph: "favorite" }, { value: "random", label: Translation.tr("Random"), glyph: "shuffle" }]
        : [{ value: "top", label: Translation.tr("Top rated"), glyph: "trending_up" }, { value: "newest", label: Translation.tr("Newest"), glyph: "schedule" },
            { value: "random", label: Translation.tr("Random"), glyph: "shuffle" }]
    readonly property var libraryOrderChoices: [{ value: "newest", label: Translation.tr("Newest"), glyph: "schedule" },
        { value: "oldest", label: Translation.tr("Oldest"), glyph: "history" }, { value: "name", label: Translation.tr("Name"), glyph: "sort_by_alpha" }]
    readonly property string topRange: ["1d", "1w", "1M", "1y"].includes(String(root.options?.topRange ?? "1w"))
        ? String(root.options?.topRange ?? "1w") : "1w"
    readonly property var rangeChoices: [{ value: "1d", label: Translation.tr("Day") }, { value: "1w", label: Translation.tr("Week") },
        { value: "1M", label: Translation.tr("Month") }, { value: "1y", label: Translation.tr("Year") }]
    readonly property string ratio: ["screen", "wide", "portrait", "any"].includes(String(root.options?.ratio ?? "screen"))
        ? String(root.options?.ratio ?? "screen") : "screen"
    readonly property var ratioChoices: [{ value: "screen", label: Translation.tr("Your screen"), glyph: "desktop_windows" },
        { value: "wide", label: Translation.tr("Wide"), glyph: "crop_landscape" },
        { value: "portrait", label: Translation.tr("Portrait"), glyph: "crop_portrait" },
        { value: "any", label: Translation.tr("Any"), glyph: "aspect_ratio" }]
    // Wallhaven searches by one colour of its own palette.
    property string colour: ""
    readonly property var palette: ["660000", "990000", "cc0000", "cc3333", "ea4c88", "993399", "663399", "333399", "0066cc",
        "0099cc", "66cccc", "77cc33", "669900", "336600", "666600", "999900", "cccc33", "ffff00", "ffcc33", "ff9900", "ff6600",
        "cc6633", "996633", "663300", "000000", "999999", "cccccc", "ffffff", "424153"]
    // The same 29 laid out as paint: the bright ones round the colour wheel, the earthy ones, the greys.
    readonly property var colourRuns: [
        { id: "spectrum", label: Translation.tr("Colours"), stops: ["cc0000", "ff6600", "ff9900", "ffcc33", "ffff00", "77cc33",
            "669900", "66cccc", "0099cc", "0066cc", "333399", "663399", "993399", "ea4c88"] },
        { id: "earth", label: Translation.tr("Earth tones"), stops: ["660000", "990000", "cc3333", "cc6633", "996633", "663300",
            "666600", "999900", "cccc33", "336600"] },
        { id: "greys", label: Translation.tr("Greys"), stops: ["000000", "424153", "999999", "cccccc", "ffffff"] }]
    // Wallhaven only knows its own 29: any other colour (the shell's accent) asks for the one nearest it in OKLCH. A
    // colour with any hue matches by hue first: a pastel pink accent is pink to the eye, not the light grey nearest it.
    function nearestColour(colour: color): string {
        const lch = c => {
            const lin = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
            const r = lin(c.r), g = lin(c.g), b = lin(c.b)
            const l = Math.pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1 / 3)
            const m = Math.pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1 / 3)
            const s = Math.pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1 / 3)
            const A = 1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s
            const B = 0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s
            return { L: 0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s, C: Math.sqrt(A * A + B * B), h: Math.atan2(B, A) }
        }
        const want = lch(colour)
        const tinted = want.C >= 0.035
        let best = "", bestDistance = Infinity
        for (const hex of root.palette) {
            const have = lch(Qt.color("#" + hex))
            if (tinted !== (have.C >= 0.05)) continue
            let dh = Math.abs(want.h - have.h)
            if (dh > Math.PI) dh = 2 * Math.PI - dh
            const dl = want.L - have.L, dc = want.C - have.C
            const distance = tinted ? dh * dh + 0.5 * dl * dl + 0.2 * dc * dc : dl * dl
            if (distance < bestDistance) { bestDistance = distance; best = hex }
        }
        return best
    }
    readonly property bool sortable: root.online ? root.orderChoices.length > 0 : true
    readonly property string order: root.online ? root.onlineOrder : root.sortOrder
    readonly property var orders: root.online ? root.orderChoices : root.libraryOrderChoices
    // Wallhaven's top list narrowed by a tag or a colour is a handful (3 for "bleach" over a week, measured): there "top"
    // is the most liked of all time and the range steps aside. Konachan and yande.re rank a tag by date fine.
    readonly property bool narrowed: root.series !== null || root.pivotLabel.length > 0 || root.query.length > 0 || root.colour.length > 0
        || ((root.discoveries[root.discovery] ?? root.discoveries[0])?.tags ?? []).length > 0
    readonly property bool topNarrowed: root.provider === "wallhaven" && root.narrowed
    readonly property bool ranged: root.online && root.onlineOrder === "top" && root.provider !== "motionbgs" && !root.topNarrowed
    readonly property bool filtersShaped: root.provider === "wallhaven" || root.provider === "konachan" || root.provider === "yandere"
    readonly property int filtersOn: (root.ratio !== "screen" ? 1 : 0) + (root.colour.length > 0 ? 1 : 0)
    function setOrder(value: string): void {
        Config.setNestedValue(root.online ? "iris.wallpaper.onlineSort" : "iris.wallpaper.sort", value)
    }
    function setRange(value: string): void { Config.setNestedValue("iris.wallpaper.topRange", value) }
    function setRatio(value: string): void { Config.setNestedValue("iris.wallpaper.ratio", value) }
    function setColour(hex: string): void {
        const wanted = String(hex ?? "").replace(/^#/, "").toLowerCase()
        root.colour = root.colour === wanted ? "" : wanted
        if (root.provider !== "wallhaven" && root.colour.length > 0 && root.offered("wallhaven")) { root.setSource("wallhaven", ""); return }
        root.searchOnline(1, true)
    }
    function clearFilters(): void {
        root.colour = ""
        if (root.ratio !== "screen") root.setRatio("screen")
        else root.searchOnline(1, true)
    }
    readonly property string onlineSorting: root.onlineOrder === "top" ? (root.topNarrowed ? "favorites" : "toplist:" + root.topRange)
        : root.onlineOrder === "hot" ? "hot" : root.onlineOrder === "views" ? "views" : root.onlineOrder === "favorites" ? "favorites"
        : root.onlineOrder === "random" ? "random" : "date_added"
    onOnlineSortingChanged: if (root.open && root.online) root.searchOnline(1, true)
    onRatioChanged: if (root.open && root.online) root.searchOnline(1, true)

    // Every web source opens on its own top list, in the order and range chosen (top of the week unless changed); the
    // rest narrow it.
    readonly property var wallhavenDiscoveries: [
        { label: Translation.tr("Top"), tags: [], category: "111" },
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
        { label: Translation.tr("Top"), tags: [] },
        { label: Translation.tr("Landscape"), tags: ["landscape"] },
        { label: Translation.tr("Sky"), tags: ["sky"] },
        { label: Translation.tr("City"), tags: ["city"] },
        { label: Translation.tr("Night"), tags: ["night"] }
    ]
    readonly property var yandereDiscoveries: [
        { label: Translation.tr("Top"), tags: [] },
        { label: Translation.tr("Landscape"), tags: ["landscape"] }
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
        : root.source === "yandere" ? root.yandereDiscoveries
        : root.source === "konachan" ? root.konachanDiscoveries : []
    property var discoveryBySource: ({})
    readonly property int discovery: Number(root.discoveryBySource[root.source] ?? 0)
    // What the list shows when it is not the discovery: a tag, a colour, an uploader or "like this one".
    property string pivotLabel: ""
    function pickDiscovery(index: int): void {
        const next = Object.assign({}, root.discoveryBySource)
        next[root.source] = index
        root.discoveryBySource = next
        root.series = null
        root.pivotLabel = ""
        root.colour = ""
        root.setQuery("")
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
        root.pivotLabel = ""
        root.seriesQueries = queries.filter((entry, i) => String(entry[0]).replace(/^tag:/, "").length > 0
            && queries.findIndex(other => other[0] === entry[0]) === i)
        root.seriesAttempt = 0
        root.setQuery("")
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

    // A tag, a colour, an uploader or a picture to search from: the list turns there, the search field says so.
    property var pivotTags: []
    function pivot(label: string, tags: var): void {
        root.series = null
        root.pivotLabel = label
        root.pivotTags = tags
        root.setQuery("")
        onlineSearchDelay.stop()
        root.searchOnline(1, true)
    }
    function searchTag(tag: string): void {
        if (!root.online) return
        root.pivot("#" + tag, root.provider === "motionbgs" ? [tag] : [root.provider === "wallhaven" ? tag : tag.replace(/\s+/g, "_")])
    }
    function searchUploader(name: string): void { if (root.provider === "wallhaven" && name) root.pivot("@" + name, ["@" + name]) }
    function similar(entry: var): void {
        if (!entry || entry.provider !== "wallhaven") return
        if (root.source !== "wallhaven") root.setSource("wallhaven", "")
        root.pivot(Translation.tr("Like %1").arg(entry.id), ["like:" + entry.id])
    }
    function clearPivot(): void {
        root.pivotLabel = ""
        root.pivotTags = []
        root.searchOnline(1, true)
    }

    function setQuery(text: string): void {
        if (root.query === text) return
        root.query = text
    }
    onQueryChanged: {
        if (root.online) {
            if (root.query.length > 0) { root.series = null; root.pivotLabel = ""; root.pivotTags = [] }
            onlineSearchDelay.restart()
            return
        }
        if (root.source === "library") Wallpapers.searchQuery = root.pathMode ? "" : root.query
        root.restart()
    }

    function searchOnline(page: int, replace: bool): void {
        if (!root.online || !Network.online) return
        const option = root.discoveries[root.discovery] ?? root.discoveries[0] ?? { tags: [], category: "111" }
        const live = root.provider === "motionbgs"
        const booru = root.provider === "konachan" || root.provider === "yandere"
        const tags = root.series !== null ? (root.seriesQueries[root.seriesAttempt] ?? [])
            : root.pivotLabel.length > 0 ? root.pivotTags
            : root.query.length > 0 ? (live ? [root.query] : booru ? root.query.toLowerCase().split(/\s+/).filter(Boolean) : root.query.split(/\s+/))
            : root.colour.length > 0 ? [] : option.tags
        const asked = root.provider === "wallhaven" && !root.suggestive ? tags.concat(root.wallhavenExclusions) : tags
        if (replace) { Wallhaven.beginSearch(); root.restart() }
        const screen = root.screen
        const fit = live ? { mode: "any" }
            : root.ratio === "screen" ? { mode: "auto", width: screen?.width ?? 1920, height: screen?.height ?? 1080, ratioCode: "", aspect: (screen?.width ?? 16) / Math.max(1, screen?.height ?? 9) }
            : { mode: "any", ratios: root.ratio === "wide" ? "landscape" : root.ratio === "portrait" ? "portrait" : "" }
        if (root.colour.length > 0) fit.colors = root.colour
        Wallhaven.makeRequest(asked, false, live ? 36 : (Config.options?.sidebar?.wallhaven?.limit ?? 24), page,
            live || root.colour.length > 0 || root.pivotLabel.length > 0 ? "111" : (option.category ?? "111"), undefined, root.provider, fit,
            live ? undefined : root.onlineSorting)
    }
    function loadMore(): void {
        if (root.online && Wallhaven.runningRequests === 0 && root.onlinePage > 0 && !root.onlineExhausted)
            root.searchOnline(root.onlinePage + 1, false)
    }
    // Close to the end of what came, the next page comes.
    onSelectedIndexChanged: if (root.online && root.selectedIndex >= root.count - 4) root.loadMore()
    // Keyed on the wallpaper, not the index: a list that arrives under a resting selection is a new choice too.
    readonly property string selectedKey: String(root.selected?.key ?? "")
    onSelectedKeyChanged: {
        if (root.local) previewDelay.restart()
        detailDelay.restart()
    }
    Connections {
        target: Network
        function onOnlineChanged(): void {
            if (Network.online && root.open && root.online && root.onlineImages.length === 0) root.searchOnline(1, true)
        }
    }
    Timer { id: onlineSearchDelay; interval: 450; onTriggered: { root.series = null; root.searchOnline(1, true) } }
    // A Wallhaven result's tags and uploader come from its own page, asked once the selection rests on it.
    Timer {
        id: detailDelay
        interval: 420
        onTriggered: if (root.open && root.selected?.provider === "wallhaven" && root.selected?.web) Wallhaven.ensureWallpaperTags(root.selected.id)
    }
    readonly property var details: root.selected?.provider === "wallhaven" ? (Wallhaven.wallpaperDetails[root.selected.id] ?? null) : null

    // ── Sources and opening ──────────────────────────────────────────────
    function setSource(next: string, text): void {
        const wanted = String(text ?? "")
        if (root.source === next && wanted.length === 0) return
        onlineSearchDelay.stop()
        root.series = null
        root.pivotLabel = ""
        root.pivotTags = []
        root.source = next
        root.kind = "all"
        root.query = wanted
        onlineSearchDelay.stop()
        root.restart()
        if (root.online) {
            Wallpapers.cancelWallpaperPreview()
            AnimeService.fetchTopAiring()
            root.searchOnline(1, true)
        } else if (next === "library") {
            Wallpapers.searchQuery = root.pathMode ? "" : wanted
            root.selectCurrent()
        }
    }
    function cycleSource(step: int): void {
        const ids = root.sources.map(entry => entry.id)
        const at = Math.max(0, ids.indexOf(root.source))
        root.setSource(ids[(at + step + ids.length) % ids.length], "")
    }
    function selectCurrent(): void {
        const current = FileUtils.trimFileProtocol(String(root.currentPath ?? ""))
        const index = (root.entries ?? []).findIndex(entry => entry.path === current)
        if (index >= 0) root.selectedIndex = index
    }
    function takeRequest(): void {
        const requested = GlobalStates.wallpaperSelectorSource
        const text = GlobalStates.wallpaperSelectorQuery
        if (requested.length === 0) return
        GlobalStates.wallpaperSelectorSource = ""
        GlobalStates.wallpaperSelectorQuery = ""
        const next = !root.offered(requested) ? "library" : requested
        const wantedSeries = GlobalStates.wallpaperSelectorSeries
        if (wantedSeries !== null) {
            GlobalStates.wallpaperSelectorSeries = null
            if (root.sourceCatalog[next]) { root.setSource(next, ""); root.pickSeries(wantedSeries); return }
        }
        if (next === "library" && /^[~\/]/.test(text)) { root.setSource(next, ""); root.jumpTo(text); return }
        root.setSource(next, text)
    }
    Connections {
        target: GlobalStates
        function onWallpaperSelectorSourceChanged(): void { if (root.open) root.takeRequest() }
        function onWallpaperSelectorKindChanged(): void {
            const wanted = GlobalStates.wallpaperSelectorKind
            if (wanted.length === 0) return
            GlobalStates.wallpaperSelectorKind = ""
            root.kind = wanted
        }
        function onWallpaperSelectorMoveRequested(step: int): void { if (root.open) root.move(step) }
    }

    property bool prepared: false
    function prepare(): void {
        if (root.prepared) return
        root.prepared = true
        root.source = "library"
        root.series = null
        root.pivotLabel = ""
        root.colour = ""
        root.kind = "all"
        root.query = ""
        Wallpapers.searchQuery = ""
        const jumping = GlobalStates.wallpaperSelectorSource === "library" && /^[~\/]/.test(GlobalStates.wallpaperSelectorQuery)
        const dir = FileUtils.parentDirectory(FileUtils.trimFileProtocol(String(root.currentPath ?? ""))).replace(/\/+$/, "")
        const inLibrary = root.wallpapersHome.length > 0 && (dir === root.wallpapersHome || dir.startsWith(root.wallpapersHome + "/"))
        const start = inLibrary ? dir : root.wallpapersHome
        if (!jumping && start.length > 0 && start !== root.folderPath) Wallpapers.setDirectory(start)
        Wallpapers.generateThumbnail("large")
        root.previewArmed = false
        root.restart()
        folderRead.restart()
        root.checkPlaces()
        folderScanDelay.restart()
        root.takeRequest()
        root.selectCurrent()
    }
    onOpenChanged: {
        if (root.open) root.prepare()
        else {
            root.prepared = false
            if (!root.committing) Wallpapers.cancelWallpaperPreview()
        }
    }
    Component.onCompleted: if (root.open) root.prepare()
    Component.onDestruction: if (!root.committing) Wallpapers.cancelWallpaperPreview()

    // ── Where it lands ───────────────────────────────────────────────────
    readonly property string selectionTarget: Wallpapers.currentSelectionTarget()
    readonly property bool overviewTargetable: (Config.options?.background?.backdrop?.enable ?? true)
        && (Config.options?.panelFamily ?? "ii") !== "waffle"
    readonly property bool targetsOverview: root.selectionTarget === "backdrop"
    readonly property bool multiMonitor: Config.options?.background?.multiMonitor?.enable ?? false
    function targetOverview(overview: bool): void {
        GlobalStates.wallpaperSelectionTarget = overview ? "backdrop" : "main"
        root.previewArmed = false
        Wallpapers.cancelWallpaperPreview()
    }
    readonly property string currentPath: Wallpapers.currentWallpaperPathForTarget(root.selectionTarget, root.targetMonitor)

    readonly property bool livePreview: root.options?.livePreview ?? true
    readonly property bool previewing: root.livePreview && root.previewArmed && root.local && !root.targetsOverview
        && String(root.selected?.path ?? "").length > 0 && !(root.selected?.video ?? false) && !root.isCurrent(root.selected)
    property bool committing: false
    Timer {
        id: previewDelay
        interval: 180
        onTriggered: {
            if (!root.open || !root.local || !root.livePreview || !root.previewArmed || root.targetsOverview) return
            const path = String(root.selected?.path ?? "")
            if (!path || Wallpapers.isVideoFile(path) || path === FileUtils.trimFileProtocol(String(root.currentPath ?? ""))) Wallpapers.cancelWallpaperPreview()
            else Wallpapers.previewWallpaper(path, root.targetMonitor)
        }
    }
    onLivePreviewChanged: if (!root.livePreview) Wallpapers.cancelWallpaperPreview()

    signal finished()
    function apply(entry: var): void {
        if (!entry) return
        if (entry.path.length === 0) { root.download(entry); return }
        const target = root.selectionTarget
        root.committing = true
        Wallpapers.applySelectionTarget(entry.path, target, Appearance.m3colors.darkmode, root.targetMonitor)
        if (target === "backdrop" || target === "waffle-backdrop") Wallpapers.cancelWallpaperPreview()
        else Wallpapers.clearWallpaperPreview()
        Config.setNestedValue("wallpaperSelector.selectionTarget", "main")
        Config.setNestedValue("wallpaperSelector.targetMonitor", "")
        GlobalStates.wallpaperSelectionTarget = "main"
        GlobalStates.wallpaperSelectorTargetMonitor = ""
        root.finished()
        committingDone.restart()
    }
    Timer { id: committingDone; interval: 0; onTriggered: root.committing = false }
    function applySelected(): void { root.apply(root.selected) }
    function shuffle(): void {
        const pool = root.entries.filter(entry => entry.path.length > 0)
        const pick = pool[Math.floor(Math.random() * pool.length)]
        if (pick) root.apply(pick)
    }
    function openPage(entry: var): void {
        const url = entry?.web || entry?.page ? String(entry.page ?? "") : ""
        if (url.length > 0) Qt.openUrlExternally(url)
        else if (entry?.path) Qt.openUrlExternally("file://" + FileUtils.parentDirectory(entry.path))
    }
    function openOrigin(entry: var): void { if (entry?.origin) Qt.openUrlExternally(entry.origin) }

    // Web pictures land in the wallpapers folder, then apply.
    property string downloadingKey: ""
    readonly property real downloadProgress: download.total > 0 ? Math.min(1, download.received / download.total) : 0
    function download(entry: var): void {
        if (!entry?.web || !entry.file || download.running) return
        const folder = Directories.booruDownloads
        const live = entry.video === true
        const sharp = live && String(entry.file4k ?? "").length > 0 && String(root.options?.liveQuality ?? "best") !== "light"
        const ext = String(entry.ext || entry.file.split("?")[0].split(".").pop() || "jpg").toLowerCase()
        const name = live ? "motionbgs-" + String(entry.slug || entry.id) + (sharp ? "-4k" : "") + ".mp4"
            : entry.provider + "-" + entry.id + "." + ext
        download.entry = entry
        download.localPath = folder + "/" + name
        root.downloadingKey = entry.key
        download.total = 0
        download.received = 0
        download.command = ["/usr/bin/bash", "-c", 'mkdir -p "$1" && [ -s "$2" ] && exit 0; '
            + 'echo "total $(curl -sIL -A "$4" "$3" | tr -d "\\r" | awk \'tolower($1)=="content-length:" { n = $2 } END { print n + 0 }\')"; '
            + 'curl -fsSL -A "$4" "$3" -o "$2.part" && mv "$2.part" "$2"',
            "_", folder, download.localPath, sharp ? entry.file4k : entry.file, Wallhaven.defaultUserAgent]
        download.running = true
    }
    Process {
        id: download
        property var entry: null
        property string localPath: ""
        property real total: 0
        property real received: 0
        stdout: SplitParser {
            onRead: line => { if (line.startsWith("total ")) download.total = Number(line.slice(6)) || 0 }
        }
        onExited: exitCode => {
            root.downloadingKey = ""
            const entry = download.entry
            download.entry = null
            if (exitCode !== 0 || !entry) return
            Wallpapers.favoriteLanded(entry.key, download.localPath)
            if (root.open) root.apply(Object.assign({}, entry, { path: download.localPath }))
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

    // ── Words the layouts share ──────────────────────────────────────────
    readonly property string emptyGlyph: root.online ? "travel_explore"
        : root.source === "favorites" ? "favorite"
        : root.pathMode ? "drive_file_move"
        : root.query.length > 0 ? "search_off"
        : root.libraryFolders.length > 0 ? "folder_open" : "hide_image"
    readonly property string emptyText: root.online && !Network.online ? Network.offlineReason
        : root.online ? (root.searching ? Translation.tr("Looking for wallpapers…") : (root.onlineMessage || Translation.tr("Nothing found")))
        : root.source === "favorites" ? (root.query.length > 0 ? Translation.tr("No matches")
            : Translation.tr("Heart a wallpaper here or on the web and it waits for you in Favourites"))
        : root.pathMode ? Translation.tr("Press Enter to open %1").arg(root.query)
        : root.query.length > 0 ? Translation.tr("No matches")
        : root.libraryFolders.length > 0 ? Translation.tr("Wallpapers live in the folders above")
        : Translation.tr("No wallpapers in this folder")
    readonly property string searchHint: root.pivotLabel.length > 0 ? root.pivotLabel
        : root.source === "live" ? Translation.tr("Search live wallpapers")
        : root.online ? Translation.tr("Search %1").arg(root.sourceInfo.label)
        : root.source === "favorites" ? Translation.tr("Search favourites")
        : Translation.tr("Search in %1, or type a path").arg(root.folderName)
    readonly property string status: root.downloadingKey.length > 0
        ? (root.downloadProgress > 0 ? Translation.tr("Downloading… %1%").arg(Math.round(root.downloadProgress * 100)) : Translation.tr("Downloading…"))
        : root.online ? (root.selected ? (root.selected.video ? Translation.tr("Apply saves it and plays it on your desktop")
            : Translation.tr("Apply saves it to your wallpapers")) : "")
        : root.pathMode ? Translation.tr("Press Enter to open %1").arg(root.query)
        : root.targetsOverview ? Translation.tr("Sets the wallpaper behind the overview")
        : Wallpapers.thumbnailGenerationRunning ? Translation.tr("Preparing previews…")
        : root.previewing ? Translation.tr("Previewing on the desktop") : ""

    function megabytes(bytes: real): string {
        return bytes >= 1048576 ? (bytes / 1048576).toFixed(bytes >= 10485760 ? 0 : 1) + " MB" : Math.max(1, Math.round(bytes / 1024)) + " KB"
    }
    function compact(value: real): string {
        return value >= 1000000 ? (value / 1000000).toFixed(1).replace(/\.0$/, "") + "M"
            : value >= 1000 ? (value / 1000).toFixed(value >= 10000 ? 0 : 1).replace(/\.0$/, "") + "k" : String(Math.round(value))
    }
    // The facts an entry has, in the order they read: what it is, its size, where it came from, how liked it is.
    function facts(entry: var): var {
        if (!entry) return []
        const out = []
        out.push(entry.video ? { glyph: "motion_photos_on", label: Translation.tr("Live") + (entry.quality ? " · " + entry.quality : "") }
            : entry.gif ? { glyph: "gif_box", label: "GIF" } : { glyph: "image", label: Translation.tr("Picture") })
        if (entry.width > 0 && entry.height > 0) out.push({ label: entry.width + " × " + entry.height, figure: true })
        else if (entry.ext) out.push({ label: entry.ext, figure: true })
        if (entry.size > 0) out.push({ label: root.megabytes(entry.size), figure: true })
        if (entry.views > 0) out.push({ glyph: "visibility", label: root.compact(entry.views), figure: true, tip: Translation.tr("Views") })
        if (entry.favorites > 0) out.push({ glyph: "favorite", label: root.compact(entry.favorites), figure: true, tip: Translation.tr("Favourites") })
        if (entry.score > 0) out.push({ glyph: "arrow_upward", label: root.compact(entry.score), figure: true, tip: Translation.tr("Score") })
        // Among favourites the day it was kept says more than the file's own.
        if (entry.added > 0) out.push({ glyph: "heart_check", label: Translation.locale.toString(new Date(entry.added), "d MMM yyyy"), tip: Translation.tr("Added to favourites") })
        else if (entry.time > 0) out.push({ glyph: "calendar_today", label: Translation.locale.toString(new Date(entry.time), "d MMM yyyy") })
        return out
    }
    function providerName(id: string): string {
        return id === "motionbgs" ? "MotionBGs" : (root.sourceCatalog[id]?.label ?? id)
    }
    readonly property var categoryNames: ({ general: Translation.tr("General"), anime: Translation.tr("Anime"), people: Translation.tr("People") })
    function titleOf(entry: var): string {
        if (!entry) return ""
        if (entry.title) return entry.title
        // Wallhaven names nothing: its most fitting tag does, or its category until the page is read.
        const tag = entry.provider === "wallhaven" ? (Wallhaven.wallpaperDetails[entry.id]?.tags?.[0]?.name ?? "") : ""
        if (tag) return tag.replace(/\b\w/g, letter => letter.toUpperCase())
        if (entry.category && root.categoryNames[entry.category]) return root.categoryNames[entry.category] + " · " + entry.id
        if (entry.web) return root.providerName(entry.provider) + " · " + entry.id
        return entry.path.split("/").pop()
    }
}
