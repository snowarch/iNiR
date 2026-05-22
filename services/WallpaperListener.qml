pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

import qs.modules.common
import qs.modules.common.functions
import qs.services
import "root:modules/common/functions/md5.js" as MD5

Singleton {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    // Reactive properties that trigger refresh
    readonly property bool multiMonitorEnabled: Config.options?.background?.multiMonitor?.enable ?? false
    readonly property var wallpapersByMonitorRef: Config.options?.background?.wallpapersByMonitor ?? []
    readonly property string globalWallpaperPath: Config.options?.background?.wallpaperPath ?? ""
    readonly property bool globalAnimationEnabled: Config.options?.background?.enableAnimation ?? true
    readonly property string globalFillMode: Config.options?.background?.fillMode ?? "fill"

    // Screen info
    readonly property int screenCount: Quickshell.screens.length
    readonly property var screenNames: {
        const names = []
        for (const screen of Quickshell.screens) {
            names.push(getMonitorName(screen))
        }
        return names
    }

    // Output: effective wallpaper map per monitor
    // Format: { "HDMI-A-1": { path: "...", isVideo: false, isGif: false, isAnimated: false, hasCustomWallpaper: false, workspaceFirst: 1, workspaceLast: 5 }, ... }
    property var effectivePerMonitor: ({})

    // Media type detection helpers
    function isVideoPath(path: string): bool {
        if (!path) return false
        const lower = path.toLowerCase()
        return lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv") || lower.endsWith(".avi") || lower.endsWith(".mov")
    }

    function isGifPath(path: string): bool {
        if (!path) return false
        return path.toLowerCase().endsWith(".gif")
    }

    function isAnimatedPath(path: string): bool {
        return isVideoPath(path) || isGifPath(path)
    }

    function mediaTypeLabel(path: string): string {
        if (isVideoPath(path)) return "Video"
        if (isGifPath(path)) return "GIF"
        if (!path) return ""
        return "Image"
    }

    function mediaTypeIcon(path: string): string {
        if (isVideoPath(path)) return "movie"
        if (isGifPath(path)) return "gif"
        if (!path) return "image_not_supported"
        return "image"
    }

    // Resolve the effective wallpaper URL for a screen (for Aurora blur, etc.)
    // Returns file:// URL suitable for Image.source; uses thumbnail for videos.
    function wallpaperUrlForScreen(screen): string {
        if (multiMonitorEnabled && screen) {
            const monName = getMonitorName(screen)
            const data = effectivePerMonitor[monName]
            if (data && data.path) {
                const p = data.path
                // For videos, return image-safe URL (consumers are Image/ColorQuantizer)
                if (isVideoPath(p)) {
                    const ff = Wallpapers.getVideoFirstFramePath(p)
                    if (ff) return (ff.startsWith("file://") ? ff : "file://" + ff) + "?ff=1"
                    const expected = Wallpapers._videoThumbDir + "/" + MD5.hash(p) + ".jpg"
                    Wallpapers.ensureVideoFirstFrame(p)
                    return "file://" + expected + "?ff=0"
                }
                return p.startsWith("file://") ? p : "file://" + p
            }
        }
        return Wallpapers.effectiveWallpaperUrl
    }

    // Get focused monitor name from compositor
    function getFocusedMonitor(): string {
        if (CompositorService.isNiri) {
            return NiriService.currentOutput ?? ""
        } else if (CompositorService.isHyprland) {
            return Hyprland.focusedMonitor?.name ?? ""
        }
        return ""
    }

    // Refresh the effective per-monitor map
    function refresh() {
        const result = {}
        const screens = Quickshell.screens

        if (!multiMonitorEnabled) {
            for (const screen of screens) {
                const monitorName = getMonitorName(screen)
                if (monitorName) {
                    result[monitorName] = {
                        path: globalWallpaperPath,
                        isVideo: isVideoPath(globalWallpaperPath),
                        isGif: isGifPath(globalWallpaperPath),
                        isAnimated: isAnimatedPath(globalWallpaperPath),
                        hasCustomWallpaper: false
                    }
                }
            }
        } else {
            const byMonitorMap = {}
            for (const entry of wallpapersByMonitorRef) {
                if (entry && entry.monitor) {
                    const p = entry.path ?? ""
                    byMonitorMap[entry.monitor] = {
                        path: p,
                        isVideo: isVideoPath(p),
                        isGif: isGifPath(p),
                        isAnimated: isAnimatedPath(p),
                        hasCustomWallpaper: true,
                        workspaceFirst: entry.workspaceFirst,
                        workspaceLast: entry.workspaceLast,
                        backdropPath: entry.backdropPath ?? ""
                    }
                }
            }

            for (const screen of screens) {
                const monitorName = getMonitorName(screen)
                if (monitorName) {
                    result[monitorName] = byMonitorMap[monitorName] ?? {
                        path: globalWallpaperPath,
                        isVideo: isVideoPath(globalWallpaperPath),
                        isGif: isGifPath(globalWallpaperPath),
                        isAnimated: isAnimatedPath(globalWallpaperPath),
                        hasCustomWallpaper: false
                    }
                }
            }
        }

        const newStr = JSON.stringify(result)
        if (JSON.stringify(effectivePerMonitor) === newStr) return
        effectivePerMonitor = result
        _log("[WallpaperListener] Refreshed effective per-monitor map:", newStr)
    }

    // Get monitor name for a screen (compositor-agnostic)
    function getMonitorName(screen: ShellScreen): string {
        if (!screen) return ""

        if (CompositorService.isNiri) {
            return screen.name ?? ""
        } else if (CompositorService.isHyprland) {
            const monitor = Hyprland.monitorFor(screen)
            return monitor?.name ?? screen.name ?? ""
        }

        return screen.name ?? ""
    }

    Component.onCompleted: {
        _log("[WallpaperListener] Service initialized")
        refresh()
    }

    onMultiMonitorEnabledChanged: {
        _log("[WallpaperListener] Multi-monitor mode changed:", multiMonitorEnabled)
        refresh()
    }

    onWallpapersByMonitorRefChanged: {
        _log("[WallpaperListener] Wallpapers by monitor config changed")
        refresh()
    }

    onGlobalWallpaperPathChanged: {
        _log("[WallpaperListener] Global wallpaper path changed:", globalWallpaperPath)
        refresh()
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            _log("[WallpaperListener] Screens changed, refreshing...")
            root.refresh()
        }
    }

    // Safety net: Config.configChanged fires on every setNestedValue call.
    // This guarantees we pick up wallpapersByMonitor changes even if the
    // list<var> property assignment doesn't propagate through the binding chain.
    // Debounced to avoid redundant refreshes when multiple values change at once.
    Timer {
        id: configChangeDebounce
        interval: 80
        onTriggered: root.refresh()
    }
    Connections {
        target: Config
        function onConfigChanged() {
            configChangeDebounce.restart()
        }
    }
}
