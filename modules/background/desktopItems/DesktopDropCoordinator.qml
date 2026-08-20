pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions

Item {
    id: root
    required property string outputName
    required property int canvasWidth
    required property int canvasHeight
    property var workArea: ({ left: 0, top: 0, right: canvasWidth, bottom: canvasHeight,
        width: canvasWidth, height: canvasHeight })
    property int gridSize: 16
    property bool gridSnap: true
    property bool interactive: true
    property bool dropHover: false
    property var _queue: []
    property int _queueIndex: 0
    property real _dropX: 0
    property real _dropY: 0
    property string _firstCreatedId: ""

    width: root.canvasWidth
    height: root.canvasHeight

    signal imageChoiceRequested(var paths, real x, real y)

    function _isImage(path: string): bool {
        return Images.isValidImageByName(path)
    }

    function _labelFor(target): string {
        if (/^https?:\/\//i.test(target))
            return target.replace(/^https?:\/\//i, "").split("/")[0]
        return FileUtils.fileNameForPath(target) || target
    }

    function _pathFromDropUrl(value: var): string {
        const raw = String(value ?? "")
        try {
            return FileUtils.trimFileProtocol(decodeURIComponent(raw))
        } catch (error) {
            return FileUtils.trimFileProtocol(raw)
        }
    }

    function _position(index): var {
        const col = index % 5
        const row = Math.floor(index / 5)
        const itemWidth = DesktopItems.itemWidth
        const itemHeight = DesktopItems.itemHeight
        const relativeX = root._dropX - Number(root.workArea.left ?? 0) - itemWidth / 2
        const relativeY = root._dropY - Number(root.workArea.top ?? 0) - itemHeight / 2
        const rawX = relativeX + col * DesktopItems.gridPitchX(root.gridSize)
        const rawY = relativeY + row * DesktopItems.gridPitchY(root.gridSize)
        return DesktopItems.arrangePosition(root.outputName, rawX, rawY,
            Number(root.workArea.width ?? root.canvasWidth),
            Number(root.workArea.height ?? root.canvasHeight),
            root.gridSize, root.gridSnap)
    }

    function _enqueue(urls, x, y): void {
        root._queue = Array.from(urls ?? []).map(url => String(url ?? "")).filter(url => url.length > 0)
        root._queueIndex = 0
        root._firstCreatedId = ""
        root._dropX = x
        root._dropY = y
        root._processNext()
    }

    function createAccesses(urls, x, y): void {
        root._enqueue(urls, x, y)
    }

    function _recordCreated(itemId: string): void {
        if (itemId.length === 0 || root._firstCreatedId.length > 0)
            return
        root._firstCreatedId = itemId
        GlobalStates.selectDesktopItem(root.outputName + "::desktopItem." + itemId)
    }

    function requestImageChoice(urls, x, y): void {
        const paths = Array.from(urls ?? []).map(url => root._pathFromDropUrl(url))
            .filter(path => path.length > 0 && root._isImage(path))
        if (paths.length === 0)
            return
        root.imageChoiceRequested(paths, x, y)
    }

    function _processNext(): void {
        if (root._queueIndex >= root._queue.length) {
            root._queue = []
            return
        }
        const raw = root._queue[root._queueIndex]
        const position = root._position(root._queueIndex)
        const normalized = raw.trim()
        if (/^https?:\/\//i.test(normalized)) {
            root._recordCreated(DesktopItems.create({ kind: "url", target: normalized, label: root._labelFor(normalized), output: root.outputName, x: position.x, y: position.y }))
            root._queueIndex++
            root._processNext()
            return
        }
        const path = root._pathFromDropUrl(normalized)
        if (path.endsWith(".desktop")) {
            const stem = FileUtils.fileNameForPath(path).replace(/\.desktop$/i, "")
            const entry = AppSearch.lookupDesktopEntry(stem)
            root._recordCreated(DesktopItems.create({
                kind: "application",
                target: String(entry?.id ?? stem).replace(/\.desktop$/, ""),
                label: String(entry?.name ?? stem),
                icon: String(entry?.icon ?? ""),
                trusted: Boolean(entry),
                output: root.outputName,
                x: position.x,
                y: position.y
            }))
            root._queueIndex++
            root._processNext()
            return
        }
        folderProbe.path = path
        folderProbe.position = position
        folderProbe.running = true
    }

    DropArea {
        anchors.fill: parent
        z: -100
        enabled: root.interactive && !GlobalStates.screenLocked && !GlobalStates.widgetEditMode
        keys: ["application/x-inir-desktop-entry", "text/uri-list", "text/plain"]
        onEntered: drag => {
            root.dropHover = true
            drag.accept(Qt.CopyAction)
        }
        onExited: root.dropHover = false
        onDropped: drop => {
            root.dropHover = false
            if (drop.keys.includes("application/x-inir-desktop-entry")) {
                root._dropX = drop.x
                root._dropY = drop.y
                const desktopId = String(drop.getDataAsString("application/x-inir-desktop-entry") ?? "")
                    .trim().replace(/\.desktop$/i, "")
                const entry = AppSearch.lookupDesktopEntry(desktopId)
                if (desktopId.length === 0 || !entry) {
                    drop.accepted = false
                    return
                }
                root._recordCreated(DesktopItems.create({
                    kind: "application",
                    target: String(entry.id ?? desktopId).replace(/\.desktop$/i, ""),
                    label: String(entry.name ?? desktopId),
                    icon: String(entry.icon ?? ""),
                    output: root.outputName,
                    x: root._position(0).x,
                    y: root._position(0).y
                }))
                drop.accept(Qt.CopyAction)
                return
            }
            if (!drop.hasUrls || drop.urls.length === 0) {
                drop.accepted = false
                return
            }

            const imageUrls = []
            const otherUrls = []
            for (const url of drop.urls) {
                const path = root._pathFromDropUrl(url)
                if (root._isImage(path)) imageUrls.push(url)
                else otherUrls.push(url)
            }
            if (otherUrls.length > 0)
                root._enqueue(otherUrls, drop.x, drop.y)
            if (imageUrls.length > 0)
                root.requestImageChoice(imageUrls, drop.x, drop.y)
            drop.accept(Qt.CopyAction)
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.dropHover
        color: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.08)
        border.width: 2
        border.color: Appearance.colors.colPrimary
        radius: Appearance.rounding.normal
    }

    Process {
        id: folderProbe
        property string path: ""
        property var position: ({})
        command: ["test", "-d", path]
        onExited: (exitCode, exitStatus) => {
            const kind = exitCode === 0 ? "folder" : "file"
            root._recordCreated(DesktopItems.create({ kind: kind, target: "file://" + folderProbe.path, label: root._labelFor(folderProbe.path), output: root.outputName, x: folderProbe.position.x, y: folderProbe.position.y }))
            root._queueIndex++
            root._processNext()
        }
    }
}
