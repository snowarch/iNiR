pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.iris.frame
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.dock
import qs.modules.iris.pieces
import qs.modules.iris.settings

// Spotlight lives in the chassis window of its output, so its body, its content and the Island it grows
// from are one surface: drawn and moved in the same frame.
Item {
    id: root

    property var screen: null
    readonly property bool here: (root.screen?.name ?? "") === (GlobalStates.focusedScreen?.name ?? "")
    readonly property bool present: root.here && (GlobalStates.searchOpen || (content.item?.progress ?? 0) > 0)
    readonly property bool armed: root.here && GlobalStates.searchOpen && (content.item?.armed ?? false)

    readonly property var options: Config.options?.iris?.palette ?? ({})
    readonly property int configuredResultLimit: Math.max(3, Math.min(14, Number(root.options?.maxResults ?? 8)))
    readonly property int heightResultLimit: Math.max(3, Math.floor(
        Math.max(180, ((root.screen?.height ?? 1080) * 0.72) - (120 * IrisStyle.density))
        / Math.max(42, 50 * IrisStyle.density)))
    readonly property int clipboardResultLimit: Math.max(3, Math.min(20, Number(root.options?.clipboardResults ?? 8)))
    readonly property int clipboardHeightLimit: Math.max(3, Math.floor(
        Math.max(180, ((root.screen?.height ?? 1080) * 0.72) - (120 * IrisStyle.density))
        / Math.max(48, 52 * IrisStyle.density)))
    readonly property int resultLimit: root.clipboardMode
        ? Math.min(root.clipboardResultLimit, root.clipboardHeightLimit)
        : Math.min(root.configuredResultLimit, root.heightResultLimit)
    function edgeClear(edge: string): real {
        let held = IrisFrame.inset(edge)
        if ((Config.options?.iris?.dock?.enable ?? true) && IrisFrame.dockEdge === edge)
            held = Math.max(held, IrisFrame.band + IrisFrame.dockBand + IrisFrame.dockMargin)
        return held - IrisFrame.band + IrisFrame.musicReach(edge) + Math.round(12 * IrisStyle.density)
    }
    // Results follow the query once typing pauses, the same moment the apps answer: searching on every key
    // ran iRiS's search twice per key and rebuilt every row two or three times (60-100 ms of the GUI thread).
    readonly property string settled: LauncherSearch.settledQuery
    readonly property bool mathQuery: /[0-9]/.test(root.settled)
    readonly property var launcherResults: (LauncherSearch.results ?? [])
        .filter(entry => String(entry?.name ?? "").length > 0
            && (root.mathQuery || entry?.type !== Translation.tr("Math")))
    // A plain query also reaches iRiS's switches, actions and options (IrisSearch): a strong one leads when no
    // word of the first app's name starts with what was typed, the rest follow the apps; the calculator, command
    // and web come last.
    readonly property bool plainQuery: {
        const prefix = Config.options?.search?.prefix ?? ({})
        const q = root.settled
        return q.trim().length > 0 && ![prefix.clipboard ?? ";", prefix.emojis ?? ":", prefix.math ?? "=", prefix.shellCommand ?? "$",
            prefix.webSearch ?? "?", prefix.action ?? "/", prefix.app ?? ">"].some(key => String(key).length > 0 && q.startsWith(key))
    }
    function rowOf(entry: var): var {
        const opens = entry.kind === "setting" || entry.kind === "section"
        const widget = entry.kind === "widget"
        return { name: entry.name, comment: entry.detail, iconName: entry.icon, tint: entry.tint, area: entry.areaName, areaTint: entry.tint,
            iconType: LauncherSearchResult.IconType.Material,
            type: opens ? Translation.tr("Settings") : widget ? Translation.tr("Widget") : Translation.tr("Action"),
            verb: opens ? Translation.tr("Open") : widget ? (entry.on ? Translation.tr("Show") : Translation.tr("Add"))
                : entry.kind === "switch" ? Translation.tr("Switch") : entry.pick ? Translation.tr("Apply") : Translation.tr("Run"),
            isOn: typeof entry.isOn === "function" ? entry.isOn : null, pick: entry.pick, keepOpen: entry.keepOpen, execute: entry.run, fuzzy: true }
    }
    readonly property var irisHits: root.plainQuery ? IrisSearch.search(root.settled).filter(hit => hit.score >= 0.7) : []
    readonly property var blendedResults: {
        if (!root.plainQuery) return root.launcherResults
        const hits = root.irisHits
        const acts = hits.filter(hit => hit.entry.kind !== "setting" && hit.entry.kind !== "section").slice(0, 4)
        const opens = hits.filter(hit => hit.entry.kind === "setting" || hit.entry.kind === "section").slice(0, 3)
        // Apps keep the lead, but three of them are enough to leave room for what the query also names.
        const allApps = root.launcherResults.filter(entry => entry?.type === Translation.tr("App"))
        const apps = hits.length > 0 ? allApps.slice(0, 3) : allApps
        const rest = root.launcherResults.filter(entry => entry?.type !== Translation.tr("App"))
        // "code" names Visual Studio Code: an app keeps the lead when any of its words starts with what was typed.
        const typed = IrisSearch.tokens(root.settled).join(" ")
        const appLeads = apps.length > 0 && typed.length > 0
            && (" " + IrisSearch.tokens(apps[0].name).join(" ")).includes(" " + typed)
        const best = acts.concat(opens).sort((a, b) => b.score - a.score)[0] ?? null
        if (best && best.score >= 0.9 && !appLeads) {
            const others = acts.concat(opens).filter(hit => hit !== best)
            return [root.rowOf(best.entry)].concat(apps, others.filter(hit => acts.includes(hit)).map(hit => root.rowOf(hit.entry)),
                others.filter(hit => opens.includes(hit)).map(hit => root.rowOf(hit.entry)), allApps.slice(apps.length), rest)
        }
        return apps.concat(acts.map(hit => root.rowOf(hit.entry)), opens.map(hit => root.rowOf(hit.entry)), allApps.slice(apps.length), rest)
    }
    // "/" is a list to browse and scrolls; a plain query stays a short answer.
    readonly property var searchResults: root.actionMode ? root.actionResults.slice(0, 120)
        : root.blendedResults.slice(0, root.resultLimit + (root.clipboardMode ? root.clipboardExtra : 0))
    // The clipboard opens on a first page (Settings › Spotlight › Entries shown) and keeps going as you
    // scroll or step past its end, through the whole history.
    property int clipboardExtra: 0
    readonly property int clipboardTotal: root.clipboardMode ? root.launcherResults.length : 0
    function loadMoreClipboard(): void {
        if (root.clipboardMode && root.searchResults.length < root.clipboardTotal) root.clipboardExtra += root.resultLimit
    }

    // "/" lists what iRiS can flip, apply or run from here, grouped by area; typed words narrow it the forgiving
    // way IrisSearch matches. A switch stays open to show its new state; the rest run and close.
    readonly property string actionPrefix: Config.options?.search?.prefix?.action ?? "/"
    readonly property bool actionMode: root.settled.startsWith(root.actionPrefix)
    // One header per area: areas follow their best row, rows keep their rank inside the area.
    function byArea(entries: var): var {
        const order = [], groups = ({})
        for (const entry of entries) {
            const key = String(entry.areaName ?? "")
            if (!groups[key]) { groups[key] = []; order.push(key) }
            groups[key].push(entry)
        }
        return order.reduce((out, key) => out.concat(groups[key]), [])
    }
    readonly property var actionResults: {
        if (!root.actionMode) return []
        const query = root.settled.slice(root.actionPrefix.length).trim()
        if (query.length > 0) return root.byArea(IrisSearch.search(query).map(hit => hit.entry)).map(entry => root.rowOf(entry))
        // Nothing typed: the everyday switches first, then everything else by area. While widgets are being
        // arranged, the widgets lead: that is what "/" was asked for there.
        const doable = IrisSearch.entries().filter(entry => entry.kind !== "setting" && entry.kind !== "section")
        const arranging = GlobalStates.widgetEditMode ? doable.filter(entry => entry.kind === "widget") : []
        const everyday = doable.filter(entry => entry.priority < 50).sort((a, b) => a.priority - b.priority)
        return arranging.map(entry => root.rowOf(entry))
            .concat(everyday.map(entry => Object.assign(root.rowOf(entry), { area: Translation.tr("Suggested"), areaTint: null })))
            .concat(root.byArea(doable.filter(entry => entry.priority >= 50 && !(GlobalStates.widgetEditMode && entry.kind === "widget"))).map(entry => root.rowOf(entry)))
    }

    readonly property var island: GlobalStates.irisIslandGeometry?.[root.screen?.name ?? ""] ?? null
    readonly property bool fromIsland: String(root.options?.opens ?? "floating") === "island"
        && root.island !== null && root.island.width > 0
    readonly property bool islandBottom: root.island?.bottomEdge ?? false
    readonly property string islandSide: root.island?.vertical ? String(root.island.edge) : ""
    readonly property bool joinsEdge: root.fromIsland && IrisFrame.notch
    readonly property bool joinsFrame: root.joinsEdge && IrisFrame.framed

    readonly property bool browsing: root.settled.length === 0
    readonly property var suggestions: {
        return IrisDockOrder.entries.filter(app => app.appId !== "SEPARATOR").slice(0, 8).map(app => {
            const entry = AppSearch.lookupDesktopEntry(app.appId)
            const windows = app.toplevels ?? []
            return {
                appId: app.appId,
                name: entry?.name ?? app.appId,
                iconName: IrisPieces.appIcon(app.appId),
                iconType: LauncherSearchResult.IconType.System,
                running: windows.length > 0,
                verb: windows.length > 0 ? Translation.tr("Switch to") : Translation.tr("Open"),
                execute: () => {
                    const focused = windows.find(window => window.activated) ?? windows[0]
                    if (focused && CompositorService.isNiri && focused.niriWindowId !== undefined)
                        NiriService.focusWindow(focused.niriWindowId)
                    else if (focused) focused.activate()
                    else if (entry) AppSearch.launchEntry(entry)
                }
            }
        })
    }
    readonly property var visibleResults: root.browsing ? root.suggestions : root.searchResults
    // The rows keep their delegate while the same result stays (ScriptModel by rowKey): a plain array made the
    // Repeater destroy and build every row on each update, ~2.5 ms a row.
    readonly property var keyedResults: {
        const seen = ({})
        const single = [Translation.tr("Math"), Translation.tr("Command"), Translation.tr("Web")]
        return (root.browsing ? [] : root.searchResults).map(entry => {
            const type = String(entry?.type ?? "")
            let key = single.includes(type) ? type
                : type + "|" + String(entry?.rawValue ?? entry?.id ?? (String(entry?.name ?? "") + "|" + String(entry?.comment ?? "")))
            seen[key] = (seen[key] ?? 0) + 1
            if (seen[key] > 1) key += "#" + seen[key]
            return Object.assign({}, entry, { rowKey: key })
        })
    }
    readonly property string clipboardPrefix: Config.options?.search?.prefix?.clipboard ?? ";"
    readonly property bool clipboardMode: root.settled.startsWith(root.clipboardPrefix)
    onClipboardModeChanged: if (root.clipboardMode) Cliphist.refresh()
    property int selectedIndex: 0
    property bool pointerSelectionArmed: false
    property point lastPointerPosition: Qt.point(-1, -1)

    function disarmPointerSelection(resetPosition = false) {
        root.pointerSelectionArmed = false
        if (resetPosition)
            root.lastPointerPosition = Qt.point(-1, -1)
    }

    function armPointerSelection(area, event) {
        const point = area.mapToItem(root.contentItem, event.x, event.y)
        if (root.lastPointerPosition.x < 0 || root.lastPointerPosition.y < 0) {
            root.lastPointerPosition = Qt.point(point.x, point.y)
            return false
        }
        const moved = Math.abs(point.x - root.lastPointerPosition.x) > 0.5
            || Math.abs(point.y - root.lastPointerPosition.y) > 0.5
        root.lastPointerPosition = Qt.point(point.x, point.y)
        if (moved) root.pointerSelectionArmed = true
        return root.pointerSelectionArmed
    }

    visible: root.present

    function focusInput(): void {
        Qt.callLater(() => content.item?.focusInput())
    }

    function takeRequestedQuery(): void {
        if (GlobalStates.irisSpotlightQuery.length === 0) return
        LauncherSearch.query = GlobalStates.irisSpotlightQuery
        GlobalStates.irisSpotlightQuery = ""
    }
    Component.onCompleted: if (root.here && GlobalStates.searchOpen) { root.takeRequestedQuery(); root.focusInput() }

    Connections {
        target: GlobalStates
        function onSearchOpenChanged(): void {
            if (!GlobalStates.searchOpen || !root.here) return
            root.selectedIndex = 0
            root.disarmPointerSelection(true)
            root.takeRequestedQuery()
            root.focusInput()
        }
        function onIrisSpotlightQueryChanged(): void {
            if (GlobalStates.searchOpen && root.here) root.takeRequestedQuery()
        }
    }

    onVisibleChanged: if (!visible) LauncherSearch.query = ""

    Connections {
        target: LauncherSearch
        function onQueryChanged(): void {
            root.selectedIndex = 0
            root.clipboardExtra = 0
            root.disarmPointerSelection()
        }
    }

    function executeSelected(): void {
        const entry = root.visibleResults[root.selectedIndex]
        if (!entry || typeof entry.execute !== "function") return
        entry.execute()
        if (!entry.keepOpen) GlobalStates.searchOpen = false
    }

    function moveSelection(step: int): void {
        const count = root.visibleResults.length
        if (count === 0) return
        if (step > 0 && root.selectedIndex + step >= count - 2) root.loadMoreClipboard()
        root.selectedIndex = Math.max(0, Math.min(root.visibleResults.length - 1, root.selectedIndex + step))
    }

    function handleKey(event): void {
        const forward = event.key === Qt.Key_Down || event.key === Qt.Key_Tab
            || (root.browsing && event.key === Qt.Key_Right)
        const backward = event.key === Qt.Key_Up || event.key === Qt.Key_Backtab
            || (root.browsing && event.key === Qt.Key_Left)
        if (forward) {
            root.disarmPointerSelection()
            root.moveSelection(1)
        } else if (backward) {
            root.disarmPointerSelection()
            root.moveSelection(-1)
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.executeSelected()
        } else if (root.clipboardMode && event.key === Qt.Key_Delete) {
            const entry = root.visibleResults[root.selectedIndex]?.rawValue
            if (!entry) return
            Cliphist.deleteEntry(entry)
            root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, root.visibleResults.length - 2))
        } else {
            return
        }
        event.accepted = true
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.here && GlobalStates.searchOpen
        onActivated: {
            if (LauncherSearch.query.length > 0) LauncherSearch.query = ""
            else GlobalStates.searchOpen = false
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -IrisFrame.band
        enabled: root.armed
        onClicked: GlobalStates.searchOpen = false
    }

    Loader {
        id: content
        anchors.fill: parent
        focus: true
        sourceComponent: spotlightComponent
    }

    Component {
        id: spotlightComponent

        Item {
            id: stage
            readonly property alias progress: surface.progress
            readonly property alias armed: surface.armed
            readonly property Item surfaceItem: surface
            readonly property real d: IrisStyle.density
            property bool confirmWipe: false
            function focusInput(): void { input.forceActiveFocus() }

            Timer {
                id: wipeDisarm
                interval: 3000
                onTriggered: stage.confirmWipe = false
            }

            function escapeHtml(value: string): string {
                return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
            }
            function emphasised(name: string): string {
                const query = root.settled.trim()
                const at = query.length > 0 ? name.toLowerCase().indexOf(query.toLowerCase()) : -1
                const dim = IrisStyle.textSecondary
                if (at < 0) return stage.escapeHtml(name)
                return "<font color='" + dim + "'>" + stage.escapeHtml(name.slice(0, at)) + "</font>"
                    + "<b>" + stage.escapeHtml(name.slice(at, at + query.length)) + "</b>"
                    + "<font color='" + dim + "'>" + stage.escapeHtml(name.slice(at + query.length)) + "</font>"
            }

            function sectionOf(entry): string {
                if (root.actionMode && entry?.fuzzy) return String(entry.area ?? "")
                const type = String(entry?.type ?? "")
                if (type === Translation.tr("App")) return Translation.tr("Applications")
                if (type === Translation.tr("Action")) return Translation.tr("Actions")
                if (type === Translation.tr("Settings")) return Translation.tr("Settings")
                if (type === Translation.tr("Math")) return Translation.tr("Calculator")
                if (type === Translation.tr("Command")) return Translation.tr("Run command")
                if (type === Translation.tr("Web")) return Translation.tr("Search the web")
                return type.length > 0 ? type : Translation.tr("Other")
            }
            function sectionAt(index: int): string {
                if (root.clipboardMode) return Translation.tr("Clipboard history · %1").arg(root.clipboardTotal)
                return index === 0 ? Translation.tr("Top hit") : stage.sectionOf(root.visibleResults[index])
            }
            function kindTint(type: string): color {
                if (type === Translation.tr("Command")) return IrisStyle.identity.gray
                if (type === Translation.tr("Web")) return IrisStyle.identity.blue
                if (type === Translation.tr("Math")) return IrisStyle.identity.orange
                if (type === Translation.tr("Action")) return IrisStyle.identity.purple
                if (type === Translation.tr("Emoji")) return IrisStyle.identity.pink
                return IrisStyle.identity.teal
            }
            function clipMark(value: string): var {
                if (/^(https?|ftp):\/\//i.test(value)) return { glyph: "link", tint: IrisStyle.identity.blue }
                if (/^(\/|~\/)[^\s]/.test(value)) return { glyph: "folder_open", tint: IrisStyle.identity.gray }
                return { glyph: "subject", tint: IrisStyle.identity.teal }
            }

            RectangularShadow {
                x: surface.x + surface.lerp(surface.from.x, 0)
                y: surface.y + surface.lerp(surface.from.y, 0) + 8 * stage.d * surface.progress
                width: surface.lerp(surface.from.width, surface.width)
                height: surface.lerp(surface.from.height, surface.height)
                radius: Math.min(width / 2, height / 2, surface.lerp(surface.fromRadius, surface.radius))
                blur: 32 * stage.d
                spread: -6 * stage.d
                color: IrisStyle.shadow
                visible: !root.fromIsland
                opacity: IrisStyle.shadowAt(surface.progress)
            }
            IrisMorphSurface {
                id: surface
                compositorBlurred: true
                open: root.here && GlobalStates.searchOpen
                settles: true
                motionSurface: "spotlight"
                fieldBacked: true
                chassisKey: "spotlight"
                chassisJoin: {
                    if (!root.joinsEdge) return {}
                    const grow = root.islandBottom ? "bottom" : "top"
                    if (root.joinsFrame) return { id: "spotlight", joins: "frame", fuse: IrisStyle.fuseEdge, grow: grow }
                    const k = IrisStyle.fuseEdge, deep = Math.max(8, k)
                    return { id: "spotlight", joins: "spotlightEdge", fuse: k, grow: grow,
                        edge: { x: -2 * k, y: root.islandBottom ? root.height + 1 : -deep - 1, width: root.width + 4 * k, height: deep,
                            radius: 0, paints: true, fuse: 0, id: "spotlightEdge", glass: IrisStyle.surfaceGlass("spotlight") } }
                }
                readonly property real dissolve: root.fromIsland ? IrisStyle.ramp(surface.progress, 0, 0.14) : 1
                origin: root.fromIsland ? ({ x: root.island.x - IrisFrame.band, y: root.island.y - IrisFrame.band,
                    width: root.island.width, height: root.island.height, radius: Math.min(root.island.width, root.island.height) / 2 }) : null
                originShare: root.fromIsland ? 1 : IrisStyle.absorbShare
                color: root.fromIsland ? ColorUtils.applyAlpha(IrisStyle.bodySurface, surface.dissolve) : IrisStyle.surface
                light: root.fromIsland ? "transparent" : IrisStyle.surfaceLight("spotlight", IrisStyle.wallpaperLight)
                lightFrom: IrisFrame.islandEdge
                radius: IrisStyle.surfaceRadius("spotlight", IrisStyle.radiusPanel)
                width: Math.max(320, Math.min(root.width - 32, Math.max(480, Number(root.options?.width ?? 640) * stage.d)))
                x: !root.fromIsland ? (root.width - width) / 2
                    : root.islandSide === "left" ? Math.round(root.island.x - IrisFrame.band)
                    : root.islandSide === "right" ? Math.round(root.island.x - IrisFrame.band + root.island.width - width)
                    : Math.round(Math.max(8, Math.min(root.width - width - 8, root.island.x - IrisFrame.band + root.island.width / 2 - width / 2)))
                y: !root.fromIsland ? Math.max(72, Math.round(root.height * 0.2))
                    : root.islandSide.length > 0 ? Math.round(Math.max(8, Math.min(root.height - height - 8,
                        root.island.y - IrisFrame.band + root.island.height / 2 - height / 2)))
                    : root.islandBottom ? Math.round(root.island.y - IrisFrame.band + root.island.height - height)
                    : Math.round(root.island.y - IrisFrame.band)
                readonly property real room: {
                    const top = root.edgeClear("top")
                    const bottom = root.edgeClear("bottom")
                    if (root.fromIsland && root.islandSide.length > 0) return root.height - top - bottom
                    if (root.fromIsland && root.islandBottom) return root.island.y - IrisFrame.band + root.island.height - top
                    const y = root.fromIsland ? root.island.y - IrisFrame.band : Math.max(72, Math.round(root.height * 0.2))
                    return root.height - y - bottom
                }
                height: Math.min(body.implicitHeight, Math.max(Math.round(160 * stage.d), surface.room))
                onClosed: LauncherSearch.query = ""
                onSettledChanged: if (surface.settled && surface.open) stage.focusInput()
                Behavior on height {
                    enabled: surface.settled
                    NumberAnimation { duration: IrisStyle.duration(150); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
                }

                MouseArea { anchors.fill: parent }

                GridLayout {
                    id: body
                    readonly property bool fieldLast: root.fromIsland && root.islandBottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: surface.height
                    columns: 1
                    rowSpacing: 0
                    columnSpacing: 0

                    Item {
                        Layout.row: body.fieldLast ? 3 : 0
                        Layout.fillWidth: true
                        implicitHeight: Math.round(68 * stage.d)

                        MaterialSymbol {
                            id: searchGlyph
                            anchors.left: parent.left
                            anchors.leftMargin: 24 * stage.d
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search"
                            iconSize: Math.round(22 * stage.d)
                            color: input.text.length > 0 ? IrisStyle.accent : IrisStyle.subtext
                            Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                        }
                        Rectangle {
                            id: modeToken
                            readonly property var modes: {
                                const prefix = Config.options?.search?.prefix ?? ({})
                                return [
                                    { key: prefix.clipboard ?? ";", label: Translation.tr("Clipboard"), glyph: "content_paste" },
                                    { key: prefix.math ?? "=", label: Translation.tr("Calculator"), glyph: "calculate" },
                                    { key: prefix.action ?? "/", label: Translation.tr("Actions"), glyph: "bolt" },
                                    { key: prefix.emojis ?? ":", label: Translation.tr("Emoji"), glyph: "mood" },
                                    { key: prefix.webSearch ?? "?", label: Translation.tr("Web"), glyph: "travel_explore" },
                                    { key: prefix.shellCommand ?? "$", label: Translation.tr("Command"), glyph: "terminal" }
                                ]
                            }
                            readonly property var mode: modeToken.modes.find(m => String(m.key).length > 0 && LauncherSearch.query.startsWith(m.key)) ?? null
                            visible: modeToken.mode !== null
                            anchors.right: parent.right
                            anchors.rightMargin: 16 * stage.d
                            anchors.verticalCenter: parent.verticalCenter
                            height: Math.round(26 * stage.d)
                            width: modeRow.implicitWidth + Math.round(20 * stage.d)
                            radius: height / 2
                            color: IrisStyle.tintFill(IrisStyle.accent)
                            Row {
                                id: modeRow
                                anchors.centerIn: parent
                                spacing: 5 * stage.d
                                MaterialSymbol {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modeToken.mode?.glyph ?? ""
                                    fill: 1
                                    iconSize: Math.round(14 * stage.d)
                                    color: IrisStyle.accent
                                }
                                IrisText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modeToken.mode?.label ?? ""
                                    color: IrisStyle.accent
                                    font.pixelSize: IrisStyle.typeMeta
                                    font.weight: IrisStyle.weight(Font.DemiBold)
                                }
                            }
                        }
                        TextInput {
                            id: input
                            anchors.left: searchGlyph.right
                            anchors.leftMargin: 12 * stage.d
                            anchors.right: modeToken.visible ? modeToken.left : parent.right
                            anchors.rightMargin: 20 * stage.d
                            anchors.verticalCenter: parent.verticalCenter
                            text: LauncherSearch.query
                            color: IrisStyle.text
                            selectionColor: IrisStyle.accentContainer
                            selectedTextColor: IrisStyle.inkOnAccentContainer
                            font.family: IrisStyle.fontMain
                            font.pixelSize: IrisStyle.typeTitleLarge
                            clip: true
                            focus: true
                            onTextChanged: if (LauncherSearch.query !== text) LauncherSearch.query = text
                            Keys.onPressed: event => root.handleKey(event)

                            IrisText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: input.text.length === 0
                                text: Translation.tr("Apps, settings, actions…")
                                color: IrisStyle.muted
                                font.pixelSize: input.font.pixelSize
                                font.weight: IrisStyle.weight(Font.Normal)
                            }
                        }
                    }

                    Rectangle {
                        Layout.row: body.fieldLast ? 2 : 1
                        Layout.fillWidth: true
                        Layout.leftMargin: 24 * stage.d
                        Layout.rightMargin: 24 * stage.d
                        implicitHeight: 1
                        visible: results.visible || browse.visible
                        color: IrisStyle.hairline
                    }

                    ColumnLayout {
                        id: browse
                        Layout.row: body.fieldLast ? 1 : 2
                        Layout.fillWidth: true
                        visible: root.browsing && (root.suggestions.length > 0 || hints.visible)
                        spacing: 0

                        IrisText {
                            visible: root.suggestions.length > 0
                            Layout.leftMargin: 24 * stage.d
                            Layout.topMargin: 16 * stage.d
                            text: Translation.tr("Suggestions")
                            color: IrisStyle.muted
                            font.pixelSize: IrisStyle.typeMeta
                            font.weight: IrisStyle.weight(Font.DemiBold)
                        }

                        Item {
                            id: tiles
                            visible: root.suggestions.length > 0
                            Layout.fillWidth: true
                            Layout.leftMargin: 16 * stage.d
                            Layout.rightMargin: 16 * stage.d
                            Layout.topMargin: 6 * stage.d
                            readonly property real tileWidth: width / 8
                            // Icon, dot and the name; a second line only while one of the names needs it.
                            // Recounted by the tiles: a binding over itemAt() never hears a label wrap.
                            property bool wraps: false
                            function recount(): void {
                                let wraps = false
                                for (let i = 0; i < tileRepeater.count; ++i)
                                    if ((tileRepeater.itemAt(i)?.lines ?? 1) > 1) wraps = true
                                tiles.wraps = wraps
                            }
                            Timer { id: recountLater; interval: 0; onTriggered: tiles.recount() }
                            implicitHeight: Math.round((tiles.wraps ? 104 : 92) * stage.d)

                            Rectangle {
                                visible: root.suggestions.length > 0
                                x: Math.min(root.selectedIndex, root.suggestions.length - 1) * tiles.tileWidth + 2 * stage.d
                                width: tiles.tileWidth - 4 * stage.d
                                height: tiles.height
                                radius: IrisStyle.radiusTile
                                color: IrisStyle.tintFill(IrisStyle.accent)
                                Behavior on x { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                            }

                            Row {
                                anchors.fill: parent
                                Repeater {
                                    id: tileRepeater
                                    onItemAdded: tiles.recount()
                                    // The removed tile still answers itemAt() during the signal.
                                    onItemRemoved: recountLater.restart()
                                    // Keyed by app: suggestions rebuild on every window event.
                                    model: ScriptModel {
                                        objectProp: "appId"
                                        values: root.browsing ? root.suggestions : []
                                    }
                                    MouseArea {
                                        id: tile
                                        required property var modelData
                                        required property int index
                                        readonly property var live: root.suggestions[tile.index] ?? tile.modelData
                                        readonly property int lines: tileLabel.lineCount
                                        onLinesChanged: tiles.recount()
                                        width: tiles.tileWidth
                                        height: tiles.height
                                        hoverEnabled: true
                                        cursorShape: root.pointerSelectionArmed ? Qt.PointingHandCursor : Qt.BlankCursor
                                        Accessible.role: Accessible.Button
                                        Accessible.name: tile.modelData.name
                                        onPositionChanged: event => {
                                            if (root.armPointerSelection(tile, event) && root.selectedIndex !== tile.index)
                                                root.selectedIndex = tile.index
                                        }
                                        onClicked: {
                                            root.pointerSelectionArmed = true
                                            root.selectedIndex = tile.index
                                            root.executeSelected()
                                        }

                                        SmartAppIcon {
                                            id: tileIcon
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: 12 * stage.d
                                            icon: tile.modelData.iconName
                                            fallback: "application-x-executable"
                                            iconSize: Math.round(46 * stage.d)
                                            scale: tile.pressed ? IrisStyle.pressScale(0.92) : 1
                                            Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                                        }
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.top: tileIcon.bottom
                                            anchors.topMargin: 3 * stage.d
                                            visible: tile.live.running
                                            width: 4 * stage.d
                                            height: width
                                            radius: width / 2
                                            color: IrisStyle.textTertiary
                                        }
                                        IrisText {
                                            id: tileLabel
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.leftMargin: 4 * stage.d
                                            anchors.rightMargin: 4 * stage.d
                                            anchors.top: tileIcon.bottom
                                            anchors.topMargin: 10 * stage.d
                                            horizontalAlignment: Text.AlignHCenter
                                            // An AppImage's version ("limusic (1.1.0)") is not its name; a long name takes a
                                            // second line at the same size ("Visual Studio / Code") before it elides.
                                            text: String(tile.modelData.name ?? "").replace(/\s*\(v?\d[^)]*\)\s*$/, "")
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                            font.pixelSize: IrisStyle.typeFootnote
                                            color: root.selectedIndex === tile.index ? IrisStyle.text : IrisStyle.subtext
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: hints.visible
                            Layout.fillWidth: true
                            Layout.leftMargin: 24 * stage.d
                            Layout.rightMargin: 24 * stage.d
                            Layout.topMargin: 12 * stage.d
                            implicitHeight: 1
                            color: IrisStyle.hairline
                        }

                        GridLayout {
                            id: hints
                            columns: 3
                            columnSpacing: 8 * stage.d
                            rowSpacing: 4 * stage.d
                            visible: root.options?.showHints ?? true
                            Layout.fillWidth: true
                            Layout.leftMargin: 16 * stage.d
                            Layout.rightMargin: 16 * stage.d
                            Layout.topMargin: 12 * stage.d
                            Layout.bottomMargin: 20 * stage.d
                            Repeater {
                                model: {
                                    const prefix = Config.options?.search?.prefix ?? ({})
                                    return [
                                        { key: prefix.clipboard ?? ";", label: Translation.tr("Clipboard") },
                                        { key: prefix.math ?? "=", label: Translation.tr("Calculator") },
                                        { key: prefix.action ?? "/", label: Translation.tr("Actions") },
                                        { key: prefix.emojis ?? ":", label: Translation.tr("Emoji") },
                                        { key: prefix.webSearch ?? "?", label: Translation.tr("Web") },
                                        { key: prefix.shellCommand ?? "$", label: Translation.tr("Command") }
                                    ]
                                }
                                IrisButton {
                                    id: hint
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    implicitHeight: Math.round(34 * stage.d)
                                    buttonRadius: IrisStyle.radiusRow
                                    buttonRadiusPressed: IrisStyle.radiusRow
                                    colBackground: "transparent"
                                    colBackgroundHover: IrisStyle.fillHover
                                    Accessible.name: hint.modelData.label
                                    onClicked: { LauncherSearch.query = hint.modelData.key; stage.focusInput() }
                                    RowLayout {
                                        id: hintRow
                                        anchors.fill: parent
                                        anchors.leftMargin: 10 * stage.d
                                        anchors.rightMargin: 10 * stage.d
                                        spacing: 8 * stage.d
                                        Rectangle {
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.preferredWidth: Math.max(20 * stage.d, keyText.implicitWidth + 8 * stage.d)
                                            Layout.preferredHeight: Math.round(20 * stage.d)
                                            radius: IrisStyle.radiusMicro
                                            color: hint.buttonHovered ? IrisStyle.tintFillHover(IrisStyle.accent) : IrisStyle.fill
                                            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                                            IrisText {
                                                id: keyText
                                                anchors.centerIn: parent
                                                text: hint.modelData.key
                                                color: hint.buttonHovered ? IrisStyle.accent : IrisStyle.subtext
                                                font.family: Appearance.font.family.monospace
                                                font.pixelSize: IrisStyle.typeMeta
                                                font.weight: IrisStyle.weight(Font.Bold)
                                            }
                                        }
                                        IrisText {
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            text: hint.modelData.label
                                            color: hint.buttonHovered ? IrisStyle.text : IrisStyle.subtext
                                            font.pixelSize: IrisStyle.typeMeta
                                            font.weight: IrisStyle.weight(Font.Medium)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: results
                        Layout.row: body.fieldLast ? 0 : 3
                        Layout.fillWidth: true
                        visible: !root.browsing
                        implicitHeight: resultColumn.implicitHeight + 16 * stage.d
                        Layout.fillHeight: true
                        Layout.minimumHeight: Math.min(results.implicitHeight, Math.round(96 * stage.d))
                        function reveal(index: int): void {
                            const target = resultRepeater.count > 0 ? resultRepeater.itemAt(index) : null
                            if (!target) return
                            const top = resultColumn.y + target.y + (index === 0 ? 0 : target.rowY)
                            const bottom = resultColumn.y + target.y + target.rowY + target.rowHeight
                            let to = resultsFlick.contentY
                            if (top < resultsFlick.contentY) to = Math.max(0, top - 8 * stage.d)
                            else if (bottom > resultsFlick.contentY + resultsFlick.height)
                                to = Math.min(resultsFlick.contentHeight - resultsFlick.height, bottom - resultsFlick.height + 8 * stage.d)
                            if (Math.abs(to - resultsFlick.contentY) < 1) return
                            // The list glides with the highlight instead of jumping under it (the gallery does the same).
                            if (!IrisStyle.motionEnabled) { resultsFlick.contentY = to; return }
                            revealGlide.to = to
                            revealGlide.restart()
                        }
                        NumberAnimation {
                            id: revealGlide
                            target: resultsFlick
                            property: "contentY"
                            duration: IrisStyle.duration(180)
                            easing.type: IrisStyle.feedbackEasing
                        }
                        Connections {
                            target: root
                            function onSelectedIndexChanged(): void { results.reveal(root.selectedIndex) }
                        }
                        Connections {
                            target: LauncherSearch
                            function onQueryChanged(): void { revealGlide.stop(); resultsFlick.contentY = 0 }
                        }

                        Flickable {
                            id: resultsFlick
                            anchors.fill: parent
                            contentWidth: width
                            contentHeight: results.implicitHeight
                            clip: true
                            interactive: contentHeight > height + 1
                            boundsBehavior: Flickable.StopAtBounds
                            onContentYChanged: if (contentY + height > contentHeight - 120 * stage.d) root.loadMoreClipboard()

                            Rectangle {
                                id: highlight
                                readonly property Item target: resultRepeater.count > 0 ? resultRepeater.itemAt(root.selectedIndex) : null
                                visible: target !== null
                                x: 8 * stage.d
                                width: parent.width - 16 * stage.d
                                y: resultColumn.y + (target ? target.y + target.rowY : 0)
                                height: target?.rowHeight ?? 0
                                radius: IrisStyle.radiusTile
                                color: IrisStyle.tintFill(IrisStyle.accent)
                                Behavior on y { NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                                Behavior on height { NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                            }

                            Column {
                                id: resultColumn
                                y: 8 * stage.d
                                width: parent.width

                                Item {
                                    width: parent.width
                                    height: 44 * stage.d
                                    visible: root.visibleResults.length === 0
                                    IrisText {
                                        anchors.centerIn: parent
                                        text: root.actionMode ? Translation.tr("Nothing by that name. Fewer letters find more.")
                                            : Translation.tr("No results. Try fewer letters, or / for every action.")
                                        color: IrisStyle.muted
                                    }
                                }

                                Repeater {
                                    id: resultRepeater
                                    model: ScriptModel {
                                        objectProp: "rowKey"
                                        values: root.keyedResults
                                    }
                                    Column {
                                        id: result
                                        required property var modelData
                                        required property int index
                                        readonly property bool topHit: result.index === 0 && !root.clipboardMode
                                        readonly property bool mathHit: result.topHit && result.modelData?.type === Translation.tr("Math")
                                        readonly property bool clipImage: root.clipboardMode
                                            && Cliphist.entryIsImage(String(result.modelData?.rawValue ?? ""))
                                        readonly property bool selected: root.selectedIndex === result.index
                                        readonly property var mark: root.clipboardMode
                                            ? stage.clipMark(String(result.modelData?.name ?? ""))
                                            : ({ glyph: "", tint: result.modelData?.tint ?? stage.kindTint(String(result.modelData?.type ?? "")) })
                                        readonly property bool showHeader: result.index === 0
                                            || stage.sectionAt(result.index) !== stage.sectionAt(result.index - 1)
                                        readonly property real rowY: row.y
                                        readonly property real rowHeight: row.height
                                        width: resultColumn.width

                                        Item {
                                            visible: result.showHeader
                                            width: parent.width
                                            height: Math.round((result.index === 0 ? 24 : 30) * stage.d)
                                            IrisText {
                                                x: 20 * stage.d
                                                height: parent.height
                                                verticalAlignment: Text.AlignBottom
                                                bottomPadding: 5 * stage.d
                                                text: stage.sectionAt(result.index)
                                                // In "/" a header names an area and wears its colour; elsewhere headers stay quiet.
                                                color: root.actionMode && result.index > 0 && result.modelData?.areaTint
                                                    ? result.modelData.areaTint : IrisStyle.muted
                                                font.pixelSize: IrisStyle.typeMeta
                                                font.weight: IrisStyle.weight(Font.DemiBold)
                                            }
                                            IrisButton {
                                                visible: root.clipboardMode && result.index === 0
                                                anchors.right: parent.right
                                                anchors.rightMargin: 12 * stage.d
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 2 * stage.d
                                                implicitHeight: Math.round(22 * stage.d)
                                                quiet: !stage.confirmWipe
                                                danger: stage.confirmWipe
                                                text: stage.confirmWipe ? Translation.tr("Clear everything?") : Translation.tr("Clear all")
                                                onClicked: {
                                                    if (!stage.confirmWipe) {
                                                        stage.confirmWipe = true
                                                        wipeDisarm.restart()
                                                        return
                                                    }
                                                    stage.confirmWipe = false
                                                    Cliphist.wipe()
                                                    root.selectedIndex = 0
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: row
                                            x: 8 * stage.d
                                            width: parent.width - 16 * stage.d
                                            height: root.clipboardMode ? Math.round(52 * stage.d)
                                                : Math.round((result.mathHit ? 66 : result.topHit ? 58 : root.actionMode || result.modelData?.fuzzy ? 48 : 40) * stage.d)
                                            hoverEnabled: true
                                            cursorShape: root.pointerSelectionArmed ? Qt.PointingHandCursor : Qt.BlankCursor
                                            Accessible.role: Accessible.Button
                                            Accessible.name: String(result.modelData?.name ?? "")
                                            onPositionChanged: event => {
                                                if (root.armPointerSelection(row, event) && !result.selected)
                                                    root.selectedIndex = result.index
                                            }
                                            onClicked: {
                                                root.pointerSelectionArmed = true
                                                root.selectedIndex = result.index
                                                root.executeSelected()
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12 * stage.d
                                                anchors.rightMargin: 14 * stage.d
                                                spacing: 12 * stage.d

                                                Item {
                                                    id: lead
                                                    readonly property real size: Math.round((result.topHit ? 34 : 26) * stage.d)
                                                    Layout.alignment: Qt.AlignVCenter
                                                    Layout.preferredWidth: root.clipboardMode ? Math.round(64 * stage.d) : Math.round(34 * stage.d)
                                                    Layout.preferredHeight: root.clipboardMode ? Math.round(40 * stage.d) : lead.size

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        visible: root.clipboardMode
                                                        radius: IrisStyle.radiusRow
                                                        color: IrisStyle.fillQuiet
                                                        Loader {
                                                            id: thumbLoader
                                                            anchors.centerIn: parent
                                                            active: result.clipImage
                                                            sourceComponent: CliphistImage {
                                                                entry: String(result.modelData?.rawValue ?? "")
                                                                maxWidth: lead.width - Math.round(4 * stage.d)
                                                                maxHeight: lead.height - Math.round(4 * stage.d)
                                                                color: "transparent"
                                                                radius: IrisStyle.radiusChip
                                                            }
                                                        }
                                                        MaterialSymbol {
                                                            anchors.centerIn: parent
                                                            visible: !result.clipImage
                                                            text: result.mark.glyph
                                                            iconSize: Math.round(19 * stage.d)
                                                            color: result.mark.tint
                                                        }
                                                    }

                                                    Item {
                                                        visible: !root.clipboardMode
                                                        anchors.left: parent.left
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: lead.size
                                                        height: lead.size
                                                        Loader {
                                                            anchors.fill: parent
                                                            active: result.modelData?.iconType === LauncherSearchResult.IconType.System
                                                            sourceComponent: SmartAppIcon {
                                                                icon: result.modelData?.iconName ?? "application-x-executable"
                                                                fallback: "application-x-executable"
                                                                iconSize: lead.size
                                                            }
                                                        }
                                                        Loader {
                                                            anchors.centerIn: parent
                                                            active: result.modelData?.iconType === LauncherSearchResult.IconType.Text
                                                            sourceComponent: IrisText {
                                                                text: result.modelData?.iconName ?? ""
                                                                font.pixelSize: Math.round((result.topHit ? 26 : 19) * IrisStyle.typeScale)
                                                            }
                                                        }
                                                        Rectangle {
                                                            anchors.fill: parent
                                                            visible: result.modelData?.iconType !== LauncherSearchResult.IconType.System
                                                                && result.modelData?.iconType !== LauncherSearchResult.IconType.Text
                                                            radius: IrisStyle.iconRadius(width)
                                                            gradient: Gradient {
                                                                GradientStop { position: 0; color: IrisStyle.tileTop(result.mark.tint) }
                                                                GradientStop { position: 1; color: result.mark.tint }
                                                            }
                                                            MaterialSymbol {
                                                                anchors.centerIn: parent
                                                                text: result.modelData?.iconName || "search"
                                                                fill: 1
                                                                iconSize: Math.round(parent.width * 0.58)
                                                                color: IrisStyle.onTint
                                                            }
                                                        }
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    IrisText {
                                                        Layout.fillWidth: true
                                                        readonly property bool emphasise: !root.clipboardMode && !result.mathHit
                                                            && result.modelData?.fontType !== LauncherSearchResult.FontType.Monospace
                                                        textFormat: emphasise || result.mathHit ? Text.StyledText : Text.PlainText
                                                        text: result.clipImage ? Translation.tr("Image")
                                                            : result.mathHit
                                                                ? "<font color='" + IrisStyle.secondaryAccent + "'>=</font> " + stage.escapeHtml(String(result.modelData?.name ?? ""))
                                                            : emphasise ? stage.emphasised(String(result.modelData?.name ?? ""))
                                                            : String(result.modelData?.name ?? "")
                                                        font.family: result.mathHit ? IrisStyle.fontMain
                                                            : result.modelData?.fontType === LauncherSearchResult.FontType.Monospace
                                                            ? Appearance.font.family.monospace : IrisStyle.fontMain
                                                        font.features: result.mathHit ? ({ "tnum": 1 }) : ({})
                                                        font.pixelSize: Math.round((result.mathHit ? 28 : result.topHit ? 16 : 13.5) * IrisStyle.typeScale)
                                                        font.weight: result.mathHit ? Font.Bold : result.topHit ? Font.DemiBold : Font.Normal
                                                        font.letterSpacing: result.mathHit ? -1 : 0
                                                        elide: Text.ElideRight
                                                    }
                                                    IrisText {
                                                        Layout.fillWidth: true
                                                        visible: (result.topHit || root.actionMode || Boolean(result.modelData?.fuzzy)) && text.length > 0
                                                        text: result.mathHit ? root.settled
                                                            : result.modelData?.comment || result.modelData?.genericName || result.modelData?.type || ""
                                                        color: IrisStyle.subtext
                                                        font.pixelSize: IrisStyle.typeMeta
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                IrisText {
                                                    visible: text.length > 0
                                                    text: result.clipImage && thumbLoader.item
                                                        ? thumbLoader.item.imageWidth + " × " + thumbLoader.item.imageHeight : ""
                                                    color: IrisStyle.textTertiary
                                                    font.pixelSize: IrisStyle.typeMeta
                                                    font.features: { "tnum": 1 }
                                                }
                                                IrisIconButton {
                                                    visible: root.clipboardMode && (result.selected || row.containsMouse)
                                                    Layout.preferredWidth: Math.round(26 * stage.d)
                                                    Layout.preferredHeight: Math.round(26 * stage.d)
                                                    materialIcon: "delete"
                                                    iconSize: Math.round(16 * stage.d)
                                                    Accessible.name: Translation.tr("Delete from history")
                                                    onClicked: {
                                                        Cliphist.deleteEntry(String(result.modelData?.rawValue ?? ""))
                                                        root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, root.visibleResults.length - 2))
                                                    }
                                                }
                                                MaterialSymbol {
                                                    visible: Boolean(result.modelData?.pick) && result.modelData.isOn()
                                                    text: "check"
                                                    iconSize: Math.round(18 * stage.d)
                                                    color: IrisStyle.accent
                                                }
                                                IrisSwitch {
                                                    visible: typeof result.modelData?.isOn === "function" && !result.modelData?.pick
                                                    on: visible && result.modelData.isOn()
                                                    name: String(result.modelData?.name ?? "")
                                                    onToggled: {
                                                        root.selectedIndex = result.index
                                                        root.executeSelected()
                                                    }
                                                }
                                                IrisText {
                                                    visible: result.selected && text.length > 0 && typeof result.modelData?.isOn !== "function"
                                                    text: String(result.modelData?.verb ?? "")
                                                    color: IrisStyle.subtext
                                                    font.pixelSize: IrisStyle.typeMeta
                                                }
                                                Rectangle {
                                                    visible: result.selected
                                                    Layout.preferredWidth: Math.round(24 * stage.d)
                                                    Layout.preferredHeight: Math.round(20 * stage.d)
                                                    radius: IrisStyle.radiusChip
                                                    color: IrisStyle.fill
                                                    MaterialSymbol {
                                                        anchors.centerIn: parent
                                                        text: "keyboard_return"
                                                        iconSize: Math.round(14 * stage.d)
                                                        color: IrisStyle.text
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
