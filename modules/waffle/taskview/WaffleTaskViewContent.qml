pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks

Item {
    id: root
    signal closed

    readonly property var workspaces: NiriService.currentOutputWorkspaces ?? []
    readonly property int currentWorkspaceIdx: {
        const ws = workspaces.find(w => w.is_active || w.is_focused)
        return ws ? ws.idx : 1
    }

    // Screen dimensions
    readonly property real screenWidth: {
        const info = NiriService.outputs?.[NiriService.currentOutput]
        return info?.logical?.width ?? 1920
    }
    readonly property real screenHeight: {
        const info = NiriService.outputs?.[NiriService.currentOutput]
        return info?.logical?.height ?? 1080
    }
    
    // Thumbnail sizing
    readonly property real workspaceSpacing: 48
    readonly property real thumbnailWidth: Math.min(screenWidth * 0.38, 600)
    readonly property real thumbnailHeight: thumbnailWidth * (screenHeight / screenWidth)
    readonly property real labelHeight: 28
    readonly property real labelSpacing: 10
    readonly property real hintsSpacing: 55  // Space between workspace and hints
    readonly property real dotsHeight: 18
    readonly property real hintsHeight: 18
    readonly property real totalHeight: thumbnailHeight + labelHeight + labelSpacing + hintsSpacing + hintsHeight + dotsHeight
    
    // View mode: "carousel" or "centered"
    readonly property string viewMode: Config.options?.waffles?.taskView?.mode ?? "centered"
    readonly property bool isCenteredMode: viewMode === "centered"
    
    // Search filter
    property string searchQuery: ""
    readonly property var filteredWindowItems: {
        if (searchQuery.length === 0) return cachedWindowItems
        const query = searchQuery.toLowerCase()
        return cachedWindowItems.filter(w => {
            const title = (w.window.title ?? "").toLowerCase()
            const appId = (AppSearch.resolveWindowIdentity(w.window) ?? "").toLowerCase()
            return title.includes(query) || appId.includes(query)
        })
    }
    
    // Auto-scroll to first result when searching
    onFilteredWindowItemsChanged: {
        if (searchQuery.length > 0 && filteredWindowItems.length > 0) {
            const firstResult = filteredWindowItems[0]
            if (firstResult && firstResult.workspaceSlot !== selectedSlot) {
                selectedSlot = firstResult.workspaceSlot
            }
            focusedWindowIndex = 0
        }
    }
    
    // Carousel state
    property int selectedSlot: {
        const idx = cachedWorkspaces.findIndex(ws => ws.is_active || ws.is_focused)
        return idx >= 0 ? idx : 0
    }
    readonly property int wsCount: Math.max(1, cachedWorkspaces.length)

    property int draggingFromWorkspace: -1
    property int dragTargetWorkspace: -1
    property bool isDragging: false
    property int draggingWindowId: -1
    
    // Keyboard navigation for windows
    property int focusedWindowIndex: -1
    
    // Cached data
    property var cachedWorkspaces: []
    property var cachedWindowItems: []
    
    // Preview counts for drag preview
    readonly property var previewCounts: {
        const _isDragging = isDragging
        const _targetWs = dragTargetWorkspace
        const _fromWs = draggingFromWorkspace
        const _draggedId = draggingWindowId
        const _items = cachedWindowItems
        const _workspaces = cachedWorkspaces
        
        const counts = {}
        for (let slot = 0; slot < _workspaces.length; slot++) {
            const ws = _workspaces[slot]
            if (!ws) continue
            
            let count = _items.filter(w => 
                w.workspaceSlot === slot && w.window.id !== _draggedId
            ).length
            
            if (_isDragging && _targetWs !== -1 && ws.idx === _targetWs) {
                count += 1
            }
            counts[slot] = count
        }
        return counts
    }

    width: screenWidth
    height: totalHeight

    function switchToWorkspace(idx: int): void {
        NiriService.switchToWorkspace(idx)
        GlobalStates.waffleTaskViewOpen = false
    }

    function moveWindowToWorkspace(windowId: int, targetIdx: int): void {
        Quickshell.execDetached(["/usr/bin/niri", "msg", "action", "move-window-to-workspace",
            "--window-id", windowId.toString(),
            "--focus", "false",
            targetIdx.toString()])
    }
    
    function moveWindowToNewWorkspace(windowId: int): void {
        // Move window to a new workspace at the end
        const lastWs = cachedWorkspaces[cachedWorkspaces.length - 1]
        const newWsIdx = lastWs ? lastWs.idx + 1 : 1
        Quickshell.execDetached(["/usr/bin/niri", "msg", "action", "move-window-to-workspace",
            "--window-id", windowId.toString(),
            "--focus", "false",
            newWsIdx.toString()])
    }
    
    function renameWorkspace(wsIdx: int, newName: string): void {
        const currentNames = Config.options?.waffles?.workspaceNames ?? {}
        const updatedNames = Object.assign({}, currentNames)
        updatedNames[wsIdx.toString()] = newName
        Config.setNestedValue("waffles.workspaceNames", updatedNames)
        refreshCache()
    }
    
    function closeEmptyWorkspace(wsIdx: int): void {
        // Focus another workspace first, then the empty one will be removed automatically by Niri
        const currentWs = cachedWorkspaces.find(ws => ws.idx === wsIdx)
        if (!currentWs) return
        
        // Find next non-empty workspace to switch to
        const otherWs = cachedWorkspaces.find(ws => 
            ws.idx !== wsIdx && cachedWindowItems.some(w => w.workspaceIdx === ws.idx)
        ) ?? cachedWorkspaces.find(ws => ws.idx !== wsIdx)
        
        if (otherWs) {
            NiriService.switchToWorkspace(otherWs.idx)
            refreshTimer.interval = 300
            refreshTimer.start()
        }
    }
    
    function executeNiriAction(action: string, windowId: int): void {
        Quickshell.execDetached(["/usr/bin/niri", "msg", "action", "focus-window", "--id", windowId.toString()])
        Qt.callLater(() => {
            Quickshell.execDetached(["/usr/bin/niri", "msg", "action", action])
            refreshTimer.start()
        })
    }
    
    function refreshCache(): void {
        cachedWorkspaces = workspaces.map(ws => ({
            id: ws.id,
            idx: ws.idx,
            name: ws.name,
            is_active: ws.is_active,
            is_focused: ws.is_focused,
            output: ws.output
        }))
        
        const wsList = cachedWorkspaces
        const result = []
        
        for (let wsIdx = 0; wsIdx < wsList.length; wsIdx++) {
            const ws = wsList[wsIdx]
            let wins = (NiriService.windows ?? []).filter(w => w.workspace_id === ws.id)
            
            // Sort windows by their X position in scrolling layout (column order)
            wins = wins.sort((a, b) => {
                const posA = a.layout?.pos_in_scrolling_layout?.[0] ?? 0
                const posB = b.layout?.pos_in_scrolling_layout?.[0] ?? 0
                return posA - posB
            })
            
            // Calculate total width of all windows in this workspace
            let totalWidth = 0
            for (const win of wins) {
                totalWidth += win.layout?.tile_size?.[0] ?? screenWidth
            }
            
            // Calculate cumulative X offset for each window
            let cumulativeX = 0
            
            for (let i = 0; i < wins.length; i++) {
                const win = wins[i]
                const tileWidth = win.layout?.tile_size?.[0] ?? screenWidth
                const tileHeight = win.layout?.tile_size?.[1] ?? screenHeight
                
                // Proportion is the ratio of this window's width to total workspace width
                const proportion = totalWidth > 0 ? tileWidth / totalWidth : 1
                // Offset is where this window starts (as proportion of total)
                const proportionOffset = totalWidth > 0 ? cumulativeX / totalWidth : 0
                
                result.push({
                    window: {
                        id: win.id,
                        app_id: AppSearch.resolveWindowIdentity(win),
                        title: win.title,
                        workspace_id: win.workspace_id,
                        is_focused: win.is_focused
                    },
                    tileWidth: tileWidth,
                    tileHeight: tileHeight,
                    totalTileWidth: totalWidth,
                    proportion: proportion,
                    proportionOffset: proportionOffset,
                    workspaceSlot: wsIdx,
                    workspaceIdx: ws.idx,
                    indexInWorkspace: i,
                    totalInWorkspace: wins.length
                })
                
                cumulativeX += tileWidth
            }
        }
        cachedWindowItems = result
        
        // Capture previews for TaskView (only stale/missing ones)
        Qt.callLater(() => WindowPreviewService.captureForTaskView())
    }
    
    Connections {
        target: GlobalStates
        function onWaffleTaskViewOpenChanged(): void {
            if (GlobalStates.waffleTaskViewOpen) {
                root.refreshCache()
            }
        }
    }
    
    Connections {
        target: NiriService
        function onWindowsChanged(): void {
            // Only refresh if window count changed (window closed/opened), not on focus change
            if (GlobalStates.waffleTaskViewOpen) {
                const currentCount = (NiriService.windows ?? []).length
                const cachedCount = root.cachedWindowItems.length
                if (currentCount !== cachedCount) {
                    root.refreshCache()
                }
            }
        }
    }
    
    Component.onCompleted: {
        if (GlobalStates.waffleTaskViewOpen) {
            refreshCache()
        }
    }
    
    Timer {
        id: refreshTimer
        interval: 150
        onTriggered: root.refreshCache()
    }

    function selectNext(): void {
        if (selectedSlot < wsCount - 1) {
            selectedSlot++
            focusedWindowIndex = -1
        }
    }
    function selectPrev(): void {
        if (selectedSlot > 0) {
            selectedSlot--
            focusedWindowIndex = -1
        }
    }
    
    // Get windows in current workspace slot
    function getWindowsInSlot(slot: int): var {
        return cachedWindowItems.filter(w => w.workspaceSlot === slot)
    }
    
    // Navigate between windows with Tab
    function focusNextWindow(): void {
        const windows = getWindowsInSlot(selectedSlot)
        if (windows.length === 0) return
        focusedWindowIndex = (focusedWindowIndex + 1) % windows.length
    }
    
    function focusPrevWindow(): void {
        const windows = getWindowsInSlot(selectedSlot)
        if (windows.length === 0) return
        focusedWindowIndex = focusedWindowIndex <= 0 ? windows.length - 1 : focusedWindowIndex - 1
    }
    
    // Get currently focused window data
    function getFocusedWindow(): var {
        const windows = getWindowsInSlot(selectedSlot)
        if (windows.length === 0) return null
        if (focusedWindowIndex < 0 || focusedWindowIndex >= windows.length) {
            return windows.find(w => w.window.is_focused) ?? windows[0]
        }
        return windows[focusedWindowIndex]
    }

    opacity: GlobalStates.waffleTaskViewOpen ? 1 : 0
    scale: GlobalStates.waffleTaskViewOpen ? 1 : 0.96
    
    Behavior on opacity { 
        NumberAnimation { 
            duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
        } 
    }
    Behavior on scale { 
        NumberAnimation { 
            duration: Looks.transition.enabled ? Looks.transition.duration.panel : 0
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Looks.transition.easing.bezierCurve.spring
        } 
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) {
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
            if (delta > 0) root.selectPrev()
            else if (delta < 0) root.selectNext()
        }
    }
    
    Keys.onLeftPressed: selectPrev()
    Keys.onRightPressed: selectNext()
    Keys.onTabPressed: event => {
        if (event.modifiers & Qt.ShiftModifier) focusPrevInSearch()
        else focusNextInSearch()
        event.accepted = true
    }
    Keys.onBacktabPressed: { focusPrevInSearch() }
    
    // Navigate in search results or current workspace
    function focusNextInSearch(): void {
        if (searchQuery.length > 0 && filteredWindowItems.length > 0) {
            focusedWindowIndex = (focusedWindowIndex + 1) % filteredWindowItems.length
        } else {
            focusNextWindow()
        }
    }
    
    function focusPrevInSearch(): void {
        if (searchQuery.length > 0 && filteredWindowItems.length > 0) {
            focusedWindowIndex = focusedWindowIndex <= 0 ? filteredWindowItems.length - 1 : focusedWindowIndex - 1
        } else {
            focusPrevWindow()
        }
    }
    Keys.onReturnPressed: selectFocusedOrWorkspace()
    Keys.onEnterPressed: selectFocusedOrWorkspace()
    
    function selectFocusedOrWorkspace(): void {
        // If searching, select from filtered results
        if (searchQuery.length > 0 && filteredWindowItems.length > 0) {
            const idx = Math.max(0, Math.min(focusedWindowIndex, filteredWindowItems.length - 1))
            const win = filteredWindowItems[idx]
            if (win) {
                NiriService.focusWindow(win.window.id)
                GlobalStates.waffleTaskViewOpen = false
                return
            }
        }
        
        // Normal mode - focus window or switch workspace
        const focusedWin = getFocusedWindow()
        if (focusedWin) {
            NiriService.focusWindow(focusedWin.window.id)
            GlobalStates.waffleTaskViewOpen = false
        } else {
            const ws = cachedWorkspaces[selectedSlot]
            if (ws) switchToWorkspace(ws.idx)
        }
    }
    Keys.onEscapePressed: {
        if (searchQuery.length > 0) {
            searchQuery = ""
        } else {
            GlobalStates.waffleTaskViewOpen = false
        }
    }
    
    // Type to search and keyboard shortcuts
    Keys.onPressed: (event) => {
        // Backspace to delete search
        if (event.key === Qt.Key_Backspace && searchQuery.length > 0) {
            searchQuery = searchQuery.slice(0, -1)
            event.accepted = true
            return
        }
        
        // Delete to close focused window
        if (event.key === Qt.Key_Delete && !event.modifiers) {
            const focusedWin = getFocusedWindow()
            if (focusedWin) {
                NiriService.closeWindow(focusedWin.window.id)
                refreshTimer.start()
                event.accepted = true
                return
            }
        }
        
        // Handle printable characters for search (charCode >= 32 filters control chars)
        if (event.text && event.text.length === 1 && !event.modifiers && event.text.charCodeAt(0) >= 32) {
            searchQuery += event.text
            event.accepted = true
        }
    }

    Item {
        id: carouselContainer
        anchors.fill: parent
        clip: false

        Item {
            id: contentContainer
            width: workspaceRow.width
            height: workspaceRow.height
            y: 0
            x: (root.screenWidth / 2) - (root.selectedSlot * (root.thumbnailWidth + root.workspaceSpacing)) - (root.thumbnailWidth / 2)
            
            Behavior on x {
                NumberAnimation { 
                    duration: Looks.transition.enabled ? Looks.transition.duration.panel : 0
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
                }
            }

            Row {
                id: workspaceRow
                spacing: root.workspaceSpacing

                Repeater {
                    model: root.cachedWorkspaces

                    WorkspaceThumbnail {
                        required property var modelData
                        required property int index

                        workspace: modelData
                        workspaceIndex: index
                        thumbnailWidth: root.thumbnailWidth
                        thumbnailHeight: root.thumbnailHeight
                        isActive: modelData.is_active || modelData.is_focused
                        isSelected: index === root.selectedSlot
                        isDragTarget: root.dragTargetWorkspace === modelData.idx
                        isLastEmpty: {
                            const isLast = index === root.cachedWorkspaces.length - 1
                            if (!isLast) return false
                            return !root.cachedWindowItems.some(w => w.workspaceSlot === index)
                        }
                        isEmpty: !root.cachedWindowItems.some(w => w.workspaceSlot === index)
                        
                        // Centered mode properties
                        viewMode: root.viewMode
                        distanceFromSelected: Math.abs(index - root.selectedSlot)
                        relativePosition: index - root.selectedSlot

                        onClicked: {
                            if (index !== root.selectedSlot) {
                                root.selectedSlot = index
                            }
                        }
                        onDragEntered: root.dragTargetWorkspace = modelData.idx
                        onWorkspaceRenamed: function(wsIdx, newName) {
                            root.renameWorkspace(wsIdx, newName)
                        }
                        onCloseRequested: root.closeEmptyWorkspace(modelData.idx)
                    }
                }
            }

            // New workspace drop zone (appears at right edge when dragging)
            Item {
                id: newWorkspaceZone
                visible: root.isDragging
                anchors.left: workspaceRow.right
                anchors.leftMargin: root.workspaceSpacing / 2
                anchors.top: workspaceRow.top
                anchors.topMargin: root.labelHeight + root.labelSpacing
                width: root.thumbnailWidth * 0.6
                height: root.thumbnailHeight
                opacity: newWsDropArea.containsDrag ? 1 : 0.6
                
                Behavior on opacity { 
                    NumberAnimation { 
                        duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0
                        easing.type: Easing.OutQuad
                    } 
                }
                
                Rectangle {
                    anchors.fill: parent
                    radius: Looks.radius.large
                    color: newWsDropArea.containsDrag ? 
                        ColorUtils.transparentize(Looks.colors.accent, 0.7) : 
                        ColorUtils.transparentize(Looks.colors.bg1Base, 0.5)
                    border.width: 2
                    border.color: newWsDropArea.containsDrag ? Looks.colors.accent : Looks.colors.bg2Border
                    
                    Behavior on color { 
                        ColorAnimation { 
                            duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0
                            easing.type: Easing.OutQuad
                        } 
                    }
                    Behavior on border.color { 
                        ColorAnimation { 
                            duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0
                            easing.type: Easing.OutQuad
                        } 
                    }
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 40
                            height: 40
                            radius: Looks.radius.medium
                            color: newWsDropArea.containsDrag ? 
                                ColorUtils.transparentize(Looks.colors.accent, 0.5) : 
                                ColorUtils.transparentize(Looks.colors.fg, 0.85)
                            
                            WText {
                                anchors.centerIn: parent
                                text: "+"
                                font.pixelSize: 24
                                font.weight: Font.Light
                                color: newWsDropArea.containsDrag ? Looks.colors.accent : Looks.colors.fg
                            }
                        }
                        
                        WText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Translation.tr("New desktop")
                            font.pixelSize: Looks.font.pixelSize.small
                            color: newWsDropArea.containsDrag ? Looks.colors.accent : Looks.colors.subfg
                        }
                    }
                }
                
                DropArea {
                    id: newWsDropArea
                    anchors.fill: parent
                    onEntered: {
                        // Signal to create new workspace
                        root.dragTargetWorkspace = -999  // Special value for "new workspace"
                    }
                }
            }

            Item {
                id: windowSpace
                anchors.left: workspaceRow.left
                anchors.top: workspaceRow.top
                anchors.topMargin: root.labelHeight + root.labelSpacing
                width: workspaceRow.width
                height: root.thumbnailHeight
                z: 10

                Repeater {
                    model: root.searchQuery.length > 0 ? root.filteredWindowItems : root.cachedWindowItems

                    WindowThumbnail {
                        required property var modelData
                        required property int index

                        windowData: modelData.window
                        workspaceSlot: modelData.workspaceSlot
                        indexInWorkspace: modelData.indexInWorkspace
                        totalInWorkspace: modelData.totalInWorkspace
                        thumbnailWidth: root.thumbnailWidth
                        thumbnailHeight: root.thumbnailHeight
                        workspaceSpacing: root.workspaceSpacing
                        isCurrentWorkspace: modelData.workspaceIdx === root.currentWorkspaceIdx
                        screenWidth: root.screenWidth
                        
                        proportion: modelData.proportion ?? 1
                        proportionOffset: modelData.proportionOffset ?? 0
                        tileWidth: modelData.tileWidth ?? 0
                        
                        previewTotalInWorkspace: root.previewCounts[modelData.workspaceSlot] ?? modelData.totalInWorkspace
                        
                        // Keyboard focus highlight - different logic for search mode
                        isKeyboardFocused: root.searchQuery.length > 0 ? 
                            (index === root.focusedWindowIndex) :
                            (modelData.workspaceSlot === root.selectedSlot && 
                             root.focusedWindowIndex >= 0 && 
                             modelData.indexInWorkspace === root.focusedWindowIndex)
                        
                        // Search highlight
                        searchQuery: root.searchQuery

                        onDragStarted: function(wsIdx, windowId) {
                            root.isDragging = true
                            root.draggingFromWorkspace = wsIdx
                            root.draggingWindowId = windowId
                        }
                        onDragEnded: function() {
                            const fromWs = root.draggingFromWorkspace
                            const targetWs = root.dragTargetWorkspace
                            const windowId = modelData.window.id
                            
                            // Handle new workspace creation
                            if (targetWs === -999) {
                                root.moveWindowToNewWorkspace(windowId)
                                root.isDragging = false
                                root.draggingFromWorkspace = -1
                                root.dragTargetWorkspace = -1
                                root.draggingWindowId = -1
                                refreshTimer.interval = 300  // Longer delay for new ws
                                refreshTimer.start()
                                return
                            }
                            
                            const movedToOther = targetWs !== -1 && targetWs !== fromWs
                            
                            if (movedToOther) {
                                root.moveWindowToWorkspace(windowId, targetWs)
                            }
                            
                            root.isDragging = false
                            root.draggingFromWorkspace = -1
                            root.dragTargetWorkspace = -1
                            root.draggingWindowId = -1
                            
                            if (movedToOther) {
                                refreshTimer.interval = 150
                                refreshTimer.start()
                            }
                        }
                        onNiriAction: function(action, windowId) {
                            root.executeNiriAction(action, windowId)
                        }
                        onFocusRequested: function(slot) {
                            root.selectedSlot = slot
                        }
                    }
                }
            }
        }
    }
    
    // Search bar - Windows 11 style
    Rectangle {
        id: searchBar
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: -60
        width: 220
        height: 44
        radius: Looks.radius.large
        color: Looks.colors.bg0Opaque
        border.width: 1.2
        border.color: searchBar.activeFocus || root.searchQuery.length > 0 ? Looks.colors.accent : Looks.colors.bg2Border
        visible: true
        
        Behavior on border.color { 
            ColorAnimation { 
                duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0
                easing.type: Easing.OutQuad
            } 
        }
        
        Row {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10
            
            FluentIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: "search"
                implicitSize: 18
                color: root.searchQuery.length > 0 ? Looks.colors.accent : Looks.colors.subfg
            }
            
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 80
                height: 24
                
                WText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.searchQuery.length === 0
                    text: Translation.tr("Type to search")
                    font.pixelSize: Looks.font.pixelSize.normal
                    color: Looks.colors.subfg
                }
                
                WText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.searchQuery.length > 0
                    text: root.searchQuery
                    font.pixelSize: Looks.font.pixelSize.normal
                    color: Looks.colors.fg
                }
            }
            
            // Results count
            WText {
                id: resultsText
                anchors.verticalCenter: parent.verticalCenter
                visible: root.searchQuery.length > 0
                text: root.filteredWindowItems.length.toString()
                font.pixelSize: Looks.font.pixelSize.small
                font.weight: Font.Medium
                color: Looks.colors.subfg
            }
        }
    }
    
    // Keyboard hints bar - minimal, only essential shortcuts
    // Keyboard hints bar - more visible
    Row {
        id: hintsBar
        anchors.bottom: dotsRow.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 4
        spacing: 24
        
        KeyHint { keyLabel: "←→"; actionLabel: Translation.tr("Desktops") }
        KeyHint { keyLabel: "Tab"; actionLabel: Translation.tr("Windows") }
        KeyHint { keyLabel: "Enter"; actionLabel: Translation.tr("Open") }
        KeyHint { keyLabel: "Del"; actionLabel: Translation.tr("Close") }
    }
    
    component KeyHint: Row {
        property string keyLabel: ""
        property string actionLabel: ""
        spacing: 6
        
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: keyText.width + 14
            height: 24
            radius: 6
            color: ColorUtils.transparentize(Looks.colors.bg0Opaque, 0.3)
            border.width: 1
            border.color: ColorUtils.transparentize(Looks.colors.fg, 0.8)
            
            WText {
                id: keyText
                anchors.centerIn: parent
                text: keyLabel
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Looks.colors.fg
            }
        }
        
        WText {
            anchors.verticalCenter: parent.verticalCenter
            text: actionLabel
            font.pixelSize: Looks.font.pixelSize.normal
            color: Looks.colors.fg
            opacity: 0.85
        }
    }
    
    // Workspace dots indicator
    Row {
        id: dotsRow
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 8
        spacing: 8
        
        Repeater {
            model: root.cachedWorkspaces
            
            Item {
                required property var modelData
                required property int index
                
                width: dotContent.width
                height: root.dotsHeight
                
                readonly property int windowCount: root.cachedWindowItems.filter(w => w.workspaceSlot === index).length
                readonly property bool isSelected: index === root.selectedSlot
                readonly property bool isActive: modelData.is_active || modelData.is_focused
                
                Row {
                    id: dotContent
                    anchors.centerIn: parent
                    spacing: 4
                    
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: isSelected ? 24 : 8
                        height: 8
                        radius: 4
                        color: isActive ? Looks.colors.accent : 
                               isSelected ? ColorUtils.transparentize(Looks.colors.fg, 0.3) :
                               ColorUtils.transparentize(Looks.colors.fg, 0.7)
                        
                        Behavior on width { 
                            NumberAnimation { 
                                duration: Looks.transition.enabled ? 150 : 0
                                easing.type: Easing.OutCubic 
                            } 
                        }
                        Behavior on color { 
                            ColorAnimation { 
                                duration: Looks.transition.enabled ? 120 : 0 
                            } 
                        }
                    }
                    
                    // Window count badge
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: windowCount > 0 && isSelected
                        width: countText.width + 8
                        height: 16
                        radius: 8
                        color: ColorUtils.transparentize(Looks.colors.fg, 0.85)
                        
                        WText {
                            id: countText
                            anchors.centerIn: parent
                            text: windowCount.toString()
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: Looks.colors.fg
                        }
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    onClicked: root.selectedSlot = index
                }
            }
        }
    }
}
