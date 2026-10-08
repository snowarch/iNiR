pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.workspaceStrip

Item {
    id: root

    required property var panelWindow
    required property real availableWidth
    required property real availableHeight
    property var runtimeOrbitOptions: null
    property string filterText: ""
    property real entryProgress: 1
    property int entryStaggerMs: 42
    property int entryDurationMs: 300
    property bool entryCascade: true

    readonly property var orbitOptions: runtimeOrbitOptions ?? Config.options?.orbit ?? {}
    readonly property var orbitalOptions: orbitOptions.orbital ?? {}
    readonly property string outputName: panelWindow?.screen?.name ?? ""
    readonly property string wallpaperPath: {
        const multiMonitorDependency = WallpaperListener.multiMonitorEnabled
        const perMonitorDependency = WallpaperListener.effectivePerMonitor
        const wallpaperDependency = Wallpapers.effectiveWallpaperUrl
        return WallpaperListener.wallpaperUrlForScreen(panelWindow?.screen ?? null)
    }
    readonly property int maxVisibleWorkspaces: {
        const requested = Math.max(3, Math.min(7, orbitalOptions.visibleWorkspaces ?? 5))
        return requested % 2 === 0 ? Math.min(7, requested + 1) : requested
    }
    readonly property int coreSizePercent: Math.max(36,
        Math.min(62, orbitalOptions.coreSizePercent ?? 48))
    readonly property int satelliteSizePercent: Math.max(28,
        Math.min(60, orbitalOptions.satelliteSizePercent ?? 42))
    readonly property int horizontalSpreadPercent: Math.max(58,
        Math.min(96, orbitalOptions.horizontalSpreadPercent ?? 82))
    readonly property int verticalSpreadPercent: Math.max(40,
        Math.min(82, orbitalOptions.verticalSpreadPercent ?? 58))
    readonly property int depthPercent: Math.max(0,
        Math.min(35, orbitalOptions.depthPercent ?? 18))
    readonly property var navigationOptions: orbitOptions.navigationMotion ?? ({})
    readonly property string navigationPreset: OrbitTuning.navigationPreset(navigationOptions)
    readonly property bool navigationAdvanced: OrbitTuning.navigationAdvanced(navigationOptions)
    readonly property int transitionDurationMs: OrbitTuning.navigationDuration(
        navigationOptions, spatialLayout)
    readonly property string navigationEasing: OrbitTuning.navigationEasing(navigationOptions)
    readonly property int navigationEasingType: OrbitTuning.navigationEasingType(navigationOptions)
    readonly property real previewDpr: Math.max(1, panelWindow?.devicePixelRatio ?? 1)
    readonly property real previewDecodeScale: Math.max(1.8, previewDpr * 1.35)
    readonly property int previewDecodeWidth: Math.max(640,
        Math.min(1600, Math.round(coreWidth * previewDecodeScale)))
    readonly property int previewDecodeHeight: Math.max(360,
        Math.min(900, Math.round(previewDecodeWidth * 9 / 16)))
    readonly property int corePreviewFreshnessMs: 10000
    readonly property int satellitePreviewFreshnessMs: 45000
    readonly property string spatialLayout: ["horizon", "gallery", "deck", "atlas"].includes(orbitalOptions.layout)
        ? orbitalOptions.layout : "orbit"
    readonly property bool satellitePreviews: orbitalOptions.satellitePreviews ?? true
    readonly property string satelliteClickAction: orbitalOptions.satelliteClickAction === "enter"
        ? "enter" : "select"
    readonly property string workspaceLabelMode: {
        const configured = String(orbitalOptions.workspaceLabelMode ?? "")
        if (["index", "name", "workspace", "full", "off"].includes(configured))
            return configured
        return (orbitalOptions.showWorkspaceLabels ?? true) ? "index" : "off"
    }
    readonly property bool showWorkspaceLabels: workspaceLabelMode !== "off"
    readonly property bool showWorkspaceWallpaper: orbitalOptions.showWorkspaceWallpaper ?? true
    readonly property real workspaceWallpaperOpacity: Math.max(0, Math.min(100,
        orbitalOptions.workspaceWallpaperOpacity ?? 70)) / 100
    readonly property var surfaceOptions: orbitalOptions.surface ?? ({})
    readonly property var geometryOptions: orbitalOptions.geometry ?? ({})
    readonly property string workspaceSurfaceStyle: surfaceOptions.style === "ricelin" ? "ricelin" : "current"
    readonly property bool workspaceSurfaceOutline: surfaceOptions.outline ?? true
    readonly property int workspaceOutlineWidth: Math.max(0,
        Math.min(4, surfaceOptions.outlineWidth ?? 1))
    readonly property real workspaceOutlineOpacity: Math.max(0,
        Math.min(100, surfaceOptions.outlineOpacityPercent ?? 72)) / 100
    readonly property int workspaceFrameInset: Math.max(0,
        Math.min(18, surfaceOptions.frameInset ?? 5))
    readonly property string workspaceShadowMode: ["off", "core", "all"].includes(surfaceOptions.shadowMode)
        ? surfaceOptions.shadowMode : "core"
    readonly property real workspaceShadowOpacity: Math.max(0,
        Math.min(100, surfaceOptions.shadowOpacityPercent ?? 72)) / 100
    readonly property int satelliteSurfaceElevation: Math.max(0, Math.min(4, surfaceOptions.satelliteElevation ?? 1))
    readonly property real workspaceRadiusScale: Math.max(0.55,
        Math.min(1.6, (surfaceOptions.radiusPercent ?? 100) / 100))
    readonly property int orbitEdgePadding: Math.max(0, Math.min(48, geometryOptions.edgePadding ?? 10))
    readonly property int horizonGapOption: Math.max(0, Math.min(48, geometryOptions.horizonGap ?? 12))
    readonly property int horizonInsetOption: Math.max(0, Math.min(96, geometryOptions.horizonInset ?? 24))
    readonly property int horizonVerticalBaseOption: Math.max(0, Math.min(80, geometryOptions.horizonVerticalBase ?? 8))
    readonly property int horizonVerticalRangeOption: Math.max(0, Math.min(96, geometryOptions.horizonVerticalRange ?? 26))
    readonly property int galleryBaseGapOption: Math.max(0, Math.min(120, geometryOptions.galleryBaseGap ?? 34))
    readonly property int galleryRowGapOption: Math.max(0, Math.min(48, geometryOptions.galleryRowGap ?? 14))
    readonly property int deckBaseGapOption: Math.max(0, Math.min(120, geometryOptions.deckBaseGap ?? 26))
    readonly property int deckStepOption: Math.max(12, Math.min(120, geometryOptions.deckStep ?? 44))
    readonly property int deckLiftStepOption: Math.max(0, Math.min(80, geometryOptions.deckLiftStep ?? 24))
    readonly property int atlasGapOption: Math.max(0, Math.min(48, geometryOptions.atlasGap ?? 14))
    readonly property int atlasColumnsOption: Math.max(2, Math.min(3, geometryOptions.atlasColumns ?? 3))
    readonly property int atlasCoreBoostPercent: Math.max(0,
        Math.min(20, geometryOptions.atlasCoreBoostPercent ?? 10))
    readonly property int coreContentMargin: Math.max(0, Math.min(28, geometryOptions.coreContentMargin ?? 9))
    readonly property int satelliteContentMargin: Math.max(0, Math.min(24, geometryOptions.satelliteContentMargin ?? 6))
    readonly property string surfaceDialect: Appearance.surfaceDialectFor("")
    readonly property string hostBackdropBlurMode: {
        const configured = String(orbitOptions.backdropBlurMode ?? "")
        if (configured === "off") return "off"
        if (["shell", "inherit", "niri"].includes(configured)) return "shell"
        return (orbitOptions.backdropBlurEnable ?? true) ? "shell" : "off"
    }
    readonly property bool hostBackdropBlurActive: hostBackdropBlurMode === "shell"
        && Appearance.effectsEnabled
        && !GameMode.active
        && Math.max(0, Math.min(100, orbitOptions.backdropBlurStrength ?? 72)) > 0
    readonly property bool workspaceWallpaperFallback: !hostBackdropBlurActive
        && (surfaceDialect === "aurora" || surfaceDialect === "angel")
    readonly property color workspaceForeground: surfaceDialect === "zzz" ? Appearance.zzz.ink
        : surfaceDialect === "regalia" ? Appearance.regalia.onColor
        : surfaceDialect === "angel" ? Appearance.angel.colText
        : surfaceDialect === "inir" ? Appearance.inir.colText
        : Appearance.colors.colOnLayer1
    readonly property var workspacesForOutput: (NiriService.allWorkspaces ?? [])
        .filter(workspace => workspace.output === root.outputName && !root.isStashWorkspace(workspace.id))
        .sort((a, b) => a.idx - b.idx)
    readonly property int activeWorkspaceIndex: {
        const index = workspacesForOutput.findIndex(workspace => workspace.is_active)
        return index >= 0 ? index : 0
    }
    readonly property int visibleWorkspaceCount: Math.min(workspacesForOutput.length, maxVisibleWorkspaces)
    readonly property int visibleSatelliteCount: Math.max(0, visibleWorkspaceCount - 1)
    readonly property var displayedWorkspaces: {
        void root.selectedWorkspaceIndex
        const result = []
        for (let i = 0; i < root.workspacesForOutput.length; ++i) {
            if (!root.workspaceVisible(i)) continue
            result.push({
                workspace: root.workspacesForOutput[i],
                workspaceId: root.workspacesForOutput[i].id,
                workspaceIndex: i
            })
        }
        return result
    }
    property int selectedWorkspaceId: workspacesForOutput.length > 0
        ? (workspacesForOutput[activeWorkspaceIndex]?.id ?? -1) : -1
    readonly property int selectedWorkspaceIndex: {
        const index = workspacesForOutput.findIndex(workspace => workspace.id === selectedWorkspaceId)
        return index >= 0 ? index : activeWorkspaceIndex
    }
    readonly property var selectedWorkspace: selectedWorkspaceIndex >= 0
        && selectedWorkspaceIndex < workspacesForOutput.length
        ? workspacesForOutput[selectedWorkspaceIndex] : null
    readonly property var keyboardWindows: selectedWorkspace
        ? root.windowsForWorkspace(selectedWorkspace.id) : []
    property int keyboardWindowIndex: -1
    property real wheelAngleAccumulator: 0
    property real wheelPixelAccumulator: 0
    property int wheelEventCount: 0
    property real lastWheelAngle: 0
    property real lastWheelPixels: 0
    readonly property int wheelStepsRequired: Math.max(1, root.orbitOptions.scrollSteps ?? 1)
    readonly property int keyboardWindowId: keyboardWindowIndex >= 0
        && keyboardWindowIndex < keyboardWindows.length
        ? keyboardWindows[keyboardWindowIndex].id : -1

    property var contextWindowData: null
    property Item contextAnchorItem: root
    property var contextAnchorRect: null
    property bool stashDropHovered: false
    property bool newWorkspaceDropHovered: false

    function workspaceLabel(workspace): string {
        const index = workspace?.idx ?? "–"
        const name = String(workspace?.name ?? "").trim()
        if (root.workspaceLabelMode === "full")
            return name.length > 0 ? `${index} · ${name}` : Translation.tr("Workspace %1").arg(index)
        if (root.workspaceLabelMode === "workspace")
            return Translation.tr("Workspace %1").arg(index)
        if (root.workspaceLabelMode === "name")
            return name.length > 0 ? name : Translation.tr("Unnamed")
        return String(index)
    }

    function visualState(): var {
        const cards = []
        for (let i = 0; i < workspaceRepeater.count; ++i) {
            const card = workspaceRepeater.itemAt(i)
            if (!card) continue
            cards.push({
                workspaceId: card.workspaceObj?.id ?? -1,
                core: card.isCore,
                label: root.workspaceLabel(card.workspaceObj),
                x: card.x,
                y: card.y,
                width: card.width,
                height: card.height,
                scale: card.scale,
                opacity: card.opacity,
                z: card.z
            })
        }
        return {
            layout: root.spatialLayout,
            selectedWorkspaceId: root.selectedWorkspaceId,
            motion: {
                preset: root.navigationPreset,
                durationMs: root.transitionDurationMs,
                easing: root.navigationEasing
            },
            cards,
            scroll: {
                enabled: root.orbitOptions.scrollNavigation ?? true,
                ticksPerWorkspace: root.wheelStepsRequired,
                switchWorkspace: root.orbitOptions.scrollSwitchWorkspace ?? true,
                wrapAround: root.orbitOptions.scrollWrapAround ?? false,
                eventCount: root.wheelEventCount,
                lastAngle: root.lastWheelAngle,
                lastPixels: root.lastWheelPixels,
                angleAccumulator: root.wheelAngleAccumulator,
                pixelAccumulator: root.wheelPixelAccumulator
            }
        }
    }

    readonly property int coreWidth: {
        const byWidth = width * root.coreSizePercent / 100
        const byHeight = height * 0.6 * 16 / 9
        return Math.max(1, Math.round(Math.min(byWidth, byHeight)))
    }
    readonly property int coreHeight: Math.max(1, Math.round(coreWidth * 9 / 16))
    readonly property int satelliteWidth: Math.max(1,
        Math.round(coreWidth * root.satelliteSizePercent / 100))
    readonly property int satelliteHeight: Math.max(1, Math.round(satelliteWidth * 9 / 16))
    // Spatial spread is a percentage of the *actual travel available* to the
    // satellite center. The previous ringHeight/ringWidth max() formulation
    // could clamp the whole configured range, making e.g. Vertical spread a
    // no-op on 1080p outputs.
    readonly property real maxOrbitRadiusX: Math.max(0,
        (width - satelliteWidth) / 2 - root.orbitEdgePadding)
    readonly property real maxOrbitRadiusY: Math.max(0,
        (height - satelliteHeight) / 2 - root.orbitEdgePadding)
    readonly property real orbitRadiusX: maxOrbitRadiusX * root.horizontalSpreadPercent / 100
    readonly property real orbitRadiusY: maxOrbitRadiusY * root.verticalSpreadPercent / 100

    implicitWidth: Math.max(1, Math.floor(availableWidth))
    implicitHeight: Math.max(1, Math.floor(availableHeight))
    width: implicitWidth
    height: implicitHeight

    function isStashWorkspace(workspaceId): bool {
        const windows = (NiriService.windows ?? []).filter(window => window.workspace_id === workspaceId)
        return windows.length > 0 && windows.every(window => MinimizedWindows.isMinimized(window.id))
    }

    function windowsForWorkspace(workspaceId): var {
        return (NiriService.windows ?? []).filter(window => window.workspace_id === workspaceId
            && !MinimizedWindows.isMinimized(window.id) && root.windowMatchesFilter(window))
    }

    function windowMatchesFilter(windowData): bool {
        const query = root.filterText.trim().toLowerCase()
        if (query.length === 0)
            return true
        const title = String(windowData?.title ?? "").toLowerCase()
        const appId = String(windowData?.app_id ?? windowData?.appId ?? "").toLowerCase()
        return title.includes(query) || appId.includes(query)
    }

    function relativeOffset(index: int): int {
        const count = root.workspacesForOutput.length
        if (count <= 1) return 0
        let diff = index - root.selectedWorkspaceIndex
        const half = Math.floor(count / 2)
        if (diff > half) diff -= count
        if (diff < -half) diff += count
        return diff
    }

    function workspaceVisible(index: int): bool {
        if (root.workspacesForOutput.length <= root.maxVisibleWorkspaces)
            return true
        const radius = Math.floor((root.maxVisibleWorkspaces - 1) / 2)
        return Math.abs(root.relativeOffset(index)) <= radius
    }

    function satelliteAngle(index: int): real {
        const offset = root.relativeOffset(index)
        if (offset === 0)
            return -Math.PI / 2
        const maxRank = Math.max(1, Math.ceil(root.visibleSatelliteCount / 2))
        const normalized = Math.max(0, Math.min(1,
            (offset + maxRank) / (maxRank * 2)))
        return Math.PI * (1.08 + normalized * 0.84)
    }

    function normalizeSelection(): void {
        if (root.workspacesForOutput.length === 0) {
            root.selectedWorkspaceId = -1
            root.keyboardWindowIndex = -1
            return
        }
        if (!root.workspacesForOutput.some(workspace => workspace.id === root.selectedWorkspaceId))
            root.selectedWorkspaceId = root.workspacesForOutput[root.activeWorkspaceIndex]?.id ?? -1
        root.ensureKeyboardWindow()
        root.syncPreviews()
    }

    function syncPreviews(): void {
        if (!GlobalStates.overviewOpen) return
        const coreIds = []
        const satelliteIds = []
        for (let i = 0; i < root.workspacesForOutput.length; ++i) {
            if (!root.workspaceVisible(i)) continue
            if (!root.satellitePreviews && i !== root.selectedWorkspaceIndex) continue
            const target = i === root.selectedWorkspaceIndex ? coreIds : satelliteIds
            for (const window of root.windowsForWorkspace(root.workspacesForOutput[i].id))
                target.push(window.id)
        }
        // Core is what the user is actively inspecting, so keep it reasonably
        // fresh. Satellites may reuse older snapshots until they become Core.
        // Both calls are coalesced by WindowPreviewService into one capture pass.
        if (coreIds.length > 0)
            WindowPreviewService.captureForTaskView(coreIds, root.corePreviewFreshnessMs)
        if (satelliteIds.length > 0)
            WindowPreviewService.captureForTaskView(satelliteIds, root.satellitePreviewFreshnessMs)
    }

    function selectWorkspace(index: int): void {
        if (root.workspacesForOutput.length === 0) return
        const count = root.workspacesForOutput.length
        const normalizedIndex = ((index % count) + count) % count
        root.selectedWorkspaceId = root.workspacesForOutput[normalizedIndex]?.id ?? -1
        root.keyboardWindowIndex = -1
        root.syncPreviews()
    }

    function relativeWorkspaceIndex(baseIndex: int, direction: int, wrapAround: bool): int {
        const count = root.workspacesForOutput.length
        if (count <= 0)
            return -1
        const target = baseIndex + direction
        if (wrapAround)
            return ((target % count) + count) % count
        return Math.max(0, Math.min(count - 1, target))
    }

    function focusRelativeWorkspace(direction: int, wrapAround): void {
        const shouldWrap = wrapAround === undefined ? true : Boolean(wrapAround)
        const targetIndex = root.relativeWorkspaceIndex(root.selectedWorkspaceIndex,
            direction, shouldWrap)
        if (targetIndex < 0 || targetIndex === root.selectedWorkspaceIndex)
            return
        root.selectWorkspace(targetIndex)
    }

    function switchRelativeWorkspace(direction: int, wrapAround): void {
        const shouldWrap = wrapAround === undefined
            ? (root.orbitOptions.scrollWrapAround ?? false) : Boolean(wrapAround)
        const workspaces = root.workspacesForOutput
        if (!workspaces || workspaces.length < 2 || !NiriService.actionReady)
            return
        // Advance from the optimistic Orbit selection, not Niri's last published
        // active workspace. This keeps rapid wheel/key navigation responsive even
        // while the compositor is still reporting the previous transition.
        const currentIndex = root.selectedWorkspaceIndex
        const targetIndex = root.relativeWorkspaceIndex(currentIndex, direction, shouldWrap)
        if (targetIndex === currentIndex)
            return
        const target = workspaces[targetIndex]
        if (!target)
            return
        root.selectedWorkspaceId = target.id
        root.keyboardWindowIndex = -1
        root.syncPreviews()
        NiriService.switchToWorkspaceById(target.id)
    }

    function focusNextWindow(): void {
        const count = root.keyboardWindows.length
        if (count === 0) return
        root.keyboardWindowIndex = root.keyboardWindowIndex < 0
            ? 0 : (root.keyboardWindowIndex + 1) % count
    }

    function focusPreviousWindow(): void {
        const count = root.keyboardWindows.length
        if (count === 0) return
        root.keyboardWindowIndex = root.keyboardWindowIndex < 0
            ? count - 1 : (root.keyboardWindowIndex - 1 + count) % count
    }

    function ensureKeyboardWindow(): void {
        if (root.keyboardWindows.length === 0) {
            root.keyboardWindowIndex = -1
            return
        }
        if (root.keyboardWindowIndex < 0 || root.keyboardWindowIndex >= root.keyboardWindows.length)
            root.keyboardWindowIndex = 0
    }

    function focusFirstWindow(): void {
        root.keyboardWindowIndex = root.keyboardWindows.length > 0 ? 0 : -1
    }

    function focusLastWindow(): void {
        root.keyboardWindowIndex = root.keyboardWindows.length > 0
            ? root.keyboardWindows.length - 1 : -1
    }

    function moveKeyboardWindow(horizontal: int, vertical: int): void {
        if (horizontal !== 0) {
            root.focusRelativeWorkspace(horizontal)
            root.ensureKeyboardWindow()
            return
        }
        const count = root.keyboardWindows.length
        if (count === 0) return
        root.ensureKeyboardWindow()
        if (vertical < 0) root.focusPreviousWindow()
        else if (vertical > 0) root.focusNextWindow()
    }

    function moveKeyboardWindowToRelativeWorkspace(direction: int): void {
        root.ensureKeyboardWindow()
        if (root.keyboardWindowId < 0 || !NiriService.actionReady || !root.selectedWorkspace)
            return
        const count = root.workspacesForOutput.length
        if (count < 2) return
        const targetIndex = ((root.selectedWorkspaceIndex + direction) % count + count) % count
        const target = root.workspacesForOutput[targetIndex]
        if (target && NiriService.moveWindowToWorkspaceById(root.keyboardWindowId, target.id, false)) {
            root.keyboardWindowIndex = -1
            root.selectWorkspace(targetIndex)
        }
    }

    function activateKeyboardWindow(): void {
        root.ensureKeyboardWindow()
        if (root.keyboardWindowId >= 0) {
            NiriService.focusWindow(root.keyboardWindowId)
            if (root.orbitOptions.closeOnSelect ?? true)
                GlobalStates.closeOverview()
            return
        }
        if (root.selectedWorkspace) {
            NiriService.switchToWorkspaceById(root.selectedWorkspace.id)
            GlobalStates.closeOverview()
        }
    }

    function activateSelectedWorkspace(): void {
        if (!root.selectedWorkspace) return
        NiriService.switchToWorkspaceById(root.selectedWorkspace.id)
        GlobalStates.closeOverview()
    }

    function resetSelectionToActive(): void {
        root.selectedWorkspaceId = root.workspacesForOutput[root.activeWorkspaceIndex]?.id ?? -1
        root.keyboardWindowIndex = -1
        root.ensureKeyboardWindow()
        root.syncPreviews()
    }

    function selectWorkspaceNumber(number: int): void {
        const index = root.workspacesForOutput.findIndex(workspace => workspace.idx === number)
        if (index >= 0)
            root.selectWorkspace(index)
    }

    function closeKeyboardWindow(): void {
        root.ensureKeyboardWindow()
        if (root.keyboardWindowId < 0) return
        NiriService.closeWindow(root.keyboardWindowId)
        root.keyboardWindowIndex = -1
    }

    function stashKeyboardWindow(): void {
        root.ensureKeyboardWindow()
        if (root.keyboardWindowId < 0 || !(root.orbitOptions.showStash ?? true)) return
        MinimizedWindows.minimize(root.keyboardWindowId)
        root.keyboardWindowIndex = -1
    }

    function openKeyboardWindowContext(): void {
        root.ensureKeyboardWindow()
        if (root.keyboardWindowId < 0) return
        const window = root.keyboardWindows[root.keyboardWindowIndex]
        if (!window) return
        root.openWindowContext(window, root.width / 2, root.height / 2)
    }

    function moveDraggedWindowToWorkspace(windowData, workspaceId): bool {
        if (!windowData || workspaceId <= 0 || !NiriService.actionReady) return false
        if (windowData.workspace_id === workspaceId) return true
        return NiriService.moveWindowToWorkspaceById(windowData.id, workspaceId, false)
    }

    function moveDraggedWindowToNewWorkspace(windowData): bool {
        const trailing = root.workspacesForOutput.length > 0
            ? root.workspacesForOutput[root.workspacesForOutput.length - 1] : null
        return trailing ? root.moveDraggedWindowToWorkspace(windowData, trailing.id) : false
    }

    function openWindowContext(windowData, x: real, y: real): void {
        if (!windowData) return
        root.contextWindowData = windowData
        root.contextAnchorRect = { x: x, y: y, width: 1, height: 1 }
        windowContextMenu.requestOpen()
    }

    function contextWorkspaceNeighbor(delta: int): var {
        if (!root.contextWindowData)
            return null
        const index = root.workspacesForOutput.findIndex(workspace =>
            workspace.id === root.contextWindowData.workspace_id)
        const targetIndex = index + delta
        if (index < 0 || targetIndex < 0 || targetIndex >= root.workspacesForOutput.length)
            return null
        return root.workspacesForOutput[targetIndex]
    }

    function contextMenuModel(): var {
        if (!root.contextWindowData) return []
        const windowId = root.contextWindowData.id
        const previousWorkspace = root.contextWorkspaceNeighbor(-1)
        const nextWorkspace = root.contextWorkspaceNeighbor(1)
        return [
            {
                text: Translation.tr("Focus window"),
                iconName: "center_focus_strong",
                monochromeIcon: true,
                action: () => {
                    NiriService.focusWindow(windowId)
                    if (root.orbitOptions.closeOnSelect ?? true)
                        GlobalStates.closeOverview()
                }
            },
            {
                text: Translation.tr("Stash in Pocket"),
                iconName: "inventory_2",
                monochromeIcon: true,
                enabled: (root.orbitOptions.showStash ?? true) && MinimizedWindows.actionReady,
                action: () => MinimizedWindows.minimize(windowId)
            },
            { type: "separator" },
            {
                text: Translation.tr("Move to previous workspace"),
                iconName: "arrow_back",
                monochromeIcon: true,
                enabled: previousWorkspace !== null,
                action: () => {
                    if (previousWorkspace)
                        NiriService.moveWindowToWorkspaceById(windowId, previousWorkspace.id, false)
                }
            },
            {
                text: Translation.tr("Move to next workspace"),
                iconName: "arrow_forward",
                monochromeIcon: true,
                enabled: nextWorkspace !== null,
                action: () => {
                    if (nextWorkspace)
                        NiriService.moveWindowToWorkspaceById(windowId, nextWorkspace.id, false)
                }
            },
            { type: "separator" },
            {
                text: Translation.tr("Close window"),
                iconName: "close",
                monochromeIcon: true,
                action: () => NiriService.closeWindow(windowId)
            }
        ]
    }

    MouseArea {
        id: canvasScrubArea
        anchors.fill: parent
        z: 1
        enabled: root.orbitOptions.canvasScrubNavigation ?? true
        acceptedButtons: Qt.RightButton
        preventStealing: true
        // Canvas scrub owns only deliberate RMB drags. Wheel and touchpad
        // scrolling belong to the workspace navigator behind this area.
        scrollGestureEnabled: false
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor
        property real lastStepX: 0

        onPressed: mouse => lastStepX = mouse.x
        onWheel: event => event.accepted = false
        onPositionChanged: mouse => {
            if (!pressed)
                return
            const threshold = Math.max(48,
                Math.min(180, root.orbitOptions.canvasScrubThreshold ?? 96))
            let delta = mouse.x - lastStepX
            while (Math.abs(delta) >= threshold) {
                const direction = delta < 0 ? 1 : -1
                root.focusRelativeWorkspace(direction)
                lastStepX += (delta < 0 ? -threshold : threshold)
                delta = mouse.x - lastStepX
            }
        }
    }

    Repeater {
        id: workspaceRepeater
        model: ScriptModel {
            values: root.displayedWorkspaces
            objectProp: "workspaceId"
        }

        delegate: Item {
            id: workspaceCard
            required property var modelData
            required property int index
            readonly property int workspaceId: modelData?.workspaceId ?? modelData?.workspace?.id ?? -1
            readonly property var workspaceObj: root.workspacesForOutput
                .find(workspace => workspace.id === workspaceId) ?? modelData?.workspace ?? null
            readonly property int workspaceIndex: {
                const liveIndex = root.workspacesForOutput.findIndex(workspace => workspace.id === workspaceId)
                return liveIndex >= 0 ? liveIndex : (modelData?.workspaceIndex ?? -1)
            }

            // ScriptModel updates asynchronously when Niri creates/removes its
            // trailing empty workspace. Identity must not depend on a transient
            // array index or the wrong card can become core mid-transition.
            readonly property bool isCore: workspaceId >= 0 && workspaceId === root.selectedWorkspaceId
            readonly property bool isActive: workspaceObj?.is_active ?? false
            readonly property int offset: root.relativeOffset(workspaceIndex)
            readonly property real angle: root.satelliteAngle(workspaceIndex)
            readonly property int satelliteRank: Math.max(1, Math.abs(offset))
            readonly property int entryOrdinal: isCore ? 0
                : root.spatialLayout === "horizon" ? horizonSlot + 1
                : root.spatialLayout === "gallery" ? gallerySlot + 1
                : root.spatialLayout === "atlas" ? atlasRow + atlasColumn + 1
                : satelliteRank
            readonly property real entryDelayProgress: root.entryCascade && root.entryDurationMs > 0
                ? Math.min(0.58, entryOrdinal * root.entryStaggerMs / root.entryDurationMs) : 0
            readonly property real entryLocalProgress: root.entryCascade
                ? Math.max(0, Math.min(1,
                    (root.entryProgress - entryDelayProgress) / Math.max(0.01, 1 - entryDelayProgress)))
                : root.entryProgress
            readonly property int maxSatelliteRank: Math.max(1, Math.ceil(root.visibleSatelliteCount / 2))
            readonly property real horizonProgress: maxSatelliteRank <= 1 ? 0
                : (satelliteRank - 1) / (maxSatelliteRank - 1)
            readonly property real depthPosition: root.spatialLayout === "horizon"
                ? 1 - horizonProgress * 0.82
                : root.spatialLayout === "gallery"
                    ? Math.max(0.18, 1 - (satelliteRank - 1) * 0.26)
                : root.spatialLayout === "deck"
                    ? Math.max(0.42, 1 - (satelliteRank - 1) * 0.14)
                : root.spatialLayout === "atlas" ? 0.92
                : Math.max(0.58, 1 - (satelliteRank - 1) * 0.14)
            readonly property real sceneAxisX: isCore ? 0
                : root.spatialLayout === "orbit" ? Math.cos(angle)
                : root.spatialLayout === "gallery" ? (offset < 0 ? -0.72 : 0.72)
                : root.spatialLayout === "deck" ? (offset < 0 ? -0.62 : 0.62)
                : root.spatialLayout === "atlas" ? atlasAxisX
                : root.visibleSatelliteCount <= 1 ? 0
                : (horizonSlot / Math.max(1, root.visibleSatelliteCount - 1)) * 2 - 1
            readonly property real sceneAxisY: isCore ? 0
                : root.spatialLayout === "orbit" ? Math.sin(angle)
                : root.spatialLayout === "gallery" ? Math.max(-0.8, Math.min(0.8,
                    (satelliteRank - 1) * 0.34 * (offset < 0 ? -1 : 1)))
                : root.spatialLayout === "deck" ? Math.max(-0.72, Math.min(0.72,
                    (satelliteRank - 1) * 0.20 * (offset < 0 ? -1 : 1)))
                : root.spatialLayout === "atlas" ? atlasAxisY : 0.48
            readonly property real entryOffsetX: (1 - entryLocalProgress) * (isCore ? 0
                : root.spatialLayout === "orbit" ? -sceneAxisX * 52
                : root.spatialLayout === "horizon" ? -42
                : root.spatialLayout === "gallery" ? -gallerySide * 44
                : root.spatialLayout === "deck" ? -gallerySide * (deckReach * 0.28 + 18)
                : root.spatialLayout === "atlas" ? -atlasAxisX * 28 : 0)
            readonly property real entryOffsetY: (1 - entryLocalProgress) * (isCore
                ? (root.spatialLayout === "horizon" ? -18
                    : root.spatialLayout === "deck" ? 12 : 8)
                : root.spatialLayout === "orbit" ? -sceneAxisY * 38
                : root.spatialLayout === "horizon" ? 24
                : root.spatialLayout === "gallery" ? 0
                : root.spatialLayout === "deck" ? -deckLift
                : root.spatialLayout === "atlas" ? -atlasAxisY * 24 : 0)
            readonly property real configuredDepthScale: 1
                - (root.depthPercent / 100) * (1 - depthPosition)
            readonly property real depthScale: configuredDepthScale
            readonly property var workspaceWindows: workspaceObj ? root.windowsForWorkspace(workspaceObj.id) : []
            readonly property real ringRadiusX: root.orbitRadiusX
            readonly property real ringRadiusY: root.orbitRadiusY
            readonly property int horizonSlot: {
                const satellites = root.displayedWorkspaces
                    .filter(entry => entry.workspaceIndex !== root.selectedWorkspaceIndex)
                return satellites.findIndex(entry => entry.workspaceIndex === workspaceIndex)
            }
            readonly property int horizonCount: Math.max(1, root.visibleSatelliteCount)
            readonly property int horizonGap: root.horizonGapOption
            readonly property int horizonRailWidth: Math.max(1,
                Math.round(root.width * root.horizontalSpreadPercent / 100) - root.horizonInsetOption)
            readonly property int horizonCardWidth: Math.max(1, Math.floor(Math.min(
                root.coreWidth * root.satelliteSizePercent / 100,
                (horizonRailWidth - horizonGap * Math.max(0, horizonCount - 1)) / horizonCount)))
            readonly property int horizonCardHeight: Math.max(1, Math.round(horizonCardWidth * 9 / 16))
            readonly property int horizonGroupWidth: horizonCardWidth * horizonCount
                + horizonGap * Math.max(0, horizonCount - 1)
            readonly property int horizonStartX: Math.max(8, Math.round((root.width - horizonGroupWidth) / 2))
            readonly property int horizonVerticalGap: Math.round(root.horizonVerticalBaseOption
                + (root.verticalSpreadPercent - 40) / 42 * root.horizonVerticalRangeOption)
            readonly property int horizonStackHeight: root.coreHeight + horizonVerticalGap + horizonCardHeight
            readonly property int horizonTop: Math.max(8, Math.round((root.height - horizonStackHeight) / 2))
            readonly property int gallerySide: offset < 0 ? -1 : 1
            readonly property var gallerySideEntries: root.displayedWorkspaces.filter(entry => {
                const relative = root.relativeOffset(entry.workspaceIndex)
                return relative !== 0 && (relative < 0) === (offset < 0)
            })
            readonly property int gallerySlot: Math.max(0,
                gallerySideEntries.findIndex(entry => entry.workspaceIndex === workspaceIndex))
            readonly property int galleryCount: Math.max(1, gallerySideEntries.length)
            readonly property int galleryAvailableWidth: Math.max(1, Math.floor(
                (root.width - root.coreWidth) / 2 - root.galleryBaseGapOption - root.orbitEdgePadding * 2))
            readonly property int galleryCardWidth: Math.max(1, Math.min(root.satelliteWidth,
                galleryAvailableWidth))
            readonly property int galleryCardHeight: Math.max(1, Math.round(galleryCardWidth * 9 / 16))
            readonly property int galleryGroupHeight: galleryCardHeight * galleryCount
                + root.galleryRowGapOption * Math.max(0, galleryCount - 1)
            readonly property int galleryStartY: Math.round((root.height - galleryGroupHeight) / 2)
            readonly property int galleryColumnX: gallerySide < 0
                ? Math.round(root.width / 2 - root.coreWidth / 2
                    - root.galleryBaseGapOption - galleryCardWidth)
                : Math.round(root.width / 2 + root.coreWidth / 2 + root.galleryBaseGapOption)
            readonly property real deckReach: root.coreWidth * 0.5
                + root.satelliteWidth * 0.22 + root.deckBaseGapOption
                + (satelliteRank - 1) * root.deckStepOption
            readonly property real deckLift: (satelliteRank - 1) * root.deckLiftStepOption
                * (offset < 0 ? -1 : 1)
            readonly property int atlasColumns: Math.min(root.atlasColumnsOption,
                Math.max(1, root.displayedWorkspaces.length))
            readonly property int atlasRows: Math.max(1,
                Math.ceil(root.displayedWorkspaces.length / Math.max(1, atlasColumns)))
            readonly property int atlasSlot: index
            readonly property int atlasColumn: atlasSlot % Math.max(1, atlasColumns)
            readonly property int atlasRow: Math.floor(atlasSlot / Math.max(1, atlasColumns))
            readonly property int atlasUsableWidth: Math.max(1, root.width
                - root.orbitEdgePadding * 2 - root.atlasGapOption * Math.max(0, atlasColumns - 1))
            readonly property int atlasUsableHeight: Math.max(1, root.height
                - root.orbitEdgePadding * 2 - root.atlasGapOption * Math.max(0, atlasRows - 1))
            readonly property real atlasMaxScale: 1 + root.atlasCoreBoostPercent / 100
            readonly property int atlasCellWidth: Math.max(1, Math.floor(Math.min(
                atlasUsableWidth / Math.max(1, atlasColumns) / atlasMaxScale,
                atlasUsableHeight / Math.max(1, atlasRows) * 16 / 9 / atlasMaxScale)))
            readonly property int atlasCellHeight: Math.max(1, Math.round(atlasCellWidth * 9 / 16))
            readonly property int atlasSlotWidth: Math.max(1, Math.round(atlasCellWidth * atlasMaxScale))
            readonly property int atlasSlotHeight: Math.max(1, Math.round(atlasCellHeight * atlasMaxScale))
            readonly property int atlasGroupWidth: atlasSlotWidth * atlasColumns
                + root.atlasGapOption * Math.max(0, atlasColumns - 1)
            readonly property int atlasGroupHeight: atlasSlotHeight * atlasRows
                + root.atlasGapOption * Math.max(0, atlasRows - 1)
            readonly property int atlasStartX: Math.round((root.width - atlasGroupWidth) / 2)
            readonly property int atlasStartY: Math.round((root.height - atlasGroupHeight) / 2)
            readonly property real atlasAxisX: atlasColumns <= 1 ? 0
                : (atlasColumn / Math.max(1, atlasColumns - 1)) * 2 - 1
            readonly property real atlasAxisY: atlasRows <= 1 ? 0
                : (atlasRow / Math.max(1, atlasRows - 1)) * 2 - 1
            readonly property int cardWidth: root.spatialLayout === "atlas"
                ? atlasCellWidth
                : isCore ? root.coreWidth
                : root.spatialLayout === "horizon"
                    ? Math.max(1, Math.round(horizonCardWidth * depthScale))
                : root.spatialLayout === "gallery"
                    ? galleryCardWidth
                : root.spatialLayout === "deck"
                    ? Math.max(1, Math.round(root.satelliteWidth * depthScale * 0.98))
                : Math.max(1, Math.round(root.satelliteWidth * depthScale))
            readonly property int cardHeight: root.spatialLayout === "atlas"
                ? atlasCellHeight
                : isCore ? root.coreHeight
                : root.spatialLayout === "horizon"
                    ? Math.max(1, Math.round(horizonCardHeight * depthScale))
                : root.spatialLayout === "gallery"
                    ? galleryCardHeight
                : root.spatialLayout === "deck"
                    ? Math.max(1, Math.round(root.satelliteHeight * depthScale * 0.98))
                : Math.max(1, Math.round(root.satelliteHeight * depthScale))
            property bool dropHovered: false
            readonly property real satelliteOpacity: dropHovered ? 0.98
                : root.spatialLayout === "horizon" ? 0.92
                : root.spatialLayout === "gallery" ? 0.94
                : root.spatialLayout === "deck" ? 0.84 + depthPosition * 0.12
                : root.spatialLayout === "atlas" ? 0.94
                : 0.74 + depthPosition * 0.20

            visible: workspaceObj !== null
            width: cardWidth
            height: cardHeight
            x: Math.round(isCore
                ? (root.spatialLayout === "atlas"
                    ? atlasStartX + atlasColumn * (atlasSlotWidth + root.atlasGapOption)
                        + (atlasSlotWidth - width) / 2
                    : (root.width - width) / 2)
                    + entryOffsetX
                : root.spatialLayout === "horizon"
                    ? horizonStartX + horizonSlot * (horizonCardWidth + horizonGap)
                        + (horizonCardWidth - width) / 2
                        + entryOffsetX
                    : root.spatialLayout === "gallery"
                        ? galleryColumnX + entryOffsetX
                    : root.spatialLayout === "deck"
                        ? root.width / 2 - width / 2
                            + gallerySide * deckReach
                            + entryOffsetX
                    : root.spatialLayout === "atlas"
                        ? atlasStartX + atlasColumn * (atlasSlotWidth + root.atlasGapOption)
                            + (atlasSlotWidth - width) / 2
                            + entryOffsetX
                    : root.width / 2
                        + Math.cos(angle) * ringRadiusX * (0.78 + depthPosition * 0.34)
                        - width / 2
                        + entryOffsetX)
            y: Math.round(isCore
                ? (root.spatialLayout === "atlas"
                    ? atlasStartY + atlasRow * (atlasSlotHeight + root.atlasGapOption)
                        + (atlasSlotHeight - height) / 2
                    : root.spatialLayout === "horizon"
                    ? horizonTop + entryOffsetY
                    : root.spatialLayout === "orbit"
                        ? root.height * 0.57 - height / 2 + entryOffsetY
                    : (root.height - height) / 2 + entryOffsetY)
                : root.spatialLayout === "horizon"
                    ? horizonTop + root.coreHeight + horizonVerticalGap
                        + (horizonCardHeight - height) / 2
                        + entryOffsetY
                    : root.spatialLayout === "gallery"
                        ? galleryStartY + gallerySlot * (galleryCardHeight + root.galleryRowGapOption)
                            + entryOffsetY
                    : root.spatialLayout === "deck"
                        ? root.height / 2 - height / 2 + deckLift
                            + entryOffsetY
                    : root.spatialLayout === "atlas"
                        ? atlasStartY + atlasRow * (atlasSlotHeight + root.atlasGapOption)
                            + (atlasSlotHeight - height) / 2
                            + entryOffsetY
                    : root.height / 2
                        + Math.sin(angle) * ringRadiusY * (0.82 + depthPosition * 0.28)
                        - height / 2
                        + entryOffsetY)
            // Stacking is deliberately stable for satellites. Previously z followed
            // selected-relative depth immediately while geometry was still moving,
            // which made cards pop behind/in front of one another mid-transition.
            z: isCore ? 100 : 20 + workspaceIndex * 0.01
            scale: 1
            opacity: (isCore ? 1 : satelliteOpacity) * entryLocalProgress

            Behavior on opacity {
                enabled: Appearance.animationsEnabled && root.transitionDurationMs > 0
                    && root.entryProgress >= 1
                NumberAnimation { duration: root.transitionDurationMs; easing.type: root.navigationEasingType }
            }

            Behavior on x {
                enabled: Appearance.animationsEnabled && root.transitionDurationMs > 0
                    && root.entryProgress >= 1
                NumberAnimation { duration: root.transitionDurationMs; easing.type: root.navigationEasingType }
            }
            Behavior on y {
                enabled: Appearance.animationsEnabled && root.transitionDurationMs > 0
                    && root.entryProgress >= 1
                NumberAnimation { duration: root.transitionDurationMs; easing.type: root.navigationEasingType }
            }
            Behavior on width {
                enabled: Appearance.animationsEnabled && root.transitionDurationMs > 0
                    && root.spatialLayout !== "atlas"
                NumberAnimation { duration: root.transitionDurationMs; easing.type: root.navigationEasingType }
            }
            Behavior on height {
                enabled: Appearance.animationsEnabled && root.transitionDurationMs > 0
                    && root.spatialLayout !== "atlas"
                NumberAnimation { duration: root.transitionDurationMs; easing.type: root.navigationEasingType }
            }
            StyledRectangularShadow {
                target: workspaceSurface
                radius: workspaceSurface._radius
                visible: root.workspaceShadowMode === "all"
                    || (root.workspaceShadowMode === "core" && workspaceCard.isCore)
                opacity: root.workspaceShadowOpacity
            }

            PanelSurface {
                id: workspaceSurface
                anchors.fill: parent
                // Keep the material layer stable while focus moves. Changing an integer
                // elevation mid-flight swaps surface colors/shadows at a discrete frame.
                elevation: root.satelliteSurfaceElevation
                cardStyle: true
                outlined: false
                clipContent: true
                islandSkin: root.workspaceSurfaceStyle === "ricelin"
                surfaceDialect: root.workspaceSurfaceStyle === "ricelin" ? "island" : root.surfaceDialect
                radiusOverride: root.workspaceSurfaceStyle === "ricelin"
                    ? (Config.options?.appearance?.island?.radius ?? 18) * root.workspaceRadiusScale
                    : Appearance.rounding.normal * root.workspaceRadiusScale
                wallpaperBackdrop: root.workspaceWallpaperFallback

                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: root.workspaceFrameInset
                    radius: Math.max(0, workspaceSurface._radius - root.workspaceFrameInset)
                    color: "transparent"

                    Image {
                        anchors.fill: parent
                        source: root.wallpaperPath
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        smooth: true
                        // All workspace cards use the same bounded decode size so
                        // Qt can share the cached image instead of decoding a 4K
                        // wallpaper for thumbnail-sized surfaces.
                        sourceSize.width: Math.max(1, Math.round(root.coreWidth * 2))
                        sourceSize.height: Math.max(1, Math.round(root.coreHeight * 2))
                        visible: root.showWorkspaceWallpaper && source.toString().length > 0
                        opacity: root.workspaceWallpaperOpacity * (workspaceCard.isCore ? 1 : 0.82)
                    }
                }

                Item {
                    id: workspaceContent
                    z: 2
                    anchors.fill: parent
                    // Keep the inner grid stable while workspace focus moves. A
                    // changing inset reflows every preview during the transition.
                    anchors.margins: root.workspaceFrameInset + root.satelliteContentMargin
                    clip: true

                    Repeater {
                        id: windowRepeater
                        model: workspaceCard.workspaceWindows

                        delegate: Item {
                            id: windowItem
                            required property var modelData
                            required property int index

                            readonly property int windowId: modelData?.id ?? -1
                            readonly property int count: workspaceCard.workspaceWindows.length
                            readonly property int columns: count <= 1 ? 1
                                : count <= 4 ? 2 : Math.ceil(Math.sqrt(count))
                            readonly property int rows: Math.max(1, Math.ceil(count / columns))
                            readonly property int configuredGap: Math.max(0, Math.min(16,
                                root.orbitOptions.windowGap ?? 4))
                            readonly property real gap: Math.max(1, configuredGap)
                            readonly property real cellWidth: workspaceContent.width / columns
                            readonly property real cellHeight: workspaceContent.height / rows
                            readonly property bool keyboardSelected: workspaceCard.isCore
                                && root.keyboardWindowId === windowId
                            property bool hovered: false
                            property int previewRevision: 0

                            x: Math.round((index % columns) * cellWidth + gap)
                            y: Math.round(Math.floor(index / columns) * cellHeight + gap)
                            width: Math.max(8, Math.round(cellWidth - gap * 2))
                            height: Math.max(8, Math.round(cellHeight - gap * 2))

                            PanelSurface {
                                id: windowSurface
                                anchors.fill: parent
                                radiusOverride: Math.min(Appearance.rounding.small, Math.min(width, height) / 6)
                                elevation: 1
                                cardStyle: false
                                outlined: false
                                clipContent: true
                                surfaceDialect: root.surfaceDialect

                                Image {
                                    id: previewImage
                                    anchors.fill: parent
                                    property bool hadReadyFrame: false
                                    source: {
                                        const ignoredRevision = windowItem.previewRevision
                                        return (workspaceCard.isCore || root.satellitePreviews)
                                                && windowItem.windowId >= 0
                                            ? WindowPreviewService.getPreviewUrl(windowItem.windowId) : ""
                                    }
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                    // Window screenshots contain small text and hard UI edges. With a
                                    // bounded near-native decode, mipmaps soften them unnecessarily.
                                    mipmap: false
                                    retainWhileLoading: true
                                    // Captures are usually near the original window size. Orbit cards are much
                                    // smaller, so use one stable decode budget for the whole stage. Binding this
                                    // to animated tile geometry reloads the PNG on every workspace transition.
                                    sourceSize.width: root.previewDecodeWidth
                                    sourceSize.height: root.previewDecodeHeight
                                    visible: opacity > 0.001
                                    opacity: status === Image.Ready
                                        || (status === Image.Loading && hadReadyFrame) ? 1 : 0

                                    onStatusChanged: {
                                        if (status === Image.Ready)
                                            hadReadyFrame = true
                                        else if (status === Image.Error || status === Image.Null)
                                            hadReadyFrame = false
                                    }

                                    Behavior on opacity {
                                        enabled: Appearance.animationsEnabled
                                        NumberAnimation {
                                            duration: Appearance.animation.elementMoveFast.duration
                                            easing.type: Appearance.animation.elementMoveFast.type
                                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                        }
                                    }
                                }

                                Connections {
                                    target: WindowPreviewService
                                    function onPreviewUpdated(updatedId: int): void {
                                        if (updatedId === windowItem.windowId)
                                            windowItem.previewRevision++
                                    }
                                    function onCaptureComplete(): void {
                                        windowItem.previewRevision++
                                    }
                                }

                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: Math.max(16,
                                        Math.round(Math.min(parent.width, parent.height) * 0.32))
                                    source: AppSearch.getIconSource(windowItem.modelData?.app_id ?? "")
                                    opacity: 1 - previewImage.opacity
                                    visible: opacity > 0.001
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: windowItem.hovered
                                        ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
                                        : "transparent"
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    radius: windowSurface.radiusOverride
                                    border.width: windowItem.keyboardSelected ? 2 : windowItem.hovered ? 1 : 0
                                    border.color: windowItem.keyboardSelected
                                        ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                                }

                                MouseArea {
                                    id: windowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                                    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    property real pressX: 0
                                    property real pressY: 0
                                    property int pressButton: Qt.NoButton
                                    property bool dragging: false

                                    onEntered: windowItem.hovered = true
                                    onExited: windowItem.hovered = false
                                    onPressed: mouse => {
                                        pressX = mouse.x
                                        pressY = mouse.y
                                        pressButton = mouse.button
                                        dragging = false
                                        if (mouse.button === Qt.LeftButton)
                                            orbitalDragProxy.placeAt(windowMouse, mouse.x, mouse.y)
                                    }
                                    onPositionChanged: mouse => {
                                        if (!pressed || pressButton !== Qt.LeftButton || !windowItem.modelData)
                                            return
                                        if (!dragging) {
                                            const dx = Math.abs(mouse.x - pressX)
                                            const dy = Math.abs(mouse.y - pressY)
                                            if (dx > 8 || dy > 8) {
                                                dragging = true
                                                orbitalDragProxy.beginDrag(windowItem.modelData,
                                                    windowItem.modelData.title || windowItem.modelData.app_id || Translation.tr("Window"),
                                                    windowItem.modelData.app_id || "")
                                            }
                                        }
                                        if (dragging)
                                            orbitalDragProxy.moveTo(windowMouse, mouse.x, mouse.y)
                                    }
                                    onReleased: mouse => {
                                        const dx = Math.abs(mouse.x - pressX)
                                        const dy = Math.abs(mouse.y - pressY)
                                        const click = dx <= 4 && dy <= 4
                                        const wasDragging = dragging
                                        dragging = false
                                        pressButton = Qt.NoButton
                                        if (wasDragging) {
                                            orbitalDragProxy.endDrag()
                                            return
                                        }
                                        if (!click || !windowItem.modelData)
                                            return
                                        if (mouse.button === Qt.LeftButton) {
                                            NiriService.focusWindow(windowItem.windowId)
                                            if (root.orbitOptions.closeOnSelect ?? true)
                                                GlobalStates.closeOverview()
                                        } else if (mouse.button === Qt.MiddleButton) {
                                            NiriService.closeWindow(windowItem.windowId)
                                        } else if (mouse.button === Qt.RightButton) {
                                            const point = windowMouse.mapToItem(root, mouse.x, mouse.y)
                                            root.openWindowContext(windowItem.modelData, point.x, point.y)
                                        }
                                    }
                                    onCanceled: {
                                        if (dragging)
                                            orbitalDragProxy.cancelDrag()
                                        dragging = false
                                        pressButton = Qt.NoButton
                                    }
                                }
                            }
                        }
                    }
                }

                PanelSurface {
                    id: workspaceLabelSurface
                    z: 3
                    visible: root.showWorkspaceLabels
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 8
                    width: Math.min(
                        Math.ceil((workspaceLabelRow.implicitWidth + 20) / 2) * 2,
                        Math.max(48, parent.width - anchors.margins * 2))
                    height: 26
                    elevation: 1
                    cardStyle: true
                    outlined: false
                    surfaceDialect: root.surfaceDialect
                    wallpaperBackdrop: false

                    RowLayout {
                        id: workspaceLabelRow
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 5

                        MaterialSymbol {
                            visible: workspaceCard.isActive
                            text: "radio_button_checked"
                            iconSize: 13
                            textRenderType: Text.QtRendering
                            color: workspaceCard.isCore
                                ? Appearance.colors.colPrimary : root.workspaceForeground
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            renderType: Text.QtRendering
                            font.hintingPreference: Font.PreferNoHinting
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            text: root.workspaceLabel(workspaceCard.workspaceObj)
                            color: root.workspaceForeground
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }

                Rectangle {
                    z: 3
                    anchors.fill: parent
                    color: "transparent"
                    radius: workspaceSurface._radius
                    border.width: root.workspaceSurfaceOutline ? root.workspaceOutlineWidth : 0
                    border.color: ColorUtils.mix(
                        ColorUtils.applyAlpha(Appearance.colors.colLayer0Border,
                            root.workspaceOutlineOpacity * 0.72),
                        ColorUtils.applyAlpha(Appearance.colors.colPrimary,
                            root.workspaceOutlineOpacity),
                        workspaceCard.isCore ? 1 : workspaceCard.isActive ? 0.65 : 0)
                }

                Rectangle {
                    z: 3
                    anchors.fill: parent
                    visible: workspaceCard.dropHovered
                    color: ColorUtils.applyAlpha(Appearance.colLayer1Hover, 0.78)
                    radius: workspaceSurface._radius

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 3

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "move_down"
                            iconSize: 26
                            textRenderType: Text.QtRendering
                            color: root.workspaceForeground
                        }

                        StyledText {
                            visible: workspaceCard.width >= 112
                            Layout.alignment: Qt.AlignHCenter
                            text: workspaceCard.isCore
                                ? Translation.tr("Move here")
                                : Translation.tr("Move to Workspace %1").arg(workspaceCard.workspaceObj?.idx ?? "–")
                            renderType: Text.QtRendering
                            font.hintingPreference: Font.PreferNoHinting
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.workspaceForeground
                        }
                    }
                }

                MouseArea {
                    id: workspaceArea
                    anchors.fill: parent
                    z: 1
                    acceptedButtons: Qt.LeftButton
                    onClicked: {
                        if (workspaceCard.isCore) {
                            if (workspaceCard.workspaceObj) {
                                NiriService.switchToWorkspaceById(workspaceCard.workspaceObj.id)
                                GlobalStates.closeOverview()
                            }
                        } else {
                            if (root.satelliteClickAction === "enter" && workspaceCard.workspaceObj) {
                                NiriService.switchToWorkspaceById(workspaceCard.workspaceObj.id)
                                GlobalStates.closeOverview()
                            } else {
                                root.selectWorkspace(workspaceCard.workspaceIndex)
                            }
                        }
                    }
                }

                DropArea {
                    anchors.fill: parent
                    z: 4
                    keys: [orbitalDragProxy.dragKey]
                    onEntered: workspaceCard.dropHovered = true
                    onExited: workspaceCard.dropHovered = false
                    onDropped: drop => {
                        workspaceCard.dropHovered = false
                        if (orbitalDragProxy.win && workspaceCard.workspaceObj
                                && root.moveDraggedWindowToWorkspace(orbitalDragProxy.win, workspaceCard.workspaceObj.id))
                            drop.accept()
                    }
                }
            }
        }
    }

    RowLayout {
        id: dragTray
        visible: orbitalDragProxy.dragging
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        z: 500
        spacing: 8

        PanelSurface {
            visible: root.orbitOptions.showStash ?? true
            Layout.preferredWidth: 148
            Layout.preferredHeight: 40
            elevation: root.stashDropHovered ? 2 : 1
            cardStyle: true
            outlined: true
            surfaceDialect: root.surfaceDialect
            wallpaperBackdrop: false

            RowLayout {
                anchors.centerIn: parent
                spacing: 6
                MaterialSymbol {
                    text: "inventory_2"
                    iconSize: 17
                    textRenderType: Text.QtRendering
                    color: root.stashDropHovered
                        ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                }
                StyledText {
                    renderType: Text.QtRendering
                    font.hintingPreference: Font.PreferNoHinting
                    text: Translation.tr("Pocket")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.stashDropHovered
                        ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                }
            }

            DropArea {
                anchors.fill: parent
                keys: [orbitalDragProxy.dragKey]
                onEntered: root.stashDropHovered = true
                onExited: root.stashDropHovered = false
                onDropped: drop => {
                    root.stashDropHovered = false
                    if (orbitalDragProxy.win && MinimizedWindows.minimize(orbitalDragProxy.win.id))
                        drop.accept()
                }
            }
        }

        PanelSurface {
            visible: root.orbitOptions.showNewWorkspaceDrop ?? true
            Layout.preferredWidth: 168
            Layout.preferredHeight: 40
            elevation: root.newWorkspaceDropHovered ? 2 : 1
            cardStyle: true
            outlined: true
            surfaceDialect: root.surfaceDialect
            wallpaperBackdrop: false

            RowLayout {
                anchors.centerIn: parent
                spacing: 6
                MaterialSymbol {
                    text: "add_to_photos"
                    iconSize: 17
                    textRenderType: Text.QtRendering
                    color: root.newWorkspaceDropHovered
                        ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext
                }
                StyledText {
                    renderType: Text.QtRendering
                    font.hintingPreference: Font.PreferNoHinting
                    text: Translation.tr("New workspace")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.newWorkspaceDropHovered
                        ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                }
            }

            DropArea {
                anchors.fill: parent
                keys: [orbitalDragProxy.dragKey]
                onEntered: root.newWorkspaceDropHovered = true
                onExited: root.newWorkspaceDropHovered = false
                onDropped: drop => {
                    root.newWorkspaceDropHovered = false
                    if (orbitalDragProxy.win && root.moveDraggedWindowToNewWorkspace(orbitalDragProxy.win))
                        drop.accept()
                }
            }
        }
    }

    WorkspaceStripDragProxy {
        id: orbitalDragProxy
        compactWidth: 184
        compactHeight: 42
        previewEnabled: true
        previewWidth: 204
        previewHeight: 122
        previewSource: win ? WindowPreviewService.getPreviewUrl(win.id) : ""
        centerOnPointer: true
        z: 600
        surfaceColor: Appearance.colors.colLayer3
        outlineColor: Appearance.colors.colPrimary
        foregroundColor: Appearance.colors.colOnLayer3
    }

    ContextMenu {
        id: windowContextMenu
        model: root.contextMenuModel()
        anchorItem: root
        anchorRect: root.contextAnchorRect
        popupAbove: false
        closeOnHoverLost: false
        closeOnOutsideClick: true
        scaleContent: false
        onActiveChanged: if (!active) root.contextWindowData = null
    }

    WheelHandler {
        enabled: root.orbitOptions.scrollNavigation ?? true
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        target: null
        blocking: true
        onWheel: event => {
            const inverted = Config.options?.bar?.workspaces?.invertScroll ?? false
            let angle = event.angleDelta.y
            let pixels = event.pixelDelta.y
            root.wheelEventCount += 1
            root.lastWheelAngle = angle
            root.lastWheelPixels = pixels
            if (inverted) {
                angle = -angle
                pixels = -pixels
            }

            if (angle !== 0) {
                root.wheelAngleAccumulator += angle
                const threshold = 120 * root.wheelStepsRequired
                if (Math.abs(root.wheelAngleAccumulator) >= threshold) {
                    const direction = root.wheelAngleAccumulator < 0 ? 1 : -1
                    root.wheelAngleAccumulator += direction > 0 ? threshold : -threshold
                    root.wheelPixelAccumulator = 0
                    if (root.orbitOptions.scrollSwitchWorkspace ?? true)
                        root.switchRelativeWorkspace(direction,
                            root.orbitOptions.scrollWrapAround ?? false)
                    else
                        root.focusRelativeWorkspace(direction,
                            root.orbitOptions.scrollWrapAround ?? false)
                }
                event.accepted = true
                return
            }

            if (pixels === 0)
                return
            root.wheelPixelAccumulator += pixels
            const pixelThreshold = 48 * root.wheelStepsRequired
            if (Math.abs(root.wheelPixelAccumulator) >= pixelThreshold) {
                const direction = root.wheelPixelAccumulator < 0 ? 1 : -1
                root.wheelPixelAccumulator += direction > 0 ? pixelThreshold : -pixelThreshold
                root.wheelAngleAccumulator = 0
                if (root.orbitOptions.scrollSwitchWorkspace ?? true)
                    root.switchRelativeWorkspace(direction,
                        root.orbitOptions.scrollWrapAround ?? false)
                else
                    root.focusRelativeWorkspace(direction,
                        root.orbitOptions.scrollWrapAround ?? false)
            }
            event.accepted = true
        }
    }

    Connections {
        target: NiriService
        function onWindowsChanged() {
            root.ensureKeyboardWindow()
            root.syncPreviews()
        }
        function onAllWorkspacesChanged() {
            root.normalizeSelection()
        }
    }

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (GlobalStates.overviewOpen) {
                root.selectedWorkspaceId = root.workspacesForOutput[root.activeWorkspaceIndex]?.id ?? -1
                root.keyboardWindowIndex = -1
                root.syncPreviews()
            } else {
                windowContextMenu.close()
            }
        }
    }

    Component.onCompleted: {
        root.normalizeSelection()
        root.syncPreviews()
    }

    onFilterTextChanged: {
        root.ensureKeyboardWindow()
        root.syncPreviews()
    }
}
