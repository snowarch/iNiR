pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

// What the wallpaper looks like under any rect of a screen: its brightness, how uneven it is and its
// mean colour. One analysis per wallpaper and screen size (a grid of 24 px cells); every desktop widget
// then sums the cells under itself, so the reading follows it live while it is dragged, with no process
// per widget or per move.
Singleton {
    id: root

    readonly property int cell: 24
    readonly property int keep: 6
    property var maps: ({})
    property int revision: 0
    property var _queue: []
    property var _failed: ({})

    function keyFor(path: string, width: int, height: int): string {
        return path + "|" + width + "x" + height
    }

    function imagePath(wallpaper: string): string {
        const still = Wallpapers.stillUrlFor(wallpaper)
        return FileUtils.trimFileProtocol(still)
    }

    function has(path: string, width: int, height: int): bool {
        return root.maps[root.keyFor(path, width, height)] !== undefined
    }

    function request(path: string, width: int, height: int): void {
        if (!path || width <= 0 || height <= 0)
            return
        const key = root.keyFor(path, width, height)
        if (root.maps[key] !== undefined || root._failed[key] || root._queue.some(job => job.key === key))
            return
        root._queue.push({ key: key, path: path, width: width, height: height })
        // Browsing previews asks for one wallpaper after another: only the latest few are worth reading.
        while (root._queue.length > 3)
            root._queue.shift()
        startTimer.restart()
    }

    // {level, spread, color, luminance} for the rect in screen coordinates, or null until analysed.
    // level and spread are gamma-encoded luma (0-1), luminance is the mean colour's relative luminance.
    function sample(path: string, width: int, height: int, x: real, y: real, w: real, h: real): var {
        const data = root.maps[root.keyFor(path, width, height)]
        if (data === undefined) {
            root.request(path, width, height)
            return null
        }
        const c = data.cell
        const x0 = Math.max(0, Math.min(data.width, x))
        const y0 = Math.max(0, Math.min(data.height, y))
        const x1 = Math.max(x0 + 1, Math.min(data.width, x + Math.max(1, w)))
        const y1 = Math.max(y0 + 1, Math.min(data.height, y + Math.max(1, h)))
        const col0 = Math.max(0, Math.floor(x0 / c))
        const col1 = Math.min(data.cols - 1, Math.floor((x1 - 1) / c))
        const row0 = Math.max(0, Math.floor(y0 / c))
        const row1 = Math.min(data.rows - 1, Math.floor((y1 - 1) / c))
        let total = 0, mean = 0, sq = 0, r = 0, g = 0, b = 0
        for (let row = row0; row <= row1; row++) {
            const top = Math.max(y0, row * c)
            const bottom = Math.min(y1, (row + 1) * c)
            if (bottom <= top)
                continue
            for (let col = col0; col <= col1; col++) {
                const left = Math.max(x0, col * c)
                const right = Math.min(x1, (col + 1) * c)
                if (right <= left)
                    continue
                const weight = (right - left) * (bottom - top)
                const i = row * data.cols + col
                total += weight
                mean += data.mean[i] * weight
                sq += data.sq[i] * weight
                r += data.r[i] * weight
                g += data.g[i] * weight
                b += data.b[i] * weight
            }
        }
        if (total <= 0)
            return null
        mean /= total
        const variance = Math.max(0, sq / total - mean * mean)
        const colour = Qt.rgba(r / total / 255, g / total / 255, b / total / 255, 1)
        return {
            level: mean / 255,
            spread: Math.sqrt(variance) / 255,
            color: colour,
            luminance: ColorUtils.relativeLuminance(colour)
        }
    }

    Timer {
        id: startTimer
        interval: 0
        onTriggered: root._next()
    }

    function _next(): void {
        if (proc.running || proc.job !== null || root._queue.length === 0)
            return
        const job = root._queue.shift()
        proc.job = job
        proc.streamDone = false
        proc.exitedDone = false
        proc.command = [Quickshell.shellPath("scripts/images/least-busy-region-venv.sh"),
            "--luma-grid", String(root.cell),
            "--screen-width", String(job.width), "--screen-height", String(job.height),
            job.path]
        proc.running = true
        watchdog.restart()
    }

    Timer {
        id: watchdog
        interval: 20000
        onTriggered: {
            if (!proc.job)
                return
            proc.running = false
            proc.streamDone = true
            proc.exitedDone = true
            proc.settle()
        }
    }

    // The next job starts only once this one's output and its exit have both arrived, so a late
    // stream can never be filed under the next job's key.
    Process {
        id: proc
        property var job: null
        property bool streamDone: false
        property bool exitedDone: false
        function settle(): void {
            if (!proc.streamDone || !proc.exitedDone)
                return
            if (proc.job && root.maps[proc.job.key] === undefined)
                root._failed[proc.job.key] = true
            proc.job = null
            startTimer.restart()
        }
        stdout: StdioCollector {
            id: output
            onStreamFinished: {
                const job = proc.job
                proc.streamDone = true
                if (!job || output.text.length === 0) {
                    proc.settle()
                    return
                }
                try {
                    const data = JSON.parse(output.text)
                    if (!(data.cols > 0) || data.mean.length !== data.cols * data.rows)
                        throw new Error("incomplete grid")
                    const next = ({})
                    const kept = Object.keys(root.maps).filter(key => key !== job.key).slice(-(root.keep - 1))
                    for (const key of kept)
                        next[key] = root.maps[key]
                    next[job.key] = data
                    root.maps = next
                    root.revision++
                } catch (e) {
                    root._failed[job.key] = true
                    console.warn("[WallpaperLuma] no reading for", job.path + ":", e.message ?? e)
                }
                proc.settle()
            }
        }
        onExited: {
            proc.exitedDone = true
            proc.settle()
        }
    }
}
