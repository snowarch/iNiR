pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.shared.background.widgets

// SekaiPop's palette card, our way: five colours read from the wallpaper, the cover that plays or a
// harmony. A tap copies one, a right click keeps it through the next read. Looking never touches the
// theme: only "Use as accent" does, and it can be taken back for a few seconds.
AbstractBackgroundWidget {
    id: root

    configEntryName: "palette"
    defaultConfig: ({
        placementStrategy: "free", widgetScale: 100, cornerRadius: -1, x: 120, y: 600
    })

    implicitWidth: root.irisFaceWidth
    implicitHeight: root.irisFaceHeight
    irisOnly: true
    irisFacePart: "palette"
    irisSizes: ["small", "medium", "large"]
    irisDefaultSize: "medium"
    irisOptions: [
        { key: "source", label: Translation.tr("Colours from"), fallback: "wallpaper", choices: [
            { label: Translation.tr("Wallpaper"), icon: "wallpaper", value: "wallpaper" },
            { label: Translation.tr("Music"), icon: "album", value: "music" },
            { label: Translation.tr("Random"), icon: "shuffle", value: "random" }] }
    ]
    semanticPaletteControls: false
    widgetSurfaceEnabled: false
    needsColText: false

    readonly property string colourSource: String(root.irisOption("source", "wallpaper"))
    readonly property var kept: Array.from(root.irisOption("kept", []) ?? [])
    readonly property var drawn: Array.from(root.irisOption("drawn", []) ?? [])
    readonly property var player: MprisController.activePlayer
    // Music with nothing playing reads the wallpaper and says so.
    readonly property bool coverRead: root.colourSource === "music" && artwork.displaySource.length > 0
    readonly property string from: root.colourSource === "random" ? "random" : root.coverRead ? "music" : "wallpaper"
    readonly property var screen: Quickshell.screens.find(entry => entry.name === root.outputName) ?? null
    readonly property string wallpaperStill: Wallpapers.stillUrlFor(WallpaperListener.wallpaperUrlForScreen(root.screen))

    MediaArtworkResolver {
        id: artwork
        sourceUrl: root.colourSource === "music" && root.player ? MprisController.effectiveArtUrl(root.player) : ""
        title: MprisController.titleOf(root.player) ?? ""
        artist: MprisController.artistOf(root.player) ?? ""
        album: root.player?.trackAlbum ?? ""
    }
    ColorQuantizer {
        id: quant
        source: root.from === "music" ? artwork.displaySource : root.from === "wallpaper" ? root.wallpaperStill : ""
        depth: 3
        rescaleSize: 96
    }

    function hex(c: color): string {
        const part = value => Math.round(Math.max(0, Math.min(1, value)) * 255).toString(16).padStart(2, "0")
        return ("#" + part(c.r) + part(c.g) + part(c.b)).toUpperCase()
    }
    // Five that stand apart: the most telling colour first, then each one farthest from those taken,
    // laid dark to light. A picture with fewer than five gives tints of what it has.
    function pickFive(list: var): var {
        const pool = Array.from(list ?? []).map(entry => Qt.color(entry))
        if (pool.length === 0) return []
        const hue = c => c.hslHue < 0 ? 0 : c.hslHue
        const gap = (a, b) => {
            const dh = Math.min(Math.abs(hue(a) - hue(b)), 1 - Math.abs(hue(a) - hue(b)))
            return Math.hypot(dh * 2 * Math.min(a.hslSaturation, b.hslSaturation), a.hslLightness - b.hslLightness,
                (a.hslSaturation - b.hslSaturation) * 0.5)
        }
        const telling = c => c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.5) * 1.4)
        const taken = [pool.reduce((best, c) => telling(c) > telling(best) ? c : best, pool[0])]
        while (taken.length < Math.min(5, pool.length)) {
            let far = null, farGap = -1
            for (const c of pool) {
                if (taken.includes(c)) continue
                const near = Math.min(...taken.map(t => gap(c, t)))
                if (near > farGap) { far = c; farGap = near }
            }
            taken.push(far)
        }
        for (let i = 0; taken.length < 5; i++) {
            const base = taken[i % taken.length]
            taken.push(Qt.hsla(hue(base), base.hslSaturation, Math.min(0.9, base.hslLightness + 0.18 * (1 + Math.floor(i / taken.length))), 1))
        }
        return taken.sort((a, b) => a.hslLightness - b.hslLightness).map(c => root.hex(c))
    }
    function harmony(): var {
        const base = Math.random()
        const shapes = [[0, 0.04, 0.5, 0.54, 0.08], [0, 0.33, 0.66, 0.05, 0.38], [0, 0.08, 0.16, 0.58, 0.5], [0, 0.42, 0.58, 0.02, 0.5]]
        const shape = shapes[Math.floor(Math.random() * shapes.length)]
        const light = [0.22, 0.38, 0.52, 0.66, 0.82]
        return shape.map((offset, i) => root.hex(Qt.hsla((base + offset) % 1, 0.42 + Math.random() * 0.38, light[i], 1)))
    }
    readonly property var read: root.from === "random" ? root.drawn : root.pickFive(quant.colors)
    readonly property var colours: [0, 1, 2, 3, 4].map(i => String(root.kept[i] || root.read[i] || ""))
    readonly property bool ready: root.colours.every(entry => entry.length > 0)

    function shuffle(): void {
        root._setOutputValues({ "iris.source": "random", "iris.drawn": root.harmony() })
    }
    function keep(index: int): void {
        const next = [0, 1, 2, 3, 4].map(i => String(root.kept[i] ?? ""))
        next[index] = next[index].length > 0 ? "" : root.colours[index]
        root.setIrisOption("kept", next)
    }
    function copy(text: string): void {
        Quickshell.clipboardText = text
    }
    // A first turn to Random deals a hand; written after the change settles, never inside it.
    onColourSourceChanged: if (root.colourSource === "random" && root.drawn.length < 5)
        Qt.callLater(() => root.setIrisOption("drawn", root.harmony()))

    // The accent it replaced, held only while the undo key shows.
    property var accentBefore: null
    readonly property bool canUseAccent: (Config.options?.panelFamily ?? "ii") === "iris"
        && !(String(ThemeService.currentTheme ?? "auto") !== "auto"
            && Boolean(Config.options?.iris?.appearance?.followTheme ?? true))
    function useAsAccent(value: string): void {
        const c = Qt.color(value)
        const appearance = Config.options?.iris?.appearance
        root.accentBefore = { accent: String(appearance?.accent ?? "blue"), hue: Number(appearance?.theme?.accentHue ?? 212) }
        Config.setNestedValues({ "iris.appearance.accent": "custom",
            "iris.appearance.theme.accentHue": Math.round((c.hslHue < 0 ? 0 : c.hslHue) * 360) })
        accentUndo.restart()
    }
    function undoAccent(): void {
        if (!root.accentBefore) return
        Config.setNestedValues({ "iris.appearance.accent": root.accentBefore.accent,
            "iris.appearance.theme.accentHue": root.accentBefore.hue })
        root.accentBefore = null
        accentUndo.stop()
    }
    Timer { id: accentUndo; interval: 8000; onTriggered: root.accentBefore = null }
}
