pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import QtQuick
import Quickshell

PathView {
    id: root

    required property var entries
    required property string searchText
    required property string currentWallpaperPath
    required property string monitorName
    property int maxVisibleItems: 5
    property real cardWidth: Math.round(240 * Appearance.fontSizeScale)
    property real cardHeight: Math.round(cardWidth / (4 / 3))

    signal applyRequested(string path)

    readonly property real itemWidth: cardWidth
    readonly property var filteredEntries: {
        const query = searchText.trim().toLowerCase()
        if (!query) return entries
        return entries.filter(entry => entry.relativePath.toLowerCase().includes(query))
    }
    readonly property int visibleItems: {
        let visible = Math.min(maxVisibleItems, filteredEntries.length)
        if (visible === 2) return 1
        if (visible > 1 && visible % 2 === 0) visible--
        return visible
    }
    readonly property string selectedPath:
        scriptModel.values[currentIndex]?.path ?? ""

    implicitWidth: itemWidth * Math.max(1, visibleItems)
    implicitHeight: cardHeight
    pathItemCount: visibleItems
    cacheItemCount: 4
    interactive: count > 1
    snapMode: PathView.SnapToItem
    highlightMoveDuration: Appearance.animationsEnabled
        ? Appearance.animation.elementMoveFast.duration : 0
    preferredHighlightBegin: 0.5
    preferredHighlightEnd: 0.5
    highlightRangeMode: PathView.StrictlyEnforceRange

    model: ScriptModel {
        id: scriptModel
        values: root.filteredEntries
        onValuesChanged: Qt.callLater(root.syncCurrentIndexAndPreview)
    }

    function syncCurrentIndex(): void {
        if (scriptModel.values.length === 0) {
            root.currentIndex = 0
            return
        }
        const index = scriptModel.values.findIndex(entry => entry.path === root.currentWallpaperPath)
        root.currentIndex = Math.max(0, index)
    }

    function syncCurrentIndexAndPreview(): void {
        root.syncCurrentIndex()
        previewDebounce.restart()
    }

    function moveSelection(delta: int): void {
        if (count <= 0) return
        const steps = Math.abs(delta)
        for (let step = 0; step < steps; step++) {
            if (delta > 0)
                incrementCurrentIndex()
            else if (delta < 0)
                decrementCurrentIndex()
        }
    }

    function activateCurrent(): void {
        const entry = scriptModel.values[currentIndex]
        if (entry?.path) root.applyRequested(entry.path)
    }

    // Show the highlighted entry on the desktop. Wallpapers routes static to
    // awww and animated to the internal renderer, so the preview always uses
    // the same engine that will render the wallpaper once applied.
    function previewCurrent(): void {
        // The surface is retained while closed, and the applied wallpaper can
        // change from elsewhere. Never repaint the desktop when not open.
        if (!GlobalStates.wallpaperLauncherOpen) return
        const entry = scriptModel.values[currentIndex]
        if (!entry?.path || entry.path === root.currentWallpaperPath) {
            // Back on the applied wallpaper — drop the preview instead of
            // repainting what is already on screen.
            Wallpapers.cancelWallpaperPreview()
            return
        }
        Wallpapers.previewWallpaper(entry.path, root.monitorName)
    }

    Component.onCompleted: Qt.callLater(syncCurrentIndexAndPreview)
    Component.onDestruction: Wallpapers.cancelWallpaperPreview()
    onCurrentWallpaperPathChanged: Qt.callLater(syncCurrentIndexAndPreview)
    onSearchTextChanged: Qt.callLater(syncCurrentIndexAndPreview)
    // The desktop always shows the highlighted card, however the highlight
    // moved — navigation, search filtering, or switching Static/Animated.
    onCurrentIndexChanged: previewDebounce.restart()

    Timer {
        id: previewDebounce
        // Static previews are a cheap awww call, but every animated preview
        // spins up a fresh decoder for a full-resolution clip. Only load one
        // once the user has actually settled on a card.
        interval: root.entries === null ? 180
            : (scriptModel.values[root.currentIndex]?.kind === "static" ? 180 : 500)
        onTriggered: root.previewCurrent()
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            root.moveSelection(event.angleDelta.y > 0 ? -1 : 1)
            event.accepted = true
        }
    }

    delegate: WallpaperLauncherItem {
        cardWidth: root.cardWidth
        cardHeight: root.cardHeight
        onActivated: selectedIndex => {
            root.currentIndex = selectedIndex
            const entry = scriptModel.values[selectedIndex]
            if (entry?.path) root.applyRequested(entry.path)
        }
    }

    path: Path {
        startY: root.height / 2
        PathAttribute { name: "z"; value: 0 }
        PathLine { x: root.width / 2; relativeY: 0 }
        PathAttribute { name: "z"; value: 1 }
        PathLine { x: root.width; relativeY: 0 }
    }
}
