import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services

// Where a widget stands: free, on one of nine zones, or on the quietest or busiest part of its wallpaper. Only a
// person's move writes a free position: a settle, another family's size or a smaller screen clamps the drawing and
// leaves what is saved (his 10-30).
Item {
    id: root

    required property var widget
    readonly property string strategy: widget.placementStrategy
    readonly property var zones: [
        "topLeft", "topCenter", "topRight",
        "centerLeft", "center", "centerRight",
        "bottomLeft", "bottomCenter", "bottomRight"
    ]
    readonly property bool onZone: root.zones.indexOf(root.strategy) >= 0
    readonly property bool onWallpaper: root.strategy === "leastBusy" || root.strategy === "mostBusy"

    // Free placement spans the output. Zones keep clear of the live bar and dock, so a snap stays visible after edit
    // mode gives those back.
    readonly property var _work: ShellLayoutController.desktopWorkArea(
        root.widget.outputName, root.widget.scaledScreenWidth, root.widget.scaledScreenHeight)
    readonly property var _zoneWork: ShellLayoutController.desktopZoneWorkArea(
        root.widget.outputName, root.widget.scaledScreenWidth, root.widget.scaledScreenHeight)
    readonly property real safeLeft: root._work.left ?? 0
    readonly property real safeTop: root._work.top ?? 0
    readonly property real safeRight: root._work.right ?? root.widget.scaledScreenWidth
    readonly property real safeBottom: root._work.bottom ?? root.widget.scaledScreenHeight
    readonly property real zoneLeft: root._zoneWork.left ?? root.safeLeft
    readonly property real zoneTop: root._zoneWork.top ?? root.safeTop
    readonly property real zoneRight: root._zoneWork.right ?? root.safeRight
    readonly property real zoneBottom: root._zoneWork.bottom ?? root.safeBottom
    readonly property int _zoneMargin: 16

    function pixel(value: real): real {
        const numeric = Number(value)
        return Math.round(Number.isFinite(numeric) ? numeric : 0)
    }
    function clampX(value: real): real {
        const most = Math.max(root.safeLeft, root.safeRight - root.widget.width)
        return root.pixel(Math.max(root.safeLeft, Math.min(Number(value) || 0, most)))
    }
    function clampY(value: real): real {
        const most = Math.max(root.safeTop, root.safeBottom - root.widget.height)
        return root.pixel(Math.max(root.safeTop, Math.min(Number(value) || 0, most)))
    }

    // A direct binding on the strategy makes a resize/config revision cycle.
    function syncStrategy(): void {
        const next = root.widget._readConfigKey("placementStrategy") ?? "free"
        if (root.widget.placementStrategy !== next)
            root.widget.placementStrategy = next
    }
    Connections {
        target: Config
        function onRevisionChanged(): void { root.syncStrategy() }
    }
    readonly property bool _resizing: root.widget._isResizing
    on_ResizingChanged: root.syncStrategy()

    function _zonePoint(zone: string): point {
        const left = root.zoneLeft + root._zoneMargin
        const top = root.zoneTop + root._zoneMargin
        const right = Math.max(left, root.zoneRight - root._zoneMargin - root.widget.width)
        const bottom = Math.max(top, root.zoneBottom - root._zoneMargin - root.widget.height)
        const xs = { Left: left, Center: left + (right - left) / 2, Right: right }
        const ys = { top: top, center: top + (bottom - top) / 2, bottom: bottom }
        if (root.zones.indexOf(zone) < 0 || zone === "center")
            return Qt.point(xs.Center, ys.center)
        const [, row, column] = zone.match(/^(top|center|bottom)(Left|Center|Right)$/)
        return Qt.point(xs[column], ys[row])
    }
    function snapToZone(zone: string): void {
        const spot = root._zonePoint(zone)
        const x = root.pixel(spot.x)
        const y = root.pixel(spot.y)
        const updates = {}
        if (root.strategy !== zone)
            updates.placementStrategy = zone
        if (Number(root.widget._readConfigKey("x")) !== x)
            updates.x = x
        if (Number(root.widget._readConfigKey("y")) !== y)
            updates.y = y
        if (Object.keys(updates).length > 0)
            root.widget._setOutputValues(updates)
    }
    function nudge(dx: real, dy: real): void {
        if (root.widget.locked)
            return
        root.widget._setOutputValues({ placementStrategy: "free",
            x: root.clampX(root.widget.x + dx), y: root.clampY(root.widget.y + dy) })
    }

    // Zones read what was stored, free clamps it to the screen, the wallpaper's spot comes from the search below.
    property real wallpaperX: 0
    property real wallpaperY: 0
    function _stored(key: string): real {
        const raw = Number(root.widget._readConfigKey(key) ?? 0)
        return Number.isFinite(raw) ? raw : 0
    }
    readonly property real targetX: root.onZone ? root.pixel(root._stored("x"))
        : root.clampX(root.strategy === "free" ? root._stored("x") : root.wallpaperX)
    readonly property real targetY: root.onZone ? root.pixel(root._stored("y"))
        : root.clampY(root.strategy === "free" ? root._stored("y") : root.wallpaperY)

    // The canvas keeps containsPress true through the drop commit, so placement resumes from committed coordinates
    // with no timed guard. Free overflow is clamped by `settle`: a Binding reading x while writing it loops.
    readonly property bool following: root.strategy !== "free" && !root.widget.containsPress
        && !root.widget.isDragging && !root.widget._isResizing
    Binding {
        target: root.widget
        property: "x"
        value: root.targetX
        when: root.following
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: root.widget
        property: "y"
        value: root.targetY
        when: root.following
        restoreMode: Binding.RestoreNone
    }

    function syncFree(): void {
        if (!Config.ready || root.widget.containsPress || root.widget._isResizing || root.strategy !== "free")
            return
        root.widget.x = root.targetX
        root.widget.y = root.targetY
    }
    onTargetXChanged: root.syncFree()
    onTargetYChanged: root.syncFree()

    function apply(): void {
        if (!Config.ready || root.widget.containsPress || root.widget._isResizing)
            return
        if (root.onZone) {
            root.snapToZone(root.strategy)
        } else {
            root.syncFree()
            region.item?.find()
        }
    }
    function applyLater(): void { later.restart() }
    onStrategyChanged: later.restart()
    // Dies with the widget: a Qt.callLater queued as a config write disables it ran into a destroyed context.
    Timer {
        id: later
        interval: 0
        onTriggered: root.apply()
    }

    // The screen, the room it leaves and the widget's size: when one moves, the widget takes its place again.
    readonly property string _room: [root.widget.scaledScreenWidth, root.widget.scaledScreenHeight,
        root.safeLeft, root.safeTop, root.safeRight, root.safeBottom,
        root.zoneLeft, root.zoneTop, root.zoneRight, root.zoneBottom,
        root.widget.width, root.widget.height].join()
    on_RoomChanged: settling.restart()
    function settle(): void { settling.restart() }
    Timer {
        id: settling
        interval: 120
        onTriggered: {
            if (!Config.ready || root.widget.containsPress || root.widget._isResizing || root.widget._sizing)
                return
            if (root.onZone) {
                root.snapToZone(root.strategy)
            } else if (root.onWallpaper) {
                region.item?.find()
            } else if (root.strategy === "free") {
                const x = root.clampX(root.widget.x)
                const y = root.clampY(root.widget.y)
                if (Math.round(root.widget.x) !== Math.round(x))
                    root.widget.x = x
                if (Math.round(root.widget.y) !== Math.round(y))
                    root.widget.y = y
            }
        }
    }

    // The quietest or busiest spot still searches the whole wallpaper in a process, so only such a widget holds one.
    function refresh(): void { region.item?.find() }
    Loader {
        id: region
        active: root.onWallpaper
        sourceComponent: Item {
            id: finder
            readonly property string path: root.widget.wallpaperPath
            onPathChanged: if (finder.path.length > 0) searchLater.restart()
            function find(): void {
                if (!Config.ready || finder.path.length === 0)
                    return
                search.running = false
                search.running = true
            }
            Component.onCompleted: finder.find()
            Timer {
                id: searchLater
                interval: 500
                onTriggered: finder.find()
            }
            Process {
                id: search
                readonly property real scale: Math.max(root.widget.wallpaperScale, 0.001)
                command: [Quickshell.shellPath("scripts/images/least-busy-region-venv.sh"),
                    "--screen-width", Math.round(root.widget.scaledScreenWidth),
                    "--screen-height", Math.round(root.widget.scaledScreenHeight),
                    "--width", Math.max(1, Math.round(root.widget.width / search.scale)),
                    "--height", Math.max(1, Math.round(root.widget.height / search.scale)),
                    "--horizontal-padding", 48,
                    "--vertical-padding", 48,
                    finder.path,
                    ...(root.strategy === "mostBusy" ? ["--busiest"] : [])]
                stdout: StdioCollector {
                    id: found
                    onStreamFinished: {
                        if (found.text.length === 0 || !root.onWallpaper)
                            return
                        try {
                            const spot = JSON.parse(found.text)
                            const scale = root.widget.wallpaperScale
                            root.wallpaperX = root.clampX(spot.center_x * scale - root.widget.width / 2)
                            root.wallpaperY = root.clampY(spot.center_y * scale - root.widget.height / 2)
                        } catch (e) {
                            console.warn("[Widgets] Failed to parse placement output:", e)
                        }
                    }
                }
            }
        }
    }
}
