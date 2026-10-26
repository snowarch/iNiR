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

import qs.modules.shared.livePins
import qs.modules.shared.background.widgets
import qs.modules.shared.background.widgets.clock
import qs.modules.shared.background.widgets.mediaControls
import qs.modules.shared.background.widgets.weather
import qs.modules.shared.background.widgets.visualizer
import qs.modules.shared.background.widgets.imageConverter
import qs.modules.shared.background.widgets.systemMonitor
import qs.modules.shared.background.widgets.battery
import qs.modules.shared.background.widgets.notes
import qs.modules.shared.background.widgets.calendar
import qs.modules.shared.background.widgets.todo
import qs.modules.shared.background.widgets.timers
import qs.modules.shared.background.widgets.shape
import qs.modules.shared.background.widgets.dateBadge
import qs.modules.shared.background.widgets.uptime
import qs.modules.shared.background.widgets.controls
import qs.modules.shared.background.widgets.screenTime
import qs.modules.shared.background.widgets.palette
import qs.modules.shared.background.widgets.lyrics
import qs.modules.shared.background.widgets.dayProgress
import qs.modules.shared.background.widgets.worldClock
import qs.modules.shared.background.widgets.userCard
import qs.modules.shared.background.widgets.newsTicker
import qs.modules.shared.background.widgets.mascot
import qs.modules.shared.background.widgets.japaneseTypography
import qs.modules.shared.background.desktopItems
import "root:modules/common/functions/parallax.js" as ParallaxMath
import "widgets/OrganicEdgeConfig.js" as OrganicEdgeConfig
import "root:modules/common/functions/ArrangeMath.js" as ArrangeMath

