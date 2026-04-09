pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets.widgetCanvas

AbstractWidget {
    id: root

    required property string configEntryName
    required property int screenWidth
    required property int screenHeight
    required property int scaledScreenWidth
    required property int scaledScreenHeight
    required property real wallpaperScale
    property bool visibleWhenLocked: false
    property var configEntry: Config.options?.background?.widgets?.[configEntryName] ?? {}
    property string placementStrategy: configEntry.placementStrategy
    function _snapToPixel(value: real): real {
        const numeric = Number(value)
        return Math.round(Number.isFinite(numeric) ? numeric : 0)
    }
    property real targetX: {
        const rawX = Number(configEntry?.x ?? 0)
        const safeX = Number.isFinite(rawX) ? rawX : 0
        const maxX = Math.max(0, scaledScreenWidth - width)
        return _snapToPixel(Math.max(0, Math.min(safeX, maxX)))
    }
    property real targetY: {
        const rawY = Number(configEntry?.y ?? 0)
        const safeY = Number.isFinite(rawY) ? rawY : 0
        const maxY = Math.max(0, scaledScreenHeight - height)
        return _snapToPixel(Math.max(0, Math.min(safeY, maxY)))
    }

    Binding {
        target: root
        property: "x"
        value: root.targetX
        when: root.placementStrategy !== "free"
    }
    Binding {
        target: root
        property: "y"
        value: root.targetY
        when: root.placementStrategy !== "free"
    }
    Behavior on x {
        enabled: Appearance.animationsEnabled && root.placementStrategy !== "free"
        NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
    }
    Behavior on y {
        enabled: Appearance.animationsEnabled && root.placementStrategy !== "free"
        NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
    }

    visible: opacity > 0
    opacity: (GlobalStates.screenLocked && !visibleWhenLocked) ? 0 : 1
    enabled: !GlobalStates.screenLocked
    Behavior on opacity {
        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    scale: (draggable && containsPress) ? 1.05 : 1
    Behavior on scale {
        animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
    }

    draggable: placementStrategy === "free" && !GlobalStates.screenLocked
    function syncFreePositionFromConfig(): void {
        if (!Config.ready) return;
        if (root.placementStrategy !== "free") return;
        root.x = root.targetX;
        root.y = root.targetY;
    }

    onReleased: {
        if (GlobalStates.screenLocked) return;
        root.targetX = root._snapToPixel(root.x);
        root.targetY  = root._snapToPixel(root.y);
        configEntry.x = root.targetX;
        configEntry.y = root.targetY ;
    }

    property bool needsColText: false
    property color dominantColor: Appearance.colors.colPrimary
    property bool dominantColorIsDark: dominantColor.hslLightness < 0.5
    property color colText: {
        const onBlurredLock = (GlobalStates.screenLocked && (Config.options?.lock?.blur?.enable ?? false))
        const baseText = Appearance.colors.colOnLayer0
        const accent = Appearance.colors.colPrimary
        // Good contrast by default, slightly tinted towards primary
        const adaptive = ColorUtils.mix(baseText, accent, dominantColorIsDark ? 0.30 : 0.15)
        return onBlurredLock ? baseText : adaptive;
    }

    property bool wallpaperIsVideo: {
        const p = (Config.options?.background?.wallpaperPath ?? "").toLowerCase();
        return p.endsWith(".mp4") || p.endsWith(".webm") || p.endsWith(".mkv") || p.endsWith(".avi") || p.endsWith(".mov");
    }
    property string wallpaperPath: wallpaperIsVideo ? (Config.options?.background?.thumbnailPath ?? "") : (Config.options?.background?.wallpaperPath ?? "")
    
    onWallpaperPathChanged: _placementDebounce.restart()
    onPlacementStrategyChanged: {
        syncFreePositionFromConfig()
        refreshPlacementIfNeeded()
    }
    Connections {
        target: Config
        function onReadyChanged() {
            refreshPlacementIfNeeded()
            syncFreePositionFromConfig()
        }
    }
    Timer {
        id: _placementDebounce
        interval: 500
        repeat: false
        onTriggered: root.refreshPlacementIfNeeded()
    }
    function refreshPlacementIfNeeded() {
        if (!Config.ready || (root.placementStrategy === "free" && root.needsColText)) return;
        leastBusyRegionProc.wallpaperPath = root.wallpaperPath;
        leastBusyRegionProc.running = false;
        leastBusyRegionProc.running = true;
    }
    Process {
        id: leastBusyRegionProc
        property string wallpaperPath: root.wallpaperPath
        // TODO: make these less arbitrary
        property int contentWidth: 300
        property int contentHeight: 300
        property int horizontalPadding: 200
        property int verticalPadding: 200
        command: [Quickshell.shellPath("scripts/images/least-busy-region-venv.sh") // Comments to force the formatter to break lines
            , "--screen-width", Math.round(root.scaledScreenWidth) //
            , "--screen-height", Math.round(root.scaledScreenHeight) //
            , "--width", contentWidth //
            , "--height", contentHeight //
            , "--horizontal-padding", horizontalPadding //
            , "--vertical-padding", verticalPadding //
            , wallpaperPath //
            , ...(root.placementStrategy === "mostBusy" ? ["--busiest"] : [])
            // "--visual-output",
        ]
        stdout: StdioCollector {
            id: leastBusyRegionOutputCollector
            onStreamFinished: {
                const output = leastBusyRegionOutputCollector.text;
                // console.log("[Background] Least busy region output:", output)
                if (output.length === 0) return;
                const parsedContent = JSON.parse(output);
                root.dominantColor = parsedContent.dominant_color || Appearance.colors.colPrimary;
                if (root.placementStrategy === "free") return;
                root.targetX = root._snapToPixel(parsedContent.center_x * root.wallpaperScale - root.width / 2);
                root.targetY  = root._snapToPixel(parsedContent.center_y * root.wallpaperScale - root.height / 2);
            }
        }
    }
}
