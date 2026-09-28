pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.frame
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.pieces

Item {
    id: root
    property var screen: null
    anchors.fill: parent
    readonly property bool showLauncher: Config.options?.iris?.dock?.launcher ?? true
    readonly property var options: Config.options?.iris?.dock ?? ({})
    readonly property real d: IrisStyle.density
    readonly property real iconSize: Math.max(28, Math.min(64, Number(root.options?.iconSize ?? 40))) * root.d
    readonly property string edge: IrisFrame.dockEdge
    readonly property bool atTop: root.edge === "top"
    readonly property bool atBottom: root.edge === "bottom"
    readonly property bool atLeft: root.edge === "left"
    readonly property bool atRight: root.edge === "right"
    readonly property bool vertical: root.atLeft || root.atRight
    readonly property real thickness: root.iconSize + 10 * root.d
    readonly property int edgeOrigin: root.atTop ? Item.Top : root.atLeft ? Item.Left : root.atRight ? Item.Right : Item.Bottom
    function edgeX(span: real, size: real, margin: real): real {
        return Math.round(root.atLeft ? margin : root.atRight ? span - size - margin : (span - size) / 2)
    }
    function edgeY(span: real, size: real, margin: real): real {
        return Math.round(root.atTop ? margin : root.atBottom ? span - size - margin : (span - size) / 2)
    }
    function innerPoint(item: Item): point {
        const p = item.mapToItem(window, root.vertical ? (root.atLeft ? item.width : 0) : item.width / 2,
            root.vertical ? item.height / 2 : (root.atTop ? item.height : 0))
        return Qt.point(Math.round(p.x), Math.round(p.y))
    }
    readonly property bool notch: root.options?.notch ?? false
    readonly property bool autoHide: root.options?.autoHide ?? true
    readonly property bool reserveSpace: root.options?.reserveSpace ?? true
    readonly property bool magnify: (root.options?.magnification ?? true) && IrisStyle.motionEnabled
    readonly property bool badges: root.options?.badges ?? true
    readonly property bool revealOnEmpty: root.options?.revealOnEmpty ?? true
    readonly property var apps: TaskbarApps.apps
    readonly property var entries: {
        const list = root.apps.slice()
        while (list.length > 0 && list[0].appId === "SEPARATOR") list.shift()
        while (list.length > 0 && list[list.length - 1].appId === "SEPARATOR") list.pop()
        if (root.showLauncher && list.length > 0) list.unshift({ appId: "SEPARATOR" })
        return list
    }
    // Keyed by appId: TaskbarApps rebuilds entries on every window event.
    readonly property var liveApps: {
        const map = {}
        for (const app of root.entries) map[app.appId] = app
        return map
    }
    readonly property var notificationTimes: {
        const times = {}
        if (!root.badges) return times
        for (const notification of Notifications.list ?? []) {
            const key = Notifications._normalizeAppKey(notification?.appName)
            if (key.length > 0) (times[key] = times[key] ?? []).push(Number(notification?.time ?? 0))
        }
        return times
    }
    property var seenAt: ({})
    property real seenAllAt: Date.now()
    function identifiersFor(app): var {
        const entry = app?.appId ? AppSearch.lookupDesktopEntry(app.appId) : null
        return [app?.appId ?? "", entry?.name ?? "", String(entry?.id ?? "").replace(/\.desktop$/, "")]
    }
    function keysFor(identifiers): var {
        return identifiers.map(id => Notifications._normalizeAppKey(id)).filter(key => key.length > 0)
    }
    function markSeen(identifiers): void {
        const next = Object.assign({}, root.seenAt)
        const now = Date.now()
        for (const key of root.keysFor(identifiers)) next[key] = now
        root.seenAt = next
    }
    function badgeCount(identifiers): int {
        const keys = root.keysFor(identifiers)
        if (keys.some(key => root.focusedKeys.includes(key))) return 0
        const seen = Math.max(root.seenAllAt, ...keys.map(key => root.seenAt[key] ?? 0))
        for (const key of keys) {
            const count = (root.notificationTimes[key] ?? []).filter(time => time > seen).length
            if (count) return count
        }
        return 0
    }
    readonly property string focusedAppId: String(NiriService.activeWindow?.app_id ?? "")
    readonly property var focusedKeys: {
        if (root.focusedAppId.length === 0) return []
        const app = root.entries.find(entry => entry.appId === root.focusedAppId
            || Notifications._normalizeAppKey(entry.appId) === Notifications._normalizeAppKey(root.focusedAppId))
        return root.keysFor(app ? root.identifiersFor(app) : [root.focusedAppId])
    }
    property var previousFocusedKeys: []
    onFocusedKeysChanged: {
        if (root.previousFocusedKeys.length > 0) root.markSeen(root.previousFocusedKeys)
        root.previousFocusedKeys = root.focusedKeys
    }
    Connections {
        target: GlobalStates
        function onSidebarRightOpenChanged(): void { if (GlobalStates.sidebarRightOpen) root.seenAllAt = Date.now() }
        function onControlPanelOpenChanged(): void { if (GlobalStates.controlPanelOpen) root.seenAllAt = Date.now() }
    }
    readonly property real slotWidth: root.iconSize + 10 * root.d
    readonly property real separatorWidth: 13 * root.d
    readonly property real slotSpacing: 2 * root.d
    readonly property real magnifyGain: Math.max(0.1, Math.min(1, (Number(root.options?.magnifySize ?? 150) - 100) / 100))
    readonly property real iconOversample: root.magnify ? 1 + root.magnifyGain : 1
    Component.onCompleted: CompositorService.setSortingConsumer("irisDock", true)
    Component.onDestruction: CompositorService.setSortingConsumer("irisDock", false)

    readonly property var urgentWindowIds: (NiriService.windows ?? []).filter(w => w.is_urgent).map(w => w.id)
    function appUrgent(app): bool {
        return (app?.toplevels ?? []).some(t => t.niriWindowId !== undefined && root.urgentWindowIds.includes(t.niriWindowId))
    }

    function activate(app): bool {
        const windows = app.toplevels ?? []
        if (MinimizedWindows.countMinimizedForApp(app.appId) > 0) {
            MinimizedWindows.restoreLatestForApp(app.appId)
        } else if (windows.length > 0) {
            const current = CompositorService.isNiri
                ? windows.findIndex(window => window.niriWindowId !== undefined
                    && window.niriWindowId === (NiriService.activeWindow?.id ?? -1))
                : windows.findIndex(window => window.activated)
            const next = windows[(current + 1) % windows.length]
            if (CompositorService.isNiri && next.niriWindowId !== undefined)
                NiriService.focusWindow(next.niriWindowId)
            else next.activate()
        } else {
            const entry = AppSearch.lookupDesktopEntry(app.appId)
            if (entry) AppSearch.launchEntry(entry)
            return true
        }
        return false
    }

    readonly property var pieces: GlobalStates.irisAbsorbed?.[root.screen?.name ?? ""]?.dock ?? []
    signal pieceActivated(string slot, string kind, var rect)
    signal pieceMenuRequested(string slot, string kind, var rect, Item menu)
    readonly property alias menuOpen: window.menuOpen
    readonly property alias overFullscreen: window.overFullscreen
    readonly property alias inputOff: window.inputOff
    readonly property alias hitItem: hitArea
    readonly property alias bodyShape: window.bodyShape
    function closeMenu(): void { window.menuApp = null }

    Item {
            id: window
            property var menuApp: null
            property string menuMode: "menu"
            property Item menuIcon: null
            property point menuAnchorHold: Qt.point(0, 0)
            property var menuOriginHold: null
            readonly property point menuAnchor: {
                const icon = window.menuIcon
                void (icon?.x + icon?.y + icon?.width + icon?.height + icon?.scale
                    + appRow.x + appRow.width + window.width + window.height)
                if (!icon) return window.menuAnchorHold
                return root.innerPoint(icon)
            }
            readonly property var menuOriginRect: window.menuOriginHold
            readonly property real menuLeftClear: {
                if (!GlobalStates.sidebarLeftOpen || GlobalStates.sidebarLeftPresentationOutput !== (root.screen?.name ?? "")) return 12
                const o = Config.options?.iris?.sidebars?.left ?? ({})
                return IrisFrame.band + Math.max(300, Math.min(600, Number(o?.width ?? 380))) * root.d
                    + ((o?.notch ?? false) ? 0 : 12 * root.d) + 12
            }
            readonly property real menuRightClear: {
                if (!GlobalStates.sidebarRightOpen || GlobalStates.sidebarRightPresentationOutput !== (root.screen?.name ?? "")) return 12
                const o = Config.options?.iris?.sidebars?.right ?? ({})
                return IrisFrame.band + Math.max(300, Math.min(600, Number(o?.width ?? 380))) * root.d
                    + ((o?.notch ?? false) ? 0 : 12 * root.d) + 12
            }
            function captureMenuAnchor(icon: Item): void {
                window.menuIcon = icon
                if (!icon) return
                window.menuAnchorHold = root.innerPoint(icon)
                const bodyCentre = icon.mapToItem(window, icon.width / 2, icon.height / 2)
                const w = Math.round(root.slotWidth)
                window.menuOriginHold = root.vertical ? {
                    x: Math.round(dock.x), y: Math.round(bodyCentre.y - w / 2),
                    width: Math.round(dock.width), height: w,
                    radius: Math.min(dock.radius, Math.round(w / 2))
                } : {
                    x: Math.round(bodyCentre.x - w / 2), y: Math.round(dock.y),
                    width: w, height: Math.round(dock.height),
                    radius: Math.min(dock.radius, Math.round(w / 2))
                }
            }
            readonly property bool menuOpen: window.menuApp !== null
            readonly property real dockHeight: root.iconSize + 18 * root.d
            // Notch: the body rests on the band's inner line and melts into it.
            // Plain: it floats, keeping its own air above the band.
            readonly property real bodyAir: root.notch ? 0 : 10 * root.d
            readonly property real edgeGap: IrisFrame.band + window.bodyAir
            readonly property real headroom: root.magnify ? root.iconSize * root.magnifyGain + 30 * root.d : 30 * root.d
            readonly property string material: {
                const chosen = String(root.options?.material ?? "inherit")
                if (chosen !== "inherit") return chosen
                return (root.options?.blur ?? false) ? "blur" : "inherit"
            }
            readonly property var bodyGlass: ({ solid: "solid", glass: "wallpaper", blur: "compositor" })[window.material]
            property bool edgeIntent: false
            readonly property bool pointerOnDock: !window.inputOff && windowHover.hovered
                && windowHover.point.position.x >= hitArea.x
                && windowHover.point.position.x < hitArea.x + hitArea.width
                && windowHover.point.position.y >= hitArea.y
                && windowHover.point.position.y < hitArea.y + hitArea.height
            HoverHandler { id: windowHover }
            readonly property bool workspaceEmpty: {
                if (!root.revealOnEmpty || !CompositorService.isNiri) return false
                const active = (NiriService.allWorkspaces ?? []).find(ws => ws.output === root.screen?.name && ws.is_active)
                return active !== undefined && !(NiriService.windows ?? []).some(w => w.workspace_id === active.id)
            }
            readonly property bool editingDock: GlobalStates.irisEdit && GlobalStates.irisEditTarget === "dock"
            readonly property bool focusedOutput: (root.screen?.name ?? "") === (GlobalStates.focusedScreen?.name ?? "")
            readonly property bool askedShown: GlobalStates.irisDockShown && window.focusedOutput
            readonly property bool spotlightHere: GlobalStates.searchOpen && window.focusedOutput
            readonly property bool fullscreenCovered: CompositorService.isNiri
                && GameMode.hasFullscreenOnOutput(root.screen?.name ?? "")
                && !NiriService.inOverview
            readonly property bool overviewOverFullscreen: CompositorService.isNiri && NiriService.inOverview
                && GameMode.hasFullscreenOnOutput(root.screen?.name ?? "")
            readonly property bool overFullscreen: window.overviewOverFullscreen || (window.fullscreenCovered
                && (window.askedShown || window.menuOpen || window.editingDock))
            readonly property bool fullscreenIdle: window.fullscreenCovered && !window.overFullscreen
            readonly property bool stepAside: GlobalStates.widgetEditMode || (GlobalStates.irisEdit && !window.editingDock)
            onStepAsideChanged: if (window.stepAside) window.menuApp = null
            readonly property bool revealed: !window.fullscreenIdle && !window.stepAside && (!root.autoHide || window.edgeIntent || window.menuOpen
                || window.askedShown || window.spotlightHere || window.workspaceEmpty || window.editingDock)
            onPointerOnDockChanged: {
                if (window.pointerOnDock) {
                    hideDelay.stop()
                    if (!window.edgeIntent) revealDwell.restart()
                } else {
                    revealDwell.stop()
                    if (!window.menuOpen) hideDelay.restart()
                }
            }
            Timer { id: revealDwell; interval: 110; onTriggered: window.edgeIntent = true }
            Timer { id: hideDelay; interval: 420; onTriggered: if (!window.pointerOnDock && !window.menuOpen) window.edgeIntent = false }
            onMenuOpenChanged: {
                if (window.menuOpen) return
                if (!window.pointerOnDock) hideDelay.restart()
            }

            visible: !GlobalStates.screenLocked
            width: root.width
            height: root.vertical ? root.height : window.implicitHeight
            y: root.vertical || root.atTop ? 0 : root.height - window.height
            readonly property real frameInset: 0
            readonly property real screenOffsetY: window.y
            readonly property real menuReserve: Math.round(Math.min((root.screen?.height ?? 1080) * 0.55, 460 * root.d))
            implicitHeight: window.dockHeight + window.edgeGap + window.headroom + window.menuReserve
            readonly property bool inputOff: window.fullscreenIdle || window.stepAside
            MouseArea {
                anchors.fill: parent
                z: -100
                enabled: window.menuOpen
                acceptedButtons: Qt.AllButtons
                onPressed: window.menuApp = null
            }

            Shortcut { sequence: "Escape"; enabled: window.menuOpen; onActivated: window.menuApp = null }
            Connections {
                target: GlobalStates
                function onIrisDockMenuRequestChanged(): void {
                    if (GlobalStates.irisDockMenuRequest?.mode !== "close") return
                    GlobalStates.irisDockMenuRequest = null
                    window.menuApp = null
                }
            }

            property real edgeOffset: window.revealed ? window.edgeGap : -(window.dockHeight + 6 * root.d)
            Behavior on edgeOffset { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }

            Item {
                id: hitArea
                readonly property real depth: !window.revealed ? 2
                    : Math.max(2, window.dockHeight + window.edgeOffset
                        + (root.magnify && !window.menuOpen ? root.iconSize * root.magnifyGain + 4 * root.d : 0))
                readonly property real span: (root.vertical ? dock.height : dock.width) + (window.revealed ? 0 : 40 * root.d)
                x: root.vertical ? (root.atLeft ? 0 : window.width - hitArea.depth) : Math.round((window.width - hitArea.span) / 2)
                y: root.vertical ? Math.round((window.height - hitArea.span) / 2) : (root.atTop ? 0 : window.height - hitArea.depth)
                width: root.vertical ? hitArea.depth : hitArea.span
                height: root.vertical ? hitArea.span : hitArea.depth
            }

            property var frozenSlotX: null
            readonly property var pointerSlotX: {
                if (window.menuOpen) return window.frozenSlotX
                if (!root.magnify || !window.pointerOnDock || !window.revealed) return null
                const x = root.vertical ? windowHover.point.position.y - (window.height - dock.baseWidth) / 2
                    : windowHover.point.position.x - (window.width - dock.baseWidth) / 2
                if (x < -root.slotWidth || x > dock.baseWidth + root.slotWidth) return null
                return x - dock.padding
            }
            readonly property var baseCenters: {
                const centers = []
                let x = 0
                const all = (root.showLauncher ? [{ appId: "__launcher" }] : []).concat(root.entries,
                    root.pieces.length > 0 ? [{ appId: "SEPARATOR" }].concat(root.pieces.map(piece => ({ appId: "__piece" }))) : [])
                for (let i = 0; i < all.length; i++) {
                    const w = all[i].appId === "SEPARATOR" ? root.separatorWidth : root.slotWidth
                    centers.push(x + w / 2)
                    x += w + root.slotSpacing
                }
                return centers
            }
            function magnification(index: int): real {
                if (window.pointerSlotX === null) return 0
                const distance = Math.abs((window.baseCenters[index] ?? 0) - window.pointerSlotX)
                const range = root.slotWidth * 2.6
                if (distance >= range) return 0
                return (Math.cos(Math.PI * distance / range) + 1) / 2
            }

            readonly property var bodyShape: {
                void (dock.x + dock.y + dock.width + dock.height + dock.radius
                    + window.edgeOffset + window.width + window.height + window.screenOffsetY
                    + menu.progress + menu.bodyRect.x + menu.bodyRect.y + menu.bodyRect.width + menu.bodyRect.height)
                if (dock.opacity <= 0.01) return null
                const p = dock.mapToItem(window, 0, 0)
                const screenW = root.screen?.width ?? window.width
                const screenH = root.screen?.height ?? 0
                const attached = root.notch && IrisFrame.band > 0 ? IrisFrame.band : 0
                const out = []
                // Without the Surround band there is nothing on the edge to melt
                // into, so the notch carries its own edge, as the Island does.
                if (root.notch && !IrisFrame.framed) {
                    const deep = Math.max(8, IrisStyle.fuseDeep * 2)
                    out.push(root.vertical ? { x: root.atLeft ? -deep - 1 : screenW + 1, y: -2 * IrisStyle.fuseDeep,
                        width: deep, height: screenH + 4 * IrisStyle.fuseDeep,
                        radius: 0, paints: true, fuse: IrisStyle.fuseDeep, id: "dockEdge", glass: window.bodyGlass }
                    : { x: -2 * IrisStyle.fuseDeep,
                        y: root.atTop ? -deep - 1 : screenH + 1,
                        width: screenW + 4 * IrisStyle.fuseDeep, height: deep,
                        radius: 0, paints: true, fuse: IrisStyle.fuseDeep, id: "dockEdge", glass: window.bodyGlass })
                }
                out.push({
                    x: Math.round(p.x + (root.atLeft ? -attached : 0)),
                    y: Math.round(p.y + window.screenOffsetY + (root.atTop ? -attached : 0)),
                    width: Math.round(dock.width + (root.vertical ? attached : 0)),
                    height: Math.round(dock.height + (root.vertical ? 0 : attached)),
                    radius: dock.radius, paints: true,
                    fuse: root.notch ? Math.round(IrisStyle.fuseEdge * window.notchReveal) : IrisStyle.fuse,
                    id: "dock", joins: !root.notch ? "" : IrisFrame.framed ? "frame" : "dockEdge", glass: window.bodyGlass
                })
                const menuBody = menu.bodyRect
                if (menu.progress > 0.01 && menuBody.width > 1 && menuBody.height > 1)
                    out.push({
                        x: Math.round(menuBody.x), y: Math.round(menuBody.y + window.screenOffsetY),
                        width: Math.round(menuBody.width), height: Math.round(menuBody.height),
                        radius: menuBody.radius, paints: true, fuse: IrisStyle.fuseDeep,
                        id: "dockMenu", joins: "dock", glass: window.bodyGlass
                    })
                return out
            }
            function publishBody(): void {
                const name = root.screen?.name ?? ""
                if (name.length === 0) return
                const bodies = Object.assign({}, GlobalStates.irisDockBody ?? {})
                bodies[name] = window.bodyShape
                GlobalStates.irisDockBody = bodies
            }
            onBodyShapeChanged: window.publishBody()
            Component.onCompleted: window.publishBody()
            Component.onDestruction: {
                const name = root.screen?.name ?? ""
                if (name.length === 0) return
                const bodies = Object.assign({}, GlobalStates.irisDockBody ?? {})
                bodies[name] = null
                GlobalStates.irisDockBody = bodies
            }

            readonly property real notchReveal: Math.max(0, Math.min(1, (window.edgeOffset + window.dockHeight) / window.dockHeight))
            IrisSurface {
                id: dock
                readonly property real padding: 8 * root.d
                readonly property real baseWidth: (window.baseCenters.length > 0
                    ? window.baseCenters[window.baseCenters.length - 1] + root.slotWidth / 2 : 0) + dock.padding * 2
                width: root.vertical ? window.dockHeight : Math.min(window.width - 32, appRow.implicitWidth + dock.padding * 2)
                height: root.vertical ? Math.min(window.height - 32, appRow.implicitHeight + dock.padding * 2) : window.dockHeight
                x: root.vertical ? (root.atLeft ? window.edgeOffset : window.width - width - window.edgeOffset)
                    : Math.round((window.width - width) / 2)
                y: root.vertical ? Math.round((window.height - height) / 2)
                    : root.atTop ? window.edgeOffset : window.height - height - window.edgeOffset
                readonly property real thickness: root.vertical ? width : height
                radius: root.notch ? dock.thickness / 2 : IrisStyle.pieceRadius(dock.thickness)
                quiet: true
                opacity: window.revealed || window.edgeOffset > -window.dockHeight ? 1 : 0

                Item {
                    id: dockResize
                    z: 30
                    visible: window.editingDock
                    width: Math.round((root.vertical ? 14 : 44) * root.d)
                    height: Math.round((root.vertical ? 44 : 14) * root.d)
                    x: root.vertical ? (root.atLeft ? parent.width - width : 0) : Math.round((parent.width - width) / 2)
                    y: root.vertical ? Math.round((parent.height - height) / 2) : (root.atTop ? parent.height - height : 0)
                    Rectangle {
                        anchors.centerIn: parent
                        width: root.vertical ? Math.max(2, Math.round(3 * root.d)) : Math.round(24 * root.d)
                        height: root.vertical ? Math.round(24 * root.d) : Math.max(2, Math.round(3 * root.d))
                        radius: Math.min(width, height) / 2
                        color: dockResizeHover.hovered || dockResizeDrag.active ? IrisStyle.accent : IrisStyle.textTertiary
                    }
                    HoverHandler { id: dockResizeHover; cursorShape: root.vertical ? Qt.SizeHorCursor : Qt.SizeVerCursor }
                    DragHandler {
                        id: dockResizeDrag
                        target: null
                        xAxis.enabled: root.vertical
                        yAxis.enabled: !root.vertical
                        property real startSize: 40
                        property IrisConfigDrag write: IrisConfigDrag { path: "iris.dock.iconSize" }
                        onActiveChanged: {
                            if (active) dockResizeDrag.startSize = Number(Config.options?.iris?.dock?.iconSize ?? 40)
                            else dockResizeDrag.write.flush()
                        }
                        onTranslationChanged: {
                            if (!active) return
                            const outward = root.vertical ? (root.atLeft ? translation.x : -translation.x)
                                : (root.atTop ? translation.y : -translation.y)
                            const delta = outward / Math.max(0.01, root.d)
                            dockResizeDrag.write.push(Math.round(Math.max(28, Math.min(64, dockResizeDrag.startSize + delta))))
                        }
                    }
                }

                Grid {
                    id: appRow
                    columns: root.vertical ? 1 : Math.max(1, root.entries.length + (root.showLauncher ? 1 : 0)
                        + (root.pieces.length > 0 ? root.pieces.length + 1 : 0))
                    flow: root.vertical ? Grid.TopToBottom : Grid.LeftToRight
                    x: root.vertical ? (root.atLeft ? Math.round(4 * root.d) : parent.width - width - Math.round(4 * root.d)) : dock.padding
                    y: root.vertical ? dock.padding : (root.atTop ? Math.round(4 * root.d) : parent.height - height - Math.round(4 * root.d))
                    spacing: root.slotSpacing

                    component Slot: Item {
                        id: slot
                        required property int slotIndex
                        readonly property real mag: window.magnification(slot.slotIndex)
                        property real grow: slot.mag
                        Behavior on grow { NumberAnimation { duration: IrisStyle.duration(70); easing.type: IrisStyle.feedbackEasing } }
                        readonly property real iconScale: 1 + root.magnifyGain * slot.grow
                        readonly property real along: root.slotWidth + root.iconSize * root.magnifyGain * slot.grow
                        readonly property real outward: root.iconSize * root.magnifyGain * slot.grow
                        width: root.vertical ? root.thickness : slot.along
                        height: root.vertical ? slot.along : root.thickness
                    }

                    Slot {
                        id: launcherSlot
                        visible: root.showLauncher
                        slotIndex: 0
                        MouseArea {
                            id: launcherArea
                            anchors.fill: parent
                            anchors.topMargin: root.atBottom ? -launcherSlot.outward : 0
                            anchors.bottomMargin: root.atTop ? -launcherSlot.outward : 0
                            anchors.leftMargin: root.atRight ? -launcherSlot.outward : 0
                            anchors.rightMargin: root.atLeft ? -launcherSlot.outward : 0
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: Translation.tr("Applications")
                            onClicked: {
                                if (GlobalStates.irisEdit) {
                                    GlobalStates.irisEditSelection = ""
                                    GlobalStates.irisEditTarget = "dock"
                                    return
                                }
                                GlobalStates.searchOpen = !GlobalStates.searchOpen
                            }
                            onContainsMouseChanged: nameLabel.present(containsMouse ? launcherSlot : null, Translation.tr("Applications"))
                            Item {
                                id: launcherGlyph
                                x: root.edgeX(parent.width, width, 7 * root.d + (root.iconSize - root.iconSize * 0.9) / 2)
                                y: root.edgeY(parent.height, height, 7 * root.d + (root.iconSize - root.iconSize * 0.9) / 2)
                                width: Math.round(root.iconSize * 0.9 * launcherSlot.iconScale * (launcherArea.pressed ? IrisStyle.pressScale(0.92) : 1))
                                height: width
                                Grid {
                                    id: launcherDots
                                    anchors.centerIn: parent
                                    visible: !window.spotlightHere
                                    readonly property real dot: Math.max(3, Math.round(launcherGlyph.width * 0.11))
                                    columns: 3
                                    spacing: Math.round(launcherGlyph.width * 0.1)
                                    Repeater {
                                        model: 9
                                        Rectangle {
                                            width: launcherDots.dot
                                            height: width
                                            radius: width / 2
                                            color: (launcherArea.containsMouse ? IrisStyle.text : IrisStyle.textStrong)
                                            Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                                        }
                                    }
                                }
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    visible: window.spotlightHere
                                    text: "close"
                                    iconSize: launcherGlyph.width * 0.5
                                    color: IrisStyle.text
                                }
                            }
                        }
                    }

                    Repeater {
                        model: ScriptModel {
                            objectProp: "appId"
                            values: root.entries
                        }
                        Item {
                            id: entry
                            required property var modelData
                            required property int index
                            readonly property var app: root.liveApps[entry.modelData.appId] ?? entry.modelData
                            readonly property bool separator: entry.modelData.appId === "SEPARATOR"
                            width: root.vertical ? root.thickness : entry.separator ? root.separatorWidth : appSlot.width
                            height: root.vertical ? (entry.separator ? root.separatorWidth : appSlot.height) : root.thickness

                            Connections {
                                target: GlobalStates
                                enabled: !entry.separator
                                function onIrisDockMenuRequestChanged(): void {
                                    const request = GlobalStates.irisDockMenuRequest
                                    if (!request || request.appId !== entry.modelData.appId
                                        || root.screen?.name !== GlobalStates.focusedScreen?.name) return
                                    GlobalStates.irisDockMenuRequest = null
                                    GlobalStates.irisDockShown = true
                                    window.captureMenuAnchor(appIcon)
                                    window.menuMode = request.mode === "menu" ? "menu" : "windows"
                                    window.menuApp = entry.app
                                }
                            }

                            Rectangle {
                                visible: entry.separator
                                anchors.centerIn: parent
                                width: root.vertical ? Math.round(root.iconSize * 0.56) : Math.max(1, Math.round(IrisStyle.density))
                                height: root.vertical ? Math.max(1, Math.round(IrisStyle.density)) : Math.round(root.iconSize * 0.56)
                                radius: width / 2
                                color: IrisStyle.borderStrong
                            }

                            Slot {
                                id: appSlot
                                visible: !entry.separator
                                slotIndex: entry.index + (root.showLauncher ? 1 : 0)
                                readonly property var desktopEntry: entry.separator ? null : AppSearch.lookupDesktopEntry(entry.modelData.appId)
                                readonly property string appName: appSlot.desktopEntry?.name ?? entry.modelData.appId
                                readonly property bool running: (entry.app.toplevels?.length ?? 0) > 0
                                readonly property bool focused: (entry.app.toplevels ?? []).some(t => CompositorService.isNiri
                                    ? t.niriWindowId !== undefined && t.niriWindowId === (NiriService.activeWindow?.id ?? -1)
                                    : t.activated)
                                property real lift: 0
                                readonly property string pieceId: IrisPieces.appPieceId(entry.modelData.appId)
                                readonly property bool carried: GlobalStates.irisBubbleDrag?.slot === appSlot.pieceId
                                function primary(): void {
                                    if (GlobalStates.irisEdit) {
                                        GlobalStates.irisEditTarget = ""
                                        GlobalStates.irisEditSelection = appSlot.pieceId
                                        return
                                    }
                                    if ((entry.app.toplevels?.length ?? 0) > 1) {
                                        if (window.menuOpen && window.menuMode === "windows"
                                            && window.menuApp?.appId === entry.modelData.appId) {
                                            window.menuApp = null
                                            return
                                        }
                                        window.frozenSlotX = window.pointerSlotX
                                        window.captureMenuAnchor(appIcon)
                                        window.menuMode = "windows"
                                        window.menuApp = entry.app
                                        nameLabel.present(null, "")
                                        return
                                    }
                                    if (window.menuOpen) window.menuApp = null
                                    GlobalStates.irisDockShown = false
                                    if (root.activate(entry.app) && IrisStyle.motionEnabled) launchBounce.restart()
                                }

                                SequentialAnimation {
                                    id: launchBounce
                                    loops: 2
                                    // A hop under gravity: slowing up, speeding down, and no ball-bounce on landing.
                                    NumberAnimation { target: appSlot; property: "lift"; to: 14 * root.d; duration: IrisStyle.duration(240); easing.type: Easing.OutQuad }
                                    NumberAnimation { target: appSlot; property: "lift"; to: 0; duration: IrisStyle.duration(240); easing.type: Easing.InQuad }
                                }

                                IrisButton {
                                    id: appButton
                                    anchors.fill: parent
                                    anchors.topMargin: root.atBottom ? -appSlot.outward : 0
                                    anchors.bottomMargin: root.atTop ? -appSlot.outward : 0
                                    anchors.leftMargin: root.atRight ? -appSlot.outward : 0
                                    anchors.rightMargin: root.atLeft ? -appSlot.outward : 0
                                    pressScaleEnabled: false
                                    quiet: true
                                    colBackgroundHover: "transparent"
                                    Accessible.name: appSlot.appName
                                    onHoveredChanged: nameLabel.present(hovered ? appSlot : null, appSlot.appName, entry.app.toplevels?.length ?? 0)
                                    onClicked: appSlot.primary()
                                    middleClickAction: () => {
                                        const e = AppSearch.lookupDesktopEntry(entry.modelData.appId)
                                        if (e) AppSearch.launchEntry(e)
                                        if (IrisStyle.motionEnabled) launchBounce.restart()
                                    }
                                    altAction: () => {
                                        window.frozenSlotX = window.pointerSlotX
                                        window.captureMenuAnchor(appIcon)
                                        window.menuMode = "menu"
                                        window.menuApp = entry.app
                                        nameLabel.present(null, "")
                                    }
                                    WheelHandler {
                                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                        property real accumulated: 0
                                        onWheel: wheel => {
                                            const windows = entry.app.toplevels ?? []
                                            if (windows.length < 2) return
                                            accumulated += wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y * 4
                                            while (Math.abs(accumulated) >= 120) {
                                                const direction = accumulated > 0 ? -1 : 1
                                                accumulated += direction * 120
                                                const current = Math.max(0, windows.findIndex(t => t.activated))
                                                const next = windows[(current + direction + windows.length) % windows.length]
                                                if (CompositorService.isNiri && next.niriWindowId !== undefined) NiriService.focusWindow(next.niriWindowId)
                                                else next.activate()
                                            }
                                        }
                                    }
                                    readonly property real iconMargin: 7 * root.d + appSlot.lift + appIcon.hoverLift
                                    readonly property real iconVisual: root.iconSize * appSlot.iconScale
                                    readonly property Item iconHost: appIcon.parent
                                    readonly property point iconCentre: Qt.point(
                                        root.edgeX(appButton.iconHost?.width ?? 0, appButton.iconVisual, appButton.iconMargin) + appButton.iconVisual / 2,
                                        root.edgeY(appButton.iconHost?.height ?? 0, appButton.iconVisual, appButton.iconMargin) + appButton.iconVisual / 2)
                                    readonly property point iconCentreInSlot: {
                                        const host = appButton.iconHost
                                        void (host?.x + host?.y + host?.width + host?.height + appButton.x + appButton.y + appButton.width + appButton.height)
                                        return host ? host.mapToItem(appSlot, appButton.iconCentre.x, appButton.iconCentre.y) : Qt.point(appSlot.width / 2, appSlot.height / 2)
                                    }
                                    Rectangle {
                                        visible: !root.magnify
                                        x: Math.round(appButton.iconCentre.x - width / 2)
                                        y: Math.round(appButton.iconCentre.y - height / 2)
                                        width: root.iconSize + 8 * root.d
                                        height: width
                                        radius: IrisStyle.iconRadius(width)
                                        color: (appButton.hovered || appButton.down ? IrisStyle.fill : ColorUtils.applyAlpha(IrisStyle.text, 0))
                                        Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                                    }
                                    SmartAppIcon {
                                        id: appIcon
                                        property real hoverLift: !root.magnify && appButton.hovered ? 2 * root.d : 0
                                        Behavior on hoverLift { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                                        width: iconSize
                                        height: iconSize
                                        x: root.edgeX(parent.width, width, appButton.iconMargin)
                                        y: root.edgeY(parent.height, height, appButton.iconMargin)
                                        transformOrigin: root.edgeOrigin
                                        icon: entry.separator ? "" : IrisPieces.appIcon(entry.modelData.appId)
                                        fallback: "application-x-executable"
                                        iconSize: Math.round(root.iconSize)
                                        readonly property real press: appButton.down || appGrip.pressed ? IrisStyle.pressScale(0.92) : 1
                                        scale: appSlot.iconScale * press
                                        visible: !largeIcon.visible
                                        opacity: appSlot.carried ? 0 : 1
                                        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                                    }
                                    SmartAppIcon {
                                        id: largeIcon
                                        visible: root.magnify && appSlot.grow > 0.02
                                        width: iconSize
                                        height: iconSize
                                        x: root.edgeX(parent.width, width, appButton.iconMargin)
                                        y: root.edgeY(parent.height, height, appButton.iconMargin)
                                        transformOrigin: root.edgeOrigin
                                        icon: appIcon.icon
                                        fallback: "application-x-executable"
                                        iconSize: root.magnify ? Math.round(root.iconSize * root.iconOversample) : 1
                                        scale: appSlot.iconScale * appIcon.press / root.iconOversample
                                        layer.enabled: root.magnify
                                        layer.smooth: true
                                        layer.mipmap: true
                                        opacity: appIcon.opacity
                                    }
                                    IrisBubbleGrip {
                                        id: appGrip
                                        x: Math.round(appButton.iconCentre.x - width / 2)
                                        y: Math.round(appButton.iconCentre.y - height / 2)
                                        width: root.iconSize + 8 * root.d
                                        height: width
                                        slot: appSlot.pieceId
                                        kind: "app"
                                        screenName: root.screen?.name ?? ""
                                        screenOffsetY: 0
                                        holdLifts: false
                                        pullDirection: GlobalStates.irisEdit ? 0 : (root.atTop || root.atLeft ? 1 : -1)
                                        pullAcross: root.vertical
                                        pullDistance: GlobalStates.irisEdit ? 6 * root.d : root.iconSize * 0.7
                                        enabled: !entry.separator && !window.menuOpen
                                            && !IrisPieces.appFloating(entry.modelData.appId)
                                        onTapped: appSlot.primary()
                                    }
                                }
                                IrisBadge {
                                    count: root.badgeCount([entry.modelData.appId, appSlot.appName,
                                        String(appSlot.desktopEntry?.id ?? "").replace(/\.desktop$/, "")])
                                    parent: appButton
                                    z: 2
                                    readonly property point corner: {
                                        void (appIcon.x + appIcon.y + appIcon.width + appIcon.scale + appButton.width + appButton.height)
                                        return appIcon.mapToItem(appButton, appIcon.width, 0)
                                    }
                                    x: Math.round(corner.x - width * 0.7)
                                    y: Math.round(corner.y - height * 0.3)
                                    size: 2 * Math.round(9 * root.d * appSlot.iconScale)
                                    opacity: appIcon.opacity
                                }
                                Grid {
                                    id: indicators
                                    columns: root.vertical ? 1 : Math.max(1, indicators.windows)
                                    readonly property int windows: Math.min(3, entry.app.toplevels?.length ?? 0)
                                    readonly property int focusedIndex: {
                                        if (!appSlot.focused) return -1
                                        const id = NiriService.activeWindow?.id ?? -1
                                        const index = (entry.app.toplevels ?? []).findIndex(t => CompositorService.isNiri ? t.niriWindowId === id : t.activated)
                                        return Math.min(indicators.windows - 1, Math.max(0, index))
                                    }
                                    readonly property bool minimizedOnly: appSlot.running
                                        && MinimizedWindows.countMinimizedForApp(entry.modelData.appId) >= (entry.app.toplevels?.length ?? 0)
                                    readonly property bool urgent: root.appUrgent(entry.app)
                                    x: Math.round(root.atLeft ? 0 : root.atRight ? appSlot.width - width
                                        : appButton.iconCentreInSlot.x - width / 2)
                                    y: Math.round(root.atTop ? 0 : root.atBottom ? appSlot.height - height
                                        : appButton.iconCentreInSlot.y - height / 2)
                                    spacing: Math.max(1, Math.round(2.5 * root.d))
                                    visible: windows > 0
                                    Repeater {
                                        model: indicators.windows
                                        Rectangle {
                                            id: indicator
                                            required property int index
                                            readonly property bool lead: indicator.index === indicators.focusedIndex
                                            readonly property real dot: 2 * Math.max(1, Math.round(2 * root.d))
                                            property real along: indicator.lead ? 2 * Math.round(6 * root.d) : indicator.dot
                                            height: root.vertical ? Math.round(indicator.along) : indicator.dot
                                            width: root.vertical ? indicator.dot : Math.round(indicator.along)
                                            antialiasing: true
                                            radius: Math.min(width, height) / 2
                                            color: indicators.minimizedOnly ? "transparent"
                                                : indicators.urgent ? IrisStyle.secondaryAccent
                                                : indicator.lead ? IrisStyle.text : (appSlot.focused ? IrisStyle.textSecondary : IrisStyle.textTertiary)
                                            border.width: indicators.minimizedOnly ? Math.max(1, Math.round(1.2 * root.d)) : 0
                                            border.color: IrisStyle.textSecondary
                                            Behavior on along { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                                            Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                                            SequentialAnimation on opacity {
                                                running: indicators.urgent && IrisStyle.motionEnabled && indicator.visible
                                                loops: Animation.Infinite
                                                NumberAnimation { to: 0.35; duration: 650; easing.type: Easing.InOutSine }
                                                NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
                                                onRunningChanged: if (!running) indicator.opacity = 1
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        visible: root.pieces.length > 0
                        width: root.vertical ? root.thickness : root.separatorWidth
                        height: root.vertical ? root.separatorWidth : root.thickness
                        Rectangle {
                            anchors.centerIn: parent
                            width: root.vertical ? Math.round(root.iconSize * 0.56) : Math.max(1, Math.round(IrisStyle.density))
                            height: root.vertical ? Math.max(1, Math.round(IrisStyle.density)) : Math.round(root.iconSize * 0.56)
                            radius: Math.min(width, height) / 2
                            color: IrisStyle.borderStrong
                        }
                    }

                    Repeater {
                        model: root.pieces
                        delegate: Slot {
                            id: pieceSlot
                            required property var modelData
                            required property int index
                            slotIndex: (root.showLauncher ? 1 : 0) + root.entries.length + 1 + pieceSlot.index
                            readonly property string label: Translation.tr(IrisPieces.labelOf(pieceSlot.modelData.kind))
                            function rect(): var {
                                const p = pieceFace.mapToItem(null, 0, 0)
                                const size = pieceFace.width * pieceFace.scale
                                return { x: p.x, y: p.y, size: size, source: "dock-" + pieceSlot.modelData.slot }
                            }
                            Rectangle {
                                visible: !root.magnify
                                anchors.centerIn: pieceFace
                                width: root.iconSize + 8 * root.d
                                height: width
                                radius: width / 2
                                color: pieceHover.hovered || pieceTap.pressed ? IrisStyle.fill : ColorUtils.applyAlpha(IrisStyle.text, 0)
                                Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                            }
                            IrisBubbleFace {
                                id: pieceFace
                                width: Math.round(root.iconSize * 0.92)
                                height: width
                                x: Math.round(root.atLeft ? 7 * root.d + (root.iconSize - width) / 2
                                    : root.atRight ? pieceSlot.width - width - 7 * root.d - (root.iconSize - width) / 2
                                    : (pieceSlot.width - width) / 2)
                                y: Math.round(root.atTop ? 7 * root.d + (root.iconSize - height) / 2
                                    : root.atBottom ? pieceSlot.height - height - 7 * root.d - (root.iconSize - height) / 2
                                    : (pieceSlot.height - height) / 2)
                                transformOrigin: root.edgeOrigin
                                scale: pieceSlot.iconScale * (pieceTap.pressed ? IrisStyle.pressScale(0.92) : 1)
                                screenName: root.screen?.name ?? ""
                                kind: pieceSlot.modelData.kind
                                plated: true
                                hovered: pieceHover.hovered
                                pressed: pieceTap.pressed
                            }
                            HoverHandler {
                                id: pieceHover
                                cursorShape: Qt.PointingHandCursor
                                onHoveredChanged: nameLabel.present(pieceHover.hovered ? pieceSlot : null, pieceSlot.label)
                            }
                            TapHandler {
                                id: pieceTap
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onTapped: (point, button) => {
                                    nameLabel.present(null, "")
                                    if (button === Qt.RightButton) {
                                        root.pieceMenuRequested(pieceSlot.modelData.slot, pieceSlot.modelData.kind, pieceSlot.rect(), pieceMenu)
                                        return
                                    }
                                    if (GlobalStates.irisEdit) {
                                        GlobalStates.irisEditTarget = ""
                                        GlobalStates.irisEditSelection = pieceSlot.modelData.slot.startsWith("extra-")
                                            ? "extra:" + pieceSlot.modelData.slot.slice(6) : pieceSlot.modelData.slot
                                        return
                                    }
                                    root.pieceActivated(pieceSlot.modelData.slot, pieceSlot.modelData.kind, pieceSlot.rect())
                                }
                            }
                            WheelHandler {
                                enabled: pieceSlot.modelData.kind === "sound" || pieceSlot.modelData.kind === "mic"
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                property real accumulated: 0
                                onWheel: event => {
                                    accumulated += event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y * 4
                                    const steps = Math.trunc(accumulated / 120)
                                    if (steps === 0) return
                                    accumulated -= steps * 120
                                    GlobalStates.quietIrisLevels()
                                    if (pieceSlot.modelData.kind === "mic") Audio.setSourceVolume(Math.max(0, Math.min(1, (Audio.micVolume ?? 0) + steps * 0.05)))
                                    else Audio.setSinkVolume(Math.max(0, Math.min(Math.max(1, Audio.ceiling), (Audio.value ?? 0) + steps * 0.05)))
                                }
                            }
                            IrisDesktopMenu {
                                id: pieceMenu
                                anchorItem: pieceFace
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: pieceSlot.label
                        }
                    }
                }
            }

            IrisSurface {
                id: nameLabel
                property Item target: null
                property string label: ""
                property bool shown: false
                function present(item, text, count): void {
                    if (item) { nameLabel.target = item; nameLabel.label = text; nameLabel.windowCount = count ?? 0; labelDelay.restart() }
                    else if (nameLabel.target) { labelDelay.stop(); nameLabel.shown = false }
                }
                Timer { id: labelDelay; interval: 380; onTriggered: nameLabel.shown = true }
                readonly property point anchorPoint: {
                    void (dock.x + dock.y + dock.width + dock.height)
                    return nameLabel.target ? nameLabel.target.mapToItem(window, nameLabel.target.width / 2, nameLabel.target.height / 2) : Qt.point(0, 0)
                }
                visible: opacity > 0.01
                opacity: nameLabel.shown && !window.menuOpen && window.revealed ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                width: labelText.implicitWidth + 22 * root.d
                height: Math.round(28 * root.d)
                radius: height / 2
                readonly property real targetLift: root.iconSize * root.magnifyGain * (nameLabel.target?.grow ?? 0)
                x: root.atLeft ? dock.x + dock.width + 8 * root.d + nameLabel.targetLift
                    : root.atRight ? dock.x - width - 8 * root.d - nameLabel.targetLift
                    : Math.max(8, Math.min(window.width - width - 8, nameLabel.anchorPoint.x - width / 2))
                y: root.vertical ? Math.round(nameLabel.anchorPoint.y - height / 2)
                    : root.atTop ? dock.y + dock.height + 8 * root.d + nameLabel.targetLift
                    : dock.y - height - 8 * root.d - nameLabel.targetLift
                property int windowCount: 0
                Row {
                    id: labelText
                    anchors.centerIn: parent
                    spacing: 6 * root.d
                    IrisText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: nameLabel.label
                        width: Math.min(implicitWidth, Math.round(260 * root.d))
                        elide: Text.ElideRight
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.DemiBold)
                    }
                    IrisText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: nameLabel.windowCount > 1
                        text: nameLabel.windowCount
                        color: IrisStyle.secondaryAccent
                        font.pixelSize: IrisStyle.typeMeta
                        font.weight: IrisStyle.weight(Font.Bold)
                        font.family: IrisStyle.fontNumbers
                        font.features: ({ "tnum": 1 })
                    }
                }
            }

            IrisMorphSurface {
                id: menu
                z: -1
                open: window.menuOpen
                motionSurface: "menus"
                origin: window.menuOriginRect
                light: menu.mode === "windows" ? "transparent" : IrisStyle.surfaceLight("menus", IrisStyle.wallpaperLight)
                lightFrom: root.edge
                readonly property Item activeContent: menu.mode === "windows" ? windowsContent : menuContent
                contentReady: menu.activeContent.implicitHeight > 0
                radius: IrisStyle.surfaceRadius("menus", menu.mode === "windows" ? IrisStyle.radiusSheet : IrisStyle.radiusCard)
                color: IrisStyle.bodySurface
                fieldBacked: true
                animationDuration: IrisStyle.morphDuration
                width: menu.mode === "windows"
                    ? Math.round(Math.min(window.width - 24, windowsContent.implicitWidth + 20 * root.d))
                    : Math.round(Math.min(Math.max(200 * root.d, menuContent.implicitWidth + 12 * root.d), 260 * root.d))
                height: Math.round(menu.activeContent.implicitHeight + (menu.mode === "windows" ? 20 : 12) * root.d)
                readonly property real topClear: IrisFrame.safeInset("top") + 8 * root.d
                readonly property real bottomClear: IrisFrame.safeInset("bottom") + 8 * root.d
                x: Math.round(root.atLeft ? dock.x + dock.width + 8 * root.d
                    : root.atRight ? dock.x - width - 8 * root.d
                    : Math.max(window.menuLeftClear, Math.min(window.width - width - window.menuRightClear, window.menuAnchor.x - width / 2)))
                y: Math.round(root.vertical
                    ? Math.max(menu.topClear, Math.min(window.height - height - menu.bottomClear, window.menuAnchor.y - height / 2))
                    : root.atTop ? window.menuAnchor.y + 8 * root.d : window.menuAnchor.y - height - 8 * root.d)
                visible: progress > 0
                onClosed: {
                    if (!window.menuOpen) {
                        menu.app = null
                        menu.windows = []
                        window.menuIcon = null
                        window.menuOriginHold = null
                        window.menuAnchorHold = Qt.point(0, 0)
                        window.frozenSlotX = null
                    }
                }
                property var app: null
                property var windows: []
                function windowKey(entry: var): string { return String(entry?.niriWindowId ?? entry?._sourceKey ?? entry?.title ?? "") }
                // In the order they sit on screen: by workspace, then by column along the strip.
                function placeOf(entry: var): int {
                    const w = (NiriService.windows ?? []).find(item => item.id === entry?.niriWindowId)
                    const ws = (NiriService.allWorkspaces ?? []).find(item => item.id === w?.workspace_id)
                    return Number(ws?.idx ?? 999) * 1000 + Number(w?.layout?.pos_in_scrolling_layout?.[0] ?? 999)
                }
                readonly property var windowKeys: menu.windows.slice().sort((a, b) => menu.placeOf(a) - menu.placeOf(b))
                    .map(entry => menu.windowKey(entry))
                property var shownKeys: []
                onWindowKeysChanged: if (menu.windowKeys.join("\n") !== menu.shownKeys.join("\n")) menu.shownKeys = menu.windowKeys
                property string mode: "menu"
                Connections {
                    target: window
                    function onMenuAppChanged(): void {
                        const app = window.menuApp
                        if (!app) return
                        menu.mode = window.menuMode
                        menu.windows = (app.toplevels ?? []).slice()
                        menu.app = app
                    }
                }
                readonly property var liveWindows: window.menuOpen && menu.app ? (root.liveApps[menu.app.appId]?.toplevels ?? []) : null
                onLiveWindowsChanged: {
                    if (menu.liveWindows === null) return
                    menu.windows = menu.liveWindows.slice()
                    if (menu.mode === "windows" && menu.windows.length === 0) window.menuApp = null
                }
                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: windowsContent
                    visible: menu.mode === "windows"
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 10 * root.d
                    spacing: 8 * root.d
                    readonly property real cardWidth: Math.round(196 * root.d)
                    readonly property real cardHeight: Math.round(124 * root.d)
                    readonly property int columns: Math.max(1, Math.min(root.vertical ? 2 : 4, menu.windows.length))

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6 * root.d
                        Layout.rightMargin: 2 * root.d
                        spacing: 8 * root.d
                        SmartAppIcon {
                            icon: IrisPieces.appIcon(menu.app?.appId ?? "")
                            fallback: "application-x-executable"
                            iconSize: Math.round(18 * root.d)
                        }
                        IrisText {
                            Layout.fillWidth: true
                            text: AppSearch.lookupDesktopEntry(menu.app?.appId ?? "")?.name ?? (menu.app?.appId ?? "")
                            elide: Text.ElideRight
                            font.pixelSize: IrisStyle.typeLabel
                            font.weight: IrisStyle.weight(Font.DemiBold)
                        }
                        IrisText {
                            text: menu.windows.length === 1 ? Translation.tr("1 window") : Translation.tr("%1 windows").arg(menu.windows.length)
                            color: IrisStyle.muted
                            font.pixelSize: IrisStyle.typeMeta
                        }
                        IrisIconButton {
                            materialIcon: "add"
                            Accessible.name: Translation.tr("New window")
                            onClicked: {
                                const e = AppSearch.lookupDesktopEntry(menu.app?.appId ?? "")
                                if (e) AppSearch.launchEntry(e)
                                window.menuApp = null
                            }
                        }
                    }

                    Grid {
                        columns: windowsContent.columns
                        spacing: 8 * root.d
                        Repeater {
                            model: menu.shownKeys
                            MouseArea {
                                id: card
                                required property string modelData
                                readonly property var win: menu.windows.find(entry => menu.windowKey(entry) === card.modelData) ?? null
                                readonly property bool focusedWindow: CompositorService.isNiri
                                    ? card.win?.niriWindowId !== undefined && card.win.niriWindowId === (NiriService.activeWindow?.id ?? -1)
                                    : (card.win?.activated ?? false)
                                readonly property var niriWindow: (NiriService.windows ?? []).find(w => w.id === card.win?.niriWindowId) ?? null
                                readonly property var workspace: (NiriService.allWorkspaces ?? []).find(ws => ws.id === card.win?.niriWorkspaceId) ?? null
                                readonly property bool minimized: card.win?.niriWindowId !== undefined && MinimizedWindows.isMinimized(card.win.niriWindowId)
                                readonly property int column: Number(card.niriWindow?.layout?.pos_in_scrolling_layout?.[0] ?? 0)
                                readonly property int columns: {
                                    const ws = card.niriWindow?.workspace_id
                                    let most = card.column
                                    for (const w of NiriService.windows ?? [])
                                        if (w.workspace_id === ws && !w.is_floating)
                                            most = Math.max(most, Number(w.layout?.pos_in_scrolling_layout?.[0] ?? 0))
                                    return most
                                }
                                width: windowsContent.cardWidth
                                height: plate.height + Math.round(8 * root.d) + caption.implicitHeight
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                Accessible.role: Accessible.Button
                                Accessible.name: String(card.win?.title ?? "")
                                onClicked: mouse => {
                                    if (mouse.button === Qt.MiddleButton) {
                                        if (card.win?.niriWindowId !== undefined) NiriService.closeWindow(card.win.niriWindowId)
                                        return
                                    }
                                    const id = card.win?.niriWindowId
                                    if (CompositorService.isNiri && id !== undefined) {
                                        if (MinimizedWindows.isMinimized(id)) MinimizedWindows.restore(id)
                                        else NiriService.focusWindow(id)
                                    } else card.win?.activate()
                                    GlobalStates.irisDockShown = false
                                    window.menuApp = null
                                }

                                Rectangle {
                                    id: plate
                                    width: windowsContent.cardWidth
                                    height: windowsContent.cardHeight
                                    radius: Math.max(IrisStyle.radiusMicro, menu.radius - Math.round(10 * root.d))
                                    color: card.pressed ? IrisStyle.fillActive : card.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet
                                    border.width: card.focusedWindow ? Math.max(2, Math.round(2 * root.d)) : 0
                                    border.color: IrisStyle.accent
                                    scale: card.pressed ? IrisStyle.pressScale(0.97) : 1
                                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                                    Behavior on scale { NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }

                                    readonly property real aspect: {
                                        const size = card.niriWindow?.layout?.window_size ?? [16, 10]
                                        return Math.max(0.45, Math.min(2.6, Number(size[0]) / Math.max(1, Number(size[1]))))
                                    }
                                    readonly property int seed: {
                                        const title = String(card.win?.title ?? "")
                                        let hash = 7
                                        for (let i = 0; i < title.length; i++) hash = (hash * 31 + title.charCodeAt(i)) % 100003
                                        return hash
                                    }
                                    readonly property real room: Math.round(14 * root.d)

                                    Rectangle {
                                        id: silhouette
                                        readonly property real fitWidth: Math.min(plate.width - plate.room * 2, (plate.height - plate.room * 2) * plate.aspect)
                                        anchors.centerIn: parent
                                        width: Math.round(silhouette.fitWidth)
                                        height: Math.round(silhouette.fitWidth / plate.aspect)
                                        radius: IrisStyle.radiusChip
                                        clip: true
                                        color: IrisStyle.surfaceHigh
                                        opacity: card.minimized ? 0.55 : 1
                                        scale: card.containsMouse ? 1.03 : 1
                                        Behavior on scale { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            height: Math.round(10 * root.d)
                                            color: IrisStyle.fill
                                        }
                                        Row {
                                            x: Math.round(6 * root.d)
                                            y: Math.round(3.5 * root.d)
                                            spacing: Math.round(3 * root.d)
                                            Repeater {
                                                model: 3
                                                Rectangle {
                                                    width: Math.max(3, Math.round(3 * root.d))
                                                    height: width
                                                    radius: width / 2
                                                    color: IrisStyle.textTertiary
                                                }
                                            }
                                        }
                                        SmartAppIcon {
                                            anchors.centerIn: parent
                                            anchors.verticalCenterOffset: Math.round(5 * root.d)
                                            icon: IrisPieces.appIcon(menu.app?.appId ?? "")
                                            fallback: "application-x-executable"
                                            iconSize: Math.round(Math.min(34, Math.max(20, silhouette.height * 0.42)) * root.d)
                                        }
                                    }
                                    // Where the window sits in its workspace's strip: one mark per column, its own lit. The
                                    // one thing a glimpse cannot show otherwise, and the thing that tells two alike apart.
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: Math.round(plate.height - plate.room / 2 - height / 2)
                                        spacing: Math.round(3 * root.d)
                                        MaterialSymbol {
                                            visible: card.niriWindow?.is_floating ?? false
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "picture_in_picture"
                                            iconSize: Math.round(11 * root.d)
                                            color: IrisStyle.subtext
                                        }
                                        Repeater {
                                            model: card.niriWindow?.is_floating ? 0 : Math.min(9, card.columns)
                                            Rectangle {
                                                required property int index
                                                readonly property bool own: index + 1 === card.column
                                                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                                width: Math.round((own ? 10 : 5) * root.d)
                                                height: Math.max(3, Math.round(4 * root.d))
                                                radius: height / 2
                                                color: own ? (card.focusedWindow ? IrisStyle.accent : IrisStyle.text) : IrisStyle.fillActive
                                            }
                                        }
                                        Rectangle {
                                            visible: card.niriWindow?.is_urgent ?? false
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.round(6 * root.d)
                                            height: width
                                            radius: width / 2
                                            color: IrisStyle.secondaryAccent
                                        }
                                    }
                                    Rectangle {
                                        x: plate.width - width - Math.round(6 * root.d)
                                        y: Math.round(6 * root.d)
                                        width: Math.round(22 * root.d)
                                        height: width
                                        radius: width / 2
                                        color: closeHover.hovered ? IrisStyle.danger : IrisStyle.veilHeavy
                                        opacity: card.containsMouse && CompositorService.isNiri ? 1 : 0
                                        visible: opacity > 0
                                        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "close"
                                            iconSize: Math.round(13 * root.d)
                                            color: IrisStyle.text
                                        }
                                        HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                                        TapHandler {
                                            onTapped: {
                                                if (card.win?.niriWindowId !== undefined) NiriService.closeWindow(card.win.niriWindowId)
                                            }
                                        }
                                    }
                                }
                                Column {
                                    id: caption
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.leftMargin: Math.round(4 * root.d)
                                    anchors.rightMargin: Math.round(4 * root.d)
                                    spacing: Math.round(1 * root.d)
                                    IrisText {
                                        width: parent.width
                                        text: String(card.win?.title ?? "")
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                        color: card.focusedWindow ? IrisStyle.text : IrisStyle.subtext
                                        font.pixelSize: IrisStyle.typeMeta
                                        font.weight: card.focusedWindow ? Font.DemiBold : Font.Medium
                                    }
                                    IrisText {
                                        width: parent.width
                                        visible: text.length > 0
                                        text: card.minimized ? Translation.tr("Minimised")
                                            : !card.workspace ? ""
                                            : (card.workspace.name || Translation.tr("Workspace %1").arg(card.workspace.idx))
                                                + (card.columns > 1 && card.column > 0 ? " · " + Translation.tr("%1 of %2").arg(card.column).arg(card.columns) : "")
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                        color: IrisStyle.muted
                                        font.pixelSize: IrisStyle.typeFootnote
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    id: menuContent
                    visible: menu.mode === "menu"
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6 * root.d
                    spacing: 0

                    component MenuRow: IrisButton {
                        id: menuRow
                        property string glyph: ""
                        property string label: ""
                        Layout.fillWidth: true
                        quiet: true
                        implicitHeight: Math.round(30 * root.d)
                        implicitWidth: menuRowLabel.implicitWidth + 52 * root.d
                        buttonRadius: IrisStyle.radiusChip
                        pressScaleEnabled: false
                        colBackgroundHover: IrisStyle.tintFill(IrisStyle.accent)
                        Accessible.name: menuRow.label
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8 * root.d
                            anchors.rightMargin: 10 * root.d
                            spacing: 8 * root.d
                            MaterialSymbol {
                                text: menuRow.glyph
                                iconSize: Math.round(15 * root.d)
                                color: menuRow.danger ? IrisStyle.danger : IrisStyle.subtext
                            }
                            IrisText {
                                id: menuRowLabel
                                Layout.fillWidth: true
                                text: menuRow.label
                                elide: Text.ElideRight
                                color: menuRow.danger ? IrisStyle.danger : IrisStyle.text
                                font.pixelSize: IrisStyle.typeLabel
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10 * root.d
                        Layout.rightMargin: 10 * root.d
                        Layout.topMargin: 4 * root.d
                        Layout.bottomMargin: 4 * root.d
                        spacing: 12 * root.d
                        IrisText {
                            Layout.fillWidth: true
                            text: AppSearch.lookupDesktopEntry(menu.app?.appId ?? "")?.name ?? (menu.app?.appId ?? "")
                            elide: Text.ElideRight
                            font.pixelSize: IrisStyle.typeLabel
                            font.weight: IrisStyle.weight(Font.DemiBold)
                        }
                        IrisText {
                            text: (menu.windows?.length ?? 0) === 0 ? Translation.tr("Not running")
                                : (menu.windows.length === 1 ? Translation.tr("1 window") : Translation.tr("%1 windows").arg(menu.windows.length))
                            color: IrisStyle.muted
                            font.pixelSize: IrisStyle.typeMeta
                        }
                    }
                    Repeater {
                        model: menu.windows
                        MenuRow {
                            required property var modelData
                            glyph: modelData.activated ? "radio_button_checked" : "select_window"
                            label: String(modelData.title ?? "")
                            onClicked: {
                                if (CompositorService.isNiri && modelData.niriWindowId !== undefined) NiriService.focusWindow(modelData.niriWindowId)
                                else modelData.activate()
                                window.menuApp = null
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.leftMargin: 10 * root.d; Layout.rightMargin: 10 * root.d; Layout.topMargin: 4 * root.d; Layout.bottomMargin: 4 * root.d; implicitHeight: 1; color: IrisStyle.hairlineStrong }
                    MenuRow {
                        visible: (menu.app?.toplevels?.length ?? 0) > 1
                        glyph: "view_carousel"
                        label: Translation.tr("Show windows")
                        onClicked: { window.menuMode = "windows"; menu.mode = "windows" }
                    }
                    MenuRow {
                        glyph: "open_in_new"
                        label: Translation.tr("New window")
                        onClicked: {
                            const e = AppSearch.lookupDesktopEntry(menu.app?.appId ?? "")
                            if (e) AppSearch.launchEntry(e)
                            window.menuApp = null
                        }
                    }
                    MenuRow {
                        glyph: menu.app?.pinned ? "keep_off" : "keep"
                        label: menu.app?.pinned ? Translation.tr("Unpin from dock") : Translation.tr("Keep in dock")
                        onClicked: { TaskbarApps.togglePin(menu.app.appId); window.menuApp = null }
                    }
                    MenuRow {
                        readonly property bool floating: IrisPieces.appFloating(menu.app?.appId ?? "")
                        glyph: floating ? "dock_to_bottom" : "bubble_chart"
                        label: floating ? Translation.tr("Return to the Dock") : Translation.tr("Float as a bubble")
                        onClicked: {
                            const appId = menu.app?.appId ?? ""
                            if (floating) IrisPieces.removeApp(appId)
                            else IrisPieces.placeApp(appId, IrisPieces.defaultPlace, 0.5, 0.5)
                            window.menuApp = null
                        }
                    }
                    MenuRow {
                        visible: CompositorService.isNiri && (menu.windows?.length ?? 0) > 0
                        glyph: "close"
                        danger: true
                        label: (menu.windows?.length ?? 0) > 1 ? Translation.tr("Close all windows") : Translation.tr("Close window")
                        onClicked: {
                            (menu.windows ?? []).forEach(t => { if (t.niriWindowId !== undefined) NiriService.closeWindow(t.niriWindowId) })
                            window.menuApp = null
                        }
                    }
                }
            }
        }
}
