import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland

Item {
    id: root

    // Debug logging gated behind QS_DEBUG env var (project convention)
    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log("[DockDrag]", ...args);
    }

    property real maxWindowPreviewHeight: 200
    property real maxWindowPreviewWidth: 300
    property real windowControlsHeight: 30
    property real buttonPadding: 5
    property bool vertical: false
    property string dockPosition: "bottom"
    property var parentWindow: null

    property Item lastHoveredButton
    property bool buttonHovered: false
    property bool contextMenuOpen: false
    property bool requestDockShow: dockPreviewPopup.visible || contextMenuOpen || dragActive

    // Signal to close any open context menu before opening a new one
    signal closeAllContextMenus()

    // Flag to suppress the automatic click() that RippleButton fires after release.
    // Set true when a drag ends so the subsequent onClicked is ignored.
    property bool _suppressNextClick: false

    // Function to show the new preview popup (Waffle-style)
    function showPreviewPopup(appEntry: var, button: Item): void {
        // Respect hoverPreview setting
        if (Config.options?.dock?.hoverPreview === false) return
        dockPreviewPopup.show(appEntry, button)
    }

    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical
    implicitWidth: listView.contentWidth
    implicitHeight: listView.contentHeight

    // ─── Drag & Drop State ───────────────────────────────────────────────
    readonly property bool dragEnabled: Config.options?.dock?.enableDragReorder ?? true
    property bool dragActive: false
    property int dragIndex: -1           // Index of item being dragged in dockItems
    property int dropTargetIndex: -1     // Index where the item would be dropped
    property string dragAppId: ""        // AppId of the item being dragged
    property real dragStartX: 0          // Mouse position at drag start (in listView coords)
    property real dragStartY: 0
    property real dragCurrentX: 0        // Current mouse position (in listView coords)
    property real dragCurrentY: 0

    // How far mouse must move during long-press before it's cancelled
    readonly property real dragThreshold: 18

    // Calculate displacement for each item during drag using actual delegate sizes
    function getDragDisplacement(itemIndex: int): real {
        if (!dragActive || dragIndex < 0 || dropTargetIndex < 0) return 0
        if (itemIndex === dragIndex) return 0 // Dragged item uses its own transform

        // Get the actual size of the dragged item from the ListView
        const draggedItem = listView.itemAtIndex(dragIndex)
        // Use actual delegate size; fallback matches DockButton.implicitHeight
        const step = draggedItem
            ? (vertical ? draggedItem.height : draggedItem.width) + listView.spacing
            : 50 + listView.spacing

        // Items between dragIndex and dropTargetIndex need to shift
        if (dragIndex < dropTargetIndex) {
            // Dragging right/down: items in (dragIndex, dropTargetIndex] shift left/up
            if (itemIndex > dragIndex && itemIndex <= dropTargetIndex) {
                return -step
            }
        } else if (dragIndex > dropTargetIndex) {
            // Dragging left/up: items in [dropTargetIndex, dragIndex) shift right/down
            if (itemIndex >= dropTargetIndex && itemIndex < dragIndex) {
                return step
            }
        }
        return 0
    }

    function startDrag(index: int, appId: string, globalX: real, globalY: real): void {
        if (!dragEnabled) return

        // Close any previews or context menus
        dockPreviewPopup.close()
        closeAllContextMenus()

        dragIndex = index
        dragAppId = appId
        dragStartX = globalX
        dragStartY = globalY
        dragCurrentX = globalX
        dragCurrentY = globalY
        dropTargetIndex = index
        dragActive = true
        _log(`START index=${index} appId=${appId} pos=(${globalX.toFixed(0)},${globalY.toFixed(0)})`)
    }

    function updateDrag(globalX: real, globalY: real): void {
        if (!dragActive || dragIndex < 0) return
        dragCurrentX = globalX
        dragCurrentY = globalY

        // Use actual delegate positions from the ListView for accurate hit-testing
        const count = dockItems.length
        if (count === 0) return

        let bestIndex = dropTargetIndex // Keep current if nothing found
        let bestDist = Infinity

        for (let i = 0; i < count; i++) {
            const item = listView.itemAtIndex(i)
            if (!item) continue

            // Get center position of the delegate in listView coordinates
            const midX = item.x + item.width / 2
            const midY = item.y + item.height / 2

            const dist = vertical
                ? Math.abs(globalY - midY)
                : Math.abs(globalX - midX)

            if (dist < bestDist) {
                bestDist = dist
                bestIndex = i
            }
        }

        // Skip separator as a drop target – snap to nearest non-separator neighbor
        if (bestIndex >= 0 && bestIndex < count && dockItems[bestIndex].appId === "SEPARATOR") {
            // Decide direction based on drag movement
            const movingForward = vertical ? (globalY > dragStartY) : (globalX > dragStartX)
            if (movingForward && bestIndex + 1 < count) bestIndex++
            else if (!movingForward && bestIndex - 1 >= 0) bestIndex--
        }

        if (dropTargetIndex !== bestIndex) {
            _log(`UPDATE dropTarget=${bestIndex} (was ${dropTargetIndex})`)
        }
        dropTargetIndex = bestIndex
    }

    function endDrag(): void {
        if (!dragActive) return

        _log(`END dragIndex=${dragIndex} dropTarget=${dropTargetIndex} reorder=${dragIndex !== dropTargetIndex}`)
        if (dragIndex >= 0 && dropTargetIndex >= 0 && dragIndex !== dropTargetIndex) {
            _applyReorder(dragIndex, dropTargetIndex)
        }

        _resetDragState()
    }

    function cancelDrag(): void {
        _resetDragState()
    }

    function _resetDragState(): void {
        dragActive = false
        dragIndex = -1
        dropTargetIndex = -1
        dragAppId = ""
        dragStartX = 0
        dragStartY = 0
        dragCurrentX = 0
        dragCurrentY = 0
    }

    function _applyReorder(fromIdx: int, toIdx: int): void {
        const fromItem = dockItems[fromIdx]
        const toItem = dockItems[toIdx]

        if (!fromItem || !toItem) return

        const fromAppId = fromItem.originalAppId ?? fromItem.appId
        const toAppId = toItem.originalAppId ?? toItem.appId

        // Skip separator targets
        if (toAppId === "SEPARATOR" || fromAppId === "SEPARATOR") return

        let pinnedApps = [...(Config.options?.dock?.pinnedApps ?? [])]

        const fromIsPinned = fromItem.pinned
        const toIsPinned = toItem.pinned

        if (fromIsPinned && toIsPinned) {
            // Both pinned: reorder within pinnedApps
            const realFromIdx = pinnedApps.findIndex(p => p.toLowerCase() === fromAppId.toLowerCase())
            const realToIdx = pinnedApps.findIndex(p => p.toLowerCase() === toAppId.toLowerCase())

            if (realFromIdx >= 0 && realToIdx >= 0) {
                const [moved] = pinnedApps.splice(realFromIdx, 1)
                pinnedApps.splice(realToIdx, 0, moved)
                Config.setNestedValue("dock.pinnedApps", pinnedApps)
            }
        } else if (!fromIsPinned && toIsPinned) {
            // Dragging a running (unpinned) app to pinned section → auto-pin at position
            const realToIdx = pinnedApps.findIndex(p => p.toLowerCase() === toAppId.toLowerCase())
            const insertIdx = toIdx < fromIdx ? realToIdx : realToIdx + 1
            pinnedApps.splice(insertIdx, 0, fromAppId)
            Config.setNestedValue("dock.pinnedApps", pinnedApps)
        } else if (fromIsPinned && !toIsPinned) {
            // Dragging a pinned app to running section → keep it pinned but move to end
            // (no-op for now, pinned order only affects pinned section)
        } else {
            // Both unpinned running apps: no persistent reorder (they're ephemeral)
        }
    }

    // ─── Dock Items Model ────────────────────────────────────────────────
    property var dockItems: []

    // Direct reactive binding to Config - will automatically trigger when Config changes
    readonly property bool separatePinnedFromRunning: Config.options?.dock?.separatePinnedFromRunning ?? true
    onSeparatePinnedFromRunningChanged: {
        root.rebuildDockItems()
    }

    // Cache compiled regexes - only recompile when config changes
    property var _cachedIgnoredRegexes: []
    property var _lastIgnoredRegexStrings: []

    function _getIgnoredRegexes(): list<var> {
        const ignoredRegexStrings = Config.options?.dock?.ignoredAppRegexes ?? [];
        // Check if we need to recompile
        if (JSON.stringify(ignoredRegexStrings) !== JSON.stringify(_lastIgnoredRegexStrings)) {
            const systemIgnored = ["^$", "^portal$", "^x-run-dialog$", "^kdialog$", "^org.freedesktop.impl.portal.*"];
            const allIgnored = ignoredRegexStrings.concat(systemIgnored);
            _cachedIgnoredRegexes = allIgnored.map(pattern => new RegExp(pattern, "i"));
            _lastIgnoredRegexStrings = ignoredRegexStrings.slice();
        }
        return _cachedIgnoredRegexes;
    }

    function rebuildDockItems() {
        const pinnedApps = Config.options?.dock?.pinnedApps ?? [];
        const ignoredRegexes = _getIgnoredRegexes();
        const separatePinnedFromRunning = root.separatePinnedFromRunning;

        // Get all open windows
        const allToplevels = CompositorService.sortedToplevels && CompositorService.sortedToplevels.length
                ? CompositorService.sortedToplevels
                : ToplevelManager.toplevels.values;

        // Build map of running apps (apps with open windows)
        const runningAppsMap = new Map();
        for (const toplevel of allToplevels) {
            if (!toplevel.appId) continue;
            if (toplevel.appId === "" || toplevel.appId === "null") continue;

            if (ignoredRegexes.some(re => re.test(toplevel.appId))) {
                continue;
            }

            const lowerAppId = toplevel.appId.toLowerCase();
            if (!runningAppsMap.has(lowerAppId)) {
                runningAppsMap.set(lowerAppId, {
                    appId: toplevel.appId,
                    toplevels: [],
                    pinned: false
                });
            }
            runningAppsMap.get(lowerAppId).toplevels.push(toplevel);
        }

        const values = [];
        let order = 0;

        // If separation is disabled, use legacy behavior: combine pinned with their running windows
        if (!separatePinnedFromRunning) {
            // Add all pinned apps (with or without windows)
            for (const appId of pinnedApps) {
                const lowerAppId = appId.toLowerCase();
                const runningEntry = runningAppsMap.get(lowerAppId);
                values.push({
                    uniqueId: "app-" + lowerAppId,
                    appId: lowerAppId,
                    toplevels: runningEntry?.toplevels ?? [],
                    pinned: true,
                    originalAppId: appId,
                    section: "pinned",
                    order: order++
                });
                // Remove from running map so we don't add it again
                runningAppsMap.delete(lowerAppId);
            }

            // Add separator if there are both pinned and unpinned running apps
            if (values.length > 0 && runningAppsMap.size > 0) {
                values.push({
                    uniqueId: "separator",
                    appId: "SEPARATOR",
                    toplevels: [],
                    pinned: false,
                    originalAppId: "SEPARATOR",
                    section: "separator",
                    order: order++
                });
            }

            // Add unpinned running apps
            for (const [lowerAppId, entry] of runningAppsMap) {
                values.push({
                    uniqueId: "app-" + lowerAppId,
                    appId: lowerAppId,
                    toplevels: entry.toplevels,
                    pinned: false,
                    originalAppId: entry.appId,
                    section: "open",
                    order: order++
                });
            }
        } else {
            // NEW BEHAVIOR: Separate pinned-only from running apps
            // 1) Add ONLY pinned apps (without running windows) - left section
            for (const appId of pinnedApps) {
                const lowerAppId = appId.toLowerCase();
                // Only show pinned apps that don't have running windows
                if (!runningAppsMap.has(lowerAppId)) {
                    values.push({
                        uniqueId: "app-" + lowerAppId,
                        appId: lowerAppId,
                        toplevels: [],
                        pinned: true,
                        originalAppId: appId,
                        section: "pinned",
                        order: order++
                    });
                }
            }

            // 2) Add separator if there are both pinned-only apps and running apps
            const hasPinnedOnly = values.length > 0;
            const hasRunning = runningAppsMap.size > 0;

            if (hasPinnedOnly && hasRunning) {
                values.push({
                    uniqueId: "separator",
                    appId: "SEPARATOR",
                    toplevels: [],
                    pinned: false,
                    originalAppId: "SEPARATOR",
                    section: "separator",
                    order: order++
                });
            }

            // 3) Add running apps (right section) - includes pinned apps that are also running
            const sortedRunningApps = [];
            for (const [lowerAppId, entry] of runningAppsMap) {
                sortedRunningApps.push({
                    lowerAppId: lowerAppId,
                    entry: entry
                });
            }
            // Sort to keep consistency: pinned+running apps first (by pinned order), then unpinned
            sortedRunningApps.sort((a, b) => {
                const aIndex = pinnedApps.findIndex(p => p.toLowerCase() === a.lowerAppId);
                const bIndex = pinnedApps.findIndex(p => p.toLowerCase() === b.lowerAppId);

                const aIsPinned = aIndex !== -1;
                const bIsPinned = bIndex !== -1;

                // Pinned apps first (in their pinned order)
                if (aIsPinned && bIsPinned) return aIndex - bIndex;
                if (aIsPinned) return -1;
                if (bIsPinned) return 1;

                // Unpinned apps maintain their order
                return 0;
            });

            for (const {lowerAppId, entry} of sortedRunningApps) {
                values.push({
                    uniqueId: "app-" + lowerAppId,
                    appId: lowerAppId,
                    toplevels: entry.toplevels,
                    pinned: pinnedApps.some(p => p.toLowerCase() === lowerAppId),
                    originalAppId: entry.appId,
                    section: "running",
                    order: order++
                });
            }
        }

        dockItems = values
    }

    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() {
            root.rebuildDockItems()
        }
    }

    Connections {
        target: CompositorService
        function onSortedToplevelsChanged() {
            root.rebuildDockItems()
        }
    }

    Connections {
        target: Config.options?.dock
        function onPinnedAppsChanged() {
            root.rebuildDockItems()
        }
        function onIgnoredAppRegexesChanged() {
            root.rebuildDockItems()
        }
    }

    Component.onCompleted: rebuildDockItems()

    StyledListView {
        id: listView
        spacing: 2
        orientation: root.vertical ? ListView.Vertical : ListView.Horizontal
        anchors {
            top: root.vertical ? undefined : parent.top
            bottom: root.vertical ? undefined : parent.bottom
            left: root.vertical ? parent.left : undefined
            right: root.vertical ? parent.right : undefined
        }
        implicitWidth: contentWidth
        implicitHeight: contentHeight
        interactive: false // Dock should never flick/scroll — all items visible

        Behavior on implicitWidth {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on implicitHeight {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        model: ScriptModel {
            objectProp: "uniqueId"
            values: root.dockItems
        }

        delegate: DockAppButton {
            id: dockDelegate
            required property var modelData
            required property int index
            appToplevel: modelData
            appListRoot: root
            vertical: root.vertical
            dockPosition: root.dockPosition

            anchors.verticalCenter: !root.vertical ? parent?.verticalCenter : undefined
            anchors.horizontalCenter: root.vertical ? parent?.horizontalCenter : undefined

            // Sin insets - el tamaño viene del DockButton
            topInset: 0
            bottomInset: 0
            leftInset: 0
            rightInset: 0

            // ─── Drag & Drop Properties ──────────────────────────────
            readonly property bool isBeingDragged: root.dragActive && root.dragIndex === index
            readonly property bool isDropTarget: root.dragActive && root.dropTargetIndex === index && root.dragIndex !== index
            readonly property real dragDisplacement: root.getDragDisplacement(index)

            // Visual offset when being dragged
            property real _dragOffsetX: isBeingDragged ? (root.dragCurrentX - root.dragStartX) : 0
            property real _dragOffsetY: isBeingDragged ? (root.dragCurrentY - root.dragStartY) : 0

            // Apply displacement transform for non-dragged items during reorder
            transform: Translate {
                id: dockDelegateTranslate
                x: dockDelegate.isBeingDragged
                    ? (root.vertical ? 0 : dockDelegate._dragOffsetX)
                    : (root.vertical ? 0 : dockDelegate.dragDisplacement)
                y: dockDelegate.isBeingDragged
                    ? (root.vertical ? dockDelegate._dragOffsetY : 0)
                    : (root.vertical ? dockDelegate.dragDisplacement : 0)

                Behavior on x {
                    enabled: Appearance.animationsEnabled && !dockDelegate.isBeingDragged
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    enabled: Appearance.animationsEnabled && !dockDelegate.isBeingDragged
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // Elevated z-order when dragging
            z: isBeingDragged ? 100 : 0

            // Scale effect when being dragged
            // Merge active-app highlight scale with drag elevation scale
            // (overrides the base DockAppButton scale property)
            scale: isBeingDragged ? 1.08
                 : appToplevel.toplevels.find(t => t.activated === true) !== undefined ? 1.05
                 : 1.0

            // Dragged item lifts slightly; others dim just enough to signal drag mode
            opacity: isBeingDragged ? 0.8
                   : root.dragActive ? 0.85 : 1.0
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            // ─── Insertion line at drop gap ───────────────────────────
            // Thin accent line centered in the gap that displacement opens.
            // Direction-aware: shows at the edge facing the gap so it
            // visually marks the exact insertion point.
            Rectangle {
                id: insertionLine
                visible: dockDelegate.isDropTarget && !dockDelegate.isSeparator
                z: 50

                // Which direction the item is being dragged
                readonly property bool forward: root.dragIndex >= 0
                    && root.dragIndex < root.dropTargetIndex

                // Horizontal dock → vertical line; vertical dock → horizontal line
                width: root.vertical ? (parent.width * 0.55) : 3
                height: root.vertical ? 3 : (parent.height * 0.55)
                radius: 1.5

                // Position: center the line in the spacing gap at the correct edge
                x: root.vertical
                    ? (parent.width - width) / 2
                    : (forward
                        ? parent.width + (listView.spacing - width) / 2
                        : -(listView.spacing + width) / 2)
                y: root.vertical
                    ? (forward
                        ? parent.height + (listView.spacing - height) / 2
                        : -(listView.spacing + height) / 2)
                    : (parent.height - height) / 2

                color: Appearance.inirEverywhere ? Appearance.inir.colPrimary
                     : Appearance.colors.colPrimary

                opacity: dockDelegate.isDropTarget ? 0.9 : 0

                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }

            // ─── Drag detection: "prime + move" pattern ──────────────
            // 1. Press  → start short timer (180ms)
            // 2. Timer  → silently "prime" (no visual change)
            // 3. Move after primed → drag starts INSTANTLY
            // 4. Release before moving → normal click
            // This feels snappy because the user is usually already
            // moving when the timer fires, so drag begins at ~180ms.
            property real _pressMouseX: 0
            property real _pressMouseY: 0
            property bool _hasPressPos: false
            property bool _dragPrimed: false      // Timer fired, awaiting movement
            property bool _longPressTriggered: false // Drag actually started

            downAction: () => {
                if (!root.dragEnabled || dockDelegate.isSeparator) return
                _longPressTriggered = false
                _dragPrimed = false
                _hasPressPos = false
                _dockPrimeTimer.restart()
            }

            moveAction: (event) => {
                // Only track during an active press, not hover
                if (!dockDelegate.down) return

                // Capture initial press position on first move event
                if (!_hasPressPos) {
                    _pressMouseX = event.x
                    _pressMouseY = event.y
                    _hasPressPos = true
                    return
                }

                const dx = event.x - _pressMouseX
                const dy = event.y - _pressMouseY
                const dist2 = dx * dx + dy * dy

                // Before primed: cancel if mouse drifts too far (user is swiping, not holding)
                if (_dockPrimeTimer.running && !_dragPrimed) {
                    if (dist2 > root.dragThreshold * root.dragThreshold) {
                        _dockPrimeTimer.stop()
                    }
                    return
                }

                // Primed but drag not yet started → start on first movement
                if (_dragPrimed && !root.dragActive) {
                    _longPressTriggered = true
                    const listPos = dockDelegate.mapToItem(listView, _pressMouseX, _pressMouseY)
                    const appId = dockDelegate.appToplevel?.originalAppId
                        ?? dockDelegate.appToplevel?.appId ?? ""
                    root.startDrag(dockDelegate.index, appId, listPos.x, listPos.y)
                    // Fall through to immediately update with current position
                }

                // Forward mouse position during active drag
                if (root.dragActive && root.dragIndex === dockDelegate.index) {
                    const listPos = dockDelegate.mapToItem(listView, event.x, event.y)
                    root.updateDrag(listPos.x, listPos.y)
                }
            }

            releaseAction: () => {
                _dockPrimeTimer.stop()
                _dragPrimed = false
                if (dockDelegate._longPressTriggered) {
                    // Drag was active — end it and suppress the click()
                    // that RippleButton fires right after releaseAction.
                    if (root.dragActive && root.dragIndex === dockDelegate.index) {
                        root.endDrag()
                    }
                    root._suppressNextClick = true
                    dockDelegate._longPressTriggered = false
                }
            }

            Timer {
                id: _dockPrimeTimer
                interval: 180  // Short: just enough to distinguish from a quick click
                onTriggered: {
                    dockDelegate._dragPrimed = true
                    // No visual change yet — drag starts on first movement
                }
            }

            // Connect hover preview signals
            onHoverPreviewRequested: {
                if (!root.dragActive) {
                    root.showPreviewPopup(appToplevel, this)
                }
            }
            onHoverPreviewDismissed: {
                dockPreviewPopup.close()
            }
        }
    }

    // New Waffle-style preview popup
    DockPreview {
        id: dockPreviewPopup
        dockHovered: root.buttonHovered
        dockPosition: root.dockPosition
        anchor.window: root.parentWindow
    }

}
