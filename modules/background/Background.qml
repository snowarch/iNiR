pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.common.functions as CF
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.modules.background.widgets
import qs.modules.background.widgets.clock
import qs.modules.background.widgets.mediaControls
import qs.modules.background.widgets.weather
import qs.modules.background.widgets.visualizer
import qs.modules.background.widgets.imageConverter
import qs.modules.background.widgets.systemMonitor
import qs.modules.background.widgets.battery
import qs.modules.background.widgets.notes
import qs.modules.background.widgets.calendar
import qs.modules.background.widgets.todo
import qs.modules.background.widgets.timers
import qs.modules.background.widgets.shape
import qs.modules.background.widgets.dateBadge
import qs.modules.background.widgets.uptime
import qs.modules.background.widgets.controls
import qs.modules.background.widgets.screenTime
import qs.modules.background.widgets.dayProgress
import qs.modules.background.widgets.worldClock
import qs.modules.background.widgets.userCard
import qs.modules.background.widgets.newsTicker
import qs.modules.background.widgets.mascot
import qs.modules.background.widgets.japaneseTypography
import qs.modules.background.desktopItems
import qs.modules.iris.components
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.background
import "root:modules/common/functions/parallax.js" as ParallaxMath
import "widgets/OrganicEdgeConfig.js" as OrganicEdgeConfig