Scope {
    id: backgroundScope
    // ii and iRiS each load one; while the family switches both stand a moment, and only the family's answers IPC
    property string family: ""
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

    readonly property var _everyKeys: ({ plate: "showBackground", outline: "showBorder", strength: "backgroundOpacity", ink: "colorMode", lock: "locked" })

    IpcHandler {
        target: "background"
        enabled: backgroundScope.family.length === 0 || (Config.options?.panelFamily ?? "ii") === backgroundScope.family
        function widgetDesign(name: string): string {
            if (name === "status")
                return DesktopWidgetDesign.current + " · " + DesktopWidgetDesign.exceptionCount + " own looks"
                    + (DesktopWidgetDesign.canUndo ? " · undo available" : "")
            if (name === "undo") return DesktopWidgetDesign.undo()
            return DesktopWidgetDesign.apply(name)
        }

        function widgetMaterial(action: string): string {
            if (action === "match") return DesktopWidgetDesign.matchSurfaces()
            if (action === "toggle" || action === "clear" || action === "glass") {
                const now = String(Config.options?.iris?.widgets?.material ?? "glass")
                const next = action !== "toggle" ? action : now === "clear" ? "glass" : "clear"
                Config.setNestedValue("iris.widgets.material", next)
                return next
            }
            if (action === "status")
                return String(Config.options?.iris?.widgets?.material ?? "glass") + " · "
                    + DesktopWidgetDesign.ownSurfaceCount + " widgets with their own material or opacity"
            return "Use status, match, toggle, clear or glass"
        }

        // Every widget's plate, outline, ink or lock at once (Material, iNstrument, Readout; a face's surface is widgetMaterial).
        function everyWidget(part: string, value: string): string {
            const key = backgroundScope._everyKeys[part]
            if (!key)
                return "Use plate, outline, strength, ink or lock"
            let next
            if (key === "colorMode") {
                if (!["auto", "light", "dark"].includes(value)) return "ink takes auto, light or dark"
                next = value
            } else if (key === "backgroundOpacity") {
                next = Number(value)
                if (!isFinite(next) || next < 0 || next > 100) return "strength takes 0 to 100"
                next = next / 100
            } else {
                if (!["on", "off"].includes(value)) return part + " takes on or off"
                next = value === "on"
            }
            return part + " " + value + " on " + DesktopWidgetOptions.setEvery(key, next) + " widgets"
        }

        function everyWidgetStatus(): string {
            return Object.keys(backgroundScope._everyKeys).map(name => name + " " + (DesktopWidgetOptions.everyState(backgroundScope._everyKeys[name]) || "none")).join(" · ")
        }

        function widgetSearch(query: string): string {
            if ((Config.options?.panelFamily ?? "ii") !== "iris")
                return "the widget search is part of the iRiS widget bar"
            if (query === "close") {
                GlobalStates.widgetSearchOpen = false
                GlobalStates.widgetSearchText = ""
                return "search closed"
            }
            if (["next", "previous", "take"].includes(query)) {
                GlobalStates.widgetSearchCommand(query)
                return query
            }
            if (!GlobalStates.widgetEditMode)
                GlobalStates.setWidgetEditMode(true)
            GlobalStates.widgetSearchText = query === "open" ? "" : query
            GlobalStates.widgetSearchOpen = true
            return "searching: " + GlobalStates.widgetSearchText
        }

        function toggleEditMode(): string {
            GlobalStates.setWidgetEditMode(!GlobalStates.widgetEditMode)
            return GlobalStates.widgetEditMode ? "edit mode on" : "edit mode off"
        }

        function toggleWidgetManager(): string {
            // The shelf is the library now: arranging opens with it out, and this finds a widget on it.
            if (!GlobalStates.widgetEditMode) GlobalStates.setWidgetEditMode(true)
            GlobalStates.widgetSearchOpen = true
            return "widget shelf search"
        }

        function setEditMode(enabled: bool): string {
            GlobalStates.setWidgetEditMode(enabled)
            return GlobalStates.widgetEditMode ? "edit mode on" : "edit mode off"
        }

        // Desktops: the factory ones and the ones saved, by id; wearing one is an ordinary change (Undo takes it back).
        function presets(): string {
            return JSON.stringify(DesktopPresets.factory.concat(DesktopPresets.presets)
                .map(preset => ({ id: preset.id, name: preset.name })).concat([{ worn: DesktopPresets.wornId() }]))
        }
        function wearPreset(id: string): string {
            if (!DesktopPresets.find(id)) return "no desktop " + id
            DesktopPresets.wear(id)
            return "wearing " + DesktopPresets.find(id).name
        }
        function savePreset(name: string): string {
            return DesktopPresets.save(name)
        }
        // A widget's size class (small, medium, large) on every screen it is out on, in the family drawing it.
        function sizeWidget(widgetName: string, size: string): string {
            const out = []
            for (const output of Object.keys(backgroundScope.widgetCanvases)) {
                const canvas = backgroundScope.widgetCanvases[output]
                if (!canvas || typeof canvas._loadedDesktopWidgets !== "function") continue
                for (const widget of canvas._loadedDesktopWidgets()) {
                    if (widget.configEntryName !== widgetName) continue
                    if (widget.materialSized && widget.materialSizes.includes(size)) widget.commitMaterialSize(size)
                    else if (!widget.materialSized && widget.irisSizeChoices.includes(size)) widget.commitIrisSize(size)
                    else continue
                    out.push(output)
                }
            }
            return out.length > 0 ? widgetName + " " + size + " on " + out.join(", ") : "no " + widgetName + " that takes " + size
        }
        // Where every widget sits, per screen: [{ output, widget, x, y, w, h }].
        function widgetRects(): string {
            const out = []
            for (const output of Object.keys(backgroundScope.widgetCanvases)) {
                const canvas = backgroundScope.widgetCanvases[output]
                if (!canvas || typeof canvas._loadedDesktopWidgets !== "function") continue
                for (const widget of canvas._loadedDesktopWidgets())
                    out.push({ output: output, widget: widget.configEntryName, x: Math.round(widget.x), y: Math.round(widget.y),
                        w: Math.round(widget.width), h: Math.round(widget.height) })
            }
            return JSON.stringify(out)
        }
        // The options the widget's Options page shows now (what Settings has for it), with their values:
        // [{ key, kind, label, value, choices?, min?, max? }].
        function widgetOptions(widgetName: string): string {
            return JSON.stringify(DesktopWidgetOptions.widgetRows
                .filter(spec => spec.widget === widgetName && !spec.widgetEnable && (!spec.showIf || spec.showIf()))
                .map(spec => ({ key: spec.key, kind: spec.kind, label: spec.label, value: DesktopWidgetOptions.read(spec),
                    choices: spec.kind === "choice" ? (spec.choicesFrom ? DesktopWidgetOptions.choicesFor(String(spec.choicesFrom))
                        : spec.choices ?? []).map(pick => pick.value) : undefined, min: spec.min, max: spec.max })))
        }
        // Writes one option the way its row does; the value is JSON (true, 12, "pill"). Returns what it reads back.
        function widgetOptionSet(widgetName: string, key: string, value: string): string {
            const spec = DesktopWidgetOptions.widgetRows.find(row => row.widget === widgetName && row.key === key)
            if (!spec)
                return "no option " + key + " on " + widgetName
            let next = value
            try { next = JSON.parse(value) } catch (error) {}
            DesktopWidgetOptions.write(spec, next)
            return JSON.stringify(DesktopWidgetOptions.read(spec))
        }
        // How every face fits its size: text over other text, past the plate, hugging its edge or cut short.
        // [{ output, widget, size, issues: [...] }], only widgets with something wrong.
        function widgetFit(): string {
            const out = []
            for (const output of Object.keys(backgroundScope.widgetCanvases)) {
                const canvas = backgroundScope.widgetCanvases[output]
                if (!canvas || typeof canvas._loadedDesktopWidgets !== "function") continue
                for (const widget of canvas._loadedDesktopWidgets()) {
                    const texts = []
                    const walk = (item, alpha) => {
                        for (const child of item.children ?? []) {
                            const seen = alpha * child.opacity
                            if (!child.visible || seen < 0.05) continue
                            if (typeof child.text === "string" && child.text.trim().length > 0 && (child.paintedWidth ?? 0) > 0) {
                                const at = child.mapToItem(widget, 0, 0)
                                const dx = child.horizontalAlignment === Text.AlignHCenter ? (child.width - child.paintedWidth) / 2
                                    : child.horizontalAlignment === Text.AlignRight ? child.width - child.paintedWidth : 0
                                const dy = child.verticalAlignment === Text.AlignVCenter ? (child.height - child.paintedHeight) / 2
                                    : child.verticalAlignment === Text.AlignBottom ? child.height - child.paintedHeight : 0
                                texts.push({ text: child.text.replace(/\s+/g, " ").slice(0, 20), x: at.x + dx, y: at.y + dy,
                                    // a wrapped text clamped to its lines (a headline) is cut on purpose; a label or figure is not
                                    w: child.paintedWidth, h: child.paintedHeight, cut: child.truncated === true && !(child.wrapMode > 0) })
                            }
                            walk(child, seen)
                        }
                    }
                    walk(widget, 1)
                    const issues = []
                    const edge = 10
                    for (const t of texts) {
                        if (t.cut) issues.push("cut '" + t.text + "'")
                        if (t.x < -1 || t.y < -1 || t.x + t.w > widget.width + 1 || t.y + t.h > widget.height + 1)
                            issues.push("past the plate '" + t.text + "'")
                        else if (t.x < edge || t.y < edge || t.x + t.w > widget.width - edge || t.y + t.h > widget.height - edge)
                            issues.push("hugs the edge '" + t.text + "' at " + Math.round(t.x) + "," + Math.round(t.y)
                                + " of " + Math.round(widget.width) + "x" + Math.round(widget.height))
                    }
                    for (let i = 0; i < texts.length; ++i)
                        for (let j = i + 1; j < texts.length; ++j) {
                            const a = texts[i], b = texts[j]
                            const ox = Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x)
                            const oy = Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y)
                            if (ox > 2 && oy > 0.3 * Math.min(a.h, b.h))
                                issues.push("'" + a.text + "' over '" + b.text + "' at " + Math.round(Math.max(a.x, b.x)) + "," + Math.round(Math.max(a.y, b.y)))
                        }
                    if (issues.length > 0)
                        out.push({ output: output, widget: widget.configEntryName, size: widget.irisSize ?? "", issues: issues })
                }
            }
            return JSON.stringify(out)
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
                    bodies: DesktopArrange.bodiesOf(screen?.name ?? ""),
                    card: DesktopEditStage.cardFor(screen?.name ?? "", screen?.width ?? 0, screen?.height ?? 0),
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
            const pages = widget.irisFaced ? ["widget", "look", "arrange"].concat(widget.stacked ? ["stack"] : [])
                : ["widget", "colors", "layout"].concat(widget.hasOptionRows ? ["options"] : [])
            const aliases = ({ look: widget.irisFaced ? "look" : "colors", colors: widget.irisFaced ? "look" : "colors",
                arrange: widget._arrangeTab, layout: widget._arrangeTab, widget: "widget", stack: "stack", options: "options" })
            const target = aliases[String(page ?? "").trim()] ?? ""
            if (!pages.includes(target))
                return "pages: widget, look, arrange" + (widget.stacked ? ", stack" : "") + (!widget.irisFaced && widget.hasOptionRows ? ", options" : "")
            widget.openQuickControls(target)
            return JSON.stringify({ widget: key, page: target })
        }

        function quickControlsGeometry(): string {
            const [output, name] = GlobalStates.selectedDesktopWidget.split("::")
            const widget = (backgroundScope.widgetCanvases[output]?._loadedDesktopWidgets() ?? [])
                .find(item => item.configEntryName === name) ?? null
            return widget ? widget.editControlsGeometryReport : "{}"
        }

        function widgetSnapshot(widgetName: string, path: string): string {
            const target = String(path ?? "").trim()
            if (!target.endsWith(".png")) return "give a path ending in .png"
            for (const output of Object.keys(backgroundScope.widgetCanvases)) {
                const canvas = backgroundScope.widgetCanvases[output]
                if (!canvas || typeof canvas._loadedDesktopWidgets !== "function") continue
                for (const widget of canvas._loadedDesktopWidgets()) {
                    if (widget.configEntryName !== widgetName) continue
                    const ok = widget.grabToImage(result => result.saveToFile(target))
                    return ok ? output + " · " + Math.round(widget.width) + "×" + Math.round(widget.height) + " → " + target
                        : "the widget could not be rendered"
                }
            }
            return "no loaded widget named " + widgetName
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
                        shadow: widget._legibleShadow ? Math.round(widget._legibleShadowOpacity * 100) / 100 : 0,
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
                worldClock: false, userCard: false, controls: false, screenTime: false, palette: false, lyrics: false
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

        // Carries a widget to x,y on the focused output the way a drop does (magnets, grid, never on top of another).
        // `probe` only reports where it would land and the guides it would draw.
        function arrangeWidget(widgetName: string, x: real, y: real, probe: bool): string {
            const screen = GlobalStates.focusedScreen ?? Quickshell.screens[0]
            const canvas = backgroundScope.widgetCanvases[screen?.name ?? ""]
            const item = canvas?.loadedWidget((screen?.name ?? "") + "::" + String(widgetName ?? "").trim()) ?? null
            if (!item)
                return "widget not on the focused output: " + widgetName
            const plan = item._planDrop(Number(x), Number(y))
            if (!probe)
                item._setOutputValues({ x: plan.x, y: plan.y, placementStrategy: "free" })
            return JSON.stringify({ widget: widgetName, asked: { x: Number(x), y: Number(y) }, lands: { x: plan.x, y: plan.y },
                size: { width: Math.round(item.width), height: Math.round(item.height) }, guides: plan.guides })
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
            if (!DesktopWidgetRegistry.has(widgetName))
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
        // An iRiS texture filter (Afterglow's grade, Light leak's exposure) draws the container (and hides it): glass copies
        // what is seen. While awww shows the picture the container draws nothing, and a glass copying it was empty: the
        // wallpaper came through unblurred. Then there is no layer and the glass reads the picture itself.
        readonly property Item wallpaperLayer: bgRoot.externalMainWallpaperActive ? null : textureLoader.item ?? wallpaperContainer
        // Bumped whenever what the wallpaper layer shows can change (picture, parallax, Afterglow arriving): iRiS glass
        // copies the layer only after a bump instead of every frame the desktop redraws.
        property int wallpaperLayerRevision: 0
        readonly property bool wallpaperLayerAnimating: bgRoot.internalShaderTransitionRequested
        onWallpaperPathRawChanged: {
            bgRoot.wallpaperLayerRevision++
            const now = Date.now()
            bgRoot.previewBrisk = Wallpapers.internalPreviewActive && now - bgRoot._lastWallpaperSwitch < 1200
            bgRoot._lastWallpaperSwitch = now
            const raw = bgRoot.wallpaperPathRaw
            if (Wallpapers.isVideoFile(raw)) {
                bgRoot._videoPath = raw
                bgRoot._outgoingVideo = ""
                videoHandoff.stop()
            } else if (bgRoot._videoPath.length > 0) {
                bgRoot._outgoingVideo = bgRoot._videoPath
                bgRoot._videoPath = ""
                videoHandoff.restart()
            }
        }
        // Leaving a video for a picture: the crossfader starts from nothing (the video was never its texture), so the
        // desktop went black until the picture arrived. The video holds its frame on top until the picture has made its
        // transition underneath, then fades out.
        property string _videoPath: Wallpapers.isVideoFile(bgRoot.wallpaperPathRaw) ? bgRoot.wallpaperPathRaw : ""
        property string _outgoingVideo: ""
        Timer {
            id: videoHandoff
            interval: bgRoot.wallpaperTransitionMs + 450
        }
        // Browsing previews quickly: a transition finishes before the next picture may start, so the configured length
        // (800 ms) left the desktop a second behind the gallery. While the previews come fast they keep its pace.
        property real _lastWallpaperSwitch: 0
        property bool previewBrisk: false
        readonly property int wallpaperTransitionMs: {
            const base = Config.options?.background?.transition?.duration ?? 800
            return bgRoot.previewBrisk && Wallpapers.internalPreviewActive ? Math.min(base, 340) : base
        }

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
        function _widgetShown(widgetKey: string): bool {
            return bgRoot._widgetEnabled(widgetKey, DesktopWidgetRegistry.defaultOn(widgetKey))
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
        readonly property bool _menuOpen: (familyDesktopMenu.item?.active ?? false) || desktopContextMenu.active || desktopItemContextMenu.active
        // Once a desktop menu has closed, the keyboard its right-click took goes back too.
        on_MenuOpenChanged: if (!bgRoot._menuOpen) Qt.callLater(bgRoot.releaseKeyboard)
        readonly property bool _needsKeyboardFocus: GlobalStates.deferredPanelsReady
            && (bgRoot._menuOpen || !bgRoot._keyboardReleased)
            && (GlobalStates.widgetEditMode
                || bgRoot._widgetEnabled("notes", false)
                || bgRoot._widgetEnabled("todo", false))

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
        // Wallpapers.fillMode: one answer for every desktop and awww (span on one screen is fill).
        readonly property string fillMode: Wallpapers.fillMode
        // Span: this output shows its own slice of one picture laid across the box around every screen.
        readonly property bool spanning: bgRoot.fillMode === "span"
        readonly property var panOptions: bgRoot.backgroundOptions.pan ?? {}
        readonly property real panX: bgRoot.panOptions.x ?? 0.0
        readonly property real panY: bgRoot.panOptions.y ?? 0.0
        readonly property real panZoom: Math.max(1.0, Math.min(3.0, bgRoot.panOptions.zoom ?? 1.0))
        readonly property bool hasPan: bgRoot.fillMode === "fill" && (bgRoot.panX !== 0.0 || bgRoot.panY !== 0.0 || bgRoot.panZoom !== 1.0)
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
            && !bgRoot.textureWallpaperActive
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
            && !textureHandoff.running
        // An iRiS texture over the wallpaper (Afterglow's grade, Light leak's exposure) filters whatever is drawn here
        // (still, transition, preview, video, GIF), so the picture is drawn here, not by awww; leaving it, the picture
        // stays drawn here until awww shows it.
        readonly property string irisTexture: (Config.options?.panelFamily ?? "ii") === "iris"
            ? String(Config.options?.iris?.appearance?.texture ?? "solid") : "solid"
        readonly property bool textureWallpaperActive: (bgRoot.irisTexture === "afterglow"
                ? (Config.options?.iris?.appearance?.afterglow?.wallpaper ?? true)
                : bgRoot.irisTexture === "leak" && (Number(Config.options?.iris?.appearance?.leak?.wallpaper ?? 50) > 0
                    || Config.options?.iris?.appearance?.leak?.backdrop === "light"))
            && bgRoot.wallpaperPathRaw.length > 0
            && !bgRoot.webWallpaperActive && !bgRoot.wallpaperSafetyTriggered && !bgRoot.backdropActive
        Timer {
            id: textureHandoff
            interval: AwwwBackend.transitionDurationMs + 1800
        }
        onTextureWallpaperActiveChanged: if (!bgRoot.textureWallpaperActive) textureHandoff.restart()
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

        readonly property bool focusBlurOn: (bgRoot.effectsOptions?.enableBlur ?? false) && (bgRoot.effectsOptions?.blurRadius ?? 0) > 0
        property real blurProgress: {
            return bgRoot.focusBlurOn ? focusPresenceProgress * _blurTransitionFactor : 0;
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
        // Host for LiveLayer (continuous motion in a widget moves to a small surface of its own instead of
        // repainting this whole output every frame): nothing here covers or moves a still widget outside edit.
        readonly property bool liveCalm: !GlobalStates.widgetEditMode && !GlobalStates.shellLayoutEditMode
            && !GlobalStates.screenLocked
        readonly property int liveLayer: WlrLayer.Bottom
        readonly property int liveEpoch: 0
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

        // Arranging widgets under a family that stages it: its paper behind the card, its card edge over it.
        readonly property var editCard: DesktopEditStage.cardFor(bgRoot.screenName, bgRoot.width, bgRoot.height)
        readonly property string editStagePart: Plugins.part(Plugins.active, "editStage")
        Loader {
            anchors.fill: parent
            active: bgRoot.editCard.p > 0 && bgRoot.editStagePart.length > 0
            source: bgRoot.editStagePart
            onLoaded: {
                item.side = "under"
                item.card = Qt.binding(() => bgRoot.editCard)
                item.waiting = Qt.binding(() => editStill.visible && editStill.status !== Image.Ready)
                item.still = Qt.binding(() => Wallpapers.stillUrlFor(bgRoot.wallpaperPathRaw))
            }
        }

        Item {
            id: desktopStage
            anchors.fill: parent
            transform: [
                Scale { xScale: bgRoot.editCard.s; yScale: bgRoot.editCard.s },
                Translate { x: bgRoot.editCard.x; y: bgRoot.editCard.y }
            ]
            // As a card the desktop is drawn whole into one picture its corners are cut from (the family's card shape:
            // a real edge, the paper and its shadow seen past it), brought down to the card's pixels by a tent of taps
            // (CardPicture.frag) at the card's scale of the moment, so it reads sharp from the first frame. Mipmaps blurred
            // text; a picture drawn at the card's size aliased it, and switching every text to distance-field glyphs once
            // the card settled made it turn legible late (and walked the whole desktop every 1.5 s while arranging).
            layer.enabled: bgRoot.editCard.p > 0 && (editOverLoader.item?.cardMask ?? null) !== null
            layer.smooth: true
            layer.effect: ShaderEffect {
                readonly property vector2d size: Qt.vector2d(bgRoot.width, bgRoot.height)
                readonly property real corner: Number(editOverLoader.item?.cardCorner ?? 0)
                readonly property real chamfer: editOverLoader.item?.cardCut ? 1 : 0
                readonly property real edge: 1 / Math.max(0.05, bgRoot.editCard.s * bgRoot.devicePixelRatio)
                readonly property vector2d reach: Qt.vector2d(
                    0.2 / Math.max(0.2, bgRoot.editCard.s) / Math.max(1, bgRoot.width * bgRoot.devicePixelRatio),
                    0.2 / Math.max(0.2, bgRoot.editCard.s) / Math.max(1, bgRoot.height * bgRoot.devicePixelRatio))
                fragmentShader: Qt.resolvedUrl("edit/CardPicture.frag.qsb")
            }

            // A wallpaper another program draws (awww) stays full size under the shell: the card carries its still.
            Image {
                id: editStill
                anchors.fill: parent
                z: -1
                visible: bgRoot.editCard.p > 0 && bgRoot.externalMainWallpaperActive
                source: editStill.visible ? Wallpapers.stillUrlFor(bgRoot.wallpaperPathRaw) : ""
                sourceSize: Qt.size(bgRoot.width, bgRoot.height)
                fillMode: Image.PreserveAspectCrop
                // Shrunk with the card: a mipmap keeps a pixel-art wall from breaking into uneven pixels.
                mipmap: true
                asynchronous: true
                cache: true
            }

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
                onEffectiveValueXChanged: bgRoot.wallpaperLayerRevision++
                onEffectiveValueYChanged: bgRoot.wallpaperLayerRevision++
                
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
                    && !Config.options?.performance?.lowPower
                readonly property bool lockBlurNeedsStaticTexture: (bgRoot.lockBlurOptions.enable ?? false)
                    && (GlobalStates.screenLocked || scaleAnim.running)
                readonly property bool needsStaticTexture: !bgRoot.backdropActive
                    && !bgRoot.wallpaperIsGif && !bgRoot.wallpaperIsVideo
                    && (showInternalStaticWallpaper || localBlurNeedsStaticTexture
                        || lockBlurNeedsStaticTexture
                        || bgRoot.internalShaderTransitionRequested)
                readonly property real panOffsetX: bgRoot.effectiveHasPan ? (bgRoot.panX * (bgRoot.parallaxTotalX / 2)) : 0
                readonly property real panOffsetY: bgRoot.effectiveHasPan ? (bgRoot.panY * (bgRoot.parallaxTotalY / 2)) : 0
                readonly property real targetX: bgRoot.spanning ? Wallpapers.spanArea.x - bgRoot.screen.x
                    : useParallax
                    ? (bgRoot.parallaxTotalX > 0
                        ? (ParallaxMath.parallaxPosition(bgRoot.parallaxTotalX, activeValueX) + panOffsetX)
                        : ParallaxMath.centerOffset(bgRoot.scaledWallpaperWidth, bgRoot.screen.width))
                    : panOffsetX
                readonly property real targetY: bgRoot.spanning ? Wallpapers.spanArea.y - bgRoot.screen.y
                    : useParallax
                    ? (bgRoot.parallaxTotalY > 0
                        ? (ParallaxMath.parallaxPosition(bgRoot.parallaxTotalY, activeValueY) + panOffsetY)
                        : ParallaxMath.centerOffset(bgRoot.scaledWallpaperHeight, bgRoot.screen.height))
                    : panOffsetY
                readonly property real targetWidth: bgRoot.spanning ? Wallpapers.spanArea.width
                    : (useParallax || bgRoot.effectiveHasPan) ? bgRoot.scaledWallpaperWidth : bgRoot.screen.width
                readonly property real targetHeight: bgRoot.spanning ? Wallpapers.spanArea.height
                    : (useParallax || bgRoot.effectiveHasPan) ? bgRoot.scaledWallpaperHeight : bgRoot.screen.height
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

                // Fit and center leave bars around the picture: they are black, as awww draws them, never the wallpaper
                // awww still holds underneath (the applied one while a preview is shown, or the last still under a video).
                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    visible: (bgRoot.fillMode === "fit" || bgRoot.fillMode === "center") && !bgRoot.webWallpaperActive
                        && !bgRoot.backdropActive
                        && (wallpaperContainer.showInternalStaticWallpaper || bgRoot.wallpaperIsGif || bgRoot.wallpaperIsVideo)
                }

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
                    // A scaling awww does not draw (fit, stretch, tile, center, span) hides its transition: this one runs.
                    enableTransitions: (!AwwwBackend.active
                            || bgRoot.internalShaderTransitionRequested
                            || bgRoot.textureWallpaperActive
                            || !AwwwBackend.supportsFillMode(bgRoot.fillMode))
                        && (Config.options?.background?.transition?.enable ?? true)
                    transitionType: Config.options?.background?.transition?.type ?? "crossfade"
                    transitionDirection: Config.options?.background?.transition?.direction ?? "right"
                    transitionBaseDuration: bgRoot.wallpaperTransitionMs
                    fillMode: Wallpapers.imageFillFor(bgRoot.fillMode)
                    // Decoded at the size it is drawn, not the file's: a 6000 px wallpaper was held twice at full size
                    // (~70 MB each) for a 1080p output. Crop and fit are then decoded at their optimal size (Qt's
                    // Image.sourceSize); tile and center draw the image at its own size, so they keep it. The target
                    // size, not the animated one, so a parallax resize does not decode again per frame.
                    sourceSize: bgRoot.fillMode === "tile" || bgRoot.fillMode === "center" ? Qt.size(0, 0)
                        : Qt.size(Math.ceil(wallpaperContainer.targetWidth * bgRoot.devicePixelRatio),
                            Math.ceil(wallpaperContainer.targetHeight * bgRoot.devicePixelRatio))

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
                    fillMode: Wallpapers.imageFillFor(bgRoot.fillMode)
                    // No sourceSize for GIFs - let Qt handle native size for performance

                    layer.enabled: visible && Appearance.effectsEnabled
                        && (bgRoot.effectsOptions.enableAnimatedBlur ?? false)
                        && (bgRoot.effectsOptions.blurRadius ?? 0) > 0
                        && (bgRoot.effectsOptions.thumbnailBlurStrength ?? 50) > 0
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
                    visible: opacity > 0 && !blurLoader.active && !bgRoot.backdropActive
                        && (bgRoot.wallpaperIsVideo || bgRoot._outgoingVideo.length > 0)
                    opacity: bgRoot.wallpaperIsVideo || videoHandoff.running ? 1 : 0
                    onOpacityChanged: if (opacity === 0 && !bgRoot.wallpaperIsVideo) bgRoot._outgoingVideo = ""
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
                        if (bgRoot.webWallpaperActive || bgRoot.wallpaperSafetyTriggered || bgRoot.backdropActive) return "";
                        if (!bgRoot._familyOwnsScreen) return "";
                        return bgRoot.wallpaperIsVideo ? bgRoot.wallpaperPathRaw : bgRoot._outgoingVideo;
                    }
                    fillMode: Wallpapers.videoFillFor(bgRoot.fillMode)
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
                        && (bgRoot.effectsOptions.thumbnailBlurStrength ?? 50) > 0
                    layer.effect: GaussianBlur {
                        radius: Math.round((bgRoot.effectsOptions.blurRadius ?? 32) * Math.max(0, Math.min(1, (bgRoot.effectsOptions.thumbnailBlurStrength ?? 50) / 100)))
                        // See #159 — cap samples to bound fragment shader cost
                        samples: Math.min(33, radius * 2 + 1)
                    }
                }
            }

            // The family's texture over the wallpaper (its parts `wallpaper.leak`, `wallpaper.afterglow`).
            FamilyPart {
                id: textureLoader
                z: 0.5
                anchors.fill: wallpaperContainer
                when: bgRoot.textureWallpaperActive && bgRoot._familyOwnsScreen
                readonly property bool leak: bgRoot.irisTexture === "leak"
                part: leak ? "wallpaper.leak" : "wallpaper.afterglow"
                // The light alone never shows the picture: a video under it needs no redraw.
                props: leak ? ({ source: wallpaperContainer, picture: bgRoot.wallpaperPathRaw,
                        live: (bgRoot.wallpaperIsVideo || bgRoot.wallpaperIsGif) && Config.options?.iris?.appearance?.leak?.backdrop !== "light" })
                    : ({ source: wallpaperContainer, live: bgRoot.wallpaperIsVideo || bgRoot.wallpaperIsGif })
                Connections {
                    target: textureLoader.item
                    ignoreUnknownSignals: true
                    function onShown(): void { bgRoot.wallpaperLayerRevision++ }
                }
            }

            // Blur behind windows. Reads what is actually drawn: the crossfader (QML or awww rendering), the
            // Afterglow grade over it, or a video/GIF when "blur live wallpapers" is on. The resting layer blur on
            // live wallpapers above is separate (thumbnailBlurStrength) and never stands in for this one.
            Loader {
                id: blurAlwaysLoader
                z: 1
                active: Appearance.effectsEnabled
                        && !bgRoot.webWallpaperActive
                        && (bgRoot.blurProgress > 0)
                        && !Config.options?.performance?.lowPower
                        && !blurLoader.active
                        && !bgRoot.backdropActive
                        && (!(bgRoot.wallpaperIsGif || bgRoot.wallpaperIsVideo) || (bgRoot.effectsOptions.enableAnimatedBlur ?? false))
                anchors.fill: wallpaperContainer
                sourceComponent: Item {
                    anchors.fill: parent
                    opacity: bgRoot.blurProgress

                    GaussianBlur {
                        anchors.fill: parent
                        source: textureLoader.item ?? (bgRoot.wallpaperIsVideo ? videoWallpaper
                            : bgRoot.wallpaperIsGif ? gifWallpaper : wallpaper)
                        radius: bgRoot.effectsOptions.blurRadius ?? 32
                        // See #159 — cap samples to bound fragment shader cost
                        samples: Math.min(33, radius * 2 + 1)
                        // A still wallpaper blurs once: any shell animation repaints this window, and without the
                        // cache every repaint re-ran the full-screen passes. A video or live grade still updates it.
                        cached: true
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
                        if (familyDesktopMenu.item?.active) familyDesktopMenu.item.close()
                        return
                    }
                    if (desktopItemContextMenu.active) desktopItemContextMenu.close()
                    desktopMenuAnchor.x = mouse.x
                    desktopMenuAnchor.y = mouse.y
                    if (familyDesktopMenu.item) familyDesktopMenu.item.requestOpen()
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
                        action: () => { GlobalStates.widgetSearchOpen = true } },
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
                        action: () => GlobalStates.openSettingsAt("widgets") },
                    { text: Translation.tr("Done editing"), iconName: "check", monochromeIcon: true,
                        action: () => GlobalStates.setWidgetEditMode(false) }
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
                function onFamilyDesktopMenuRequested(outputName: string, x: real, y: real): void {
                    if (outputName !== bgRoot.screenName || !familyDesktopMenu.item) return
                    desktopMenuAnchor.x = x
                    desktopMenuAnchor.y = y
                    familyDesktopMenu.item.requestOpen()
                }
            }

            // The family's own desktop menu (its part `desktopMenu`); the shared one below otherwise.
            FamilyPart {
                id: familyDesktopMenu
                z: 27
                part: "desktopMenu"
                props: ({ anchorItem: desktopMenuAnchor, screenName: bgRoot.screenName, wallpaperPath: bgRoot.wallpaperPath })
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

            // Live snips on this desktop: here, not in a layer of their own, because niri stacks this window over any
            // later Bottom layer and it takes the pointer everywhere.
            Loader {
                anchors.fill: parent
                z: 21
                active: LivePins.supported && LivePins.pins.some(pin => !pin.onTop)
                visible: !GlobalStates.shellLayoutEditMode
                sourceComponent: LivePinDesk { screenName: bgRoot.screenName }
            }

            WidgetCanvas {
                id: widgetCanvas
                z: 20
                // Each widget's edit toolbar and quick-controls sheet live here, above every widget and
                // outside the widget's own opacity and dim, so they stay opaque and on top.
                readonly property Item editChromeLayer: widgetChromeLayer
                Component.onDestruction: {
                    delete backgroundScope.widgetCanvases[bgRoot.screenName]
                    DesktopArrange.setRoom(bgRoot.screenName, null)
                }
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

                // The widget lit as a drop target while another is carried over it (iRiS stacks).
                property string stackHint: ""

                function loadedWidget(instanceKey: string): var {
                    return widgetCanvas._loadedDesktopWidgets().find(item => item.editInstanceKey === instanceKey) ?? null
                }

                // The stackable widget most covered by the one being carried, or "" when none is covered enough.
                function stackDropCandidate(instanceKey: string): string {
                    const widgets = widgetCanvas._loadedDesktopWidgets()
                    const carried = widgets.find(item => item.editInstanceKey === instanceKey)
                    if (!carried || !carried.stackable)
                        return ""
                    const area = Math.max(1, carried.width * carried.height)
                    let best = ""
                    let bestShare = 0.4
                    for (const other of widgets) {
                        if (other === carried || !other.stackable || (carried.stacked && other.stacked))
                            continue
                        const across = Math.min(carried.x + carried.width, other.x + other.width) - Math.max(carried.x, other.x)
                        const down = Math.min(carried.y + carried.height, other.y + other.height) - Math.max(carried.y, other.y)
                        if (across <= 0 || down <= 0)
                            continue
                        const share = across * down / Math.min(area, Math.max(1, other.width * other.height))
                        if (share > bestShare) {
                            bestShare = share
                            best = other.editInstanceKey
                        }
                    }
                    return best
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

                // The gutter widgets keep between each other when the canvas places them: arranged side by side,
                // pushed aside or added, they sit this far apart.
                readonly property int arrangeGap: 16
                function _nearestFreePosition(item, desiredX, desiredY, placed, work): var {
                    const left = Number(work.left ?? 0)
                    const top = Number(work.top ?? 0)
                    const right = Number(work.right ?? widgetCanvas.width)
                    const bottom = Number(work.bottom ?? widgetCanvas.height)
                    const maxX = Math.max(left, right - item.width)
                    const maxY = Math.max(top, bottom - item.height)
                    const startX = Math.max(left, Math.min(maxX, desiredX))
                    const startY = Math.max(top, Math.min(maxY, desiredY))
                    // A hair under the gutter, so a spot exactly one gutter away counts as free.
                    const gap = widgetCanvas.arrangeGap
                    const testGap = gap - 1
                    if (widgetCanvas._positionIsFree(
                            startX, startY, item.width, item.height, placed, testGap))
                        return { x: Math.round(startX), y: Math.round(startY) }

                    const step = 24
                    let best = null
                    let bestDistance = Infinity
                    function consider(x, y): void {
                        const px = Math.max(left, Math.min(maxX, x))
                        const py = Math.max(top, Math.min(maxY, y))
                        if (!widgetCanvas._positionIsFree(
                                px, py, item.width, item.height, placed, testGap))
                            return
                        const dx = px - startX
                        const dy = py - startY
                        const distance = dx * dx + dy * dy
                        if (distance < bestDistance) {
                            bestDistance = distance
                            best = { x: Math.round(px), y: Math.round(py) }
                        }
                    }
                    // Beside a neighbour, one gutter away and aligned with it: a widget moved aside or added lines up
                    // with what is already there instead of landing on the lattice.
                    for (const rect of placed) {
                        consider(rect.x + rect.width + gap, rect.y)
                        consider(rect.x - item.width - gap, rect.y)
                        consider(rect.x, rect.y + rect.height + gap)
                        consider(rect.x, rect.y - item.height - gap)
                        consider(rect.x + rect.width + gap, rect.y + rect.height - item.height)
                        consider(rect.x + rect.width - item.width, rect.y + rect.height + gap)
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

                // ── Arranging (edit mode) ─────────────────────────────────────
                // The widgets an arranged one meets: on screen, neither the item itself nor the pages of its stack.
                // One still on a shelf (not loaded) meets every widget out.
                function arrangeNeighbours(instanceKey: string): var {
                    const widgets = widgetCanvas._loadedDesktopWidgets()
                    const current = widgets.find(item => item.editInstanceKey === instanceKey) ?? null
                    return widgets.filter(item => item !== current && item.width > 0 && item.height > 0
                        && item.opacity > 0.01
                        && !(current?.stacked && item.stacked && item.stack?.id === current?.stack?.id))
                        .map(item => ({ key: item.editInstanceKey, x: item.x, y: item.y, width: item.width,
                            height: item.height, locked: Boolean(item.locked), item: item }))
                }

                // Where a carried widget may rest: the spot asked for when nothing is under it, else the nearest free
                // one (beside a neighbour first). Nothing is left lying on top of another at rest.
                function freeSpot(instanceKey: string, x: real, y: real, width: real, height: real): var {
                    const placed = widgetCanvas.arrangeNeighbours(instanceKey)
                        .map(n => ({ id: n.key, x: n.x, y: n.y, w: n.width, h: n.height }))
                        .concat(DesktopArrange.bodiesOf(bgRoot.screenName))
                    const spot = ArrangeMath.settle({ id: instanceKey, x: x, y: y, w: width, h: height }, placed,
                        widgetCanvas.arrangeRoom, widgetCanvas.arrangeGap)
                    return { x: spot.x, y: spot.y, moved: spot.moved }
                }
                // The room widgets rest in, for DesktopArrange.
                readonly property var arrangeRoom: ({ w: widgetCanvas.width, h: widgetCanvas.height,
                    left: Number(bgRoot.desktopFreeWorkArea?.left ?? 0), top: Number(bgRoot.desktopFreeWorkArea?.top ?? 0),
                    right: Number(bgRoot.desktopFreeWorkArea?.right ?? widgetCanvas.width),
                    bottom: Number(bgRoot.desktopFreeWorkArea?.bottom ?? widgetCanvas.height) })
                onArrangeRoomChanged: DesktopArrange.setRoom(bgRoot.screenName, widgetCanvas.arrangeRoom)

                // A widget that grew (resized, a larger size class) moves the neighbours it now covers aside, each to
                // its nearest free spot. When one of them cannot move (locked, held by a zone), the grown one steps off.
                function makeRoom(instanceKey: string): void {
                    const grown = widgetCanvas.loadedWidget(instanceKey)
                    if (!grown)
                        return
                    const all = widgetCanvas.arrangeNeighbours(instanceKey)
                    const me = { x: grown.x, y: grown.y, width: grown.width, height: grown.height }
                    const covered = all.filter(n => widgetCanvas._rectOverlaps(me, n, 0))
                    if (covered.length === 0)
                        return
                    const moving = covered.filter(n => !n.locked && n.item.placementStrategy === "free")
                    if (moving.length < covered.length) {
                        const spot = widgetCanvas.freeSpot(instanceKey, me.x, me.y, me.width, me.height)
                        if (spot.moved)
                            grown._setOutputValues({ x: spot.x, y: spot.y, placementStrategy: "free" })
                        return
                    }
                    const settled = [me].concat(all.filter(n => moving.indexOf(n) < 0))
                    const cx = me.x + me.width / 2
                    const cy = me.y + me.height / 2
                    moving.sort((a, b) => Math.hypot(a.x + a.width / 2 - cx, a.y + a.height / 2 - cy)
                        - Math.hypot(b.x + b.width / 2 - cx, b.y + b.height / 2 - cy))
                    for (const n of moving) {
                        const spot = widgetCanvas._nearestFreePosition(n, n.x, n.y, settled, bgRoot.desktopItemsWorkArea)
                        settled.push({ x: spot.x, y: spot.y, width: n.width, height: n.height })
                        n.item._setOutputValues({ x: spot.x, y: spot.y })
                    }
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

                    // From here on a widget that appears is a newcomer (AbstractBackgroundWidget._settleNewcomer).
                    widgetCanvas.settled = true
                    const geometryChanged = !DesktopWidgetLayout.outputLayoutMatches(
                        outputName, outputWidth, outputHeight)
                    let missingGeometry = false
                    for (const item of widgets) {
                        const strategy = String(item.placementStrategy ?? "free")
                        if (DesktopWidgetStacks.isSplit(item.configEntryName)
                                || (strategy === "free"
                                && (!DesktopWidgetLayout.hasValue(outputName,
                                        item.configEntryName, "x")
                                    || !DesktopWidgetLayout.hasValue(outputName,
                                        item.configEntryName, "y")))) {
                            missingGeometry = true
                            break
                        }
                    }
                    if (!geometryChanged && !missingGeometry)
                        return

                    const previousGeometry = geometryChanged
                        ? DesktopWidgetLayout.outputGeometry(outputName) : null
                    const work = bgRoot.desktopItemsWorkArea
                    const ordered = widgets.slice().sort((a, b) => {
                        const aLocal = DesktopWidgetLayout.hasValue(
                            outputName, a.configEntryName, "x") ? 1 : 0
                        const bLocal = DesktopWidgetLayout.hasValue(
                            outputName, b.configEntryName, "x") ? 1 : 0
                        if (!geometryChanged && aLocal !== bLocal)
                            return bLocal - aLocal
                        // A widget that just left a stack is the one that moves aside.
                        const aSplit = DesktopWidgetStacks.isSplit(a.configEntryName)
                        if (aSplit !== DesktopWidgetStacks.isSplit(b.configEntryName))
                            return aSplit ? 1 : -1
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
                    const leaving = ({})
                    const remembered = ({})
                    const restored = ({})
                    for (const item of widgets) {
                        const spot = geometryChanged
                            ? DesktopWidgetLayout.rememberedPosition(
                                outputName, item.configEntryName, outputWidth, outputHeight) : null
                        remembered[item.configEntryName] = spot
                        if (spot?.x !== undefined) {
                            // Kept where it was arranged on this size, held only by the output's edges: the
                            // work area can be narrower than where it was placed (over the Dock's band), and
                            // clamping to it moved a widget on the way back.
                            restored[item.configEntryName] = {
                                x: Math.round(Math.max(0, Math.min(Math.max(0, outputWidth - item.width), spot.x))),
                                y: Math.round(Math.max(0, Math.min(Math.max(0, outputHeight - item.height), spot.y)))
                            }
                            placed.push({ x: restored[item.configEntryName].x,
                                y: restored[item.configEntryName].y, width: item.width, height: item.height })
                        }
                    }
                    for (const item of widgets) {
                        const was = String(item.placementStrategy ?? "free")
                        leaving[item.configEntryName] = { placementStrategy: was }
                        if (was === "free") {
                            leaving[item.configEntryName].x = Number(DesktopWidgetLayout.value(
                                outputName, item.configEntryName, "x", item.x))
                            leaving[item.configEntryName].y = Number(DesktopWidgetLayout.value(
                                outputName, item.configEntryName, "y", item.y))
                        }
                    }

                    for (const item of ordered) {
                        const strategy = String(item.placementStrategy ?? "free")
                        const maxX = Math.max(left, right - item.width)
                        const maxY = Math.max(top, bottom - item.height)
                        const localX = DesktopWidgetLayout.hasValue(
                            outputName, item.configEntryName, "x")
                        const localY = DesktopWidgetLayout.hasValue(
                            outputName, item.configEntryName, "y")
                        const spot = remembered[item.configEntryName]
                        const target = spot?.placementStrategy ?? strategy
                        if (target !== "free" && target !== strategy) {
                            updates[item.configEntryName] = { placementStrategy: target }
                            placed.push({ x: item.x, y: item.y, width: item.width, height: item.height })
                            continue
                        }
                        // Same screen: a widget with its own place keeps it and only the new one finds room. Placing
                        // everyone again moved the whole desktop each time one was added (10-23).
                        if (!geometryChanged && strategy === "free" && localX && localY
                                && !DesktopWidgetStacks.isSplit(item.configEntryName)) {
                            placed.push({ x: item.x, y: item.y, width: item.width, height: item.height })
                            continue
                        }
                        let wantX = Number(item.x) || 0
                        let wantY = Number(item.y) || 0
                        if (geometryChanged && target === "free" && localX && localY) {
                            const storedX = Number(DesktopWidgetLayout.value(
                                outputName, item.configEntryName, "x", wantX))
                            const storedY = Number(DesktopWidgetLayout.value(
                                outputName, item.configEntryName, "y", wantY))
                            if (spot?.x !== undefined) {
                                wantX = spot.x
                                wantY = spot.y
                            } else if (previousGeometry && Number.isFinite(storedX)
                                    && Number.isFinite(storedY)) {
                                wantX = (storedX + item.width / 2) / previousGeometry.width
                                    * outputWidth - item.width / 2
                                wantY = (storedY + item.height / 2) / previousGeometry.height
                                    * outputHeight - item.height / 2
                            }
                        }
                        const desiredX = Math.max(left, Math.min(maxX, wantX))
                        const desiredY = Math.max(top, Math.min(maxY, wantY))
                        const needsLocal = target === "free"
                            && (geometryChanged || !localX || !localY)
                        let position = restored[item.configEntryName]
                            ?? { x: Math.round(desiredX), y: Math.round(desiredY) }
                        const collides = !restored[item.configEntryName] && !widgetCanvas._positionIsFree(
                            position.x, position.y, item.width, item.height, placed, 14)
                        if (collides && (!item.locked || DesktopWidgetStacks.isSplit(item.configEntryName)))
                            position = widgetCanvas._nearestFreePosition(
                                item, desiredX, desiredY, placed, work)

                        const moved = Math.round(position.x) !== Math.round(item.x)
                            || Math.round(position.y) !== Math.round(item.y)
                        if (needsLocal || moved || (collides && (!item.locked || DesktopWidgetStacks.isSplit(item.configEntryName)))) {
                            updates[item.configEntryName] = {
                                x: position.x,
                                y: position.y,
                                placementStrategy: "free"
                            }
                        }
                        if (!restored[item.configEntryName])
                            placed.push({
                                x: position.x,
                                y: position.y,
                                width: item.width,
                                height: item.height
                            })
                    }

                    widgetCanvas._outputLayoutAttempts = 0
                    DesktopWidgetLayout.initializeOutputLayout(
                        outputName, outputWidth, outputHeight, updates, geometryChanged ? leaving : null)
                    DesktopWidgetStacks.clearSplits()
                }

                property int _outputLayoutAttempts: 0
                property bool settled: false

                Timer {
                    id: outputLayoutTimer
                    interval: DesktopWidgetStacks.splitPending ? 250 : 1400
                    repeat: false
                    onTriggered: widgetCanvas.initializeOutputWidgetLayout()
                }

                Component.onCompleted: {
                    backgroundScope.widgetCanvases[bgRoot.screenName] = widgetCanvas
                    DesktopArrange.setRoom(bgRoot.screenName, widgetCanvas.arrangeRoom)
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
                    // The pages of one stack are one layer, not several piled up.
                    const matches = widgets.filter(item => item.width > 0 && item.height > 0
                        && (item === current || !current.stacked || item.stack?.id !== current.stack.id)
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

                function promoteDesktopWidget(instanceKey: string, layerKey: string): string {
                    const key = String(instanceKey ?? "")
                    if (!key)
                        return ""
                    backgroundScope.promoteDesktopWidgetKey(String(layerKey ?? "") || key)
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

                // Where the shell's own bodies rest (the frame, the Island, the Dock, a bar), drawn by the family under
                // the widgets while arranging: the card is the screen as it will be, and they stay clear of them.
                Loader {
                    anchors.fill: parent
                    z: -1
                    active: GlobalStates.widgetEditMode && bgRoot.editStagePart.length > 0
                    source: bgRoot.editStagePart
                    onLoaded: {
                        item.side = "inside"
                        item.output = bgRoot.screenName
                        item.card = Qt.binding(() => bgRoot.editCard)
                        item.room = Qt.binding(() => widgetCanvas.arrangeRoom)
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

                // Arranging, drawn over every widget in the card's space (DesktopArrange): the grid while a widget is
                // carried, the lines it meets (light while it moves, named once let go), the four sides of the drop
                // running across the screen, a flare on every widget it lined up with, and where a widget pulled off
                // a family's shelf will land.
                Loader {
                    id: arrangeLayer
                    anchors.fill: parent
                    z: 15001
                    active: GlobalStates.widgetEditMode
                    sourceComponent: Item {
                        id: guides
                        readonly property bool here: DesktopArrange.dragOutput === bgRoot.screenName && DesktopArrange.phase !== "idle"
                        readonly property var carry: DesktopEditStage.carry?.output === bgRoot.screenName ? DesktopEditStage.carry : null
                        readonly property bool iris: (Config.options?.panelFamily ?? "ii") === "iris"
                        readonly property color ink: guides.iris ? FamilyStyle.accent : Appearance.colors.colPrimary
                        readonly property color paper: guides.iris ? FamilyStyle.raised : Appearance.colors.colPrimaryContainer
                        readonly property color paperInk: guides.iris ? FamilyStyle.text : Appearance.colors.colOnPrimaryContainer
                        // One screen pixel, and type at its true size, while the desktop is a card.
                        readonly property real hair: 1 / Math.max(0.2, bgRoot.editCard.s)
                        readonly property real radius: guides.iris
                            ? Math.round(Math.max(0, Math.min(40, Config.options?.iris?.widgets?.radius ?? 22)) * FamilyStyle.density)
                            : Appearance.rounding.small
                        readonly property real strength: !guides.here ? 0 : DesktopArrange.phase === "drag" ? 0.6
                            : DesktopArrange.phase === "confirm" ? 1 : 0
                        readonly property bool moving: (guides.here && DesktopArrange.phase === "drag") || guides.carry !== null
                        readonly property var room: DesktopArrange.rooms[bgRoot.screenName] ?? widgetCanvas.arrangeRoom
                        // Only names that say more than the line: a body (Island, Dock), the screen's centre or edge. "Left",
                        // "Top" or "Centre" over a neighbour's edge sat on the chosen widget's keys row and said nothing new.
                        function word(line: var): string {
                            const body = (line?.ids ?? []).find(id => String(id).startsWith("@"))
                            if (body && line?.kind !== "gutter")
                                return DesktopArrange.bodiesOf(bgRoot.screenName).find(b => b.id === body)?.name ?? ""
                            switch (line?.kind) {
                            case "room": return Translation.tr("Edge")
                            case "screen": return Translation.tr("Screen centre")
                            }
                            return ""
                        }

                        // The lattice a carried widget is pulled onto: a dot on each crossing, painted once per size.
                        Canvas {
                            id: lattice
                            anchors.fill: parent
                            readonly property int cell: DesktopArrange.grid
                            readonly property string look: lattice.cell + ":" + guides.room.left + ":" + guides.room.top + ":" + guides.ink + ":" + guides.hair
                            visible: lattice.opacity > 0.01 && lattice.cell > 0
                            opacity: guides.moving ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            onLookChanged: if (lattice.visible) lattice.requestPaint()
                            onVisibleChanged: if (lattice.visible) lattice.requestPaint()
                            onPaint: {
                                const ctx = lattice.getContext("2d")
                                ctx.clearRect(0, 0, lattice.width, lattice.height)
                                if (lattice.cell <= 0)
                                    return
                                ctx.fillStyle = Qt.rgba(guides.ink.r, guides.ink.g, guides.ink.b, 0.32)
                                const r = 1.1 * guides.hair
                                for (let y = guides.room.top; y <= guides.room.bottom + 0.5; y += lattice.cell)
                                    for (let x = guides.room.left; x <= guides.room.right + 0.5; x += lattice.cell)
                                        ctx.fillRect(x - r, y - r, 2 * r, 2 * r)
                            }
                        }

                        // Where a widget pulled off the shelf lands.
                        Rectangle {
                            visible: guides.carry !== null
                            x: guides.carry?.plan?.x ?? 0
                            y: guides.carry?.plan?.y ?? 0
                            width: guides.carry?.width ?? 0
                            height: guides.carry?.height ?? 0
                            radius: guides.radius
                            color: guides.iris ? FamilyStyle.tintFill(FamilyStyle.accent) : CF.ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.08)
                            border.width: guides.hair
                            border.color: guides.ink
                            Behavior on x { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                            Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
                        }

                        // The lines, in fixed slots: a line that stays keeps its slot, a new one draws on from its middle.
                        Repeater {
                            model: DesktopArrange.slotCount
                            delegate: Item {
                                id: guide
                                required property int index
                                anchors.fill: parent
                                readonly property var now: DesktopArrange.slots[guide.index] ?? null
                                property var line: null
                                property real drawn: 0
                                onNowChanged: {
                                    if (!guide.now)
                                        return
                                    const fresh = !guide.line || guide.line.key !== guide.now.key || guide.opacity < 0.05
                                    guide.line = guide.now
                                    if (fresh) drawOn.restart()
                                }
                                NumberAnimation { id: drawOn; target: guide; property: "drawn"; from: 0; to: 1; duration: 170; easing.type: Easing.OutCubic }
                                opacity: guide.now !== null ? guides.strength : 0
                                visible: guide.opacity > 0.01 && guide.line !== null
                                Behavior on opacity { NumberAnimation { duration: DesktopArrange.phase === "fade" ? DesktopArrange.fadeMs : 120; easing.type: Easing.OutCubic } }
                                readonly property bool vertical: guide.line?.vertical ?? true
                                readonly property real mid: guide.line ? ((guide.line?.from ?? 0) + guide.line.to) / 2 : 0
                                readonly property real half: guide.line ? (guide.line.to - (guide.line?.from ?? 0)) / 2 * guide.drawn : 0
                                readonly property real thick: (DesktopArrange.phase === "drag" ? 1 : 1.5) * guides.hair
                                Rectangle {
                                    x: guide.vertical ? (guide.line?.at ?? 0) - guide.thick / 2 : guide.mid - guide.half
                                    y: guide.vertical ? guide.mid - guide.half : (guide.line?.at ?? 0) - guide.thick / 2
                                    width: guide.vertical ? guide.thick : 2 * guide.half
                                    height: guide.vertical ? 2 * guide.half : guide.thick
                                    color: guides.ink
                                    opacity: guide.line?.kind === "flush" ? 0.75 : 1
                                }
                                // Its name, once let go, past the line's start (inside the card for a line that runs all of it).
                                Rectangle {
                                    id: name
                                    readonly property string text: guides.word(guide.line)
                                    visible: DesktopArrange.phase !== "drag" && name.text.length > 0
                                    width: nameText.implicitWidth + 14 * guides.hair
                                    height: nameText.implicitHeight + 6 * guides.hair
                                    radius: guides.iris ? height / 2 : Appearance.rounding.full
                                    color: guides.paper
                                    border.width: guides.hair
                                    border.color: guides.ink
                                    readonly property real lead: 6 * guides.hair
                                    // At the end of the line away from the widget let go, so it never sits on its keys.
                                    readonly property real start: guide.line?.from ?? 0
                                    readonly property real end: guide.line?.to ?? 0
                                    readonly property var drop: DesktopArrange.dropRect
                                    readonly property real dropMid: !name.drop ? name.start
                                        : guide.vertical ? name.drop.y + name.drop.h / 2 : name.drop.x + name.drop.w / 2
                                    readonly property bool atEnd: Math.abs(name.dropMid - name.start) < Math.abs(name.dropMid - name.end)
                                    readonly property real along: guide.vertical ? name.height : name.width
                                    readonly property real place: name.atEnd
                                        ? (name.end + name.lead + name.along <= (guide.vertical ? parent.height : parent.width) ? name.end + name.lead : name.end - name.lead - name.along)
                                        : (name.start - name.lead - name.along >= 0 ? name.start - name.lead - name.along : name.start + name.lead)
                                    x: Math.max(0, Math.min(parent.width - width, guide.vertical ? (guide.line?.at ?? 0) - width / 2 : name.place))
                                    y: Math.max(0, Math.min(parent.height - height, guide.vertical ? name.place : (guide.line?.at ?? 0) - height / 2))
                                    scale: visible ? 1 : 0.9
                                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                    StyledText {
                                        id: nameText
                                        anchors.centerIn: parent
                                        text: name.text
                                        color: guides.paperInk
                                        font.family: guides.iris ? FamilyStyle.fontMain : Appearance.font.family.main
                                        font.pixelSize: (guides.iris ? FamilyStyle.typeFootnote : Appearance.font.pixelSize.smaller) * guides.hair
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }
                        }

                        // Let go: the four sides of the drop run across the screen, and the widgets it met flare.
                        property real rail: 0
                        property real flare: 1
                        property var flareRects: []
                        readonly property int serial: DesktopArrange.confirmSerial
                        onSerialChanged: {
                            if (DesktopArrange.dragOutput !== bgRoot.screenName || !DesktopArrange.dropRect || !Appearance.animationsEnabled)
                                return
                            guides.flareRects = Object.keys(DesktopArrange.matched)
                                .map(key => DesktopArrange.rectOf(bgRoot.screenName, key)).filter(r => r !== null)
                            railRun.restart()
                            flareRun.restart()
                        }
                        SequentialAnimation {
                            id: railRun
                            NumberAnimation { target: guides; property: "rail"; from: 0; to: 1; duration: 240; easing.type: Easing.OutCubic }
                            PauseAnimation { duration: 140 }
                            NumberAnimation { target: guides; property: "rail"; to: 2; duration: 220; easing.type: Easing.InCubic }
                        }
                        NumberAnimation { id: flareRun; target: guides; property: "flare"; from: 0; to: 1; duration: 620; easing.type: Easing.OutCubic }
                        Connections {
                            target: DesktopArrange
                            function onPinged(output: string, key: string): void {
                                const r = output === bgRoot.screenName ? DesktopArrange.rectOf(output, key) : null
                                if (!r || !Appearance.animationsEnabled)
                                    return
                                guides.flareRects = [r]
                                flareRun.restart()
                            }
                        }
                        Repeater {
                            model: guides.rail > 0 && guides.rail < 2 ? 4 : 0
                            delegate: Rectangle {
                                required property int index
                                readonly property var r: DesktopArrange.dropRect ?? ({ x: 0, y: 0, w: 0, h: 0 })
                                readonly property bool vertical: index < 2
                                readonly property real at: index === 0 ? r.x : index === 1 ? r.x + r.w : index === 2 ? r.y : r.y + r.h
                                readonly property real from: vertical ? r.y : r.x
                                readonly property real to: vertical ? r.y + r.h : r.x + r.w
                                readonly property real span: vertical ? guides.height : guides.width
                                readonly property real run: Math.min(1, guides.rail)
                                readonly property real head: from * (1 - run)
                                readonly property real tail: to + (span - to) * run
                                x: vertical ? at - guides.hair / 2 : head
                                y: vertical ? head : at - guides.hair / 2
                                width: vertical ? guides.hair : tail - head
                                height: vertical ? tail - head : guides.hair
                                color: guides.ink
                                opacity: 0.7 * (guides.rail <= 1 ? 1 : 2 - guides.rail)
                            }
                        }
                        Repeater {
                            model: guides.flare < 1 ? guides.flareRects : []
                            delegate: Rectangle {
                                required property var modelData
                                readonly property real grow: (2 + 8 * guides.flare) * guides.hair
                                x: modelData.x - grow
                                y: modelData.y - grow
                                width: modelData.w + 2 * grow
                                height: modelData.h + 2 * grow
                                radius: guides.radius + grow
                                color: "transparent"
                                border.width: 1.5 * guides.hair
                                border.color: guides.ink
                                opacity: 0.9 * (1 - guides.flare)
                            }
                        }
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetShown("weather")
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
                    shown: bgRoot._widgetShown("customImage")
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
                    shown: bgRoot._widgetShown("imageConverter")
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
                    shown: bgRoot._widgetShown("clock")
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
                    shown: bgRoot._widgetShown("mediaControls")
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
                    shown: bgRoot._widgetShown("visualizer")
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
                    shown: bgRoot._widgetShown("systemMonitor")
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
                    shown: bgRoot._widgetShown("battery")
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
                    shown: bgRoot._widgetShown("notes")
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
                    shown: bgRoot._widgetShown("calendarUpcoming")
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
                    shown: bgRoot._widgetShown("monthCalendar")
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
                    shown: bgRoot._widgetShown("todo")
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
                    shown: bgRoot._widgetShown("timers")
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
                    shown: bgRoot._widgetShown("dayProgress")
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
                    shown: bgRoot._widgetShown("uptime")
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
                    shown: bgRoot._widgetShown("controls") && (Config.options?.panelFamily ?? "ii") === "iris"
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
                    shown: bgRoot._widgetShown("screenTime") && (Config.options?.panelFamily ?? "ii") === "iris"
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
                    shown: bgRoot._widgetShown("palette") && (Config.options?.panelFamily ?? "ii") === "iris"
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMaskPalette : null
                    WidgetInputMask { id: _hitMaskPalette; loader: parent }
                    sourceComponent: PaletteWidget {
                        widgetIndex: 40
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetShown("lyrics") && (Config.options?.panelFamily ?? "ii") === "iris"
                    z: item?.desktopStackZ ?? 0
                    containmentMask: GlobalStates.widgetEditMode ? _hitMaskLyrics : null
                    WidgetInputMask { id: _hitMaskLyrics; loader: parent }
                    sourceComponent: LyricsWidget {
                        widgetIndex: 40
                        outputName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot._widgetShown("editorial")
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
                    shown: bgRoot._widgetShown("shape")
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
                    shown: bgRoot._widgetShown("dateBadge")
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
                    shown: bgRoot._widgetShown("worldClock")
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
                    shown: bgRoot._widgetShown("userCard")
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
                    shown: bgRoot._widgetShown("newsTicker")
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
                    shown: bgRoot._widgetShown("mascot")
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
                    shown: bgRoot._widgetShown("japaneseTypography")
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
                            setSource(Quickshell.shellPath("modules/shared/background/widgets/mascot/MascotWidget.qml"), {
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
        Loader {
            id: editOverLoader
            anchors.fill: parent
            active: bgRoot.editCard.p > 0 && bgRoot.editStagePart.length > 0
            source: bgRoot.editStagePart
            onLoaded: { item.side = "over"; item.card = Qt.binding(() => bgRoot.editCard) }
        }
    }
    }
}
