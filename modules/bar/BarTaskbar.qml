pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models

// Taskbar embedded in the bar — reuses dock app model and logic
// but renders with bar-appropriate sizing and style.
// Supports horizontal (top/bottom bar) and vertical (left/right bar) orientations.
Item {
    id: root
    property bool _sortingConsumerAcquired: false

    property var parentWindow: null
    property bool vertical: false
    // Bar position: "top", "bottom", "left", "right"
    property string barPosition: {
        if (vertical) return (Config.options?.bar?.bottom ?? false) ? "right" : "left"
        return (Config.options?.bar?.bottom ?? false) ? "bottom" : "top"
    }
    // Maximum height for vertical mode (-1 = no limit, 0+ = cap)
    property real maximumHeight: -1

    // Height the host grants us. Islands hand over the capsule's inner height, so
    // the buttons size to the surface they sit on instead of the whole bar.
    property real slotSize: -1

    readonly property real barSize: vertical
        ? Appearance.sizes.baseVerticalBarWidth
        : (slotSize > 0 ? Math.min(slotSize, Appearance.sizes.baseBarHeight) : Appearance.sizes.baseBarHeight)
    property real iconSize: vertical ? Math.round(barSize * 0.58) : Math.round(barSize * 0.68)

    readonly property bool isOverflowing: vertical && maximumHeight > 0 && listView.contentHeight > (maximumHeight - 8)

    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical
    implicitWidth: vertical ? barSize : (listView.contentWidth + 8)
    implicitHeight: vertical
        ? (maximumHeight > 0 ? Math.min(listView.contentHeight + 8, maximumHeight) : (listView.contentHeight + 8))
        : barSize

    // Per-item slot pitch in horizontal mode (icon + spacing), used to decide
    // how many items fit before the focused/running ones must be prioritised.
    readonly property real itemPitch: barSize + listView.spacing
    // Visible width available for items in horizontal mode (slot width minus the
    // 8px the implicitWidth accounts for). Drives focus-priority trimming below.
    readonly property real availableWidth: vertical ? -1 : Math.max(0, root.width - 8)

    // ─── Dock Items Model (mirrored from DockApps logic) ─────────────
    // `dockItems` is the full model; `visibleDockItems` is what the ListView
    // renders after horizontal-overflow trimming (focused + running kept,
    // pinned-only shed first when space runs out).
    property var dockItems: []

    // Horizontal-overflow trimming: when the slot can't fit every item, shed the
    // least-relevant ones first — pinned apps that aren't running (pure
    // shortcuts) — while always keeping running and focused apps. The focused
    // app is guaranteed visible. Vertical mode scrolls instead, so it's a no-op.
    readonly property var visibleDockItems: {
        const items = root.dockItems
        if (root.vertical || !(root.availableWidth > 0) || items.length === 0)
            return items
        const pitch = root.itemPitch > 0 ? root.itemPitch : root.barSize
        const maxFit = Math.max(1, Math.floor((root.availableWidth + listView.spacing) / pitch))
        if (items.length <= maxFit)
            return items
        // Rank: running/focused stay; pinned-only (running === false) are the
        // first to drop. Keep original order otherwise (stable, no shuffle).
        const keep = []
        const droppable = []
        for (const it of items) {
            if (it.section === "separator") continue
            if (it.running === false && it.focused !== true) droppable.push(it)
            else keep.push(it)
        }
        // If even the must-keep set overflows, trim it too (oldest order first),
        // but never drop the focused item.
        let result
        if (keep.length >= maxFit) {
            const focused = keep.filter(it => it.focused === true)
            const rest = keep.filter(it => it.focused !== true)
            result = focused.concat(rest).slice(0, maxFit)
        } else {
            const room = maxFit - keep.length
            result = keep.concat(droppable.slice(0, room))
        }
        // Re-sort kept items back into their original model order so the bar
        // doesn't reorder visually (focus only affects WHICH items show).
        const orderOf = new Map(items.map((it, i) => [it.uniqueId, i]))
        result.sort((a, b) => orderOf.get(a.uniqueId) - orderOf.get(b.uniqueId))
        // Drop a now-orphaned leading/trailing separator.
        return result.filter((it, i) => {
            if (it.section !== "separator") return true
            const prev = result[i - 1], next = result[i + 1]
            return prev && next && prev.section !== "separator" && next.section !== "separator"
        })
    }

    readonly property bool separatePinnedFromRunning: Config.options?.dock?.separatePinnedFromRunning ?? true
    onSeparatePinnedFromRunningChanged: rebuildDockItems()

    property var _cachedIgnoredRegexes: []
    property var _lastIgnoredRegexStrings: []

    function _getIgnoredRegexes(): list<var> {
        const ignoredRegexStrings = Config.options?.dock?.ignoredAppRegexes ?? [];
        if (JSON.stringify(ignoredRegexStrings) !== JSON.stringify(_lastIgnoredRegexStrings)) {
            const systemIgnored = ["^$", "^portal$", "^x-run-dialog$", "^kdialog$", "^org.freedesktop.impl.portal.*"];
            const allIgnored = ignoredRegexStrings.concat(systemIgnored);
            _cachedIgnoredRegexes = allIgnored.map(pattern => new RegExp(pattern, "i"));
            _lastIgnoredRegexStrings = ignoredRegexStrings.slice();
        }
        return _cachedIgnoredRegexes;
    }

    Timer {
        id: rebuildTimer
        interval: 80
        repeat: false
        onTriggered: root._doRebuildDockItems()
    }

    function rebuildDockItems(): void {
        rebuildTimer.restart()
    }

    function _toplevelLiveKey(toplevel: var): string {
        if (!toplevel) return ""
        if (toplevel._sourceKey !== undefined && toplevel._sourceKey !== null)
            return String(toplevel._sourceKey)
        return `${toplevel.appId || ""}::${toplevel.title || ""}`
    }

    // Compare toplevels by stable identifier (sourceKey / appId+title) instead of
    // object reference — sortToplevels() rebuilds enriched objects on every
    // focus change, so reference comparison would always trigger a rebuild and
    // shake the taskbar layout for non-structural updates.
    function _dockItemsEqual(oldItems: var, newItems: var): bool {
        if (oldItems.length !== newItems.length) return false
        for (let i = 0; i < oldItems.length; i++) {
            const o = oldItems[i], n = newItems[i]
            if (o.uniqueId !== n.uniqueId || o.pinned !== n.pinned || o.section !== n.section || o.focused !== n.focused) return false
            const oTL = o.toplevels, nTL = n.toplevels
            if (oTL.length !== nTL.length) return false
            for (let j = 0; j < oTL.length; j++) {
                if (root._toplevelLiveKey(oTL[j]) !== root._toplevelLiveKey(nTL[j])) return false
                if (!!oTL[j].activated !== !!nTL[j].activated) return false
            }
        }
        return true
    }

    // App id of the currently focused window (lowercased). Used to flag the
    // focused item so it's prioritised for visibility when space runs out.
    readonly property string focusedAppId: CompositorService.isNiri
        ? String(NiriService.activeWindow?.app_id ?? "").toLowerCase()
        : String(ToplevelManager.activeToplevel?.appId ?? "").toLowerCase()

    function _doRebuildDockItems(): void {
        const pinnedApps = Config.options?.dock?.pinnedApps ?? [];
        const ignoredRegexes = _getIgnoredRegexes();
        const separate = root.separatePinnedFromRunning;
        const focusedId = root.focusedAppId;

        // Source of truth (mirrors DockApps): on Niri, sortedToplevels is
        // built from niri's authoritative `windows` list and is the only
        // valid source — falling back to ToplevelManager would resurrect
        // stale Wayland foreign-toplevel handles when an app fails to release
        // its handle on close (zen, electron, AppImages…), the exact ghost
        // bug we want to avoid. Off-Niri, fall back to ToplevelManager only
        // when sortedToplevels hasn't been populated.
        const sorted = CompositorService.sortedToplevels;
        const sortedHasItems = sorted && sorted.length > 0;
        const niriAuthoritative = CompositorService.isNiri;
        const allToplevels = niriAuthoritative
                ? (sorted ?? [])
                : (sortedHasItems ? sorted : ToplevelManager.toplevels.values);

        // Off-Niri ghost guard: when using enriched `sorted`, cross-check it
        // against live ToplevelManager and drop entries with no live handle.
        // On Niri this is redundant (sortToplevels already filters ghosts).
        const liveToplevelCounts = new Map();
        const crossCheck = sortedHasItems && !niriAuthoritative;
        if (crossCheck) {
            for (const tl of ToplevelManager.toplevels.values) {
                const key = root._toplevelLiveKey(tl);
                liveToplevelCounts.set(key, (liveToplevelCounts.get(key) ?? 0) + 1);
            }
        }

        const runningAppsMap = new Map();
        for (const toplevel of allToplevels) {
            if (!toplevel.appId || toplevel.appId === "" || toplevel.appId === "null") continue;
            const effectiveId = AppSearch.resolveWindowIdentity(toplevel);
            if (ignoredRegexes.some(re => re.test(effectiveId))) continue;
            if (crossCheck) {
                const key = root._toplevelLiveKey(toplevel);
                const count = liveToplevelCounts.get(key) ?? 0;
                if (count <= 0) continue;
                liveToplevelCounts.set(key, count - 1);
            }

            const lowerAppId = effectiveId.toLowerCase();
            if (!runningAppsMap.has(lowerAppId)) {
                runningAppsMap.set(lowerAppId, {
                    appId: effectiveId,
                    toplevels: [],
                    pinned: false
                });
            }
            runningAppsMap.get(lowerAppId).toplevels.push(toplevel);
        }

        const values = [];
        let order = 0;

        if (!separate) {
            for (const appId of pinnedApps) {
                const lowerAppId = appId.toLowerCase();
                const runningEntry = runningAppsMap.get(lowerAppId);
                // Skip pinned apps with no desktop entry and no running windows
                if (!runningEntry && !AppSearch.lookupDesktopEntry(appId))
                    continue;
                values.push({
                    uniqueId: "app-" + lowerAppId,
                    appId: lowerAppId,
                    toplevels: runningEntry?.toplevels ?? [],
                    pinned: true,
                    running: (runningEntry?.toplevels?.length ?? 0) > 0,
                    focused: focusedId === lowerAppId,
                    originalAppId: appId,
                    section: "pinned",
                    order: order++
                });
                runningAppsMap.delete(lowerAppId);
            }

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

            // Stable alphabetical order so unpinned apps don't shuffle as
            // sortedToplevels reorders on focus/layout changes.
            const unpinned = Array.from(runningAppsMap.entries())
                .sort((a, b) => a[0].localeCompare(b[0]));
            for (const [lowerAppId, entry] of unpinned) {
                values.push({
                    uniqueId: "app-" + lowerAppId,
                    appId: lowerAppId,
                    toplevels: entry.toplevels,
                    pinned: false,
                    running: true,
                    focused: focusedId === lowerAppId,
                    originalAppId: entry.appId,
                    section: "open",
                    order: order++
                });
            }
        } else {
            for (const appId of pinnedApps) {
                const lowerAppId = appId.toLowerCase();
                if (!runningAppsMap.has(lowerAppId)) {
                    // Skip pinned apps with no desktop entry
                    if (!AppSearch.lookupDesktopEntry(appId))
                        continue;
                    values.push({
                        uniqueId: "app-" + lowerAppId,
                        appId: lowerAppId,
                        toplevels: [],
                        pinned: true,
                        running: false,
                        focused: false,
                        originalAppId: appId,
                        section: "pinned",
                        order: order++
                    });
                }
            }

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

            const sortedRunningApps = [];
            for (const [lowerAppId, entry] of runningAppsMap) {
                sortedRunningApps.push({ lowerAppId, entry });
            }
            // Pinned+running first (by pinned order), then unpinned alphabetically
            // — stable across sortedToplevels reorderings caused by focus changes.
            sortedRunningApps.sort((a, b) => {
                const aIndex = pinnedApps.findIndex(p => p.toLowerCase() === a.lowerAppId);
                const bIndex = pinnedApps.findIndex(p => p.toLowerCase() === b.lowerAppId);
                const aIsPinned = aIndex !== -1;
                const bIsPinned = bIndex !== -1;
                if (aIsPinned && bIsPinned) return aIndex - bIndex;
                if (aIsPinned) return -1;
                if (bIsPinned) return 1;
                return a.lowerAppId.localeCompare(b.lowerAppId);
            });

            for (const {lowerAppId, entry} of sortedRunningApps) {
                values.push({
                    uniqueId: "app-" + lowerAppId,
                    appId: lowerAppId,
                    toplevels: entry.toplevels,
                    pinned: pinnedApps.some(p => p.toLowerCase() === lowerAppId),
                    running: entry.toplevels.length > 0,
                    focused: focusedId === lowerAppId,
                    originalAppId: entry.appId,
                    section: "running",
                    order: order++
                });
            }
        }

        if (!_dockItemsEqual(dockItems, values)) {
            dockItems = values
        }
    }

    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() { root.rebuildDockItems() }
    }
    Connections {
        target: CompositorService
        function onSortedToplevelsChanged() { root.rebuildDockItems() }
    }
    Connections {
        target: Config.options?.dock
        function onPinnedAppsChanged() { root.rebuildDockItems() }
        function onIgnoredAppRegexesChanged() { root.rebuildDockItems() }
    }
    Connections {
        target: Config.options?.windows
        function onAppIdentityRulesChanged() { root.rebuildDockItems() }
    }
    Component.onCompleted: {
        CompositorService.acquireSortingConsumer()
        _sortingConsumerAcquired = true
        rebuildDockItems()
    }
    Component.onDestruction: {
        if (_sortingConsumerAcquired)
            CompositorService.releaseSortingConsumer()
    }

    // ─── Hover preview state ────────────────────────────────────────
    property Item lastHoveredButton
    property bool buttonHovered: false
    property bool contextMenuOpen: false

    signal closeAllContextMenus()

    function showPreviewPopup(appEntry: var, button: Item): void {
        if (Config.options?.dock?.hoverPreview === false) return
        previewPopup.show(appEntry, button)
    }

    // ─── ListView ───────────────────────────────────────────────────
    StyledListView {
        id: listView
        spacing: 2
        orientation: root.vertical ? ListView.Vertical : ListView.Horizontal
        // Horizontal: align left (next to sidebar button). Vertical: center horizontally, top-align.
        anchors.left: root.vertical ? undefined : parent.left
        anchors.top: root.vertical ? parent.top : undefined
        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        implicitWidth: root.vertical ? root.barSize : contentWidth
        implicitHeight: root.vertical ? contentHeight : root.barSize
        width: root.vertical ? root.barSize : contentWidth
        height: root.vertical
            ? (root.maximumHeight > 0 ? Math.min(contentHeight, root.maximumHeight - 8) : contentHeight)
            : root.barSize
        interactive: false
        clip: root.isOverflowing
        boundsBehavior: Flickable.StopAtBounds

        // Mouse wheel scroll when overflowing
        WheelHandler {
            enabled: root.isOverflowing
            onWheel: event => {
                const step = event.angleDelta.y * 0.6
                listView.contentY = Math.max(0,
                    Math.min(listView.contentHeight - listView.height,
                        listView.contentY - step))
            }
        }

        Behavior on implicitWidth {
            enabled: !root.vertical && Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on implicitHeight {
            enabled: root.vertical && Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        model: ScriptModel {
            objectProp: "uniqueId"
            values: root.visibleDockItems
        }

        delegate: BarTaskbarButton {
            id: taskbarDelegate
            required property var modelData
            required property int index
            appEntry: modelData
            taskbarRoot: root
            iconSize: root.iconSize
            vertical: root.vertical
            barSize: root.barSize
            barPosition: root.barPosition
        }
    }

    // ─── Preview popup (PopupWindow anchored to bar) ────────────────
    BarTaskbarPreview {
        id: previewPopup
        dockHovered: root.buttonHovered
        barPosition: root.barPosition
        anchor.window: root.parentWindow
    }
}
