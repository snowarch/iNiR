import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

Item {
    id: root
    property bool vertical: false
    property bool borderless: Config.options?.bar?.borderless ?? false
    readonly property HyprlandMonitor monitor: CompositorService.isHyprland ? Hyprland.monitorFor(root.QsWindow.window?.screen) : null
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

    property bool showAppIcons: true
    property bool alwaysShowNumbers: false
    property bool useNerdFont: false
    property bool monochromeIcons: true
    property string indicatorStyle: "dot"
    property var numberMap: []
    property bool forceMaterialStyle: false
    property bool syncGlobalWorkspaceConfig: true
    readonly property bool useZzzStyle: Appearance.zzzEverywhere && !root.forceMaterialStyle
    readonly property bool useAngelStyle: Appearance.angelEverywhere && !root.forceMaterialStyle
    readonly property bool useAuroraStyle: Appearance.auroraEverywhere && !root.forceMaterialStyle
    readonly property color workspacePrimary: root.forceMaterialStyle ? Appearance.m3colors.m3primary : Appearance.colors.colPrimary
    readonly property color workspaceOnPrimary: root.forceMaterialStyle ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnPrimary
    readonly property color workspaceSecondaryContainer: root.forceMaterialStyle ? Appearance.m3colors.m3secondaryContainer : Appearance.colors.colSecondaryContainer
    readonly property color workspaceOnSecondaryContainer: root.forceMaterialStyle ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnSecondaryContainer
    readonly property color workspaceInactive: root.forceMaterialStyle ? Appearance.m3colors.m3onSurfaceVariant : Appearance.colors.colOnLayer1Inactive
    property bool configuredPerMonitor: true
    property string scrollBehavior: "workspace"
    property bool configuredDynamicCount: true
    property int configuredWorkspaceCount: 10
    property bool wrapAround: true
    property int scrollSteps: 3
    property bool invertScroll: false

    function _intOr(value, fallback: int): int {
        const parsed = Number(value)
        return isFinite(parsed) ? Math.round(parsed) : fallback
    }

    function _stringOr(value, fallback: string): string {
        return typeof value === "string" ? value : fallback
    }

    function _workspaceLabel(workspace, workspaceValue): string {
        if (CompositorService.isNiri && workspace) {
            const name = root._stringOr(workspace.name, "")
            if (name.length > 0)
                return name
            const mapped = root.numberMap?.[root._intOr(workspace.idx, 1) - 1]
            if (mapped !== undefined && mapped !== null)
                return String(mapped)
            const idx = root._intOr(workspace.idx, 0)
            return idx > 0 ? String(idx) : ""
        }
        const mapped = root.numberMap?.[root._intOr(workspaceValue, 1) - 1]
        if (mapped !== undefined && mapped !== null)
            return String(mapped)
        const value = root._intOr(workspaceValue, 0)
        return value > 0 ? String(value) : ""
    }

    function syncWorkspaceConfig(): void {
        if (!root.syncGlobalWorkspaceConfig) {
            root.updateWorkspaceOccupied()
            return
        }
        const config = Config.options?.bar?.workspaces
        root.showAppIcons = typeof config?.showAppIcons === "boolean" ? config.showAppIcons : true
        root.alwaysShowNumbers = typeof config?.alwaysShowNumbers === "boolean" ? config.alwaysShowNumbers : false
        root.useNerdFont = typeof config?.useNerdFont === "boolean" ? config.useNerdFont : false
        root.monochromeIcons = typeof config?.monochromeIcons === "boolean" ? config.monochromeIcons : true
        root.numberMap = config?.numberMap ?? []
        root.configuredPerMonitor = typeof config?.perMonitor === "boolean" ? config.perMonitor : true
        root.scrollBehavior = typeof config?.scrollBehavior === "string" ? config.scrollBehavior : "workspace"
        root.configuredDynamicCount = typeof config?.dynamicCount === "boolean" ? config.dynamicCount : true
        root.configuredWorkspaceCount = root._intOr(config?.shown, 10)
        root.wrapAround = typeof config?.wrapAround === "boolean" ? config.wrapAround : true
        root.scrollSteps = Math.max(1, root._intOr(config?.scrollSteps, 3))
        root.invertScroll = typeof config?.invertScroll === "boolean" ? config.invertScroll : false
        root.updateWorkspaceOccupied()
    }

    Timer {
        id: syncWorkspaceConfigTimer
        interval: 0
        onTriggered: root.syncWorkspaceConfig()
    }

    Connections {
        target: Config
        function onReadyChanged(): void {
            if (Config.ready)
                syncWorkspaceConfigTimer.restart()
        }
        function onConfigChanged(): void {
            syncWorkspaceConfigTimer.restart()
        }
    }

    // Per-monitor: each bar shows workspaces for its own output (Niri)
    readonly property bool perMonitor: root.configuredPerMonitor && CompositorService.isNiri === true
    readonly property string screenName: root.QsWindow.window?.screen?.name ?? ""
    readonly property var outputWorkspaces: {
        if (!CompositorService.isNiri) return []
        if (perMonitor && screenName.length > 0) {
            return (NiriService.allWorkspaces ?? []).filter(w => w.output === screenName)
        }
        return NiriService.currentOutputWorkspaces ?? []
    }
    function workspaceForSlot(slotNumber) {
        if (!CompositorService.isNiri)
            return null
        if (!root.perMonitor)
            return (NiriService.allWorkspaces ?? []).find(w => w.idx === slotNumber) ?? null
        const slotIndex = slotNumber - 1
        if (slotIndex < 0 || slotIndex >= root.outputWorkspaces.length)
            return null
        return root.outputWorkspaces[slotIndex] ?? null
    }
    function workspaceIndexForSlot(slotNumber) {
        const ws = workspaceForSlot(slotNumber)
        return ws?.idx ?? slotNumber
    }
    // This bar renders its own output's workspaces, but a niri Index reference
    // resolves against the *focused* output and idx repeats across outputs — so
    // clicking slot 1 here switched the other monitor whenever focus was
    // elsewhere. Ids are globally unique; fall back to idx only when unavailable.
    function switchToSlot(slotNumber) {
        const ws = root.workspaceForSlot(slotNumber)
        if (ws?.id !== undefined)
            NiriService.switchToWorkspaceById(ws.id)
        else
            NiriService.switchToWorkspace(root.workspaceIndexForSlot(slotNumber))
    }

    // Scroll behavior: "workspace" = switch workspaces, "column" = cycle windows left/right in same workspace
    readonly property bool columnMode: root.scrollBehavior === "column" && CompositorService.isNiri

    readonly property int currentWorkspaceNumber: {
        if (CompositorService.isNiri) {
            if (root.perMonitor) {
                const activeSlot = root.outputWorkspaces.findIndex(w => w.is_active)
                return activeSlot >= 0 ? activeSlot + 1 : 1
            }
            return NiriService.getCurrentWorkspaceNumber()
        }
        return monitor?.activeWorkspace?.id || 1
    }
    
    // Dynamic workspace count: use actual workspaces from Niri, or fixed count
    readonly property bool dynamicCount: root.configuredDynamicCount && CompositorService.isNiri === true
    readonly property int actualWorkspaceCount: {
        if (!dynamicCount)
            return root.configuredWorkspaceCount
        // Niri: count workspaces on this output
        return Math.max(root.outputWorkspaces.length, 1)
    }
    readonly property int workspacesShown: actualWorkspaceCount
    // Coalesced so the Repeater never outruns the Grid during a config reload.
    property int renderedWorkspaceCount: Math.max(actualWorkspaceCount, 1)

    readonly property int workspaceGroup: Math.floor((currentWorkspaceNumber - 1) / root.workspacesShown)
    property list<bool> workspaceOccupied: []
    property int widgetPadding: 4
    property int workspaceButtonWidth: 26
    property real activeWorkspaceMargin: 2
    property real workspaceIconSize: workspaceButtonWidth * 0.69
    property real workspaceIconSizeShrinked: workspaceButtonWidth * 0.55
    property real workspaceIconOpacityShrinked: 1
    property real workspaceIconMarginShrinked: -4
    property int workspaceIndexInGroup: (currentWorkspaceNumber - 1) % root.workspacesShown

    Timer {
        id: workspaceLayoutTimer
        interval: 0
        repeat: false
        onTriggered: root.renderedWorkspaceCount = Math.max(root.workspacesShown, 1)
    }

    onWorkspacesShownChanged: workspaceLayoutTimer.restart()

    // Column mode: windows in current workspace
    readonly property var currentWorkspaceWindows: {
        if (!columnMode) return []
        const currentWs = root.outputWorkspaces.find(w => w.is_active)
        if (!currentWs) return []
        return NiriService.windows?.filter(w => w.workspace_id === currentWs.id) ?? []
    }
    readonly property int currentWindowIndex: {
        if (!columnMode) return -1
        return currentWorkspaceWindows.findIndex(w => w.is_focused)
    }
    readonly property int columnsShown: columnMode ? Math.max(currentWorkspaceWindows.length, 1) : workspacesShown

    property bool showNumbers: false
    Timer {
        id: showNumbersTimer
        interval: (Config?.options.bar.autoHide.showWhenPressingSuper.delay ?? 100)
        repeat: false
        onTriggered: {
            root.showNumbers = true
        }
    }
    Connections {
        target: GlobalStates
        function onSuperDownChanged() {
            if (!Config?.options.bar.autoHide.showWhenPressingSuper.enable) return;
            if (GlobalStates.superDown) showNumbersTimer.restart();
            else {
                showNumbersTimer.stop();
                root.showNumbers = false;
            }
        }
        function onSuperReleaseMightTriggerChanged() { 
            showNumbersTimer.stop()
        }
    }

    Timer {
        id: updateWorkspaceOccupiedTimer
        interval: 50
        repeat: false
        onTriggered: doUpdateWorkspaceOccupied()
    }

    function updateWorkspaceOccupied() {
        updateWorkspaceOccupiedTimer.restart()
    }

    function doUpdateWorkspaceOccupied() {
        if (CompositorService.isNiri) {
            const wsList = root.outputWorkspaces || []
            const windows = NiriService.windows || []
            const base = workspaceGroup * root.workspacesShown

            // Build set of workspace IDs that currently contain windows (O(n))
            const occupiedWorkspaceIds = new Set()
            for (let i = 0; i < windows.length; i++) {
                const wsId = windows[i]?.workspace_id
                if (wsId !== undefined && wsId !== null) occupiedWorkspaceIds.add(wsId)
            }

            workspaceOccupied = Array.from({ length: root.workspacesShown }, (_, i) => {
                const targetNumber = base + i + 1
                const ws = root.workspaceForSlot(targetNumber)
                if (!ws) return false
                return occupiedWorkspaceIds.has(ws.id)
            })
        } else {
            workspaceOccupied = Array.from({ length: root.workspacesShown }, (_, i) => {
                return Hyprland.workspaces.values.some(ws => ws.id === workspaceGroup * root.workspacesShown + i + 1);
            })
        }
    }

    // Occupied workspace updates
    Component.onCompleted: {
        root.syncWorkspaceConfig()
        root.doUpdateWorkspaceOccupied()
        root.renderedWorkspaceCount = Math.max(root.workspacesShown, 1)
    }
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() {
            if (CompositorService.isHyprland)
                updateWorkspaceOccupied();
        }
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            if (CompositorService.isHyprland)
                updateWorkspaceOccupied();
        }
    }
    Connections {
        target: NiriService
        enabled: CompositorService.isNiri
        function onAllWorkspacesChanged() {
            updateWorkspaceOccupied();
        }
        function onCurrentOutputWorkspacesChanged() {
            updateWorkspaceOccupied();
        }
        function onWindowsChanged() {
            updateWorkspaceOccupied();
        }
    }
    onWorkspaceGroupChanged: {
        updateWorkspaceOccupied();
    }

    implicitWidth: root.vertical ? Appearance.sizes.verticalBarWidth : (root.workspaceButtonWidth * root.columnsShown)
    implicitHeight: root.vertical ? (root.workspaceButtonWidth * root.columnsShown) : Appearance.sizes.barHeight

    // Scroll handler overlay - captures wheel events above all content
    MouseArea {
        z: 10
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        
        property int wheelStepCounter: 0
        readonly property int wheelStepsRequired: root.scrollSteps
        
        onPressed: (event) => {
            if (event.button === Qt.BackButton && CompositorService.isHyprland) {
                Hyprland.dispatch(`togglespecialworkspace`);
            }
        }
        
        onWheel: (event) => {
            wheelStepCounter += 1
            if (wheelStepCounter < wheelStepsRequired) return
            wheelStepCounter = 0
            const deltaX = event.angleDelta.x
            const deltaY = event.angleDelta.y
            let delta = deltaX !== 0 ? deltaX : -deltaY
            if (delta === 0) return
            
            if (root.invertScroll) delta = -delta
            const direction = delta > 0 ? 1 : -1

            if (CompositorService.isNiri) {
                if (root.columnMode) {
                    // Column mode with wrap-around
                    const windowCount = root.currentWorkspaceWindows.length
                    if (windowCount <= 1) return
                    
                    if (root.wrapAround) {
                        const currentIdx = root.currentWindowIndex
                        if (direction > 0 && currentIdx >= windowCount - 1) {
                            // At last, go to first
                            NiriService.focusColumnFirst()
                        } else if (direction < 0 && currentIdx <= 0) {
                            // At first, go to last
                            NiriService.focusColumnLast()
                        } else {
                            if (direction > 0) NiriService.focusColumnRight()
                            else NiriService.focusColumnLeft()
                        }
                    } else {
                        if (direction > 0) NiriService.focusColumnRight()
                        else NiriService.focusColumnLeft()
                    }
                } else {
                    // Workspace mode with wrap-around
                    const wsCount = root.workspacesShown
                    const currentWs = root.currentWorkspaceNumber
                    
                    // focusWorkspaceUp/Down act on the focused output, so scrolling
                    // this bar moved the *other* monitor's workspaces whenever focus
                    // was elsewhere. Step within our own slots and dispatch by id.
                    const step = direction > 0 ? 1 : -1

                    if (root.wrapAround) {
                        if (direction > 0 && currentWs >= wsCount) {
                            // At last, go to first
                            root.switchToSlot(1)
                        } else if (direction < 0 && currentWs <= 1) {
                            // At first, go to last
                            root.switchToSlot(wsCount)
                        } else {
                            root.switchToSlot(currentWs + step)
                        }
                    } else {
                        const target = currentWs + step
                        if (target >= 1 && target <= wsCount)
                            root.switchToSlot(target)
                    }
                }
            } else if (CompositorService.isHyprland) {
                Hyprland.dispatch(direction > 0 ? `workspace r+1` : `workspace r-1`)
            }
        }
    }

    // Workspaces/Columns - background
    Grid {
        z: 1
        anchors.centerIn: parent
        visible: !root.columnMode

        rowSpacing: 0
        columnSpacing: 0
        columns: root.vertical ? 1 : root.renderedWorkspaceCount
        rows: root.vertical ? root.renderedWorkspaceCount : 1

        Repeater {
            model: root.renderedWorkspaceCount

            Rectangle {
                z: 1
                implicitWidth: workspaceButtonWidth
                implicitHeight: workspaceButtonWidth
                // No plain radius here: all four corners are per-corner bound, and
                // a Behavior on radius alongside them is the known "another
                // interceptor on property radius" warning (Qt supports one).
                Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                property bool previousOccupied: (workspaceOccupied[index-1] ?? false) && !(!activeWindow?.activated && currentWorkspaceNumber === index)
                property bool rightOccupied: (workspaceOccupied[index+1] ?? false) && !(!activeWindow?.activated && currentWorkspaceNumber === index+2)
                property real radiusPrev: root.useZzzStyle ? Appearance.zzz.cornerRadius
                    : root.useAngelStyle ? Appearance.angel.roundingSmall : (previousOccupied ? 0 : (width / 2))
                property real radiusNext: root.useZzzStyle ? Appearance.zzz.cornerRadius
                    : root.useAngelStyle ? Appearance.angel.roundingSmall : (rightOccupied ? 0 : (width / 2))

                topLeftRadius: radiusPrev
                bottomLeftRadius: root.vertical ? radiusNext : radiusPrev
                topRightRadius: root.vertical ? radiusPrev : radiusNext
                bottomRightRadius: radiusNext
                
                // ZZZ: drop this occupied-cell fill entirely — the active plate
                // (ZzzPlate, generated accent) is the only workspace background,
                // so the active cell no longer stacks two fills.
                color: root.useZzzStyle
                    ? "transparent"
                    : root.useAngelStyle
                    ? Appearance.angel.colGlassCard
                    : root.useAuroraStyle
                    ? Appearance.aurora.colSubSurface
                    : ColorUtils.transparentize(root.workspaceSecondaryContainer, 0.4)
                opacity: (workspaceOccupied[index] && !(!activeWindow?.activated && currentWorkspaceNumber === index+1)) ? 1 : 0

                Behavior on opacity {
                    animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                }
                Behavior on radiusPrev {
                    animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                }

                Behavior on radiusNext {
                    animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                }

            }

        }

    }

    // Active workspace indicator (workspace mode only)
    Rectangle {
        z: 2
        visible: !root.columnMode
        // Make active ws indicator, which has a brighter color, smaller to look like it is of the same size as ws occupied highlight
        radius: root.useZzzStyle ? Appearance.zzz.cornerRadius
            : root.useAngelStyle ? Appearance.angel.roundingSmall : Math.min(width, height) / 2
        // ZZZ shows a chamfered signal plate (geometry) instead of the rounded fill.
        color: root.useZzzStyle ? "transparent"
            : root.useAngelStyle ? Appearance.angel.colPrimary : root.workspacePrimary
        Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animationCurves.zzzOvershoot } }
        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

        ZzzPlate {
            anchors.fill: parent
            visible: root.useZzzStyle
            chamfer: Appearance.zzz.cutCorner * 0.4
            fillColor: Appearance.zzz.accentSoft
        }

        anchors {
            verticalCenter: vertical ? undefined : parent.verticalCenter
            horizontalCenter: vertical ? parent.horizontalCenter : undefined
        }

        AnimatedTabIndexPair {
            id: idxPair
            index: root.workspaceIndexInGroup
        }
        property real indicatorPosition: Math.min(idxPair.idx1, idxPair.idx2) * workspaceButtonWidth + root.activeWorkspaceMargin
        property real indicatorLength: Math.abs(idxPair.idx1 - idxPair.idx2) * workspaceButtonWidth + workspaceButtonWidth - root.activeWorkspaceMargin * 2
        property real indicatorThickness: workspaceButtonWidth - root.activeWorkspaceMargin * 2

        x: root.vertical ? null : indicatorPosition
        implicitWidth: root.vertical ? indicatorThickness : indicatorLength
        y: root.vertical ? indicatorPosition : null
        implicitHeight: root.vertical ? indicatorLength : indicatorThickness

    }

    // Workspaces - numbers (workspace mode)
    Grid {
        z: 3
        visible: !root.columnMode

        columns: root.vertical ? 1 : root.renderedWorkspaceCount
        rows: root.vertical ? root.renderedWorkspaceCount : 1
        columnSpacing: 0
        rowSpacing: 0

        anchors.fill: parent

        Repeater {
            model: root.renderedWorkspaceCount

            Button {
                id: button
                property int workspaceValue: workspaceGroup * root.workspacesShown + index + 1
                implicitHeight: vertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.barHeight
                implicitWidth: vertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.verticalBarWidth
                onPressed: {
                    if (CompositorService.isNiri) {
                        root.switchToSlot(workspaceValue)
                    } else if (CompositorService.isHyprland) {
                        Hyprland.dispatch(`workspace ${workspaceValue}`)
                    }
                }
                width: vertical ? undefined : workspaceButtonWidth
                height: vertical ? workspaceButtonWidth : undefined

                background: Item {
                    id: workspaceButtonBackground
                    implicitWidth: workspaceButtonWidth
                    implicitHeight: workspaceButtonWidth
                    readonly property var niriWorkspace: CompositorService.isNiri 
                        ? root.workspaceForSlot(button.workspaceValue)
                        : null
                    property var biggestWindow: {
                        if (CompositorService.isNiri) {
                            if (!niriWorkspace) return null
                            const wins = NiriService.windows?.filter(w => w.workspace_id === niriWorkspace.id) ?? []
                            if (wins.length === 0) return null
                            return wins.find(w => w.is_focused) || wins[0]
                        } else {
                            return HyprlandData.biggestWindowForWorkspace(button.workspaceValue)
                        }
                    }
                    property var mainAppIconSource: {
                        const appClass = CompositorService.isNiri 
                            ? (biggestWindow?.app_id || biggestWindow?.appId) 
                            : biggestWindow?.class
                        return AppSearch.getIconSource(appClass)
                    }

                    StyledText { // Workspace number text
                        opacity: root.showNumbers
                            || ((root.alwaysShowNumbers && (!root.showAppIcons || !workspaceButtonBackground.biggestWindow || root.showNumbers))
                            || (root.showNumbers && !root.showAppIcons)
                            )  ? 1 : 0
                        z: 3

                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font {
                            pixelSize: Appearance.font.pixelSize.small - ((text.length - 1) * (text !== "10") * 2)
                            family: root.useNerdFont ? (Appearance.font.family.iconNerd ?? "") : (defaultFont ?? "")
                        }
                        text: {
                            const label = root._workspaceLabel(
                                workspaceButtonBackground.niriWorkspace,
                                button.workspaceValue)
                            return typeof label === "string" ? label : ""
                        }
                        elide: Text.ElideRight
                        color: (currentWorkspaceNumber == button.workspaceValue) ?
                            root.workspaceOnPrimary :
                            // ZZZ: occupied cells have no plate (transparent), so the dark
                            // onSecondary ink read black-on-black — use light zzz inks instead.
                            root.useZzzStyle
                                ? (workspaceOccupied[index] ? Appearance.zzz.onColor : Appearance.zzz.onMuted)
                                : (workspaceOccupied[index] ? root.workspaceOnSecondaryContainer :
                                    root.workspaceInactive)

                        Behavior on opacity {
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }
                    Loader { // Compact workspace marker when no app icon/number is shown
                        id: wsMarker
                        opacity: (root.alwaysShowNumbers
                            || root.showNumbers
                            || (root.showAppIcons && workspaceButtonBackground.biggestWindow)
                            ) ? 0 : 1
                        visible: opacity > 0
                        anchors.centerIn: parent
                        readonly property color markerColor: (currentWorkspaceNumber == button.workspaceValue)
                            ? root.workspaceOnPrimary
                            : root.useZzzStyle
                                ? (workspaceOccupied[index] ? Appearance.zzz.onColor : Appearance.zzz.onMuted)
                                : (workspaceOccupied[index] ? root.workspaceOnSecondaryContainer
                                    : root.workspaceInactive)
                        sourceComponent: root.indicatorStyle === "icon" ? workspaceIconMarker : workspaceDotMarker

                        Component {
                            id: workspaceDotMarker
                            Rectangle {
                                width: workspaceButtonWidth * 0.18
                                height: width
                                radius: width / 2
                                color: wsMarker.markerColor
                            }
                        }

                        Component {
                            id: workspaceIconMarker
                            MaterialSymbol {
                                iconSize: workspaceButtonWidth * 0.5
                                color: wsMarker.markerColor
                                text: {
                                    switch (button.workspaceValue) {
                                    case 1: return "code"
                                    case 2: return "public"
                                    case 3: return "music_note"
                                    case 4: return "edit_square"
                                    case 5: return "image"
                                    case 6: return "forum"
                                    case 7: return "browser_updated"
                                    case 8: return "finance_mode"
                                    case 9: return "monitor"
                                    case 10: return "analytics"
                                    default: return "circle"
                                    }
                                }
                            }
                        }

                        Behavior on opacity {
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }
                    Item { // Main app icon
                        anchors.centerIn: parent
                        width: workspaceButtonWidth
                        height: workspaceButtonWidth
                        opacity: !root.showAppIcons ? 0 :
                            (workspaceButtonBackground.biggestWindow && !root.showNumbers && root.showAppIcons) ?
                            1 : workspaceButtonBackground.biggestWindow ? workspaceIconOpacityShrinked : 0
                            visible: opacity > 0
                        IconImage {
                            id: mainAppIcon
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.bottomMargin: (!root.showNumbers && root.showAppIcons) ?
                                (workspaceButtonWidth - workspaceIconSize) / 2 : workspaceIconMarginShrinked
                            anchors.rightMargin: (!root.showNumbers && root.showAppIcons) ?
                                (workspaceButtonWidth - workspaceIconSize) / 2 : workspaceIconMarginShrinked

                            source: workspaceButtonBackground.mainAppIconSource
                            implicitSize: (!root.showNumbers && root.showAppIcons) ? workspaceIconSize : workspaceIconSizeShrinked

                            Behavior on opacity {
                                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                            }
                            Behavior on anchors.bottomMargin {
                                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                            }
                            Behavior on anchors.rightMargin {
                                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                            }
                            Behavior on implicitSize {
                                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                            }
                        }

                        Loader {
                            active: root.monochromeIcons
                            anchors.fill: mainAppIcon
                            sourceComponent: Item {
                                Desaturate {
                                    id: desaturatedIcon
                                    visible: false // There's already color overlay
                                    anchors.fill: parent
                                    source: mainAppIcon
                                    desaturation: 0.8
                                }
                                ColorOverlay {
                                    anchors.fill: desaturatedIcon
                                    source: desaturatedIcon
                                    color: ColorUtils.transparentize(wsMarker.markerColor, 0.9)
                                }
                            }
                        }
                    }
                }
                

            }

        }

    }

    // Column mode - background (same style as workspace mode)
    Grid {
        z: 1
        anchors.centerIn: parent
        visible: root.columnMode && root.currentWorkspaceWindows.length > 0

        rowSpacing: 0
        columnSpacing: 0
        columns: root.vertical ? 1 : root.currentWorkspaceWindows.length
        rows: root.vertical ? root.currentWorkspaceWindows.length : 1

        Repeater {
            model: root.currentWorkspaceWindows.length

            Rectangle {
                z: 1
                implicitWidth: workspaceButtonWidth
                implicitHeight: workspaceButtonWidth
                // Per-corner radii below own every corner; see note on the
                // occupied-cell Rectangle above about the interceptor warning.
                property bool previousExists: index > 0
                property bool nextExists: index < root.currentWorkspaceWindows.length - 1
                property real radiusPrev: root.useZzzStyle ? Appearance.zzz.cornerRadius : (previousExists ? 0 : (width / 2))
                property real radiusNext: root.useZzzStyle ? Appearance.zzz.cornerRadius : (nextExists ? 0 : (width / 2))

                topLeftRadius: radiusPrev
                bottomLeftRadius: root.vertical ? radiusNext : radiusPrev
                topRightRadius: root.vertical ? radiusPrev : radiusNext
                bottomRightRadius: radiusNext
                
                color: root.useAuroraStyle
                    ? Appearance.aurora.colSubSurface
                    : ColorUtils.transparentize(root.workspaceSecondaryContainer, 0.4)

                Behavior on radiusPrev {
                    animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                }
                Behavior on radiusNext {
                    animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                }
            }
        }
    }

    // Column mode - active indicator
    Rectangle {
        z: 2
        visible: root.columnMode && root.currentWindowIndex >= 0
        radius: root.useZzzStyle ? Appearance.zzz.cornerRadius
            : root.useAngelStyle ? Appearance.angel.roundingSmall : Math.min(width, height) / 2
        color: root.useAngelStyle ? Appearance.angel.colPrimary : root.workspacePrimary
        Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animationCurves.zzzOvershoot } }
        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

        anchors {
            verticalCenter: vertical ? undefined : parent.verticalCenter
            horizontalCenter: vertical ? parent.horizontalCenter : undefined
        }

        AnimatedTabIndexPair {
            id: columnIdxPair
            index: root.currentWindowIndex
        }
        property real indicatorPosition: Math.min(columnIdxPair.idx1, columnIdxPair.idx2) * workspaceButtonWidth + root.activeWorkspaceMargin
        property real indicatorLength: Math.abs(columnIdxPair.idx1 - columnIdxPair.idx2) * workspaceButtonWidth + workspaceButtonWidth - root.activeWorkspaceMargin * 2
        property real indicatorThickness: workspaceButtonWidth - root.activeWorkspaceMargin * 2

        x: root.vertical ? null : indicatorPosition
        implicitWidth: root.vertical ? indicatorThickness : indicatorLength
        y: root.vertical ? indicatorPosition : null
        implicitHeight: root.vertical ? indicatorLength : indicatorThickness
    }

    // Column mode - buttons with icons
    Grid {
        z: 3
        visible: root.columnMode
        anchors.centerIn: parent
        
        columns: root.vertical ? 1 : Math.max(root.currentWorkspaceWindows.length, 1)
        rows: root.vertical ? Math.max(root.currentWorkspaceWindows.length, 1) : 1
        columnSpacing: 0
        rowSpacing: 0

        Repeater {
            model: root.currentWorkspaceWindows

            Button {
                id: columnButton
                required property var modelData
                required property int index
                
                implicitHeight: vertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.barHeight
                implicitWidth: vertical ? Appearance.sizes.verticalBarWidth : workspaceButtonWidth
                width: vertical ? undefined : workspaceButtonWidth
                height: vertical ? workspaceButtonWidth : undefined
                
                onPressed: {
                    if (modelData?.id !== undefined) {
                        NiriService.focusWindow(modelData.id)
                    }
                }

                background: Item {
                    implicitWidth: workspaceButtonWidth
                    implicitHeight: workspaceButtonWidth
                    
                    property string appIconSource: AppSearch.getIconSource(columnButton.modelData?.app_id ?? "")
                    property bool isActive: columnButton.index === root.currentWindowIndex
                    property color dotColor: isActive ? root.workspaceOnPrimary : root.workspaceOnSecondaryContainer

                    // Dot (when showAppIcons is off) - always hidden in column mode
                    Rectangle {
                        id: columnDot
                        opacity: 0  // Column mode always shows icons
                        visible: opacity > 0
                        anchors.centerIn: parent
                        width: workspaceButtonWidth * 0.18
                        height: width
                        radius: width / 2
                        color: parent.dotColor

                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }

                    // App icon - always visible in column mode
                    Item {
                        anchors.centerIn: parent
                        width: workspaceButtonWidth
                        height: workspaceButtonWidth
                        opacity: 1
                        visible: true

                        IconImage {
                            id: columnAppIcon
                            anchors.centerIn: parent
                            source: parent.parent.appIconSource
                            implicitSize: root.workspaceIconSize

                            Behavior on opacity {
                                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                            }
                        }

                        Loader {
                            active: root.monochromeIcons
                            anchors.fill: columnAppIcon
                            sourceComponent: Item {
                                Desaturate {
                                    id: colDesaturatedIcon
                                    visible: false
                                    anchors.fill: parent
                                    source: columnAppIcon
                                    desaturation: 0.8
                                }
                                ColorOverlay {
                                    anchors.fill: colDesaturatedIcon
                                    source: colDesaturatedIcon
                                    color: ColorUtils.transparentize(columnDot.color, 0.9)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
