pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services
import qs.modules.common.functions
import qs.modules.iris.style
import qs.modules.background.widgets

Singleton {
    id: root

    readonly property string folder: FileUtils.trimFileProtocol(`${Directories.shellConfig}/iris/themes`)
    readonly property var excludedPaths: ["iris.bar.position", "iris.dock.launcher", "iris.appearance.surfaces.cards.header",
        "iris.appearance.surfaces.cards.devices", "iris.appearance.surfaces.cards.mixer",
        "iris.dock.magnifySize",
        "iris.bubbles.extras.anime.enable", "iris.anime.shows"]
    readonly property var extraPaths: [
        { path: "iris.appearance.preset", fallback: "iris" },
        { path: "iris.bar.composition", fallback: "cluster" },
        { path: "iris.appearance.motionDuration", fallback: 220 },
        { path: "iris.lock.material", fallback: "glass" },
        { path: "iris.lock.type.clockWeight", fallback: 700 },
        { path: "iris.lock.type.clockTracking", fallback: -2 },
        { path: "iris.lock.type.accent", fallback: "plain" }
    ]
    readonly property var paths: {
        const seen = new Set()
        const out = []
        for (const entry of root.extraPaths) { seen.add(entry.path); out.push(entry) }
        for (const spec of IrisOptions.studio) {
            const path = String(spec.path ?? "")
            if (!path.startsWith("iris.") || spec.kind === "pieces" || spec.fallback === undefined) continue
            if (seen.has(path) || root.excludedPaths.includes(path)) continue
            seen.add(path)
            out.push({ path: path, fallback: spec.fallback })
        }
        return out
    }
    readonly property var pathSet: new Set(root.paths.map(entry => entry.path))
    function owns(path: string): bool { return root.pathSet.has(path) }

    function resolved(values: var): var {
        const out = {}
        for (const entry of root.paths)
            out[entry.path] = Object.prototype.hasOwnProperty.call(values ?? {}, entry.path) ? values[entry.path] : entry.fallback
        return out
    }
    function current(): var {
        const out = {}
        for (const entry of root.paths) out[entry.path] = IrisOptions.plain(Config.getNestedValue(entry.path, entry.fallback))
        return out
    }
    function differences(values: var): var {
        const out = {}
        for (const entry of root.paths)
            if (!IrisOptions.same(values[entry.path], entry.fallback)) out[entry.path] = values[entry.path]
        return out
    }
    function apply(theme: var): void {
        if (!theme) return
        const updates = root.resolved(theme.values)
        // The widget design goes through its owner so every widget follows the theme and the looks
        // it replaces can be undone.
        const design = String(updates["iris.widgets.design"] ?? "iris")
        delete updates["iris.widgets.design"]
        updates["iris.appearance.themeId"] = String(theme.id ?? "")
        Config.setNestedValues(updates)
        DesktopWidgetDesign.apply(design)
    }
    // A theme's palette alone: what it colours, never how anything is shaped, laid out or moves.
    readonly property var colourPaths: ["iris.appearance.accent", "iris.appearance.highlight", "iris.appearance.theme.accentHue",
        "iris.appearance.theme.highlightHue", "iris.appearance.theme.surface", "iris.appearance.theme.badge", "iris.appearance.aura",
        "iris.appearance.theme.lightReach", "iris.appearance.theme.glow", "iris.appearance.tint", "iris.appearance.theme.rimTint",
        "iris.appearance.glass.edgeColour", "iris.bar.clockAccent", "iris.controlCenter.accent", "iris.controlCenter.sliders",
        "iris.lock.type.accent", "iris.appearance.anime.enabled", "iris.appearance.anime.palette", "iris.appearance.anime.strength",
        "iris.appearance.anime.highlight", "iris.widgets.tint"]
    function applyColours(theme: var): void {
        if (!theme) return
        const all = root.resolved(theme.values)
        const updates = {}
        for (const path of root.colourPaths) if (Object.prototype.hasOwnProperty.call(all, path)) updates[path] = all[path]
        Config.setNestedValues(updates)
    }
    readonly property bool coloursOnly: Boolean(Config.options?.iris?.appearance?.themeColoursOnly ?? false)
    // What choosing a theme does, as the person set it: the whole theme, or its colours.
    function choose(theme: var): void {
        if (root.coloursOnly) root.applyColours(theme)
        else root.apply(theme)
    }
    function find(id: string): var {
        return root.all.find(theme => theme.id === id) ?? null
    }
    readonly property string activeId: String(Config.options?.iris?.appearance?.themeId ?? "iris")
    readonly property var active: root.find(root.activeId)
    readonly property bool modified: {
        void Config.revision
        if (!root.active) return true
        const wanted = root.resolved(root.active.values)
        for (const entry of root.paths)
            if (!IrisOptions.same(Config.getNestedValue(entry.path, entry.fallback), wanted[entry.path])) return true
        return false
    }

    function slug(name: string): string {
        const base = String(name).toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "")
            .replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
        return base.length > 0 ? base.slice(0, 48) : "theme"
    }
    function document(theme: var): var {
        return { iris: "theme", version: 1, id: theme.id, name: theme.name, author: theme.author ?? "",
            description: theme.description ?? "", values: root.differences(root.resolved(theme.values)) }
    }
    function exportText(theme: var): string { return JSON.stringify(root.document(theme), null, 2) }
    function parse(text: string, fallbackId: string): var {
        let data = null
        try { data = JSON.parse(String(text).trim()) } catch (error) { return null }
        if (!data || (data.iris !== "theme" && data.iris !== "look") || typeof data.values !== "object") return null
        const values = {}
        for (const path of Object.keys(data.values)) if (root.owns(path)) values[path] = data.values[path]
        const name = String(data.name ?? "").trim() || Translation.tr("Imported theme")
        return { id: fallbackId.length > 0 ? fallbackId : root.slug(String(data.id ?? name)), name: name,
            author: String(data.author ?? ""), description: String(data.description ?? ""), values: values, user: true }
    }
    function uniqueId(base: string): string {
        let id = base
        let n = 2
        while (root.curated.some(theme => theme.id === id) || root.user.some(theme => theme.id === id && theme.id !== base)) id = `${base}-${n++}`
        return root.curated.some(theme => theme.id === id) ? `${base}-mine` : id
    }
    function save(name: string, description: string): string {
        const clean = String(name).trim() || Translation.tr("My theme %1").arg(root.user.length + 1)
        const id = root.uniqueId(root.slug(clean))
        const theme = { id: id, name: clean, author: Quickshell.env("USER") ?? "", description: String(description ?? "").trim(),
            values: root.differences(root.current()) }
        root.write(theme)
        Config.setNestedValue("iris.appearance.themeId", id)
        return id
    }
    function importText(text: string): var {
        const theme = root.parse(text, "")
        if (!theme) return null
        theme.id = root.uniqueId(theme.id)
        root.write(theme)
        return theme
    }
    function importFile(path: string): void {
        importer.command = ["cat", FileUtils.trimFileProtocol(path)]
        importer.running = true
    }
    function remove(id: string): void {
        if (!root.user.some(theme => theme.id === id)) return
        writer.exec(["rm", "-f", `${root.folder}/${id}.json`])
    }
    function reveal(): void {
        Quickshell.execDetached(["bash", "-c", 'mkdir -p "$1" && xdg-open "$1"', "reveal", root.folder])
    }
    function write(theme: var): void { root.writeAll([theme]) }
    function writeAll(themes: var): void {
        const args = []
        for (const theme of themes) args.push(theme.id, root.exportText(theme))
        writer.exec(["python3", "-c", "import os,sys\nd=sys.argv[1]\nos.makedirs(d,exist_ok=True)\na=sys.argv[2:]\nfor i in range(0,len(a),2): open(os.path.join(d,a[i]+'.json'),'w',encoding='utf-8').write(a[i+1]+'\\n')",
            root.folder].concat(args))
    }
    signal imported(var theme)
    Process {
        id: importer
        stdout: StdioCollector {
            id: importedText
            onStreamFinished: {
                const theme = root.importText(importedText.text)
                root.imported(theme)
            }
        }
    }
    Process {
        id: writer
        onExited: root.reload()
    }

    // A theme installed or removed from the community hub is one more user theme.
    Connections {
        target: Hub
        function onChanged(kind: string, id: string): void {
            if (kind === "iris-theme")
                root.reload()
        }
    }

    property var user: []
    function reload(): void {
        loader.running = false
        loader.running = true
    }
    Process {
        id: loader
        command: ["python3", "-c", "import os,sys,json\nd=sys.argv[1]\nout=[]\nfor f in sorted(os.listdir(d)) if os.path.isdir(d) else []:\n  if f.endswith('.json'):\n    try: out.append([f[:-5], open(os.path.join(d,f),encoding='utf-8').read()])\n    except Exception: pass\nprint(json.dumps(out))",
            root.folder]
        stdout: StdioCollector {
            id: listing
            onStreamFinished: {
                let rows = []
                try { rows = JSON.parse(listing.text) } catch (error) { rows = [] }
                root.user = rows.map(row => root.parse(row[1], row[0])).filter(theme => theme !== null)
            }
        }
    }
    FolderListModel {
        id: watcher
        folder: `file://${root.folder}`
        nameFilters: ["*.json"]
        showDirs: false
        onCountChanged: root.reload()
    }
    Component.onCompleted: {
        root.reload()
        root.migrateSaved()
    }
    function migrateSaved(): void {
        const saved = Array.from(Config.options?.iris?.appearance?.saved ?? [])
        if (saved.length === 0) return
        const themes = []
        for (const entry of saved) {
            const theme = root.parse(JSON.stringify({ iris: "look", name: entry?.name, values: entry?.values ?? {} }), "")
            if (!theme) continue
            theme.id = root.uniqueId(theme.id)
            if (!themes.some(other => other.id === theme.id)) themes.push(theme)
        }
        if (themes.length > 0) root.writeAll(themes)
        Config.setNestedValue("iris.appearance.saved", [])
    }

    readonly property var all: root.curated.concat(root.user)

    function swatch(theme: var): var {
        const v = root.resolved(theme?.values ?? {})
        const baseAccent = IrisStyle.accentFrom(String(v["iris.appearance.accent"] ?? "blue"), v["iris.appearance.theme.accentHue"])
        const animeOn = Boolean(v["iris.appearance.anime.enabled"] ?? false)
        const animePalette = String(v["iris.appearance.anime.palette"] ?? "sakura")
        const animeStrength = Number(v["iris.appearance.anime.strength"] ?? 0) / 100
        const accent = animeOn ? IrisStyle.animeAccent(baseAccent, animePalette, animeStrength) : baseAccent
        const baseHighlight = IrisStyle.highlightFrom(String(v["iris.appearance.highlight"] ?? "orange"), v["iris.appearance.theme.highlightHue"], baseAccent)
        const highlight = animeOn && Boolean(v["iris.appearance.anime.highlight"] ?? false)
            ? IrisStyle.animeHighlight(baseHighlight, animePalette, animeStrength) : baseHighlight
        const preset = IrisStyle.presets[v["iris.appearance.preset"]] ?? IrisStyle.presets.iris
        return {
            surface: IrisStyle.materialSwatch(String(v["iris.appearance.theme.surface"])),
            accent: accent,
            highlight: highlight,
            glass: v["iris.appearance.glass.mode"] !== "off",
            tint: Number(v["iris.appearance.glass.tint"]) / 100,
            shape: preset.shape * Number(v["iris.appearance.theme.shape"]) / 100,
            pieceShape: String(v["iris.appearance.theme.pieceShape"]),
            lines: Number(v["iris.appearance.theme.lines"]) / 100,
            rim: Boolean(v["iris.appearance.theme.rim"]),
            titleFont: IrisStyle.face("iris.appearance.titleFontFamily", v["iris.appearance.titleFontFamily"]),
            numbersFont: IrisStyle.face("iris.appearance.numbersFontFamily", v["iris.appearance.numbersFontFamily"]),
            figureWeight: ({ light: Font.Light, regular: Font.Normal })[v["iris.appearance.figureWeight"]] ?? Font.Bold,
            framed: Boolean(v["iris.surround.enable"]),
            notch: Boolean(v["iris.bar.notch"]),
            dockNotch: Boolean(v["iris.dock.notch"]),
            dockPosition: String(v["iris.dock.position"] ?? "auto"),
            layout: String(v["iris.bar.layout"]),
            clearStrip: String(v["iris.bar.strip"] ?? "clear") === "clear",
            clockAccent: String(v["iris.bar.clockAccent"])
        }
    }

    readonly property string a: "iris.appearance."
    readonly property string t: "iris.appearance.theme."
    function values(pairs: var): var {
        const out = {}
        for (const key of Object.keys(pairs)) {
            const path = key.startsWith("iris.") ? key : key.startsWith("theme.") ? root.a + key : key.startsWith("glass.") || key.startsWith("surfaces.") ? root.a + key : key
            out[path] = pairs[key]
        }
        return out
    }
    readonly property var curated: [
        { id: "iris", name: "iRiS", author: "iNiR", tags: ["dark", "direct"],
            values: ({}) },
        { id: "liquid-glass", name: "Liquid Glass", author: "iNiR", tags: ["glass", "round", "springy"],
            values: root.values({ "iris.lock.material": "glass", "iris.lock.type.clockWeight": 300, "iris.lock.type.clockTracking": -2, "iris.lock.type.accent": "plain", "iris.controlCenter.accent": "accent", "iris.controlCenter.sliders": "neutral", "glass.mode": "wallpaper", "glass.tint": 42, "glass.blur": 100, "theme.rim": false, "iris.appearance.preset": "round",
                "theme.shape": 115, "theme.melt": 55, "theme.lines": 0, "theme.shadow": 110, "theme.glow": 20, "iris.appearance.aura": "vivid",
                "theme.lightReach": 170, "iris.appearance.accent": "wallpaper", "iris.appearance.highlight": "wallpaper",
                "iris.appearance.fontFamily": "Roboto Flex", "iris.appearance.numbersFontFamily": "Roboto Flex", "iris.appearance.figureWeight": "light",
                "iris.appearance.morph": "liquid", "theme.bounce": 120, "iris.bar.notch": true, "iris.bar.height": 44, "iris.bar.satelliteGap": 8,
                "iris.bubbles.scale": 108, "iris.surround.thickness": 8, "iris.surround.radius": 30, "iris.palette.opens": "island",
                "iris.controlCenter.controls": "round", "iris.widgets.material": "glass", "iris.widgets.radius": 30, "iris.widgets.weight": "light",
                "iris.dock.material": "inherit", "iris.dock.magnification": false, "iris.dock.iconSize": 44 }) },
        { id: "frost", name: "Frost", author: "iNiR", tags: ["glass", "bar", "calm"],
            values: root.values({ "iris.lock.material": "glass", "iris.lock.type.clockWeight": 300, "iris.lock.type.clockTracking": -1, "iris.lock.type.accent": "accent", "iris.controlCenter.accent": "accent", "iris.controlCenter.sliders": "accent", "glass.mode": "wallpaper", "glass.tint": 56, "glass.blur": 100, "theme.surface": "graphite", "theme.rim": false,
                "iris.appearance.preset": "soft", "theme.lines": 35, "theme.shadow": 80, "theme.melt": 15, "iris.appearance.accent": "custom",
                "theme.accentHue": 196, "iris.appearance.highlight": "custom", "theme.highlightHue": 188, "iris.appearance.aura": "subtle",
                "iris.appearance.morph": "glide", "theme.curve": "gentle", "theme.openTime": 115, "iris.appearance.figureWeight": "light",
                "iris.appearance.fontFamily": "Roboto Flex", "iris.appearance.numbersFontFamily": "Roboto Flex", "iris.appearance.titleFontFamily": "Roboto Flex",
                "iris.bar.layout": "full", "iris.bar.notch": true, "iris.bar.height": 38, "iris.bar.composition": "unified", "iris.bar.clockStyle": "time",
                "iris.bar.clockAccent": "accent", "iris.surround.enable": false, "iris.widgets.material": "glass", "iris.widgets.radius": 18,
                "iris.widgets.weight": "light", "iris.dock.notch": false, "iris.dock.iconSize": 38, "iris.dock.magnification": false,
                "iris.controlCenter.controls": "round" }) },
        { id: "obsidian", name: "Obsidian", author: "iNiR", tags: ["sharp", "technical"],
            values: root.values({ "iris.lock.material": "tint", "iris.lock.type.clockWeight": 600, "iris.lock.type.clockTracking": -4, "iris.lock.type.accent": "plain", "iris.controlCenter.accent": "accent", "iris.controlCenter.sliders": "neutral", "iris.appearance.preset": "angular", "theme.shape": 70, "theme.pieceShape": "squircle", "theme.surface": "black",
                "theme.lines": 130, "theme.rim": false, "theme.shadow": 150, "theme.fill": 115, "iris.dock.notch": false,
                "iris.appearance.aura": "off", "iris.appearance.accent": "lilac", "iris.appearance.highlight": "accent",
                "theme.badge": "accent", "iris.appearance.morph": "snap", "theme.curve": "swift", "theme.openTime": 80, "theme.press": 60,
                "iris.appearance.fontFamily": "Space Grotesk", "iris.appearance.titleFontFamily": "Space Grotesk", "iris.appearance.numbersFontFamily": "Space Grotesk",
                "iris.appearance.figureWeight": "regular", "iris.surround.thickness": 14, "iris.surround.radius": 8, "iris.bar.layout": "left",
                "iris.bar.margin": 12, "iris.bar.notchCurve": 55, "iris.bar.clockAccent": "plain", "iris.bar.clockStyle": "time", "iris.bar.blockStyle": "grouped",
                "iris.controlCenter.controls": "tiles", "iris.widgets.material": "solid", "iris.widgets.radius": 6, "iris.widgets.weight": "regular",
                "iris.dock.material": "solid", "iris.dock.iconSize": 40 , "iris.appearance.expandedRadius": 16}) },
        { id: "aurora", name: "Aurora", author: "iNiR", tags: ["wallpaper", "vivid", "soft"],
            values: root.values({ "iris.lock.material": "glass", "iris.lock.type.clockWeight": 200, "iris.lock.type.clockTracking": -2, "iris.lock.type.accent": "accent", "iris.controlCenter.accent": "colourful", "iris.controlCenter.sliders": "accent", "theme.surface": "wallpaper", "theme.rim": false, "glass.mode": "wallpaper", "glass.tint": 44, "iris.appearance.tint": 60,
                "iris.appearance.aura": "vivid", "theme.lightReach": 260, "theme.glow": 20, "iris.appearance.accent": "wallpaper",
                "iris.appearance.highlight": "wallpaper", "iris.appearance.preset": "soft", "theme.shape": 125, "theme.melt": 60, "theme.lines": 0,
                "iris.appearance.morph": "glide", "theme.curve": "gentle", "theme.openTime": 130, "iris.appearance.titleFontFamily": "Gabarito",
                "iris.appearance.figureWeight": "light", "iris.bar.clockScale": 118, "iris.bar.height": 46, "iris.bar.desktopBanner": "wallpaper",
                "iris.surround.thickness": 12, "iris.surround.radius": 34, "iris.widgets.material": "clear", "iris.widgets.weight": "light",
                "iris.widgets.radius": 34, "iris.dock.magnification": false, "iris.palette.opens": "island" }) },
        { id: "terminal", name: "Terminal", author: "iNiR", tags: ["mono", "brutalist", "bar"],
            values: root.values({ "iris.lock.material": "none", "iris.lock.type.clockWeight": 400, "iris.lock.type.clockTracking": 0, "iris.lock.type.accent": "accent", "iris.controlCenter.accent": "accent", "iris.controlCenter.sliders": "accent", "iris.appearance.fontFamily": "JetBrainsMono Nerd Font", "iris.appearance.titleFontFamily": "JetBrainsMono Nerd Font",
                "iris.appearance.numbersFontFamily": "JetBrainsMono Nerd Font", "iris.appearance.figureWeight": "regular",
                "iris.appearance.preset": "angular", "theme.shape": 35, "theme.pieceShape": "square", "theme.lines": 200,
                "theme.fill": 70, "theme.shadow": 0, "theme.rim": false, "iris.bubbles.join": "weld", "iris.appearance.aura": "off",
                "iris.appearance.accent": "custom", "theme.accentHue": 135, "iris.appearance.highlight": "green", "theme.badge": "highlight",
                "iris.appearance.morph": "snap", "theme.bounce": 0, "theme.curve": "standard", "theme.openTime": 65,
                "theme.moveTime": 70, "theme.press": 30, "theme.text": 95, "theme.contrast": 125,
                "iris.bar.layout": "full", "iris.bar.notch": false, "iris.bar.composition": "unified", "iris.bar.clockStyle": "time",
                "iris.bar.clockAccent": "accent", "iris.bar.height": 34, "iris.surround.thickness": 4, "iris.surround.radius": 0,
                "iris.widgets.material": "solid", "iris.widgets.weight": "regular", "iris.widgets.radius": 0, "iris.dock.material": "solid",
                "iris.dock.notch": false, "iris.dock.iconSize": 34, "iris.controlCenter.controls": "tiles", "iris.palette.opens": "floating",
                "iris.wallpaper.layout": "wall" , "iris.appearance.expandedRadius": 16}) },
        { id: "neo-tokyo", name: "Neo Tokyo", author: "iNiR", tags: ["anime", "neon", "glass", "sci-fi"],
            values: root.values({ "iris.lock.material": "glass", "iris.lock.type.clockWeight": 600, "iris.lock.type.clockTracking": -1, "iris.lock.type.accent": "accent", "iris.controlCenter.accent": "colourful", "iris.controlCenter.sliders": "accent", "theme.surface": "midnight", "glass.mode": "wallpaper", "glass.tint": 58, "iris.appearance.preset": "crisp",
                "theme.shape": 90, "theme.pieceShape": "squircle", "theme.lines": 120, "theme.shadow": 160, "theme.glow": 55,
                "iris.appearance.accent": "custom", "theme.accentHue": 186, "iris.appearance.highlight": "custom", "theme.highlightHue": 312,
                "iris.appearance.aura": "vivid", "theme.lightReach": 210, "theme.badge": "highlight", "iris.appearance.titleFontFamily": "Oxanium",
                "iris.appearance.numbersFontFamily": "Oxanium", "iris.appearance.morph": "elastic", "theme.bounce": 80, "iris.bar.clockScale": 110,
                "iris.appearance.glass.edgeColour": "accent", "iris.appearance.glass.edgeLight": 70, "iris.appearance.glass.edgeLine": 22, "iris.surround.thickness": 12, "iris.surround.radius": 16,
                "iris.widgets.material": "tinted", "iris.widgets.radius": 14, "iris.widgets.weight": "bold", "theme.rim": false,
                "iris.dock.notch": false, "iris.dock.material": "glass", "iris.dock.magnification": false }) },
        { id: "afterglow", name: "Afterglow", author: "iNiR", tags: ["retro", "amber", "chrome", "bloom", "crt"],
            values: root.values({ "iris.appearance.texture": "afterglow", "iris.appearance.afterglow.grade": "dusk", "iris.appearance.afterglow.atmosphere": 75,
                "iris.appearance.afterglow.chrome": 70, "iris.appearance.afterglow.bloom": 60, "iris.appearance.afterglow.signal": 40, "iris.appearance.afterglow.wallpaper": true,
                "iris.lock.material": "tint", "iris.lock.type.clockWeight": 700, "iris.lock.type.clockTracking": -1, "iris.lock.type.accent": "accent",
                "iris.controlCenter.accent": "accent", "iris.controlCenter.sliders": "accent", "theme.surface": "black", "glass.mode": "off",
                "iris.appearance.preset": "crisp", "theme.shape": 85, "theme.pieceShape": "squircle", "theme.lines": 60, "theme.glow": 40, "theme.shadow": 120,
                "iris.appearance.accent": "custom", "theme.accentHue": 32, "iris.appearance.highlight": "custom", "theme.highlightHue": 170, "theme.badge": "highlight",
                "iris.appearance.aura": "vivid", "theme.lightReach": 190, "iris.appearance.titleFontFamily": "Oxanium", "iris.appearance.numbersFontFamily": "Oxanium",
                "iris.appearance.figureWeight": "bold", "iris.appearance.morph": "snap", "theme.openTime": 90, "iris.bar.clockAccent": "accent", "iris.bar.clockScale": 110,
                "iris.surround.thickness": 10, "iris.surround.radius": 18, "iris.widgets.material": "tinted", "iris.widgets.radius": 14, "iris.widgets.weight": "bold",
                "iris.dock.material": "inherit", "iris.dock.magnification": false, "iris.controlCenter.controls": "tiles" }) },
        { id: "y2k", name: "Y2K", author: "iNiR", tags: ["retro", "ice", "lime", "chrome", "glass"],
            values: root.values({ "iris.appearance.texture": "afterglow", "iris.appearance.afterglow.grade": "cyber", "iris.appearance.afterglow.atmosphere": 65,
                "iris.appearance.afterglow.chrome": 90, "iris.appearance.afterglow.bloom": 55, "iris.appearance.afterglow.signal": 25, "iris.appearance.afterglow.wallpaper": true,
                "iris.lock.material": "glass", "iris.lock.type.clockWeight": 600, "iris.lock.type.clockTracking": -1, "iris.lock.type.accent": "highlight",
                "iris.controlCenter.accent": "accent", "iris.controlCenter.sliders": "accent", "theme.surface": "midnight", "glass.mode": "wallpaper", "glass.tint": 64,
                "iris.appearance.preset": "round", "theme.shape": 120, "theme.pieceShape": "circle", "theme.lines": 40, "theme.glow": 50,
                "iris.appearance.accent": "custom", "theme.accentHue": 198, "iris.appearance.highlight": "custom", "theme.highlightHue": 86, "theme.badge": "highlight",
                "iris.appearance.aura": "subtle", "theme.lightReach": 160, "iris.appearance.titleFontFamily": "Oxanium", "iris.appearance.numbersFontFamily": "Oxanium",
                "iris.appearance.figureWeight": "regular", "iris.appearance.morph": "liquid", "theme.bounce": 90, "iris.bar.clockAccent": "highlight",
                "iris.surround.thickness": 10, "iris.surround.radius": 30, "iris.widgets.material": "glass", "iris.widgets.radius": 26, "iris.widgets.weight": "regular",
                "iris.dock.material": "inherit", "iris.dock.magnification": false, "iris.controlCenter.controls": "round" }) },
        { id: "faded-light", name: "Faded Light", author: "iNiR", tags: ["analog", "film", "prism", "grain", "mono"],
            values: root.values({ "iris.appearance.texture": "leak", "iris.appearance.leak.grade": "prism", "iris.appearance.leak.shape": "lens", "iris.appearance.leak.light": 65,
                "iris.appearance.leak.spill": 60, "iris.appearance.leak.prism": 60, "iris.appearance.leak.grain": 50, "iris.appearance.leak.streaks": 0, "iris.appearance.leak.backdrop": "light", "iris.appearance.leak.wallpaper": 55,
                "iris.lock.material": "tint", "iris.lock.type.clockWeight": 400, "iris.lock.type.clockTracking": 0, "iris.lock.type.accent": "highlight",
                "iris.controlCenter.accent": "accent", "iris.controlCenter.sliders": "accent", "theme.surface": "black", "glass.mode": "off",
                "iris.appearance.preset": "iris", "theme.lines": 50, "theme.glow": 45, "theme.shadow": 100,
                "iris.appearance.accent": "custom", "theme.accentHue": 252, "iris.appearance.highlight": "custom", "theme.highlightHue": 188, "theme.badge": "highlight",
                "iris.appearance.aura": "subtle", "iris.appearance.fontFamily": "JetBrainsMono Nerd Font", "iris.appearance.titleFontFamily": "JetBrainsMono Nerd Font", "iris.appearance.numbersFontFamily": "JetBrainsMono Nerd Font",
                "iris.appearance.figureWeight": "regular", "iris.appearance.morph": "liquid", "iris.bar.clockAccent": "highlight",
                "iris.widgets.material": "tinted", "iris.widgets.weight": "regular", "iris.dock.material": "inherit", "iris.controlCenter.controls": "tiles" }) },
        { id: "film-burn", name: "Film Burn", author: "iNiR", tags: ["analog", "film", "ember", "streaks", "warm"],
            values: root.values({ "iris.appearance.texture": "leak", "iris.appearance.leak.grade": "ember", "iris.appearance.leak.shape": "burn", "iris.appearance.leak.light": 70,
                "iris.appearance.leak.spill": 60, "iris.appearance.leak.prism": 35, "iris.appearance.leak.grain": 55, "iris.appearance.leak.streaks": 65, "iris.appearance.leak.backdrop": "picture", "iris.appearance.leak.wallpaper": 70,
                "iris.lock.material": "tint", "iris.lock.type.clockWeight": 700, "iris.lock.type.clockTracking": -1, "iris.lock.type.accent": "accent",
                "iris.controlCenter.accent": "accent", "iris.controlCenter.sliders": "accent", "theme.surface": "black", "glass.mode": "off",
                "iris.appearance.preset": "crisp", "theme.lines": 50, "theme.glow": 45, "theme.shadow": 110,
                "iris.appearance.accent": "custom", "theme.accentHue": 26, "iris.appearance.highlight": "custom", "theme.highlightHue": 44, "theme.badge": "accent",
                "iris.appearance.aura": "vivid", "iris.appearance.titleFontFamily": "Space Grotesk", "iris.appearance.numbersFontFamily": "Space Grotesk",
                "iris.appearance.figureWeight": "bold", "iris.appearance.morph": "snap", "iris.bar.clockAccent": "accent",
                "iris.widgets.material": "tinted", "iris.widgets.weight": "bold", "iris.dock.material": "inherit", "iris.controlCenter.controls": "tiles" }) },
        { id: "grain-orb", name: "Grain Orb", author: "iNiR", tags: ["analog", "grain", "gradient", "pink", "soft"],
            values: root.values({ "iris.appearance.texture": "leak", "iris.appearance.leak.grade": "orchid", "iris.appearance.leak.shape": "orbs", "iris.appearance.leak.light": 65,
                "iris.appearance.leak.spill": 55, "iris.appearance.leak.prism": 30, "iris.appearance.leak.grain": 70, "iris.appearance.leak.streaks": 0, "iris.appearance.leak.backdrop": "light", "iris.appearance.leak.wallpaper": 60,
                "iris.lock.material": "tint", "iris.lock.type.clockWeight": 300, "iris.lock.type.clockTracking": -2, "iris.lock.type.accent": "accent",
                "iris.controlCenter.accent": "accent", "iris.controlCenter.sliders": "accent", "theme.surface": "black", "glass.mode": "off",
                "iris.appearance.preset": "soft", "theme.lines": 40, "theme.glow": 50, "theme.shadow": 100,
                "iris.appearance.accent": "custom", "theme.accentHue": 326, "iris.appearance.highlight": "custom", "theme.highlightHue": 250, "theme.badge": "accent",
                "iris.appearance.aura": "vivid", "iris.appearance.figureWeight": "light", "iris.appearance.morph": "liquid", "iris.bar.clockAccent": "accent",
                "iris.widgets.material": "tinted", "iris.widgets.weight": "regular", "iris.dock.material": "inherit", "iris.controlCenter.controls": "round" }) },
        { id: "polaroid", name: "Polaroid", author: "iNiR", tags: ["analog", "film", "flash", "beam", "mono"],
            values: root.values({ "iris.appearance.texture": "leak", "iris.appearance.leak.grade": "polaroid", "iris.appearance.leak.shape": "beam", "iris.appearance.leak.light": 65,
                "iris.appearance.leak.spill": 55, "iris.appearance.leak.prism": 55, "iris.appearance.leak.grain": 60, "iris.appearance.leak.streaks": 25, "iris.appearance.leak.backdrop": "picture", "iris.appearance.leak.wallpaper": 65,
                "iris.lock.material": "tint", "iris.lock.type.clockWeight": 500, "iris.lock.type.clockTracking": 0, "iris.lock.type.accent": "highlight",
                "iris.controlCenter.accent": "accent", "iris.controlCenter.sliders": "accent", "theme.surface": "black", "glass.mode": "off",
                "iris.appearance.preset": "iris", "theme.lines": 50, "theme.glow": 45, "theme.shadow": 100,
                "iris.appearance.accent": "custom", "theme.accentHue": 18, "iris.appearance.highlight": "custom", "theme.highlightHue": 196, "theme.badge": "highlight",
                "iris.appearance.aura": "subtle", "iris.appearance.fontFamily": "JetBrainsMono Nerd Font", "iris.appearance.titleFontFamily": "JetBrainsMono Nerd Font", "iris.appearance.numbersFontFamily": "JetBrainsMono Nerd Font",
                "iris.appearance.figureWeight": "regular", "iris.appearance.morph": "snap", "iris.bar.clockAccent": "highlight",
                "iris.widgets.material": "tinted", "iris.widgets.weight": "regular", "iris.dock.material": "inherit", "iris.controlCenter.controls": "tiles" }) },
        { id: "twilight", name: "Twilight", author: "iNiR", tags: ["anime", "dusk", "glass", "menu bar"],
            values: root.values({ "iris.lock.material": "glass", "iris.lock.type.clockWeight": 300, "iris.lock.type.clockTracking": -2, "iris.lock.type.accent": "highlight", "iris.controlCenter.accent": "accent", "iris.controlCenter.sliders": "accent", "theme.surface": "midnight", "glass.mode": "wallpaper", "glass.tint": 52, "glass.blur": 100, "theme.rim": false,
                "iris.appearance.preset": "soft", "theme.shape": 115, "theme.melt": 70, "theme.lines": 25, "theme.shadow": 110, "theme.glow": 35,
                "iris.appearance.accent": "custom", "theme.accentHue": 24, "iris.appearance.highlight": "custom", "theme.highlightHue": 262,
                "iris.appearance.aura": "vivid", "theme.lightReach": 170, "iris.appearance.morph": "glide", "theme.curve": "gentle", "theme.openTime": 115,
                "iris.appearance.figureWeight": "light", "iris.bar.layout": "menubar", "iris.bar.strip": "clear", "iris.bar.notch": true, "iris.bar.height": 40,
                "iris.bar.composition": "unified", "iris.bar.clockAccent": "accent", "iris.surround.enable": false,
                "iris.widgets.material": "glass", "iris.widgets.radius": 24, "iris.widgets.weight": "light",
                "iris.dock.notch": false, "iris.dock.material": "glass", "iris.dock.iconSize": 42, "iris.dock.magnification": false,
                "iris.controlCenter.controls": "round" }) },
        { id: "daybreak", name: "Daybreak", author: "iNiR", tags: ["glass", "calm", "menu bar"],
            values: root.values({ "iris.lock.material": "glass", "iris.lock.type.clockWeight": 300, "iris.lock.type.clockTracking": -2, "iris.lock.type.accent": "accent", "iris.controlCenter.accent": "accent", "iris.controlCenter.sliders": "accent", "theme.surface": "graphite", "glass.mode": "wallpaper", "glass.tint": 66, "glass.blur": 100, "theme.rim": false,
                "iris.appearance.preset": "soft", "theme.lines": 20, "theme.shadow": 90, "theme.melt": 40, "iris.appearance.accent": "custom",
                "theme.accentHue": 205, "iris.appearance.highlight": "custom", "theme.highlightHue": 38, "iris.appearance.aura": "subtle",
                "iris.appearance.morph": "glide", "theme.curve": "gentle", "theme.openTime": 105, "iris.appearance.figureWeight": "regular",
                "iris.bar.layout": "menubar", "iris.bar.strip": "clear", "iris.bar.notch": true, "iris.bar.height": 38, "iris.bar.composition": "unified",
                "iris.bar.clockStyle": "dateTime", "iris.bar.clockAccent": "highlight", "iris.surround.enable": false,
                "iris.widgets.material": "glass", "iris.widgets.radius": 22, "iris.widgets.weight": "regular",
                "iris.dock.notch": false, "iris.dock.material": "glass", "iris.dock.iconSize": 44, "iris.dock.magnification": false,
                "iris.controlCenter.controls": "round" }) },
        { id: "horizon", name: "Horizon", author: "iNiR", tags: ["dark", "bar", "direct"],
            values: root.values({ "iris.lock.material": "tint", "iris.lock.type.clockWeight": 600, "iris.lock.type.clockTracking": -3, "iris.lock.type.accent": "highlight", "iris.controlCenter.accent": "system", "iris.controlCenter.sliders": "neutral", "theme.surface": "black", "glass.mode": "off", "theme.rim": false,
                "iris.appearance.preset": "iris", "iris.appearance.accent": "blue", "iris.appearance.highlight": "orange", "theme.badge": "alert", "iris.appearance.aura": "subtle",
                "iris.bar.layout": "full", "iris.bar.notch": true, "iris.bar.height": 40, "iris.bar.composition": "unified",
                "iris.bar.clockStyle": "dateTime", "iris.bar.clockAccent": "highlight", "iris.surround.enable": true, "iris.surround.thickness": 10,
                "iris.surround.radius": 22, "iris.widgets.material": "solid", "iris.widgets.radius": 22, "iris.widgets.weight": "regular",
                "iris.dock.notch": true, "iris.dock.material": "solid", "iris.dock.iconSize": 44, "iris.dock.magnification": false,
                "iris.controlCenter.controls": "tiles" }) },
        { id: "monolith", name: "Monolith", author: "iNiR", tags: ["minimal", "quiet"],
            values: root.values({ "iris.lock.material": "none", "iris.lock.type.clockWeight": 200, "iris.lock.type.clockTracking": -3, "iris.lock.type.accent": "plain", "iris.controlCenter.accent": "mono", "iris.controlCenter.sliders": "neutral", "iris.surround.enable": false, "theme.lines": 0, "theme.rim": false, "theme.fill": 70,
                "theme.shadow": 60, "iris.appearance.aura": "off", "iris.appearance.accent": "custom", "theme.accentHue": 220,
                "iris.appearance.highlight": "accent", "theme.badge": "neutral", "iris.bar.clockAccent": "plain",
                "iris.bar.composition": "unified", "iris.bar.clockStyle": "time", "iris.appearance.figureWeight": "light",
                "iris.appearance.titleFontFamily": "Roboto Flex", "iris.appearance.numbersFontFamily": "Roboto Flex",
                "iris.appearance.fontFamily": "Roboto Flex", "iris.appearance.morph": "glide", "theme.openTime": 120,
                "iris.bar.notch": true, "iris.bar.height": 36, "iris.bar.clockScale": 108, "iris.bar.satelliteScale": 90,
                "iris.dock.notch": true, "iris.dock.iconSize": 36, "iris.dock.magnification": false,
                "iris.widgets.material": "clear", "iris.widgets.weight": "light", "iris.widgets.radius": 0 }) },
        { id: "sakura", name: "Sakura", author: "iNiR", tags: ["anime", "pink", "round", "playful"],
            values: root.values({ "iris.lock.material": "glass", "iris.lock.type.clockWeight": 300, "iris.lock.type.clockTracking": -2, "iris.lock.type.accent": "accent", "iris.controlCenter.accent": "accent", "iris.controlCenter.sliders": "accent", "theme.surface": "graphite", "theme.rim": false, "glass.mode": "wallpaper", "glass.tint": 60,
                "iris.appearance.preset": "round", "theme.shape": 140, "theme.melt": 90, "theme.lines": 30, "theme.glow": 45,
                "iris.appearance.accent": "custom", "theme.accentHue": 334, "iris.appearance.highlight": "pink",
                "iris.appearance.aura": "vivid", "theme.lightReach": 180, "iris.appearance.morph": "liquid", "theme.bounce": 150,
                "iris.appearance.titleFontFamily": "Gabarito", "iris.bar.satelliteGap": 10, "iris.bubbles.scale": 112, "iris.bar.notch": true,
                "iris.appearance.glass.edgeColour": "accent", "iris.appearance.glass.edgeLight": 50, "iris.appearance.glass.edgeLine": 14,
                "iris.surround.thickness": 12, "iris.surround.radius": 36, "iris.widgets.material": "glass", "iris.widgets.radius": 32,
                "iris.dock.magnification": false, "iris.dock.iconSize": 44, "iris.controlCenter.controls": "round" }) },
        { id: "meadow", name: "Meadow", author: "iNiR", tags: ["warm", "soft", "organic"],
            values: root.values({ "iris.lock.material": "glass", "iris.lock.type.clockWeight": 400, "iris.lock.type.clockTracking": -2, "iris.lock.type.accent": "highlight", "iris.controlCenter.accent": "colourful", "iris.controlCenter.sliders": "accent", "theme.surface": "graphite", "theme.rim": false, "glass.mode": "wallpaper", "glass.tint": 58,
                "iris.appearance.preset": "round", "theme.shape": 150, "theme.melt": 110, "iris.appearance.accent": "mint",
                "iris.appearance.highlight": "custom", "theme.highlightHue": 40, "theme.lines": 35, "theme.contrast": 95,
                "iris.appearance.aura": "subtle", "iris.appearance.morph": "liquid", "theme.bounce": 160, "theme.curve": "gentle",
                "iris.appearance.titleFontFamily": "Gabarito", "iris.appearance.fontFamily": "Rubik", "iris.bubbles.scale": 115, "iris.bar.padding": 115,
                "iris.bar.clockStyle": "weather", "iris.bar.height": 46, "iris.surround.thickness": 12, "iris.surround.radius": 32, "iris.widgets.material": "tinted", "iris.widgets.radius": 28,
                "iris.widgets.tint": "system", "iris.dock.iconSize": 46, "iris.dock.magnification": false, "iris.controlCenter.controls": "round" }) },
        { id: "unit-01", name: "Unit-01", author: "iNiR", tags: ["anime", "mecha", "hard", "violet"],
            values: root.values({ "iris.lock.material": "tint", "iris.lock.type.clockWeight": 700, "iris.lock.type.clockTracking": -1, "iris.lock.type.accent": "highlight", "iris.controlCenter.accent": "accent", "iris.controlCenter.sliders": "accent", "theme.surface": "midnight", "iris.appearance.preset": "contrast", "theme.shape": 75,
                "theme.pieceShape": "squircle", "iris.appearance.accent": "custom", "theme.accentHue": 275,
                "iris.appearance.highlight": "custom", "theme.highlightHue": 95, "theme.badge": "highlight",
                "theme.lines": 170, "theme.shadow": 150, "theme.glow": 30, "iris.appearance.titleFontFamily": "Oxanium",
                "iris.appearance.numbersFontFamily": "JetBrainsMono Nerd Font", "iris.appearance.morph": "snap",
                "theme.curve": "swift", "iris.bar.clockAccent": "highlight", "iris.bar.clockStyle": "time", "iris.bar.height": 44,
                "iris.bar.clockScale": 112, "iris.surround.thickness": 18, "iris.surround.radius": 6, "iris.bar.notchCurve": 60,
                "iris.widgets.material": "solid", "iris.widgets.radius": 4, "iris.widgets.weight": "bold", "iris.dock.material": "solid",
                "iris.dock.iconSize": 42, "iris.controlCenter.controls": "tiles", "theme.rim": false,
                "iris.dock.notch": false, "iris.appearance.expandedRadius": 16 }) },
        { id: "magical-girl", name: "Magical Girl", author: "iNiR", tags: ["anime", "rose", "gold", "playful"],
            values: root.values({ "iris.lock.material": "glass", "iris.lock.type.clockWeight": 300, "iris.lock.type.clockTracking": -2, "iris.lock.type.accent": "accent", "iris.controlCenter.accent": "colourful", "iris.controlCenter.sliders": "accent", "theme.surface": "graphite", "theme.rim": false, "glass.mode": "wallpaper", "glass.tint": 58,
                "iris.appearance.preset": "round", "theme.shape": 138, "theme.melt": 85, "theme.lines": 35, "theme.glow": 45,
                "iris.appearance.accent": "custom", "theme.accentHue": 338, "iris.appearance.highlight": "custom", "theme.highlightHue": 44,
                "iris.appearance.anime.enabled": true, "iris.appearance.anime.palette": "magical-girl", "iris.appearance.anime.strength": 100, "iris.appearance.anime.highlight": true,
                "iris.appearance.aura": "vivid", "theme.lightReach": 185, "iris.appearance.morph": "liquid", "theme.bounce": 145,
                "iris.appearance.titleFontFamily": "Gabarito", "iris.appearance.fontFamily": "Gabarito",
                "iris.bubbles.scale": 112, "iris.bar.notch": true, "iris.bar.clockStyle": "dateTime", "iris.bar.clockAccent": "highlight",
                "iris.appearance.glass.edgeColour": "accent", "iris.appearance.glass.edgeLight": 55, "iris.appearance.glass.edgeLine": 16,
                "iris.surround.thickness": 12, "iris.surround.radius": 34, "iris.widgets.material": "glass", "iris.widgets.radius": 30,
                "iris.dock.magnification": false, "iris.dock.iconSize": 44, "iris.controlCenter.controls": "round" }) },
        { id: "spirit-forest", name: "Spirit Forest", author: "iNiR", tags: ["anime", "green", "amber", "organic"],
            values: root.values({ "iris.lock.material": "glass", "iris.lock.type.clockWeight": 400, "iris.lock.type.clockTracking": -2, "iris.lock.type.accent": "highlight", "iris.controlCenter.accent": "colourful", "iris.controlCenter.sliders": "accent", "theme.surface": "graphite", "theme.rim": false, "glass.mode": "wallpaper", "glass.tint": 56,
                "iris.appearance.preset": "round", "theme.shape": 145, "theme.melt": 105, "theme.lines": 30, "theme.glow": 30,
                "iris.appearance.accent": "mint", "iris.appearance.highlight": "custom", "theme.highlightHue": 40,
                "iris.appearance.anime.enabled": true, "iris.appearance.anime.palette": "spirit-forest", "iris.appearance.anime.strength": 100, "iris.appearance.anime.highlight": true,
                "iris.appearance.aura": "subtle", "iris.appearance.morph": "glide", "theme.curve": "gentle", "theme.openTime": 120,
                "iris.appearance.titleFontFamily": "Space Grotesk", "iris.appearance.fontFamily": "Rubik",
                "iris.bubbles.scale": 114, "iris.bar.padding": 112, "iris.bar.clockStyle": "weather", "iris.bar.clockAccent": "highlight",
                "iris.appearance.glass.edgeColour": "highlight", "iris.appearance.glass.edgeLight": 50, "iris.appearance.glass.edgeLine": 14,
                "iris.bar.height": 46, "iris.surround.thickness": 12, "iris.surround.radius": 32, "iris.widgets.material": "tinted", "iris.widgets.radius": 28,
                "iris.widgets.tint": "system", "iris.dock.iconSize": 46, "iris.dock.magnification": false, "iris.controlCenter.controls": "round" }) },
        { id: "signal", name: "Signal", author: "iNiR", tags: ["contrast", "legible"],
            values: root.values({ "iris.lock.material": "tint", "iris.lock.type.clockWeight": 800, "iris.lock.type.clockTracking": -2, "iris.lock.type.accent": "accent", "iris.controlCenter.accent": "accent", "iris.controlCenter.sliders": "accent", "iris.appearance.preset": "contrast", "theme.fill": 130, "theme.text": 110, "theme.lines": 160,
                "theme.contrast": 130, "iris.appearance.aura": "off", "iris.appearance.highlight": "yellow",
                "iris.appearance.accent": "custom", "theme.accentHue": 52, "iris.appearance.figureWeight": "bold",
                "theme.openTime": 80, "iris.bar.height": 50, "iris.bar.clockScale": 122, "iris.dock.iconSize": 50,
                "iris.dock.magnification": false, "iris.widgets.material": "solid", "iris.widgets.weight": "bold", "iris.widgets.radius": 16,
                "iris.widgets.tint": "system" }) },
        { id: "inir", name: "iNiR Theme", author: "iNiR", tags: ["system"],
            values: root.values({ "theme.surface": "theme", "iris.appearance.accent": "theme", "iris.appearance.highlight": "theme",
                "iris.widgets.design": "material", "iris.widgets.tint": "system", "iris.controlCenter.controls": "tiles" }) },
        { id: "lume", name: "Lume", author: "iNiR", tags: ["wallpaper", "clear", "instrument", "menu bar"],
            values: root.values({ "iris.lock.material": "glass", "iris.lock.type.clockWeight": 300, "iris.lock.type.clockTracking": -2, "iris.lock.type.accent": "accent", "iris.controlCenter.accent": "accent", "iris.controlCenter.sliders": "accent",
                "iris.appearance.adaptive": 60, "theme.surface": "wallpaper", "iris.appearance.accent": "wallpaper", "iris.appearance.highlight": "wallpaper",
                "iris.appearance.aura": "subtle", "iris.appearance.tint": 20, "theme.rim": false, "theme.lines": 20, "glass.mode": "wallpaper", "glass.tint": 40, "glass.blur": 100,
                "iris.appearance.preset": "soft", "iris.appearance.morph": "glide", "theme.curve": "gentle", "iris.appearance.figureWeight": "light",
                "iris.bar.layout": "menubar", "iris.bar.strip": "clear", "iris.bar.notch": true, "iris.bar.height": 38, "iris.bar.composition": "unified",
                "iris.bar.clockStyle": "dateTime", "iris.bar.clockAccent": "accent", "iris.surround.enable": false,
                "iris.widgets.design": "instrument", "iris.widgets.tint": "wallpaper", "iris.widgets.material": "clear", "iris.widgets.weight": "light",
                "iris.dock.notch": false, "iris.dock.material": "glass", "iris.dock.magnification": false, "iris.controlCenter.controls": "round" }) },
        { id: "adaptive", name: "Adaptive", author: "iNiR", tags: ["wallpaper", "automatic"],
            values: root.values({ "iris.lock.material": "glass", "iris.lock.type.clockWeight": 400, "iris.lock.type.clockTracking": -2, "iris.lock.type.accent": "plain", "iris.controlCenter.accent": "system", "iris.controlCenter.sliders": "neutral", "iris.appearance.adaptive": 80, "theme.surface": "wallpaper", "iris.appearance.accent": "wallpaper",
                "iris.appearance.highlight": "wallpaper", "iris.appearance.aura": "subtle", "iris.appearance.tint": 25,
                "theme.rim": false, "glass.mode": "wallpaper", "glass.tint": 52, "iris.surround.thickness": 10, "iris.surround.radius": 28,
                "iris.widgets.material": "clear", "iris.widgets.weight": "regular" }) }
    ]
}
