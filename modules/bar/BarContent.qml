import qs.modules.bar.weather
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.pill
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE

Item { // Bar content region
    id: root

    // Shell desaturation effect
    layer.enabled: Appearance.shouldDesaturate("bar") && root.visible
    layer.effect: ShellDesaturationEffect {}

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
    property alias backgroundItem: barBackground
    property bool nativeBlurAllowed: true

    // Mascot chaos: her ground slam rattles the bar; a direct kick more so
    property real _quakeY: 0
    property real _quakeScale: 1
    transform: Translate { y: root._quakeY }
    SequentialAnimation {
        id: _quakeAnim
        NumberAnimation { target: root; property: "_quakeY"; to: 7 * root._quakeScale; duration: 60; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "_quakeY"; to: -5 * root._quakeScale; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "_quakeY"; to: 3 * root._quakeScale; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "_quakeY"; to: 0; duration: 90; easing.type: Easing.OutBack }
    }
    Connections {
        target: MascotChaos
        enabled: MascotChaos.enabled
        function onPanelShake(intensity) {
            root._quakeScale = Math.max(1, intensity)
            if (Appearance.animationsEnabled) _quakeAnim.restart()
        }
    }

    // Right-click context menu anchor (invisible, positioned at click)
    Item {
        id: barContextMenuAnchor
        width: 1
        height: 1
    }

    function openBarContextMenu(clickX, clickY, mouseArea) {
        // Position anchor at bar edge for correct popup positioning
        // For bar top: anchor at bottom edge (y = height), popup appears below
        // For bar bottom: anchor at top edge (y = 0), popupAbove makes it appear above
        const mapped = mouseArea.mapToItem(root, clickX, clickY)
        barContextMenuAnchor.x = mapped.x
        barContextMenuAnchor.y = (Config.options?.bar?.bottom ?? false) ? 0 : root.height
        barContextMenu.requestOpen()
    }

    ContextMenu {
        id: barContextMenu
        anchorItem: barContextMenuAnchor
        popupAbove: Config.options?.bar?.bottom ?? false
        closeOnFocusLost: true
        closeOnHoverLost: true

        model: [
            {
                iconName: "browse_activity",
                monochromeIcon: true,
                text: Translation.tr("Mission Center"),
                action: () => {
                    Session.launchTaskManager()
                },
            },
            { type: "separator" },
            {
                iconName: "settings",
                monochromeIcon: true,
                text: Translation.tr("Settings"),
                action: () => {
                    Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings"])
                },
            },
        ]
    }
    readonly property bool taskbarEnabled: Config.options?.bar?.modules?.taskbar ?? false

    function _moduleBudget(id, level) {
        if (level >= 1 && (id === "activeWindow" || id === "tray" || id === "utilButtons")) return 0
        if (level >= 2 && (id === "media" || id === "battery")) return 0
        const scale = Appearance.fontSizeScale
        const widths = {
            "leftSidebarButton": 44, "rightSidebarButton": 44,
            "activeWindow": 260, "resources": 185, "media": 190,
            "workspaces": 115, "clock": 135, "utilButtons": 150,
            "battery": 80, "tray": 180, "timer": 44,
            "shellUpdate": 44, "weather": 125,
            "spacer": Math.max(24, root._spacerMinimumWidth),
        }
        return (widths[id] ?? 64) * scale
    }
    function _zoneBudget(ids, level) {
        let total = 0
        for (let i = 0; i < ids.length; ++i)
            total += root._moduleBudget(ids[i], level)
        return total
    }
    function _layoutBudget(level) {
        const left = root._zoneBudget(root._leftIds, level) + root._zoneBudget(root._centerLeftIds, level)
        const right = root._zoneBudget(root._rightIds, level) + root._zoneBudget(root._centerRightIds, level)
        const center = root._zoneBudget(root._centerIds, level)
        return center + Math.max(left, right) * 2 + root.hostGap * 4
    }
    readonly property real regularLayoutBudget: Math.max(
        Appearance.sizes.barShortenScreenWidthThreshold, root._layoutBudget(0))
    readonly property real compactLayoutBudget: Math.max(
        Appearance.sizes.barHellaShortenScreenWidthThreshold, root._layoutBudget(1))
    property real useShortenedForm: {
        const width = screen?.width ?? 1920
        if (width < root.compactLayoutBudget) return 2
        if (width < root.regularLayoutBudget) return 1
        return 0
    }
    readonly property int baseCenterSideModuleWidth: (useShortenedForm == 2) ? Appearance.sizes.barCenterSideModuleWidthHellaShortened : (useShortenedForm == 1) ? Appearance.sizes.barCenterSideModuleWidthShortened : Appearance.sizes.barCenterSideModuleWidth
    // Five independently content-sized zones can exceed the physical output even
    // when every individual module is valid. Once their symmetric natural demand
    // no longer fits, compress each host by the same factor instead of letting
    // neighbouring hosts paint through each other. The normal case stays fully
    // natural-sized; clipping is only the final safety net for impossible layouts.
    readonly property real hostGap: root.isIslands ? 8 : 4
    readonly property real leftEdgeDemand: Math.max(0, leftSectionRowLayout.implicitWidth)
        + (root.isIslands
            ? root.islandOuterInset + root.islandPad * 2
            : Appearance.rounding.screenRounding * 2)
    readonly property real rightEdgeDemand: Math.max(0, rightSectionRowLayout.implicitWidth)
        + (root.isIslands
            ? root.islandOuterInset + root.islandPad * 2
            : Appearance.rounding.screenRounding * 2)
    readonly property real leftCenterDemand: leftCenterGroup.empty ? 0 : leftCenterGroup.contentWidth
    readonly property real rightCenterDemand: rightCenterGroupPill.empty ? 0 : rightCenterGroupPill.contentWidth
    readonly property real centerDemand: middleCenterGroup.empty ? 0 : middleCenterGroup.contentWidth
    readonly property real leftSideDemand: root.leftEdgeDemand + root.leftCenterDemand
        + ((root.leftEdgeDemand > 0 && root.leftCenterDemand > 0) ? root.hostGap : 0)
    readonly property real rightSideDemand: root.rightEdgeDemand + root.rightCenterDemand
        + ((root.rightEdgeDemand > 0 && root.rightCenterDemand > 0) ? root.hostGap : 0)
    readonly property real symmetricSideDemand: Math.max(root.leftSideDemand, root.rightSideDemand)
    readonly property real centerBoundaryGap: (root.centerDemand > 0 && root.symmetricSideDemand > 0)
        ? root.hostGap : 0
    readonly property real naturalHostDemand: root.centerDemand
        + root.symmetricSideDemand * 2 + root.centerBoundaryGap * 2
    readonly property real hostScale: root.naturalHostDemand > 0 && root.width > 0
        ? Math.min(1, root.width / root.naturalHostDemand) : 1
    readonly property bool layoutCompressionActive: root.hostScale < 0.999
    readonly property real compressedLeftEdgeWidth: root.leftEdgeDemand * root.hostScale
    readonly property real compressedRightEdgeWidth: root.rightEdgeDemand * root.hostScale
    readonly property real compressedLeftCenterWidth: root.leftCenterDemand * root.hostScale
    readonly property real compressedRightCenterWidth: root.rightCenterDemand * root.hostScale
    readonly property real compressedCenterWidth: root.centerDemand * root.hostScale
    // Max width a side pill may take before it would collide with an edge
    // section. Pure outer geometry (screen width, edge sections, workspaces) so
    // there is no binding loop with the pills' own content width. A pill takes
    // its NATURAL content width, clamped to this — its modules elide/clip to fit
    // instead of inflating the pill or pushing into the edges.
    readonly property real centerSideMaxWidth: {
        const total = root.width
        if (!(total > 0)) return root.baseCenterSideModuleWidth
        const edge = Math.max(barLeftSideMouseArea.implicitWidth, barRightSideMouseArea.implicitWidth)
        const wsHalf = middleCenterGroup.width / 2
        return Math.max(0, total / 2 - edge - wsHalf - 12)
    }
    // Both centre pills share one width = the larger of the two non-empty
    // content widths (clamped to centerSideMaxWidth). This keeps the cluster
    // balanced around the workspaces pivot; each BarGroup centres its content,
    // so the narrower side doesn't look stuck to one edge. An empty zone
    // contributes 0 and collapses entirely.
    readonly property real centerPillMirrorSlack: 56 * Appearance.fontSizeScale
    function _pillWidth(cw) {
        const lw = leftCenterGroup.empty ? 0 : leftCenterGroup.contentWidth
        const rw = rightCenterGroupPill.empty ? 0 : rightCenterGroupPill.contentWidth
        const raw = Math.max(lw, rw)
        if (raw <= 0) return 0
        const own = Math.max(0, cw)
        const mirrored = own > 0 ? Math.min(raw, own + root.centerPillMirrorSlack) : raw
        return Math.min(mirrored, root.centerSideMaxWidth)
    }
    readonly property bool cardStyleEverywhere: (Config.options?.dock?.cardStyle ?? false) && (Config.options?.sidebar?.cardStyle ?? false) && (Config.options?.bar?.cornerStyle === 3)
    readonly property bool zzzEverywhere: root.surfaceDialect === "zzz"
    readonly property color separatorColor: root.zzzEverywhere ? Appearance.zzz.hairlineStrong : Appearance.colors.colOutlineVariant

    // Per-monitor wallpaper URL for Aurora blur — uses the actual wallpaper on this screen
    readonly property string wallpaperUrl: {
        const _dep1 = WallpaperListener.multiMonitorEnabled
        const _dep2 = WallpaperListener.effectivePerMonitor
        const _dep3 = Wallpapers.effectiveWallpaperUrl
        return WallpaperListener.wallpaperUrlForScreen(root.screen)
    }

    readonly property bool _useGlobalQuantizer: root.wallpaperUrl === Wallpapers.effectiveWallpaperUrl
    ColorQuantizer {
        id: wallpaperColorQuantizer
        source: root.auroraEverywhere
            ? (root._useGlobalQuantizer ? "" : root.wallpaperUrl)
            : ""
        depth: 0 // 2^0 = 1 color
        rescaleSize: 10
    }

    readonly property color wallpaperDominantColor: root._useGlobalQuantizer
        ? Appearance.wallpaperDominantColor
        : (wallpaperColorQuantizer?.colors?.[0] ?? Appearance.colors.colPrimary)
    AdaptedMaterialScheme {
        id: _localBlendedColors
        color: ColorUtils.mix(root.wallpaperDominantColor, Appearance.colors.colPrimaryContainer, 0.8) || Appearance.colors.colSecondaryContainer
    }
    readonly property QtObject blendedColors: root._useGlobalQuantizer
        ? Appearance.wallpaperBlendedColors : _localBlendedColors

    readonly property bool inirEverywhere: root.surfaceDialect === "inir"
    readonly property bool angelEverywhere: root.surfaceDialect === "angel"
    readonly property bool regaliaEverywhere: root.surfaceDialect === "regalia"
    readonly property bool auroraEverywhere: root.surfaceDialect === "aurora" || root.angelEverywhere
    // Bar appearance style: how the bar surface itself is drawn.
    //   classic — single full-width background (per cornerStyle, current default)
    //   islands — no bar surface; every section floats as its own island
    //   scenic  — gradient scrim fading into the wallpaper, content on top
    //   frame   — outlined floating frame, transparent inside
    readonly property string barAppearance: Config.options?.bar?.appearanceStyle ?? "classic"
    readonly property string surfaceDialect: Appearance.surfaceDialectFor(
        root.barAppearance === "islands" ? "island" : "")
    readonly property bool isIslands: root.surfaceDialect === "island"
    // Island geometry knobs (bar.islands.*): vertical breathing room and the
    // horizontal capsule padding the edge islands wrap their content with.
    readonly property int islandInset: Config.options?.bar?.islands?.inset ?? 4
    readonly property int islandPad: Config.options?.bar?.islands?.padding ?? 12
    readonly property real islandShadowAllowance: root.isIslands
        && Appearance.effectsEnabled
        && (Config.options?.appearance?.island?.shadow ?? true)
        ? Appearance.sizes.elevationMargin : 0
    readonly property real islandOuterInset: root.isIslands
        ? Math.max(Appearance.sizes.hyprlandGapsOut, root.islandShadowAllowance)
        : Appearance.sizes.hyprlandGapsOut
    readonly property bool isScenic: root.barAppearance === "scenic"
    readonly property bool isFrame: root.barAppearance === "frame"
    // Name the exact Region topology published by Bar.qml. A five-card islands
    // union is exact, but `auto` still keeps its style-owned wallpaper material;
    // an explicit compositor request may use the proven union.
    readonly property string nativeBlurTopology: root.isIslands
        ? Appearance.blurTopology.islandsUnion
        : root.barAppearance === "classic"
            && (Config.options?.bar?.cornerStyle ?? 0) !== 0
            && (!root.zzzEverywhere || Appearance.zzz.round)
            ? Appearance.blurTopology.roundedRectangle
            : Appearance.blurTopology.unsupported
    readonly property bool nativeBlurGeometryExact: Appearance.blurTopologyExact(root.nativeBlurTopology)
    readonly property bool nativeBlurActive: Appearance.useCompositorBlur(
            root.isIslands ? "islands" : "bar", root.nativeBlurTopology)
        && root.nativeBlurAllowed
        && (Config.options?.bar?.showBackground ?? true)
        && !root.gameModeMinimal
    readonly property Item nativeBlurLeftIsland: leftEdgeIsland
    readonly property Item nativeBlurCenterIsland: middleCenterGroup.islandSurface
    readonly property Item nativeBlurCenterLeftIsland: leftCenterGroup.islandSurface
    readonly property Item nativeBlurCenterRightIsland: rightCenterGroupPill.islandSurface
    readonly property Item nativeBlurRightIsland: rightEdgeIsland
    readonly property bool zzzDetachedRounded: root.zzzEverywhere
        && Appearance.zzz.round
        && root.barAppearance === "classic"
        && (Config.options?.bar?.showBackground ?? true)
        && (((Config.options?.bar?.cornerStyle ?? 0) === 1) || ((Config.options?.bar?.cornerStyle ?? 0) === 3))
    readonly property string leftAction: Config.options?.bar?.leftScrollAction ?? "brightness"
    readonly property string rightAction: Config.options?.bar?.rightScrollAction ?? "volume"
    readonly property bool barSpectrumAudioPlaying: MprisController.isPlaying || YtMusic.isPlaying
    readonly property bool barSpectrumOutputEnabled:
        (Config.options?.bar?.visualizer?.multiMonitorMode ?? "primary") === "all"
        || Quickshell.screens.length <= 1
        || String(root.screen?.name ?? "") === String(GlobalStates.primaryScreen?.name ?? "")
    readonly property bool barSpectrumConfigured: (Config.options?.bar?.visualizer?.enable ?? false)
        && (root.isIslands || (Config.options?.bar?.showBackground ?? true))
        && root.barSpectrumOutputEnabled
        && !Appearance.gameModeMinimal
        && root.visible
    readonly property bool barSpectrumProcessWanted: root.barSpectrumConfigured
        && root.barSpectrumAudioPlaying
    readonly property bool barSpectrumVisible: root.barSpectrumConfigured
        && barCavaProcess.audioSignalActive
    readonly property real barSpectrumFillRatio: Math.max(0.1,
        Math.min(1, Config.options?.bar?.visualizer?.height ?? 0.6))
    readonly property real barSpectrumOpacity: Math.max(0,
        Math.min(1, Config.options?.bar?.visualizer?.opacity ?? 0.35))
    readonly property string barSpectrumType: Config.options?.bar?.visualizer?.type ?? "bars"
    readonly property string barSpectrumBarsOrigin: Config.options?.bar?.visualizer?.barsOrigin ?? "bottom"
    readonly property real barSpectrumDensity: Math.max(4, Config.options?.bar?.visualizer?.density ?? 12)
    readonly property real barSpectrumGap: Math.max(0, Config.options?.bar?.visualizer?.gap ?? 2)
    readonly property int barSpectrumSmoothing: Math.max(0, Config.options?.bar?.visualizer?.smoothing ?? 2)
    readonly property string barSpectrumWaveMode: Config.options?.bar?.visualizer?.waveMode ?? "fill"
    readonly property real barSpectrumLineWidth: Math.max(1, Config.options?.bar?.visualizer?.lineWidth ?? 2)
    readonly property real barSpectrumEdgeInset: Math.max(0, Config.options?.bar?.visualizer?.edgeInset ?? 0)
    readonly property real barSpectrumEdgeSoftness: Math.max(0,
        Math.min(1, (Config.options?.bar?.visualizer?.edgeSoftness ?? 28) / 100))
    readonly property string barSpectrumFrequencyProfile: Config.options?.bar?.visualizer?.frequencyProfile ?? "flat"
    readonly property real barSpectrumAccentStrength: Math.max(0,
        Math.min(1, (Config.options?.bar?.visualizer?.accentStrength ?? 70) / 100))
    readonly property color barSpectrumColor: root.inirEverywhere ? Appearance.inir.colPrimary
        : root.zzzEverywhere ? Appearance.zzz.accent
        : root.regaliaEverywhere ? Appearance.regalia.hardwarePrimary
        : (root.blendedColors?.colPrimary ?? Appearance.colors.colPrimary)

    CavaProcess {
        id: barCavaProcess
        active: root.barSpectrumProcessWanted
        sampleCount: Math.max(50, Math.round(Math.max(1, root.width) / root.barSpectrumDensity))
    }

    function performScrollAction(action: string, isUp: bool): void {
        if (action === "brightness") {
            const step = 0.05;
            root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness + (isUp ? step : -step));
        } else if (action === "volume") {
            if (isUp) Audio.incrementVolume();
            else Audio.decrementVolume();
        } else if (action === "workspace") {
            let up = isUp;
            if (Config.options?.bar?.workspaces?.invertScroll ?? false) up = !up;

            if (CompositorService.isNiri) {
                if (up) NiriService.focusWorkspaceUp();
                else NiriService.focusWorkspaceDown();
            } else if (CompositorService.isHyprland) {
                Hyprland.dispatch(up ? "workspace r-1" : "workspace r+1");
            }
        }
    }

    function closeOSD(action: string): void {
        if (action === "brightness") GlobalStates.osdBrightnessOpen = false;
        else if (action === "volume") GlobalStates.osdVolumeOpen = false;
    }

    function getScrollIcon(action: string): string {
        if (action === "brightness") return "light_mode";
        if (action === "volume") return "volume_up";
        if (action === "workspace") return "workspaces";
        return "";
    }

    function getScrollTooltip(action: string): string {
        if (action === "brightness") return Translation.tr("Scroll to change brightness");
        if (action === "volume") return Translation.tr("Scroll to change volume");
        if (action === "workspace") return Translation.tr("Scroll to switch workspaces");
        return "";
    }

    // Islands appearance: each SECTION floats as one cohesive Ricelin card
    // (left edge, centre pills, right edge). The centre pills get it via
    // BarGroup.islandStyle; the edge zones draw one EdgeIsland behind their
    // whole content row. Same skin in every global style — islands mode is an
    // explicit opt-in to the pill's dialect.
    // NO Behaviors on x/width here: the capsule derives from the row's
    // implicitWidth, and the row reflows INSTANTLY when a module's implicit
    // changes (active-window titles change it constantly). Animating only the
    // capsule left content poking outside it for the whole animation. Motion
    // is applied at the SOURCE instead (the activeWindow wrapper animates its
    // implicitWidth), so row and capsule move through the same frames.
    component EdgeIsland: BarIslandSurface {
        id: edgeIsland
        glassEnabled: true
        nativeBlurActive: root.nativeBlurActive
        screen: root.screen

        readonly property real spectrumX: {
            const geometryDependency = edgeIsland.x + edgeIsland.y
                + edgeIsland.width + edgeIsland.height
                + (edgeIsland.parent?.x ?? 0) + (edgeIsland.parent?.width ?? 0)
            return edgeIsland.mapToItem(root, 0, 0).x
        }

        CavaSpectrum {
            anchors.fill: parent
            active: root.barSpectrumVisible && root.isIslands && edgeIsland.visible
            threadedRendering: true
            points: active ? barCavaProcess.points : []
            normalizationCeiling: active ? barCavaProcess.normalizationCeiling : 100
            visualizerType: root.barSpectrumType
            spectrumOpacity: root.barSpectrumOpacity
            fillRatio: root.barSpectrumFillRatio
            spectrumColor: root.barSpectrumColor
            sampleStartRatio: root.width > 0
                ? Math.max(0, Math.min(1, edgeIsland.spectrumX / root.width)) : 0
            sampleEndRatio: root.width > 0
                ? Math.max(sampleStartRatio,
                    Math.min(1, (edgeIsland.spectrumX + edgeIsland.width) / root.width)) : 1
            barsOrigin: root.barSpectrumBarsOrigin
            pixelsPerBar: root.barSpectrumDensity
            barSpacing: root.barSpectrumGap
            smoothing: root.barSpectrumSmoothing
            waveMode: root.barSpectrumWaveMode
            lineWidth: root.barSpectrumLineWidth
            edgeInset: root.barSpectrumEdgeInset
            edgeSoftness: root.barSpectrumEdgeSoftness
            frequencyProfile: root.barSpectrumFrequencyProfile
            accentStrength: root.barSpectrumAccentStrength
            topLeftRadius: edgeIsland.radius
            topRightRadius: edgeIsland.radius
            bottomLeftRadius: edgeIsland.radius
            bottomRightRadius: edgeIsland.radius
        }
    }
    // Edge-zone layout cell: hosts the module Loader. Layout hints live HERE
    // (the real layout child) — hints inside the loaded item are ignored.
    component EdgeZoneCell: Item {
        id: cell
        required property string modelData
        property string zone: "left"
        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: root._fillWidth(modelData, zone)
        Layout.fillHeight: root._fillHeight(modelData)
        implicitWidth: cellLoader.implicitWidth
        implicitHeight: cellLoader.implicitHeight
        // Same latch-free rule as the centre zones: never read item.visible
        // from the host (effective visibility latches hidden) — mirror the
        // module's show conditions from root state.
        visible: root._moduleShown(cell.modelData, cell.zone)
        Loader {
            id: cellLoader
            anchors.fill: parent
            active: root._moduleShown(cell.modelData, cell.zone)
            sourceComponent: root._allComponents[cell.modelData] ?? null
            onLoaded: if (cell.modelData === "activeWindow" && item) item.fillSlot = Qt.binding(() => root._fillSlot(cell.zone) && !root.isIslands)
        }
    }

    component VerticalBarSeparator: Rectangle {
        Layout.topMargin: Appearance.sizes.baseBarHeight / 3
        Layout.bottomMargin: Appearance.sizes.baseBarHeight / 3
        Layout.fillHeight: true
        implicitWidth: root.zzzEverywhere ? 1 : 1
        color: root.zzzEverywhere ? Appearance.zzz.hairlineStrong
            : root.inirEverywhere ? Appearance.inir.colBorderSubtle : root.separatorColor
        Behavior on implicitWidth {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }

    // ═══ Modular layout engine ══════════════════════════════════════════
    // Five zones map 1:1 to the bar's real structure. Pills size to their
    // natural content; the `center` zone stays screen-centered regardless of
    // which modules it contains; side pills grow outward and clamp so they
    // never collide with the edge sections.
    // Visibility still comes from Config.options.bar.modules.*; the arrays only
    // define order/zone. Falls back to the classic layout until migrated.
    readonly property bool _layoutMigrated: Config.options?.bar?.layout?.migrated === true
    readonly property real _spacerMinimumWidth: Math.max(0, Config.options?.bar?.layout?.spacerWidth ?? 0) * Appearance.fontSizeScale
    function _zone(name, fallback) {
        const a = Config.options?.bar?.layout?.[name]
        return (root._layoutMigrated && a && a.length >= 0) ? a : fallback
    }
    readonly property var _leftIds:        root._zone("left",        ["leftSidebarButton", "activeWindow"])
    readonly property var _centerLeftIds:  root._zone("centerLeft",  ["resources", "media"])
    readonly property var _centerIds:      root._zone("center",      ["workspaces"])
    readonly property var _centerRightIds: root._zone("centerRight", ["clock", "utilButtons", "battery"])
    readonly property var _rightIds:       root._zone("right",       ["rightSidebarButton", "tray", "timer", "shellUpdate", "spacer", "weather"])

    function _moduleVisible(id) { return Config.options?.bar?.modules?.[id] ?? true }

    /**
     * Latch-free layout visibility. Reading `item.visible` from a host Loader
     * returns EFFECTIVE visibility (parent chain included): once the Loader
     * hides, the item can never be observed turning visible again and the
     * module is stuck hidden. Mirror each module's own show conditions from
     * root state/services instead — these bindings re-evaluate reliably.
     * Modules not listed either are always shown or self-collapse via
     * implicitWidth (shellUpdate) / an inner wrapper (activeWindow).
     */
    function _moduleShown(id, zone) {
        if (id === "spacer") return root._fillWidth(id, zone) || root._spacerMinimumWidth > 0;
        if (id === "tray") return root._moduleVisible("sysTray") && root.useShortenedForm === 0;
        if (!root._moduleVisible(id)) return false;
        if (id === "activeWindow")
            return root.taskbarEnabled || root.useShortenedForm === 0;
        if (id === "media") return root.useShortenedForm < 2;
        if (id === "utilButtons") return (Config.options?.bar?.verbose ?? true) && root.useShortenedForm === 0;
        if (id === "battery") return root.useShortenedForm < 2 && Battery.available;
        if (id === "weather") return Config.options?.bar?.weather?.enable ?? false;
        return true;
    }

    // Unified id→Component map. Every zone uses this same map so ANY module can
    // live in ANY zone (the editor allows cross-zone moves). Layout sizing hints
    // are applied on the Loader (the real layout child) via _fillWidth/_fillHeight
    // below — hints set inside a loaded item are ignored by the parent layout.
    readonly property var _allComponents: ({
        "leftSidebarButton": leftSidebarButtonComponent,
        "activeWindow": activeWindowComponent,
        "resources": resourcesModuleComponent,
        "media": mediaModuleComponent,
        "workspaces": workspacesModuleComponent,
        "clock": clockModuleComponent,
        "utilButtons": utilButtonsModuleComponent,
        "battery": batteryModuleComponent,
        "rightSidebarButton": rightSidebarButtonComponent,
        "tray": trayComponent,
        "timer": timerComponent,
        "shellUpdate": shellUpdateComponent,
        "weather": weatherComponent,
        "spacer": spacerComponent,
    })
    // Edge zones (left/right) are RowLayouts with real slack; the centre zones
    // are content-sized pills with none. `activeWindow` only fills where there
    // is slack — in a centre pill it instead reports a clamped intrinsic width
    // (see _fillSlot below) so it stays visible there.
    readonly property var _edgeZones: ["left", "right"]
    function _fillSlot(zone) { return root._edgeZones.indexOf(zone) !== -1 }

    // Which ids stretch along the bar axis. `spacer` is a pure gap;
    // activeWindow/taskbar fill the edge section; resources fills only on the
    // tightest screens. Centre pills size tightly to content, so clock/media do
    // NOT fill — they sit at natural width with no leftover space.
    readonly property string _spacerMode: Config.options?.bar?.layout?.spacerMode ?? "auto"
    function _fillWidth(id, zone) {
        if (id === "spacer") {
            // Islands: edge sections size to content so the island can wrap
            // them — a stretching spacer would inflate the island to the whole
            // edge section. Always degrade to a fixed gap there.
            if (root.isIslands && root._fillSlot(zone)) return false
            // "auto": only stretch where the layout actually has slack (edge
            // zones); inside content-sized centre pills a greedy spacer fights
            // the pill sizing and breaks the look — fall back to a fixed gap.
            if (root._spacerMode === "fixed") return false
            if (root._spacerMode === "fill") return true
            return root._fillSlot(zone)
        }
        // Islands: edge sections size to content so the island can wrap them —
        // activeWindow adopts its clamped intrinsic width instead of filling.
        if (id === "activeWindow") return root._fillSlot(zone) && !root.isIslands
        if (id === "resources") return root.useShortenedForm === 2
        return false
    }
    function _fillHeight(id) {
        // Islands: filling the row's height means filling the BAR's height, which is
        // taller than the capsule — the module then paints over the island's edges.
        // Let it keep its own (capsule-sized) implicit height and centre instead.
        if (id === "activeWindow")
            return !root.isIslands
        return id === "spacer" || id === "tray" || id === "workspaces"
    }

    Component {
        id: resourcesModuleComponent
        Resources {
            visible: root._moduleVisible("resources")
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: root.useShortenedForm === 2
            alwaysShowAllResources: root.useShortenedForm === 2
        }
    }
    Component {
        id: mediaModuleComponent
        Media {
            visible: root._moduleVisible("media") && root.useShortenedForm < 2
        }
    }
    Component {
        id: workspacesModuleComponent
        Workspaces {
            visible: root._moduleVisible("workspaces")
            Layout.fillHeight: true
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onPressed: event => {
                    if (event.button === Qt.RightButton)
                        GlobalStates.toggleOverview(root.screen?.name ?? "");
                }
            }
        }
    }
    Component {
        id: clockModuleComponent
        ClockWidget {
            visible: root._moduleVisible("clock")
            showDate: ((Config.options?.bar?.verbose ?? true) && root.useShortenedForm < 2)
        }
    }
    Component {
        id: utilButtonsModuleComponent
        UtilButtons {
            visible: root._moduleVisible("utilButtons") && ((Config.options?.bar?.verbose ?? true) && root.useShortenedForm === 0)
            Layout.alignment: Qt.AlignVCenter
        }
    }
    Component {
        id: batteryModuleComponent
        BatteryIndicator {
            visible: root._moduleVisible("battery") && (root.useShortenedForm < 2 && Battery.available)
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // id → Component for the left edge zone.
    Component {
        id: leftSidebarButtonComponent
        LeftSidebarButton {
            visible: root._moduleVisible("leftSidebarButton")
            Layout.alignment: Qt.AlignVCenter
            // Inside a capsule the hover/toggled plate must sit clearly within
            // the island — at the classic padding it nearly filled its height.
            buttonPadding: root.isIslands ? 3 : 5
            colBackground: buttonHovered
                ? (root.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover : Appearance.colors.colLayer1Hover)
                : "transparent"
        }
    }
    // activeWindow covers the title display and the optional taskbar (mutually
    // exclusive: taskbar replaces the active window title).
    // The wrapper deliberately reports implicitWidth: 0 so neither a long title
    // nor extra taskbar items inflate the edge section (which would shrink
    // centerSideMaxWidth and shuffle the centre pills on every change). The
    // Loader's Layout.fillWidth (see root._fillWidth) gives this item the
    // leftover horizontal space inside the section, and the inner content
    // elides / clips to fit instead of pushing the bar around.
    Component {
        id: activeWindowComponent
        Item {
            id: awWrapper
            // Set by the host Loader: true in edge zones (gets fill slack →
            // width 0 + fillWidth), false in centre pills (no slack → adopt a
            // clamped intrinsic width so the title is actually visible).
            property bool fillSlot: true
            // Islands: a FIXED width. The capsule derives from the row's implicit
            // width, so a content-sized wrapper reflowed the whole island on every
            // focus change. The texts elide inside a constant box instead.
            implicitWidth: fillSlot ? 0
                : (root.isIslands
                    ? ((root.screen?.width ?? 1920) <= 1440 ? 150 : 220)
                    : Math.min(_awItem.contentImplicitWidth, 220))
            // Be exactly as tall as the surface we sit on. The cell adopts this as
            // its implicitHeight, so at full bar height the module overflowed the
            // shorter island capsule by the inset on both edges.
            implicitHeight: root.isIslands
                ? Appearance.sizes.baseBarHeight - root.islandInset * 2
                : Appearance.sizes.baseBarHeight
            clip: true
            // The one animated width in the chain: every title change reflows
            // the row, the island and the edge-section geometry from THIS
            // value, all in the same frame — smooth, and nothing can lag
            // outside the capsule. The texts elide at intermediate widths.
            Behavior on implicitWidth {
                enabled: !awWrapper.fillSlot && !root.isIslands && Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
            }
            ActiveWindow {
                id: _awItem
                anchors.fill: parent
                visible: root._moduleVisible("activeWindow") && root.useShortenedForm === 0 && !root.taskbarEnabled
            }
            Loader {
                id: _tbLoader
                anchors.fill: parent
                active: root.taskbarEnabled
                visible: active
                sourceComponent: BarTaskbar {
                    parentWindow: root.QsWindow.window
                    slotSize: _tbLoader.height
                }
            }
        }
    }

    // Background shadow
    Loader {
        active: root.barAppearance === "classic"
            && !root.inirEverywhere
            && (root.angelEverywhere || root.surfaceDialect !== "aurora")
            && !Appearance.gameModeMinimal
            && (Config.options?.bar?.showBackground ?? true)
            && (root.angelEverywhere || (((Config.options?.bar?.cornerStyle ?? 0) === 1 || (Config.options?.bar?.cornerStyle ?? 0) === 3)
            && (Config.options?.bar?.floatStyleShadow ?? true)))
        anchors.fill: barBackground
        sourceComponent: StyledRectangularShadow {
            anchors.fill: undefined // The loader's anchors act on this, and this should not have any anchor
            target: barBackground
        }
    }
    // Background
    Rectangle {
        id: barBackground
        readonly property bool auroraEverywhere: root.surfaceDialect === "aurora" || root.angelEverywhere
        readonly property bool gameModeMinimal: Appearance.gameModeMinimal
        readonly property int cornerStyle: Config.options?.bar?.cornerStyle ?? 0
        readonly property bool zzzGlassActive: root.zzzEverywhere
            && root.barAppearance === "classic"
            && Appearance.effectsEnabled
            && (Config.options?.appearance?.zzz?.glass ?? true)
        // Float (1) and Card (3) are floating; Aurora makes everything floating except Hug and Rect.
        // Frame appearance always floats; scenic hugs the edge by definition.
        readonly property bool floatingStyle: root.zzzDetachedRounded
            || root.isFrame
            || (!root.isScenic && ((cornerStyle === 1 || cornerStyle === 3) || (auroraEverywhere && cornerStyle !== 0 && cornerStyle !== 2)))

        anchors {
            fill: parent
            margins: root.zzzDetachedRounded ? Appearance.sizes.elevationMargin
                : floatingStyle ? Appearance.sizes.hyprlandGapsOut : 0
        }
        readonly property real barMargin: root.zzzDetachedRounded ? Appearance.sizes.elevationMargin
            : floatingStyle ? Appearance.sizes.hyprlandGapsOut : 0
        readonly property bool isBottom: Config.options?.bar?.bottom ?? false

        readonly property QtObject blendedColors: root.blendedColors

        visible: (Config.options?.bar?.showBackground ?? true) && !gameModeMinimal && !root.isIslands
        // User-configurable background opacity (lets you make the bar translucent
        // without changing the global style). Applied as Item.opacity so border,
        // blurredWallpaper, inset glow and partial borders all fade together.
        // Widgets sit OUTSIDE this Rectangle so they stay fully opaque.
        // Regalia is an opaque physical-material style. Preserve the user's
        // persisted opacity for every other style instead of rewriting config.
        opacity: root.regaliaEverywhere && root.barAppearance === "classic"
            ? 1 : Math.max(0, Math.min(1, Config.options?.bar?.opacity ?? 1))
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        // Scenic scrim: the surface is a vertical fade from the screen edge into
        // the wallpaper. Edge strength follows colLayer0; bar.opacity still
        // applies on top as the whole-item fade.
        gradient: root.isScenic ? scenicScrim : null
        Gradient {
            id: scenicScrim
            orientation: Gradient.Vertical
            GradientStop {
                position: 0
                color: barBackground.isBottom ? "transparent"
                    : ColorUtils.transparentize(root.inirEverywhere ? Appearance.inir.colLayer0 : Appearance.colors.colLayer0, 0.15)
            }
            GradientStop {
                position: 1
                color: barBackground.isBottom
                    ? ColorUtils.transparentize(root.inirEverywhere ? Appearance.inir.colLayer0 : Appearance.colors.colLayer0, 0.15)
                    : "transparent"
            }
        }

        // Color logic per global style and corner style
        color: {
            if (root.zzzEverywhere) {
                const zzzBase = cornerStyle === 3 ? Appearance.zzz.chromeAlt : Appearance.zzz.chrome
                // With glass on, ZzzGlassWash below paints the whole background
                // (blurred wallpaper + chrome veil). Painting a translucent chrome
                // here too just let the SHARP wallpaper through — transparency, not
                // glass — and double-veiled the wash.
                return barBackground.zzzGlassActive ? "transparent" : zzzBase
            }
            // Frame is an outline only; scenic paints via the gradient above
            if (root.isFrame || root.isScenic) {
                return ColorUtils.transparentize(Appearance.colors.colLayer0, 1)
            }
            if (root.regaliaEverywhere) {
                return "transparent"
            }
            if (root.angelEverywhere) {
                const base = blendedColors?.colLayer0 ?? Appearance.colors.colLayer0
                if (root.nativeBlurActive)
                    return ColorUtils.transparentize(base, Appearance.angel.compositorPanelTransparentize)
                return ColorUtils.applyAlpha(base, 1)
            }
            if (root.inirEverywhere) {
                return Appearance.inir.colLayer0
            }
            if (auroraEverywhere) {
                const base = blendedColors?.colLayer0 ?? Appearance.colors.colLayer0
                if (root.nativeBlurActive)
                    return ColorUtils.transparentize(base, Appearance.aurora.compositorOverlayTransparentize)
                return ColorUtils.applyAlpha(base, 1)
            }
            // Material/Cards
            if (root.cardStyleEverywhere || cornerStyle === 3) {
                return Appearance.colors.colLayer1
            }
            return Appearance.colors.colLayer0
        }
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        RegaliaPlate {
            anchors.fill: parent
            visible: root.regaliaEverywhere && !root.isFrame && !root.isScenic
            fillColor: barBackground.floatingStyle ? Appearance.regalia.barSurfaceFloating
                : Appearance.regalia.barSurface
            radius: barBackground.radius
            inset: barBackground.floatingStyle
                ? Appearance.regalia.surfaceInset : Appearance.regalia.controlInset
            elevated: barBackground.floatingStyle
            deepFrame: !barBackground.floatingStyle
            glassEnabled: true
        }

        // Radius logic per global style and corner style
        radius: {
            if (root.isScenic) return 0
            if (root.zzzEverywhere) {
                return 0
            }
            // Custom rounding override (-1 means use theme default)
            const customRounding = Config.options?.bar?.customRounding ?? -1
            if (customRounding >= 0) {
                return customRounding
            }
            if (root.isFrame) {
                return root.angelEverywhere ? Appearance.angel.roundingNormal
                    : root.inirEverywhere ? Appearance.inir.roundingNormal
                    : Appearance.rounding.windowRounding
            }
            if (root.regaliaEverywhere) {
                return (cornerStyle === 1 || cornerStyle === 3) ? Appearance.regalia.roundLarge : 0
            }
            if (root.angelEverywhere) {
                return (cornerStyle === 1 || cornerStyle === 3) ? Appearance.angel.roundingNormal : 0
            }
            if (root.inirEverywhere) {
                // Inir: use inir rounding for Float/Card, 0 for Hug/Rect
                if (cornerStyle === 1 || cornerStyle === 3) {
                    return Appearance.inir.roundingNormal
                }
                return 0
            }
            if (floatingStyle) {
                // Float or Card floating
                return cornerStyle === 3 ? Appearance.rounding.normal : Appearance.rounding.windowRounding
            }
            return 0
        }
        // No Behavior on the base radius: all four corners below are always
        // bound (radius only feeds them), and stacking a radius interceptor on
        // top of the per-corner ones triggers Qt's "another interceptor on
        // property radius - unsupported" warning.

        // ZZZ corner semantics:
        // - Round mode keeps the same capsule language at the screen ends.
        // - Rect stays edge-bound and sharp.
        // - Float/Card detach and round all visible corners in round mode.
        readonly property real zzzRoundEdge: (root.zzzEverywhere && Appearance.zzz.round) ? Appearance.zzz.panelRadius : -1
        readonly property bool zzzHugCorners: zzzRoundEdge >= 0 && cornerStyle === 0
        readonly property bool zzzAllCorners: zzzRoundEdge >= 0 && floatingStyle
        topLeftRadius: (zzzAllCorners || zzzHugCorners) ? zzzRoundEdge : radius
        topRightRadius: (zzzAllCorners || zzzHugCorners) ? zzzRoundEdge : radius
        bottomLeftRadius: (zzzAllCorners || zzzHugCorners) ? zzzRoundEdge : radius
        bottomRightRadius: (zzzAllCorners || zzzHugCorners) ? zzzRoundEdge : radius
        Behavior on topLeftRadius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on topRightRadius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on bottomLeftRadius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on bottomRightRadius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        // Border logic per global style
        border.width: {
            if (root.isScenic) return 0
            if (root.zzzEverywhere) return 1
            if (root.regaliaEverywhere) return 0
            if (root.isFrame) return root.angelEverywhere ? Appearance.angel.panelBorderWidth : 1
            if (root.angelEverywhere) return Appearance.angel.panelBorderWidth
            if (root.inirEverywhere) {
                return (cornerStyle === 1 || cornerStyle === 3) ? 1 : 0
            }
            if (auroraEverywhere) {
                return floatingStyle ? 1 : 0
            }
            return floatingStyle ? 1 : 0
        }
        Behavior on border.width {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
        border.color: {
            if (root.zzzEverywhere) return Appearance.zzz.hairline
            if (root.regaliaEverywhere) return "transparent"
            // Frame is defined by its outline — use the visible outline token
            if (root.isFrame && !root.angelEverywhere && !root.inirEverywhere) {
                return Appearance.colors.colOutlineVariant
            }
            if (root.angelEverywhere) return Appearance.angel.colPanelBorder
            if (root.inirEverywhere) {
                return Appearance.inir.colBorder
            }
            if (auroraEverywhere) {
                return Appearance.aurora.colTooltipBorder
            }
            return Appearance.colors.colLayer0Border
        }
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        clip: true

        ZzzGlassWash {
            anchors.fill: parent
            maskRadius: barBackground.zzzRoundEdge >= 0 ? barBackground.zzzRoundEdge : barBackground.radius
            // barBackground is a plain rectangle in zzz (radius always 0 unless
            // round mode) — it never chamfers a corner. ZzzGlassWash defaults to
            // a bottom-right chamfer mask, which left an unwashed square wedge
            // (flat chrome, reading as a stray black corner) wherever the bar
            // itself has no cut to match. Match the host: no chamfer here.
            chamfer: 0
            glassEnabled: barBackground.zzzGlassActive
            selfBacked: true
            // The bar carries small text, so it keeps the heaviest veil of the two
            // glass hosts — enough wallpaper to read as glass, not enough to move
            // the ink's ground out of the band onMuted is calibrated for.
            veilAlpha: Appearance.zzz.dark ? 0.78 : 0.82
            z: -1
        }

        layer.enabled: auroraEverywhere && !root.inirEverywhere && !root.zzzEverywhere && !gameModeMinimal && root.barAppearance === "classic"
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: barBackground.width
                height: barBackground.height
                radius: barBackground.radius
            }
        }

        Image {
            id: blurredWallpaper
            x: -barBackground.barMargin
            y: barBackground.isBottom ? -(root.screen?.height ?? 1080) + barBackground.height + barBackground.barMargin : -barBackground.barMargin
            width: root.screen?.width ?? 1920
            height: root.screen?.height ?? 1080
            visible: barBackground.auroraEverywhere && !root.inirEverywhere && !root.zzzEverywhere && !barBackground.gameModeMinimal && !root.nativeBlurActive && root.barAppearance === "classic"
            // An invisible Image still downloads and decodes its source, so gating
            // only `visible` on the style left a screen-sized wallpaper bitmap
            // resident for every user NOT on aurora. Gate the source too.
            source: visible ? root.wallpaperUrl : ""
            fillMode: Image.PreserveAspectCrop
            cache: true
            sourceSize.width: root.screen?.width ?? 1920
            sourceSize.height: root.screen?.height ?? 1080
            asynchronous: true

            // Skip QML blur when the compositor is already blurring this layer
            // (avoids double-blur and the FBO cost). See #159.
            layer.enabled: Appearance.effectsEnabled && barBackground.auroraEverywhere && !root.inirEverywhere && !root.nativeBlurActive
            layer.effect: MultiEffect {
                source: blurredWallpaper
                anchors.fill: source
                saturation: root.angelEverywhere
                    ? (Appearance.angel.blurSaturation * Appearance.angel.colorStrength)
                    : (Appearance.effectsEnabled ? 0.2 : 0)
                blurEnabled: Appearance.effectsEnabled
                blurMax: 64
                blur: Appearance.effectsEnabled
                    ? (root.angelEverywhere ? Appearance.angel.blurIntensity : 1)
                    : 0
            }

            Rectangle {
                anchors.fill: parent
                color: root.angelEverywhere
                    ? ColorUtils.transparentize((barBackground.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.angel.overlayOpacity * Appearance.angel.panelTransparentize)
                    : ColorUtils.transparentize((barBackground.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.aurora.overlayTransparentize)
            }
        }

        // Angel inset glow — top edge
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Appearance.angel.insetGlowHeight
            visible: root.angelEverywhere && root.barAppearance === "classic"
            color: Appearance.angel.colInsetGlow
        }

        // Angel partial border — elegant half-borders
        AngelPartialBorder {
            targetRadius: barBackground.radius
        }

        ZzzTechFrame {
            margin: 6
            showGrid: false
            showCornerMarks: false
            showLabels: false
            showTicks: false
            accentColor: Appearance.zzz.chromeStroke
        }

        CavaSpectrum {
            anchors.fill: parent
            active: root.barSpectrumVisible && !root.isIslands
            threadedRendering: true
            points: active ? barCavaProcess.points : []
            normalizationCeiling: active ? barCavaProcess.normalizationCeiling : 100
            visualizerType: root.barSpectrumType
            spectrumOpacity: root.barSpectrumOpacity
            fillRatio: root.barSpectrumFillRatio
            spectrumColor: root.barSpectrumColor
            barsOrigin: root.barSpectrumBarsOrigin
            pixelsPerBar: root.barSpectrumDensity
            barSpacing: root.barSpectrumGap
            smoothing: root.barSpectrumSmoothing
            waveMode: root.barSpectrumWaveMode
            lineWidth: root.barSpectrumLineWidth
            edgeInset: root.barSpectrumEdgeInset
            edgeSoftness: root.barSpectrumEdgeSoftness
            frequencyProfile: root.barSpectrumFrequencyProfile
            accentStrength: root.barSpectrumAccentStrength
            topLeftRadius: barBackground.topLeftRadius
            topRightRadius: barBackground.topRightRadius
            bottomLeftRadius: barBackground.bottomLeftRadius
            bottomRightRadius: barBackground.bottomRightRadius
        }
    }

    FocusedScrollMouseArea { // Left side | scroll to change brightness
        id: barLeftSideMouseArea

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
        }
        // Extend up to the left pill's inner edge but keep at least the natural
        // content width so the sidebar button / active window are never clipped.
        width: root.layoutCompressionActive
            ? root.compressedLeftEdgeWidth
            : Math.max(implicitWidth, middleSection.leftPillX)
        implicitWidth: leftSectionRowLayout.implicitWidth
        implicitHeight: Appearance.sizes.baseBarHeight
        clip: root.layoutCompressionActive

        onScrollDown: root.performScrollAction(root.leftAction, false)
        onScrollUp: root.performScrollAction(root.leftAction, true)
        onMovedAway: root.closeOSD(root.leftAction)
        onPressed: event => {
            if (event.button === Qt.LeftButton)
                ShellLayoutController.toggleSidebarAtSlot("left");
            else if (event.button === Qt.RightButton)
                root.openBarContextMenu(event.x, event.y, barLeftSideMouseArea)
        }

        // ScrollHint as overlay - at the inner edge of the margin space
        ScrollHint {
            id: leftScrollHint
            reveal: barLeftSideMouseArea.hovered && (Config.options?.bar?.showScrollHints ?? true) && root.leftAction !== "none"
            icon: root.getScrollIcon(root.leftAction)
            tooltipText: root.getScrollTooltip(root.leftAction)
            side: "left"
            x: Appearance.rounding.screenRounding - implicitWidth - Appearance.sizes.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            z: 1
        }

        // Islands: one capsule wraps the whole left section content.
        EdgeIsland {
            id: leftEdgeIsland
            visible: root.isIslands && leftSectionRowLayout.implicitWidth > 1
            anchors.verticalCenter: parent.verticalCenter
            x: leftSectionRowLayout.anchors.leftMargin - root.islandPad
            width: root.layoutCompressionActive
                ? Math.max(0, parent.width - x)
                : leftSectionRowLayout.implicitWidth + root.islandPad * 2
            height: Appearance.sizes.baseBarHeight - root.islandInset * 2
        }

        RowLayout {
            id: leftSectionRowLayout
            // Islands: hug content (no right anchor → width = implicitWidth), so
            // the island wraps the row exactly and nothing can stretch across
            // the zone's slack. Classic keeps the full-zone fill.
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: root.isIslands && !root.layoutCompressionActive ? undefined : parent.right
            anchors.leftMargin: root.isIslands
                ? root.islandOuterInset + root.islandPad
                : Appearance.rounding.screenRounding
            anchors.rightMargin: Appearance.rounding.screenRounding
            spacing: 10
            clip: root.layoutCompressionActive

            Repeater {
                model: root._leftIds
                delegate: EdgeZoneCell { zone: "left" }
            }
        }
    }

    Item { // Middle section — the center zone stays screen-centered; the side
           // pills size to their natural content and grow outward from it,
           // clamped so they never collide with the edge sections.
        id: middleSection
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        // Inner X edges of the side pills (BarContent coords) so the edge
        // sections can extend up to — but never into — the center cluster.
        readonly property real leftPillX: leftCenterGroup.width > 0 ? leftCenterGroup.x : middleCenterGroup.x
        readonly property real rightPillEndX: rightCenterGroup.width > 0
            ? (rightCenterGroup.x + rightCenterGroup.width)
            : (middleCenterGroup.x + middleCenterGroup.width)

        BarGroup {
            id: middleCenterGroup
            nativeBlurActive: root.nativeBlurActive
            screen: root.screen
            spectrumEnabled: root.barSpectrumVisible && root.isIslands && visible
            spectrumPoints: spectrumEnabled ? barCavaProcess.points : []
            spectrumCeiling: spectrumEnabled ? barCavaProcess.normalizationCeiling : 100
            spectrumType: root.barSpectrumType
            spectrumOpacity: root.barSpectrumOpacity
            spectrumFillRatio: root.barSpectrumFillRatio
            spectrumBarsOrigin: root.barSpectrumBarsOrigin
            spectrumDensity: root.barSpectrumDensity
            spectrumGap: root.barSpectrumGap
            spectrumSmoothing: root.barSpectrumSmoothing
            spectrumWaveMode: root.barSpectrumWaveMode
            spectrumLineWidth: root.barSpectrumLineWidth
            spectrumEdgeInset: root.barSpectrumEdgeInset
            spectrumEdgeSoftness: root.barSpectrumEdgeSoftness
            spectrumFrequencyProfile: root.barSpectrumFrequencyProfile
            spectrumAccentStrength: root.barSpectrumAccentStrength
            spectrumDomain: root
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            padding: 4
            implicitWidth: empty ? 0 : (root.layoutCompressionActive
                ? root.compressedCenterWidth : contentWidth)
            clipContent: root.layoutCompressionActive
            // Collapse the pivot pill background when workspaces (its only
            // default content) is hidden — leaves a tiny centred gap instead of
            // a ghost pill. Width stays minimal so side pills still flank it.
            visible: !empty

            Repeater {
                model: root._centerIds
                delegate: Loader {
                    required property string modelData
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: root._fillWidth(modelData, "center")
                    Layout.fillHeight: root._fillHeight(modelData)
                    // Hidden modules must leave the layout entirely, or their
                    // implicit width lingers as a ghost gap inside the pill.
                    active: root._moduleShown(modelData, "center")
                    visible: active
                    sourceComponent: root._allComponents[modelData] ?? null
                    onLoaded: if (modelData === "activeWindow" && item) item.fillSlot = false
                }
            }
        }

        VerticalBarSeparator {
            id: leftSeparator
            visible: (Config.options?.bar.borderless ?? false) && !root.isIslands && !leftCenterGroup.empty && !middleCenterGroup.empty
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: middleCenterGroup.left
            anchors.rightMargin: 4
            height: Appearance.sizes.baseBarHeight / 3
        }

        BarGroup {
            id: leftCenterGroup
            nativeBlurActive: root.nativeBlurActive
            screen: root.screen
            spectrumEnabled: root.barSpectrumVisible && root.isIslands && visible
            spectrumPoints: spectrumEnabled ? barCavaProcess.points : []
            spectrumCeiling: spectrumEnabled ? barCavaProcess.normalizationCeiling : 100
            spectrumType: root.barSpectrumType
            spectrumOpacity: root.barSpectrumOpacity
            spectrumFillRatio: root.barSpectrumFillRatio
            spectrumBarsOrigin: root.barSpectrumBarsOrigin
            spectrumDensity: root.barSpectrumDensity
            spectrumGap: root.barSpectrumGap
            spectrumSmoothing: root.barSpectrumSmoothing
            spectrumWaveMode: root.barSpectrumWaveMode
            spectrumLineWidth: root.barSpectrumLineWidth
            spectrumEdgeInset: root.barSpectrumEdgeInset
            spectrumEdgeSoftness: root.barSpectrumEdgeSoftness
            spectrumFrequencyProfile: root.barSpectrumFrequencyProfile
            spectrumAccentStrength: root.barSpectrumAccentStrength
            spectrumDomain: root
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: (Config.options?.bar.borderless ?? false) ? leftSeparator.left : middleCenterGroup.left
            anchors.rightMargin: (root.isIslands ? 8 : 4) * root.hostScale
            // Collapse to nothing when this zone has no visible modules;
            // otherwise take the symmetric target width. Modules elide/clip.
            visible: !empty
            // Islands: each capsule hugs its own content (no symmetric mirroring,
            // which would leave dead space in the lighter side). Classic keeps the
            // mirrored width so the two side pills stay visually balanced.
            implicitWidth: empty ? 0 : (root.layoutCompressionActive
                ? root.compressedLeftCenterWidth
                : (root.isIslands ? Math.min(contentWidth, root.centerSideMaxWidth) : root._pillWidth(contentWidth)))
            clipContent: true

            Repeater {
                model: root._centerLeftIds
                delegate: Loader {
                    required property string modelData
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: root._fillWidth(modelData, "centerLeft")
                    Layout.fillHeight: root._fillHeight(modelData)
                    active: root._moduleShown(modelData, "centerLeft")
                    visible: active
                    sourceComponent: root._allComponents[modelData] ?? null
                    onLoaded: if (modelData === "activeWindow" && item) item.fillSlot = false
                }
            }
        }

        VerticalBarSeparator {
            id: rightSeparator
            visible: (Config.options?.bar.borderless ?? false) && !root.isIslands && !rightCenterGroupPill.empty && !middleCenterGroup.empty
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: middleCenterGroup.right
            anchors.leftMargin: 4
            height: Appearance.sizes.baseBarHeight / 3
        }

        Item {
            id: rightCenterGroup
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: (Config.options?.bar.borderless ?? false) ? rightSeparator.right : middleCenterGroup.right
            anchors.leftMargin: (root.isIslands ? 8 : 4) * root.hostScale
            visible: !rightCenterGroupPill.empty
            implicitWidth: rightCenterGroupPill.empty ? 0 : rightCenterGroupPill.width
            implicitHeight: rightCenterGroupPill.height
            readonly property real contentWidth: rightCenterGroupPill.contentWidth

            // Gesture sequence tracking for multi-tap detection
            property int _tapSeq: 0
            property bool _confirmFx: false
            Timer { id: _tapSeqTimer; interval: 500; onTriggered: rightCenterGroup._tapSeq = 0 }
            Timer { id: _fxResetTimer; interval: 2000; onTriggered: rightCenterGroup._confirmFx = false }

            // Pill + content — structurally identical to leftCenterGroup so it
            // sizes to natural content and centers it the same way.
            BarGroup {
                id: rightCenterGroupPill
                nativeBlurActive: root.nativeBlurActive
                screen: root.screen
                spectrumEnabled: root.barSpectrumVisible && root.isIslands && visible
                spectrumPoints: spectrumEnabled ? barCavaProcess.points : []
                spectrumCeiling: spectrumEnabled ? barCavaProcess.normalizationCeiling : 100
                spectrumType: root.barSpectrumType
                spectrumOpacity: root.barSpectrumOpacity
                spectrumFillRatio: root.barSpectrumFillRatio
                spectrumBarsOrigin: root.barSpectrumBarsOrigin
                spectrumDensity: root.barSpectrumDensity
                spectrumGap: root.barSpectrumGap
                spectrumSmoothing: root.barSpectrumSmoothing
                spectrumWaveMode: root.barSpectrumWaveMode
                spectrumLineWidth: root.barSpectrumLineWidth
                spectrumEdgeInset: root.barSpectrumEdgeInset
                spectrumEdgeSoftness: root.barSpectrumEdgeSoftness
                spectrumFrequencyProfile: root.barSpectrumFrequencyProfile
                spectrumAccentStrength: root.barSpectrumAccentStrength
                spectrumDomain: root
                anchors.verticalCenter: parent.verticalCenter
                visible: !empty
                // Islands: each capsule hugs its own content (no symmetric mirroring,
                // which would leave dead space in the lighter side). Classic keeps the
                // mirrored width so the two side pills stay visually balanced.
                implicitWidth: empty ? 0 : (root.layoutCompressionActive
                    ? root.compressedRightCenterWidth
                    : (root.isIslands ? Math.min(contentWidth, root.centerSideMaxWidth) : root._pillWidth(contentWidth)))
                clipContent: true

                Repeater {
                    model: root._centerRightIds
                    delegate: Loader {
                        required property string modelData
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: root._fillWidth(modelData, "centerRight")
                        Layout.fillHeight: root._fillHeight(modelData)
                        active: root._moduleShown(modelData, "centerRight")
                        visible: active
                        sourceComponent: root._allComponents[modelData] ?? null
                        onLoaded: if (modelData === "activeWindow" && item) item.fillSlot = false
                    }
                }
            }

            // Interaction overlay (sidebar toggle / control panel / triple-tap fx)
            MouseArea {
                anchors.fill: rightCenterGroupPill
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                z: -1
                onPressed: event => {
                    if (event.button === Qt.RightButton) {
                        GlobalStates.controlPanelOpen = !GlobalStates.controlPanelOpen;
                    } else {
                        ShellLayoutController.toggleSidebarAtSlot("right");
                        rightCenterGroup._tapSeq++; _tapSeqTimer.restart()
                        if (rightCenterGroup._tapSeq >= 3) { rightCenterGroup._confirmFx = true; rightCenterGroup._tapSeq = 0; _fxResetTimer.restart() }
                    }
                }
            }

            // Tap-sequence visual confirmation overlay
            Repeater {
                model: rightCenterGroup._confirmFx ? 3 : 0
                Text {
                    property int _delay: index * 120
                    text: "\ud83e\udec3\ud83c\udffb"
                    font.pixelSize: 22
                    x: (rightCenterGroup.width - implicitWidth) / 2 + (index - 1) * 28
                    y: rightCenterGroup.height / 2
                    z: 10
                    scale: 0
                    opacity: 0
                    SequentialAnimation on y {
                        PauseAnimation { duration: _delay }
                        NumberAnimation { to: -20; duration: 1200; easing.type: Easing.OutCubic }
                    }
                    SequentialAnimation on scale {
                        PauseAnimation { duration: _delay }
                        NumberAnimation { to: 1.3; duration: 250; easing.type: Easing.OutBack }
                        NumberAnimation { to: 1.0; duration: 200 }
                        PauseAnimation { duration: 500 }
                        NumberAnimation { to: 0; duration: 300; easing.type: Easing.InBack }
                    }
                    SequentialAnimation on opacity {
                        PauseAnimation { duration: _delay }
                        NumberAnimation { to: 1; duration: 200 }
                        PauseAnimation { duration: 700 }
                        NumberAnimation { to: 0; duration: 350 }
                    }
                }
            }
        }
    }

    FocusedScrollMouseArea { // Right side | scroll to change volume
        id: barRightSideMouseArea

        anchors {
            top: parent.top
            bottom: parent.bottom
            right: parent.right
        }
        width: root.layoutCompressionActive
            ? root.compressedRightEdgeWidth
            : Math.max(implicitWidth, root.width - middleSection.rightPillEndX)
        implicitWidth: rightSectionRowLayout.implicitWidth
        implicitHeight: Appearance.sizes.baseBarHeight
        clip: root.layoutCompressionActive

        onScrollDown: root.performScrollAction(root.rightAction, false)
        onScrollUp: root.performScrollAction(root.rightAction, true)
        onMovedAway: root.closeOSD(root.rightAction)
        onPressed: event => {
            if (event.button === Qt.LeftButton) {
                ShellLayoutController.toggleSidebarAtSlot("right");
            } else if (event.button === Qt.RightButton) {
                root.openBarContextMenu(event.x, event.y, barRightSideMouseArea)
            }
        }

        // ScrollHint as overlay - at the inner edge of the margin space
        ScrollHint {
            id: rightScrollHint
            reveal: barRightSideMouseArea.hovered && (Config.options?.bar?.showScrollHints ?? true) && root.rightAction !== "none"
            icon: root.getScrollIcon(root.rightAction)
            tooltipText: root.getScrollTooltip(root.rightAction)
            side: "right"
            x: parent.width - Appearance.rounding.screenRounding + Appearance.sizes.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            z: 1
        }

        // Islands: one capsule wraps the whole right section content (RTL — the
        // content sits flush against the right margin).
        EdgeIsland {
            id: rightEdgeIsland
            visible: root.isIslands && rightSectionRowLayout.implicitWidth > 1
            anchors.verticalCenter: parent.verticalCenter
            x: root.layoutCompressionActive ? 0
                : parent.width - rightSectionRowLayout.anchors.rightMargin - rightSectionRowLayout.implicitWidth - root.islandPad
            width: root.layoutCompressionActive
                ? Math.max(0, parent.width - root.islandOuterInset)
                : rightSectionRowLayout.implicitWidth + root.islandPad * 2
            height: Appearance.sizes.baseBarHeight - root.islandInset * 2
        }

        RowLayout {
            id: rightSectionRowLayout
            // Islands: hug content against the right margin (no left anchor →
            // width = implicitWidth) so the island wraps the row exactly.
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.left: root.isIslands && !root.layoutCompressionActive ? undefined : parent.left
            anchors.leftMargin: Appearance.rounding.screenRounding
            anchors.rightMargin: root.isIslands
                ? root.islandOuterInset + root.islandPad
                : Appearance.rounding.screenRounding
            spacing: 5
            layoutDirection: Qt.RightToLeft
            clip: root.layoutCompressionActive

            Repeater {
                model: root._rightIds
                delegate: EdgeZoneCell {
                    zone: "right"
                    Layout.leftMargin: modelData === "weather" ? 4 : 0
                }
            }
        }
    }

    // id → Component for the right edge zone. The RowLayout is RTL: the first id
    // renders nearest the screen edge. `spacer` is a flexible gap.
    // The right edge zone renders RTL: the first id sits nearest the screen
    // edge. `spacer` is a flexible gap.
    Component { id: timerComponent; TimerIndicator { Layout.alignment: Qt.AlignVCenter } }
    Component { id: shellUpdateComponent; ShellUpdateIndicator { Layout.alignment: Qt.AlignVCenter } }
    Component {
        id: spacerComponent
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: root._spacerMinimumWidth
            implicitWidth: root._spacerMinimumWidth
            Behavior on implicitWidth {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementResize.duration
                    easing.type: Appearance.animation.elementResize.type
                    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                }
            }
        }
    }
    Component {
        id: trayComponent
        SysTray {
            visible: root._moduleVisible("sysTray") && root.useShortenedForm === 0
            Layout.fillWidth: false
            Layout.fillHeight: true
            invertSide: Config.options?.bar?.bottom ?? false
        }
    }
    Component {
        id: weatherComponent
        Loader {
            active: root._moduleVisible("weather") && (Config.options?.bar?.weather?.enable ?? false)
            visible: active
            sourceComponent: BarGroup {
                // Inside an edge island the weather is a bare chip — its own
                // card would nest a card inside the island.
                bare: root.isIslands
                WeatherBar {}
            }
        }
    }
    Component {
        id: rightSidebarButtonComponent
        RippleButton { // Right sidebar button
            id: rightSidebarButton
            cookieMorphing: true
            visible: root._moduleVisible("rightSidebarButton")

            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.fillWidth: false

            // Islands: tighter plate so the hover/toggled pill reads as a chip
            // inside the capsule instead of almost filling it.
            implicitWidth: indicatorsRowLayout.implicitWidth + (root.isIslands ? 7 : 10) * 2
            implicitHeight: indicatorsRowLayout.implicitHeight + (root.isIslands ? 2 : 5) * 2

            buttonRadius: root.regaliaEverywhere ? Appearance.regalia.controlRadius
                : root.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.full

            // zzz: transparent everywhere on this Control's own background —
            // the ZzzPlate below is the only hover/toggle surface. Matches
            // LeftSidebarButton.qml/CircleUtilButton.qml; leaving these as a
            // plain rounded fill let it poke out past the ZzzPlate's chamfer.
            colBackground: buttonHovered
                ? (root.zzzEverywhere ? "transparent"
                : root.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover : Appearance.colors.colLayer1Hover)
                : "transparent"
            colBackgroundHover: root.zzzEverywhere ? "transparent"
                : root.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover : Appearance.colors.colLayer1Hover
            colRipple: root.zzzEverywhere ? ColorUtils.applyAlpha(Appearance.zzz.accent, 0.20)
                : root.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer1Active
            colBackgroundToggled: root.regaliaEverywhere ? Appearance.regalia.primaryPlate
                : root.zzzEverywhere ? "transparent"
                : root.auroraEverywhere ? Appearance.aurora.colElevatedSurface : Appearance.colors.colSecondaryContainer
            colBackgroundToggledHover: root.regaliaEverywhere ? Appearance.regalia.primaryPlateHover
                : root.zzzEverywhere ? "transparent"
                : root.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover : Appearance.colors.colSecondaryContainerHover
            colRippleToggled: root.zzzEverywhere ? ColorUtils.applyAlpha(Appearance.zzz.accent, 0.20)
                : root.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colSecondaryContainerActive

            // Same chamfer-grows-on-hover language as LeftSidebarButton.qml —
            // the right sidebar button previously had no zzz plate at all.
            ZzzPlate {
                anchors.fill: parent
                visible: root.zzzEverywhere
                chamfer: (rightSidebarButton.buttonHovered || rightSidebarButton.toggled) ? Appearance.zzz.cutCorner * 0.7 : Appearance.zzz.cutCorner * 0.35
                fillColor: rightSidebarButton.toggled ? Appearance.zzz.accentSoft
                    : rightSidebarButton.buttonHovered ? Appearance.zzz.sticker : "transparent"
                strokeColor: rightSidebarButton.toggled ? "transparent"
                    : rightSidebarButton.buttonHovered ? Appearance.zzz.accentSoft : "transparent"
                strokeWidth: 1
                z: -1
            }

            toggled: ShellLayoutController.sidebarOpenAtSlot("right")
            property color colText: root.regaliaEverywhere
                ? (toggled ? Appearance.regalia.primaryPlateInk : Appearance.regalia.onColor)
                : root.zzzEverywhere
                ? (toggled ? Appearance.zzz.onAccentSoft : Appearance.zzz.ink)
                : toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer0

            Behavior on colText {
                enabled: Appearance.animationsEnabled
                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            onPressed: {
                ShellLayoutController.toggleSidebarAtSlot("right");
            }

            RowLayout {
                id: indicatorsRowLayout
                anchors.centerIn: parent
                property real realSpacing: 15
                spacing: 0

                Revealer {
                    reveal: Audio.sink?.audio?.muted ?? false
                    Layout.fillHeight: true
                    Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                    Behavior on Layout.rightMargin {
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    MaterialSymbol {
                        text: "volume_off"
                        iconSize: Appearance.font.pixelSize.larger
                        color: rightSidebarButton.colText
                    }
                }
                Revealer {
                    reveal: Audio.micMuted
                    Layout.fillHeight: true
                    Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                    Behavior on Layout.rightMargin {
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    MaterialSymbol {
                        text: "mic_off"
                        iconSize: Appearance.font.pixelSize.larger
                        color: rightSidebarButton.colText
                    }
                }
                HyprlandXkbIndicator {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: KeyboardIndicators.hasPanelIndicators ? indicatorsRowLayout.realSpacing : 0
                    color: rightSidebarButton.colText
                }
                Revealer {
                    reveal: Notifications.silent || Notifications.unread > 0
                    Layout.fillHeight: true
                    Layout.rightMargin: reveal ? indicatorsRowLayout.realSpacing : 0
                    implicitHeight: reveal ? notificationUnreadCount.implicitHeight : 0
                    implicitWidth: reveal ? notificationUnreadCount.implicitWidth : 0
                    Behavior on Layout.rightMargin {
                        enabled: Appearance.animationsEnabled
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    NotificationUnreadCount {
                        id: notificationUnreadCount
                    }
                }
                MaterialSymbol {
                    text: Network.materialSymbol
                    iconSize: Appearance.font.pixelSize.larger
                    color: rightSidebarButton.colText
                    Layout.rightMargin: BluetoothStatus.available ? indicatorsRowLayout.realSpacing : 0

                    HoverHandler {
                        id: wifiHover
                        onHoveredChanged: {
                            if (hovered) {
                                Network.refreshActiveNetworkDetails();
                            }
                        }
                    }

                    StyledToolTip {
                        extraVisibleCondition: wifiHover.hovered
                        text: {
                            if (!Network.wifiEnabled) return Translation.tr("Wi-Fi is disabled");
                            if (Network.ethernet) return Translation.tr("Ethernet connected");
                            if (!Network.networkName) return Translation.tr("Not connected");
                            const connected = Translation.tr("Connected to %1").arg(Network.networkName);
                            const details = Network.accessPointDetails(Network.active, true);
                            return details.length > 0 ? `${connected} | ${details}` : connected;
                        }
                    }
                }
                Revealer {
                    reveal: BluetoothStatus.available
                    Layout.rightMargin: indicatorsRowLayout.realSpacing
                    MaterialSymbol {
                        text: BluetoothStatus.activeIcon
                        iconSize: Appearance.font.pixelSize.larger
                        color: rightSidebarButton.colText

                        HoverHandler {
                            id: btHover
                        }

                        StyledToolTip {
                            extraVisibleCondition: btHover.hovered
                            text: BluetoothStatus.connectionTooltip()
                        }
                    }
                }
            }
        }
    }
}
