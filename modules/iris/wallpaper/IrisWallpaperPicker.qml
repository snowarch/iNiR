pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.iris.frame
import qs.modules.iris.style
import qs.modules.iris.components

// The wallpaper picker lives in the chassis window of its output, so its body, its content and the Island it grows
// from are one surface: drawn and moved in the same frame. What it knows is the engine's; how it looks is one of three
// layouts (Reel, Mosaic, Browser) the person picks in any of them.
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
    readonly property bool morphOpen: root.here && GlobalStates.wallpaperSelectorOpen
    // Full-size images and video wait for the open to finish: decoded mid-motion they cost it 4-7 frames.
    readonly property bool opened: root.morphOpen && surface.settled

    readonly property real d: IrisStyle.density
    readonly property var barOptions: Config.options?.iris?.bar ?? ({})
    readonly property bool barBottom: String(root.barOptions?.position ?? "top") === "bottom"
    readonly property string layoutName: {
        const wanted = String(Config.options?.iris?.wallpaper?.layout ?? "reel")
        // The layouts before these three: Strip and Showcase were a run, Wall a grid.
        return wanted === "wall" ? "browser" : wanted === "showcase" || wanted === "strip" ? "reel"
            : ["reel", "mosaic", "browser"].includes(wanted) ? wanted : "reel"
    }

    // Asked for in one layout, kept across them for the session.
    property bool detailsOpen: false
    property bool filtersOpen: false

    visible: root.present

    WallpaperEngine {
        id: engine
        screen: root.screen
        open: root.morphOpen
        opened: root.opened
        present: root.present
        onFinished: GlobalStates.wallpaperSelectorOpen = false
    }
    onMorphOpenChanged: if (root.morphOpen) {
        const gsTarget = GlobalStates.wallpaperSelectorTargetMonitor ?? ""
        engine.targetMonitor = !engine.multiMonitor ? ""
            : gsTarget.length > 0 ? gsTarget : (GlobalStates.focusedScreen?.name ?? "")
    }

    // Keys every layout answers the same way.
    function commonKey(event): bool {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) { engine.cycleSource(event.key === Qt.Key_Backtab ? -1 : 1); return true }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { engine.applySelected(); return true }
        if (ctrl && event.key === Qt.Key_D) { engine.toggleFavorite(engine.selected); return true }
        if (ctrl && event.key === Qt.Key_I) { root.detailsOpen = !root.detailsOpen; return true }
        if (ctrl && event.key >= Qt.Key_1 && event.key <= Qt.Key_3) {
            Config.setNestedValue("iris.wallpaper.layout", ["reel", "mosaic", "browser"][event.key - Qt.Key_1])
            return true
        }
        if (event.key === Qt.Key_Home && engine.query.length === 0) { engine.select(0); return true }
        if (event.key === Qt.Key_End && engine.query.length === 0) { engine.select(engine.count - 1); return true }
        return false
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
        onActivated: GlobalStates.wallpaperSelectorOpen = false
    }
    Shortcut { sequence: "Alt+Left"; enabled: root.morphOpen && engine.source === "library" && engine.canGoBack; onActivated: engine.goBack() }
    Shortcut { sequence: "Alt+Right"; enabled: root.morphOpen && engine.source === "library" && engine.canGoForward; onActivated: engine.goForward() }
    Shortcut { sequence: "Alt+Up"; enabled: root.morphOpen && engine.source === "library"; onActivated: engine.goUp() }

    IrisBodyShadow {
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

    // A layout switch or a fold reshapes the body on the gallery's own spring; opening lands at the size it opens to.
    IrisSpring {
        id: bodyWidth
        surface: "gallery"
        intent: "move"
        animate: IrisStyle.motionEnabled && surface.settled
        to: Math.min(root.width - 48 * root.d, layoutLoader.item?.implicitWidth ?? 960 * root.d)
    }
    IrisSpring {
        id: bodyHeight
        surface: "gallery"
        intent: "move"
        animate: IrisStyle.motionEnabled && surface.settled
        to: Math.min(root.height - surface.edgeGap - 24 * root.d, layoutLoader.item?.implicitHeight ?? 480 * root.d)
    }

    IrisMorphSurface {
        id: surface
        motionSurface: "gallery"
        settles: true
        fieldBacked: true
        chassisKey: "gallery"
        compositorBlurred: true
        open: root.morphOpen
        contentReady: layoutLoader.status === Loader.Ready
        radius: IrisStyle.surfaceRadius("gallery", IrisStyle.radiusPanel)
        light: IrisStyle.surfaceLight("gallery", IrisStyle.wallpaperLight)
        lightFrom: root.barBottom ? "bottom" : "top"
        readonly property real edgeGap: (Number(root.barOptions?.height ?? 42)
            + ((root.barOptions?.notch ?? false) ? 0 : Number(root.barOptions?.margin ?? 8) * 2)) * root.d + 10 * root.d
        width: Math.round(bodyWidth.value)
        height: Math.round(bodyHeight.value)
        x: Math.round((root.width - width) / 2)
        y: root.barBottom ? root.height - height - edgeGap - IrisFrame.musicReach("bottom")
            : edgeGap + IrisFrame.musicReach("top")
        onClosed: { engine.setQuery(""); root.detailsOpen = false }
        onSettledChanged: if (surface.settled && surface.open) layoutLoader.item?.focusSearch()

        MouseArea { anchors.fill: parent }

        // Laid out once at its own size; the body grows or shrinks around it.
        Loader {
            id: layoutLoader
            x: Math.round((surface.width - width) / 2)
            width: layoutLoader.item?.implicitWidth ?? 0
            height: layoutLoader.item?.implicitHeight ?? 0
            sourceComponent: root.layoutName === "mosaic" ? mosaic : root.layoutName === "browser" ? browser : reel
            onLoaded: if (root.morphOpen) layoutLoader.item.focusSearch()
        }
        Component { id: reel; WallpaperReel { engine: engine; host: root; maxWidth: root.width; maxHeight: root.height } }
        Component { id: mosaic; WallpaperMosaic { engine: engine; host: root; maxWidth: root.width; maxHeight: root.height } }
        Component { id: browser; WallpaperBrowser { engine: engine; host: root; maxWidth: root.width; maxHeight: root.height } }
    }
}
