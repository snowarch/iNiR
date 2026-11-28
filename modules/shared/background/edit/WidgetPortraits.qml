pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.shared.background.widgets

// The picture of every widget a shelf offers, for any family. A widget on the desktop takes its own (WidgetShelfMotion)
// and leaves it on disk; one never put out had none, and its card showed a bare glyph. Here each widget with no
// picture for the look on show is made once, off screen, from the same file the desktop loads, photographed at its
// own size, written beside the others and then let go: one at a time, after the shelf has opened, so the opening
// stays smooth. The next arranging reads it from disk at once.
Item {
    id: root

    // The widget keys the shelf shows, and the screen it arranges (a widget out there takes its own picture).
    property var keys: []
    property string outputName: ""
    property bool running: GlobalStates.widgetEditMode
    property int screenWidth: 1920
    property int screenHeight: 1080

    width: 0
    height: 0

    // key -> url: the live picture, else the one on disk; "" while there is none yet.
    function url(key: string): string {
        const live = DesktopEditStage.pictures[key]
        if (live) return live.url
        const made = root.made[key + "@" + DesktopEditStage.look]
        if (made) return made
        const path = DesktopEditStage.savedPicture(key)
        return root.saved[path.slice(path.lastIndexOf("/") + 1)] ? "file://" + path : ""
    }

    // The pictures on disk, read once per arranging and again when one is added.
    FolderListModel {
        id: savedFolder
        folder: root.running ? "file://" + DesktopEditStage.pictureDir : ""
        nameFilters: ["*.png"]
        showDirs: false
        onStatusChanged: if (savedFolder.status === FolderListModel.Ready) root.readSaved()
        onCountChanged: if (savedFolder.status === FolderListModel.Ready) root.readSaved()
    }
    property var saved: ({})
    property bool savedRead: false
    function readSaved(): void {
        const out = {}
        for (let i = 0; i < savedFolder.count; i++) out[savedFolder.get(i, "fileName")] = true
        root.saved = out
        root.savedRead = true
    }
    // Pictures made this session (key@look -> url), so a card shows one before the folder notices the file.
    property var made: ({})
    // Keys that failed once this session: never tried again in a loop.
    property var failed: ({})

    function fileOf(key: string): string {
        if (key.startsWith("custom.")) return CustomWidgets.widgets.find(widget => "custom." + widget.id === key)?.qmlPath ?? ""
        return DesktopWidgetRegistry.entry(key)?.file ?? ""
    }
    function onDesktop(key: string): bool {
        return DesktopWidgetLayout.enabled(root.outputName, key, Config.getNestedValue("background.widgets." + key + ".enable", false))
    }
    readonly property var wanted: {
        if (!root.running || !root.savedRead) return []
        Config.revision
        DesktopEditStage.pictures
        return root.keys.filter(key => root.url(key).length === 0 && !root.failed[key + "@" + DesktopEditStage.look]
            && !root.onDesktop(key) && root.fileOf(key).length > 0)
    }
    property string sitting: ""
    onWantedChanged: if (root.sitting.length === 0 && root.wanted.length > 0) nextTimer.restart()
    onRunningChanged: if (!root.running) root.release()

    Timer {
        id: nextTimer
        // The first after the shelf has opened, the rest a beat apart.
        interval: root.madeAny ? 120 : 900
        onTriggered: {
            if (!root.running || root.sitting.length > 0) return
            const key = root.wanted[0]
            if (!key) return
            root.sitting = key
            watchdog.restart()
            sitter.setSource(root.fileOf(key), {
                screenWidth: root.screenWidth, screenHeight: root.screenHeight,
                scaledScreenWidth: root.screenWidth, scaledScreenHeight: root.screenHeight
            })
        }
    }
    property bool madeAny: false

    // A widget that draws nothing (hidden while it has nothing to show) is never painted, and its grab never answers.
    Timer {
        id: watchdog
        interval: 3000
        onTriggered: if (root.sitting.length > 0) root.giveUp()
    }
    function release(): void {
        watchdog.stop()
        settleTimer.stop()
        nextTimer.stop()
        sitter.source = ""
        root.sitting = ""
    }
    function giveUp(): void {
        const next = Object.assign({}, root.failed)
        next[root.sitting + "@" + DesktopEditStage.look] = true
        root.failed = next
        root.release()
    }

    // Far off the window: drawn into its own picture, never seen, never under the pointer.
    Loader {
        id: sitter
        x: -100000
        y: -100000
        asynchronous: true
        onStatusChanged: {
            if (sitter.status === Loader.Ready) settleTimer.restart()
            else if (sitter.status === Loader.Error) root.giveUp()
        }
    }
    // Its face loads and its data lands a moment after it is made.
    Timer {
        id: settleTimer
        interval: 650
        onTriggered: {
            const widget = sitter.item
            const key = root.sitting
            const look = DesktopEditStage.look
            const w = Math.round(widget?.width ?? 0)
            const h = Math.round(widget?.height ?? 0)
            if (!widget || w < 8 || h < 8 || !sitter.Window.window?.visible) {
                root.giveUp()
                return
            }
            const asked = widget.grabToImage(result => {
                const path = DesktopEditStage.savedPicture(key)
                if (look !== DesktopEditStage.look || root.sitting !== key || !result.saveToFile(path)) { root.giveUp(); return }
                probe.path = path
                probe.url = "file://" + path + "?" + Date.now()
                probe.loadImage(probe.url)
            }, Qt.size(w, h))
            if (!asked) root.giveUp()
        }
    }
    // A picture with nothing in it (a visualizer with no sound) is no picture: it goes, and the card keeps its glyph.
    // Read back from disk at 8x8.
    Canvas {
        id: probe
        x: -100000
        width: 8
        height: 8
        property string path: ""
        property string url: ""
        onImageLoaded: probe.requestPaint()
        onPaint: {
            if (probe.url.length === 0 || !probe.isImageLoaded(probe.url)) return
            const ctx = probe.getContext("2d")
            ctx.clearRect(0, 0, 8, 8)
            ctx.drawImage(probe.url, 0, 0, 8, 8)
            const data = ctx.getImageData(0, 0, 8, 8).data
            let alpha = 0
            for (let i = 3; i < data.length; i += 4) alpha += data[i]
            ctx.clearRect(0, 0, 8, 8)
            probe.unloadImage(probe.url)
            const url = probe.url
            probe.url = ""
            if (alpha < 64) {
                Quickshell.execDetached(["rm", "-f", probe.path])
                root.giveUp()
                return
            }
            const next = Object.assign({}, root.made)
            next[root.sitting + "@" + DesktopEditStage.look] = url
            root.made = next
            root.madeAny = true
            root.release()
        }
    }
}
