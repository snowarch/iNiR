import qs
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: overviewScope
    property bool dontAutoCancelSearch: false

    Component.onCompleted: CompositorService.setSortingConsumer("overview", GlobalStates.overviewOpen)
    Variants {
        id: overviewVariants
        model: Quickshell.screens
        PanelWindow {
            id: root
            required property var modelData
            property bool _presentedOpen: false
            property bool _presentPending: false
            property string searchingText: ""
            property string orbitKeyboardZone: "windows"
            property bool orbitPocketOpen: false
            property bool orbitStudioOpen: false
            property bool orbitStudioDocked: true
            property var orbitStudioDraft: ({})
            property bool orbitStudioGeometryReady: false
            property bool orbitStudioUserResized: false
            property real orbitStudioX: -1
            property real orbitStudioY: -1
            property real orbitStudioWidth: 392
            property real orbitStudioHeight: 500
            property real orbitStudioGestureX: 0
            property real orbitStudioGestureY: 0
            property real orbitStudioGestureWidth: 0
            property real orbitStudioGestureHeight: 0
            readonly property real orbitStudioBoundsWidth: root.screen?.width ?? root.width
            readonly property real orbitStudioBoundsHeight: root.screen?.height ?? root.height
            readonly property real orbitStudioFocusInset: 0
            readonly property real orbitStudioReservedWidth: root.orbitMode && root.orbitStudioOpen
                && root.orbitStudioDocked ? Math.min(root.width * 0.4, root.orbitStudioWidth + 36) : 0
            readonly property real orbitWorkingWidth: Math.max(640, root.width - root.orbitStudioReservedWidth)
            readonly property real orbitSceneCenterOffset: -root.orbitStudioReservedWidth / 2
            property real orbitStageReveal: 1
            property real orbitPresentationProgress: 0
            property real orbitBackdropProgress: 0
            property real orbitEntryProgress: 0
            property bool _orbitStageReady: false
            property bool _orbitHostStarted: false
            property bool _orbitSceneStarted: false
            property int orbitStageSwitchDirection: 1
            property bool orbitLensOpen: false
            property string orbitLensText: ""
            readonly property bool orbitMode: GlobalStates.overviewMode === "orbit"
            readonly property var configuredOrbitOptions: Config.options?.orbit ?? {}
            readonly property var orbitOptions: root.mergeOrbitOptions(
                root.configuredOrbitOptions, root.orbitStudioDraft)
            readonly property string orbitStageMode: root.orbitStudioDraft.stageMode !== undefined
                ? (root.orbitStudioDraft.stageMode === "orbital" ? "orbital" : "stage")
                : GlobalStates.orbitStageOverride.length > 0
                    ? GlobalStates.orbitStageOverride
                    : orbitOptions.stageMode === "orbital" ? "orbital" : "stage"
            readonly property var orbitPresentation: orbitOptions.presentation ?? ({})
            readonly property var orbitNavigationMotion: orbitOptions.navigationMotion ?? ({})
            readonly property var orbitStudioOptions: orbitOptions.studio ?? ({})
            readonly property string orbitPresentationPreset: OrbitTuning.presentationPreset(orbitPresentation)
            readonly property bool orbitPresentationAdvanced: OrbitTuning.presentationAdvanced(orbitPresentation)
            readonly property string orbitEffectivePresentationDirection: OrbitTuning.presentationDirection(
                orbitPresentation, root.orbitStageMode, root.orbitOptions.orbital?.layout ?? "orbit")
            readonly property int orbitPresentationDistance: OrbitTuning.presentationDistance(orbitPresentation)
            readonly property int orbitEnterDuration: OrbitTuning.presentationEnterDuration(orbitPresentation)
            readonly property int orbitExitDuration: OrbitTuning.presentationExitDuration(orbitPresentation)
            readonly property int orbitBackdropWarmupBudgetMs: Math.min(80,
                Math.max(24, Math.round(root.orbitEnterDuration * 0.25)))
            readonly property int orbitEntryDelayMs: OrbitTuning.presentationEntryDelay(orbitPresentation)
            readonly property string orbitEntryStyle: OrbitTuning.presentationEntryStyle(orbitPresentation)
            readonly property int orbitEntryStaggerMs: OrbitTuning.presentationStagger(orbitPresentation)
            readonly property int orbitShelfDelayMs: OrbitTuning.presentationShelfDelay(orbitPresentation)
            readonly property real orbitEntryOpacityStart: OrbitTuning.presentationEntryOpacity(orbitPresentation)
            readonly property real orbitShelfEntryProgress: {
                if (root.orbitEnterDuration <= 0)
                    return 1
                const delay = Math.min(0.72, root.orbitShelfDelayMs / root.orbitEnterDuration)
                return Math.max(0, Math.min(1,
                    (root.orbitEntryProgress - delay) / Math.max(0.01, 1 - delay)))
            }
            readonly property string orbitBackdropBlurMode: {
                const configured = String(root.orbitOptions.backdropBlurMode ?? "")
                if (configured === "off") return "off"
                if (["shell", "inherit", "niri"].includes(configured)) return "shell"
                return (root.orbitOptions.backdropBlurEnable ?? true) ? "shell" : "off"
            }
            readonly property int orbitBackdropBlurStrength: Math.max(0,
                Math.min(100, root.orbitOptions.backdropBlurStrength ?? 72))
            readonly property int orbitBackdropBlurSaturation: Math.max(0,
                Math.min(100, root.orbitOptions.backdropBlurSaturation ?? 18))
            readonly property int orbitBackdropBlurTint: Math.max(0,
                Math.min(100, root.orbitOptions.backdropBlurTint ?? 28))
            readonly property bool orbitWallpaperBlurConfigured: root.orbitBackdropBlurMode === "shell"
                && root.orbitBackdropBlurStrength > 0
                && Appearance.effectsEnabled
                && !GameMode.active
            readonly property bool orbitWallpaperBlurActive: root.orbitMode
                && root.orbitWallpaperBlurConfigured
            readonly property HyprlandMonitor monitor: CompositorService.isHyprland ? Hyprland.monitorFor(root.screen) : null
            property bool monitorIsFocused: CompositorService.isHyprland 
                ? (Hyprland.focusedMonitor?.id == monitor?.id)
                : (NiriService.currentOutput === root.screen?.name)
            readonly property bool activeScreenOnly: Config.options?.overview?.activeScreenOnly ?? true
            readonly property bool isTargetOutput:
                GlobalStates.overviewPresentationOutput === (root.modelData?.name ?? "")
            readonly property bool shouldShow: GlobalStates.overviewOpen
                && (orbitMode ? isTargetOutput : (!activeScreenOnly || isTargetOutput))
            readonly property bool applicationDragActive: searchWidget.applicationDragActive
                || (allAppsGridLoader.item?.applicationDragActive ?? false)
            readonly property int orbitLensResultCount: {
                const outputName = root.screen?.name ?? ""
                const workspaceIds = new Set((NiriService.allWorkspaces ?? [])
                    .filter(workspace => workspace.output === outputName)
                    .map(workspace => workspace.id))
                let count = 0
                for (const window of NiriService.windows ?? []) {
                    if (!workspaceIds.has(window.workspace_id) || MinimizedWindows.isMinimized(window.id))
                        continue
                    if (root.windowMatchesOrbitLens(window))
                        count++
                }
                return count
            }
            screen: modelData

            function windowMatchesOrbitLens(windowData): bool {
                const query = root.orbitLensText.trim().toLowerCase()
                if (query.length === 0)
                    return true
                const title = String(windowData?.title ?? "").toLowerCase()
                const appId = String(windowData?.app_id ?? windowData?.appId ?? "").toLowerCase()
                return title.includes(query) || appId.includes(query)
            }

            function copyObject(source): var {
                const result = {}
                if (!source)
                    return result
                for (const key in source)
                    result[key] = source[key]
                return result
            }

            function mergeObjects(base, overlay): var {
                const result = root.copyObject(base)
                for (const key in overlay ?? {}) {
                    const value = overlay[key]
                    if (value && typeof value === "object" && !Array.isArray(value))
                        result[key] = root.mergeObjects(base?.[key] ?? {}, value)
                    else
                        result[key] = value
                }
                return result
            }

            function mergeOrbitOptions(base, draft): var {
                return root.mergeObjects(base, draft)
            }

            function publishOrbitRuntimeStatus(): void {
                if (!root.orbitMode || !root.isTargetOutput) return
                const item = overviewLoader.item
                const visual = item && typeof item.visualState === "function"
                    ? item.visualState() : ({})
                GlobalStates.orbitRuntimeStatus = {
                    open: root.shouldShow,
                    presented: root._presentedOpen,
                    output: root.screen?.name ?? "",
                    mode: root.orbitStageMode,
                    layout: root.orbitStageMode === "orbital"
                        ? String(item?.spatialLayout ?? root.orbitOptions.orbital?.layout ?? "orbit")
                        : "stage",
                    loaderReady: overviewLoader.status === Loader.Ready && item !== null,
                    cardCount: root.orbitStageMode === "orbital"
                        ? (item?.displayedWorkspaces?.length ?? 0)
                        : (item?.workspacesForOutput?.length ?? 0),
                    stageWidth: item?.width ?? 0,
                    stageHeight: item?.height ?? 0,
                    stageOpacity: overviewLoader.opacity,
                    stageVisible: overviewLoader.visible,
                    backdropLoaded: orbitBackdropLoader.status === Loader.Ready
                        && orbitBackdropLoader.item !== null,
                    presentationProgress: root.orbitPresentationProgress,
                    backdropProgress: root.orbitBackdropProgress,
                    entryProgress: root.orbitEntryProgress,
                    stageReveal: root.orbitStageReveal,
                    cards: visual.cards ?? [],
                    scroll: visual.scroll ?? ({}),
                    studio: root.orbitStudioOpen,
                    pocket: root.orbitPocketOpen,
                    lens: root.orbitLensOpen
                }
            }

            function setOrbitStudioPreview(path: string, value): void {
                const parts = path.split(".")
                const draft = root.mergeObjects({}, root.orbitStudioDraft)
                let cursor = draft
                for (let i = 0; i < parts.length - 1; ++i) {
                    const key = parts[i]
                    cursor[key] = root.mergeObjects({}, cursor[key] ?? {})
                    cursor = cursor[key]
                }
                cursor[parts[parts.length - 1]] = value
                root.orbitStudioDraft = draft
            }

            function clearOrbitStudioPreview(): void {
                root.orbitStudioDraft = ({})
            }

            function commitOrbitStudioPreview(): void {
                function writeBranch(prefix, branch): void {
                    for (const key in branch) {
                        const value = branch[key]
                        const path = `${prefix}.${key}`
                        if (value && typeof value === "object" && !Array.isArray(value))
                            writeBranch(path, value)
                        else
                            Config.setNestedValue(path, value)
                    }
                }
                const draft = root.orbitStudioDraft
                writeBranch("orbit", draft)
                if (draft.stageMode !== undefined)
                    GlobalStates.orbitStageOverride = ""
                root.clearOrbitStudioPreview()
            }

            function resetOrbitDefaults(): void {
                root.clearOrbitStudioPreview()
                GlobalStates.orbitStageOverride = ""
                Config.setNestedValues(OrbitTuning.defaultConfigUpdates())
            }

            function clampOrbitStudioGeometry(): void {
                if (!root.orbitStudioGeometryReady)
                    return
                if (root.orbitStudioDocked) {
                    const widthRatio = Math.max(20, Math.min(34,
                        root.orbitStudioOptions.widthPercent ?? 26)) / 100
                    root.orbitStudioWidth = Math.max(360,
                        Math.min(420, root.orbitStudioBoundsWidth * widthRatio))
                    root.orbitStudioHeight = root.orbitStudioBoundsHeight
                    root.orbitStudioX = 0
                    root.orbitStudioY = 0
                    return
                }
                const margin = 12
                const boundsWidth = root.orbitStudioBoundsWidth
                const boundsHeight = root.orbitStudioBoundsHeight
                const maxWidth = Math.max(360, boundsWidth - margin * 2)
                const maxHeight = Math.max(440, boundsHeight - margin * 2)
                root.orbitStudioWidth = Math.max(360, Math.min(root.orbitStudioWidth, maxWidth))
                root.orbitStudioHeight = Math.max(440, Math.min(root.orbitStudioHeight, maxHeight))
                root.orbitStudioX = Math.max(margin,
                    Math.min(root.orbitStudioX, boundsWidth - root.orbitStudioWidth - margin))
                root.orbitStudioY = Math.max(margin,
                    Math.min(root.orbitStudioY, boundsHeight - root.orbitStudioHeight - margin))
            }

            function ensureOrbitStudioGeometry(): void {
                if (root.orbitStudioGeometryReady) {
                    root.clampOrbitStudioGeometry()
                    return
                }
                if (root.orbitStudioDocked) {
                    root.orbitStudioGeometryReady = true
                    root.clampOrbitStudioGeometry()
                    return
                }
                const margin = 20
                const boundsWidth = root.orbitStudioBoundsWidth
                const boundsHeight = root.orbitStudioBoundsHeight
                root.orbitStudioWidth = Math.max(360, Math.min(392, boundsWidth - margin * 2))
                root.orbitStudioHeight = Math.max(440, Math.min(500, boundsHeight - margin * 2))
                root.orbitStudioX = Math.round(boundsWidth - root.orbitStudioWidth - margin)
                root.orbitStudioY = Math.round((boundsHeight - root.orbitStudioHeight) / 2)
                root.orbitStudioGeometryReady = true
                root.clampOrbitStudioGeometry()
            }

            function resetOrbitStudioGeometry(): void {
                root.orbitStudioUserResized = false
                root.orbitStudioGeometryReady = false
                root.ensureOrbitStudioGeometry()
            }

            function setOrbitStudioDocked(docked: bool): void {
                if (root.orbitStudioDocked === docked)
                    return
                root.orbitStudioDocked = docked
                root.orbitStudioUserResized = false
                root.orbitStudioGeometryReady = false
                root.ensureOrbitStudioGeometry()
            }

            function applyOrbitStudioHeightHint(heightHint: real): void {
                if (!root.orbitStudioGeometryReady || root.orbitStudioUserResized || root.orbitStudioDocked)
                    return
                const margin = 12
                const boundsHeight = root.orbitStudioBoundsHeight
                const target = Math.round(Math.max(380,
                    Math.min(heightHint, Math.min(620, boundsHeight - margin * 2))))
                if (Math.abs(target - root.orbitStudioHeight) < 2)
                    return
                const centerY = root.orbitStudioY + root.orbitStudioHeight / 2
                root.orbitStudioHeight = target
                root.orbitStudioY = Math.round(Math.max(margin, Math.min(
                    centerY - target / 2,
                    boundsHeight - target - margin)))
            }

            function beginOrbitStudioMove(): void {
                root.orbitStudioGestureX = root.orbitStudioX
                root.orbitStudioGestureY = root.orbitStudioY
            }

            function updateOrbitStudioMove(deltaX: real, deltaY: real): void {
                if (root.orbitStudioDocked)
                    return
                const margin = 12
                const boundsWidth = root.orbitStudioBoundsWidth
                const boundsHeight = root.orbitStudioBoundsHeight
                root.orbitStudioX = Math.round(Math.max(margin, Math.min(
                    root.orbitStudioGestureX + deltaX,
                    boundsWidth - root.orbitStudioWidth - margin)))
                root.orbitStudioY = Math.round(Math.max(margin, Math.min(
                    root.orbitStudioGestureY + deltaY,
                    boundsHeight - root.orbitStudioHeight - margin)))
            }

            function beginOrbitStudioResize(): void {
                if (root.orbitStudioDocked)
                    return
                root.orbitStudioUserResized = true
                root.orbitStudioGestureWidth = root.orbitStudioWidth
                root.orbitStudioGestureHeight = root.orbitStudioHeight
            }

            function updateOrbitStudioResize(deltaX: real, deltaY: real): void {
                if (root.orbitStudioDocked)
                    return
                const margin = 12
                const maxWidth = Math.max(360,
                    root.orbitStudioBoundsWidth - root.orbitStudioX - margin)
                const maxHeight = Math.max(440,
                    root.orbitStudioBoundsHeight - root.orbitStudioY - margin)
                root.orbitStudioWidth = Math.round(Math.max(360,
                    Math.min(root.orbitStudioGestureWidth + deltaX, maxWidth)))
                root.orbitStudioHeight = Math.round(Math.max(440,
                    Math.min(root.orbitStudioGestureHeight + deltaY, maxHeight)))
            }

            function animateOrbitStageSwitch(): void {
                if (!root.orbitMode || !root.shouldShow)
                    return
                root.orbitStageSwitchDirection = root.orbitStageMode === "orbital" ? 1 : -1
                root.orbitStageReveal = 0
                orbitStageEnterAnimation.restart()
            }

            function openOrbitStudio(): void {
                if (!root.orbitMode || !root.isTargetOutput)
                    return
                root.orbitStudioDocked = true
                root.orbitStudioGeometryReady = false
                root.ensureOrbitStudioGeometry()
                root.orbitStudioOpen = true
                root.orbitLensOpen = false
                root.orbitPocketOpen = false
                root.orbitKeyboardZone = "studio"
                orbitShelfLoader.item?.clearKeyboardSelection()
                Qt.callLater(() => orbitStudioLoader.item?.focusFirst())
            }

            function closeOrbitStudio(): void {
                root.orbitStudioOpen = false
                root.orbitStudioDocked = true
                root.orbitKeyboardZone = "windows"
                Qt.callLater(() => overviewLoader.item?.ensureKeyboardWindow())
            }

            function openOrbitLens(): void {
                if (!root.orbitMode || !root.isTargetOutput)
                    return
                root.orbitLensOpen = true
                root.orbitStudioOpen = false
                root.orbitPocketOpen = false
                root.orbitKeyboardZone = "lens"
                orbitShelfLoader.item?.clearKeyboardSelection()
                Qt.callLater(() => orbitLensLoader.item?.focusInput())
            }

            function acceptOrbitLens(): void {
                root.orbitLensOpen = false
                root.orbitKeyboardZone = "windows"
                Qt.callLater(() => overviewLoader.item?.ensureKeyboardWindow())
            }

            function clearOrbitLens(): void {
                root.orbitLensText = ""
                root.orbitLensOpen = false
                root.orbitKeyboardZone = "windows"
                Qt.callLater(() => overviewLoader.item?.ensureKeyboardWindow())
            }

            function consumeOrbitPocketRequest(): void {
                if (!root.orbitMode || !root.isTargetOutput || !GlobalStates.orbitPocketRequested)
                    return
                GlobalStates.orbitPocketRequested = false
                if (MinimizedWindows.getMinimizedForOutput(root.screen?.name ?? "").length === 0)
                    return
                root.orbitPocketOpen = true
                root.orbitKeyboardZone = "pocket"
                orbitShelfLoader.item?.clearKeyboardSelection()
                Qt.callLater(() => pocketLoader.item?.focusFirstKeyboard())
            }

            function consumeOrbitStudioRequest(): void {
                if (!root.orbitMode || !root.isTargetOutput || !GlobalStates.orbitStudioRequested)
                    return
                GlobalStates.orbitStudioRequested = false
                root.openOrbitStudio()
            }

            function consumeOrbitLensRequest(): void {
                if (!root.orbitMode || !root.isTargetOutput || !GlobalStates.orbitLensRequested)
                    return
                root.orbitLensText = GlobalStates.orbitLensRequestedQuery
                GlobalStates.orbitLensRequested = false
                GlobalStates.orbitLensRequestedQuery = ""
                root.openOrbitLens()
            }

            function present(): void {
                if (root._presentedOpen || root._presentPending)
                    return
                const freshOrbitOpen = root.orbitMode && !root.visible
                root._presentPending = true
                _overviewCloseTimer.stop()
                orbitPresentationExit.stop()
                orbitBackdropExit.stop()
                visible = true
                if (root.orbitMode) {
                    root._orbitHostStarted = false
                    root._orbitStageReady = overviewLoader.status === Loader.Ready
                    root._orbitSceneStarted = root.orbitEntryProgress >= 1
                }
                if (freshOrbitOpen) {
                    root.orbitPresentationProgress = 0
                    root.orbitBackdropProgress = 0
                    root.orbitEntryProgress = 0
                    root._orbitSceneStarted = false
                }
                Qt.callLater(() => {
                    root._presentPending = false
                    if (!root.shouldShow)
                        return
                    root._presentedOpen = true
                    if (root.orbitMode) {
                        if (Appearance.animationsEnabled && root.orbitEnterDuration > 0) {
                            if (root.orbitWallpaperBlurActive) {
                                orbitBackdropWarmupDeadline.restart()
                                root.beginOrbitBackdropWarmup()
                            } else {
                                root.startOrbitHost()
                            }
                        } else {
                            root.orbitPresentationProgress = 1
                            root.orbitBackdropProgress = root.orbitWallpaperBlurActive ? 1 : 0
                            root._orbitHostStarted = true
                            root.maybeStartOrbitScene()
                        }
                    }
                    if (!root.isTargetOutput)
                        return
                    if (root.orbitMode) {
                        overviewScope.dontAutoCancelSearch = false
                        searchWidget.cancelSearch()
                        root.orbitKeyboardZone = "windows"
                        root.orbitPocketOpen = false
                        root.orbitStudioOpen = false
                        root.orbitLensOpen = false
                        root.orbitLensText = ""
                        root.clearOrbitStudioPreview()
                        columnLayout.forceActiveFocus()
                        root.consumeOrbitPocketRequest()
                        root.consumeOrbitStudioRequest()
                        root.consumeOrbitLensRequest()
                    } else {
                        const prefix = GlobalStates.overviewSearchPrefix
                        if (prefix.length > 0) {
                            overviewScope.dontAutoCancelSearch = true
                            root.setSearchingText(prefix)
                        } else {
                            searchWidget.cancelSearch()
                        }
                        searchWidget.focusSearchInput()
                        root.maybeSwitchWorkspaceOnOpen()
                    }
                    delayedGrabTimer.start()
                })
            }

            function dismiss(): void {
                root._presentPending = false
                root._presentedOpen = false
                root.orbitStudioOpen = false
                root.orbitStudioGeometryReady = false
                root.orbitStudioUserResized = false
                root.orbitLensOpen = false
                root.orbitLensText = ""
                root.clearOrbitStudioPreview()
                if (root.orbitMode) {
                    orbitPresentationWarmup.running = false
                    orbitBackdropWarmupDeadline.stop()
                    orbitPresentationDelayTimer.stop()
                    orbitSceneEnter.stop()
                    orbitPresentationEnter.stop()
                    orbitBackdropEnter.stop()
                    if (Appearance.animationsEnabled && root.orbitExitDuration > 0) {
                        orbitPresentationExit.restart()
                        if (root.orbitBackdropProgress > 0)
                            orbitBackdropExit.restart()
                    } else {
                        root.orbitPresentationProgress = 0
                        root.orbitBackdropProgress = 0
                        root.orbitEntryProgress = 0
                    }
                }
                _overviewCloseTimer.restart()
            }

            function startOrbitPresentation(): void {
                if (!root.orbitMode || !root.shouldShow || overviewLoader.status !== Loader.Ready)
                    return
                root._orbitStageReady = true
                root.maybeStartOrbitScene()
            }

            function startOrbitHost(): void {
                if (!root.orbitMode || !root.shouldShow || root._orbitHostStarted)
                    return
                root._orbitHostStarted = true
                if (!Appearance.animationsEnabled || root.orbitEnterDuration <= 0)
                    root.orbitPresentationProgress = 1
                else
                    orbitPresentationEnter.restart()
                root.maybeStartOrbitScene()
            }

            function startOrbitBackdrop(): void {
                if (!root.orbitWallpaperBlurActive || root.orbitBackdropProgress >= 1)
                    return
                if (!Appearance.animationsEnabled || root.orbitEnterDuration <= 0)
                    root.orbitBackdropProgress = 1
                else
                    orbitBackdropEnter.restart()
            }

            function beginOrbitBackdropWarmup(): void {
                if (!root._presentedOpen || !root.shouldShow || !root.orbitWallpaperBlurActive
                        || !root.orbitBackdropReady() || orbitPresentationWarmup.running)
                    return
                orbitPresentationWarmup.frames = 0
                orbitPresentationWarmup.running = true
            }

            function maybeStartOrbitScene(): void {
                if (!root.orbitMode || !root.shouldShow || !root._orbitStageReady
                        || !root._orbitHostStarted || root._orbitSceneStarted)
                    return
                root._orbitSceneStarted = true
                if (!Appearance.animationsEnabled || root.orbitEnterDuration <= 0) {
                    root.orbitEntryProgress = 1
                    root.publishOrbitRuntimeStatus()
                    return
                }
                if (root.orbitEntryDelayMs > 0)
                    orbitPresentationDelayTimer.restart()
                else
                    orbitSceneEnter.restart()
            }

            function orbitBackdropReady(): bool {
                if (!root.orbitWallpaperBlurActive)
                    return true
                return orbitBackdropLoader.status === Loader.Ready
                    && (orbitBackdropLoader.item?.backdropReady ?? false)
            }

            Component.onCompleted: {
                if (root.shouldShow) root.present()
                else root.visible = false
                root.publishOrbitRuntimeStatus()
            }
            onShouldShowChanged: {
                if (root.shouldShow) root.present()
                else root.dismiss()
                root.publishOrbitRuntimeStatus()
            }
            onOrbitStageModeChanged: {
                root.animateOrbitStageSwitch()
                Qt.callLater(root.publishOrbitRuntimeStatus)
            }
            onOrbitWallpaperBlurActiveChanged: {
                if (!root._presentedOpen || !root.shouldShow)
                    return
                if (root.orbitWallpaperBlurActive) {
                    orbitBackdropExit.stop()
                    root.beginOrbitBackdropWarmup()
                    return
                }
                orbitPresentationWarmup.running = false
                orbitBackdropWarmupDeadline.stop()
                orbitBackdropEnter.stop()
                if (Appearance.animationsEnabled && root.orbitExitDuration > 0
                        && root.orbitBackdropProgress > 0)
                    orbitBackdropExit.restart()
                else
                    root.orbitBackdropProgress = 0
            }
            onOrbitOptionsChanged: Qt.callLater(root.publishOrbitRuntimeStatus)
            onOrbitStudioOpenChanged: root.publishOrbitRuntimeStatus()
            onOrbitPocketOpenChanged: root.publishOrbitRuntimeStatus()
            onOrbitLensOpenChanged: root.publishOrbitRuntimeStatus()
            onOrbitStudioOptionsChanged: {
                if (root.orbitStudioOpen && root.orbitStudioDocked)
                    root.clampOrbitStudioGeometry()
            }
            onWidthChanged: if (root.orbitStudioGeometryReady) root.clampOrbitStudioGeometry()
            onHeightChanged: if (root.orbitStudioGeometryReady) root.clampOrbitStudioGeometry()

            NumberAnimation {
                id: orbitStageEnterAnimation
                target: root
                property: "orbitStageReveal"
                from: 0
                to: 1
                duration: OrbitTuning.navigationDuration(root.orbitNavigationMotion)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.standardDecel
            }

            NumberAnimation {
                id: orbitPresentationEnter
                target: root
                property: "orbitPresentationProgress"
                to: 1
                duration: root.orbitEnterDuration
                easing.type: Easing.Linear
                onFinished: root.publishOrbitRuntimeStatus()
            }

            FrameAnimation {
                id: orbitPresentationWarmup
                property int frames: 0
                running: false
                onTriggered: {
                    frames++
                    if (frames < 2)
                        return
                    running = false
                    orbitBackdropWarmupDeadline.stop()
                    if (!root.shouldShow || !root.orbitMode || !root._presentedOpen)
                        return
                    root.startOrbitBackdrop()
                    root.startOrbitHost()
                }
            }

            Timer {
                id: orbitBackdropWarmupDeadline
                interval: root.orbitBackdropWarmupBudgetMs
                repeat: false
                onTriggered: root.startOrbitHost()
            }

            NumberAnimation {
                id: orbitBackdropEnter
                target: root
                property: "orbitBackdropProgress"
                to: 1
                duration: root.orbitEnterDuration
                easing.type: Easing.Linear
                onFinished: root.publishOrbitRuntimeStatus()
            }

            NumberAnimation {
                id: orbitSceneEnter
                target: root
                property: "orbitEntryProgress"
                to: 1
                duration: root.orbitEnterDuration
                easing.type: root.orbitEntryStyle === "fade"
                    ? Easing.OutQuad : Easing.OutCubic
                onFinished: root.publishOrbitRuntimeStatus()
            }

            Timer {
                id: orbitPresentationDelayTimer
                interval: root.orbitEntryDelayMs
                repeat: false
                onTriggered: if (root.shouldShow && root.orbitMode) orbitSceneEnter.restart()
            }

            NumberAnimation {
                id: orbitPresentationExit
                target: root
                property: "orbitPresentationProgress"
                to: 0
                duration: root.orbitExitDuration
                easing.type: Easing.Linear
            }

            NumberAnimation {
                id: orbitBackdropExit
                target: root
                property: "orbitBackdropProgress"
                to: 0
                duration: root.orbitExitDuration
                easing.type: Easing.Linear
                onFinished: root.publishOrbitRuntimeStatus()
            }

            Timer {
                id: _overviewCloseTimer
                // Cover the full exit animation (elementMoveExit scales with the
                // enterExit speed setting) plus a small margin so the window is
                // never torn down mid-close.
                interval: (root.orbitMode ? root.orbitExitDuration
                    : Appearance.animation.elementMoveExit.duration) + 40
                onTriggered: {
                    root.visible = false
                    if (root.orbitMode) {
                        root.orbitPresentationProgress = 0
                        root.orbitBackdropProgress = 0
                        root.orbitEntryProgress = 0
                        root._orbitStageReady = false
                        root._orbitHostStarted = false
                        root._orbitSceneStarted = false
                    }
                    Qt.callLater(root.publishOrbitRuntimeStatus)
                }
            }

            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: root.orbitMode ? "quickshell:orbit" : "quickshell:overview"
            WlrLayershell.layer: WlrLayer.Overlay
            // Keyboard focus only on the monitor that should show
            WlrLayershell.keyboardFocus: root.shouldShow
                && !root.applicationDragActive
                && !GlobalStates.regionSelectorOpen
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            color: "transparent"

            mask: Region {
                item: root.applicationDragActive ? emptyDragMask : overviewInputMask
            }

            Item {
                id: emptyDragMask
                width: 0
                height: 0
            }

            Item {
                id: overviewInputMask
                anchors.fill: parent
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Image {
                anchors.fill: parent
                z: -3
                visible: root.orbitWallpaperBlurActive && root.visible
                opacity: root.orbitPresentationProgress
                source: WallpaperListener.wallpaperUrlForScreen(root.screen)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                sourceSize.width: Math.max(1, Math.round(root.width))
                sourceSize.height: Math.max(1, Math.round(root.height))
            }

            Loader {
                id: orbitBackdropLoader
                anchors.fill: parent
                z: -2
                // Qt Loader.active=false destroys the loaded item. Keep the blur
                // subtree alive only for the visible Orbit lifecycle.
                active: root.visible
                    && (root.orbitWallpaperBlurConfigured || root.orbitBackdropProgress > 0)
                visible: active && root.orbitMode && root.visible

                sourceComponent: GlassBackground {
                    visible: orbitBackdropLoader.visible
                    anchors.fill: parent
                    radius: 0
                    forceBackdrop: true
                    forceNeutralMaterial: true
                    wallpaperUrl: WallpaperListener.wallpaperUrlForScreen(root.screen)
                    blurStrength: root.orbitBackdropBlurStrength / 100
                    saturationStrength: root.orbitBackdropBlurSaturation / 100
                    auroraTransparency: 1 - root.orbitBackdropBlurTint / 100
                    fallbackColor: "transparent"
                    screenX: 0
                    screenY: 0
                    screenWidth: root.width
                    screenHeight: root.height
                    opacity: root._presentedOpen && root.orbitBackdropProgress <= 0
                        ? 0.001 : root.orbitBackdropProgress
                }
            }

            Connections {
                target: orbitBackdropLoader.item
                ignoreUnknownSignals: true
                function onBackdropReadyChanged(): void {
                    if (orbitBackdropLoader.item?.backdropReady ?? false)
                        root.beginOrbitBackdropWarmup()
                }
            }

            // Scrim de fondo: oscurece todo detrás del overview mientras está activo
            Rectangle {
                anchors.fill: parent
                z: -1
                color: {
                    const ov = Config.options?.overview ?? null
                    const v = root.orbitMode
                        ? (root.orbitOptions.scrimDim ?? 35)
                        : ((ov && ov.scrimDim !== undefined) ? ov.scrimDim : 35)
                    const clamped = Math.max(0, Math.min(100, v))
                    const a = clamped / 100
                    return ColorUtils.transparentize(Appearance.colors.colLayer0Base, 1 - a)
                }
                opacity: root.orbitMode ? root.orbitPresentationProgress
                    : (root._presentedOpen ? 1 : 0)
                visible: opacity > 0.001

                // The scrim fades a little slower than the content on the way out, so
                // the dimmed backdrop lingers under the dissolving panel instead of
                // snapping the desktop back before the surface has left.
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled && !root.orbitMode
                    animation: NumberAnimation {
                        duration: root._presentedOpen
                            ? Appearance.animation.elementMoveEnter.duration
                            : Appearance.animation.elementMoveExit.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root._presentedOpen
                            ? Appearance.animationCurves.standardDecel
                            : Appearance.animationCurves.standardAccel
                    }
                }
            }

            MouseArea {
                id: backdropClickArea
                anchors.fill: parent
                enabled: !root.applicationDragActive
                onClicked: mouse => {
                    if (root.orbitMode) {
                        GlobalStates.overviewOpen = false
                        return
                    }
                    // Cierra solo si el click es fuera del contenido visible
                    // Check against searchWidget and overviewLoader, not columnLayout
                    // because columnLayout fills the whole window height
                    const searchPos = mapToItem(searchWidget, mouse.x, mouse.y)
                    const inSearch = searchWidget.visible && searchPos.x >= 0 && searchPos.x <= searchWidget.width &&
                                     searchPos.y >= 0 && searchPos.y <= searchWidget.height
                    
                    const overviewPos = overviewLoader.item ? mapToItem(overviewLoader.item, mouse.x, mouse.y) : null
                    const inOverview = overviewLoader.item && overviewPos &&
                                       overviewPos.x >= 0 && overviewPos.x <= overviewLoader.item.width &&
                                       overviewPos.y >= 0 && overviewPos.y <= overviewLoader.item.height

                    const dashPos = dashboardPanel.visible ? mapToItem(dashboardPanel, mouse.x, mouse.y) : null
                    const inDashboard = dashboardPanel.visible && dashPos &&
                                        dashPos.x >= 0 && dashPos.x <= dashboardPanel.width &&
                                        dashPos.y >= 0 && dashPos.y <= dashboardPanel.height

                    const allAppsPos = allAppsGridLoader.item ? mapToItem(allAppsGridLoader.item, mouse.x, mouse.y) : null
                    const inAllApps = allAppsGridLoader.item && allAppsPos &&
                                      allAppsPos.x >= 0 && allAppsPos.x <= allAppsGridLoader.item.width &&
                                      allAppsPos.y >= 0 && allAppsPos.y <= allAppsGridLoader.item.height
                    
                    if (!inSearch && !inOverview && !inDashboard && !inAllApps) {
                        GlobalStates.overviewOpen = false
                    }
                }
            }

            // Focus grab for Hyprland (doesn't work on Niri)
            CompositorFocusGrab {
                id: grab
                windows: [root]
                property bool canBeActive: root.shouldShow && root.isTargetOutput
                active: false
                onCleared: () => {
                    if (!active)
                        GlobalStates.overviewOpen = false;
                }
            }
            
            // For Niri: detect window focus changes to close overview (if configured)
            Connections {
                target: CompositorService.isNiri ? NiriService : null
                enabled: CompositorService.isNiri
                function onActiveWindowChanged() {
                    // Respect keepOverviewOpenOnWindowClick setting
                    const keepOpen = Config.options?.overview?.keepOverviewOpenOnWindowClick ?? true;
                    // If a window gets focus while overview is open, close it only if not configured to keep open
                    if (GlobalStates.overviewOpen && NiriService.activeWindow && !keepOpen) {
                        GlobalStates.overviewOpen = false;
                    }
                }
            }

            Connections {
                target: GlobalStates
                function onOverviewOpenChanged() {
                    CompositorService.setSortingConsumer("overview", GlobalStates.overviewOpen)
                    if (!GlobalStates.overviewOpen) {
                        // Al cerrar, limpiar completamente la búsqueda
                        searchWidget.cancelSearch();
                        searchWidget.disableExpandAnimation();
                        overviewScope.dontAutoCancelSearch = false;
                        GlobalStates.overviewSearchPrefix = "";
                    } else {
                        if (!overviewScope.dontAutoCancelSearch) {
                            searchWidget.cancelSearch();
                        }
                    }
                }
                function onOrbitPocketRequestedChanged() {
                    if (GlobalStates.orbitPocketRequested && root._presentedOpen)
                        root.consumeOrbitPocketRequest()
                }
                function onOrbitStudioRequestedChanged() {
                    if (GlobalStates.orbitStudioRequested && root._presentedOpen)
                        root.consumeOrbitStudioRequest()
                }
                function onOrbitLensRequestedChanged() {
                    if (GlobalStates.orbitLensRequested && root._presentedOpen)
                        root.consumeOrbitLensRequest()
                }
                function onOrbitNavigateRequested(direction: int) {
                    if (!root.shouldShow || !root.orbitMode || !root.isTargetOutput)
                        return
                    const item = overviewLoader.item
                    if (item && typeof item.switchRelativeWorkspace === "function")
                        item.switchRelativeWorkspace(direction)
                    else
                        item?.focusRelativeWorkspace(direction)
                }
            }

            Timer {
                id: delayedGrabTimer
                interval: Config.options.hacks.arbitraryRaceConditionDelay
                repeat: false
                onTriggered: {
                    if (!root.shouldShow || !grab.canBeActive)
                        return;
                    grab.active = GlobalStates.overviewOpen;
                }
            }

            implicitWidth: root.orbitMode
                ? (root.screen?.width ?? columnLayout.implicitWidth)
                : columnLayout.implicitWidth
            implicitHeight: root.orbitMode
                ? (root.screen?.height ?? columnLayout.implicitHeight)
                : columnLayout.implicitHeight

            function setSearchingText(text) {
                searchWidget.setSearchingText(text);
                searchWidget.focusFirstItem();
            }

            function maybeSwitchWorkspaceOnOpen() {
                const ov = Config.options?.overview ?? null;
                if (!ov || !ov.switchToWorkspaceOnOpen || !ov.switchWorkspaceIndex || ov.switchWorkspaceIndex <= 0)
                    return;

                if (CompositorService.isNiri) {
                    const screenName = root.modelData && root.modelData.name;
                    if (!screenName)
                        return;
                    const targetIdx = ov.switchWorkspaceIndex;
                    if (!targetIdx || targetIdx <= 0)
                        return;
                    const targetWorkspace = NiriService.allWorkspaces.find(workspace =>
                        workspace.output === screenName && workspace.idx === targetIdx)
                    if (targetWorkspace)
                        NiriService.switchToWorkspaceById(targetWorkspace.id)
                } else if (CompositorService.isHyprland) {
                    if (!root.isTargetOutput)
                        return;
                    const wsNumber = ov.switchWorkspaceIndex;
                    Hyprland.dispatch(`workspace ${wsNumber}`);
                }
            }

            Column {
                id: columnLayout

                // Shell desaturation effect
                layer.enabled: Appearance.shouldDesaturate("overlays") && columnLayout.visible
                layer.effect: ShellDesaturationEffect {}

                // One 0..1 driver so the surface unfolds as a single coherent morph.
                // Orbit entry is authored independently from workspace navigation;
                // exit keeps the host-level travel while the scene itself remains
                // geometrically stable.
                // because opacity leads OUT (below) the slow tail is already invisible
                // — the surface dissolves upward toward the search bar instead of
                // visibly squishing to nothing, which is what made the old close ugly.
                readonly property int motionDuration: root.orbitMode
                    ? (root._presentedOpen ? root.orbitEnterDuration : root.orbitExitDuration)
                    : root._presentedOpen
                        ? Appearance.animation.elementMoveEnter.duration
                        : Appearance.animation.elementMoveExit.duration
                readonly property var motionCurve: root.orbitMode
                    ? (root.orbitPresentationPreset === "sweep"
                        ? Appearance.animationCurves.emphasizedDecel
                        : root._presentedOpen
                            ? Appearance.animationCurves.standardDecel
                            : Appearance.animationCurves.standardAccel)
                    : root._presentedOpen
                        ? Appearance.animation.elementMoveEnter.bezierCurve
                        : Appearance.animationCurves.emphasizedDecel
                readonly property real orbitDistanceFactor: root.orbitPresentationPreset === "soft" ? 0.65
                    : root.orbitPresentationPreset === "sweep" ? 1.8
                    : root.orbitPresentationPreset === "adaptive" ? 1.45 : 1.15
                readonly property real orbitTravel: root.orbitPresentationDistance * orbitDistanceFactor
                readonly property real orbitClosedX: root.orbitStageMode === "orbital" ? 0
                    : root.orbitEffectivePresentationDirection === "left" ? -orbitTravel
                    : root.orbitEffectivePresentationDirection === "right" ? orbitTravel : 0
                readonly property real orbitClosedY: root.orbitStageMode === "orbital" ? 0
                    : root.orbitEffectivePresentationDirection === "top" ? -orbitTravel
                    : root.orbitEffectivePresentationDirection === "bottom" ? orbitTravel : 0
                property real openProgress: root.orbitMode
                    ? (root._presentedOpen ? 1 : root.orbitPresentationProgress)
                    : (root._presentedOpen ? 1 : 0)

                // Direction-aware opacity. Open: leads in, fully legible by 70% of the
                // unfold. Close: leads out, fully faded by the time the surface has
                // receded ~45%, so the slow decel tail collapses invisibly.
                opacity: root._presentedOpen
                    ? 1
                    : root.orbitMode
                        ? root.orbitPresentationProgress
                        : Math.max(0, (openProgress - 0.45) / 0.55)
                visible: openProgress > 0.001

                Scale {
                    id: overviewScaleTransform
                    origin.x: columnLayout.width / 2
                    origin.y: 0
                    xScale: 0.975 + 0.025 * columnLayout.openProgress
                    yScale: 0.93 + 0.07 * columnLayout.openProgress
                }
                Translate {
                    id: overviewTranslateTransform
                    y: (1 - columnLayout.openProgress) * -12
                }
                Translate {
                    id: orbitPresentationTransform
                    x: (1 - columnLayout.openProgress) * columnLayout.orbitClosedX
                    y: (1 - columnLayout.openProgress) * columnLayout.orbitClosedY
                }
                transform: root.orbitMode ? [orbitPresentationTransform]
                    : [overviewScaleTransform, overviewTranslateTransform]

                Behavior on openProgress {
                    enabled: Appearance.animationsEnabled && !root.orbitMode
                    NumberAnimation {
                        duration: columnLayout.motionDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: columnLayout.motionCurve
                    }
                }
                
                // Always center the overview vertically - this is the default behavior.
                // Never use verticalCenter anchor with dynamic Column - causes blur and erratic positioning.
                // Use top anchor with calculated topMargin to center instead.
                
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    horizontalCenterOffset: root.orbitMode ? root.orbitSceneCenterOffset : 0
                    top: parent.top
                    topMargin: {
                        const ov = Config?.options?.overview;
                        const respectBar = ov && ov.respectBar !== undefined ? ov.respectBar : true;
                        
                        // Calculate bar/dock offset at top
                        let barOffset = 0;
                        if (respectBar && !(Config.options?.bar?.bottom ?? false)) {
                            barOffset = Appearance.sizes.barHeight + Appearance.rounding.screenRounding;
                        }
                        const dock = Config.options?.dock;
                        if (dock?.enable && dock?.position === "top") {
                            barOffset += (dock.height ?? 60) + 20;
                        }
                        
                        // Calculate bar/dock offset at bottom
                        let bottomOffset = 8;
                        if (respectBar && (Config.options?.bar?.bottom ?? false)) {
                            bottomOffset += Appearance.sizes.barHeight + Appearance.rounding.screenRounding;
                        }
                        if (dock?.enable && dock?.position === "bottom") {
                            bottomOffset += (dock.height ?? 60) + 20;
                        }
                        
                        // Center the content vertically in available space
                        const availableHeight = root.height - barOffset - bottomOffset;
                        const contentHeight = columnLayout.implicitHeight;
                        // Round to avoid subpixel positioning that causes blur
                        const centeredMargin = barOffset + Math.round(Math.max(0, (availableHeight - contentHeight) / 2));
                        return centeredMargin + (root.orbitMode
                            ? Math.round((1 - columnLayout.openProgress) * 8) : 0);
                    }
                }
                spacing: root.orbitMode ? 10 : -8


                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape && root.orbitMode && root.orbitStudioOpen) {
                        root.closeOrbitStudio()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape && root.orbitMode && root.orbitPocketOpen) {
                        root.orbitPocketOpen = false
                        root.orbitKeyboardZone = "shelf"
                        orbitShelfLoader.item?.focusFirstKeyboard()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape && root.orbitMode
                            && (root.orbitLensOpen || root.orbitLensText.length > 0)) {
                        root.clearOrbitLens()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        GlobalStates.overviewOpen = false;
                    } else if (root.orbitMode && root.orbitKeyboardZone !== "studio"
                            && root.orbitKeyboardZone !== "lens"
                            && (root.orbitOptions.keyboardNavigation ?? true)
                            && event.key === Qt.Key_Tab) {
                        if (root.orbitKeyboardZone === "pocket") {
                            root.orbitKeyboardZone = "windows"
                            overviewLoader.item?.ensureKeyboardWindow()
                        } else if (root.orbitKeyboardZone === "windows" && orbitShelfLoader.item?.hasKeyboardEntries) {
                            root.orbitKeyboardZone = "shelf"
                            if (event.modifiers & Qt.ShiftModifier)
                                orbitShelfLoader.item.focusLastKeyboard()
                            else
                                orbitShelfLoader.item.focusFirstKeyboard()
                        } else if (root.orbitPocketOpen && pocketLoader.item) {
                            root.orbitKeyboardZone = "pocket"
                            orbitShelfLoader.item?.clearKeyboardSelection()
                            pocketLoader.item.focusFirstKeyboard()
                        } else {
                            root.orbitKeyboardZone = "windows"
                            orbitShelfLoader.item?.clearKeyboardSelection()
                            if (event.modifiers & Qt.ShiftModifier)
                                overviewLoader.item?.focusPreviousWindow()
                            else
                                overviewLoader.item?.focusNextWindow()
                        }
                        event.accepted = true
                    } else if (root.orbitMode && root.orbitKeyboardZone !== "studio"
                            && root.orbitKeyboardZone !== "lens"
                            && (root.orbitOptions.keyboardNavigation ?? true)
                            && event.key === Qt.Key_Backtab) {
                        if (root.orbitKeyboardZone === "windows" && root.orbitPocketOpen && pocketLoader.item) {
                            root.orbitKeyboardZone = "pocket"
                            pocketLoader.item.focusFirstKeyboard()
                        } else if (root.orbitKeyboardZone === "pocket" && orbitShelfLoader.item?.hasKeyboardEntries) {
                            root.orbitKeyboardZone = "shelf"
                            orbitShelfLoader.item.focusLastKeyboard()
                        } else {
                            root.orbitKeyboardZone = "windows"
                            orbitShelfLoader.item?.clearKeyboardSelection()
                            overviewLoader.item?.focusPreviousWindow()
                        }
                        event.accepted = true
                    } else if (root.orbitMode && root.orbitKeyboardZone !== "lens"
                            && (root.orbitOptions.keyboardNavigation ?? true)
                            && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                        if (root.orbitKeyboardZone === "pocket")
                            pocketLoader.item?.activateKeyboard()
                        else if (root.orbitKeyboardZone === "shelf")
                            orbitShelfLoader.item?.activateKeyboard()
                        else
                            overviewLoader.item?.activateKeyboardWindow()
                        event.accepted = true
                    } else if (root.orbitMode && (root.orbitOptions.keyboardNavigation ?? true)
                            && root.orbitKeyboardZone === "windows"
                            && (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace)) {
                        overviewLoader.item?.closeKeyboardWindow()
                        event.accepted = true
                    } else if (root.orbitMode && root.orbitStageMode === "orbital"
                            && (root.orbitOptions.keyboardNavigation ?? true)
                            && root.orbitKeyboardZone === "windows" && event.key === Qt.Key_Space) {
                        overviewLoader.item?.activateSelectedWorkspace()
                        event.accepted = true
                    } else if (root.orbitMode && root.orbitStageMode === "orbital"
                            && (root.orbitOptions.keyboardNavigation ?? true)
                            && root.orbitKeyboardZone === "windows" && event.key === Qt.Key_R) {
                        overviewLoader.item?.resetSelectionToActive()
                        event.accepted = true
                    } else if (root.orbitMode && root.orbitStageMode === "orbital"
                            && (root.orbitOptions.keyboardNavigation ?? true)
                            && root.orbitKeyboardZone === "windows"
                            && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        overviewLoader.item?.selectWorkspaceNumber(event.key - Qt.Key_0)
                        event.accepted = true
                    } else if (root.orbitMode && (root.orbitOptions.keyboardNavigation ?? true)
                            && root.orbitKeyboardZone === "windows" && event.key === Qt.Key_S) {
                        overviewLoader.item?.stashKeyboardWindow()
                        event.accepted = true
                    } else if (root.orbitMode && (root.orbitOptions.keyboardNavigation ?? true)
                            && root.orbitKeyboardZone === "windows"
                            && (event.key === Qt.Key_Menu
                                || (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier)))) {
                        overviewLoader.item?.openKeyboardWindowContext()
                        event.accepted = true
                    } else if (root.orbitMode && (root.orbitOptions.keyboardNavigation ?? true)
                            && event.key === Qt.Key_P) {
                        const stashed = MinimizedWindows.getMinimizedForOutput(root.screen?.name ?? "")
                        if (stashed.length > 0) {
                            root.orbitPocketOpen = !root.orbitPocketOpen
                            if (root.orbitPocketOpen) {
                                root.orbitKeyboardZone = "pocket"
                                orbitShelfLoader.item?.clearKeyboardSelection()
                                Qt.callLater(() => pocketLoader.item?.focusFirstKeyboard())
                            } else {
                                root.orbitKeyboardZone = "windows"
                                overviewLoader.item?.ensureKeyboardWindow()
                            }
                        }
                        event.accepted = true
                    } else if (root.orbitMode && (root.orbitOptions.keyboardNavigation ?? true)
                            && event.key === Qt.Key_O) {
                        GlobalStates.toggleOrbitStageView()
                        root.orbitKeyboardZone = "windows"
                        orbitShelfLoader.item?.clearKeyboardSelection()
                        event.accepted = true
                    } else if (root.orbitMode && event.key === Qt.Key_E) {
                        if (root.orbitStudioOpen)
                            root.closeOrbitStudio()
                        else
                            root.openOrbitStudio()
                        event.accepted = true
                    } else if (root.orbitMode && root.orbitKeyboardZone !== "lens"
                            && event.key === Qt.Key_Slash) {
                        root.openOrbitLens()
                        event.accepted = true
                    } else if (root.orbitMode && (root.orbitOptions.keyboardNavigation ?? true)
                            && root.orbitKeyboardZone === "windows" && event.key === Qt.Key_Home) {
                        overviewLoader.item?.focusFirstWindow()
                        event.accepted = true
                    } else if (root.orbitMode && (root.orbitOptions.keyboardNavigation ?? true)
                            && root.orbitKeyboardZone === "windows" && event.key === Qt.Key_End) {
                        overviewLoader.item?.focusLastWindow()
                        event.accepted = true
                    } else if (root.orbitMode && (root.orbitOptions.keyboardNavigation ?? true)
                            && root.orbitKeyboardZone === "windows"
                            && (event.modifiers & Qt.ShiftModifier)
                            && !(event.modifiers & Qt.ControlModifier)
                            && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
                        overviewLoader.item?.moveKeyboardWindowToRelativeWorkspace(
                            event.key === Qt.Key_Left ? -1 : 1)
                        event.accepted = true
                    } else if (root.orbitMode && (root.orbitOptions.keyboardNavigation ?? true)
                            && root.orbitKeyboardZone === "windows"
                            && (event.key === Qt.Key_Left || event.key === Qt.Key_Right
                                || event.key === Qt.Key_Up || event.key === Qt.Key_Down)
                            && !(event.modifiers & Qt.ControlModifier)
                            && !(event.modifiers & Qt.ShiftModifier)) {
                        overviewLoader.item?.moveKeyboardWindow(
                            event.key === Qt.Key_Left ? -1 : event.key === Qt.Key_Right ? 1 : 0,
                            event.key === Qt.Key_Up ? -1 : event.key === Qt.Key_Down ? 1 : 0)
                        event.accepted = true
                    } else if (event.key === Qt.Key_PageUp
                            || (root.orbitMode && event.key === Qt.Key_Left
                                && (event.modifiers & Qt.ControlModifier))) {
                        if (!root.searchingText) {
                            if (root.orbitMode && CompositorService.isNiri) {
                                overviewLoader.item?.switchRelativeWorkspace(-1)
                            } else if (CompositorService.isNiri) {
                                const outputName = root.screen?.name ?? ""
                                const workspaces = NiriService.allWorkspaces
                                    .filter(workspace => workspace.output === outputName)
                                    .sort((a, b) => a.idx - b.idx)
                                const currentIndex = workspaces.findIndex(workspace => workspace.is_active)
                                if (currentIndex > 0)
                                    NiriService.switchToWorkspaceById(workspaces[currentIndex - 1].id)
                            } else {
                                Hyprland.dispatch("workspace r-1");
                            }
                        }
                    } else if (event.key === Qt.Key_PageDown
                            || (root.orbitMode && event.key === Qt.Key_Right
                                && (event.modifiers & Qt.ControlModifier))) {
                        if (!root.searchingText) {
                            if (root.orbitMode && CompositorService.isNiri) {
                                overviewLoader.item?.switchRelativeWorkspace(1)
                            } else if (CompositorService.isNiri) {
                                const outputName = root.screen?.name ?? ""
                                const workspaces = NiriService.allWorkspaces
                                    .filter(workspace => workspace.output === outputName)
                                    .sort((a, b) => a.idx - b.idx)
                                const currentIndex = workspaces.findIndex(workspace => workspace.is_active)
                                if (currentIndex >= 0 && currentIndex < workspaces.length - 1)
                                    NiriService.switchToWorkspaceById(workspaces[currentIndex + 1].id)
                            } else {
                                Hyprland.dispatch("workspace r+1");
                            }
                        }
                    } else if (root.orbitMode && (root.orbitOptions.keyboardNavigation ?? true)
                            && root.orbitKeyboardZone === "shelf"
                            && (event.key === Qt.Key_Left || event.key === Qt.Key_Up)) {
                        orbitShelfLoader.item?.focusPreviousKeyboard()
                        event.accepted = true
                    } else if (root.orbitMode && (root.orbitOptions.keyboardNavigation ?? true)
                            && root.orbitKeyboardZone === "shelf"
                            && (event.key === Qt.Key_Right || event.key === Qt.Key_Down)) {
                        orbitShelfLoader.item?.focusNextKeyboard()
                        event.accepted = true
                    } else if (root.orbitMode && (root.orbitOptions.keyboardNavigation ?? true)
                            && root.orbitKeyboardZone === "pocket"
                            && (event.key === Qt.Key_Left || event.key === Qt.Key_Up)) {
                        pocketLoader.item?.focusPreviousKeyboard()
                        event.accepted = true
                    } else if (root.orbitMode && (root.orbitOptions.keyboardNavigation ?? true)
                            && root.orbitKeyboardZone === "pocket"
                            && (event.key === Qt.Key_Right || event.key === Qt.Key_Down)) {
                        pocketLoader.item?.focusNextKeyboard()
                        event.accepted = true
                    }
                }

                SearchWidget {
                    id: searchWidget
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !root.orbitMode
                    searchingText: root.searchingText
                    panelVisible: root.visible
                    // Centered mode: limit search results to 60% of screen height
                    availableHeight: Math.max(220, root.height * 0.6)
                    onSearchingTextChanged: if (searchingText !== root.searchingText) root.searchingText = searchingText
                }

                Loader {
                    id: overviewLoader
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: root.orbitMode
                        ? Math.round((1 - root.orbitStageReveal)
                            * root.orbitStageSwitchDirection * 24) : 0
                    readonly property real orbitEntryVisual: root.orbitEntryStyle === "instant"
                        ? 1 : root.orbitEntryProgress
                    readonly property real orbitEntryTravelFactor: root.orbitStageMode === "orbital" ? 0
                        : root.orbitEntryStyle === "fade" ? 0
                        : root.orbitEntryStyle === "drift" ? 0.52 : 0.20
                    readonly property real orbitEntryTravel: root.orbitPresentationDistance * orbitEntryTravelFactor
                    readonly property real orbitEntryX: root.orbitEffectivePresentationDirection === "left" ? -orbitEntryTravel
                        : root.orbitEffectivePresentationDirection === "right" ? orbitEntryTravel : 0
                    readonly property real orbitEntryY: root.orbitEffectivePresentationDirection === "top" ? -orbitEntryTravel
                        : root.orbitEffectivePresentationDirection === "bottom" ? orbitEntryTravel : 0
                    opacity: root.orbitMode
                        ? Math.min(1, root.orbitStageReveal * 1.35)
                            * (root.orbitEntryOpacityStart
                                + (1 - root.orbitEntryOpacityStart) * orbitEntryVisual)
                        : 1
                    Translate {
                        id: orbitStageEntryTransform
                        x: (1 - overviewLoader.orbitEntryVisual) * overviewLoader.orbitEntryX
                        y: (1 - overviewLoader.orbitEntryVisual) * overviewLoader.orbitEntryY
                    }
                    transform: root.orbitMode ? [orbitStageEntryTransform] : []
                    readonly property bool dashboardMode: Config.options?.overview?.dashboard?.enable ?? false
                    readonly property bool allAppsGridEnabled: Config.options?.overview?.allAppsGrid ?? false
                    active: (root.orbitMode ? root.visible : root.shouldShow)
                        && (root.orbitMode || (!dashboardMode && !allAppsGridEnabled))
                        && (root.orbitMode || (Config.options?.overview?.enable ?? true))
                    visible: active && (root.searchingText == "")
                    sourceComponent: root.orbitMode
                        ? (CompositorService.isNiri
                            ? (root.orbitStageMode === "orbital" ? orbitalComponent : niriComponent)
                            : null)
                        : (CompositorService.isNiri ? niriComponent : hyprComponent)
                    onStatusChanged: {
                        if (status === Loader.Ready && root.orbitMode && root.shouldShow) {
                            Qt.callLater(root.startOrbitPresentation)
                            Qt.callLater(root.publishOrbitRuntimeStatus)
                        }
                    }
                }

                Connections {
                    target: root.orbitStageMode === "orbital" ? overviewLoader.item : null
                    ignoreUnknownSignals: true
                    function onSpatialLayoutChanged(): void { root.publishOrbitRuntimeStatus() }
                    function onDisplayedWorkspacesChanged(): void { root.publishOrbitRuntimeStatus() }
                    function onSelectedWorkspaceIdChanged(): void { root.publishOrbitRuntimeStatus() }
                    function onWidthChanged(): void { root.publishOrbitRuntimeStatus() }
                    function onHeightChanged(): void { root.publishOrbitRuntimeStatus() }
                    function onWheelEventCountChanged(): void { root.publishOrbitRuntimeStatus() }
                }

                Item {
                    id: pocketHost
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: pocketLoader.item?.implicitWidth ?? 0
                    implicitHeight: root.orbitPocketOpen ? (pocketLoader.item?.implicitHeight ?? 0) : 0
                    opacity: root.orbitPocketOpen ? 1 : 0
                    clip: implicitHeight + 0.5 < (pocketLoader.item?.implicitHeight ?? 0)

                    Behavior on implicitHeight {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    Loader {
                        id: pocketLoader
                        anchors.horizontalCenter: parent.horizontalCenter
                        active: root.visible && root.orbitMode
                            && (root.orbitPocketOpen || pocketHost.implicitHeight > 0.5)
                            && MinimizedWindows.getMinimizedForOutput(root.screen?.name ?? "").length > 0
                        visible: active && status === Loader.Ready
                        sourceComponent: Component {
                            OrbitPocket {
                                outputName: root.screen?.name ?? ""
                                availableWidth: root.orbitWorkingWidth
                                    * Math.max(0.6, Math.min(1.0,
                                        (root.orbitOptions.maxPanelWidthPercent ?? 92) / 100))
                                onDismissed: {
                                    root.orbitPocketOpen = false
                                    root.orbitKeyboardZone = "shelf"
                                    orbitShelfLoader.item?.focusFirstKeyboard()
                                }
                            }
                        }
                    }
                }

                Loader {
                    id: orbitShelfLoader
                    anchors.horizontalCenter: parent.horizontalCenter
                    active: root.visible && root.orbitMode
                        && (root.orbitOptions.shelf?.enable ?? true)
                    visible: active && status === Loader.Ready
                    opacity: root.orbitShelfEntryProgress
                    Translate {
                        id: orbitShelfEntryTransform
                        y: (1 - root.orbitShelfEntryProgress) * 14
                    }
                    transform: [orbitShelfEntryTransform]
                    sourceComponent: Component {
                        OrbitShelf {
                            outputName: root.screen?.name ?? ""
                            runtimeOrbitOptions: root.orbitOptions
                            studioOpen: root.orbitStudioOpen
                            filterText: root.orbitLensText
                            contextWorkspaceId: root.orbitStageMode === "orbital"
                                ? (overviewLoader.item?.selectedWorkspaceId ?? -1) : -1
                            availableWidth: root.orbitWorkingWidth
                                * Math.max(0.6, Math.min(1.0,
                                    (root.orbitOptions.maxPanelWidthPercent ?? 92) / 100))
                            onPocketRequested: {
                                root.orbitPocketOpen = true
                                root.orbitKeyboardZone = "pocket"
                                Qt.callLater(() => pocketLoader.item?.focusFirstKeyboard())
                            }
                            onStudioRequested: {
                                if (root.orbitStudioOpen)
                                    root.closeOrbitStudio()
                                else
                                    root.openOrbitStudio()
                            }
                        }
                    }
                }

                Loader {
                    id: allAppsGridLoader
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property bool allAppsEnabled: Config.options?.overview?.allAppsGrid ?? false
                    readonly property bool dashboardMode: Config.options?.overview?.dashboard?.enable ?? false
                    active: root.shouldShow && !root.orbitMode && allAppsEnabled && !dashboardMode
                    visible: active && (root.searchingText == "")
                    sourceComponent: allAppsGridComponent
                }

                Component {
                    id: hyprComponent
                    OverviewWidget {
                        panelWindow: root
                        visible: (root.searchingText == "")
                    }
                }

                Component {
                    id: niriComponent
                    OverviewNiriWidget {
                        panelWindow: root
                        orbitMode: root.orbitMode
                        runtimeOrbitOptions: root.orbitOptions
                        filterText: root.orbitLensText
                        orbitEntryProgress: root.orbitEntryProgress
                        availableWidthOverride: root.orbitMode ? root.orbitWorkingWidth : 0
                        visible: (root.searchingText == "")
                    }
                }

                Component {
                    id: orbitalComponent
                    OrbitOrbitalStage {
                        panelWindow: root
                        runtimeOrbitOptions: root.orbitOptions
                        filterText: root.orbitLensText
                        entryProgress: root.orbitEntryProgress
                        entryStaggerMs: root.orbitEntryStaggerMs
                        entryDurationMs: root.orbitEnterDuration
                        entryCascade: root.orbitEntryStyle === "cascade"
                        availableWidth: root.orbitWorkingWidth
                            * Math.max(0.6, Math.min(1.0,
                                (root.orbitOptions.maxPanelWidthPercent ?? 92) / 100))
                        availableHeight: Math.max(1, root.height * 0.66)
                        visible: root.searchingText == ""
                    }
                }

                Component {
                    id: allAppsGridComponent
                    OverviewAllAppsGrid {
                        panelVisible: root.visible
                        availableHeight: Math.max(400, root.height * 0.78)
                        onAppLaunched: GlobalStates.overviewOpen = false
                    }
                }

                // Dashboard panel below workspace thumbnails
                Loader {
                    id: dashboardPanel
                    anchors.horizontalCenter: parent.horizontalCenter
                    active: !root.orbitMode && (Config.options?.overview?.dashboard?.enable ?? false)
                    visible: active && status === Loader.Ready
                        && root.shouldShow && (root.searchingText == "")
                    opacity: root._presentedOpen ? 1 : 0
                    sourceComponent: Component {
                        OverviewDashboard {
                            panelVisible: root.visible
                            availableWidth: dashboardPanel.parent?.width ?? root.width
                            availableHeight: Math.max(260, root.height * 0.78)
                        }
                    }

                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation?.elementMoveEnter?.duration ?? 400
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves?.emphasizedDecel ?? [0.05, 0.7, 0.1, 1, 1, 1]
                        }
                    }
                }
            }

            Loader {
                id: orbitLensLoader
                active: root.shouldShow && root.orbitMode
                    && (root.orbitLensOpen || root.orbitLensText.length > 0)
                visible: active && status === Loader.Ready
                z: 2800
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 18
                sourceComponent: Component {
                    OrbitFocusLens {
                        query: root.orbitLensText
                        resultCount: root.orbitLensResultCount
                        onQueryChangedByUser: query => {
                            root.orbitLensText = query
                            Qt.callLater(() => overviewLoader.item?.ensureKeyboardWindow())
                        }
                        onAccepted: root.acceptOrbitLens()
                        onCleared: root.clearOrbitLens()
                    }
                }
            }

            Loader {
                id: orbitStudioLoader
                active: root.shouldShow && root.orbitMode && root.orbitStudioOpen
                visible: active && status === Loader.Ready
                z: 3000
                x: root.orbitStudioDocked ? 0 : root.orbitStudioX
                y: root.orbitStudioDocked ? 0 : root.orbitStudioY
                width: root.orbitStudioDocked ? root.width : root.orbitStudioWidth
                height: root.orbitStudioDocked ? root.height : root.orbitStudioHeight
                sourceComponent: Component {
                    OrbitStudioWorkspace {
                        width: orbitStudioLoader.width
                        height: orbitStudioLoader.height
                        effectiveOptions: root.orbitOptions
                        dirty: Object.keys(root.orbitStudioDraft).length > 0
                        availableWidth: orbitStudioLoader.width
                        availableHeight: orbitStudioLoader.height
                        docked: root.orbitStudioDocked
                        inspectorWidth: root.orbitStudioWidth
                        onPreviewRequested: (path, value) => root.setOrbitStudioPreview(path, value)
                        onCommitRequested: root.commitOrbitStudioPreview()
                        onRevertRequested: root.clearOrbitStudioPreview()
                        onResetDefaultsRequested: root.resetOrbitDefaults()
                        onDismissed: root.closeOrbitStudio()
                        onMoveStarted: root.beginOrbitStudioMove()
                        onMoveRequested: (deltaX, deltaY) => root.updateOrbitStudioMove(deltaX, deltaY)
                        onResizeStarted: root.beginOrbitStudioResize()
                        onResizeRequested: (deltaX, deltaY) => root.updateOrbitStudioResize(deltaX, deltaY)
                        onResetGeometryRequested: root.resetOrbitStudioGeometry()
                        onDockRequested: docked => root.setOrbitStudioDocked(docked)
                        onHeightHintRequested: height => root.applyOrbitStudioHeightHint(height)
                    }
                }
            }
        }
    }

}
