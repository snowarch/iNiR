pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.workspaceStrip
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Item {
    id: root
    required property var panelWindow
    property bool orbitMode: false
    property var runtimeOrbitOptions: null
    property string filterText: ""
    property real orbitEntryProgress: 1
    property real availableWidthOverride: 0

    readonly property var overviewOptions: Config.options?.overview ?? {}
    readonly property var orbitOptions: runtimeOrbitOptions ?? Config.options?.orbit ?? {}
    readonly property var navigationOptions: orbitOptions.navigationMotion ?? ({})
    readonly property string navigationPreset: OrbitTuning.navigationPreset(navigationOptions)
    readonly property bool navigationAdvanced: OrbitTuning.navigationAdvanced(navigationOptions)
    readonly property int orbitNavigationDuration: !orbitMode
        ? Appearance.animation.elementMoveFast.duration
        : OrbitTuning.navigationDuration(navigationOptions)
    readonly property string orbitNavigationEasing: OrbitTuning.navigationEasing(navigationOptions)
    readonly property int orbitNavigationEasingType: OrbitTuning.navigationEasingType(navigationOptions)
    readonly property int overviewRows: orbitMode ? 1 : (overviewOptions.rows ?? 3)
    readonly property int overviewColumns: orbitMode
        ? Math.max(1, Math.min(5, orbitOptions.workspaceCount ?? 3))
        : (overviewOptions.columns ?? 1)
    readonly property real overviewScale: orbitMode
        ? Math.max(0.16, Math.min(0.42, (orbitOptions.workspaceScalePercent ?? 27) / 100))
        : (overviewOptions.scale ?? 0.17)
    readonly property real overviewMaxPanelWidthRatio: orbitMode
        ? Math.max(0.6, Math.min(1.0, (orbitOptions.maxPanelWidthPercent ?? 92) / 100))
        : (overviewOptions.maxPanelWidthRatio ?? 1.0)
    readonly property int overviewWorkspaceSpacing: orbitMode
        ? (orbitOptions.workspaceSpacing ?? 18)
        : (overviewOptions.workspaceSpacing ?? 5)
    readonly property int overviewWindowTileMargin: overviewOptions.windowTileMargin ?? 6
    readonly property string orbitWindowLabels: ["hover", "always", "off"].includes(orbitOptions.windowLabels)
        ? orbitOptions.windowLabels : "hover"
    readonly property bool orbitWindowLabelIcons: orbitOptions.windowLabelIcons ?? true
    readonly property int overviewScrollWorkspaceSteps: overviewOptions.scrollWorkspaceSteps ?? 2

    function windowMatchesFilter(windowData): bool {
        const query = root.filterText.trim().toLowerCase()
        if (!root.orbitMode || query.length === 0)
            return true
        const title = String(windowData?.title ?? "").toLowerCase()
        const appId = String(windowData?.app_id ?? windowData?.appId ?? "").toLowerCase()
        return title.includes(query) || appId.includes(query)
    }

    readonly property bool overviewFocusAnimEnabled: overviewOptions.focusAnimationEnable ?? true
    readonly property int overviewFocusAnimDurationMs: overviewOptions.focusAnimationDurationMs ?? 180
    readonly property bool overviewKeepOpenOnWindowClick: orbitMode
        ? !(orbitOptions.closeOnSelect ?? true)
        : (overviewOptions.keepOverviewOpenOnWindowClick ?? true)
    readonly property bool overviewShowWorkspaceNumbers: orbitMode
        ? (orbitOptions.showWorkspaceNumbers ?? true)
        : (overviewOptions.showWorkspaceNumbers ?? true)

    readonly property string wallpaperPathRaw: Config.options?.background?.wallpaperPath ?? ""
    readonly property string wallpaperThumbnailPath: Config.options?.background?.thumbnailPath ?? wallpaperPathRaw

    readonly property int workspacesShown: root.overviewRows * root.overviewColumns
    readonly property string outputName: panelWindow?.screen?.name ?? ""
    readonly property var workspacesForOutput: NiriService.allWorkspaces
        .filter(workspace => workspace.output === root.outputName
            && (!root.orbitMode || !root.isStashWorkspace(workspace.id)))
        .sort((a, b) => a.idx - b.idx)
    readonly property var outputWorkspaceNumbers: workspacesForOutput.map(workspace => workspace.idx)
    readonly property int currentWorkspaceNumber: {
        const activeWorkspace = workspacesForOutput.find(workspace => workspace.is_active)
        return activeWorkspace?.idx ?? (outputWorkspaceNumbers[0] ?? 1)
    }
    readonly property int currentWorkspaceSlot: {
        if (!outputWorkspaceNumbers || outputWorkspaceNumbers.length === 0)
            return 0;
        const idx = outputWorkspaceNumbers.indexOf(currentWorkspaceNumber);
        return idx >= 0 ? idx : 0;
    }
    readonly property int totalWorkspacesForOutput: workspacesForOutput ? workspacesForOutput.length : 0
    readonly property int firstVisibleWorkspaceSlot: {
        const total = totalWorkspacesForOutput;
        if (total <= 0)
            return 0;
        const cur = currentWorkspaceSlot;
        const slots = workspacesShown <= 0 ? 1 : workspacesShown;
        const half = Math.floor(slots / 2);
        var start = cur - half;
        if (start < 0)
            start = 0;
        if (start + slots > total)
            start = Math.max(0, total - slots);
        return start;
    }

    property real scale: root.overviewScale
    property real clampedPanelWidthRatio: {
        const r = root.overviewMaxPanelWidthRatio;
        return Math.max(0.1, Math.min(1.0, r));
    }
    readonly property var orbitSurfaceOptions: root.orbitOptions.orbital?.surface ?? ({})
    readonly property string orbitSurfaceStyle: root.orbitSurfaceOptions.style === "ricelin"
        ? "ricelin" : "current"
    readonly property bool orbitSurfaceOutline: root.orbitSurfaceOptions.outline ?? true
    readonly property int orbitSurfaceOutlineWidth: Math.max(0,
        Math.min(4, root.orbitSurfaceOptions.outlineWidth ?? 1))
    readonly property real orbitSurfaceOutlineOpacity: Math.max(0,
        Math.min(100, root.orbitSurfaceOptions.outlineOpacityPercent ?? 72)) / 100
    readonly property int orbitSurfaceFrameInset: Math.max(0,
        Math.min(18, root.orbitSurfaceOptions.frameInset ?? 5))
    readonly property string orbitSurfaceShadowMode: ["off", "core", "all"].includes(
        root.orbitSurfaceOptions.shadowMode) ? root.orbitSurfaceOptions.shadowMode : "core"
    readonly property real orbitSurfaceShadowOpacity: Math.max(0,
        Math.min(100, root.orbitSurfaceOptions.shadowOpacityPercent ?? 72)) / 100
    readonly property int orbitSurfaceCoreElevation: Math.max(0,
        Math.min(4, root.orbitSurfaceOptions.coreElevation ?? 2))
    readonly property int orbitSurfaceSatelliteElevation: Math.max(0,
        Math.min(4, root.orbitSurfaceOptions.satelliteElevation ?? 1))
    readonly property real orbitSurfaceRadiusScale: Math.max(0.55,
        Math.min(1.6, (root.orbitSurfaceOptions.radiusPercent ?? 100) / 100))
    property color activeBorderColor: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colSecondary
    property bool focusAnimEnabled: root.overviewFocusAnimEnabled
    property int focusAnimDuration: root.overviewFocusAnimDurationMs
    property bool keepOverviewOpenOnWindowClick: root.overviewKeepOpenOnWindowClick
    property bool showWorkspaceNumber: root.overviewShowWorkspaceNumbers

    // Wallpaper de fondo a reutilizar en cada workspace
    property bool wallpaperIsVideo: wallpaperPathRaw.endsWith(".mp4")
                                    || wallpaperPathRaw.endsWith(".webm")
                                    || wallpaperPathRaw.endsWith(".mkv")
                                    || wallpaperPathRaw.endsWith(".avi")
                                    || wallpaperPathRaw.endsWith(".mov")
    property string wallpaperPath: root.orbitMode
        ? WallpaperListener.wallpaperUrlForScreen(root.panelWindow?.screen ?? null)
        : (wallpaperIsVideo ? wallpaperThumbnailPath : wallpaperPathRaw)

    property var outputs: NiriService.outputs

    property var currentOutputInfo: (!outputName && Object.keys(outputs).length > 0)
                                    ? outputs[Object.keys(outputs)[0]]
                                    : outputs[outputName]

    property int logicalWidth: currentOutputInfo && currentOutputInfo.logical ? currentOutputInfo.logical.width : 1920
    property int logicalHeight: currentOutputInfo && currentOutputInfo.logical ? currentOutputInfo.logical.height : 1080
    property real logicalScale: currentOutputInfo && currentOutputInfo.logical && currentOutputInfo.logical.scale !== undefined
                                 ? currentOutputInfo.logical.scale : 1.0

    property real baseWorkspaceWidth: (logicalWidth * root.scale) / logicalScale
    property real baseWorkspaceHeight: (logicalHeight * root.scale) / logicalScale
    property real workspaceImplicitWidth: {
        const cols = root.overviewColumns;
        const spacing = root.workspaceSpacing;
        const totalBase = baseWorkspaceWidth * cols + spacing * Math.max(0, cols - 1);
        const ownerWidth = root.availableWidthOverride > 0
            ? root.availableWidthOverride
            : (panelWindow ? panelWindow.width : (logicalWidth / logicalScale));
        const maxWidth = ownerWidth * clampedPanelWidthRatio;
        if (cols <= 0 || totalBase <= maxWidth)
            return baseWorkspaceWidth;
        return (maxWidth - spacing * Math.max(0, cols - 1)) / cols;
    }
    property real workspaceImplicitHeight: {
        const aspect = baseWorkspaceHeight <= 0 || baseWorkspaceWidth <= 0 ? 1 : baseWorkspaceHeight / baseWorkspaceWidth;
        return workspaceImplicitWidth * aspect;
    }
    readonly property real previewDpr: Math.max(1, panelWindow?.devicePixelRatio ?? 1)
    readonly property real previewDecodeScale: Math.max(1.8, previewDpr * 1.35)
    readonly property int previewDecodeWidth: Math.max(640,
        Math.min(1600, Math.round(workspaceImplicitWidth * previewDecodeScale)))
    readonly property int previewDecodeHeight: Math.max(360,
        Math.min(900, Math.round(previewDecodeWidth * 9 / 16)))

    property real workspaceNumberMargin: 80
    property real workspaceNumberSize: root.orbitMode ? 120 : 250
    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999
    property real workspaceSpacing: root.overviewWorkspaceSpacing

    property var contextWindowData: null
    property Item contextAnchorItem: null
    property var contextAnchorRect: null

    // Orbit uses real wheel delta so high-resolution wheels/touchpads and
    // classic 120-unit notches share the same configured sensitivity.
    property real orbitWheelAngleAccumulator: 0
    property real orbitWheelPixelAccumulator: 0
    property int wheelStepCounter: 0
    property int wheelStepsRequired: Math.max(1, root.orbitMode
        ? (root.orbitOptions.scrollSteps ?? 1)
        : root.overviewScrollWorkspaceSteps)

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1
    readonly property int stashTargetWorkspace: -2
    readonly property bool dragActive: draggingFromWorkspace !== -1
    property bool stashDropHovered: false
    property bool newWorkspaceDropHovered: false
    property int keyboardWindowIndex: -1
    readonly property var keyboardWindows: windowSpace.windowItems.filter(item =>
        item.workspaceSlot === root.currentWorkspaceSlot)
    readonly property int keyboardWindowId: keyboardWindowIndex >= 0
        && keyboardWindowIndex < keyboardWindows.length
        ? keyboardWindows[keyboardWindowIndex].id : -1

    implicitWidth: overviewBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: overviewBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

    Timer {
        id: dragCleanupTimer
        interval: 100
        onTriggered: {
            root.draggingFromWorkspace = -1
            root.draggingTargetWorkspace = -1
            root.stashDropHovered = false
            root.newWorkspaceDropHovered = false
        }
    }

    function openWindowContext(windowItem, mouseX, mouseY) {
        if (!windowItem || !windowItem.windowData) return
        contextWindowData = windowItem.windowData
        contextAnchorItem = windowItem
        contextAnchorRect = { x: mouseX, y: mouseY, width: 1, height: 1 }
        windowContextMenu.requestOpen()
    }

    function closeWindowContext() {
        windowContextMenu.close()
        contextWindowData = null
        contextAnchorItem = null
        contextAnchorRect = null
    }

    function contextWorkspaceNeighbor(delta): var {
        if (!contextWindowData)
            return null
        const workspaces = root.workspacesForOutput ?? []
        const index = workspaces.findIndex(workspace => workspace.id === contextWindowData.workspace_id)
        const targetIndex = index + delta
        if (index < 0 || targetIndex < 0 || targetIndex >= workspaces.length)
            return null
        return workspaces[targetIndex]
    }

    function contextMenuModel(): var {
        if (!contextWindowData)
            return []
        const windowId = contextWindowData.id
        const previousWorkspace = contextWorkspaceNeighbor(-1)
        const nextWorkspace = contextWorkspaceNeighbor(1)
        return [
            {
                text: Translation.tr("Focus window"),
                iconName: "center_focus_strong",
                monochromeIcon: true,
                action: () => {
                    NiriService.focusWindow(windowId)
                    if (!root.keepOverviewOpenOnWindowClick)
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

    function moveDraggedWindowToWorkspace(windowData, workspaceId): bool {
        if (!windowData || workspaceId < 0)
            return false
        if (windowData.workspace_id === workspaceId)
            return true
        return NiriService.moveWindowToWorkspaceById(windowData.id, workspaceId, false)
    }

    function stashDraggedWindow(windowData): bool {
        if (!windowData || !(root.orbitOptions.showStash ?? true))
            return false
        return MinimizedWindows.minimize(windowData.id) === true
    }

    function moveDraggedWindowToNewWorkspace(windowData): bool {
        if (!windowData || !(root.orbitOptions.showNewWorkspaceDrop ?? true))
            return false
        const workspaces = root.workspacesForOutput ?? []
        if (workspaces.length === 0)
            return false
        const trailingWorkspace = workspaces[workspaces.length - 1]
        if (!trailingWorkspace)
            return false
        return root.moveDraggedWindowToWorkspace(windowData, trailingWorkspace.id)
    }

    function isStashWorkspace(workspaceId): bool {
        const windows = (NiriService.windows ?? []).filter(window => window.workspace_id === workspaceId)
        return windows.length > 0 && windows.every(window => MinimizedWindows.isMinimized(window.id))
    }

    function focusNextWindow(): void {
        const count = keyboardWindows.length
        if (count === 0) return
        keyboardWindowIndex = keyboardWindowIndex < 0 ? 0 : (keyboardWindowIndex + 1) % count
    }

    function focusPreviousWindow(): void {
        const count = keyboardWindows.length
        if (count === 0) return
        keyboardWindowIndex = keyboardWindowIndex < 0 ? count - 1
            : (keyboardWindowIndex - 1 + count) % count
    }

    function ensureKeyboardWindow(): void {
        if (keyboardWindows.length === 0) {
            keyboardWindowIndex = -1
            return
        }
        if (keyboardWindowIndex < 0 || keyboardWindowIndex >= keyboardWindows.length)
            keyboardWindowIndex = 0
    }

    function focusFirstWindow(): void {
        keyboardWindowIndex = keyboardWindows.length > 0 ? 0 : -1
    }

    function focusLastWindow(): void {
        keyboardWindowIndex = keyboardWindows.length > 0 ? keyboardWindows.length - 1 : -1
    }

    function moveKeyboardWindow(horizontal: int, vertical: int): void {
        const count = keyboardWindows.length
        if (count === 0) return
        ensureKeyboardWindow()

        if (!(root.orbitOptions.balancedGrid ?? true)) {
            if (horizontal < 0 || vertical < 0) focusPreviousWindow()
            else if (horizontal > 0 || vertical > 0) focusNextWindow()
            return
        }

        const columns = count <= 1 ? 1 : count <= 4 ? 2 : Math.ceil(Math.sqrt(count))
        const row = Math.floor(keyboardWindowIndex / columns)
        const col = keyboardWindowIndex % columns
        const targetRow = Math.max(0, row + vertical)
        const targetCol = Math.max(0, Math.min(columns - 1, col + horizontal))
        let target = targetRow * columns + targetCol

        if (target >= count) {
            const lastRowStart = Math.floor((count - 1) / columns) * columns
            target = Math.min(count - 1, lastRowStart + targetCol)
        }
        keyboardWindowIndex = Math.max(0, Math.min(count - 1, target))
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
        const shouldWrap = wrapAround === undefined ? false : Boolean(wrapAround)
        const workspaces = root.workspacesForOutput
        if (!workspaces || workspaces.length < 2) return
        const currentIndex = workspaces.findIndex(workspace => workspace.is_active)
        if (currentIndex < 0) return
        const targetIndex = root.relativeWorkspaceIndex(currentIndex, direction, shouldWrap)
        if (targetIndex === currentIndex) return
        NiriService.switchToWorkspaceById(workspaces[targetIndex].id)
    }

    function switchRelativeWorkspace(direction: int, wrapAround): void {
        const shouldWrap = wrapAround === undefined
            ? (root.orbitOptions.scrollWrapAround ?? false) : Boolean(wrapAround)
        root.focusRelativeWorkspace(direction, shouldWrap)
    }

    function moveKeyboardWindowToRelativeWorkspace(direction: int): void {
        ensureKeyboardWindow()
        if (keyboardWindowId < 0 || !NiriService.actionReady)
            return
        const selected = keyboardWindows[keyboardWindowIndex]
        if (!selected || !selected.window)
            return
        const workspaces = root.workspacesForOutput
        const currentIndex = workspaces.findIndex(workspace => workspace.id === selected.window.workspace_id)
        if (currentIndex < 0)
            return
        const targetIndex = currentIndex + direction
        if (targetIndex < 0 || targetIndex >= workspaces.length)
            return
        if (NiriService.moveWindowToWorkspaceById(keyboardWindowId, workspaces[targetIndex].id, false))
            keyboardWindowIndex = -1
    }

    function activateKeyboardWindow(): void {
        ensureKeyboardWindow()
        if (keyboardWindowId < 0) return
        NiriService.focusWindow(keyboardWindowId)
        if (root.orbitOptions.closeOnSelect ?? true)
            GlobalStates.closeOverview()
    }

    function closeKeyboardWindow(): void {
        ensureKeyboardWindow()
        if (keyboardWindowId < 0) return
        NiriService.closeWindow(keyboardWindowId)
        keyboardWindowIndex = -1
    }

    function stashKeyboardWindow(): void {
        ensureKeyboardWindow()
        if (keyboardWindowId < 0 || !(root.orbitOptions.showStash ?? true)) return
        MinimizedWindows.minimize(keyboardWindowId)
        keyboardWindowIndex = -1
    }

    function openKeyboardWindowContext(): void {
        ensureKeyboardWindow()
        if (keyboardWindowId < 0) return
        for (let i = 0; i < windowRepeater.count; ++i) {
            const item = windowRepeater.itemAt(i)
            if (!item || item.windowId !== keyboardWindowId) continue
            root.openWindowContext(item, item.width / 2, item.height / 2)
            return
        }
    }

    onCurrentWorkspaceSlotChanged: keyboardWindowIndex = -1

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (!GlobalStates.overviewOpen) {
                root.closeWindowContext()
            }
        }
    }





    // Scroll del mouse para subir/bajar de workspace en Niri
    WheelHandler {
        enabled: !root.orbitMode || (root.orbitOptions.scrollNavigation ?? true)
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            let deltaY = event.angleDelta.y
            let pixelY = event.pixelDelta.y

            if (Config.options?.bar?.workspaces?.invertScroll ?? false) {
                deltaY = -deltaY
                pixelY = -pixelY
            }

            if (root.orbitMode) {
                if (deltaY !== 0) {
                    root.orbitWheelAngleAccumulator += deltaY
                    const threshold = 120 * root.wheelStepsRequired
                    if (Math.abs(root.orbitWheelAngleAccumulator) < threshold) {
                        event.accepted = true
                        return
                    }
                    const direction = root.orbitWheelAngleAccumulator < 0 ? 1 : -1
                    root.orbitWheelAngleAccumulator += direction > 0 ? threshold : -threshold
                    root.orbitWheelPixelAccumulator = 0
                    root.switchRelativeWorkspace(direction,
                        root.orbitOptions.scrollWrapAround ?? false)
                    event.accepted = true
                    return
                }

                if (pixelY === 0)
                    return
                root.orbitWheelPixelAccumulator += pixelY
                const pixelThreshold = 48 * root.wheelStepsRequired
                if (Math.abs(root.orbitWheelPixelAccumulator) >= pixelThreshold) {
                    const direction = root.orbitWheelPixelAccumulator < 0 ? 1 : -1
                    root.orbitWheelPixelAccumulator += direction > 0 ? pixelThreshold : -pixelThreshold
                    root.orbitWheelAngleAccumulator = 0
                    root.switchRelativeWorkspace(direction,
                        root.orbitOptions.scrollWrapAround ?? false)
                }
                event.accepted = true
                return
            }

            if (deltaY === 0)
                return

            // Requerir varios pasos de rueda antes de cambiar de workspace
            root.wheelStepCounter += 1
            if (root.wheelStepCounter < root.wheelStepsRequired)
                return
            root.wheelStepCounter = 0

            const direction = deltaY < 0 ? 1 : -1

            const wsList = root.outputWorkspaceNumbers
            if (!wsList || wsList.length < 2)
                return

            const currentNumber = root.currentWorkspaceNumber
            const currentIndex = wsList.indexOf(currentNumber)
            const validIndex = currentIndex === -1 ? 0 : currentIndex
            const nextIndex = direction > 0
                    ? Math.min(validIndex + 1, wsList.length - 1)
                    : Math.max(validIndex - 1, 0)
            if (nextIndex === validIndex)
                return

            const nextWorkspace = root.workspacesForOutput[nextIndex]
            if (nextWorkspace)
                NiriService.switchToWorkspaceById(nextWorkspace.id)
        }
    }

    StyledRectangularShadow {
        target: overviewBackground
        visible: Appearance.angelEverywhere || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere)
    }

    Rectangle {
        id: overviewBackground
        property real padding: root.orbitMode ? 16 : 10
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin

        implicitWidth: workspaceColumnLayout.implicitWidth + padding * 2
        implicitHeight: workspaceColumnLayout.implicitHeight + padding * 2
        radius: Appearance.angelEverywhere ? Appearance.angel.roundingLarge
            : Appearance.inirEverywhere ? Appearance.inir.roundingLarge
            : (Appearance.rounding.large + padding)
        clip: false
        color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
             : Appearance.inirEverywhere ? Appearance.inir.colLayer1
             : Appearance.auroraEverywhere ? Appearance.aurora.colPopupSurface
             : Appearance.colors.colBackgroundSurfaceContainer
        border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
        border.color: Appearance.angelEverywhere ? Appearance.angel.colBorder
            : Appearance.inirEverywhere ? Appearance.inir.colBorder
            : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.72)
            : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.68)

        Column {
            id: workspaceColumnLayout

            z: root.workspaceZ
            anchors.centerIn: parent
            spacing: workspaceSpacing

            Repeater {
                model: root.overviewRows
                delegate: Row {
                    id: row
                    required property int index
                    spacing: workspaceSpacing

                    Repeater {
                        model: root.overviewColumns
                        Rectangle {
                            id: workspace
                            required property int index
                            property int colIndex: index
                            property int workspaceIndex: root.firstVisibleWorkspaceSlot + row.index * root.overviewColumns + colIndex

                            property var workspaceObj: {
                                const wsList = root.workspacesForOutput
                                if (!wsList || wsList.length === 0)
                                    return null
                                if (workspaceIndex < 0 || workspaceIndex >= wsList.length)
                                    return null
                                return wsList[workspaceIndex]
                            }

                            // Número mostrado en el recuadro (1..N dentro del output actual)
                            property int workspaceValue: workspaceIndex + 1

                            property bool workspaceExists: workspaceObj !== null
                            property bool isActive: workspaceObj && workspaceObj.is_active
                            property color defaultWorkspaceColor: workspaceExists
                                ? (Appearance.angelEverywhere ? Appearance.angel.colGlassPopup
                                    : Appearance.inirEverywhere ? Appearance.inir.colLayer2 
                                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface 
                                    : Appearance.colors.colBackgroundSurfaceContainer)
                                : ColorUtils.transparentize(Appearance.angelEverywhere ? Appearance.angel.colGlassPopup
                                    : Appearance.inirEverywhere ? Appearance.inir.colLayer2 
                                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface 
                                    : Appearance.colors.colBackgroundSurfaceContainer, 0.3)
                            property color hoveredWorkspaceColor: ColorUtils.mix(defaultWorkspaceColor, 
                                Appearance.angelEverywhere ? Appearance.angel.colGlassPopupHover
                                : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover : Appearance.colors.colLayer1Hover, 0.1)
                            property color hoveredBorderColor: Appearance.angelEverywhere ? Appearance.angel.colBorderHover
                                : Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer2Hover
                            property bool hoveredWhileDragging: false

                            implicitWidth: root.workspaceImplicitWidth
                            implicitHeight: root.workspaceImplicitHeight
                            color: "transparent"
                            clip: !root.orbitMode

                            property bool workspaceAtLeft: colIndex === 0
                            property bool workspaceAtRight: colIndex === root.overviewColumns - 1
                            property bool workspaceAtTop: row.index === 0
                            property bool workspaceAtBottom: row.index === root.overviewRows - 1
                            property real orbitWorkspaceRadius: (root.orbitSurfaceStyle === "ricelin"
                                ? (Config.options?.appearance?.island?.radius ?? 18)
                                : Appearance.rounding.normal) * root.orbitSurfaceRadiusScale
                            property real largeWorkspaceRadius: root.orbitMode ? orbitWorkspaceRadius
                                : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                                : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.large
                            property real smallWorkspaceRadius: root.orbitMode ? orbitWorkspaceRadius
                                : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                                : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.verysmall
                            topLeftRadius: (workspaceAtLeft && workspaceAtTop) ? largeWorkspaceRadius : smallWorkspaceRadius
                            topRightRadius: (workspaceAtRight && workspaceAtTop) ? largeWorkspaceRadius : smallWorkspaceRadius
                            bottomLeftRadius: (workspaceAtLeft && workspaceAtBottom) ? largeWorkspaceRadius : smallWorkspaceRadius
                            bottomRightRadius: (workspaceAtRight && workspaceAtBottom) ? largeWorkspaceRadius : smallWorkspaceRadius
                            border.width: 0
                            border.color: "transparent"

                            StyledRectangularShadow {
                                target: orbitWorkspaceSurface
                                radius: workspace.orbitWorkspaceRadius
                                visible: root.orbitMode && (root.orbitSurfaceShadowMode === "all"
                                    || (root.orbitSurfaceShadowMode === "core" && workspace.isActive))
                                opacity: root.orbitSurfaceShadowOpacity
                            }

                            PanelSurface {
                                id: orbitWorkspaceSurface
                                anchors.fill: parent
                                visible: root.orbitMode
                                elevation: workspace.isActive
                                    ? root.orbitSurfaceCoreElevation : root.orbitSurfaceSatelliteElevation
                                cardStyle: true
                                outlined: false
                                clipContent: false
                                islandSkin: root.orbitSurfaceStyle === "ricelin"
                                surfaceDialect: root.orbitSurfaceStyle === "ricelin"
                                    ? "island" : Appearance.surfaceDialectFor("")
                                radiusOverride: workspace.orbitWorkspaceRadius
                                wallpaperBackdrop: false
                            }

                            // Wallpaper de fondo recortado al workspace, con blur + dim para mejorar legibilidad
                            Image {
                                id: workspaceWallpaperSource
                                anchors.fill: parent
                                anchors.margins: root.orbitMode ? root.orbitSurfaceFrameInset : 0
                                source: root.wallpaperPath
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                // Visible as unblurred fallback when effects are disabled
                                visible: !Appearance.effectsEnabled
                                layer.enabled: !Appearance.effectsEnabled
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width: workspaceWallpaperSource.width
                                        height: workspaceWallpaperSource.height
                                        topLeftRadius: root.orbitMode
                                            ? Math.max(0, workspace.topLeftRadius - root.orbitSurfaceFrameInset)
                                            : workspace.topLeftRadius
                                        topRightRadius: root.orbitMode
                                            ? Math.max(0, workspace.topRightRadius - root.orbitSurfaceFrameInset)
                                            : workspace.topRightRadius
                                        bottomLeftRadius: root.orbitMode
                                            ? Math.max(0, workspace.bottomLeftRadius - root.orbitSurfaceFrameInset)
                                            : workspace.bottomLeftRadius
                                        bottomRightRadius: root.orbitMode
                                            ? Math.max(0, workspace.bottomRightRadius - root.orbitSurfaceFrameInset)
                                            : workspace.bottomRightRadius
                                    }
                                }
                            }

                            FastBlur {
                                anchors.fill: parent
                                anchors.margins: root.orbitMode ? root.orbitSurfaceFrameInset : 0
                                source: workspaceWallpaperSource
                                visible: Appearance.effectsEnabled
                                radius: {
                                    if ((root.overviewOptions.backgroundBlurEnable ?? true) === false || !Appearance.effectsEnabled)
                                        return 0
                                    const r = root.overviewOptions.backgroundBlurRadius ?? 22
                                    return r * root.scale
                                }
                                transparentBorder: true
                                layer.enabled: Appearance.effectsEnabled
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width: Math.max(0, workspace.width
                                            - (root.orbitMode ? root.orbitSurfaceFrameInset * 2 : 0))
                                        height: Math.max(0, workspace.height
                                            - (root.orbitMode ? root.orbitSurfaceFrameInset * 2 : 0))
                                        topLeftRadius: root.orbitMode
                                            ? Math.max(0, workspace.topLeftRadius - root.orbitSurfaceFrameInset)
                                            : workspace.topLeftRadius
                                        topRightRadius: root.orbitMode
                                            ? Math.max(0, workspace.topRightRadius - root.orbitSurfaceFrameInset)
                                            : workspace.topRightRadius
                                        bottomLeftRadius: root.orbitMode
                                            ? Math.max(0, workspace.bottomLeftRadius - root.orbitSurfaceFrameInset)
                                            : workspace.bottomLeftRadius
                                        bottomRightRadius: root.orbitMode
                                            ? Math.max(0, workspace.bottomRightRadius - root.orbitSurfaceFrameInset)
                                            : workspace.bottomRightRadius
                                    }
                                }
                            }

                            // Dim overlay encima del wallpaper (misma forma que el workspace)
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: root.orbitMode ? root.orbitSurfaceFrameInset : 0
                                color: {
                                    const base = root.overviewOptions.backgroundDim ?? 35
                                    const delta = workspace.isActive ? -10 : 0 // activo un poco menos dim
                                    const v = base + delta
                                    const clamped = Math.max(0, Math.min(100, v))
                                    const a = clamped / 100
                                    return ColorUtils.transparentize(Appearance.colors.colLayer0Base, 1 - a)
                                }
                                topLeftRadius: root.orbitMode
                                    ? Math.max(0, workspace.topLeftRadius - root.orbitSurfaceFrameInset)
                                    : workspace.topLeftRadius
                                topRightRadius: root.orbitMode
                                    ? Math.max(0, workspace.topRightRadius - root.orbitSurfaceFrameInset)
                                    : workspace.topRightRadius
                                bottomLeftRadius: root.orbitMode
                                    ? Math.max(0, workspace.bottomLeftRadius - root.orbitSurfaceFrameInset)
                                    : workspace.bottomLeftRadius
                                bottomRightRadius: root.orbitMode
                                    ? Math.max(0, workspace.bottomRightRadius - root.orbitSurfaceFrameInset)
                                    : workspace.bottomRightRadius
                                border.width: 0
                            }

                            // Overlay de hover/drag (respeta esquinas redondeadas)
                            Rectangle {
                                anchors.fill: parent
                                color: (workspaceArea.containsMouse || hoveredWhileDragging)
                                       ? hoveredWorkspaceColor
                                       : "transparent"
                                opacity: (workspaceArea.containsMouse || hoveredWhileDragging) ? 0.25 : 0.0
                                topLeftRadius: workspace.topLeftRadius
                                topRightRadius: workspace.topRightRadius
                                bottomLeftRadius: workspace.bottomLeftRadius
                                bottomRightRadius: workspace.bottomRightRadius
                                Behavior on opacity {
                                    enabled: Appearance.animationsEnabled
                                    NumberAnimation {
                                        duration: Appearance.animation.elementMoveFast.duration
                                        easing.type: Appearance.animation.elementMoveFast.type
                                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                    }
                                }
                            }

                            // Border Overlay
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.width: hoveredWhileDragging ? Math.max(2, root.orbitSurfaceOutlineWidth)
                                    : root.orbitMode
                                        ? (root.orbitSurfaceOutline ? root.orbitSurfaceOutlineWidth : 0)
                                        : 1
                                // Usar este borde sólo para hover/drag.
                                // El estado activo se dibuja con focusedWorkspaceIndicator para evitar solapamientos.
                                border.color: hoveredWhileDragging
                                    ? hoveredBorderColor
                                    : root.orbitMode
                                        ? ColorUtils.applyAlpha(root.activeBorderColor,
                                            root.orbitSurfaceOutlineOpacity * 0.62)
                                    : (Appearance.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colBorder, 0.64)
                                        : Appearance.inirEverywhere ? ColorUtils.transparentize(Appearance.inir.colBorder, 0.45)
                                        : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.78)
                                        : ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.74))
                                topLeftRadius: workspace.topLeftRadius
                                topRightRadius: workspace.topRightRadius
                                bottomLeftRadius: workspace.bottomLeftRadius
                                bottomRightRadius: workspace.bottomRightRadius
                            }

                            StyledText {
                                anchors.centerIn: parent
                                text: workspace.workspaceValue
                                font {
                                    pixelSize: root.workspaceNumberSize * root.scale
                                    weight: Font.DemiBold
                                    family: Appearance.font.family.expressive
                                }
                                color: ColorUtils.transparentize(
                                    Appearance.angelEverywhere ? Appearance.angel.colText
                                    : Appearance.inirEverywhere ? Appearance.inir.colText
                                    : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer1
                                    : Appearance.colors.colOnLayer1,
                                    0.7
                                )
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                visible: root.showWorkspaceNumber
                            }

                            MouseArea {
                                id: workspaceArea
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onPressed: {
                                    if (root.draggingTargetWorkspace === -1 && workspace.workspaceObj) {
                                        GlobalStates.overviewOpen = false
                                        NiriService.switchToWorkspaceById(workspace.workspaceObj.id)
                                    }
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                keys: [orbitDragProxy.dragKey]
                                onEntered: {
                                    root.draggingTargetWorkspace = workspace.workspaceObj ? workspace.workspaceObj.id : -1
                                    if (root.draggingFromWorkspace === root.draggingTargetWorkspace)
                                        return
                                    hoveredWhileDragging = true
                                }
                                onExited: {
                                    hoveredWhileDragging = false
                                    if (workspace.workspaceObj && root.draggingTargetWorkspace === workspace.workspaceObj.id)
                                        root.draggingTargetWorkspace = -1
                                }
                                onDropped: drop => {
                                    hoveredWhileDragging = false
                                    const draggedWindow = orbitDragProxy.win
                                    if (!workspace.workspaceObj || !draggedWindow)
                                        return
                                    if (root.moveDraggedWindowToWorkspace(draggedWindow, workspace.workspaceObj.id))
                                        drop.accept()
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: windowSpace
            anchors.centerIn: parent
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight
            
            property var windowItems: []
            
            function rebuildWindowItems() {
                if (!GlobalStates.overviewOpen) {
                    windowItems = []
                    return
                }
                
                const wins = (NiriService.windows || []).filter(window => root.windowMatchesFilter(window))
                const wsList = root.workspacesForOutput || []
                if (wsList.length === 0 || wins.length === 0) {
                    windowItems = []
                    return
                }

                const workspaceSlotById = {}
                for (let i = 0; i < wsList.length; ++i) {
                    const ws = wsList[i]
                    if (ws)
                        workspaceSlotById[ws.id] = i
                }

                const startSlot = root.firstVisibleWorkspaceSlot
                const endSlot = Math.min(startSlot + root.workspacesShown - 1, wsList.length - 1)

                const collected = []
                const seenWindowIds = new Set()
                const counters = {}
                const countsPerWorkspace = {}
                const maxPerWorkspace = {}

                for (let i = 0; i < wins.length; ++i) {
                    const w = wins[i]
                    if (!w || seenWindowIds.has(w.id))
                        continue
                    seenWindowIds.add(w.id)
                    const slot = workspaceSlotById[w.workspace_id]
                    if (slot === undefined)
                        continue
                    if (slot < startSlot || slot > endSlot)
                        continue

                    const wsNumber = slot + 1

                    const pos = w.layout && w.layout.pos_in_scrolling_layout ? w.layout.pos_in_scrolling_layout : [1, 1]
                    const col = pos.length >= 1 && pos[0] ? pos[0] : 1
                    const row = pos.length >= 2 && pos[1] ? pos[1] : 1

                    const keyWs = wsNumber.toString()
                    countsPerWorkspace[keyWs] = (countsPerWorkspace[keyWs] || 0) + 1
                    const info = maxPerWorkspace[keyWs] || { maxCol: 1, maxRow: 1 }
                    info.maxCol = Math.max(info.maxCol, col)
                    info.maxRow = Math.max(info.maxRow, row)
                    maxPerWorkspace[keyWs] = info

                    collected.push({ window: w, workspaceNumber: wsNumber, workspaceSlot: slot })
                }

                const result = []
                for (let i = 0; i < collected.length; ++i) {
                    const entry = collected[i]
                    const wsKey = entry.workspaceNumber.toString()
                    const key = wsKey
                    const count = counters[key] || 0
                    counters[key] = count + 1

                    const gridInfo = maxPerWorkspace[wsKey] || { maxCol: 1, maxRow: 1 }

                    result.push({
                        "id": entry.window.id,
                        "window": entry.window,
                        "workspaceNumber": entry.workspaceNumber,
                        "workspaceSlot": entry.workspaceSlot,
                        "indexInWorkspace": count,
                        "windowCount": countsPerWorkspace[wsKey] || 1,
                        "maxCol": gridInfo.maxCol,
                        "maxRow": gridInfo.maxRow
                    })
                }

                windowItems = result
                if (GlobalStates.overviewOpen
                        && (root.orbitMode || Config.options?.overview?.showPreviews !== false)
                        && result.length > 0) {
                    WindowPreviewService.captureForTaskView(result.map(item => item.id),
                        root.orbitMode ? 12000 : undefined)
                }
            }
            
            Connections {
                target: NiriService
                enabled: GlobalStates.overviewOpen
                function onWindowsChanged() {
                    windowSpace.rebuildWindowItems()
                }
            }
            
            Connections {
                target: root
                function onWorkspacesForOutputChanged() {
                    windowSpace.rebuildWindowItems()
                }
                function onFirstVisibleWorkspaceSlotChanged() {
                    windowSpace.rebuildWindowItems()
                }
            }
            
            Connections {
                target: GlobalStates
                function onOverviewOpenChanged() {
                    if (GlobalStates.overviewOpen)
                        windowSpace.rebuildWindowItems()
                }
            }
            
            Component.onCompleted: rebuildWindowItems()

            Connections {
                target: root
                function onFilterTextChanged() { windowSpace.rebuildWindowItems() }
            }

            Repeater {
                id: windowRepeater
                model: ScriptModel {
                    values: windowSpace.windowItems
                }

                delegate: Item {
                    id: windowItem
                    required property var modelData

                    readonly property var windowData: modelData.window
                    readonly property int windowId: modelData.id
                    readonly property int workspaceNumber: modelData.workspaceNumber
                    readonly property int workspaceSlot: modelData.workspaceSlot
                    readonly property int indexInWorkspace: modelData.indexInWorkspace
                    readonly property int windowCount: modelData.windowCount || 1

                    readonly property int workspaceMaxCol: modelData.maxCol || 1
                    readonly property int workspaceMaxRow: modelData.maxRow || 1

                    readonly property int workspaceIndex: workspaceSlot - root.firstVisibleWorkspaceSlot
                    readonly property int workspaceColIndex: workspaceIndex % root.overviewColumns
                    readonly property int workspaceRowIndex: Math.floor(workspaceIndex / root.overviewColumns)

                    readonly property real xOffset: (root.workspaceImplicitWidth + workspaceSpacing) * workspaceColIndex
                    readonly property real yOffset: (root.workspaceImplicitHeight + workspaceSpacing) * workspaceRowIndex

                    readonly property var layoutPos: (windowData.layout && windowData.layout.pos_in_scrolling_layout) ? windowData.layout.pos_in_scrolling_layout : [1, 1]
                    readonly property int layoutCol: layoutPos.length >= 1 && layoutPos[0] ? layoutPos[0] : 1
                    readonly property int layoutRow: layoutPos.length >= 2 && layoutPos[1] ? layoutPos[1] : 1

                    readonly property int taskGridColumns: windowCount <= 1 ? 1
                        : windowCount <= 4 ? 2 : Math.ceil(Math.sqrt(windowCount))
                    readonly property int taskGridRows: Math.ceil(windowCount / taskGridColumns)
                    readonly property bool useBalancedGrid: root.orbitMode
                        && (root.orbitOptions.balancedGrid ?? true)
                    readonly property real tileWidth: root.workspaceImplicitWidth
                        / (useBalancedGrid ? taskGridColumns : workspaceMaxCol)
                    readonly property real tileHeight: root.workspaceImplicitHeight
                        / (useBalancedGrid ? taskGridRows : workspaceMaxRow)
                    readonly property real tileMargin: root.orbitMode
                        ? (root.orbitOptions.windowGap ?? 4)
                        : root.overviewWindowTileMargin * root.scale

                    readonly property real baseX: xOffset + (useBalancedGrid
                        ? (indexInWorkspace % taskGridColumns) * tileWidth
                        : (layoutCol - 1) * tileWidth)
                    readonly property real baseY: yOffset + (useBalancedGrid
                        ? Math.floor(indexInWorkspace / taskGridColumns) * tileHeight
                        : (layoutRow - 1) * tileHeight)

                    x: baseX + tileMargin
                    y: baseY + tileMargin
                    width: Math.max(10, tileWidth - 2 * tileMargin)
                    height: Math.max(10, tileHeight - 2 * tileMargin)
                    z: root.windowZ

                    Behavior on x {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: root.orbitMode ? root.orbitNavigationDuration
                                : Appearance.animation.elementMoveFast.duration
                            easing.type: root.orbitMode ? root.orbitNavigationEasingType
                                : Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: root.orbitMode ? []
                                : Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                    Behavior on y {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: root.orbitMode ? root.orbitNavigationDuration
                                : Appearance.animation.elementMoveFast.duration
                            easing.type: root.orbitMode ? root.orbitNavigationEasingType
                                : Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: root.orbitMode ? []
                                : Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    readonly property var toplevel: {
                        const tlMap = ToplevelManager.toplevels
                        if (!tlMap || !tlMap.values)
                            return null
                        const arr = Array.from(tlMap.values)
                        for (let i = 0; i < arr.length; ++i) {
                            const tl = arr[i]
                            if (!tl)
                                continue
                            const match = NiriService.findNiriWindow(tl)
                            if (match && match.niriWindow && match.niriWindow.id === windowData.id)
                                return tl
                        }
                        return null
                    }

                    property bool hovered: false
                    property bool pressed: false
                    readonly property bool isKeyboardSelected: root.orbitMode
                        && root.keyboardWindowId === windowData.id
                    readonly property bool isFocused: !!windowData && (windowData.is_focused
                                                                         || (NiriService.activeWindow
                                                                             && NiriService.activeWindow.id === windowData.id))

                    // Window item radius adapts to angel theme editor rounding values
                    readonly property real windowRadius: Appearance.angelEverywhere 
                        ? Appearance.angel.roundingSmall 
                        : Appearance.rounding.small

                    Rectangle {
                        anchors.fill: parent
                        radius: windowItem.windowRadius
                        color: root.orbitMode ? Appearance.colors.colLayer1Base : "transparent"
                        border.width: windowItem.isFocused || windowItem.isKeyboardSelected ? 2
                            : windowItem.hovered ? 1 : 0
                        border.color: windowItem.isKeyboardSelected
                            ? Appearance.colors.colPrimary
                            : windowItem.isFocused ? Appearance.colors.colLayer2Active
                            : windowItem.hovered
                                ? (root.orbitMode ? Appearance.colors.colLayer0Border : M3Palette.outlineVariant)
                                : "transparent"

                        // Window preview image
                        readonly property bool showPreviews: root.orbitMode || Config.options?.overview?.showPreviews !== false
                        Image {
                            id: windowPreview
                            anchors.fill: parent
                            anchors.margins: 2
                            property int revision: 0
                            property bool hadReadyFrame: false
                            source: {
                                const ignoredRevision = revision
                                if (!parent.showPreviews || !windowItem.windowId)
                                    return ""
                                return WindowPreviewService.getPreviewUrl(windowItem.windowId)
                            }
                            asynchronous: true
                            fillMode: root.orbitMode ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                            smooth: true
                            mipmap: false
                            retainWhileLoading: true
                            // Keep decode size independent from animated tile geometry. Changing
                            // sourceSize reloads the image and used to expose the fallback icon.
                            sourceSize.width: root.previewDecodeWidth
                            sourceSize.height: root.previewDecodeHeight
                            visible: parent.showPreviews && opacity > 0.001
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

                            // Listen for preview updates
                            Connections {
                                target: WindowPreviewService
                                function onPreviewUpdated(updatedId: int): void {
                                    if (updatedId === windowItem.windowId)
                                        windowPreview.revision++
                                }
                                function onCaptureComplete(): void {
                                    windowPreview.revision++
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: Math.max(0, windowItem.windowRadius - 2)
                            color: windowItem.pressed
                                ? ColorUtils.transparentize(root.orbitMode
                                    ? Appearance.colors.colPrimary : M3Palette.primary, 0.78)
                                : windowItem.hovered
                                    ? ColorUtils.transparentize(root.orbitMode
                                        ? Appearance.colors.colPrimary : M3Palette.primary, 0.9)
                                    : "transparent"

                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                        }

                        // Icono de la app (fallback cuando no hay preview)
                        Image {
                            id: windowIcon
                            anchors.centerIn: parent
                            width: {
                                var size = Math.min(parent.width, parent.height) * (windowPreview.visible ? 0.25 : 0.35);
                                const min = root.overviewOptions.iconMinSize ?? 0;
                                const max = root.overviewOptions.iconMaxSize ?? 0;
                                if (min > 0) size = Math.max(size, min);
                                if (max > 0) size = Math.min(size, max);
                                return size;
                            }
                            height: width
                            source: AppSearch.getIconSource(windowData.app_id || windowData.appId || "")
                            asynchronous: true
                            fillMode: Image.PreserveAspectFit
                            opacity: windowPreview.opacity > 0.001 ? (root.orbitMode ? 0 : 0.6) : 1.0
                            Behavior on opacity {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic }
                            }
                            scale: windowItem.hovered ? 1.08 : 1.0
                            Behavior on scale {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Appearance.animation.elementMoveFast.type
                                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                }
                            }
                        }

                        Item {
                            id: windowLabel
                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                bottom: parent.bottom
                                bottomMargin: 10
                            }
                            readonly property bool shown: root.orbitMode
                                && root.orbitWindowLabels !== "off"
                                && (root.orbitWindowLabels === "always"
                                    || windowItem.hovered || windowItem.isKeyboardSelected)
                            width: Math.min(parent.width - 20, Math.max(72, labelRow.implicitWidth + 18))
                            height: 28
                            opacity: shown ? 1 : 0
                            visible: opacity > 0.001

                            Behavior on opacity {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Appearance.animation.elementMoveFast.type
                                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                }
                            }

                            PanelSurface {
                                anchors.fill: parent
                                elevation: 1
                                cardStyle: true
                                outlined: true
                                surfaceDialect: Appearance.surfaceDialectFor("")
                                wallpaperBackdrop: false
                            }

                            RowLayout {
                                id: labelRow
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                Image {
                                    visible: root.orbitWindowLabelIcons
                                    Layout.preferredWidth: visible ? 16 : 0
                                    Layout.preferredHeight: visible ? 16 : 0
                                    source: visible
                                        ? AppSearch.getIconSource(windowData.app_id || windowData.appId || "") : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: windowData.title || windowData.app_id || Translation.tr("Window")
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Medium
                                    color: Appearance.colors.colOnLayer2
                                }
                            }
                        }

                        MouseArea {
                            id: windowMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            property real pressX: 0
                            property real pressY: 0
                            property int pressButton: Qt.NoButton
                            property bool dragging: false
                            onEntered: windowItem.hovered = true
                            onExited: windowItem.hovered = false
                            onPressed: (mouse) => {
                                if (!windowData)
                                    return
                                pressX = mouse.x
                                pressY = mouse.y
                                pressButton = mouse.button
                                dragging = false
                                if (mouse.button !== Qt.LeftButton)
                                    return
                                windowItem.pressed = true
                                orbitDragProxy.placeAt(windowMouseArea, mouse.x, mouse.y)
                            }
                            onPositionChanged: mouse => {
                                if (!pressed || pressButton !== Qt.LeftButton || !windowData)
                                    return
                                if (!dragging) {
                                    const dx = Math.abs(mouse.x - pressX)
                                    const dy = Math.abs(mouse.y - pressY)
                                    if (dx > 8 || dy > 8) {
                                        dragging = true
                                        const ws = NiriService.workspaces[windowData.workspace_id]
                                        root.draggingFromWorkspace = ws ? ws.id : -1
                                        orbitDragProxy.beginDrag(
                                            windowData,
                                            windowData.title || windowData.app_id || Translation.tr("Window"),
                                            windowData.app_id || "")
                                    }
                                }
                                if (dragging)
                                    orbitDragProxy.moveTo(windowMouseArea, mouse.x, mouse.y)
                            }
                            onReleased: (event) => {
                                const dx = Math.abs(event.x - pressX)
                                const dy = Math.abs(event.y - pressY)
                                const isClick = dx <= 4 && dy <= 4

                                if (!windowData) return

                                if (event.button === Qt.RightButton) {
                                    if (isClick) root.openWindowContext(windowItem, event.x, event.y)
                                    windowItem.pressed = false
                                    pressButton = Qt.NoButton
                                    root.draggingFromWorkspace = -1
                                    root.draggingTargetWorkspace = -1
                                    root.stashDropHovered = false
                                    return
                                }

                                const wasDragging = dragging
                                windowItem.pressed = false
                                dragging = false
                                pressButton = Qt.NoButton
                                if (wasDragging)
                                    orbitDragProxy.endDrag()
                                dragCleanupTimer.restart()

                                if (!wasDragging && isClick && event.button === Qt.LeftButton) {
                                    NiriService.focusWindow(windowData.id)
                                    if (!root.keepOverviewOpenOnWindowClick)
                                        GlobalStates.overviewOpen = false
                                } else if (!wasDragging && isClick && event.button === Qt.MiddleButton) {
                                    NiriService.closeWindow(windowData.id)
                                }
                            }
                            onCanceled: {
                                if (dragging)
                                    orbitDragProxy.cancelDrag()
                                windowItem.pressed = false
                                dragging = false
                                pressButton = Qt.NoButton
                                dragCleanupTimer.restart()
                            }
                        }
                    }
                }
            }

            WorkspaceStripDragProxy {
                id: orbitDragProxy
                compactWidth: 184
                compactHeight: 42
                previewEnabled: true
                previewWidth: 196
                previewHeight: 118
                previewSource: win ? WindowPreviewService.getPreviewUrl(win.id) : ""
                centerOnPointer: true
                z: root.windowDraggingZ
                surfaceColor: root.orbitMode ? Appearance.colors.colLayer3 : M3Palette.surfaceContainerHigh
                outlineColor: ColorUtils.transparentize(root.orbitMode
                    ? Appearance.colors.colPrimary : M3Palette.primary, 0.28)
                foregroundColor: root.orbitMode ? Appearance.colors.colOnLayer3 : M3Palette.surfaceForeground
                cornerRadius: height / 2
                surfaceOpacity: 0.98
            }

            ContextMenu {
                id: windowContextMenu
                model: root.contextMenuModel()
                anchorItem: root.contextAnchorItem ?? windowSpace
                anchorRect: root.contextAnchorRect
                popupAbove: false
                closeOnHoverLost: false
                closeOnOutsideClick: true
                scaleContent: false
                onActiveChanged: {
                    if (!active) {
                        root.contextWindowData = null
                        root.contextAnchorItem = null
                        root.contextAnchorRect = null
                    }
                }
            }

            RowLayout {
                id: dragDropTray
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                height: 44
                z: root.windowDraggingZ + 10
                spacing: 8
                visible: root.orbitMode && root.dragActive
                    && ((root.orbitOptions.showStash ?? true)
                        || (root.orbitOptions.showNewWorkspaceDrop ?? true))
                opacity: visible ? 1 : 0

                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
                Rectangle {
                    id: stashDropTarget
                    visible: root.orbitOptions.showStash ?? true
                    implicitWidth: root.stashDropHovered ? 202 : 176
                    implicitHeight: 44
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                    radius: height / 2
                    color: root.stashDropHovered
                        ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer3
                    border.width: 1
                    border.color: root.stashDropHovered
                        ? Appearance.colors.colPrimary
                        : ColorUtils.transparentize(Appearance.colors.colLayer0Border, 0.45)

                    Behavior on implicitWidth {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 7

                        MaterialSymbol {
                            text: "inventory_2"
                            iconSize: Appearance.font.pixelSize.normal
                            color: root.stashDropHovered
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colSubtext
                        }
                        StyledText {
                            text: root.stashDropHovered
                                ? Translation.tr("Release to Pocket") : Translation.tr("Pocket")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: root.stashDropHovered
                                ? Appearance.colors.colOnPrimaryContainer
                                : Appearance.colors.colOnLayer3
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        keys: [orbitDragProxy.dragKey]
                        onEntered: {
                            root.stashDropHovered = true
                            root.draggingTargetWorkspace = root.stashTargetWorkspace
                        }
                        onExited: {
                            root.stashDropHovered = false
                            if (root.draggingTargetWorkspace === root.stashTargetWorkspace)
                                root.draggingTargetWorkspace = -1
                        }
                        onDropped: drop => {
                            root.stashDropHovered = false
                            if (root.stashDraggedWindow(orbitDragProxy.win))
                                drop.accept()
                        }
                    }
                }

                Rectangle {
                    id: newWorkspaceDropTarget
                    visible: root.orbitOptions.showNewWorkspaceDrop ?? true
                    implicitWidth: root.newWorkspaceDropHovered ? 224 : 188
                    implicitHeight: 44
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                    radius: height / 2
                    color: root.newWorkspaceDropHovered
                        ? Appearance.colors.colSecondaryContainer : Appearance.colors.colLayer3
                    border.width: 1
                    border.color: root.newWorkspaceDropHovered
                        ? Appearance.colors.colPrimary
                        : ColorUtils.transparentize(Appearance.colors.colLayer0Border, 0.45)

                    Behavior on implicitWidth {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 7

                        MaterialSymbol {
                            text: "add_box"
                            iconSize: Appearance.font.pixelSize.normal
                            color: root.newWorkspaceDropHovered
                                ? Appearance.colors.colOnSecondaryContainer
                                : Appearance.colors.colSubtext
                        }
                        StyledText {
                            text: root.newWorkspaceDropHovered
                                ? Translation.tr("Release to new workspace")
                                : Translation.tr("New workspace")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: root.newWorkspaceDropHovered
                                ? Appearance.colors.colOnSecondaryContainer
                                : Appearance.colors.colOnLayer3
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        keys: [orbitDragProxy.dragKey]
                        onEntered: {
                            root.newWorkspaceDropHovered = true
                            const workspaces = root.workspacesForOutput ?? []
                            root.draggingTargetWorkspace = workspaces.length > 0
                                ? workspaces[workspaces.length - 1].id : -1
                        }
                        onExited: {
                            root.newWorkspaceDropHovered = false
                            const workspaces = root.workspacesForOutput ?? []
                            const trailingId = workspaces.length > 0
                                ? workspaces[workspaces.length - 1].id : -1
                            if (root.draggingTargetWorkspace === trailingId)
                                root.draggingTargetWorkspace = -1
                        }
                        onDropped: drop => {
                            root.newWorkspaceDropHovered = false
                            if (root.moveDraggedWindowToNewWorkspace(orbitDragProxy.win))
                                drop.accept()
                        }
                    }
                }
            }

            Rectangle {
                id: focusedWorkspaceIndicator
                readonly property int activeSlot: root.currentWorkspaceSlot
                readonly property int activeSlotInGroup: activeSlot - root.firstVisibleWorkspaceSlot
                readonly property int rowIndex: Math.floor(activeSlotInGroup / root.overviewColumns)
                readonly property int colIndex: activeSlotInGroup % root.overviewColumns

                x: (root.workspaceImplicitWidth + workspaceSpacing) * colIndex
                y: (root.workspaceImplicitHeight + workspaceSpacing) * rowIndex
                z: root.windowZ
                width: root.workspaceImplicitWidth
                height: root.workspaceImplicitHeight
                color: "transparent"

                property bool workspaceAtLeft: colIndex === 0
                property bool workspaceAtRight: colIndex === root.overviewColumns - 1
                property bool workspaceAtTop: rowIndex === 0
                property bool workspaceAtBottom: rowIndex === root.overviewRows - 1
                property real orbitWorkspaceRadius: (root.orbitSurfaceStyle === "ricelin"
                    ? (Config.options?.appearance?.island?.radius ?? 18)
                    : Appearance.rounding.normal) * root.orbitSurfaceRadiusScale
                property real largeWorkspaceRadius: root.orbitMode ? orbitWorkspaceRadius
                    : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                    : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.large
                property real smallWorkspaceRadius: root.orbitMode ? orbitWorkspaceRadius
                    : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                    : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.verysmall
                topLeftRadius: (workspaceAtLeft && workspaceAtTop) ? largeWorkspaceRadius : smallWorkspaceRadius
                topRightRadius: (workspaceAtRight && workspaceAtTop) ? largeWorkspaceRadius : smallWorkspaceRadius
                bottomLeftRadius: (workspaceAtLeft && workspaceAtBottom) ? largeWorkspaceRadius : smallWorkspaceRadius
                bottomRightRadius: (workspaceAtRight && workspaceAtBottom) ? largeWorkspaceRadius : smallWorkspaceRadius

                border.width: root.orbitMode
                    ? (root.orbitSurfaceOutline ? root.orbitSurfaceOutlineWidth : 0) : 2
                border.color: root.orbitMode
                    ? ColorUtils.applyAlpha(root.activeBorderColor, root.orbitSurfaceOutlineOpacity)
                    : root.activeBorderColor

                Behavior on x {
                    enabled: root.focusAnimEnabled && Appearance.animationsEnabled
                    animation: NumberAnimation {
                        duration: root.orbitMode ? root.orbitNavigationDuration : root.focusAnimDuration
                        easing.type: root.orbitMode ? root.orbitNavigationEasingType
                            : Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: root.orbitMode ? []
                            : Appearance.animationCurves.emphasizedLastHalf
                    }
                }
                Behavior on y {
                    enabled: root.focusAnimEnabled && Appearance.animationsEnabled
                    animation: NumberAnimation {
                        duration: root.orbitMode ? root.orbitNavigationDuration : root.focusAnimDuration
                        easing.type: root.orbitMode ? root.orbitNavigationEasingType
                            : Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: root.orbitMode ? []
                            : Appearance.animationCurves.emphasizedLastHalf
                    }
                }
                Behavior on topLeftRadius {
                    enabled: root.focusAnimEnabled && Appearance.animationsEnabled
                    animation: NumberAnimation {
                        duration: root.focusAnimDuration
                        easing.type: Appearance.animation.elementMoveEnter.type
                        easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                    }
                }
                Behavior on topRightRadius {
                    enabled: root.focusAnimEnabled && Appearance.animationsEnabled
                    animation: NumberAnimation {
                        duration: root.focusAnimDuration
                        easing.type: Appearance.animation.elementMoveEnter.type
                        easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                    }
                }
                Behavior on bottomLeftRadius {
                    enabled: root.focusAnimEnabled && Appearance.animationsEnabled
                    animation: NumberAnimation {
                        duration: root.focusAnimDuration
                        easing.type: Appearance.animation.elementMoveEnter.type
                        easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                    }
                }
                Behavior on bottomRightRadius {
                    enabled: root.focusAnimEnabled && Appearance.animationsEnabled
                    animation: NumberAnimation {
                        duration: root.focusAnimDuration
                        easing.type: Appearance.animation.elementMoveEnter.type
                        easing.bezierCurve: Appearance.animationCurves.emphasizedLastHalf
                    }
                }
            }
        }
    }
}
