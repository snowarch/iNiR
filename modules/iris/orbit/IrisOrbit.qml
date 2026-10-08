pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.frame
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.pieces

// Orbit: your session as Niri holds it, one strip per workspace with its windows where they are, and everything you need to
// get somewhere else in it. The Island grows into it (or a sheet does, under it): a Place in the chassis window of its
// output, like Spotlight, resident so it opens on a warm frame, taking the keyboard while it is up. The workspace you are
// on is in the middle, its neighbours show their near edge. Typing lights up the windows that match wherever they are.
Item {
    id: root

    property var screen: null
    readonly property string outputName: root.screen?.name ?? ""
    readonly property bool here: root.outputName === (GlobalStates.irisOrbitOutput.length > 0 ? GlobalStates.irisOrbitOutput
        : (GlobalStates.focusedScreen?.name ?? ""))
    readonly property bool wanted: root.here && GlobalStates.irisOrbitOpen
    readonly property bool present: root.here && (GlobalStates.irisOrbitOpen || (content.item?.progress ?? 0) > 0)
    readonly property bool armed: root.wanted && (content.item?.armed ?? false)
    // The focused output keeps its model built, so opening is showing it, not making it.
    readonly property bool live: root.here
    readonly property real d: IrisStyle.density
    readonly property var options: Config.options?.iris?.orbit ?? ({})
    readonly property bool previewsOn: (root.options?.previews ?? true) && !GameMode.active
    readonly property real outputWidth: Math.max(1, Number(NiriService.outputs?.[root.outputName]?.logical?.width ?? root.screen?.width ?? 1920))
    readonly property real outputHeight: Math.max(1, Number(NiriService.outputs?.[root.outputName]?.logical?.height ?? root.screen?.height ?? 1080))

    // ---- Where it grows from -------------------------------------------------------------------------------------------
    readonly property var island: GlobalStates.irisIslandGeometry?.[root.outputName] ?? null
    readonly property bool fromIsland: String(root.options?.opens ?? "island") === "island" && root.island !== null && root.island.width > 0
    readonly property bool islandBottom: root.island?.bottomEdge ?? false
    readonly property string islandSide: root.island?.vertical ? String(root.island.edge) : ""
    readonly property bool joinsEdge: root.fromIsland && IrisFrame.notch
    readonly property bool joinsFrame: root.joinsEdge && IrisFrame.framed
    function edgeClear(edge: string): real {
        let held = IrisFrame.inset(edge)
        if ((Config.options?.iris?.dock?.enable ?? true) && IrisFrame.dockEdge === edge)
            held = Math.max(held, IrisFrame.band + IrisFrame.dockBand + IrisFrame.dockMargin)
        return held - IrisFrame.band + IrisFrame.musicReach(edge) + Math.round(12 * root.d)
    }

    visible: root.present

    // ---- The model: Niri's, for this output ---------------------------------------------------------------------------
    readonly property var workspaces: !root.live ? [] : (NiriService.allWorkspaces ?? [])
        .filter(ws => ws.output === root.outputName && !MinimizedWindows.isStashWorkspace(ws.id))
        .slice().sort((a, b) => Number(a.idx ?? 0) - Number(b.idx ?? 0))
    readonly property var outputWindows: !root.live ? [] : (NiriService.windows ?? [])
        .filter(window => (NiriService.allWorkspaces ?? []).some(ws => ws.id === window.workspace_id && ws.output === root.outputName))
    readonly property var windowMap: {
        const map = {}
        for (const window of root.outputWindows) map[window.id] = window
        return map
    }
    readonly property var stashedIds: !root.live || !(root.options?.showMinimised ?? true) ? []
        : MinimizedWindows.getMinimizedForOutput(root.outputName).filter(id => root.windowMap[id] !== undefined)

    // Columns left to right, the tiles of a column top to bottom, then whatever floats.
    function readingOrder(workspaceId: int): var {
        return root.outputWindows.filter(window => window.workspace_id === workspaceId).slice().sort((a, b) => {
            if (!!a.is_floating !== !!b.is_floating) return a.is_floating ? 1 : -1
            const pa = a.layout?.pos_in_scrolling_layout, pb = b.layout?.pos_in_scrolling_layout
            if (!pa || !pb) return 0
            return pa[0] !== pb[0] ? pa[0] - pb[0] : pa[1] - pb[1]
        }).map(window => window.id)
    }
    function computeCards(): var {
        return root.workspaces.map(ws => ({ ws: ws, ids: root.readingOrder(ws.id) }))
    }
    // The cards are rebuilt when what they hold changes, not when a title does.
    readonly property var freshCards: root.computeCards()
    readonly property string cardsKey: JSON.stringify(root.freshCards.map(card => [card.ws.id, card.ws.idx, card.ws.name, card.ws.is_active,
        card.ws.active_window_id, card.ids]))
    property var cards: []
    onCardsKeyChanged: root.cards = root.freshCards

    readonly property int recentLimit: Math.max(1, Math.min(8, Number(root.options?.recentCount ?? 5)))
    readonly property var recentIds: {
        if (!root.live || !(root.options?.showRecent ?? true)) return []
        const focused = new Set(root.workspaces.filter(ws => ws.is_active).map(ws => ws.active_window_id))
        const out = []
        for (const id of NiriService.mruWindowIds ?? []) {
            if (root.windowMap[id] === undefined || root.stashedIds.includes(id) || focused.has(id)) continue
            out.push(id)
            if (out.length >= root.recentLimit) break
        }
        return out
    }

    // ---- Where the selection is ---------------------------------------------------------------------------------------
    property int selectedWsId: -1
    property int cursorId: -1
    readonly property int selectedIndex: {
        const at = root.cards.findIndex(card => card.ws.id === root.selectedWsId)
        return at >= 0 ? at : Math.max(0, root.cards.findIndex(card => card.ws.is_active))
    }
    readonly property var selectedCard: root.cards[root.selectedIndex] ?? null
    function defaultCursor(card: var): int {
        if (!card || card.ids.length === 0) return -1
        return card.ids.includes(card.ws.active_window_id) ? card.ws.active_window_id : card.ids[0]
    }
    function select(index: int, cursor: int): void {
        const card = root.cards[Math.max(0, Math.min(root.cards.length - 1, index))]
        if (!card) return
        root.selectedWsId = card.ws.id
        root.cursorId = cursor !== undefined && cursor >= 0 ? cursor : root.defaultCursor(card)
        previewTimer.restart()
    }

    // ---- Finding ------------------------------------------------------------------------------------------------------
    property string query: ""
    readonly property bool searching: root.query.trim().length > 0
    function nameOf(window: var): string {
        const id = String(window?.app_id ?? "")
        return AppSearch.lookupDesktopEntry(id)?.name ?? id
    }
    function titleOf(window: var): string {
        const title = String(window?.title ?? "").trim()
        return title.length > 0 ? title : root.nameOf(window)
    }
    readonly property var matchOrder: {
        if (!root.searching) return []
        const words = root.query.trim().toLowerCase().split(/\s+/)
        const out = []
        const scan = (id, ws) => {
            const window = root.windowMap[id]
            if (!window) return
            const hay = (root.titleOf(window) + " " + root.nameOf(window) + " " + String(window.app_id ?? "") + " " + (ws ? String(ws.name ?? "") : "")).toLowerCase()
            if (words.every(word => hay.includes(word))) out.push(id)
        }
        for (const card of root.cards) for (const id of card.ids) scan(id, card.ws)
        for (const id of root.stashedIds) scan(id, null)
        return out
    }
    readonly property var matches: {
        if (!root.searching) return null
        const map = {}
        for (const id of root.matchOrder) map[id] = true
        return map
    }
    // The match you used most recently leads.
    function bestMatch(): int {
        const mru = NiriService.mruWindowIds ?? []
        let best = -1, bestRank = 1e9
        for (const id of root.matchOrder) {
            const rank = mru.indexOf(id)
            if (rank >= 0 && rank < bestRank) { best = id; bestRank = rank }
        }
        return best >= 0 ? best : (root.matchOrder[0] ?? -1)
    }
    function focusMatch(id: int): void {
        if (id < 0) return
        const at = root.cards.findIndex(card => card.ids.includes(id))
        if (at >= 0) root.select(at, id)
        else root.cursorId = id
    }
    onQueryChanged: {
        if (root.searching) root.focusMatch(root.bestMatch())
        else root.cursorId = root.defaultCursor(root.selectedCard)
    }

    // ---- Doing --------------------------------------------------------------------------------------------------------
    function close(): void { GlobalStates.irisOrbitOpen = false }
    function leave(): void { if (root.options?.closeOnGo ?? true) root.close() }
    function isStashed(id: int): bool { return root.stashedIds.includes(id) }
    function restore(id: int): void {
        if ((root.options?.stashRestore ?? "original") === "current") MinimizedWindows.restore(id)
        else MinimizedWindows.restoreOriginal(id)
    }
    function goToWindow(id: int): void {
        if (id < 0) return
        root.leave()
        if (root.isStashed(id)) root.restore(id)
        else NiriService.focusWindow(id)
    }
    function goToWorkspace(wsId: int): void {
        root.leave()
        NiriService.switchToWorkspaceById(wsId)
    }
    function activate(): void {
        if (root.searching && root.cursorId < 0) {
            if (!(root.options?.askSpotlight ?? true)) return
            root.close()
            GlobalStates.irisSpotlightQuery = root.query.trim()
            GlobalStates.searchOpen = true
            return
        }
        if (root.cursorId >= 0) root.goToWindow(root.cursorId)
        else if (root.selectedCard) root.goToWorkspace(root.selectedCard.ws.id)
    }
    function closeSubject(): void { if (root.cursorId >= 0) NiriService.closeWindow(root.cursorId) }
    function stashSubject(): void {
        if (root.cursorId < 0) return
        if (root.isStashed(root.cursorId)) root.restore(root.cursorId)
        else MinimizedWindows.minimize(root.cursorId)
    }
    function floatSubject(): void {
        if (root.cursorId >= 0 && !root.isStashed(root.cursorId)) NiriService.send({ "Action": { "ToggleWindowFloating": { "id": root.cursorId } } })
    }
    // The window goes to the workspace beside the one it is on; past the last one is Niri's empty workspace.
    function sendSubject(step: int): void {
        const id = root.cursorId
        if (id < 0 || root.isStashed(id)) return
        const from = root.cards.findIndex(card => card.ids.includes(id))
        const target = root.cards[from + step]
        if (from < 0 || !target) return
        if (NiriService.moveWindowToWorkspaceById(id, target.ws.id, false)) {
            root.selectedWsId = target.ws.id
            root.cursorId = id
        }
    }
    function openOverview(): void {
        root.close()
        overviewTimer.restart()
    }
    Timer { id: overviewTimer; interval: 120; onTriggered: NiriService.toggleOverview() }

    // ---- Walking ------------------------------------------------------------------------------------------------------
    function stepWorkspace(step: int): void {
        const next = Math.max(0, Math.min(root.cards.length - 1, root.selectedIndex + step))
        if (next !== root.selectedIndex) root.select(next, -1)
    }
    function stepWindow(step: int): void {
        const ids = root.selectedCard?.ids ?? []
        if (ids.length === 0) return
        const at = ids.indexOf(root.cursorId)
        root.cursorId = ids[at < 0 ? 0 : Math.max(0, Math.min(ids.length - 1, at + step))]
    }
    function stepMatch(step: int): void {
        const list = root.matchOrder
        if (list.length === 0) return
        const at = list.indexOf(root.cursorId)
        root.focusMatch(list[(Math.max(0, at) + (at < 0 ? 0 : step) + list.length) % list.length])
    }
    readonly property bool swapped: String(root.options?.keys ?? "niri") === "swapped"
    function handleKey(event): void {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        const key = event.key
        const workspaceKeys = root.swapped ? [Qt.Key_Left, Qt.Key_Right] : [Qt.Key_Up, Qt.Key_Down]
        const windowKeys = root.swapped ? [Qt.Key_Up, Qt.Key_Down] : [Qt.Key_Left, Qt.Key_Right]
        if (key === Qt.Key_Return || key === Qt.Key_Enter) root.activate()
        else if (key === Qt.Key_Delete) root.closeSubject()
        else if (ctrl && key === Qt.Key_M) root.stashSubject()
        else if (ctrl && key === Qt.Key_F) root.floatSubject()
        else if (ctrl && key === workspaceKeys[0]) root.sendSubject(-1)
        else if (ctrl && key === workspaceKeys[1]) root.sendSubject(1)
        else if (key === windowKeys[0] || key === Qt.Key_Backtab) root.searching ? root.stepMatch(-1) : root.stepWindow(-1)
        else if (key === windowKeys[1] || key === Qt.Key_Tab) root.searching ? root.stepMatch(1) : root.stepWindow(1)
        else if (key === workspaceKeys[0]) root.searching ? root.stepMatch(-1) : root.stepWorkspace(-1)
        else if (key === workspaceKeys[1]) root.searching ? root.stepMatch(1) : root.stepWorkspace(1)
        else return
        event.accepted = true
    }

    // ---- Pictures -----------------------------------------------------------------------------------------------------
    // Niri's own screenshot of a window is all a shell can get of one (its overview draws the live windows itself), so
    // Orbit asks for the ones it is about to show, the strip in the middle first, and shows the picture it has meanwhile.
    function syncPreviews(): void {
        if (!root.wanted || !root.previewsOn) return
        const core = root.selectedCard ? root.selectedCard.ids.slice() : []
        const near = []
        for (const offset of [-1, 1]) for (const id of root.cards[root.selectedIndex + offset]?.ids ?? []) near.push(id)
        for (const id of root.recentIds.concat(root.stashedIds)) if (!core.includes(id)) near.push(id)
        const age = Math.max(1, Number(root.options?.previewAge ?? 10)) * 1000
        if (core.length > 0) WindowPreviewService.captureForTaskView(core, age)
        if (near.length > 0) WindowPreviewService.captureForTaskView(near, age * 4)
    }
    Timer { id: previewTimer; interval: 60; onTriggered: root.syncPreviews() }
    onCardsChanged: if (root.wanted) previewTimer.restart()

    function opened(): void {
        root.query = GlobalStates.irisOrbitQuery
        GlobalStates.irisOrbitQuery = ""
        const active = root.cards.findIndex(card => card.ws.is_active)
        root.select(active >= 0 ? active : 0, -1)
        if (root.searching) root.focusMatch(root.bestMatch())
        root.focusInput()
        previewTimer.restart()
    }
    function focusInput(): void { Qt.callLater(() => content.item?.focusInput()) }

    Connections {
        target: GlobalStates
        function onIrisOrbitOpenChanged(): void { if (GlobalStates.irisOrbitOpen && root.here) root.opened() }
    }
    onVisibleChanged: if (!visible) root.query = ""
    Component.onCompleted: if (root.wanted) root.opened()

    Shortcut {
        sequence: "Escape"
        enabled: root.wanted
        onActivated: {
            if (root.query.length > 0) root.query = ""
            else root.close()
        }
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -IrisFrame.band
        enabled: root.armed
        onClicked: root.close()
    }

    Loader {
        id: content
        anchors.fill: parent
        focus: true
        sourceComponent: stageComponent
    }

    // ---- Anatomy ------------------------------------------------------------------------------------------------------
    component ShelfLabel: IrisText {
        role: IrisText.Eyebrow
        color: IrisStyle.muted
    }
    component ActionButton: IrisIconButton {
        id: action
        property string label: ""
        Accessible.name: action.label
        implicitWidth: Math.round(34 * root.d)
    }

    Component {
        id: stageComponent

        Item {
            id: stage
            readonly property alias progress: surface.progress
            readonly property alias armed: surface.armed
            readonly property alias settled: surface.settled
            function focusInput(): void { input.forceActiveFocus() }

            RectangularShadow {
                x: surface.x + surface.lerp(surface.from.x, 0)
                y: surface.y + surface.lerp(surface.from.y, 0) + 8 * root.d * surface.progress
                width: surface.lerp(surface.from.width, surface.width)
                height: surface.lerp(surface.from.height, surface.height)
                radius: Math.min(width / 2, height / 2, surface.lerp(surface.fromRadius, surface.radius))
                blur: 32 * root.d
                spread: -6 * root.d
                color: IrisStyle.shadow
                visible: !root.fromIsland
                opacity: IrisStyle.shadowAt(surface.progress)
            }

            IrisMorphSurface {
                id: surface
                compositorBlurred: true
                open: root.wanted
                settles: true
                motionSurface: "orbit"
                fieldBacked: true
                chassisKey: "orbit"
                chassisJoin: {
                    if (!root.joinsEdge) return {}
                    const grow = root.islandBottom ? "bottom" : "top"
                    if (root.joinsFrame) return { id: "orbit", joins: "frame", fuse: IrisStyle.fuseEdge, grow: grow }
                    const k = IrisStyle.fuseEdge, deep = Math.max(8, k)
                    return { id: "orbit", joins: "orbitEdge", fuse: k, grow: grow,
                        edge: { x: -2 * k, y: root.islandBottom ? root.height + 1 : -deep - 1, width: root.width + 4 * k, height: deep,
                            radius: 0, paints: true, fuse: 0, id: "orbitEdge", glass: IrisStyle.surfaceGlass("orbit") } }
                }
                readonly property real dissolve: root.fromIsland ? IrisStyle.ramp(surface.progress, 0, 0.14) : 1
                origin: root.fromIsland ? ({ x: root.island.x - IrisFrame.band, y: root.island.y - IrisFrame.band,
                    width: root.island.width, height: root.island.height, radius: Math.min(root.island.width, root.island.height) / 2 }) : null
                originShare: root.fromIsland ? 1 : IrisStyle.absorbShare
                color: root.fromIsland ? ColorUtils.applyAlpha(IrisStyle.bodySurface, surface.dissolve) : IrisStyle.surface
                light: root.fromIsland ? "transparent" : IrisStyle.surfaceLight("orbit", IrisStyle.wallpaperLight)
                lightFrom: IrisFrame.islandEdge
                radius: IrisStyle.surfaceRadius("orbit", IrisStyle.radiusPanel)
                width: Math.max(Math.round(420 * root.d), Math.min(root.width - Math.round(32 * root.d), Math.round(Number(root.options?.width ?? 1100) * root.d)))
                x: !root.fromIsland ? Math.round((root.width - width) / 2)
                    : root.islandSide === "left" ? Math.round(root.island.x - IrisFrame.band)
                    : root.islandSide === "right" ? Math.round(root.island.x - IrisFrame.band + root.island.width - width)
                    : Math.round(Math.max(8, Math.min(root.width - width - 8, root.island.x - IrisFrame.band + root.island.width / 2 - width / 2)))
                // Heights hug content: the workspace you are on decides how tall it is.
                height: Math.min(scene.contentH, Math.max(Math.round(200 * root.d), surface.room))
                y: !root.fromIsland ? Math.max(Math.round(72 * root.d), Math.round(root.height * 0.12))
                    : root.islandSide.length > 0 ? Math.round(Math.max(8, Math.min(root.height - height - 8,
                        root.island.y - IrisFrame.band + root.island.height / 2 - height / 2)))
                    : root.islandBottom ? Math.round(root.island.y - IrisFrame.band + root.island.height - height)
                    : Math.round(root.island.y - IrisFrame.band)
                readonly property real room: {
                    const top = root.edgeClear("top")
                    const bottom = root.edgeClear("bottom")
                    if (root.fromIsland && root.islandSide.length > 0) return root.height - top - bottom
                    if (root.fromIsland && root.islandBottom) return root.island.y - IrisFrame.band + root.island.height - top
                    const y = root.fromIsland ? root.island.y - IrisFrame.band : Math.max(Math.round(72 * root.d), Math.round(root.height * 0.12))
                    return root.height - y - bottom
                }
                onSettledChanged: if (surface.settled && surface.open) stage.focusInput()
                Behavior on height {
                    enabled: surface.settled
                    NumberAnimation { duration: IrisStyle.duration(150); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
                }

                MouseArea { anchors.fill: parent }

                Item {
                    id: scene
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: scene.contentH

                    // The field sits on the Island's side of the body: at the bottom when the Island is.
                    readonly property bool fieldLast: root.fromIsland && root.islandBottom
                    readonly property real pad: Math.round(18 * root.d)
                    readonly property real headerH: Math.round(52 * root.d)
                    readonly property real labelH: Math.round(30 * root.d)
                    readonly property real peek: Math.max(0, Math.round(Number(root.options?.peek ?? 56) * root.d))
                    readonly property real gap: Math.round(14 * root.d)
                    // A neighbour takes room only on the side where there is one, so the first and last workspaces
                    // leave no empty band; the room moves on its own scalar as you walk.
                    readonly property bool hasAbove: scene.peek > 0 && root.selectedIndex > 0
                    readonly property bool hasBelow: scene.peek > 0 && root.selectedIndex < root.cards.length - 1
                    property real aboveH: scene.hasAbove ? scene.peek + scene.gap : 0
                    property real belowH: scene.hasBelow ? scene.peek + scene.gap : 0
                    Behavior on aboveH {
                        enabled: surface.settled
                        NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve }
                    }
                    Behavior on belowH {
                        enabled: surface.settled
                        NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve }
                    }
                    // The cap on the strip in the middle reserves both sides at once, so it never changes while walking
                    // (a moving cap would rebuild every card each frame).
                    readonly property real neighboursMax: scene.peek > 0 ? 2 * (scene.peek + scene.gap) : 0
                    readonly property real stageMargin: Math.round(14 * root.d)
                    readonly property bool hasActions: (root.options?.showActions ?? true) && root.cursorId >= 0
                    readonly property real thumbW: Math.round(Number(root.options?.thumbSize ?? 88) * root.d)
                    readonly property real thumbH: Math.round(scene.thumbW * 9 / 16)
                    readonly property bool hasShelf: root.recentIds.length > 0 || root.stashedIds.length > 0
                    readonly property real shelfH: scene.hasShelf ? scene.thumbH + Math.round(48 * root.d) : 0
                    readonly property real shelfBlock: scene.hasShelf ? scene.shelfH + Math.round(10 * root.d) : 0
                    readonly property real hintsH: (root.options?.hints ?? true) ? Math.round(24 * root.d) : Math.round(8 * root.d)
                    // Everything but the strip in the middle, and so how tall that strip may be.
                    readonly property real chrome: scene.headerH + 1 + scene.stageMargin * 2 + scene.shelfBlock + scene.hintsH + scene.pad
                    readonly property real heroMax: Math.max(Math.round(150 * root.d),
                        Math.min(Math.round(Number(root.options?.cardHeight ?? 440) * root.d) + scene.labelH + Math.round(8 * root.d),
                            surface.room - scene.chrome - scene.neighboursMax))
                    property real heroTarget: scene.heroMax
                    property real heroH: scene.heroTarget
                    Behavior on heroH {
                        enabled: surface.settled
                        NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve }
                    }
                    readonly property real regionH: Math.round(scene.heroH + scene.aboveH + scene.belowH)
                    readonly property real contentH: scene.chrome + scene.regionH
                    // The strip in the middle, in the stage's coordinates: its caption row, then its card.
                    readonly property real captionRow: 0
                    readonly property real heroFaceH: Math.max(1, scene.heroH - scene.captionRow)
                    readonly property real heroFaceY: scene.aboveH + scene.captionRow
                    property real heroFaceW: 0

                    // The rail on the left names each workspace by its figure; the strips stand to its right.
                    readonly property real gutterW: Math.round(176 * root.d)
                    readonly property real railX: scene.pad + Math.round(10 * root.d)
                    readonly property real stageW: Math.max(Math.round(300 * root.d), scene.width - scene.pad * 2 - scene.gutterW)
                    readonly property real stageCenterX: scene.pad + scene.gutterW + scene.stageW / 2
                    // Top to bottom in the order the body reads; the field first unless the Island is at the bottom.
                    readonly property real headerY: scene.fieldLast ? scene.contentH - scene.headerH - 1 : 0
                    readonly property real regionY: scene.fieldLast ? scene.stageMargin : scene.headerH + 1 + scene.stageMargin
                    readonly property real shelfY: scene.regionY + scene.regionH + scene.stageMargin
                    readonly property real hintsY: scene.shelfY + (scene.hasShelf ? scene.shelfH + Math.round(10 * root.d) : 0)
                    // One number moves the whole stage: which strip is in the middle. Everything else is read from it.
                    property real pos: root.selectedIndex
                    Behavior on pos {
                        enabled: surface.settled
                        NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve }
                    }

                    // ---- The way in: what to find, and the way out to Niri's own overview.
                    Item {
                        id: field
                        x: 0
                        y: scene.headerY
                        width: scene.width
                        height: scene.headerH
                        MaterialSymbol {
                            id: searchGlyph
                            x: scene.pad + Math.round(4 * root.d)
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search"
                            iconSize: Math.round(22 * root.d)
                            color: root.searching ? IrisStyle.accent : IrisStyle.subtext
                            Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                        }
                        TextInput {
                            id: input
                            anchors.left: searchGlyph.right
                            anchors.leftMargin: Math.round(12 * root.d)
                            anchors.right: status.left
                            anchors.rightMargin: Math.round(12 * root.d)
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.query
                            color: IrisStyle.text
                            selectionColor: IrisStyle.accentContainer
                            selectedTextColor: IrisStyle.inkOnAccentContainer
                            font.family: IrisStyle.fontMain
                            font.pixelSize: IrisStyle.typeTitleLarge
                            clip: true
                            focus: true
                            onTextChanged: if (root.query !== text) root.query = text
                            Keys.onPressed: event => root.handleKey(event)
                            IrisText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: input.text.length === 0
                                text: Translation.tr("Find a window")
                                color: IrisStyle.muted
                                font.pixelSize: input.font.pixelSize
                                font.weight: IrisStyle.weight(Font.Normal)
                            }
                        }
                        Row {
                            id: status
                            anchors.right: parent.right
                            anchors.rightMargin: scene.pad
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Math.round(8 * root.d)
                            IrisText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.searching
                                text: root.matchOrder.length === 0 ? ((root.options?.askSpotlight ?? true) ? Translation.tr("No match · ↵ asks Spotlight") : Translation.tr("No match"))
                                    : root.matchOrder.length === 1 ? Translation.tr("1 window") : Translation.tr("%1 windows").arg(root.matchOrder.length)
                                role: IrisText.Meta
                                color: root.matchOrder.length === 0 ? IrisStyle.danger : IrisStyle.subtext
                            }
                            IrisIconButton {
                                visible: root.searching
                                anchors.verticalCenter: parent.verticalCenter
                                materialIcon: "close"
                                iconSize: Math.round(16 * root.d)
                                Accessible.name: Translation.tr("Clear")
                                onClicked: { root.query = ""; root.focusInput() }
                            }
                            IrisIconButton {
                                anchors.verticalCenter: parent.verticalCenter
                                materialIcon: "space_dashboard"
                                Accessible.name: Translation.tr("Open Niri's overview")
                                onClicked: root.openOverview()
                            }
                        }
                    }
                    Rectangle {
                        x: scene.pad
                        y: scene.fieldLast ? scene.headerY - 1 : scene.headerH
                        width: scene.width - scene.pad * 2
                        height: 1
                        color: IrisStyle.hairline
                    }

                    // ---- The stage: one strip per workspace, stacked the way Niri stacks them, the one you are on in the middle.
                    Item {
                        id: cardsArea
                        x: 0
                        y: scene.regionY
                        width: scene.width
                        height: scene.regionH
                        clip: true
                        property real wheelSum: 0
                        WheelHandler {
                            enabled: root.options?.scroll ?? true
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => {
                                cardsArea.wheelSum += event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y * 3
                                while (Math.abs(cardsArea.wheelSum) >= 120) {
                                    root.stepWorkspace(cardsArea.wheelSum < 0 ? 1 : -1)
                                    cardsArea.wheelSum += cardsArea.wheelSum < 0 ? 120 : -120
                                }
                            }
                        }

                        // The rail: Niri's workspaces are a column, so the session reads down one line.
                        Rectangle {
                            x: Math.round(scene.railX - width / 2)
                            y: 0
                            width: Math.max(1, Math.round(1 * root.d))
                            height: cardsArea.height
                            // It fades out at both ends: the session goes on past what the stage shows.
                            gradient: Gradient {
                                GradientStop { position: 0; color: "transparent" }
                                GradientStop { position: 0.12; color: IrisStyle.hairline }
                                GradientStop { position: 0.88; color: IrisStyle.hairline }
                                GradientStop { position: 1; color: "transparent" }
                            }
                        }
                        Repeater {
                            model: root.cards
                            Item {
                                id: slot
                                required property var modelData
                                required property int index
                                readonly property real rel: slot.index - scene.pos
                                readonly property real dist: Math.abs(slot.rel)
                                readonly property int side: slot.rel < 0 ? -1 : 1
                                readonly property bool hero: slot.index === root.selectedIndex
                                readonly property var ws: slot.modelData.ws
                                // Its Niri name, when it has one and names are shown.
                                readonly property string wsName: String(root.options?.labels ?? "full") === "full" ? String(slot.ws.name ?? "").trim() : ""
                                // A neighbour is the whole workspace in miniature, as tall as the peek: a deck that
                                // recedes above and below, never a strip cut by the edge. One scalar (pos) walks it.
                                readonly property real mini: Math.min(1, scene.peek / Math.max(1, face.height))
                                readonly property real near: Math.min(slot.dist, 1)
                                readonly property real far: Math.max(0, Math.min(slot.dist, 2) - 1)
                                readonly property real cardScale: slot.dist <= 1 ? 1 - (1 - slot.mini) * slot.dist : slot.mini * (1 - 0.3 * slot.far)
                                // Measured from the strip in the middle, whatever this card's own height: a neighbour taller
                                // than the middle strip would otherwise land past the edge.
                                readonly property real reach: (scene.heroFaceH / 2 + scene.gap + scene.peek / 2) * slot.near
                                    + (scene.peek + scene.gap) * slot.far
                                // A neighbour lines up on the middle strip's left edge: the deck has a spine beside the rail.
                                readonly property real centerX: scene.stageCenterX
                                    + (scene.stageCenterX - scene.heroFaceW / 2 + slot.shownW / 2 - scene.stageCenterX) * slot.near
                                readonly property real centerY: scene.heroFaceY + scene.heroFaceH / 2 + slot.side * slot.reach
                                readonly property real shownW: face.width * slot.cardScale
                                readonly property real shownH: face.height * slot.cardScale
                                anchors.fill: parent
                                z: 10 - slot.dist
                                visible: slot.dist < 2.05 && (scene.peek > 0 || slot.hero)
                                opacity: slot.dist <= 1 ? 1 - 0.35 * slot.dist : Math.max(0, 0.65 * (2 - slot.dist))

                                Binding {
                                    target: scene
                                    property: "heroTarget"
                                    value: face.height > 0 ? face.height + scene.captionRow : scene.heroMax
                                    when: slot.hero
                                }
                                Binding { target: scene; property: "heroFaceW"; value: face.width; when: slot.hero }
                                // The strip in the middle stands off the body; a miniature lies flat in the deck.
                                RectangularShadow {
                                    x: Math.round(slot.centerX - slot.shownW / 2)
                                    y: Math.round(slot.centerY - slot.shownH / 2 + Math.round(6 * root.d))
                                    width: Math.round(slot.shownW)
                                    height: Math.round(slot.shownH)
                                    radius: IrisStyle.radiusCard * slot.cardScale
                                    blur: Math.round(28 * root.d)
                                    spread: -Math.round(6 * root.d)
                                    color: IrisStyle.plateShadow
                                    opacity: 1 - slot.near
                                    visible: face.status === Loader.Ready && opacity > 0.01
                                }
                                Loader {
                                    id: face
                                    x: Math.round(slot.centerX - width / 2)
                                    y: Math.round(slot.centerY - height / 2)
                                    active: slot.visible
                                    scale: slot.cardScale
                                    sourceComponent: IrisOrbitCard {
                                        screen: root.screen
                                        outputWidth: root.outputWidth
                                        outputHeight: root.outputHeight
                                        fitWidth: scene.stageW
                                        fitHeight: scene.heroMax - scene.captionRow
                                        windows: root.outputWindows.filter(window => window.workspace_id === slot.ws.id)
                                        cursorId: slot.hero ? root.cursorId : -1
                                        matches: root.matches
                                        previews: root.previewsOn
                                        interactive: slot.hero
                                        showWallpaper: root.options?.wallpaper ?? true
                                        titleMode: String(root.options?.titles ?? "hover")
                                        dimOpacity: 1 - Math.max(0, Math.min(95, Number(root.options?.dimMatches ?? 78))) / 100
                                        onCardClicked: slot.hero ? root.goToWorkspace(slot.ws.id) : root.select(slot.index, -1)
                                        onWindowHovered: windowId => { if (slot.hero && !root.searching) root.cursorId = windowId }
                                        onWindowClicked: (windowId, button) => {
                                            if (!slot.hero) { root.select(slot.index, windowId); return }
                                            if (button === Qt.MiddleButton) NiriService.closeWindow(windowId)
                                            else root.goToWindow(windowId)
                                        }
                                    }
                                }
                                // Its place on the rail: a node that fills with the accent as the workspace reaches the middle.
                                Rectangle {
                                    readonly property real size: Math.round((8 + 6 * (1 - slot.near)) * root.d)
                                    // Level with the figure in the middle, on the miniature's centre as a neighbour.
                                    readonly property real heroY: slot.centerY - slot.shownH / 2 + Math.round(40 * root.d)
                                    x: Math.round(scene.railX - width / 2)
                                    y: Math.round(heroY + (slot.centerY - heroY) * slot.near - height / 2)
                                    width: size
                                    height: size
                                    radius: size / 2
                                    color: slot.hero ? IrisStyle.accent : IrisStyle.surface
                                    border.width: slot.hero ? 0 : Math.max(1, Math.round(1.5 * root.d))
                                    border.color: slot.ws.is_active ? IrisStyle.accent : IrisStyle.subtext
                                }
                                // The workspace in the middle is named by its figure, large, the way an instrument reads.
                                Column {
                                    x: Math.round(scene.railX + Math.round(18 * root.d))
                                    y: Math.round(slot.centerY - slot.shownH / 2 - Math.round(4 * root.d))
                                    width: scene.gutterW - Math.round(36 * root.d)
                                    spacing: Math.round(2 * root.d)
                                    opacity: 1 - slot.near
                                    visible: opacity > 0.01
                                    IrisText {
                                        width: parent.width
                                        text: slot.wsName.length > 0 ? slot.wsName
                                            : slot.ws.is_active ? Translation.tr("You are here") : Translation.tr("Workspace")
                                        role: IrisText.Eyebrow
                                        color: slot.ws.is_active ? IrisStyle.accent : IrisStyle.subtext
                                        elide: Text.ElideRight
                                    }
                                    IrisText {
                                        text: String(slot.ws.idx ?? "–").padStart(2, "0")
                                        font.family: IrisStyle.fontNumbers
                                        font.features: ({ "tnum": 1 })
                                        font.pixelSize: Math.round(IrisStyle.typeDisplay * 1.75)
                                        font.weight: IrisStyle.weight(Font.Bold)
                                        font.letterSpacing: IrisStyle.tracking(Math.round(IrisStyle.typeDisplay * 1.75))
                                        color: IrisStyle.text
                                    }
                                    IrisText {
                                        text: slot.modelData.ids.length === 0 ? Translation.tr("Empty")
                                            : slot.modelData.ids.length === 1 ? Translation.tr("1 window") : Translation.tr("%1 windows").arg(slot.modelData.ids.length)
                                        role: IrisText.Meta
                                        color: IrisStyle.muted
                                    }
                                }
                                // A neighbour, on its node: figure and count in one quiet line.
                                Row {
                                    x: Math.round(scene.railX + Math.round(18 * root.d))
                                    y: Math.round(slot.centerY - height / 2)
                                    spacing: Math.round(8 * root.d)
                                    opacity: slot.near
                                    visible: opacity > 0.01
                                    IrisText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: String(slot.ws.idx ?? "–").padStart(2, "0")
                                        font.family: IrisStyle.fontNumbers
                                        font.features: ({ "tnum": 1 })
                                        font.pixelSize: IrisStyle.typeTitle
                                        font.weight: IrisStyle.weight(Font.Bold)
                                        color: IrisStyle.subtext
                                    }
                                    IrisText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: slot.wsName.length > 0 ? slot.wsName
                                            : slot.modelData.ids.length === 0 ? Translation.tr("Empty")
                                            : slot.modelData.ids.length === 1 ? Translation.tr("1 window") : Translation.tr("%1 windows").arg(slot.modelData.ids.length)
                                        role: IrisText.Meta
                                        color: IrisStyle.muted
                                    }
                                }
                            }
                        }

                        // The window under the cursor, filed under its workspace's figure: its name, then what can be
                        // done to it. Beside the rail, never across the strip.
                        Column {
                            id: actions
                            readonly property var subject: root.windowMap[root.cursorId] ?? null
                            readonly property bool aside: root.isStashed(root.cursorId)
                            visible: scene.hasActions && actions.subject !== null
                            x: Math.round(scene.railX + Math.round(18 * root.d))
                            y: Math.round(scene.heroFaceY + Math.round(104 * root.d))
                            width: scene.gutterW - Math.round(36 * root.d)
                            spacing: Math.round(8 * root.d)
                            Rectangle { width: Math.round(24 * root.d); height: Math.max(1, Math.round(2 * root.d)); radius: height / 2; color: IrisStyle.accent }
                            Row {
                                width: parent.width
                                spacing: Math.round(6 * root.d)
                                SmartAppIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: IrisPieces.appIcon(String(actions.subject?.app_id ?? ""))
                                    fallback: "application-x-executable"
                                    iconSize: Math.round(16 * root.d)
                                }
                                IrisText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - Math.round(22 * root.d)
                                    text: actions.subject ? root.nameOf(actions.subject) : ""
                                    font.weight: IrisStyle.weight(Font.DemiBold)
                                    elide: Text.ElideRight
                                }
                            }
                            IrisText {
                                width: parent.width
                                text: actions.subject ? String(actions.subject.title ?? "") : ""
                                role: IrisText.Meta
                                color: IrisStyle.muted
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                            Grid {
                                columns: 3
                                spacing: Math.round(2 * root.d)
                                ActionButton { materialIcon: "arrow_outward"; label: Translation.tr("Go to this window"); onClicked: root.activate() }
                                ActionButton { materialIcon: "arrow_upward"; label: Translation.tr("Send to the workspace above"); enabled: !actions.aside; onClicked: root.sendSubject(-1) }
                                ActionButton { materialIcon: "arrow_downward"; label: Translation.tr("Send to the workspace below"); enabled: !actions.aside; onClicked: root.sendSubject(1) }
                                ActionButton { materialIcon: actions.aside ? "unarchive" : "inventory_2"; label: actions.aside ? Translation.tr("Bring back") : Translation.tr("Set aside"); onClicked: root.stashSubject() }
                                ActionButton { materialIcon: "picture_in_picture_alt"; label: Translation.tr("Float or tile"); enabled: !actions.aside; onClicked: root.floatSubject() }
                                ActionButton { materialIcon: "close"; danger: true; label: Translation.tr("Close window"); onClicked: root.closeSubject() }
                            }
                        }
                    }

                    // ---- The shelf: where you just were and what you set aside.
                    Item {
                        id: shelf
                        visible: scene.hasShelf
                        x: scene.pad
                        y: scene.shelfY
                        width: scene.width - scene.pad * 2
                        height: scene.shelfH
                        readonly property real step: scene.thumbW + Math.round(8 * root.d)
                        readonly property real room: shelf.width - Math.round(8 * root.d)
                        readonly property int fits: Math.max(1, Math.floor(shelf.room / shelf.step))
                        readonly property int recentCount: Math.min(root.recentIds.length, root.stashedIds.length > 0 ? Math.max(1, Math.ceil(shelf.fits * 0.6)) : shelf.fits)
                        readonly property int asideCount: Math.min(root.stashedIds.length, Math.max(0, shelf.fits - shelf.recentCount))
                        readonly property real recentW: shelf.recentCount * shelf.step

                        Item {
                            visible: shelf.recentCount > 0
                            width: shelf.recentW
                            height: parent.height
                            ShelfLabel { y: 0; text: Translation.tr("Recent") }
                            Row {
                                y: Math.round(20 * root.d)
                                spacing: Math.round(8 * root.d)
                                Repeater {
                                    model: root.recentIds.slice(0, shelf.recentCount)
                                    IrisOrbitThumb {
                                        id: recent
                                        required property int modelData
                                        readonly property var window: root.windowMap[recent.modelData] ?? ({})
                                        width: scene.thumbW
                                        height: scene.thumbH
                                        windowId: recent.modelData
                                        appId: String(recent.window.app_id ?? "")
                                        title: root.titleOf(recent.window)
                                        previews: root.previewsOn
                                        decodeSize: Qt.size(320, 192)
                                        shelved: true
                                        cursor: root.cursorId === recent.modelData
                                        dimmed: root.matches !== null && root.matches[recent.modelData] !== true
                                        dimOpacity: 1 - Math.max(0, Math.min(95, Number(root.options?.dimMatches ?? 78))) / 100
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                            Accessible.role: Accessible.Button
                                            Accessible.name: recent.title
                                            onClicked: mouse => mouse.button === Qt.MiddleButton ? NiriService.closeWindow(recent.modelData) : root.goToWindow(recent.modelData)
                                        }
                                    }
                                }
                            }
                        }
                        Item {
                            visible: shelf.asideCount > 0
                            x: shelf.recentW + (shelf.recentCount > 0 ? Math.round(8 * root.d) : 0)
                            width: shelf.asideCount * shelf.step
                            height: parent.height
                            ShelfLabel { y: 0; text: Translation.tr("Set aside") }
                            Row {
                                y: Math.round(20 * root.d)
                                spacing: Math.round(8 * root.d)
                                Repeater {
                                    model: root.stashedIds.slice(0, shelf.asideCount)
                                    IrisOrbitThumb {
                                        id: aside
                                        required property int modelData
                                        readonly property var window: root.windowMap[aside.modelData] ?? ({})
                                        width: scene.thumbW
                                        height: scene.thumbH
                                        windowId: aside.modelData
                                        appId: String(aside.window.app_id ?? "")
                                        title: root.titleOf(aside.window)
                                        previews: root.previewsOn
                                        decodeSize: Qt.size(320, 192)
                                        shelved: true
                                        minimised: true
                                        cursor: root.cursorId === aside.modelData
                                        dimmed: root.matches !== null && root.matches[aside.modelData] !== true
                                        dimOpacity: 1 - Math.max(0, Math.min(95, Number(root.options?.dimMatches ?? 78))) / 100
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            Accessible.role: Accessible.Button
                                            Accessible.name: aside.title
                                            onClicked: root.goToWindow(aside.modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ---- Keys, once, quietly.
                    IrisText {
                        visible: root.options?.hints ?? true
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: scene.hintsY
                        text: root.swapped
                            ? Translation.tr("← → workspaces   ↑ ↓ windows   ↵ go   Ctrl M set aside   Del close")
                            : Translation.tr("↑ ↓ workspaces   ← → windows   ↵ go   Ctrl M set aside   Del close")
                        role: IrisText.Meta
                        color: IrisStyle.muted
                    }
                }
            }
        }
    }
}