Scope {
    id: backgroundScope
    property var organicEdgeHosts: ({})
    property var widgetCanvases: ({})

    // Bounded diagnostics for the desktop clock. They are inert unless the
    // supervised shell is loaded with INIR_REGION_DEBUG=1.
    property bool clockDebugRegionActive: false
    property color clockDebugRegionColor: "transparent"
    property real clockDebugRegionBrightness: -1
    property real clockDebugRegionSpread: 0
    property bool clockDebugQuickControlsOpen: false
    property bool clockDebugLayoutProbeActive: false
    property int clockDebugLayoutProbeX: 0
    property int clockDebugLayoutProbeY: 0
    property var _clockDebugSnapshot: null
    property bool _clockDebugEditModeSnapshot: false
    property bool _clockDebugEditModeSnapshotValid: false
    property string clockDebugPaletteReport: "{}"
    property string clockDebugControlsReport: "{}"

    function promoteDesktopWidgetKey(instanceKey: string): var {
        const key = String(instanceKey ?? "")
        if (key.length === 0)
            return Config.getNestedValue("background.widgets.layerOrder", []) ?? []
        const stored = Config.getNestedValue("background.widgets.layerOrder", []) ?? []
        const order = []
        for (let i = 0; i < stored.length; ++i) {
            const candidate = String(stored[i] ?? "")
            if (candidate.length > 0 && candidate !== key
                    && order.indexOf(candidate) === -1)
                order.push(candidate)
        }
        order.push(key)
        Config.setNestedValue("background.widgets.layerOrder", order)
        return order
    }

    function applyOrganicEdgeNamedPreset(presets, name: string, label: string): string {
        const preset = presets.find(p => p.name.toLowerCase() === name.toLowerCase())
        if (!preset) return "Unknown Organic edge " + label.toLowerCase()
        const updates = {}
        for (const key of Object.keys(preset.values))
            updates[OrganicEdgeConfig.path + "." + key] = preset.values[key]
        Config.setNestedValues(updates)
        return "Organic edge " + label + ": " + preset.name
    }

    IpcHandler {
        target: "background"
        function widgetDesign(name: string): string {
            if (name === "status")
                return DesktopWidgetDesign.current + " · " + DesktopWidgetDesign.exceptionCount + " own looks"
                    + (DesktopWidgetDesign.canUndo ? " · undo available" : "")
            if (name === "undo") return DesktopWidgetDesign.undo()
            return DesktopWidgetDesign.apply(name)
        }

        function toggleEditMode(): string {
            GlobalStates.setWidgetEditMode(!GlobalStates.widgetEditMode)
            return GlobalStates.widgetEditMode ? "edit mode on" : "edit mode off"
        }

        function toggleWidgetManager(): string {
            if (!GlobalStates.widgetEditMode) GlobalStates.setWidgetEditMode(true)
            GlobalStates.desktopWidgetManagerToggleRequested(GlobalStates.focusedScreen?.name ?? "")
            return "widget manager toggled"
        }

        function setEditMode(enabled: bool): string {
            GlobalStates.setWidgetEditMode(enabled)
            return GlobalStates.widgetEditMode ? "edit mode on" : "edit mode off"
        }

        function editState(): string {
            return JSON.stringify({
                active: GlobalStates.widgetEditMode,
                selected: GlobalStates.selectedDesktopWidget,
                quickControls: GlobalStates.desktopWidgetQuickControls,
                layerOrder: Config.getNestedValue("background.widgets.layerOrder", []) ?? [],
                outputOverrides: Config.options?.background?.widgets?.outputOverrides ?? [],
                outputs: Quickshell.screens.map(screen => ({
                    name: screen?.name ?? "",
                    width: screen?.width ?? 0,
                    height: screen?.height ?? 0,
                    widgetsAllowed: DesktopWidgetLayout.outputAllowed(screen?.name ?? ""),
                    insets: ShellLayoutController.desktopInsets(screen?.name ?? ""),
                    workArea: ShellLayoutController.desktopWorkArea(
                        screen?.name ?? "", screen?.width ?? 0,
                        screen?.height ?? 0),
                    zoneWorkArea: ShellLayoutController.desktopZoneWorkArea(
                        screen?.name ?? "", screen?.width ?? 0,
                        screen?.height ?? 0)
                }))
            })
        }

        function applyOrganicEdgePreset(name: string): string {
            return backgroundScope.applyOrganicEdgeNamedPreset(OrganicEdgeConfig.presets, name, "scene")
        }

        function applyOrganicEdgeComposition(name: string): string {
            return backgroundScope.applyOrganicEdgeNamedPreset(OrganicEdgeConfig.compositionPresets, name, "composition")
        }

        function applyOrganicEdgeMaterial(name: string): string {
            return backgroundScope.applyOrganicEdgeNamedPreset(OrganicEdgeConfig.materialPresets, name, "material")
        }

        function applyOrganicEdgeResponse(name: string): string {
            return backgroundScope.applyOrganicEdgeNamedPreset(OrganicEdgeConfig.responsePresets, name, "response")
        }

        function organicEdgeState(): string {
            return JSON.stringify(Object.values(backgroundScope.organicEdgeHosts)
                .map(host => host.diagnostics()))
        }

        function setOrganicEdgeEnabled(enabled: bool): string {
            Config.setNestedValue("background.edgeWidgets.organic.enable", enabled)
            return enabled ? "Organic edge enabled" : "Organic edge disabled"
        }

        function quickControlsPage(page: string): string {
            const key = GlobalStates.selectedDesktopWidget
            const [output, name] = key.split("::")
            const widget = (backgroundScope.widgetCanvases[output]?._loadedDesktopWidgets() ?? [])
                .find(item => item.configEntryName === name) ?? null
            if (!widget)
                return "select a widget first: focusWidget <name> true"
            const pages = widget.irisFaced ? ["widget", "look", "arrange"] : ["widget", "colors", "layout"]
            const aliases = ({ look: widget.irisFaced ? "look" : "colors", colors: widget.irisFaced ? "look" : "colors",
                arrange: widget._arrangeTab, layout: widget._arrangeTab, widget: "widget" })
            const target = aliases[String(page ?? "").trim()] ?? ""
            if (!pages.includes(target))
                return "pages: widget, look, arrange"
            widget.openQuickControls(target)
            return JSON.stringify({ widget: key, page: target })
        }

        function quickControlsGeometry(): string {
            const [output, name] = GlobalStates.selectedDesktopWidget.split("::")
            const widget = (backgroundScope.widgetCanvases[output]?._loadedDesktopWidgets() ?? [])
                .find(item => item.configEntryName === name) ?? null
            return widget ? widget.editControlsGeometryReport : "{}"
        }

        function legibilityState(): string {
            const out = []
            for (const output of Object.keys(backgroundScope.widgetCanvases)) {
                const canvas = backgroundScope.widgetCanvases[output]
                if (!canvas || typeof canvas._loadedDesktopWidgets !== "function")
                    continue
                for (const widget of canvas._loadedDesktopWidgets())
                    out.push({
                        output: output,
                        widget: widget.configEntryName,
                        adaptive: widget.positionColorAdaptationEnabled,
                        sampled: widget._hasBrightness,
                        level: Math.round(widget.regionBrightness * 1000) / 1000,
                        spread: Math.round(widget.regionBrightnessSpread * 1000) / 1000,
                        luminance: Math.round(widget.regionLuminance * 1000) / 1000,
                        lightBackdrop: widget.backdropIsLight,
                        darkInk: widget.inkOnLight,
                        plate: widget.widgetHasSurface,
                        face: widget.irisFaced ? { lightBackdrop: widget.irisFaceView?.lightBackdrop ?? null,
                            veil: Math.round((widget.irisFaceView?.veil ?? -1) * 100) / 100,
                            material: widget.irisFaceView?.material ?? "" } : false,
                        ink: String(widget.widgetInk),
                        accent: String(widget.widgetAccent)
                    })
            }
            return JSON.stringify(out)
        }

        function desktopItemsState(): string {
            return DesktopItems.diagnostics()
        }

        function focusWidget(widgetName: string, openControls: bool): string {
            const name = String(widgetName ?? "").trim()
            if (name.length === 0)
                return "widget name is required"

            const builtinDefaults = ({
                weather: false, clock: true, customImage: false,
                imageConverter: false, mediaControls: false,
                visualizer: false, systemMonitor: false, battery: false,
                notes: false, calendarUpcoming: false, monthCalendar: false,
                todo: false, timers: false, dayProgress: false, uptime: false, shape: false, dateBadge: false, editorial: false,
                newsTicker: false, mascot: false, japaneseTypography: false,
                worldClock: false, userCard: false, controls: false, screenTime: false
            })
            let known = builtinDefaults[name] !== undefined
            let baseEnabled = known
                ? Boolean(Config.getNestedValue(
                    "background.widgets." + name + ".enable",
                    builtinDefaults[name]))
                : false

            if (name.startsWith("mascotInstances.")) {
                const instanceId = name.slice("mascotInstances.".length)
                const instance = Config.getNestedValue(
                    "background.widgets.mascotInstances." + instanceId, null)
                known = instance !== null && typeof instance === "object"
                baseEnabled = known && Boolean(instance.enable)
            } else if (name.startsWith("custom.")) {
                const customId = name.slice("custom.".length)
                known = CustomWidgets.ready
                    && CustomWidgets.widgets.some(widget => widget.id === customId)
                baseEnabled = known && Boolean(Config.getNestedValue(
                    "background.widgets.custom." + customId + ".enable", false))
            }

            if (!known)
                return "unknown widget: " + name
            if (name === "battery" && !Battery.available)
                return "widget unavailable: " + name

            const screen = GlobalStates.focusedScreen ?? Quickshell.screens[0]
            if (!screen)
                return "no output available"
            if (!DesktopWidgetLayout.enabled(screen.name ?? "", name, baseEnabled))
                return "widget disabled on output: " + (screen.name ?? "")

            const key = (screen.name ?? "") + "::" + name
            GlobalStates.setWidgetEditMode(true)
            if (openControls)
                GlobalStates.requestDesktopWidgetQuickControls(key)
            else
                GlobalStates.selectDesktopWidget(key)
            return key
        }

        function promoteWidget(widgetName: string): string {
            const name = String(widgetName ?? "").trim()
            if (name.length === 0)
                return "widget name is required"
            const screen = GlobalStates.focusedScreen ?? Quickshell.screens[0]
            if (!screen)
                return "no output available"
            const key = (screen.name ?? "") + "::" + name
            return JSON.stringify({
                promoted: key,
                layerOrder: backgroundScope.promoteDesktopWidgetKey(key)
            })
        }

        function resetLayerOrder(): string {
            Config.setNestedValue("background.widgets.layerOrder", [])
            return "widget layer order reset"
        }

        function setWidgetEnabled(widgetName: string, enabled: bool): string {
            const knownWidgets = ["weather", "clock", "customImage", "imageConverter",
                "mediaControls", "visualizer", "systemMonitor", "battery", "notes",
                "calendarUpcoming", "monthCalendar", "todo", "timers", "dayProgress", "uptime", "shape", "dateBadge", "editorial",
                "newsTicker", "mascot", "japaneseTypography",
                "worldClock", "userCard", "controls", "screenTime"];
            if (!knownWidgets.includes(widgetName))
                return "unknown widget: " + widgetName;
            DesktopWidgetLayout.setGloballyEnabled(widgetName, enabled);
            return widgetName + (enabled ? " enabled" : " disabled");
        }

        function clockDebugState(): string {
            return JSON.stringify({
                enabled: Quickshell.env("INIR_REGION_DEBUG") === "1",
                config: {
                    style: Config.getNestedValue("background.widgets.clock.style", "cookie"),
                    adaptToWallpaper: Config.getNestedValue("background.widgets.clock.digital.adaptToWallpaper", true),
                    placementStrategy: Config.getNestedValue("background.widgets.clock.placementStrategy", "free"),
                    x: Config.getNestedValue("background.widgets.clock.x", 0),
                    y: Config.getNestedValue("background.widgets.clock.y", 0)
                },
                injectedRegion: {
                    active: backgroundScope.clockDebugRegionActive,
                    color: String(backgroundScope.clockDebugRegionColor),
                    brightness: backgroundScope.clockDebugRegionBrightness,
                    spread: backgroundScope.clockDebugRegionSpread
                },
                palette: backgroundScope.clockDebugPaletteReport,
                controls: backgroundScope.clockDebugControlsReport,
                snapshotActive: backgroundScope._clockDebugSnapshot !== null
                    || backgroundScope._clockDebugEditModeSnapshotValid
            });
        }

        function clockDebugSetMode(style: string, adaptToWallpaper: bool): string {
            if (Quickshell.env("INIR_REGION_DEBUG") !== "1")
                return "clock diagnostics disabled; load with INIR_REGION_DEBUG=1";
            if (style !== "digital" && style !== "cookie")
                return "invalid clock style: " + style;
            backgroundScope._captureClockDebugSnapshot();
            let updates = {};
            updates["background.widgets.clock.style"] = style;
            updates["background.widgets.clock.digital.adaptToWallpaper"] = adaptToWallpaper;
            if (style === "cookie") {
                updates["background.widgets.clock.cookie.hourMarks"] = true;
                updates["background.widgets.clock.cookie.timeIndicators"] = true;
                updates["background.widgets.clock.cookie.dialNumberStyle"] = "full";
                updates["background.widgets.clock.cookie.minuteHandStyle"] = "medium";
                updates["background.widgets.clock.cookie.hourHandStyle"] = "fill";
                updates["background.widgets.clock.cookie.secondHandStyle"] = "classic";
                updates["background.widgets.clock.cookie.dateStyle"] = "bubble";
            }
            Config.setNestedValues(updates);
            return style + (adaptToWallpaper ? " adaptive" : " static");
        }

        function clockDebugSetRegion(color: string, brightness: real, spread: real): string {
            if (Quickshell.env("INIR_REGION_DEBUG") !== "1")
                return "clock diagnostics disabled; load with INIR_REGION_DEBUG=1";
            const parsed = Qt.color(color);
            if (!parsed.valid)
                return "invalid color: " + color;
            backgroundScope.clockDebugRegionColor = parsed;
            backgroundScope.clockDebugRegionBrightness = Math.max(0, Math.min(1, brightness));
            backgroundScope.clockDebugRegionSpread = Math.max(0, Math.min(1, spread));
            backgroundScope.clockDebugRegionActive = true;
            return "region injected";
        }

        function clockDebugSetLayout(x: int, y: int, quickControlsOpen: bool): string {
            if (Quickshell.env("INIR_REGION_DEBUG") !== "1")
                return "clock diagnostics disabled; load with INIR_REGION_DEBUG=1";
            if (!backgroundScope._clockDebugEditModeSnapshotValid) {
                backgroundScope._clockDebugEditModeSnapshot = GlobalStates.widgetEditMode;
                backgroundScope._clockDebugEditModeSnapshotValid = true;
            }
            backgroundScope.clockDebugLayoutProbeX = x;
            backgroundScope.clockDebugLayoutProbeY = y;
            backgroundScope.clockDebugLayoutProbeActive = true;
            GlobalStates.setWidgetEditMode(true);
            backgroundScope.clockDebugQuickControlsOpen = quickControlsOpen;
            return "layout probe requested";
        }

        function clockDebugRestore(): string {
            backgroundScope.clockDebugRegionActive = false;
            backgroundScope.clockDebugQuickControlsOpen = false;
            backgroundScope.clockDebugLayoutProbeActive = false;
            if (backgroundScope._clockDebugSnapshot !== null) {
                Config.setNestedValues(backgroundScope._clockDebugSnapshot);
                backgroundScope._clockDebugSnapshot = null;
            }
            if (backgroundScope._clockDebugEditModeSnapshotValid) {
                GlobalStates.setWidgetEditMode(backgroundScope._clockDebugEditModeSnapshot);
                backgroundScope._clockDebugEditModeSnapshotValid = false;
            }
            return "clock diagnostics restored";
        }
    }

    function _captureClockDebugSnapshot(): void {
        if (backgroundScope._clockDebugSnapshot !== null)
            return;
        const prefix = "background.widgets.clock";
        let snapshot = {};
        snapshot[prefix + ".style"] = Config.getNestedValue(prefix + ".style", "cookie");
        snapshot[prefix + ".digital.adaptToWallpaper"] = Config.getNestedValue(prefix + ".digital.adaptToWallpaper", true);
        snapshot[prefix + ".cookie.hourMarks"] = Config.getNestedValue(prefix + ".cookie.hourMarks", false);
        snapshot[prefix + ".cookie.timeIndicators"] = Config.getNestedValue(prefix + ".cookie.timeIndicators", true);
        snapshot[prefix + ".cookie.dialNumberStyle"] = Config.getNestedValue(prefix + ".cookie.dialNumberStyle", "none");
        snapshot[prefix + ".cookie.minuteHandStyle"] = Config.getNestedValue(prefix + ".cookie.minuteHandStyle", "medium");
        snapshot[prefix + ".cookie.hourHandStyle"] = Config.getNestedValue(prefix + ".cookie.hourHandStyle", "fill");
        snapshot[prefix + ".cookie.secondHandStyle"] = Config.getNestedValue(prefix + ".cookie.secondHandStyle", "dot");
        snapshot[prefix + ".cookie.dateStyle"] = Config.getNestedValue(prefix + ".cookie.dateStyle", "bubble");
        backgroundScope._clockDebugSnapshot = snapshot;
    }

    Variants {
        id: root
        model: Quickshell.screens

        // Shared cache for magick identify results across all monitor instances.
        // Avoids re-running the subprocess for previously-seen wallpapers.
        property var _wallpaperSizeCache: ({})
        property var _wallpaperSizeCacheKeys: []
        readonly property int _wallpaperSizeCacheLimit: 64

        function cacheWallpaperSize(path, width, height) {
            const cache = Object.assign({}, root._wallpaperSizeCache)
            const keys = root._wallpaperSizeCacheKeys.slice()
            const existingIndex = keys.indexOf(path)
            if (existingIndex >= 0)
                keys.splice(existingIndex, 1)

            cache[path] = { width: width, height: height }
            keys.push(path)
            while (keys.length > root._wallpaperSizeCacheLimit) {
                const oldestPath = keys.shift()
                delete cache[oldestPath]
            }

            root._wallpaperSizeCache = cache
            root._wallpaperSizeCacheKeys = keys
        }

    PanelWindow {
        id: bgRoot

        required property var modelData
        readonly property Item wallpaperLayer: wallpaperContainer

        // Hide when fullscreen
        property list<HyprlandWorkspace> workspacesForMonitor: CompositorService.isHyprland ? Hyprland.workspaces.values.filter(workspace => workspace.monitor && workspace.monitor.name == monitor.name) : []
        property var activeWorkspaceWithFullscreen: workspacesForMonitor.filter(workspace => ((workspace.toplevels.values.filter(window => window.wayland?.fullscreen)[0] != undefined) && workspace.active))[0]
        property bool hasFullscreenWindow: {
            if (CompositorService.isHyprland) {
                return activeWorkspaceWithFullscreen != undefined
            }
            if (CompositorService.isNiri) {
                return GameMode.hasFullscreenOnOutput(modelData?.name ?? "")
            }
            return false
        }
        visible: GlobalStates.screenLocked
            || !hasFullscreenWindow
            || !(Config.options?.background?.hideWhenFullscreen ?? false)

        // Workspaces
        property HyprlandMonitor monitor: CompositorService.isHyprland ? Hyprland.monitorFor(modelData) : null
        property list<var> relevantWindows: CompositorService.isHyprland ? HyprlandData.windowList.filter(win => win.monitor == monitor?.id && win.workspace.id >= 0).sort((a, b) => a.workspace.id - b.workspace.id) : []
        property int firstWorkspaceId: relevantWindows[0]?.workspace.id || 1
        property int lastWorkspaceId: relevantWindows[relevantWindows.length - 1]?.workspace.id || 10
        readonly property string screenName: screen?.name ?? ""
        readonly property var backgroundOptions: Config.options?.background ?? {}
        readonly property var parallaxOptions: backgroundOptions.parallax ?? {}
        readonly property var effectsOptions: backgroundOptions.effects ?? {}
        readonly property bool webWallpaperActive: WebWallpaper.active
        readonly property var workSafetyOptions: Config.options?.workSafety ?? {}
        readonly property var workSafetyEnableOptions: workSafetyOptions.enable ?? {}
        readonly property var workSafetyTriggerOptions: workSafetyOptions.triggerCondition ?? {}
        readonly property var lockBlurOptions: Config.options?.panelFamily === "iris" ? ({}) : (Config.options?.lock?.blur ?? {})
        readonly property var desktopFreeWorkArea: ShellLayoutController.desktopWorkArea(
            screen?.name ?? "", screen?.width ?? 0, screen?.height ?? 0)
        readonly property var desktopItemsWorkArea: ShellLayoutController.desktopZoneWorkArea(
            screen?.name ?? "", screen?.width ?? 0, screen?.height ?? 0)
        function _widgetConfigValue(widgetKey: string, key: string, fallback: var): var {
            return DesktopWidgetLayout.value(bgRoot.screenName, widgetKey, key, fallback);
        }
        function _widgetEnabled(widgetKey: string, fallback: bool): bool {
            return DesktopWidgetLayout.enabled(bgRoot.screenName, widgetKey, fallback);
        }

        property int _imageRouteRevision: 0
        property var _pendingImageConversion: null
        property var _conversionPlacement: null
        property int _imageConversionRouteAttempts: 0
        readonly property int _imageConversionRouteMaxAttempts: 40

        function _loadedWidget(widgetName: string): var {
            if (!widgetCanvas || typeof widgetCanvas._loadedDesktopWidgets !== "function")
                return null
            return widgetCanvas._loadedDesktopWidgets().find(item =>
                String(item?.configEntryName ?? "") === widgetName) ?? null
        }

        function _routeDecorativeImage(paths, x, y): void {
            const path = String(paths?.[0] ?? "").trim()
            if (path.length === 0)
                return
            const work = bgRoot.desktopFreeWorkArea
            const size = Math.max(80, Number(Config.getNestedValue(
                "background.widgets.customImage.size", 220)))
            const maxX = Math.max(Number(work.left ?? 0), Number(work.right ?? bgRoot.screen.width) - size)
            const maxY = Math.max(Number(work.top ?? 0), Number(work.bottom ?? bgRoot.screen.height) - size)
            Config.setNestedValues({
                "background.widgets.customImage.sourceMode": "file",
                "background.widgets.customImage.path": path
            })
            DesktopWidgetLayout.setValues(bgRoot.screenName, "customImage", {
                enable: true,
                placementStrategy: "free",
                x: Math.max(Number(work.left ?? 0), Math.min(maxX, x - size / 2)),
                y: Math.max(Number(work.top ?? 0), Math.min(maxY, y - size / 2))
            })
            imageChoice.showNotice(paths.length > 1
                ? Translation.tr("Decorative image uses the first dropped image.")
                : Translation.tr("Decorative image added."), x, y)
        }

        function _routeImageConversion(paths, x, y): void {
            const valid = Array.from(paths ?? []).filter(path => Images.isValidImageByName(String(path)))
            if (valid.length === 0)
                return
            bgRoot._conversionPlacement = { x: x, y: y }
            bgRoot._pendingImageConversion = valid
            bgRoot._imageConversionRouteAttempts = 0
            DesktopWidgetLayout.setEnabled(bgRoot.screenName, "imageConverter", true)
            imageConversionRouteTimer.restart()
        }

        function _handleImageChoice(action): void {
            const paths = imageChoice.imagePaths.slice()
            const resultPaths = imageChoice.resultPaths.slice()
            const x = imageChoice.requestedX
            const y = imageChoice.requestedY
            imageChoice.open = false
            if (action === "access")
                desktopDropCoordinator.createAccesses(paths, x, y)
            else if (action === "decorative")
                bgRoot._routeDecorativeImage(paths, x, y)
            else if (action === "convert")
                bgRoot._routeImageConversion(paths, x, y)
            else if (action === "place-results")
                desktopDropCoordinator.createAccesses(resultPaths, x, y)
        }

        Timer {
            id: imageConversionRouteTimer
            interval: 50
            repeat: true
            onTriggered: {
                bgRoot._imageConversionRouteAttempts++
                const converter = bgRoot._loadedWidget("imageConverter")
                if (!converter || typeof converter.enqueueFiles !== "function") {
                    if (bgRoot._imageConversionRouteAttempts < bgRoot._imageConversionRouteMaxAttempts)
                        return
                    const placement = bgRoot._conversionPlacement
                    bgRoot._pendingImageConversion = null
                    bgRoot._conversionPlacement = null
                    bgRoot._imageConversionRouteAttempts = 0
                    imageConversionRouteTimer.stop()
                    if (placement)
                        imageChoice.showNotice(Translation.tr("Could not open the image converter."), placement.x, placement.y)
                    return
                }
                const paths = bgRoot._pendingImageConversion
                bgRoot._pendingImageConversion = null
                bgRoot._imageConversionRouteAttempts = 0
                imageConversionRouteTimer.stop()
                converter.enqueueFiles(paths)
            }
        }

        Connections {
            target: Config
            function onRevisionChanged() { bgRoot._imageRouteRevision++ }
        }

        Connections {
            target: {
                void bgRoot._imageRouteRevision
                return bgRoot._loadedWidget("imageConverter")
            }
            function onConversionFinished(paths) {
                if (!bgRoot._conversionPlacement || !paths || paths.length === 0)
                    return
                const placement = bgRoot._conversionPlacement
                bgRoot._conversionPlacement = null
                imageChoice.showResults(paths, placement.x, placement.y)
            }
        }

        // An OnDemand layer that took keyboard focus (a click on the desktop)
        // keeps it across workspace switches and focus-window actions on Niri,
        // so the new workspace's window never receives focus and the Dock needs
        // a second click. Dropping to None for a moment hands focus back to the
        // compositor's focused window; re-arming a mapped surface never grabs it.
        property bool _keyboardReleased: false
        function releaseKeyboard(): void {
            if (bgRoot._menuOpen || (!bgRoot._needsKeyboardFocus && !bgRoot._keyboardReleased)) return
            bgRoot._keyboardReleased = true
            keyboardRearm.restart()
        }
        Timer { id: keyboardRearm; interval: 120; onTriggered: bgRoot._keyboardReleased = false }
        Connections {
            target: CompositorService.isNiri ? NiriService : null
            function onFocusedWorkspaceIdChanged(): void { bgRoot.releaseKeyboard() }
            function onWindowFocusRequested(): void { bgRoot.releaseKeyboard() }
        }

        // True if any widget on this background needs keyboard input (sticky notes
        // today, future text-entry widgets later). Used to flip the layer-shell
        // surface to focusable=true so TextEdits actually receive key events.
        // Without this the Bottom layer is keyboard-inert and clicks reach the
        // TextEdit but typing does nothing.
        // Desktop items remain pointer-driven until their focus contract is
        // owned by the background surface; do not make a stale global selection
        // turn the Bottom layer keyboard-focusable during reload.
        // A desktop menu is a grabbing popup of this surface: its parent's keyboard
        // mode never changes while one is open.
        readonly property bool _menuOpen: irisDesktopMenu.active || desktopContextMenu.active || desktopItemContextMenu.active
        // Once a desktop menu has closed, the keyboard its right-click took goes back too.
        on_MenuOpenChanged: if (!bgRoot._menuOpen) Qt.callLater(bgRoot.releaseKeyboard)
        readonly property bool _needsKeyboardFocus: GlobalStates.deferredPanelsReady
            && (bgRoot._menuOpen || !bgRoot._keyboardReleased)
            && (GlobalStates.widgetEditMode
                || bgRoot._widgetEnabled("notes", false)
                || bgRoot._widgetEnabled("todo", false))

        // Zone occupancy: map zone name → array of widget names
        readonly property var _builtinWidgets: [
            { key: "weather",            defaultOn: false, icon: "cloud" },
            { key: "clock",              defaultOn: true,  icon: "schedule" },
            { key: "customImage",        defaultOn: false, icon: "add_photo_alternate" },
            { key: "imageConverter",     defaultOn: false, icon: "transform" },
            { key: "mediaControls",      defaultOn: false, icon: "album" },
            { key: "visualizer",         defaultOn: false, icon: "graphic_eq" },
            { key: "systemMonitor",      defaultOn: false, icon: "monitor_heart" },
            { key: "battery",            defaultOn: false, icon: "battery_full" },
            { key: "notes",              defaultOn: false, icon: "sticky_note_2" },
            { key: "calendarUpcoming",   defaultOn: false, icon: "event" },
            { key: "monthCalendar",      defaultOn: false, icon: "calendar_month" },
            { key: "todo",               defaultOn: false, icon: "checklist" },
            { key: "timers",             defaultOn: false, icon: "timer" },
            { key: "uptime",             defaultOn: false, icon: "avg_pace" },
            { key: "shape", defaultOn: false, icon: "category" },
            { key: "dateBadge", defaultOn: false, icon: "today" },
            { key: "editorial", defaultOn: false, icon: "text_fields" },
            { key: "newsTicker",         defaultOn: false, icon: "newspaper" },
            { key: "mascot",             defaultOn: false, icon: "pets" },
            { key: "japaneseTypography", defaultOn: false, icon: "translate" },
            { key: "worldClock",         defaultOn: false, icon: "public" },
            { key: "userCard",           defaultOn: false, icon: "account_circle" },
            { key: "controls",           defaultOn: false, icon: "toggle_on" },
            { key: "screenTime",         defaultOn: false, icon: "hourglass_bottom" }
        ]
        // Revision counter to force re-evaluation
        property int _zoneRevision: 0
        Connections {
            target: Config
            function onConfigChanged() { bgRoot._zoneRevision++ }
        }
        function _computeZoneOccupants(): var {
            void bgRoot._zoneRevision; // bind to revision
            const zones = ["topLeft", "topCenter", "topRight", "centerLeft", "center", "centerRight", "bottomLeft", "bottomCenter", "bottomRight"];
            let occ = {};
            for (const z of zones) occ[z] = [];
            for (const w of bgRoot._builtinWidgets) {
                if (!bgRoot._widgetEnabled(w.key, w.defaultOn)) continue;
                const strat = bgRoot._widgetConfigValue(w.key, "placementStrategy", "free");
                if (zones.indexOf(strat) >= 0)
                    occ[strat].push({ name: w.key, icon: w.icon, locked: Boolean(bgRoot._widgetConfigValue(w.key, "locked", false)) });
            }
            // Extra mascot instances
            {
                const extraMascots = Config.getNestedValue("background.widgets.mascotInstances", {}) ?? {};
                for (const id of Object.keys(extraMascots)) {
                    const prefix = "background.widgets.mascotInstances." + id;
                    if (!Config.getNestedValue(prefix + ".enable", false)) continue;
                    const strat = Config.getNestedValue(prefix + ".placementStrategy", "free");
                    if (zones.indexOf(strat) >= 0)
                        occ[strat].push({ name: "mascot #" + id, icon: "pets", locked: Boolean(Config.getNestedValue(prefix + ".locked", false)) });
                }
            }
            // Custom widgets
            if (typeof CustomWidgets !== "undefined" && CustomWidgets.ready) {
                const list = CustomWidgets.widgets;
                for (let i = 0; i < list.length; i++) {
                    const cw = list[i];
                    if (!Config.getNestedValue("background.widgets.custom." + cw.id + ".enable", false)) continue;
                    const strat = Config.getNestedValue("background.widgets.custom." + cw.id + ".placementStrategy", "free");
                    if (zones.indexOf(strat) >= 0)
                        occ[strat].push({ name: cw.name || cw.id, icon: cw.icon || "widgets", locked: Boolean(Config.getNestedValue("background.widgets.custom." + cw.id + ".locked", false)) });
                }
            }
            return occ;
        }
        readonly property var zoneOccupants: _computeZoneOccupants()

        // Multi-monitor wallpaper support
        // IMPORTANT: Only use WallpaperListener when multi-monitor is enabled.
        // When disabled, use direct config path to preserve QML reactive bindings
        // that Aurora glass/blur depends on.
        readonly property bool _multiMonEnabled: WallpaperListener.multiMonitorEnabled
        readonly property string monitorName: {
            if (CompositorService.isNiri) {
                return modelData.name ?? ""
            } else if (CompositorService.isHyprland && bgRoot.monitor) {
                return bgRoot.monitor.name ?? ""
            }
            return modelData.name ?? ""
        }
        readonly property var wallpaperData: _multiMonEnabled
            ? (WallpaperListener.effectivePerMonitor[monitorName] ?? { path: "" })
            : ({ path: "" })

        // Per-monitor workspace range for parallax
        readonly property bool usePerMonitorRange: _multiMonEnabled &&
            (wallpaperData.workspaceFirst !== undefined && wallpaperData.workspaceLast !== undefined)
        readonly property int effectiveWorkspaceFirst: usePerMonitorRange ? wallpaperData.workspaceFirst : 1
        readonly property int effectiveWorkspaceLast: usePerMonitorRange ? wallpaperData.workspaceLast : (Config.options?.bar?.workspaces?.shown ?? 10)

        // Wallpaper — use per-monitor path when multi-monitor enabled, otherwise direct config
        readonly property string wallpaperPathRaw: {
            const configuredPath = (_multiMonEnabled && wallpaperData.path)
                ? wallpaperData.path
                : (bgRoot.backgroundOptions.wallpaperPath ?? "")
            // Supplies the preview path only. awww eligibility is untouched, so
            // whichever engine already owns this wallpaper keeps owning it.
            return Wallpapers.internalPreviewFor(monitorName, configuredPath)
        }
        readonly property string wallpaperThumbnailPath: bgRoot.backgroundOptions.thumbnailPath ?? bgRoot.wallpaperPathRaw
        readonly property bool enableAnimation: bgRoot.backgroundOptions.enableAnimation ?? true
        // True while ii is the family actually painting the screen. The family
        // LazyLoader can retain the inactive tree, so every heavy source in here
        // has to ask, not assume.
        readonly property bool _familyOwnsScreen: ["ii", "iris"].includes(Config.options?.panelFamily ?? "ii")
        property bool wallpaperIsVideo: wallpaperPathRaw.endsWith(".mp4") || wallpaperPathRaw.endsWith(".webm") || wallpaperPathRaw.endsWith(".mkv") || wallpaperPathRaw.endsWith(".avi") || wallpaperPathRaw.endsWith(".mov")
        property bool wallpaperIsGif: wallpaperPathRaw.toLowerCase().endsWith(".gif")
        property string wallpaperPath: bgRoot.wallpaperPathRaw
        property bool wallpaperSafetyTriggered: {
            const enabled = bgRoot.workSafetyEnableOptions.wallpaper ?? false;
            const fileKeywords = bgRoot.workSafetyTriggerOptions.fileKeywords ?? [];
            const networkKeywords = bgRoot.workSafetyTriggerOptions.networkNameKeywords ?? [];
            const sensitiveWallpaper = (CF.StringUtils.stringListContainsSubstring(wallpaperPath.toLowerCase(), fileKeywords));
            const sensitiveNetwork = (CF.StringUtils.stringListContainsSubstring(Network.networkName.toLowerCase(), networkKeywords));
            return enabled && sensitiveWallpaper && sensitiveNetwork;
        }
        readonly property string fillMode: bgRoot.backgroundOptions.fillMode ?? "fill"
        readonly property var panOptions: bgRoot.backgroundOptions.pan ?? {}
        readonly property real panX: bgRoot.panOptions.x ?? 0.0
        readonly property real panY: bgRoot.panOptions.y ?? 0.0
        readonly property real panZoom: Math.max(1.0, Math.min(3.0, bgRoot.panOptions.zoom ?? 1.0))
        readonly property bool hasPan: bgRoot.panX !== 0.0 || bgRoot.panY !== 0.0 || bgRoot.panZoom !== 1.0
        property string _panReadyWallpaperPath: bgRoot.wallpaperPath
        readonly property bool parallaxEnabled: bgRoot.parallaxOptions.enable
            ?? ((bgRoot.parallaxOptions.enableWorkspace ?? false) || (bgRoot.parallaxOptions.enableSidebar ?? false))
        readonly property bool workspaceParallaxEnabled: bgRoot.parallaxEnabled && (bgRoot.parallaxOptions.enableWorkspace ?? false)
        readonly property bool sidebarParallaxEnabled: bgRoot.parallaxEnabled && (bgRoot.parallaxOptions.enableSidebar ?? false)
        readonly property bool dynamicParallaxRequested: bgRoot.workspaceParallaxEnabled || bgRoot.sidebarParallaxEnabled
        readonly property real parallaxWorkspaceShift: ParallaxMath.resolveWorkspaceShift(bgRoot.parallaxOptions, 1)
        readonly property real parallaxPanelShift: ParallaxMath.resolvePanelShift(bgRoot.parallaxOptions, 0.15)
        readonly property real parallaxWidgetDepth: ParallaxMath.resolveWidgetDepth(bgRoot.parallaxOptions, 1.2)
        readonly property bool pauseParallaxDuringTransitions: bgRoot.parallaxOptions.pauseDuringTransitions ?? true
        readonly property int parallaxTransitionSettleMs: ParallaxMath.resolveTransitionSettle(bgRoot.parallaxOptions, 220)
        readonly property bool externalMainWallpaperEligible: !wallpaperSafetyTriggered
            && !bgRoot.webWallpaperActive
            && !((bgRoot.backgroundOptions.backdrop?.enable ?? false) && (bgRoot.backgroundOptions.backdrop?.hideWallpaper ?? false))
            && AwwwBackend.supportsVisibleMainWallpaper(
                bgRoot.wallpaperPathRaw,
                bgRoot.fillMode,
                bgRoot.dynamicParallaxRequested,
                bgRoot.effectsOptions.enableAnimatedBlur ?? false
            )
        readonly property bool effectiveHasPan: bgRoot.hasPan
            && (!bgRoot.externalMainWallpaperEligible || bgRoot._panReadyWallpaperPath === bgRoot.wallpaperPath)
        // Internal shader transitions are rendered by the QML background. Keep
        // that renderer as the visible owner for the whole static-wallpaper
        // lifecycle instead of handing ownership AWWW -> QML -> AWWW around
        // every transition. A transient ownership handoff can expose the AWWW
        // wallpaper underneath for one or more compositor frames.
        readonly property bool externalMainWallpaperActive: bgRoot.externalMainWallpaperEligible
            && !bgRoot.effectiveHasPan
            && !bgRoot.internalShaderTransitionRequested
        property real preferredWallpaperScale: ParallaxMath.resolveZoom(bgRoot.parallaxOptions, 1.0)
        property real _manualWallpaperScaleOverride: 0
        property int wallpaperWidth: modelData.width
        property int wallpaperHeight: modelData.height
        readonly property real baseWallpaperScale: ParallaxMath.effectiveScale(
            wallpaperWidth,
            wallpaperHeight,
            screen.width,
            screen.height,
            preferredWallpaperScale
        )
        readonly property real effectiveWallpaperScale: {
            const overrideScale = Number(bgRoot._manualWallpaperScaleOverride)
            const baseScale = Number.isFinite(overrideScale) && overrideScale > 0 ? overrideScale : bgRoot.baseWallpaperScale
            return bgRoot.effectiveHasPan ? baseScale * bgRoot.panZoom : baseScale
        }
        readonly property real scaledWallpaperWidth: bgRoot.wallpaperWidth * bgRoot.effectiveWallpaperScale
        readonly property real scaledWallpaperHeight: bgRoot.wallpaperHeight * bgRoot.effectiveWallpaperScale
        readonly property real parallaxTotalX: ParallaxMath.parallaxTotalPixels(bgRoot.scaledWallpaperWidth, bgRoot.screen.width)
        readonly property real parallaxTotalY: ParallaxMath.parallaxTotalPixels(bgRoot.scaledWallpaperHeight, bgRoot.screen.height)
        readonly property string parallaxAxis: ParallaxMath.resolveAxis(
            bgRoot.parallaxOptions.axis,
            bgRoot.parallaxOptions.autoVertical ?? false,
            bgRoot.parallaxOptions.vertical ?? false,
            wallpaperWidth,
            wallpaperHeight
        )
        readonly property bool verticalParallax: bgRoot.parallaxAxis === "vertical"
        
        // Backdrop mode
        readonly property bool backdropActive: (bgRoot.backgroundOptions.backdrop?.enable ?? false) && (bgRoot.backgroundOptions.backdrop?.hideWallpaper ?? false)

        readonly property bool internalShaderTransitionRequested:
            (Config.options?.background?.transition?.enable ?? true)
            && Appearance.animationsEnabled
            && !bgRoot.webWallpaperActive
            && AwwwBackend.isInternalShaderTransitionType(
                Config.options?.background?.transition?.type ?? "crossfade")
            && !bgRoot.wallpaperIsGif
            && !bgRoot.wallpaperIsVideo
            && !bgRoot.wallpaperSafetyTriggered
            && !bgRoot.backdropActive
        readonly property bool internalShaderPreviewActive: bgRoot.internalShaderTransitionRequested
            && Wallpapers.internalPreviewActive
            && (!Wallpapers.internalPreviewMonitor
                || Wallpapers.internalPreviewMonitor === bgRoot.monitorName)

        // awww reveal: when parallax is active and awww handles wallpaper,
        // instantly hide crossfader, let awww transition play, then fade back in.
        property real _awwwRevealOpacity: 1
        readonly property bool _awwwParallaxRevealNeeded: AwwwBackend.active
            && !bgRoot.internalShaderTransitionRequested
            && bgRoot.dynamicParallaxRequested
            && !bgRoot.wallpaperIsGif
            && !bgRoot.wallpaperIsVideo
            && !bgRoot.wallpaperSafetyTriggered
            && !bgRoot.backdropActive
        
        readonly property int _wallpaperTransitionDurationMs: {
            const transitionBaseDuration = Config.options?.background?.transition?.duration ?? 800
            const qmlTransitionDuration = (Config.options?.background?.transition?.enable ?? true)
                ? Appearance.calcEffectiveDuration(transitionBaseDuration)
                : 0
            const awwwTransitionDuration = AwwwBackend.active ? AwwwBackend.transitionDurationMs : 0
            return Math.max(qmlTransitionDuration, awwwTransitionDuration)
        }
        property bool parallaxTransitionActive: false
        property real parallaxResumeProgress: 1
        property real parallaxFreezeValueX: 0.5
        property real parallaxFreezeValueY: 0.5
        property bool _parallaxWaitingCrossfader: false
        property string _parallaxTransitionReason: ""
        property string pendingWallpaperMetricsPath: ""
        property string activeWallpaperMetricsPath: ""

        function beginParallaxTransition(waitForCrossfader: bool, reason: string): void {
            if (!bgRoot.dynamicParallaxRequested || !bgRoot.pauseParallaxDuringTransitions)
                return

            if (waitForCrossfader && bgRoot.parallaxTransitionActive && bgRoot._parallaxWaitingCrossfader)
                return

            const currentX = Number(wallpaperContainer ? wallpaperContainer.activeValueX : 0.5)
            const currentY = Number(wallpaperContainer ? wallpaperContainer.activeValueY : 0.5)
            bgRoot.parallaxFreezeValueX = Number.isFinite(currentX) ? currentX : 0.5
            bgRoot.parallaxFreezeValueY = Number.isFinite(currentY) ? currentY : 0.5
            bgRoot.parallaxTransitionActive = true
            bgRoot.parallaxResumeProgress = 0
            bgRoot._parallaxWaitingCrossfader = waitForCrossfader
            bgRoot._parallaxTransitionReason = String(reason ?? "")
            parallaxResumeAnimation.stop()
            parallaxTransitionPauseTimer.stop()
            parallaxTransitionWatchdog.stop()

            if (!waitForCrossfader) {
                parallaxTransitionPauseTimer.interval = bgRoot._wallpaperTransitionDurationMs + bgRoot.parallaxTransitionSettleMs
                parallaxTransitionPauseTimer.restart()
            } else {
                parallaxTransitionWatchdog.interval = Math.max(
                    1000,
                    bgRoot._wallpaperTransitionDurationMs + bgRoot.parallaxTransitionSettleMs + 500
                )
                parallaxTransitionWatchdog.restart()
            }
        }

        function settleParallaxAfterTransition(): void {
            if (!bgRoot.parallaxTransitionActive)
                return
            bgRoot._parallaxWaitingCrossfader = false
            parallaxTransitionWatchdog.stop()
            parallaxTransitionPauseTimer.interval = bgRoot.parallaxTransitionSettleMs
            parallaxTransitionPauseTimer.restart()
        }

        function pauseParallaxForWallpaperTransition(): void {
            if (!bgRoot.dynamicParallaxRequested || !bgRoot.pauseParallaxDuringTransitions)
                return
            if (bgRoot.wallpaperIsGif || bgRoot.wallpaperIsVideo)
                return

            const crossfaderTransitionsEnabled = (!AwwwBackend.active
                    || bgRoot.internalShaderTransitionRequested)
                && (Config.options?.background?.transition?.enable ?? true)

            if (!crossfaderTransitionsEnabled && bgRoot._wallpaperTransitionDurationMs <= 0)
                return

            bgRoot.beginParallaxTransition(crossfaderTransitionsEnabled, "wallpaper")
        }

        function queueWallpaperMetricsUpdate(path: string): void {
            const normalizedPath = String(path ?? "")
            if (!normalizedPath || normalizedPath.length === 0)
                return
            if (bgRoot.wallpaperIsVideo || bgRoot.wallpaperSafetyTriggered)
                return

            bgRoot.pendingWallpaperMetricsPath = normalizedPath
            if (bgRoot.activeWallpaperMetricsPath.length === 0)
                bgRoot.startNextWallpaperMetricsRequest()
        }

        function startNextWallpaperMetricsRequest(): void {
            if (bgRoot.pendingWallpaperMetricsPath.length === 0)
                return

            const nextPath = bgRoot.pendingWallpaperMetricsPath
            bgRoot.pendingWallpaperMetricsPath = ""
            bgRoot.activeWallpaperMetricsPath = nextPath
            getWallpaperSizeProc.path = nextPath
            getWallpaperSizeProc.running = true
        }

        function finishWallpaperMetricsRequest(): void {
            bgRoot.activeWallpaperMetricsPath = ""
            if (bgRoot.pendingWallpaperMetricsPath.length > 0)
                bgRoot.startNextWallpaperMetricsRequest()

            // Invariant: never keep manual override after reveal/metrics settle.
            if (bgRoot.pendingWallpaperMetricsPath.length === 0 && bgRoot._awwwRevealOpacity >= 1)
                bgRoot._manualWallpaperScaleOverride = 0
        }

        // Colors
        property bool shouldBlur: (GlobalStates.screenLocked && (bgRoot.lockBlurOptions.enable ?? false))
        property color dominantColor: Appearance.colors.colPrimary
        property bool dominantColorIsDark: dominantColor.hslLightness < 0.5
        property color colText: {
            if (wallpaperSafetyTriggered)
                return CF.ColorUtils.mix(Appearance.colors.colOnLayer0, Appearance.colors.colPrimary, 0.75);
            return (GlobalStates.screenLocked && shouldBlur) ? Appearance.colors.colOnLayer0 : CF.ColorUtils.colorWithLightness(Appearance.colors.colPrimary, (dominantColorIsDark ? 0.8 : 0.12));
        }
        Behavior on colText {
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        // Dynamic focus based on windows
        property bool hasWindowsOnCurrentWorkspace: {
            try {
                if (CompositorService.isNiri && typeof NiriService !== "undefined" && NiriService.windows && NiriService.workspaces) {
                    const allWs = Object.values(NiriService.workspaces);
                    if (!allWs || allWs.length === 0) return false;
                    const outputName = bgRoot.modelData?.name ?? "";
                    const currentWs = allWs.find(ws => ws.output === outputName
                        && ws.is_active);
                    if (!currentWs) return false;
                    return NiriService.windows.some(w => w.workspace_id === currentWs.id);
                }
                if (CompositorService.isHyprland && monitor && monitor.activeWorkspace) {
                    const wsId = monitor.activeWorkspace.id;
                    return relevantWindows.some(w => w.workspace.id === wsId);
                }
                return relevantWindows.length > 0;
            } catch (e) { return false; }
        }

        property bool focusWindowsPresent: !GlobalStates.screenLocked && hasWindowsOnCurrentWorkspace
        property real focusPresenceProgress: focusWindowsPresent ? 1 : 0
        Behavior on focusPresenceProgress {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        // Runtime invariant:
        // - _manualWallpaperScaleOverride is temporary and must return to 0 after reveal/metrics settle.
        // - _awwwRevealOpacity must return to 1 after each wallpaper transition.
        // - _blurTransitionFactor must return to 1 even if transitions overlap.
        // This avoids stale zoom/overlay artifacts during rapid wallpaper changes.

        // Blur suppression during wallpaper transitions — briefly fades blur out
        // so awww/crossfader transitions are visible, then fades back in.
        property real _blurTransitionFactor: 1
        property int _blurHoldDurationMs: 0
        function beginBlurSuppression(totalTransitionMs: int): void {
            if (bgRoot.blurProgress <= 0)
                return
            const holdMs = Math.max(0, totalTransitionMs)
            _blurTransitionAnimation.stop()
            bgRoot._blurTransitionFactor = 1
            bgRoot._blurHoldDurationMs = holdMs
            _blurTransitionAnimation.restart()
            _blurTransitionSafetyTimer.interval = holdMs + Appearance.calcEffectiveDuration(800)
            _blurTransitionSafetyTimer.restart()
        }
        SequentialAnimation {
            id: _blurTransitionAnimation
            NumberAnimation {
                target: bgRoot; property: "_blurTransitionFactor"
                to: 0; duration: Appearance.calcEffectiveDuration(200); easing.type: Easing.OutQuad
            }
            PauseAnimation {
                duration: bgRoot._blurHoldDurationMs
            }
            NumberAnimation {
                target: bgRoot; property: "_blurTransitionFactor"
                to: 1; duration: Appearance.calcEffectiveDuration(400); easing.type: Easing.InOutQuad
            }
        }
        Timer {
            id: _blurTransitionSafetyTimer
            interval: bgRoot._wallpaperTransitionDurationMs + Appearance.calcEffectiveDuration(1200)
            repeat: false
            onTriggered: bgRoot._blurTransitionFactor = 1
        }

        property real blurProgress: {
            const effects = bgRoot.effectsOptions;
            if (!(effects?.enableBlur && (effects?.blurRadius ?? 0) > 0)) return 0;
            return focusPresenceProgress * _blurTransitionFactor;
        }

        Connections {
            target: Wallpapers
            function onWallpaperBlurTransitionRequested(targetMonitors, durationMs): void {
                if (!targetMonitors || targetMonitors.length === 0 || targetMonitors.indexOf(bgRoot.monitorName) >= 0)
                    bgRoot.beginBlurSuppression(durationMs)
            }
        }

        // Layer props
        screen: modelData
        exclusionMode: ExclusionMode.Ignore
        // Keep background behind the lock surface. Moving this to Overlay can capture input.
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:background"
        // Map the desktop keyboard-inert during startup, then arm OnDemand after
        // the first-frame/deferred lifecycle has settled. Niri can temporarily
        // focus a newly mapped OnDemand layer surface during shell restart, which
        // loses the previously focused app. Changing an already-mapped surface to
        // OnDemand is safe and still lets Notes/Todo receive keyboard input.
        WlrLayershell.keyboardFocus: bgRoot._needsKeyboardFocus
            ? WlrKeyboardFocus.OnDemand
            : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }
        color: {
            if (!bgRoot.wallpaperSafetyTriggered || bgRoot.wallpaperIsVideo) return "transparent";
            return CF.ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colPrimary, 0.75);
        }
        Behavior on color {
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        onWallpaperPathChanged: {
            const normalizedPath = String(bgRoot.wallpaperPath ?? "")
            if (bgRoot.hasPan && bgRoot.externalMainWallpaperEligible) {
                bgRoot._panReadyWallpaperPath = ""
                panActivationTimer.restart()
            } else {
                bgRoot._panReadyWallpaperPath = normalizedPath
                panActivationTimer.stop()
            }
            bgRoot.pauseParallaxForWallpaperTransition()
            if (bgRoot._awwwParallaxRevealNeeded) {
                // Instantly hide crossfader BEFORE bindings propagate the new source.
                // The crossfader swaps to the new wallpaper at opacity:0 (invisible).
                _awwwRevealAnimation.stop()
                bgRoot._awwwRevealOpacity = 0
                bgRoot._manualWallpaperScaleOverride = bgRoot.baseWallpaperScale
                _awwwRevealAnimation.restart()
                _awwwRevealSafetyTimer.interval = bgRoot._wallpaperTransitionDurationMs + Appearance.calcEffectiveDuration(900)
                _awwwRevealSafetyTimer.restart()
            } else {
                _awwwRevealAnimation.stop()
                _awwwRevealSafetyTimer.stop()
                bgRoot._awwwRevealOpacity = 1
                bgRoot._manualWallpaperScaleOverride = 0
            }
            if (!Wallpapers._applyInProgress && bgRoot.blurProgress > 0) {
                bgRoot.beginBlurSuppression(bgRoot._wallpaperTransitionDurationMs)
            } else {
                _blurTransitionAnimation.stop()
                _blurTransitionSafetyTimer.stop()
                bgRoot._blurTransitionFactor = 1
            }
            bgRoot.updateZoomScale()
        }

        onHasPanChanged: {
            if (bgRoot.hasPan)
                return
            bgRoot._panReadyWallpaperPath = String(bgRoot.wallpaperPath ?? "")
            panActivationTimer.stop()
            bgRoot.updateZoomScale()
        }

        onPreferredWallpaperScaleChanged: {
            if (!bgRoot._awwwParallaxRevealNeeded) {
                bgRoot._manualWallpaperScaleOverride = 0
                return
            }
            if (_awwwRevealAnimation.running || bgRoot._awwwRevealOpacity < 1)
                bgRoot._manualWallpaperScaleOverride = bgRoot.baseWallpaperScale
        }

        onPanZoomChanged: {
            const normalizedPath = String(bgRoot.wallpaperPath ?? "")
            if (!bgRoot.hasPan) {
                bgRoot._panReadyWallpaperPath = normalizedPath
                panActivationTimer.stop()
                bgRoot.updateZoomScale()
                return
            }

            if (bgRoot.externalMainWallpaperEligible && bgRoot._panReadyWallpaperPath !== normalizedPath)
                return

            bgRoot._panReadyWallpaperPath = normalizedPath
            bgRoot.updateZoomScale()
        }

        function updateZoomScale(): void {
            wallpaperSizeDebounce.restart()
        }

        Timer {
            id: parallaxTransitionPauseTimer
            interval: bgRoot._wallpaperTransitionDurationMs + bgRoot.parallaxTransitionSettleMs
            repeat: false
            onTriggered: {
                parallaxTransitionWatchdog.stop()
                bgRoot._parallaxWaitingCrossfader = false
                bgRoot._parallaxTransitionReason = ""
                bgRoot.parallaxTransitionActive = false
                parallaxResumeAnimation.restart()
            }
        }

        Timer {
            id: parallaxTransitionWatchdog
            repeat: false
            onTriggered: {
                if (!bgRoot.parallaxTransitionActive || !bgRoot._parallaxWaitingCrossfader)
                    return
                bgRoot.settleParallaxAfterTransition()
            }
        }

        Connections {
            target: AwwwBackend
            function onActiveChanged(): void {
                if (!AwwwBackend.active)
                    return
                if (bgRoot._parallaxWaitingCrossfader && bgRoot._parallaxTransitionReason === "wallpaper")
                    bgRoot.settleParallaxAfterTransition()
            }
        }

        Connections {
            target: GlobalStates
            function onFamilyTransitionActiveChanged() {
                if (!bgRoot.dynamicParallaxRequested || !bgRoot.pauseParallaxDuringTransitions)
                    return

                if (GlobalStates.familyTransitionActive) {
                    bgRoot.beginParallaxTransition(true, "family")
                    return
                }

                if (bgRoot._parallaxWaitingCrossfader && bgRoot._parallaxTransitionReason === "family")
                    bgRoot.settleParallaxAfterTransition()
            }
        }

        Timer {
            id: panActivationTimer
            interval: bgRoot._wallpaperTransitionDurationMs + 120
            repeat: false
            onTriggered: {
                const normalizedPath = String(bgRoot.wallpaperPath ?? "")
                bgRoot._panReadyWallpaperPath = normalizedPath
                if (bgRoot.hasPan)
                    bgRoot.updateZoomScale()
            }
        }

        NumberAnimation {
            id: parallaxResumeAnimation
            target: bgRoot
            property: "parallaxResumeProgress"
            from: 0
            to: 1
            duration: Appearance.calcEffectiveDuration(260)
            easing.type: Easing.OutCubic
        }

        SequentialAnimation {
            id: _awwwRevealAnimation

            PauseAnimation {
                duration: AwwwBackend.transitionDurationMs + 400
            }
            NumberAnimation {
                target: bgRoot
                property: "_awwwRevealOpacity"
                to: 1
                duration: Appearance.calcEffectiveDuration(250)
                easing.type: Easing.OutQuad
            }
            onFinished: {
                bgRoot._awwwRevealOpacity = 1
                bgRoot._manualWallpaperScaleOverride = 0
                _awwwRevealSafetyTimer.stop()
            }
            onStopped: {
                if (!_awwwRevealAnimation.running && bgRoot._awwwRevealOpacity >= 1)
                    bgRoot._manualWallpaperScaleOverride = 0
            }
        }
        Timer {
            id: _awwwRevealSafetyTimer
            interval: bgRoot._wallpaperTransitionDurationMs + Appearance.calcEffectiveDuration(900)
            repeat: false
            onTriggered: {
                bgRoot._awwwRevealOpacity = 1
                bgRoot._manualWallpaperScaleOverride = 0
            }
        }

        Timer {
            id: wallpaperSizeDebounce
            // Fire magick identify quickly so the result arrives while the
            // crossfader transition is still running.  The container has
            // Behavior on width/height/x/y so the resize blends smoothly
            // with the ongoing transition instead of snapping afterwards.
            interval: 80
            repeat: false
            onTriggered: {
                if (!bgRoot.wallpaperPath || bgRoot.wallpaperPath.length === 0) return;
                if (bgRoot.wallpaperIsVideo) return;
                if (bgRoot.wallpaperSafetyTriggered) return;

                // Check shared cache before spawning a subprocess
                const cached = root._wallpaperSizeCache[bgRoot.wallpaperPath]
                if (cached) {
                    bgRoot.wallpaperWidth = cached.width
                    bgRoot.wallpaperHeight = cached.height
                    bgRoot._manualWallpaperScaleOverride = 0
                    return
                }

                bgRoot.queueWallpaperMetricsUpdate(bgRoot.wallpaperPath)
            }
        }

        Process {
            id: getWallpaperSizeProc
            property string path: bgRoot.wallpaperPath
            command: ["/usr/bin/magick", "identify", "-format", "%w %h", path]
            stdout: StdioCollector {
                id: wallpaperSizeOutputCollector
                onStreamFinished: {
                    const requestPath = bgRoot.activeWallpaperMetricsPath || getWallpaperSizeProc.path
                    const output = (wallpaperSizeOutputCollector.text ?? "").trim();
                    const parts = output.split(/\s+/).filter(Boolean);
                    const width = Number(parts[0]);
                    const height = Number(parts[1]);
                    const screenWidth = bgRoot.screen?.width ?? 0;
                    const screenHeight = bgRoot.screen?.height ?? 0;

                    if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0 || screenWidth <= 0 || screenHeight <= 0) {
                        console.warn("[Background] Failed to parse wallpaper size:", output);
                        bgRoot._manualWallpaperScaleOverride = 0
                        bgRoot.finishWallpaperMetricsRequest()
                        return;
                    }

                    if (requestPath !== bgRoot.wallpaperPath) {
                        bgRoot.finishWallpaperMetricsRequest()
                        return
                    }

                    bgRoot.wallpaperWidth = Math.round(width);
                    bgRoot.wallpaperHeight = Math.round(height);
                    bgRoot._manualWallpaperScaleOverride = 0

                    // Cache the result so subsequent switches to this wallpaper skip magick identify
                    root.cacheWallpaperSize(requestPath, Math.round(width), Math.round(height))

                    bgRoot.finishWallpaperMetricsRequest()
                }
            }
        }

        Item {
            anchors.fill: parent

            // Wallpaper container - used as reference for blur and widgets
            Item {
                id: wallpaperContainer
                property int chunkSize: bgRoot.usePerMonitorRange ?
                    (bgRoot.effectiveWorkspaceLast - bgRoot.effectiveWorkspaceFirst + 1) :
                    (Config?.options?.bar?.workspaces?.shown ?? 10)
                property int lower: bgRoot.usePerMonitorRange ?
                    bgRoot.effectiveWorkspaceFirst :
                    (Math.floor(bgRoot.firstWorkspaceId / chunkSize) * chunkSize)
                property int upper: bgRoot.usePerMonitorRange ?
                    bgRoot.effectiveWorkspaceLast :
                    (Math.ceil(bgRoot.lastWorkspaceId / chunkSize) * chunkSize)
                property int range: Math.max(1, upper - lower)
                property int currentWorkspaceId: CompositorService.isNiri ? (NiriService.focusedWorkspaceIndex ?? 1) : (bgRoot.monitor?.activeWorkspace?.id ?? 1)
                property real workspaceProgress: ParallaxMath.normalizedWorkspaceProgress(currentWorkspaceId, lower, upper)
                property real valueX: ParallaxMath.axisValue(
                    "horizontal",
                    bgRoot.parallaxAxis,
                    bgRoot.workspaceParallaxEnabled,
                    workspaceProgress,
                    bgRoot.parallaxWorkspaceShift,
                    bgRoot.sidebarParallaxEnabled,
                    [GlobalStates.sidebarLeftOpen],
                    [GlobalStates.sidebarRightOpen],
                    bgRoot.parallaxPanelShift
                )
                property real valueY: ParallaxMath.axisValue(
                    "vertical",
                    bgRoot.parallaxAxis,
                    bgRoot.workspaceParallaxEnabled,
                    workspaceProgress,
                    bgRoot.parallaxWorkspaceShift,
                    false,
                    [],
                    [],
                    0
                )
                property real effectiveValueX: Math.max(0, Math.min(1, valueX))
                property real effectiveValueY: Math.max(0, Math.min(1, valueY))
                
                // Internal rendering and parallax geometry are separate concerns.
                // Shader transitions temporarily move static wallpaper ownership into
                // QML, but that must not make the wallpaper container adopt source-
                // sized parallax geometry when parallax itself is disabled.
                readonly property bool useParallax: bgRoot.dynamicParallaxRequested
                    && bgRoot.fillMode === "fill"
                    && !bgRoot.wallpaperIsGif
                    && !bgRoot.wallpaperIsVideo
                    && !bgRoot.externalMainWallpaperActive
                readonly property bool showInternalStaticWallpaper: !bgRoot.externalMainWallpaperActive
                readonly property bool localBlurNeedsStaticTexture: Appearance.effectsEnabled
                    && bgRoot.blurProgress > 0
                    && (bgRoot.effectsOptions.enableBlur ?? false)
                    && !Config.options?.performance?.lowPower
                    && (bgRoot.effectsOptions.blurRadius ?? 0) > 0
                readonly property bool lockBlurNeedsStaticTexture: (bgRoot.lockBlurOptions.enable ?? false)
                    && (GlobalStates.screenLocked || scaleAnim.running)
                readonly property bool needsStaticTexture: !bgRoot.backdropActive
                    && !bgRoot.wallpaperIsGif && !bgRoot.wallpaperIsVideo
                    && (showInternalStaticWallpaper || localBlurNeedsStaticTexture
                        || lockBlurNeedsStaticTexture
                        || bgRoot.internalShaderTransitionRequested)
                readonly property real panOffsetX: bgRoot.effectiveHasPan ? (bgRoot.panX * (bgRoot.parallaxTotalX / 2)) : 0
                readonly property real panOffsetY: bgRoot.effectiveHasPan ? (bgRoot.panY * (bgRoot.parallaxTotalY / 2)) : 0
                readonly property real targetX: useParallax
                    ? (bgRoot.parallaxTotalX > 0
                        ? (ParallaxMath.parallaxPosition(bgRoot.parallaxTotalX, activeValueX) + panOffsetX)
                        : ParallaxMath.centerOffset(bgRoot.scaledWallpaperWidth, bgRoot.screen.width))
                    : panOffsetX
                readonly property real targetY: useParallax
                    ? (bgRoot.parallaxTotalY > 0
                        ? (ParallaxMath.parallaxPosition(bgRoot.parallaxTotalY, activeValueY) + panOffsetY)
                        : ParallaxMath.centerOffset(bgRoot.scaledWallpaperHeight, bgRoot.screen.height))
                    : panOffsetY
                readonly property real targetWidth: (useParallax || bgRoot.effectiveHasPan) ? bgRoot.scaledWallpaperWidth : bgRoot.screen.width
                readonly property real targetHeight: (useParallax || bgRoot.effectiveHasPan) ? bgRoot.scaledWallpaperHeight : bgRoot.screen.height
                x: targetX
                y: targetY
                Behavior on x {
                    enabled: Appearance.animationsEnabled
                        && (wallpaperContainer.useParallax || bgRoot.effectiveHasPan)
                        && ((!bgRoot.parallaxTransitionActive && bgRoot.parallaxResumeProgress >= 1)
                            || bgRoot._parallaxWaitingCrossfader)
                    animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                }
                Behavior on y {
                    enabled: Appearance.animationsEnabled
                        && (wallpaperContainer.useParallax || bgRoot.effectiveHasPan)
                        && ((!bgRoot.parallaxTransitionActive && bgRoot.parallaxResumeProgress >= 1)
                            || bgRoot._parallaxWaitingCrossfader)
                    animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                }
                width: targetWidth
                height: targetHeight
                // Animate container resize so it blends with the crossfader transition
                readonly property int _transitionBaseDuration: Config.options?.background?.transition?.duration ?? 800
                readonly property int _transitionDur: Appearance.calcEffectiveDuration(_transitionBaseDuration)
                readonly property var _transitionBezierRaw: Config.options?.background?.transition?.bezier ?? [0.54, 0.0, 0.34, 0.99]
                readonly property list<real> _transitionBezierCurve: {
                    const raw = _transitionBezierRaw
                    if (!raw || raw.length !== 4)
                        return [0.54, 0.0, 0.34, 0.99, 1, 1]
                    const x1 = Number(raw[0])
                    const y1 = Number(raw[1])
                    const x2 = Number(raw[2])
                    const y2 = Number(raw[3])
                    if (!Number.isFinite(x1) || !Number.isFinite(y1) || !Number.isFinite(x2) || !Number.isFinite(y2))
                        return [0.54, 0.0, 0.34, 0.99, 1, 1]
                    return [x1, y1, x2, y2, 1, 1]
                }
                // Container resize is NOT animated during crossfader transitions.
                // The crossfader handles its own transition visually; animating the
                // container size simultaneously causes double-image artifacts.
                Behavior on width {
                    enabled: Appearance.animationsEnabled
                        && (wallpaperContainer.useParallax || bgRoot.effectiveHasPan)
                        && bgRoot._awwwRevealOpacity >= 1
                        && !bgRoot.parallaxTransitionActive
                        && bgRoot.parallaxResumeProgress >= 1
                    NumberAnimation {
                        duration: wallpaperContainer._transitionDur
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: wallpaperContainer._transitionBezierCurve
                    }
                }
                Behavior on height {
                    enabled: Appearance.animationsEnabled
                        && (wallpaperContainer.useParallax || bgRoot.effectiveHasPan)
                        && bgRoot._awwwRevealOpacity >= 1
                        && !bgRoot.parallaxTransitionActive
                        && bgRoot.parallaxResumeProgress >= 1
                    NumberAnimation {
                        duration: wallpaperContainer._transitionDur
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: wallpaperContainer._transitionBezierCurve
                    }
                }

                readonly property real activeValueX: bgRoot.parallaxTransitionActive
                    ? bgRoot.parallaxFreezeValueX
                    : (bgRoot.parallaxFreezeValueX + ((effectiveValueX - bgRoot.parallaxFreezeValueX) * bgRoot.parallaxResumeProgress))
                readonly property real activeValueY: bgRoot.parallaxTransitionActive
                    ? bgRoot.parallaxFreezeValueY
                    : (bgRoot.parallaxFreezeValueY + ((effectiveValueY - bgRoot.parallaxFreezeValueY) * bgRoot.parallaxResumeProgress))

                // Static wallpaper — when awww manages the visible wallpaper
                // (externalMainWallpaperActive), this is just a hidden texture for blur.
                // Otherwise (parallax, unsupported fill mode, etc.), this is the visible
                // renderer and uses the user's transition settings.
                WallpaperCrossfader {
                    id: wallpaper
                    readonly property bool shaderOverlayHeld: bgRoot.internalShaderTransitionRequested
                        && (wallpaper.shaderTransitionBusy
                            || bgRoot.internalShaderPreviewActive
                            || AwwwBackend.shaderHandoffPending)
                    anchors.fill: parent
                    visible: !bgRoot.webWallpaperActive && !blurLoader.active && !bgRoot.backdropActive && !bgRoot.wallpaperIsGif && !bgRoot.wallpaperIsVideo
                    opacity: (wallpaperContainer.showInternalStaticWallpaper
                        || wallpaper.shaderOverlayHeld ? 1 : 0) * bgRoot._awwwRevealOpacity
                    // The backdrop replaces the desktop wallpaper outright: this
                    // crossfader is hidden, blurAlwaysLoader is off, and the lock
                    // blur cannot see it either (an invisible child never reaches
                    // the ShaderEffectSource texture). Nothing consumes it, so drop
                    // the source instead of holding a decoded fullscreen bitmap —
                    // an Image with a source decodes whether or not it is visible.
                    layer.enabled: wallpaperContainer.needsStaticTexture
                        && !wallpaperContainer.showInternalStaticWallpaper
                        && !wallpaper.shaderOverlayHeld
                    source: (bgRoot.webWallpaperActive || bgRoot.wallpaperSafetyTriggered || !wallpaperContainer.needsStaticTexture
                            || Wallpapers.isVideoFile(bgRoot.wallpaperPath))
                        ? "" : bgRoot.wallpaperPath
                    // NEVER use crossfader transitions when awww is active — awww handles all transitions.
                    // When parallax is on, the crossfader fades out to reveal awww's native transition.
                    enableTransitions: (!AwwwBackend.active
                            || bgRoot.internalShaderTransitionRequested)
                        && (Config.options?.background?.transition?.enable ?? true)
                    transitionType: Config.options?.background?.transition?.type ?? "crossfade"
                    transitionDirection: Config.options?.background?.transition?.direction ?? "right"
                    transitionBaseDuration: Config.options?.background?.transition?.duration ?? 800
                    fillMode: bgRoot.fillMode === "fit" ? Image.PreserveAspectFit
                            : bgRoot.fillMode === "tile" ? Image.Tile
                            : bgRoot.fillMode === "center" ? Image.Pad
                            : Image.PreserveAspectCrop

                    onTransitionStarted: {
                        if (!bgRoot.dynamicParallaxRequested || !bgRoot.pauseParallaxDuringTransitions)
                            return
                        bgRoot.beginParallaxTransition(true, "wallpaper")
                    }

                    onTransitionFinished: {
                        if (bgRoot._parallaxWaitingCrossfader && bgRoot._parallaxTransitionReason === "wallpaper")
                            bgRoot.settleParallaxAfterTransition()
                    }
                }

                // Animated GIF wallpaper
                // Always loaded for GIFs: plays when animation enabled, frozen (first frame) when disabled
                AnimatedImage {
                    id: gifWallpaper
                    anchors.fill: parent
                    visible: opacity > 0 && !blurLoader.active && !bgRoot.backdropActive && bgRoot.wallpaperIsGif && !bgRoot.externalMainWallpaperActive
                    opacity: (status === AnimatedImage.Ready && bgRoot.wallpaperIsGif) ? 1 : 0
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    cache: false
                    playing: visible && bgRoot.enableAnimation && !GlobalStates.screenLocked && !Appearance._gameModeActive && !Wallpapers.batteryPauseActive
                        && Wallpapers.videoMotionAllowedOn(bgRoot.screenName)
                    asynchronous: true
                    source: (bgRoot.webWallpaperActive || bgRoot.wallpaperSafetyTriggered || !bgRoot.wallpaperIsGif || bgRoot.backdropActive) ? "" : bgRoot.wallpaperPathRaw
                    fillMode: Image.PreserveAspectCrop
                    // No sourceSize for GIFs - let Qt handle native size for performance

                    layer.enabled: visible && Appearance.effectsEnabled
                        && (bgRoot.effectsOptions.enableAnimatedBlur ?? false)
                        && (bgRoot.effectsOptions.blurRadius ?? 0) > 0
                    layer.effect: GaussianBlur {
                        radius: Math.round((bgRoot.effectsOptions.blurRadius ?? 32) * Math.max(0, Math.min(1, (bgRoot.effectsOptions.thumbnailBlurStrength ?? 50) / 100)))
                        // Cap samples — beyond ~33 the visual difference is imperceptible
                        // but the fragment shader cost grows linearly. See #159.
                        samples: Math.min(33, radius * 2 + 1)
                    }
                }

                // Video wallpaper (Qt Multimedia)
                // Two-slot crossfader: a single Video tears down its pipeline on
                // every source change, so switching between two videos went black
                // and popped. This keeps the outgoing clip playing until the new
                // one has decoded a frame.
                VideoCrossfader {
                    id: videoWallpaper
                    anchors.fill: parent
                    visible: opacity > 0 && !blurLoader.active && !bgRoot.backdropActive && bgRoot.wallpaperIsVideo
                    opacity: bgRoot.wallpaperIsVideo ? 1 : 0
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    // The family loader can keep this whole tree alive after a
                    // switch, and nothing else in these gates knows which family
                    // owns the screen — so both backgrounds kept a 4K video
                    // decoding at once and every switch added another. Clearing
                    // the source releases the decoder outright instead of only
                    // pausing it; the transition overlay covers the swap.
                    source: {
                        if (bgRoot.webWallpaperActive || bgRoot.wallpaperSafetyTriggered || !bgRoot.wallpaperIsVideo || bgRoot.backdropActive) return "";
                        if (!bgRoot._familyOwnsScreen) return "";
                        return bgRoot.wallpaperPathRaw;
                    }
                    fillMode: VideoOutput.PreserveAspectCrop
                    enableTransitions: Config.options?.background?.transition?.enable ?? true
                    transitionBaseDuration: Config.options?.background?.transition?.duration ?? 800
                    shouldPlay: bgRoot.enableAnimation && !GlobalStates.screenLocked
                        && !Appearance._gameModeActive && !Wallpapers.batteryPauseActive
                        && Wallpapers.videoMotionAllowedOn(bgRoot.screenName)
                        && bgRoot._familyOwnsScreen
                        && visible

                    layer.enabled: visible && Appearance.effectsEnabled
                        && (bgRoot.effectsOptions.enableAnimatedBlur ?? false)
                        && (bgRoot.effectsOptions.blurRadius ?? 0) > 0
                    layer.effect: GaussianBlur {
                        radius: Math.round((bgRoot.effectsOptions.blurRadius ?? 32) * Math.max(0, Math.min(1, (bgRoot.effectsOptions.thumbnailBlurStrength ?? 50) / 100)))
                        // See #159 — cap samples to bound fragment shader cost
                        samples: Math.min(33, radius * 2 + 1)
                    }
                }
            }

            // Always-on wallpaper blur — reads from crossfader texture (works with both QML and awww rendering; disabled for GIFs/videos)
            Loader {
                id: blurAlwaysLoader
                z: 1
                active: Appearance.effectsEnabled
                        && !bgRoot.webWallpaperActive
                        && (bgRoot.blurProgress > 0)
                        && (bgRoot.effectsOptions.enableBlur ?? false)
                        && !Config.options?.performance?.lowPower
                        && (bgRoot.effectsOptions.blurRadius ?? 0) > 0
                        && !blurLoader.active
                        && !bgRoot.backdropActive
                        && !bgRoot.wallpaperIsGif
                        && !bgRoot.wallpaperIsVideo
                anchors.fill: wallpaperContainer
                sourceComponent: Item {
                    anchors.fill: parent
                    opacity: bgRoot.blurProgress

                    GaussianBlur {
                        anchors.fill: parent
                        source: wallpaper
                        radius: bgRoot.effectsOptions.blurRadius ?? 32
                        // See #159 — cap samples to bound fragment shader cost
                        samples: Math.min(33, radius * 2 + 1)
                    }
                }
            }

            Loader {
                id: blurLoader
                z: 2
                active: (bgRoot.lockBlurOptions.enable ?? false) && (GlobalStates.screenLocked || scaleAnim.running)
                anchors.fill: wallpaperContainer
                scale: GlobalStates.screenLocked ? (bgRoot.lockBlurOptions.extraZoom ?? 1) : 1
                Behavior on scale {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        id: scaleAnim
                        duration: Appearance.animation.elementMoveEnter.duration
                        easing.type: Appearance.animation.elementMoveEnter.type
                        easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                    }
                }
                sourceComponent: GaussianBlur {
                    source: wallpaperContainer
                    radius: GlobalStates.screenLocked ? (bgRoot.lockBlurOptions.radius ?? 0) : 0
                    // See #159 — cap samples to bound fragment shader cost
                    samples: Math.min(33, radius * 2 + 1)
                    Rectangle {
                        opacity: GlobalStates.screenLocked ? 1 : 0
                        anchors.fill: parent
                        color: CF.ColorUtils.transparentize(Appearance.colors.colLayer0, 0.7)
                    }
                }
            }

            // Dimming overlay
            Rectangle {
                id: dimOverlay
                anchors.fill: parent
                visible: !bgRoot.backdropActive
                z: 10
                color: {
                    const effects = bgRoot.effectsOptions;
                    const baseSafe = Math.max(0, Math.min(100, Number(effects?.dim) || 0));
                    const dynSafe = Number(effects?.dynamicDim) || 0;
                    const extra = (!GlobalStates.screenLocked && bgRoot.focusPresenceProgress > 0) ? dynSafe * bgRoot.focusPresenceProgress : 0;
                    const total = Math.max(0, Math.min(100, baseSafe + extra));
                    return Qt.rgba(0, 0, 0, total / 100);
                }
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }

            // Vignette overlays over the workspace wallpaper. Mirrors the dim
            // pattern (dimOverlay here ↔ backdropDim in Backdrop.qml): this group
            // covers normal mode (gated !backdropActive) while Backdrop.qml keeps
            // drawing the same vignette in backdrop-only mode. Mutually exclusive,
            // so the effects now apply over the workspace whether or not the main
            // wallpaper is hidden, with no double-render.
            Item {
                id: vignetteOverlay
                anchors.fill: parent
                z: 11
                visible: !bgRoot.backdropActive

                // Bar-level vignette (darkens the edge under the bar)
                Rectangle {
                    id: barVignette
                    readonly property bool isVertical: Config.options?.bar?.vertical ?? false
                    readonly property bool isBarAtTop: !isVertical && !(Config.options?.bar?.bottom ?? false)
                    readonly property bool isBarAtLeft: isVertical && !(Config.options?.bar?.bottom ?? false)
                    readonly property bool barVignetteEnabled: Config.options?.bar?.vignette?.enabled ?? false
                    readonly property real barVignetteIntensity: Config.options?.bar?.vignette?.intensity ?? 0.6
                    readonly property real barVignetteRadius: Config.options?.bar?.vignette?.radius ?? 0.5

                    anchors {
                        left: isVertical ? (isBarAtLeft ? parent.left : undefined) : parent.left
                        right: isVertical ? (isBarAtLeft ? undefined : parent.right) : parent.right
                        top: isVertical ? parent.top : (isBarAtTop ? parent.top : undefined)
                        bottom: isVertical ? parent.bottom : (isBarAtTop ? undefined : parent.bottom)
                    }
                    width: isVertical ? Math.max(200, vignetteOverlay.width * barVignetteRadius) : undefined
                    height: isVertical ? undefined : Math.max(200, vignetteOverlay.height * barVignetteRadius)
                    visible: barVignetteEnabled

                    gradient: Gradient {
                        orientation: barVignette.isVertical ? Gradient.Horizontal : Gradient.Vertical
                        GradientStop {
                            position: 0.0
                            color: (barVignette.isBarAtTop || barVignette.isBarAtLeft)
                                ? Qt.rgba(0, 0, 0, barVignette.barVignetteIntensity)
                                : "transparent"
                        }
                        GradientStop {
                            position: barVignette.barVignetteRadius
                            color: "transparent"
                        }
                        GradientStop {
                            position: 1.0
                            color: (barVignette.isBarAtTop || barVignette.isBarAtLeft)
                                ? "transparent"
                                : Qt.rgba(0, 0, 0, barVignette.barVignetteIntensity)
                        }
                    }
                }

                // Background-effects vignette (bottom gradient)
                Rectangle {
                    anchors.fill: parent
                    visible: bgRoot.backgroundOptions.backdrop?.vignetteEnabled ?? false
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: bgRoot.backgroundOptions.backdrop?.vignetteRadius ?? 0.7; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, bgRoot.backgroundOptions.backdrop?.vignetteIntensity ?? 0.5) }
                    }
                }
            }

            FocusScope {
                id: desktopFocusSink
                width: 0
                height: 0
                focus: false
            }

            // Desktop right-click context menu
            MouseArea {
                anchors.fill: parent
                z: 15  // Below WidgetCanvas (z: 20) so widgets can receive input
                // Left button too, so a click on the bare desktop closes an
                // already-open menu — ContextMenu's own closeOnFocusLost
                // backdrop (a separate fullscreen layer-surface on Niri) sits
                // above the popup's own surface and swallows clicks meant for
                // the menu items, so that path stays off; this MouseArea
                // already reliably gets right-clicks regardless, so reuse it.
                acceptedButtons: Qt.RightButton | Qt.LeftButton
                onClicked: function(mouse) {
                    if (mouse.button === Qt.LeftButton) {
                        desktopFocusSink.forceActiveFocus()
                        // A click on the bare desktop is not typing: Niri gave this
                        // OnDemand surface the keyboard for it, so hand it straight
                        // back to the window that had it.
                        bgRoot.releaseKeyboard()
                        GlobalStates.clearDesktopItemSelection()
                        if (desktopContextMenu.active) desktopContextMenu.close()
                        if (desktopItemContextMenu.active) desktopItemContextMenu.close()
                        if (irisDesktopMenu.active) irisDesktopMenu.close()
                        return
                    }
                    if (desktopItemContextMenu.active) desktopItemContextMenu.close()
                    desktopMenuAnchor.x = mouse.x
                    desktopMenuAnchor.y = mouse.y
                    if ((Config.options?.panelFamily ?? "ii") === "iris") irisDesktopMenu.requestOpen()
                    else desktopContextMenu.requestOpen()
                }
            }

            Item {
                id: desktopMenuAnchor
                z: 26
                width: 1; height: 1
            }

            ContextMenu {
                id: desktopContextMenu
                z: 27
                anchorItem: desktopMenuAnchor
                popupAbove: false
                // Left as false: ContextMenu's own closeOnFocusLost backdrop
                // (see the desktop MouseArea above) blocks clicks on the menu's
                // own items on Niri. Left-click-to-close is handled by that
                // MouseArea directly instead.
                closeOnFocusLost: false
                closeOnHoverLost: true
                closeOnHoverLostAfterEntered: true
                closeOnHoverLostDelay: 700
                model: GlobalStates.widgetEditMode ? [
                    { text: Translation.tr("Manage widgets"), iconName: "tune", monochromeIcon: true,
                        action: () => { widgetManagerPanel.shown = true } },
                    { text: Config.getNestedValue("background.widgets.editGrid.snap", true)
                            ? Translation.tr("Disable grid snap") : Translation.tr("Enable grid snap"),
                        iconName: "grid_3x3", monochromeIcon: true,
                        action: () => Config.setNestedValue("background.widgets.editGrid.snap",
                            !Config.getNestedValue("background.widgets.editGrid.snap", true)) },
                    { text: Translation.tr("Grid size: %1 px").arg(
                            Config.getNestedValue("background.widgets.editGrid.size", 32)),
                        iconName: "grid_4x4", monochromeIcon: true,
                        action: () => {
                            const sizes = [16, 32, 48, 64]
                            const current = Config.getNestedValue("background.widgets.editGrid.size", 32)
                            const index = sizes.indexOf(current)
                            Config.setNestedValue("background.widgets.editGrid.size",
                                sizes[(index + 1) % sizes.length])
                        } },
                    { type: "separator" },
                    { text: Translation.tr("Widget settings"), iconName: "settings", monochromeIcon: true,
                        action: () => GlobalStates.openSettingsPage(14) },
                    { text: Translation.tr("Done editing"), iconName: "check", monochromeIcon: true,
                        action: () => { widgetManagerPanel.shown = false; GlobalStates.setWidgetEditMode(false) } }
                ] : [
                    { text: Translation.tr("Settings"), iconName: "settings", monochromeIcon: true,
                        action: () => { Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings"]) } },
                    { type: "separator" },
                    { text: Translation.tr("Change wallpaper"), iconName: "image", monochromeIcon: true,
                        action: () => { GlobalActions.runLauncher(["wallpaperSelector", "toggle"]) } },
                    { text: Translation.tr("Edit widgets"), iconName: "edit", monochromeIcon: true,
                        action: () => { GlobalStates.setWidgetEditMode(true) } },
                    { text: Translation.tr("Edit shell layout"), iconName: "dashboard_customize", monochromeIcon: true,
                        action: () => { ShellEditSession.toggle() } },
                    { type: "separator" },
                    { text: Translation.tr("Reload shell"), iconName: "refresh", monochromeIcon: true,
                        action: () => { Quickshell.execDetached(["/usr/bin/bash", Quickshell.shellPath("scripts/restart-shell.sh")]) } }
                ]
            }

            // iRiS desktop menu: the Island's material, quick-action tiles and
            // keyboard, growing out of the pointer. Only the actions that drive
            // something under iRiS (shell layout editing is ii/Waffle-only).
            Connections {
                target: GlobalStates
                function onIrisDesktopMenuRequested(outputName: string, x: real, y: real): void {
                    if (outputName !== bgRoot.screenName || (Config.options?.panelFamily ?? "ii") !== "iris") return
                    desktopMenuAnchor.x = x
                    desktopMenuAnchor.y = y
                    irisDesktopMenu.requestOpen()
                }
            }

            IrisDesktopMenu {
                id: irisDesktopMenu
                z: 27
                anchorItem: desktopMenuAnchor
                readonly property int gridSize: Config.getNestedValue("background.widgets.editGrid.size", 32)
                readonly property bool gridSnap: Config.getNestedValue("background.widgets.editGrid.snap", true)
                model: GlobalStates.widgetEditMode ? [
                    { text: Translation.tr("Add widgets"), iconName: "dashboard_customize", tint: "teal",
                        action: () => { widgetManagerPanel.shown = true } },
                    { text: Translation.tr("Snap to grid"), iconName: "grid_on", checked: irisDesktopMenu.gridSnap, keepOpen: true,
                        action: () => Config.setNestedValue("background.widgets.editGrid.snap", !irisDesktopMenu.gridSnap) },
                    { type: "separator" },
                    { text: Translation.tr("Grid size"), iconName: "grid_4x4", detail: irisDesktopMenu.gridSize + " px",
                        action: () => {
                            const sizes = [16, 32, 48, 64]
                            Config.setNestedValue("background.widgets.editGrid.size",
                                sizes[(sizes.indexOf(irisDesktopMenu.gridSize) + 1) % sizes.length])
                        } },
                    { text: Translation.tr("Widget settings"), iconName: "settings",
                        action: () => GlobalStates.openSettingsPage(14) },
                    { type: "separator" },
                    { text: Translation.tr("Done"), iconName: "check", tint: "green",
                        action: () => { widgetManagerPanel.shown = false; GlobalStates.setWidgetEditMode(false) } }
                ] : IrisDesktopActions.menu(bgRoot.screenName, bgRoot.wallpaperPath, bgRoot.wallpaperPath)
            }

            // Managed items use the same stable screen-level popup path as the
            // proven bare-desktop menu. Do not anchor a PopupWindow inside the
            // transformed WidgetCanvas delegate tree.
            ContextMenu {
                id: desktopItemContextMenu
                z: 27
                anchorItem: desktopMenuAnchor
                popupAbove: false
                closeOnFocusLost: false
                closeOnHoverLost: true
                closeOnHoverLostAfterEntered: true
                closeOnHoverLostDelay: 700
            }

            OrganicEdgeWidget {
                id: organicEdge
                Component.onCompleted: backgroundScope.organicEdgeHosts[screenName] = organicEdge
                Component.onDestruction: delete backgroundScope.organicEdgeHosts[screenName]
                anchors.fill: parent
                z: 19
                screenName: modelData?.name ?? ""
            }

            WidgetCanvas {
                id: widgetCanvas
                z: 20
                // Each widget's edit toolbar and quick-controls sheet live here, above every widget and
                // outside the widget's own opacity and dim, so they stay opaque and on top.
                readonly property Item editChromeLayer: widgetChromeLayer
                Component.onDestruction: delete backgroundScope.widgetCanvases[bgRoot.screenName]
                visible: !GlobalStates.shellLayoutEditMode
                    && DesktopWidgetLayout.outputAllowed(modelData?.name ?? "")
                enabled: visible && !GlobalStates.screenLocked  // Disable all widget input during lock
                // Widgets arrive with the shell (boot, reload, family switch): a short settle inward.
                property real arrival: GlobalStates.shellEntryReady ? 1 : 0
                Behavior on arrival {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration * 1.4; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve }
                }
                scale: arrival >= 1 ? 1 : 1.025 - 0.025 * arrival
                opacity: {
                    const dynOp = Math.max(0, Math.min(100, Number(Config.options?.background?.widgets?.dynamicOpacity) || 0));
                    const presence = dynOp <= 0 || !bgRoot.focusWindowsPresent ? 1 : 1 - (dynOp / 100) * bgRoot.focusPresenceProgress;
                    return presence * widgetCanvas.arrival;
                }
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                readonly property bool useParallax: wallpaperContainer.useParallax && !bgRoot.backdropActive
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }
                // Parallax widget depth: translate the canvas as a whole to create
                // layered movement relative to the wallpaper.
                transform: Translate {
                    // Whole pixels: native text on a fractional offset is resampled and goes soft.
                    x: widgetCanvas._parallaxActive ? Math.round(bgRoot.parallaxTotalX * wallpaperContainer.activeValueX * (1 - bgRoot.parallaxWidgetDepth)) : 0
                    y: widgetCanvas._parallaxActive ? Math.round(bgRoot.parallaxTotalY * wallpaperContainer.activeValueY * (1 - bgRoot.parallaxWidgetDepth)) : 0
                    Behavior on x {
                        enabled: Appearance.animationsEnabled
                            && ((!bgRoot.parallaxTransitionActive && bgRoot.parallaxResumeProgress >= 1)
                                || bgRoot._parallaxWaitingCrossfader)
                        animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                    }
                    Behavior on y {
                        enabled: Appearance.animationsEnabled
                            && ((!bgRoot.parallaxTransitionActive && bgRoot.parallaxResumeProgress >= 1)
                                || bgRoot._parallaxWaitingCrossfader)
                        animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                    }
                }
                width: parent.width
                height: parent.height
                // Disable parallax transform when locked/safe/backdrop
                readonly property bool _parallaxActive: useParallax && !GlobalStates.widgetEditMode
                    && !GlobalStates.screenLocked && !bgRoot.wallpaperSafetyTriggered && !bgRoot.backdropActive

                // Managed desktop items are a separate, lightweight canvas model.
                // The coordinator is deliberately beneath widget receivers so
                // CustomImage/ImageConverter keep ownership of their drops.
                DesktopDropCoordinator {
                    id: desktopDropCoordinator
                    z: -100
                    outputName: bgRoot.screen?.name ?? ""
                    canvasWidth: widgetCanvas.width
                    canvasHeight: widgetCanvas.height
                    workArea: bgRoot.desktopItemsWorkArea
                    gridSize: Number(Config.getNestedValue("background.widgets.editGrid.size", 16))
                    gridSnap: Boolean(Config.getNestedValue("background.widgets.editGrid.snap", true))
                    interactive: !GlobalStates.screenLocked && !GlobalStates.shellLayoutEditMode
                    onImageChoiceRequested: (paths, x, y) => imageChoice.openAt(paths, x, y)
                }

                Repeater {
                    id: desktopItemsRepeater
                    model: widgetCanvas._desktopItemsForOutput(bgRoot.screen?.name ?? "")
                    delegate: DesktopItemDelegate {
                        id: desktopItemDelegate
                        required property var modelData
                        itemId: String(modelData.id ?? "")
                        itemData: modelData
                        outputName: bgRoot.screen?.name ?? ""
                        canvasWidth: widgetCanvas.width
                        canvasHeight: widgetCanvas.height
                        workArea: bgRoot.desktopItemsWorkArea
                        gridSize: Number(Config.getNestedValue("background.widgets.editGrid.size", 16))
                        gridSnap: Boolean(Config.getNestedValue("background.widgets.editGrid.snap", true))
                        dragEnabled: !GlobalStates.screenLocked && !GlobalStates.shellLayoutEditMode
                        onContextMenuRequested: (menuModel, anchorX, anchorY) => {
                            const position = desktopItemDelegate.mapToItem(
                                desktopMenuAnchor.parent, anchorX, anchorY)
                            if (desktopContextMenu.active) desktopContextMenu.close()
                            desktopMenuAnchor.x = position.x
                            desktopMenuAnchor.y = position.y
                            desktopItemContextMenu.model = menuModel
                            desktopItemContextMenu.requestOpen()
                        }
                        onContextMenuCloseRequested: {
                            if (desktopItemContextMenu.active)
                                desktopItemContextMenu.close()
                        }
                    }
                }

                DesktopImageChoice {
                    id: imageChoice
                    anchors.fill: parent
                    onChosen: action => bgRoot._handleImageChoice(action)
                }

                function _desktopItemsForOutput(outputName: string): var {
                    const output = String(outputName ?? "")
                    const screens = Quickshell.screens.map(screen => String(screen?.name ?? ""))
                    const focused = String(GlobalStates.focusedScreen?.name ?? screens[0] ?? "")
                    return DesktopItems.listItems().filter(item =>
                        String(item.output ?? "") === output
                        || (!screens.includes(String(item.output ?? "")) && output === focused))
                }

                // The canvas owns layer discovery. Individual widgets should not
                // walk the visual tree themselves: loaders, repeater delegates and
                // custom widgets all live here, and this is the only place with a
                // complete view of the current output.
                function _loadedDesktopWidgets(): var {
                    const widgets = []
                    for (let i = 0; i < widgetCanvas.children.length; ++i) {
                        const holder = widgetCanvas.children[i]
                        const item = holder?.item ?? holder
                        if (!item || item.editInstanceKey === undefined || !item.visible)
                            continue
                        widgets.push(item)
                    }
                    return widgets
                }

                function _rectOverlaps(a, b, gap): bool {
                    return a.x < b.x + b.width + gap
                        && a.x + a.width + gap > b.x
                        && a.y < b.y + b.height + gap
                        && a.y + a.height + gap > b.y
                }

                function _positionIsFree(x, y, width, height, placed, gap): bool {
                    const candidate = { x: x, y: y, width: width, height: height }
                    for (const rect of placed) {
                        if (widgetCanvas._rectOverlaps(candidate, rect, gap))
                            return false
                    }
                    return true
                }

                function _nearestFreePosition(item, desiredX, desiredY, placed, work): var {
                    const left = Number(work.left ?? 0)
                    const top = Number(work.top ?? 0)
                    const right = Number(work.right ?? widgetCanvas.width)
                    const bottom = Number(work.bottom ?? widgetCanvas.height)
                    const maxX = Math.max(left, right - item.width)
                    const maxY = Math.max(top, bottom - item.height)
                    const startX = Math.max(left, Math.min(maxX, desiredX))
                    const startY = Math.max(top, Math.min(maxY, desiredY))
                    const gap = 14
                    if (widgetCanvas._positionIsFree(
                            startX, startY, item.width, item.height, placed, gap))
                        return { x: Math.round(startX), y: Math.round(startY) }

                    const step = 24
                    let best = null
                    let bestDistance = Infinity
                    function consider(x, y): void {
                        const px = Math.max(left, Math.min(maxX, x))
                        const py = Math.max(top, Math.min(maxY, y))
                        if (!widgetCanvas._positionIsFree(
                                px, py, item.width, item.height, placed, gap))
                            return
                        const dx = px - startX
                        const dy = py - startY
                        const distance = dx * dx + dy * dy
                        if (distance < bestDistance) {
                            bestDistance = distance
                            best = { x: Math.round(px), y: Math.round(py) }
                        }
                    }
                    for (let y = top; y <= maxY; y += step) {
                        for (let x = left; x <= maxX; x += step)
                            consider(x, y)
                    }
                    consider(maxX, top)
                    consider(left, maxY)
                    consider(maxX, maxY)
                    return best ?? { x: Math.round(startX), y: Math.round(startY) }
                }

                function initializeOutputWidgetLayout(): void {
                    if (!Config.ready || !widgetCanvas.visible)
                        return
                    const outputName = String(bgRoot.screen?.name ?? "")
                    const outputWidth = Math.round(widgetCanvas.width)
                    const outputHeight = Math.round(widgetCanvas.height)
                    if (!outputName || outputWidth <= 0 || outputHeight <= 0)
                        return

                    const widgets = widgetCanvas._loadedDesktopWidgets()
                        .filter(item => item.width > 0 && item.height > 0)
                    if (widgets.length === 0) {
                        if (widgetCanvas._outputLayoutAttempts < 8) {
                            widgetCanvas._outputLayoutAttempts++
                            outputLayoutTimer.restart()
                        }
                        return
                    }

                    const geometryChanged = !DesktopWidgetLayout.outputLayoutMatches(
                        outputName, outputWidth, outputHeight)
                    let missingGeometry = false
                    for (const item of widgets) {
                        const strategy = String(item.placementStrategy ?? "free")
                        if (strategy === "free"
                                && (!DesktopWidgetLayout.hasValue(outputName,
                                        item.configEntryName, "x")
                                    || !DesktopWidgetLayout.hasValue(outputName,
                                        item.configEntryName, "y"))) {
                            missingGeometry = true
                            break
                        }
                    }
                    if (!geometryChanged && !missingGeometry)
                        return

                    const work = bgRoot.desktopItemsWorkArea
                    const ordered = widgets.slice().sort((a, b) => {
                        const aLocal = DesktopWidgetLayout.hasValue(
                            outputName, a.configEntryName, "x") ? 1 : 0
                        const bLocal = DesktopWidgetLayout.hasValue(
                            outputName, b.configEntryName, "x") ? 1 : 0
                        if (!geometryChanged && aLocal !== bLocal)
                            return bLocal - aLocal
                        if (Boolean(a.locked) !== Boolean(b.locked))
                            return a.locked ? -1 : 1
                        return b.width * b.height - a.width * a.height
                    })
                    const placed = []
                    const updates = ({})
                    const left = Number(work.left ?? 0)
                    const top = Number(work.top ?? 0)
                    const right = Number(work.right ?? outputWidth)
                    const bottom = Number(work.bottom ?? outputHeight)

                    for (const item of ordered) {
                        const strategy = String(item.placementStrategy ?? "free")
                        const maxX = Math.max(left, right - item.width)
                        const maxY = Math.max(top, bottom - item.height)
                        const desiredX = Math.max(left, Math.min(maxX, Number(item.x) || 0))
                        const desiredY = Math.max(top, Math.min(maxY, Number(item.y) || 0))
                        const localX = DesktopWidgetLayout.hasValue(
                            outputName, item.configEntryName, "x")
                        const localY = DesktopWidgetLayout.hasValue(
                            outputName, item.configEntryName, "y")
                        const needsLocal = strategy === "free"
                            && (geometryChanged || !localX || !localY)
                        let position = { x: Math.round(desiredX), y: Math.round(desiredY) }
                        const collides = !widgetCanvas._positionIsFree(
                            position.x, position.y, item.width, item.height, placed, 14)
                        if (collides && !item.locked)
                            position = widgetCanvas._nearestFreePosition(
                                item, desiredX, desiredY, placed, work)

                        const moved = Math.round(position.x) !== Math.round(item.x)
                            || Math.round(position.y) !== Math.round(item.y)
                        if (needsLocal || moved || (collides && !item.locked)) {
                            updates[item.configEntryName] = {
                                x: position.x,
                                y: position.y,
                                placementStrategy: "free"
                            }
                        }
                        placed.push({
                            x: position.x,
                            y: position.y,
                            width: item.width,
                            height: item.height
                        })
                    }

                    widgetCanvas._outputLayoutAttempts = 0
                    DesktopWidgetLayout.initializeOutputLayout(
                        outputName, outputWidth, outputHeight, updates)
                }

                property int _outputLayoutAttempts: 0

                Timer {
                    id: outputLayoutTimer
                    interval: 1400
                    repeat: false
                    onTriggered: widgetCanvas.initializeOutputWidgetLayout()
                }

                Component.onCompleted: {
                    backgroundScope.widgetCanvases[bgRoot.screenName] = widgetCanvas
                    outputLayoutTimer.restart()
                }

                Connections {
                    target: Config
                    function onRevisionChanged(): void {
                        if (!outputLayoutTimer.running)
                            outputLayoutTimer.restart()
                    }
                }

                Connections {
                    target: bgRoot.screen
                    function onWidthChanged(): void { outputLayoutTimer.restart() }
                    function onHeightChanged(): void { outputLayoutTimer.restart() }
                }

                function overlappingDesktopWidgets(instanceKey: string): var {
                    const widgets = widgetCanvas._loadedDesktopWidgets()
                    const current = widgets.find(item => item.editInstanceKey === instanceKey)
                    if (!current || current.width <= 0 || current.height <= 0)
                        return []
                    const matches = widgets.filter(item => item.width > 0 && item.height > 0
                        && item.x < current.x + current.width
                        && item.x + item.width > current.x
                        && item.y < current.y + current.height
                        && item.y + item.height > current.y)
                    // Topmost first. The selected widget has a temporary edit z,
                    // so use the persistent z when deciding which underlying
                    // widget should be promoted next.
                    matches.sort((a, b) => {
                        const order = Number(b.desktopPersistentZ ?? b.widgetIndex ?? 0)
                            - Number(a.desktopPersistentZ ?? a.widgetIndex ?? 0)
                        return order !== 0 ? order
                            : String(a.editInstanceKey).localeCompare(String(b.editInstanceKey))
                    })
                    return matches
                }

                function overlappingDesktopWidgetCount(instanceKey: string): int {
                    return widgetCanvas.overlappingDesktopWidgets(instanceKey).length
                }

                function cycleOverlappingDesktopWidget(instanceKey: string): string {
                    const matches = widgetCanvas.overlappingDesktopWidgets(instanceKey)
                    if (matches.length < 2)
                        return instanceKey
                    const current = matches.findIndex(item => item.editInstanceKey === instanceKey)
                    if (current < 0)
                        return instanceKey
                    const next = matches[(current + 1) % matches.length]
                    const nextKey = String(next?.editInstanceKey ?? instanceKey)
                    backgroundScope.promoteDesktopWidgetKey(nextKey)
                    GlobalStates.selectDesktopWidget(nextKey)
                    if (Quickshell.env("INIR_REGION_DEBUG") === "1")
                        console.debug("[WidgetEdit] layer promote", instanceKey, "->", nextKey,
                            "overlaps=", matches.length)
                    return nextKey
                }

                function promoteDesktopWidget(instanceKey: string): string {
                    const key = String(instanceKey ?? "")
                    if (!key)
                        return ""
                    backgroundScope.promoteDesktopWidgetKey(key)
                    GlobalStates.selectDesktopWidget(key)
                    return key
                }

                // ── Edit Mode Scrim ──────────────────────────────
                Rectangle {
                    anchors.fill: parent
                    z: -2
                    visible: opacity > 0
                    opacity: GlobalStates.widgetEditMode ? 1 : 0
                    color: Qt.rgba(0, 0, 0, 0.15)
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve }
                    }
                }

                // ── Edit Mode Overlay ─────────────────────────────
                Item {
                    id: editGridOverlay
                    anchors.fill: parent
                    visible: opacity > 0
                    opacity: GlobalStates.widgetEditMode ? 1 : 0
                    z: -1

                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve }
                    }

                    readonly property int gridSize: Config.getNestedValue("background.widgets.editGrid.size", 32)
                    readonly property bool gridVisible: Config.getNestedValue("background.widgets.editGrid.snap", true)
                    readonly property color gridColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                        : Appearance.inirEverywhere ? Appearance.inir.colAccent
                        : Appearance.auroraEverywhere ? Appearance.colors.colPrimary
                        : Appearance.colors.colPrimary
                    readonly property color crosshairColor: Appearance.angelEverywhere ? Appearance.angel.colTertiary
                        : Appearance.inirEverywhere ? Appearance.inir.colTertiary
                        : Appearance.auroraEverywhere ? Appearance.colors.colTertiary
                        : Appearance.colors.colTertiary
                    readonly property var workArea: ShellLayoutController.desktopWorkArea(
                        bgRoot.screen?.name ?? "", width, height)
                    readonly property var zoneWorkArea: ShellLayoutController.desktopZoneWorkArea(
                        bgRoot.screen?.name ?? "", width, height)
                    readonly property int zoneMargin: 16
                    readonly property real safeLeft: workArea.left ?? 0
                    readonly property real safeTop: workArea.top ?? 0
                    readonly property real safeRight: workArea.right ?? width
                    readonly property real safeBottom: workArea.bottom ?? height
                    readonly property real safeWidth: workArea.width ?? 0
                    readonly property real safeHeight: workArea.height ?? 0
                    readonly property real zoneLeft: zoneWorkArea.left ?? safeLeft
                    readonly property real zoneTop: zoneWorkArea.top ?? safeTop
                    readonly property real zoneWidth: zoneWorkArea.width ?? safeWidth
                    readonly property real zoneHeight: zoneWorkArea.height ?? safeHeight
                    readonly property bool hasSelection: GlobalStates.selectedDesktopWidget
                        .startsWith((bgRoot.screen?.name ?? "") + "::")
                    readonly property bool manipulating: {
                        if (!hasSelection) return false
                        const widget = bgRoot._loadedWidget(GlobalStates.selectedDesktopWidget.split("::")[1])
                        return widget !== null && (widget.isDragging || widget._isResizing)
                    }

                    // Grid dots at intersections. The lattice uses the same
                    // panel-aware bounds as drag snapping, so moving the bar or
                    // dock changes both the visible guide and the committed
                    // position instead of leaving two competing coordinate systems.
                    readonly property bool gridNonDefault: gridSize !== 32
                    // One tiled texture, not a Canvas: painting every dot of a 4K lattice in software
                    // stalled the main thread ~60 ms as editing began, the toolbar's entrance with it.
                    Item {
                        id: editGridCanvas
                        x: editGridOverlay.zoneLeft
                        y: editGridOverlay.zoneTop
                        width: editGridOverlay.zoneWidth
                        height: editGridOverlay.zoneHeight
                        visible: editGridOverlay.gridVisible
                        clip: true
                        readonly property int gs: Math.max(4, editGridOverlay.gridSize)
                        readonly property bool custom: editGridOverlay.gridNonDefault
                        // SVG Tiny paint: a hex colour and its opacity apart (QtSvg reads no rgba()).
                        function paint(c: color, a: real, kind: string): string {
                            const hex = n => ("0" + Math.round(n * 255).toString(16)).slice(-2)
                            return kind + "='#" + hex(c.r) + hex(c.g) + hex(c.b) + "' " + kind + "-opacity='" + a + "'"
                        }
                        readonly property string tile: {
                            const g = editGridCanvas.gs, h = g / 2
                            const dot = editGridCanvas.paint(editGridOverlay.gridColor, editGridCanvas.custom ? 0.18 : 0.10, "fill")
                            const line = editGridCanvas.paint(editGridOverlay.gridColor, 0.05, "stroke")
                            const lines = editGridCanvas.custom
                                ? "<path d='M" + h + " 0V" + g + "M0 " + h + "H" + g + "' fill='none' " + line + " stroke-width='0.5'/>" : ""
                            const svg = "<svg xmlns='http://www.w3.org/2000/svg' width='" + g + "' height='" + g + "'>" + lines
                                + "<circle cx='" + h + "' cy='" + h + "' r='" + (editGridCanvas.custom ? 1.8 : 1.4) + "' " + dot + "/></svg>"
                            // Base64: Qt hands a percent-encoded data URL to the SVG reader undecoded.
                            const table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
                            let out = ""
                            for (let i = 0; i < svg.length; i += 3) {
                                const a = svg.charCodeAt(i), b = svg.charCodeAt(i + 1), c = svg.charCodeAt(i + 2)
                                const n = (a << 16) | ((b || 0) << 8) | (c || 0)
                                out += table[(n >> 18) & 63] + table[(n >> 12) & 63]
                                    + (i + 1 < svg.length ? table[(n >> 6) & 63] : "=") + (i + 2 < svg.length ? table[n & 63] : "=")
                            }
                            return "data:image/svg+xml;base64," + out
                        }
                        Image {
                            x: -editGridCanvas.gs / 2
                            y: -editGridCanvas.gs / 2
                            width: parent.width + editGridCanvas.gs
                            height: parent.height + editGridCanvas.gs
                            fillMode: Image.Tile
                            source: editGridCanvas.tile
                            sourceSize: Qt.size(editGridCanvas.gs, editGridCanvas.gs)
                            cache: false
                            smooth: false
                        }
                    }

                    Rectangle {
                        x: editGridOverlay.zoneLeft
                        y: editGridOverlay.zoneTop
                        width: editGridOverlay.zoneWidth
                        height: editGridOverlay.zoneHeight
                        color: "transparent"
                        radius: Appearance.rounding.small
                        border.width: 1
                        border.color: CF.ColorUtils.applyAlpha(editGridOverlay.gridColor, 0.18)
                    }

                    // Crosshair follows the adaptive panel-safe widget area.
                    Rectangle {
                        x: Math.floor(editGridOverlay.zoneLeft + editGridOverlay.zoneWidth / 2)
                        y: editGridOverlay.zoneTop
                        width: 1; height: editGridOverlay.zoneHeight
                        color: CF.ColorUtils.applyAlpha(editGridOverlay.crosshairColor, 0.08)
                    }
                    Rectangle {
                        x: editGridOverlay.zoneLeft
                        y: Math.floor(editGridOverlay.zoneTop + editGridOverlay.zoneHeight / 2)
                        width: editGridOverlay.zoneWidth; height: 1
                        color: CF.ColorUtils.applyAlpha(editGridOverlay.crosshairColor, 0.08)
                    }
                    // Center dot
                    Rectangle {
                        x: Math.floor(editGridOverlay.zoneLeft + editGridOverlay.zoneWidth / 2) - 3
                        y: Math.floor(editGridOverlay.zoneTop + editGridOverlay.zoneHeight / 2) - 3
                        width: 6; height: 6; radius: 3
                        color: CF.ColorUtils.applyAlpha(editGridOverlay.crosshairColor, 0.25)
                    }

                    // ── Snap Zone Indicators (3x3 grid) ──────────────
                    Repeater {
                        model: [
                            { zone: "topLeft",      col: 0, row: 0 },
                            { zone: "topCenter",    col: 1, row: 0 },
                            { zone: "topRight",     col: 2, row: 0 },
                            { zone: "centerLeft",   col: 0, row: 1 },
                            { zone: "center",       col: 1, row: 1 },
                            { zone: "centerRight",  col: 2, row: 1 },
                            { zone: "bottomLeft",   col: 0, row: 2 },
                            { zone: "bottomCenter", col: 1, row: 2 },
                            { zone: "bottomRight",  col: 2, row: 2 }
                        ]
                        delegate: Rectangle {
                            id: zoneRect
                            required property var modelData
                            readonly property int col: modelData.col
                            readonly property int row: modelData.row
                            readonly property real zw: (editGridOverlay.zoneWidth - editGridOverlay.zoneMargin * 2) / 3
                            readonly property real zh: (editGridOverlay.zoneHeight - editGridOverlay.zoneMargin * 2) / 3
                            readonly property var occupants: bgRoot.zoneOccupants[modelData.zone] ?? []
                            readonly property bool occupied: occupants.length > 0
                            readonly property bool hasLocked: {
                                for (let i = 0; i < occupants.length; i++)
                                    if (occupants[i].locked) return true;
                                return false;
                            }

                            x: editGridOverlay.zoneLeft + editGridOverlay.zoneMargin + col * zw + 4
                            y: editGridOverlay.zoneTop + editGridOverlay.zoneMargin + row * zh + 4
                            width: zw - 8
                            height: zh - 8
                            radius: Appearance.rounding.small
                            visible: editGridOverlay.manipulating
                            opacity: 0.65
                            color: occupied
                                ? CF.ColorUtils.applyAlpha(hasLocked ? Appearance.colors.colError : editGridOverlay.gridColor, 0.04)
                                : "transparent"
                            border {
                                width: occupied ? 1.5 : 1
                                color: CF.ColorUtils.applyAlpha(
                                    hasLocked ? Appearance.colors.colError : editGridOverlay.gridColor,
                                    occupied ? 0.25 : 0.10)
                            }
                            Behavior on opacity {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                            Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: 200 } }
                            Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: 200 } }

                            // Zone content: arrow + occupant icons
                            Column {
                                anchors.centerIn: parent
                                spacing: 4

                                // Direction arrow
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: {
                                        const labels = {
                                            topLeft: "↖", topCenter: "↑", topRight: "↗",
                                            centerLeft: "←", center: "⊙", centerRight: "→",
                                            bottomLeft: "↙", bottomCenter: "↓", bottomRight: "↘"
                                        };
                                        return labels[zoneRect.modelData.zone] ?? "";
                                    }
                                    font.pixelSize: zoneRect.occupied ? 14 : 16
                                    color: CF.ColorUtils.applyAlpha(editGridOverlay.gridColor, zoneRect.occupied ? 0.35 : 0.20)
                                }

                                // Occupant widget icons
                                Row {
                                    visible: zoneRect.occupied
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4
                                    Repeater {
                                        model: zoneRect.occupants
                                        MaterialSymbol {
                                            required property var modelData
                                            text: modelData.icon
                                            iconSize: 14
                                            color: CF.ColorUtils.applyAlpha(
                                                modelData.locked ? Appearance.colors.colError : editGridOverlay.gridColor, 0.45)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: 0
                    enabled: GlobalStates.widgetEditMode
                    acceptedButtons: Qt.LeftButton
                    onClicked: GlobalStates.clearDesktopWidgetSelection()
                }

                Item {
                    id: widgetChromeLayer
                    anchors.fill: parent
                    z: 15000
                }

                Item {
                    id: editControlsOverlay
                    anchors.fill: parent
                    visible: opacity > 0
                    opacity: GlobalStates.widgetEditMode ? 1 : 0
                    z: 20000
                    enabled: GlobalStates.widgetEditMode

                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve }
                    }

                    DesktopEditToolbar {
                        id: editControlsBar
                        // iRiS hosts the toolbar in its chassis (IrisWidgetBar) so it joins the frame.
                        visible: !editControlsBar.iris
                        enabled: !editControlsBar.iris
                        availableWidth: Math.max(0, editGridOverlay.safeWidth - 16)
                        availableHeight: editGridOverlay.safeHeight
                        outputName: bgRoot.screenName
                        hasSelection: editGridOverlay.hasSelection
                        libraryOpen: widgetManagerPanel.shown
                        x: Math.round(editGridOverlay.safeLeft
                            + (editGridOverlay.safeWidth - width) / 2)
                        // iRiS: the Dock steps aside while editing and the toolbar takes the
                        // edge opposite the Island, so it never lands on the Island.
                        readonly property bool irisTopEdge: (Config.options?.panelFamily ?? "ii") === "iris"
                            && editGridOverlay.workArea?.insets?.barEdge === "bottom"
                        attachedTopEdge: irisTopEdge
                        y: editControlsBar.iris ? (irisTopEdge ? IrisFrame.band : parent.height - height - IrisFrame.band)
                            : Math.max(editGridOverlay.safeTop, editGridOverlay.safeBottom - height - 12)
                        onLibraryRequested: widgetManagerPanel.shown = !widgetManagerPanel.shown
                        onEdgeSettingsRequested: GlobalStates.openSettingsPage(14, "Organic edge")
                        onSettingsRequested: GlobalStates.openSettingsPage(14)
                        onDoneRequested: {
                            widgetManagerPanel.shown = false
                            GlobalStates.setWidgetEditMode(false)
                        }
                    }

                    // ── Widget Manager Panel ─────────────────────────
                    Loader {
                        id: widgetManagerPanel
                        property bool shown: false
                        property bool geometryReady: false
                        Connections {
                            target: GlobalStates
                            function onDesktopWidgetManagerToggleRequested(outputName: string): void {
                                if (outputName.length === 0 || outputName === bgRoot.screenName)
                                    widgetManagerPanel.shown = !widgetManagerPanel.shown
                            }
                            function onWidgetEditModeChanged(): void {
                                if (!GlobalStates.widgetEditMode) widgetManagerPanel.shown = false
                            }
                        }
                        active: shown
                        visible: shown
                        enabled: shown && (!editControlsBar.iris || geometryReady)
                        opacity: editControlsBar.iris && !geometryReady ? 0 : 1
                        z: 150
                        x: 0
                        y: 0

                        Behavior on opacity {
                            enabled: editControlsBar.iris && IrisStyle.motionEnabled
                            NumberAnimation {
                                duration: IrisStyle.revealDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: IrisStyle.morphCurve
                            }
                        }

                        function restoreGeometry(): void {
                            if (!widgetManagerPanel.shown)
                                return
                            Qt.callLater(() => {
                                const panel = widgetManagerPanel.item
                                if (!panel)
                                    return
                                const inset = 12
                                const canvasWidth = widgetManagerPanel.parent?.width ?? 0
                                const canvasHeight = widgetManagerPanel.parent?.height ?? 0
                                const spanX = Math.max(0, canvasWidth - panel.width - inset * 2)
                                const spanY = Math.max(0, canvasHeight - panel.height - inset * 2)
                                const rx = Math.max(0, Math.min(1,
                                    Number(Persistent.states?.desktopWidgets?.managerXRatio ?? 0.68)))
                                const ry = Math.max(0, Math.min(1,
                                    Number(Persistent.states?.desktopWidgets?.managerYRatio ?? 0.48)))
                                widgetManagerPanel.x = inset + Math.round(spanX * rx)
                                widgetManagerPanel.y = inset + Math.round(spanY * ry)
                                widgetManagerPanel.geometryReady = true
                            })
                        }

                        Timer { id: managerCloseLater; interval: 0; onTriggered: widgetManagerPanel.shown = false }
                        onShownChanged: {
                            if (shown) GlobalStates.desktopWidgetManagerOutput = bgRoot.screenName
                            else if (GlobalStates.desktopWidgetManagerOutput === bgRoot.screenName) GlobalStates.desktopWidgetManagerOutput = ""
                            if (!shown) {
                                geometryReady = false
                                return
                            }
                            geometryReady = false
                            restoreGeometry()
                        }
                        onLoaded: restoreGeometry()

                        sourceComponent: WidgetManagerPanel {
                            outputName: bgRoot.screen?.name ?? ""
                            canvasWidth: widgetManagerPanel.parent?.width ?? 800
                            canvasHeight: widgetManagerPanel.parent?.height ?? 600
                            screenWidth: bgRoot.screen.width
                            screenHeight: bgRoot.screen.height
                            // Closed after its own click returns: unloading the panel inside the
                            // click that asked for it lost the next click.
                            onCloseRequested: managerCloseLater.restart()
                            onFocusWidgetRequested: layoutKey => {
                                GlobalStates.selectDesktopWidget(
                                    bgRoot.screenName + "::" + layoutKey)
                            }
                            Component.onCompleted: widgetManagerPanel.restoreGeometry()
                        }
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("weather", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMask : null
                    WidgetInputMask { id: _hitMask; loader: parent }
                    sourceComponent: WeatherWidget {
                        widgetIndex: 0
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("customImage", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMaskCustomImage : null
                    WidgetInputMask { id: _hitMaskCustomImage; loader: parent }
                    sourceComponent: CustomImageWidget {
                        widgetIndex: 16
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("imageConverter", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMaskImageConverter : null
                    WidgetInputMask { id: _hitMaskImageConverter; loader: parent }
                    sourceComponent: ImageConverterWidget {
                        widgetIndex: 17
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("clock", true)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMask2 : null
                    WidgetInputMask { id: _hitMask2; loader: parent }
                    sourceComponent: ClockWidget {
                        widgetIndex: 1
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                        wallpaperSafetyTriggered: bgRoot.wallpaperSafetyTriggered
                        debugRegionActive: backgroundScope.clockDebugRegionActive
                        debugRegionColor: backgroundScope.clockDebugRegionColor
                        debugRegionBrightness: backgroundScope.clockDebugRegionBrightness
                        debugRegionSpread: backgroundScope.clockDebugRegionSpread
                        debugQuickControlsOpen: backgroundScope.clockDebugQuickControlsOpen
                        debugLayoutProbeActive: backgroundScope.clockDebugLayoutProbeActive
                        debugLayoutProbeX: backgroundScope.clockDebugLayoutProbeX
                        debugLayoutProbeY: backgroundScope.clockDebugLayoutProbeY
                        onDebugPaletteReportChanged: backgroundScope.clockDebugPaletteReport = debugPaletteReport
                        onEditControlsGeometryReportChanged: backgroundScope.clockDebugControlsReport = editControlsGeometryReport
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("mediaControls", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMask3 : null
                    WidgetInputMask { id: _hitMask3; loader: parent }
                    sourceComponent: MediaControlsWidget {
                        widgetIndex: 2
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("visualizer", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMask4 : null
                    WidgetInputMask { id: _hitMask4; loader: parent }
                    sourceComponent: VisualizerWidget {
                        widgetIndex: 3
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("systemMonitor", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMask5 : null
                    WidgetInputMask { id: _hitMask5; loader: parent }
                    sourceComponent: SystemMonitorWidget {
                        widgetIndex: 4
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("battery", false) && Battery.available
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMask6 : null
                    WidgetInputMask { id: _hitMask6; loader: parent }
                    sourceComponent: BatteryWidget {
                        widgetIndex: 5
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("notes", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMask7 : null
                    WidgetInputMask { id: _hitMask7; loader: parent }
                    sourceComponent: NotesWidget {
                        widgetIndex: 6
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("calendarUpcoming", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMask8 : null
                    WidgetInputMask { id: _hitMask8; loader: parent }
                    sourceComponent: CalendarUpcomingWidget {
                        widgetIndex: 7
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("monthCalendar", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMaskMonthCalendar : null
                    WidgetInputMask { id: _hitMaskMonthCalendar; loader: parent }
                    sourceComponent: MonthCalendarWidget {
                        widgetIndex: 8
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("todo", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMaskTodo : null
                    WidgetInputMask { id: _hitMaskTodo; loader: parent }
                    sourceComponent: TodoWidget {
                        widgetIndex: 10
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("timers", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMaskTimers : null
                    WidgetInputMask { id: _hitMaskTimers; loader: parent }
                    sourceComponent: TimerWidget {
                        widgetIndex: 18
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("dayProgress", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMaskDayProgress : null
                    WidgetInputMask { id: _hitMaskDayProgress; loader: parent }
                    sourceComponent: DayProgressWidget {
                        widgetIndex: 8
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("uptime", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMask10 : null
                    WidgetInputMask { id: _hitMask10; loader: parent }
                    sourceComponent: UptimeWidget {
                        widgetIndex: 9
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("controls", false) && (Config.options?.panelFamily ?? "ii") === "iris"
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMaskControls : null
                    WidgetInputMask { id: _hitMaskControls; loader: parent }
                    sourceComponent: ControlsWidget {
                        widgetIndex: 19
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("screenTime", false) && (Config.options?.panelFamily ?? "ii") === "iris"
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMaskScreenTime : null
                    WidgetInputMask { id: _hitMaskScreenTime; loader: parent }
                    sourceComponent: ScreenTimeWidget {
                        widgetIndex: 39
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("editorial", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? editorialHitMask : null
                    WidgetInputMask { id: editorialHitMask; loader: parent }
                    sourceComponent: EditorialWidget {
                        widgetIndex: 22
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("shape", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMaskshape : null
                    WidgetInputMask { id: _hitMaskshape; loader: parent }
                    sourceComponent: ShapeWidget {
                        widgetIndex: 20
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("dateBadge", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMaskdateBadge : null
                    WidgetInputMask { id: _hitMaskdateBadge; loader: parent }
                    sourceComponent: DateBadgeWidget {
                        widgetIndex: 21
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }


                FadeLoader {
                    shown: bgRoot._widgetEnabled("worldClock", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMask15 : null
                    WidgetInputMask { id: _hitMask15; loader: parent }
                    sourceComponent: WorldClockWidget {
                        widgetIndex: 14
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("userCard", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMask16 : null
                    WidgetInputMask { id: _hitMask16; loader: parent }
                    sourceComponent: UserCardWidget {
                        widgetIndex: 15
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("newsTicker", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMask12 : null
                    WidgetInputMask { id: _hitMask12; loader: parent }
                    sourceComponent: NewsTickerWidget {
                        widgetIndex: 11
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("mascot", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMask13 : null
                    WidgetInputMask { id: _hitMask13; loader: parent }
                    sourceComponent: MascotWidget {
                        widgetIndex: 12
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetEnabled("japaneseTypography", false)
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMask14 : null
                    WidgetInputMask { id: _hitMask14; loader: parent }
                    sourceComponent: JapaneseTypographyWidget {
                        widgetIndex: 13
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                // Extra mascot instances (Settings › Widgets › Mascot › "+"),
                // one MascotWidget per id under background.widgets.mascotInstances.
                Repeater {
                    model: ScriptModel {
                        values: {
                            void Config.revision;
                            const obj = Config.getNestedValue("background.widgets.mascotInstances", {});
                            return Object.keys(obj ?? {}).sort();
                        }
                    }

                    Loader {
                        id: mascotInstanceLoader
                        required property string modelData
                        required property int index
                        z: item?.desktopStackZ ?? 0
                        containmentMask: GlobalStates.widgetEditMode ? _hitMaskInst : null
                        WidgetInputMask { id: _hitMaskInst; loader: parent }

                        active: false

                        function _configEnabled(): bool {
                            return DesktopWidgetLayout.enabled(bgRoot.screenName,
                                "mascotInstances." + modelData,
                                Config.getNestedValue("background.widgets.mascotInstances." + modelData + ".enable", false));
                        }
                        function _load(): void {
                            active = true;
                            setSource(Quickshell.shellPath("modules/background/widgets/mascot/MascotWidget.qml"), {
                                configEntryName: "mascotInstances." + modelData,
                                widgetIndex: 23 + index,
                                outputName: bgRoot.screen?.name ?? "",
                                screenWidth: bgRoot.screen.width,
                                screenHeight: bgRoot.screen.height,
                                scaledScreenWidth: bgRoot.screen.width,
                                scaledScreenHeight: bgRoot.screen.height,
                                wallpaperScale: 1
                            });
                        }
                        function _unload(): void {
                            active = false;
                            source = "";
                        }
                        function _syncLoaded(): void {
                            if (_configEnabled()) {
                                if (!item) _load();
                            } else if (item || active) {
                                _unload();
                            }
                        }

                        Component.onCompleted: Qt.callLater(_syncLoaded)

                        Connections {
                            target: Config
                            function onConfigChanged() { Qt.callLater(mascotInstanceLoader._syncLoaded) }
                        }
                        Connections {
                            target: bgRoot.screen
                            function onWidthChanged() {
                                if (!mascotInstanceLoader.item) return;
                                mascotInstanceLoader.item.screenWidth = bgRoot.screen.width;
                                mascotInstanceLoader.item.scaledScreenWidth = bgRoot.screen.width;
                            }
                            function onHeightChanged() {
                                if (!mascotInstanceLoader.item) return;
                                mascotInstanceLoader.item.screenHeight = bgRoot.screen.height;
                                mascotInstanceLoader.item.scaledScreenHeight = bgRoot.screen.height;
                            }
                        }
                    }
                }

                // Custom user widgets from ~/.config/inir/widgets/
                Repeater {
                    model: CustomWidgets.ready ? CustomWidgets.widgets : []

                    Loader {
                        id: customWidgetLoader
                        z: item?.desktopStackZ ?? 0
                        containmentMask: GlobalStates.widgetEditMode ? _customHitMask : null
                        WidgetInputMask { id: _customHitMask; loader: parent }
                        required property var modelData
                        required property int index

                        active: false

                        function _configEnabled(): bool {
                            return DesktopWidgetLayout.enabled(bgRoot.screenName,
                                "custom." + modelData.id,
                                Config.getNestedValue("background.widgets.custom." + modelData.id + ".enable", false));
                        }

                        // setSource passes required properties at construction time
                        function _load(): void {
                            const props = {
                                widgetIndex: 40 + index,
                                outputName: bgRoot.screen?.name ?? "",
                                screenWidth: bgRoot.screen.width,
                                screenHeight: bgRoot.screen.height,
                                scaledScreenWidth: bgRoot.screen.width,
                                scaledScreenHeight: bgRoot.screen.height,
                                wallpaperScale: 1,
                            };
                            // Pass manifest data for auto-popover and resize
                            if (modelData.configKeys && Object.keys(modelData.configKeys).length > 0)
                                props.manifestConfigKeys = modelData.configKeys;
                            // Default to uniform resize via widgetScale for all custom widgets
                            const axes = (modelData.resizableAxes && Object.keys(modelData.resizableAxes).length > 0)
                                ? modelData.resizableAxes : { uniform: "widgetScale" };
                            props.resizableAxes = axes;
                            active = true;
                            setSource(modelData.qmlPath, props);
                        }

                        function _unload(): void {
                            active = false;
                            source = "";
                        }

                        function _syncLoaded(): void {
                            if (_configEnabled()) {
                                if (!item)
                                    _load();
                            } else if (item || active) {
                                _unload();
                            }
                        }

                        Component.onCompleted: Qt.callLater(_syncLoaded)

                        Connections {
                            target: Config
                            function onConfigChanged() {
                                Qt.callLater(customWidgetLoader._syncLoaded);
                            }
                        }

                        Connections {
                            target: bgRoot.screen
                            function onWidthChanged() {
                                if (!customWidgetLoader.item) return;
                                customWidgetLoader.item.screenWidth = bgRoot.screen.width;
                                customWidgetLoader.item.scaledScreenWidth = bgRoot.screen.width;
                            }
                            function onHeightChanged() {
                                if (!customWidgetLoader.item) return;
                                customWidgetLoader.item.screenHeight = bgRoot.screen.height;
                                customWidgetLoader.item.scaledScreenHeight = bgRoot.screen.height;
                            }
                        }
                    }
                }

            }
        }
    }
    }
}
