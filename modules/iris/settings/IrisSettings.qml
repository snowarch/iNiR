pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.style
import qs.modules.iris.field as Field
import qs.modules.iris.pieces
import qs.modules.iris.sidebar
import qs.modules.iris.preview
import qs.modules.iris.widgets

Item {
    id: root
    // Hosted by IrisSettingsOverlay (a layer over the desktop) or IrisSettingsWindow (a Niri window).
    property bool windowed: false
    readonly property alias frame: frame
    readonly property var screen: root.QsWindow.window?.screen ?? null
    property string section: "general"
    // The main-list row that holds the selection, for the travelling wash in the sidebar.
    property Item travelRow: null
    property int advancedPage: -1
    property string query: ""
    property string group: ""
    property var backStack: []
    property var forwardStack: []
    property int travel: 1
    property string requestedSection: ""
    readonly property real d: IrisStyle.settingsDensity
    // The widest a page's column gets: on a 1080p screen the window's pane is its width less a gutter of air.
    readonly property real columnMost: Math.round(1200 * root.d)
    // Rows never run that wide (DI38): a label 1200 px from its switch is read and aimed worse. Past their width the
    // page's scene takes the side of the window and its whole height, so a wide window fills with what the rows change.
    readonly property real rowsMost: Math.round(760 * root.d)
    readonly property real besideGap: Math.round(20 * root.d)
    readonly property real besideMargin: Math.round(28 * root.d)
    // The scene always keeps the screen's proportions; how it shares the page with the rows is measured, not fixed
    // (DI38): stacked, one column as wide as the scene that fits above the rows; beside, the scene as large as the rows
    // leave or as tall as the panel. Whichever leaves the least of the page bare wins (`relayout`).
    property string pageMode: ""
    property real besideSide: 0
    property real besideRows: root.rowsMost
    property real stackWidth: root.rowsMost
    readonly property bool layoutable: root.heroPinned && !root.split && !root.sceneDrawn && pageHero.stageAvailable
    readonly property bool heroBeside: root.layoutable && root.pageMode === "beside"
    readonly property bool heroStacked: root.layoutable && root.pageMode === "stack"
    readonly property var layoutInputs: [detailBody.width, detailBody.height, settingsRows.implicitHeight, root.layoutable, root.section, root.blocksShown, root.fedAll]
    onLayoutInputsChanged: Qt.callLater(root.relayout)
    function relayout(): void {
        // A page still arriving block by block is measured once it is whole.
        // Once whole, a page that later grows (another block built, a long area read by blocks) is never "arriving" again.
        if (!root.layoutable || (root.fedPage === root.pageKey && !root.fedAll && root.blocksShown < root.shownGroups.length)) {
            if (!root.layoutable) root.pageMode = ""
            return
        }
        const d = root.d
        const W = detailBody.width, H = detailBody.height, k = root.screenShape, words = root.stageCaption
        const rows = settingsRows.implicitHeight
        const options = []
        const column = Math.min(root.columnMost, W - 56 * d, (H - rows - words - 78 * d) / k)
        if (column >= 520 * d) options.push({ mode: "stack", width: column, empty: W * H - column * (column * k + words + rows) })
        for (const wanted of [root.rowsMost, 520 * d]) {
            const side = Math.min(W - 2 * root.besideMargin - root.besideGap - wanted, (H - words - 26 * d) / k)
            if (side < 340 * d) continue
            const rowsWidth = Math.min(root.rowsMost, W - 2 * root.besideMargin - root.besideGap - side)
            options.push({ mode: "beside", side: side, rows: rowsWidth, empty: W * H - side * (side * k + words) - rowsWidth * Math.min(rows, H) })
        }
        if (options.length === 0) { root.pageMode = ""; return }
        const pool = options
        let best = pool.reduce((a, b) => b.empty < a.empty ? b : a)
        // A layout already on screen stays unless the other is clearly better: rows rewrap when their width changes.
        const kept = pool.find(option => option.mode === root.pageMode)
        if (kept && kept.empty <= best.empty * 1.05) best = kept
        root.pageMode = best.mode
        if (best.mode === "stack") root.stackWidth = Math.round(best.width)
        else { root.besideSide = Math.round(best.side); root.besideRows = Math.round(best.rows) }
    }
    readonly property real screenShape: {
        const screen = GlobalStates.focusedScreen
        return screen ? screen.height / Math.max(1, screen.width) : 0.5625
    }
    // A section about hardware this machine lacks is not offered (Battery on a desktop); `inir battery simulate` brings it back.
    readonly property var sections: IrisOptions.sections.filter(section => section.id !== "battery" || Battery.available)
    // Sources and the Community Hub sit in a footer under the list, always in view.
    readonly property int footerCluster: 6
    readonly property var specifications: IrisOptions.settings
    readonly property var currentSection: IrisOptions.sectionById(root.section)
    // Every area is a row of the sidebar (DI49g, 2026-10-21): ten categories that each opened a page of their areas, then a
    // capsule of them, kept what you came for two clicks deep. The categories stay as captions over their areas, the way
    // macOS groups its panes; areas this machine does not offer (Battery on a desktop) drop out.
    readonly property var sideSections: {
        const out = []
        IrisOptions.categories.filter(category => !category.foot).forEach((category, at) => {
            const areas = category.sections.map(id => root.sections.find(section => section.id === id)).filter(section => !!section)
            areas.forEach((section, i) => out.push(Object.assign({}, section, { tint: section.tint, cluster: at,
                caption: i === 0 && areas.length > 1 ? category.title : "" })))
        })
        return out
    }
    // An area's colour as ink: lifted toward the text so a chosen name reads on its wash in dark and light.
    function tintInk(tint: color): color {
        const ink = IrisStyle.text
        return Qt.rgba(tint.r * 0.72 + ink.r * 0.28, tint.g * 0.72 + ink.g * 0.28, tint.b * 0.72 + ink.b * 0.28, 1)
    }
    readonly property bool searching: root.query.length > 0
    // A Design may lay the whole page out its own way (DESIGNS.md › Composiciones): its `settingsPage` draws the areas,
    // the head and the foot, and holds this file's search, scene, rows and shared pages in its slots. The model, the
    // history and every row stay here.
    readonly property Item scene: pageScene.item
    readonly property bool sceneDrawn: root.scene !== null
    // A Design's page is a spread (AIRISU: name and plate, the sheet of rows, the index): under 960 px it squeezed the
    // sheet to a sliver and the rows ran past its foot, so a narrow window reads the engine's one column, in the Design's
    // own parts. The frame's width, never the page's: the page's width follows the choice.
    readonly property bool sceneFits: frame.width >= Math.round(960 * root.d)
    // A Design that draws the page is known before its scene arrives: the engine's own chrome is then never built, and the
    // body waits for the scene instead of showing that chrome for the frames the scene takes to load.
    readonly property bool sceneDesigned: pageScene.url.length > 0
    // How tall the rows a scene holds are, so it can end their sheet where they end; -1 while a shared page fills the slot.
    readonly property real rowsExtent: settingsFlick.visible
        ? settingsFlick.anchors.topMargin + settingsFlick.contentHeight + settingsFlick.anchors.bottomMargin : -1
    // One layout (2026-10-15, the maintainer: "tres versiones de Settings"): the sidebar lists every area beside the page.
    // The Rail and Home variants went; a Design's scene (AIRISU) draws its own.
    readonly property string layoutStyle: root.sceneDrawn ? "scene" : "sidebar"
    // A section with a single group has nothing to choose between: it opens on that group.
    readonly property string openGroup: root.searching ? ""
        : root.group.length > 0 ? root.group
        : root.groups.length === 1 ? root.groups[0].title : ""
    // Columns (2026-10-11, the maintainer: "que todo se abra hacia el lado que tenga espacio y aprovechar el espacio que hoy
    // no se usa … que no quede vacío"): a section reads whole in one pane, its groups down a column beside it as the index;
    // the row of the group being read is the pane reaching into the column, melting into it as the Island's bodies meet
    // it. Search, the Hub, Home, the shared pages and a window too narrow for it keep the full width.
    // Measured beside a full sidebar, never from the page itself: the sidebar narrows when the columns show, and a width
    // that decided the columns from the room they make would flip between the two.
    readonly property real pageWidth: root.sceneDrawn ? Number(root.scene.pageWidth ?? frame.width) : frame.width - root.sidebarFull
    readonly property real sidebarNeed: root.sceneDrawn ? Number(root.scene.need ?? 0) : sidebarLayout.implicitHeight + 2 * sidebar.pad + Math.round(4 * root.d)
    // The sidebar keeps its width on every section: it never narrows to a rail (2026-10-15).
    readonly property real sidebarFull: Math.round(Math.min(272 * root.d, frame.width * 0.3))
    readonly property bool wideEnough: root.pageWidth >= Math.round(720 * root.d)
    // A shared page the column lists (the Hub, General's About and Shortcuts) reads in the pane beside it,
    // its row the tab; any other shared page keeps the full width.
    readonly property bool pageInPane: root.advancedPage >= 0 && root.wideEnough
        && root.navLinks.some(link => link.page && root.pageIndexOf(link.page) === root.advancedPage)
    readonly property bool paneable: (root.advancedPage < 0 || root.pageInPane) && root.wideEnough
    // The page as one pane beside an index is a Design's scene (AIRISU); iRiS reads its groups as cards on the window
    // (2026-10-15), each under its caption, as a grouped form does.
    readonly property bool split: root.sceneDrawn && root.paneable && !root.searching
    // A section with a single group has nothing to index: its pane takes the whole width.
    // Only a Design's scene (AIRISU) reads a section beside its own index of groups; iRiS keeps one layout (2026-10-15):
    // the sidebar never narrows, a short section reads whole and a long one lists its groups to open one at a time.
    readonly property bool columns: root.sceneDrawn && root.split
        && (root.groups.length > 1 || root.section === "general" || root.section === "sidebars" || root.section === "system")
    // A group asked for by name (a link, the CLI, history) is a place in the section's scroll: it scrolls there once built.
    property string pendingGroup: ""
    Timer { id: pendingScroll; interval: 140; onTriggered: { if (root.pendingGroup.length > 0) root.scrollToGroup(root.pendingGroup); root.pendingGroup = "" } }
    function showGroup(title: string): void {
        if (root.paneable && root.readsWhole && root.groups.length > 1 && root.section !== "general") { root.group = ""; root.pendingGroup = title; pendingScroll.restart() }
        else root.group = title
    }
    // In a section shown whole, the group being read: the column follows it; a click holds its pick until you scroll.
    property string readGroup: ""
    property string heldGroup: ""
    readonly property bool browsing: !root.searching && root.openGroup.length === 0 && root.advancedPage < 0
    // The page's head stays in view while its rows scroll when it shows a scene, unless the window is so short that the
    // rows would be left a sliver: then it scrolls with them.
    // A Design's scene holds the section's picture beside its index of groups.
    readonly property real columnStageWidth: root.sceneDrawn ? Number(root.scene.stageWidth ?? 0) : 0
    readonly property real columnStageHeight: root.sceneDrawn ? Number(root.scene.stageHeight ?? 0) : 0
    // A Design's page holds the scene in a place of its own beside the rows, whatever the section.
    readonly property bool stageInColumn: root.sceneDrawn && pageHero.shown && pageHero.stageAvailable
    readonly property bool heroPinned: !root.stageInColumn && pageHero.shown && pageHero.staged
        && detailBody.height >= (root.split ? root.stageMin : Math.round(196 * root.d)) + root.stageCaption + Math.round(260 * root.d)
    // In the pane the scene is a stage across its width that takes the room the rows leave: a short group shows what it
    // makes large, a long one keeps it small and in view while the rows pass under it.
    readonly property real stageCaption: Math.round(52 * root.d)
    readonly property real stageMin: Math.round(168 * root.d)
    readonly property real stageHeight: {
        if (!root.heroPinned) return Math.round((root.split ? 150 : 196) * root.d)
        // A scene is a picture of the screen: it may grow to the screen's own proportions, never taller.
        const screen = GlobalStates.focusedScreen
        const shape = screen ? screen.height / Math.max(1, screen.width) : 0.5625
        if (root.heroStacked) return Math.round(root.stackWidth * shape)
        if (!root.split) {
            // iRiS's own head (DI38): a short area's scene takes the height its few rows leave empty.
            const room = detailBody.height - settingsRows.implicitHeight - pageHero.wordsHeight - Math.round(84 * root.d)
            return Math.round(Math.max(196 * root.d, Math.min(settingsRows.width * shape, room)))
        }
        const most = Math.round((detailPane.width - Math.round(24 * root.d)) * shape)
        const room = detailBody.height - settingsRows.implicitHeight - root.stageCaption - Math.round(48 * root.d)
        return Math.round(Math.max(root.stageMin, Math.min(most, room)))
    }
    // Beside the rows the scene is at least the screen's proportions, and grows into what the index leaves under it, up
    // to a square (P3): a short area left most of the column bare under a 16:9 strip. Never column-tall: a crop of a
    // 16:9 desktop that tall is not that desktop.
    readonly property real besideStageLeast: Math.round(Math.min(heroBesideSlot.width * root.screenShape,
        heroBesideSlot.height - pageHero.wordsHeight - Math.round(16 * root.d)))
    readonly property real besideStageHeight: {
        const left = heroBesideSlot.height - pageHero.wordsBox - Math.round(34 * root.d) - (indexFlick.visible ? indexColumn.implicitHeight : 0)
        return Math.round(Math.max(root.besideStageLeast, Math.min(heroBesideSlot.width, left)))
    }
    function shown(spec: var): bool { return IrisOptions.shown(spec) }

    readonly property int searchLimit: 24
    readonly property var searchIndex: root.specifications.filter(spec => !spec.mirror).map(spec => {
        const label = Translation.tr(spec.label).toLowerCase()
        const sectionTitle = Translation.tr(IrisOptions.sectionById(spec.section).title)
        return { spec: spec, label: label, section: sectionTitle.toLowerCase(), rest: [Translation.tr(spec.group ?? ""), sectionTitle, Translation.tr(spec.description ?? ""), ...(spec.keywords ?? [])].join(" ").toLowerCase(),
            loose: IrisSearch.prepare({ name: Translation.tr(spec.label), english: spec.label, detail: Translation.tr(spec.group ?? ""), areaName: sectionTitle,
                words: [spec.group ?? ""].concat(spec.keywords ?? []).join(" ") }) }
    })
    // Exact words first; then what the forgiving match reads through a typo, initials or letters in order.
    function searchScore(entry: var, terms: var): int {
        if (!terms.every(term => entry.label.includes(term) || entry.rest.includes(term)))
            return IrisSearch.score(terms.join(" "), entry.loose) >= 0.6 ? 4 : 99
        const first = terms[0]
        if (terms.length === 1 && entry.section.startsWith(first)) return -1
        if (entry.label.startsWith(first)) return 0
        if (entry.label.includes(" " + first)) return 1
        if (entry.label.includes(first)) return 2
        return 3
    }
    readonly property var matches: {
        Config.revision
        const terms = root.query.toLowerCase().split(/\s+/).filter(term => term.length > 0)
        if (terms.length === 0) return []
        return root.searchIndex
            .map((entry, order) => ({ spec: entry.spec, order: order, score: root.searchScore(entry, terms) }))
            .filter(hit => hit.score < 99 && root.shown(hit.spec) && root.sections.some(section => section.id === hit.spec.section))
            .sort((a, b) => a.score - b.score || a.order - b.order)
            .map(hit => hit.spec)
    }
    readonly property var matchedSections: {
        const ids = new Set(root.matches.map(spec => spec.section))
        return ids
    }
    readonly property var entries: {
        Config.revision
        return root.searching ? root.matches.slice(0, root.searchLimit)
            : root.specifications.filter(spec => spec.section === root.section && root.shown(spec))
    }
    readonly property var groups: {
        const out = []
        for (const spec of root.entries) {
            // A result names where it lives, section and group, so the path is learned while searching.
            const sectionTitle = Translation.tr(IrisOptions.sectionById(spec.section).title)
            const groupTitle = Translation.tr(spec.group ?? "")
            const title = !root.searching ? groupTitle
                : groupTitle.length > 0 && groupTitle !== sectionTitle ? sectionTitle + "  ›  " + groupTitle : sectionTitle
            let group = out.find(entry => entry.title === title)
            if (!group) { group = { title: title, key: String(spec.group ?? ""), rows: [] }; out.push(group) }
            group.rows.push(spec)
        }
        return out
    }
    // A small section shows every row at once (Android's rule: a sub-page from about fifteen settings): its groups read as
    // captioned cards and nothing is behind a click; galleries and editors read whole too, as they do in the pane. What
    // counts is what shows: rows folded behind a group's Fine-tune take no room (a modified one never folds). An index of
    // a few groups is a few rows over an empty page: those sections read whole up to twice as long.
    // Every area reads its rows in line (DI48-R1): a list of groups that each open a page to pick one value hid the answer
    // a click away. Only a window too narrow for the engine's page keeps the old list of groups for a long area.
    readonly property bool readsWhole: root.columns || (!root.sceneDrawn && root.wideEnough) || root.essentialCount <= 15
    // A long area reads whole on one scroll too (DI49d, 2026-10-21): read a block at a time, a block of three rows left
    // most of the page bare and every other block was a click away behind an index that swapped pages. Fine-tune keeps
    // the rare rows folded, and the index beside the scene keeps the way through.
    readonly property int essentialCount: {
        let count = 0
        for (const group of root.groups) {
            const tuned = group.rows.filter(spec => IrisOptions.fineTune(spec) && !IrisOptions.changed(spec)).length
            count += tuned >= 2 ? group.rows.length - tuned + 1 : group.rows.length
        }
        return count
    }
    // General beside its column opens on its welcome (IrisGeneralHome) and each group alone: read whole it mixed the hero
    // with every row under it.
    readonly property bool generalHome: root.section === "general" && root.paneable && !root.searching
    readonly property bool flatSection: !root.searching && root.advancedPage < 0 && root.group.length === 0 && root.groups.length > 1
        && root.section !== "system" && !root.generalHome
        && root.readsWhole
    // Groups of one row would each be a card under a caption that repeats the row's name: neighbours share one card.
    readonly property var flatBlocks: {
        if (!root.flatSection) return []
        const out = []
        // In columns the pane reads in the column's order, and every group is a place with its name: the column points at
        // each one, so none hides inside a neighbour's card.
        if (root.split) {
            for (const group of root.groups)
                out.push({ title: group.title, caption: group.title, key: group.key, rows: group.rows.slice(), loose: false })
            return out
        }
        let previous = null
        for (const group of root.groups) {
            // A list is a group of its own: it reads under its name, not inside a neighbour's card.
            const single = group.rows.length === 1 && group.rows[0].kind !== "list"
            if (single && previous?.loose) { previous.rows = previous.rows.concat(group.rows); continue }
            previous = { title: single ? "\u200b" + group.key : group.title, caption: single ? "" : group.title, key: group.key, rows: group.rows.slice(), loose: single }
            out.push(previous)
        }
        return out
    }
    // A group of one switch reads as that switch, named by its own label ("Confirm before closing windows" says more
    // than "Closing"); where that label repeats across the area (every widget's "On the desktop") it names nothing, and
    // each row takes its group's name instead.
    readonly property var sharedLoneLabels: {
        Config.revision
        IrisNiri.revision
        const seen = {}, shared = {}
        for (const group of root.groups) {
            const rows = group.rows.filter(spec => root.shown(spec))
            if (rows.length !== 1 || rows[0].kind !== "switch") continue
            const label = String(rows[0].label)
            if (seen[label]) shared[label] = true
            seen[label] = true
        }
        return shared
    }
    readonly property var shownGroups: root.searching ? root.groups
        : root.openGroup.length > 0 ? root.groups.filter(entry => entry.title === root.openGroup)
        : root.flatBlocks
    // A page's groups arrive one per frame: building a long page's rows at once (Appearance, Lock) froze the whole
    // shell for a quarter second on every switch. The first comes at once, so the top of the page is there on the
    // first frame; a search or a link to a row gets every group at once, so it can scroll to it.
    readonly property string pageKey: root.section + "/" + root.openGroup + "/" + root.advancedPage
    property string fedPage: ""
    property int blocksShown: 1
    // The page has arrived whole: a block built later (another block of a long area) comes in at once, never by trimming
    // the ones already there.
    property bool fedAll: false
    readonly property var fedGroups: {
        if (root.searching || root.landingPath.length > 0) return root.shownGroups
        if (root.fedAll && root.fedPage === root.pageKey) return root.shownGroups
        const shown = root.fedPage === root.pageKey ? root.blocksShown : 1
        return shown >= root.shownGroups.length ? root.shownGroups : root.shownGroups.slice(0, shown)
    }
    function feedPage(): void {
        root.fedPage = root.pageKey
        root.fedAll = false
        root.blocksShown = 1
        blockFeed.restart()
    }
    Timer {
        id: blockFeed
        interval: 16
        repeat: true
        onTriggered: {
            if (root.blocksShown >= root.shownGroups.length) { stop(); root.fedAll = true }
            else root.blocksShown += 1
        }
    }
    // A section's groups in named blocks, by what someone came to change (IrisOptions.groupClusters); a section without
    // blocks is cut into even cards. Groups a block does not name close the page in a last block of their own.
    readonly property var groupChunks: {
        const clusters = IrisOptions.groupClusters[root.section] ?? []
        const out = []
        if (clusters.length > 0) {
            const placed = new Set()
            for (const cluster of clusters) {
                const groups = cluster.groups.map(key => root.groups.find(entry => entry.key === key)).filter(entry => entry !== undefined)
                groups.forEach(entry => placed.add(entry.key))
                if (groups.length > 0) out.push({ caption: Translation.tr(cluster.caption), groups: groups, flow: cluster.flow ?? false })
            }
            const rest = root.groups.filter(entry => !placed.has(entry.key))
            if (rest.length > 0) out.push({ caption: out.length > 0 ? Translation.tr("More") : "", groups: rest })
            return out
        }
        const size = root.groups.length > 7 ? Math.ceil(root.groups.length / Math.ceil(root.groups.length / 6)) : root.groups.length
        for (let i = 0; i < root.groups.length; i += Math.max(1, size)) out.push({ caption: "", groups: root.groups.slice(i, i + size) })
        return out
    }
    function valueText(spec: var): string {
        if (spec.summary === false) return ""
        // A list says what it holds now (the speakers in use, how many apps play).
        if (typeof spec.summary === "function") return String(spec.summary() ?? "")
        const value = IrisOptions.currentValue(spec)
        switch (spec.kind) {
        case "switch": {
            const on = spec.invert ? !value : value
            // The group's own on and off (named after it, or `master`): off says Off, on lets the next row answer.
            if (spec.label === spec.group || spec.master) return on ? "" : Translation.tr("Off")
            // A switch's name answers when it is short; a sentence ("Close the shell around the screen") reads as On.
            const name = Translation.tr(spec.label)
            // A label the area repeats (every widget's "On the desktop") or that repeats its group's name ("Enable power
            // saving" under Power saving) names nothing either.
            const group = String(spec.group ?? "").toLowerCase()
            const echoes = root.sharedLoneLabels[spec.label] || (group.length > 0 && spec.label.toLowerCase().includes(group))
            return !on ? "" : name.length <= 24 && !echoes ? name : Translation.tr("On")
        }
        case "text": {
            if (spec.numeric && Number(value ?? 0) === 0) return ""
            // A name answers ("iNiR Hotspot"); a long string (a browser's user agent, a command) is no answer at a glance.
            const text = String(value ?? "")
            return text.length <= 24 ? text : ""
        }
        case "niriMotion": return NiriAnimationPresets.activePreset?.name ?? ""
        case "icon": return String(value ?? "").length > 0 ? Translation.tr("Custom") : ""
        case "zone":
        case "choice":
            // "None" says nothing in a group's summary ("Graphite, None"): only what is there is named.
            if ((spec.fallback === "" && value === "") || value === "none") return ""
            return Translation.tr(String(IrisOptions.choicesOf(spec).find(choice => IrisOptions.same(choice.value, value))?.label ?? ""))
        case "range":
            if (spec.fallback !== undefined && IrisOptions.same(value, spec.fallback)) return ""
            return Translation.tr(spec.label) + " " + Translation.tr(IrisOptions.rangeText(spec, value))
        case "pieces": {
            const choices = IrisOptions.choicesOf(spec)
            return Array.from(value ?? []).slice(0, 2)
                .map(item => Translation.tr(String(choices.find(choice => IrisOptions.same(choice.value, item))?.label ?? "")))
                .filter(text => text.length > 0).join(", ")
        }
        default: return ""
        }
    }
    function summaryOf(entry: var): string {
        Config.revision
        const rows = entry.rows.filter(spec => root.shown(spec))
        const parts = [...new Set(rows.map(spec => root.valueText(spec)).filter(text => text.length > 0))]
        // Switches that all keep quiet answer for themselves: a group's own switch on ("Notch") said Off when no row followed it.
        if (parts.length === 0 && rows.length > 0 && rows.every(spec => spec.kind === "switch")) {
            const on = rows.some(spec => { const value = IrisOptions.currentValue(spec); return spec.invert ? !value : !!value })
            return on ? Translation.tr("On") : Translation.tr("Off")
        }
        // One answer, the group's first: two read as a list of unrelated words ("Off, Own", "iRiS, iRiS, Material").
        return parts[0] ?? ""
    }
    function modifiedIn(entry: var): bool {
        Config.revision
        return entry.rows.some(spec => IrisOptions.modified(spec))
    }
    // The pages iRiS keeps beside its sections, asked for by name ("about", "shortcuts", "hub"). Each scrolls itself.
    readonly property var pages: [
        { key: "about", component: Qt.resolvedUrl("IrisAboutPage.qml") },
        { key: "shortcuts", component: Qt.resolvedUrl("IrisShortcutsPage.qml") },
        { key: "hub", component: Qt.resolvedUrl("IrisHubPage.qml") }
    ]
    property var unfolded: ({})
    // Every Fine-tune fold on the page at once (`inir iris settings tune:open`); a section change folds them again.
    property bool tuneAll: false
    function fold(key: string): void {
        const next = Object.assign({}, root.unfolded)
        next[key] = !next[key]
        root.unfolded = next
    }
    IrisGroupPreview { id: sceneProbe; visible: false; section: ""; group: "" }
    // The wallpaper every scene is drawn on, decoded once in each of the two sizes a scene asks for (IrisGroupPreview
    // `decodeFor`) while Settings is open: a scene arriving takes it from the image cache in the same frame. Measured: the
    // scene drew in 40 ms and its wallpaper landed 150-220 ms later, decoded again at each width the page passed through
    // while it settled.
    Repeater {
        model: [1, 1024]
        IrisWallpaperView {
            required property int modelData
            visible: false
            live: false
            screen: GlobalStates.focusedScreen
            provideTexture: true
            decodeSize: sceneProbe.decodeFor(modelData)
        }
    }
    readonly property var morePages: IrisOptions.morePages.filter(entry => root.pages.some(page => page.key === entry.key))
    readonly property var moreGroups: [...new Set(root.morePages.map(entry => Translation.tr(entry.group)))]
    // iRiS's own pages (General's links) are found by search as the shared ones are.
    readonly property var ownPages: [
        { key: "about", home: "general", label: "About iNiR", detail: "Version, updates and the people behind it", icon: "info",
            get tint() { return IrisStyle.identity.lavender }, keywords: ["about", "version", "update", "credits", "acerca"] },
        { key: "shortcuts", home: "general", label: "Keyboard shortcuts", detail: "Every keybind, searchable", icon: "keyboard",
            get tint() { return IrisStyle.identity.indigo }, keywords: ["shortcuts", "keybinds", "hotkeys", "binds", "atajos"] }
    ].filter(entry => root.pages.some(page => page.key === entry.key))
    readonly property var pageMatches: {
        const terms = root.query.toLowerCase().split(/\s+/).filter(term => term.length > 0)
        if (terms.length === 0) return []
        return root.ownPages.concat(root.morePages).filter(entry => {
            // The English names too: "about" finds Acerca de in any language, as rows do through `english`.
            const text = [Translation.tr(entry.label), Translation.tr(entry.detail), entry.label, entry.detail, ...(entry.keywords ?? [])].join(" ").toLowerCase()
            return terms.every(term => text.includes(term))
        })
    }
    // A page leads when every word typed starts a word of its name ("shortcuts" → Keyboard shortcuts, "colour themes").
    readonly property bool pagesFirst: {
        const terms = root.query.trim().toLowerCase().split(/\s+/).filter(term => term.length > 0)
        return terms.length > 0 && root.pageMatches.some(entry => [Translation.tr(entry.label), entry.label]
            .some(name => { const words = name.toLowerCase().split(/\s+/); return terms.every(term => words.some(word => word.startsWith(term))) }))
    }
    function openFirstResult(): void {
        if (root.pageMatches.length > 0 && (root.pagesFirst || root.matches.length === 0)) {
            root.moreLink(root.pageMatches[0]).action()
            return
        }
        const spec = root.matches[0]
        if (spec) root.openResult(spec, true)
    }
    // Where a result is shown: a small section (shown whole, see flatSection) opens on itself, a larger one on the
    // group; the row then scrolls into view and glows once, so the eye lands on it.
    property string landingPath: ""
    // On a page shown whole, the pinned head follows the group being read: its scene, mark and caption, as a group page
    // would show them, while the rows scroll under it. Groups without a scene leave the section's own.
    property string spyGroup: ""
    // The index under a scene beside the rows: the area's groups, under the names of its blocks (Look, Surfaces …) where
    // it has them. Every entry answers on a second line (DI48-R3): a group its value now ("Black", "Auto"), so the index
    // is the area's overview. It fits its column without a scroll of its own: when every group would not, the blocks
    // stay named and only the one being read opens on its groups, following the rows.
    readonly property var besideIndex: {
        if (!root.flatSection)
            return root.groupChunks.map((chunk, at) => ({ key: "", title: chunk.caption, chunk: at, block: false, list: true, detail: "" }))
                .filter(entry => entry.title.length > 0)
        const groupEntry = group => ({ key: String(group.key), title: group.title, chunk: -1, block: false, detail: root.summaryOf(group) })
        if (root.groupChunks.filter(chunk => chunk.caption.length > 0).length < 2) return root.groups.map(groupEntry)
        const reading = root.chunkOfKey(root.readGroup)
        const out = []
        root.groupChunks.forEach((chunk, at) => {
            // A group named as its block is the block's own line: "Look" under "Look" says nothing twice.
            const named = chunk.groups.filter(group => group.title !== chunk.caption)
            const open = (root.indexRoomy || at === reading) && named.length > 0
            const detail = open ? "" : named.length === 0 ? root.summaryOf(chunk.groups[0]) : named.map(group => group.title).join(" · ")
            out.push({ key: String(chunk.groups[0].key), title: chunk.caption, chunk: at, block: true, detail: detail })
            if (open) for (const group of named) out.push(groupEntry(group))
        })
        return out
    }
    function chunkOfKey(key: string): int {
        return root.groupChunks.findIndex(chunk => chunk.groups.some(group => String(group.key) === key))
    }
    // Every block open fits the column under the scene.
    readonly property bool indexRoomy: {
        let need = 0
        for (const chunk of root.groupChunks) {
            need += indexFlick.blockHeight
            need += chunk.groups.filter(group => group.title !== chunk.caption).length * (indexFlick.groupHeight + indexFlick.answerHeight)
        }
        // Measured under the least scene: the scene grows from what the index leaves, never the other way round.
        return need <= heroBesideSlot.height - root.besideStageLeast - pageHero.wordsBox - Math.round(34 * root.d)
    }
    property int readChunk: 0
    function scrollToChunk(at: int): void {
        const item = chunkRepeater.itemAt(at)
        if (!item) return
        root.readChunk = at
        const end = Math.max(0, settingsFlick.contentHeight - settingsFlick.height)
        revealMotion.to = Math.max(0, Math.min(end, item.mapToItem(settingsFlick.contentItem, 0, 0).y - Math.round(8 * root.d)))
        revealMotion.restart()
    }
    function spyChunk(): void {
        let found = 0
        for (let at = 0; at < chunkRepeater.count; at++) {
            const item = chunkRepeater.itemAt(at)
            if (item && item.mapToItem(settingsFlick.contentItem, 0, 0).y - settingsFlick.contentY <= settingsFlick.height * 0.2) found = at
        }
        root.readChunk = found
    }
    // A group row under the pointer shows its scene beside the rows before it is opened (DI24): what Material, Glass or
    // Shape change is seen on the hover, not after the click. Only beside, where the rows never move under the pointer;
    // a short dwell both ways, so passing over the rows does not flick the scene.
    property string hoverWanted: ""
    property string hoverGroup: ""
    // Only a group of the page in view leads: a hover or a read group left from the area before asked the new area's
    // scene for a group it lacks, the scene went, heroBeside fell and cleared the hover inside that same scene pass.
    readonly property string leadGroup: {
        const own = key => key.length > 0 && root.groups.some(entry => entry.key === key)
        return own(root.hoverGroup) ? root.hoverGroup : own(root.spyGroup) ? root.spyGroup : ""
    }
    onHoverWantedChanged: hoverDwell.restart()
    // A group under the pointer, on the rows or in the index, leads the scene when it has one of its own.
    function hoverOver(key: string, over: bool): void {
        if (over && key.length > 0 && sceneProbe.sceneFor(root.section, key).length > 0) root.hoverWanted = key
        else if (root.hoverWanted === key || over) root.hoverWanted = ""
    }
    Timer { id: hoverDwell; interval: 140; onTriggered: root.hoverGroup = root.heroBeside ? root.hoverWanted : "" }
    onHeroBesideChanged: if (!root.heroBeside) { root.hoverWanted = ""; root.hoverGroup = "" }
    function spy(): void {
        if (!root.flatSection) { root.spyGroup = ""; root.readGroup = ""; return }
        let found = ""
        // At the foot of the page the last groups can never rise to the reading line: the last one in view wins.
        const atEnd = settingsFlick.contentY >= settingsFlick.contentHeight - settingsFlick.height - 2 && settingsFlick.contentY > 0
        const targets = root.spyTargets()
        // Before any head reaches the line, the first block on the page is the one being read (the column's order); at the
        // top of the page it still is, however short it is: a one-row group at the top let the next head pass the line.
        if (root.section !== "general" && targets.length > 0) found = targets[0].key
        const atTop = settingsFlick.contentY < 1 && root.section !== "general"
        for (const target of atTop ? [] : targets) {
            const top = target.item.mapToItem(settingsFlick.contentItem, 0, 0).y - settingsFlick.contentY
            // The group whose head has reached the upper fifth is the one being read; at the foot, the last one in view.
            if (top > settingsFlick.height * (atEnd ? 0.92 : 0.2)) break
            if (target.key.length > 0) found = target.key
        }
        if (found.length === 0) found = root.section === "general" ? "@welcome" : String(root.groups[0]?.key ?? "")
        if (root.heldGroup.length === 0) root.readGroup = found
        // The scene follows only where the head already carries one: one appearing mid-scroll would pin the head and move the rows.
        // A group picked in the index leads the scene while the rows travel to it: the groups passing on the way changed
        // the scene once more for each.
        const lead = root.heldGroup.length > 0 ? root.heldGroup : found
        root.spyGroup = sceneProbe.sceneFor(root.section, "").length > 0 && lead.length > 0
            && sceneProbe.sceneFor(root.section, lead).length > 0 ? lead : ""
    }
    // The column of a section shown whole is its index: a group scrolls into view instead of opening alone.
    // What the page shows, in order, each with the column entry it answers to.
    function spyTargets(): var {
        const out = []
        for (let i = 0; i < blockRepeater.count; i++) {
            const block = blockRepeater.itemAt(i)
            if (block && block.visible) out.push({ key: String(block.modelData.key ?? ""), item: block })
        }
        for (let i = 0; i < editorRepeater.count; i++) {
            const editor = editorRepeater.itemAt(i)
            if (editor && editor.visible) out.push({ key: "@" + editor.modelData, item: editor })
        }
        return out
    }
    function scrollToGroup(wanted: string): void {
        const lower = wanted.toLowerCase()
        const match = root.groups.find(entry => entry.key === wanted || entry.title === wanted
            || entry.key.toLowerCase() === lower || entry.title.toLowerCase() === lower)
        const key = match ? String(match.key) : wanted
        root.heldGroup = key
        root.readGroup = key
        let top = 0
        if (key !== "@welcome") {
            const target = root.spyTargets().find(candidate => candidate.key === key)
            if (!target) return
            top = target.item.mapToItem(settingsFlick.contentItem, 0, 0).y - Math.round(8 * root.d)
        }
        const end = Math.max(0, settingsFlick.contentHeight - settingsFlick.height)
        revealMotion.to = Math.max(0, Math.min(end, top))
        revealMotion.restart()
    }
    // What the column lists: the section's groups in their blocks (captions, or air between unnamed blocks), General's
    // welcome first, the side panels' editors, and the links that leave the page at its foot.
    readonly property var navEntries: {
        if (!root.columns) return []
        const out = []
        if (root.section === "general") out.push({ type: "you", key: "@welcome", title: "@welcome" })
        let first = root.section !== "general"
        for (const chunk of root.groupChunks) {
            if (chunk.caption.length > 0) out.push({ type: "caption", key: "caption:" + chunk.caption, text: chunk.caption })
            else if (!first) out.push({ type: "gap", key: "gap:" + out.length })
            for (const group of chunk.groups) out.push({ type: "group", key: group.key, title: group.title, rows: group.rows })
            first = false
        }
        if (root.section === "sidebars") {
            out.push({ type: "gap", key: "gap:editors" })
            out.push({ type: "group", key: "@left", title: "@left", label: Translation.tr("Focus sections"), glyph: "dock_to_left", tintName: "green" })
            out.push({ type: "group", key: "@right", title: "@right", label: Translation.tr("Today sections"), glyph: "dock_to_right", tintName: "orange" })
        }
        const links = root.navLinks
        if (root.section === "system") {
            // The Hub entry is its pages, in their blocks.
            for (const block of root.moreGroups) {
                out.push({ type: "caption", key: "caption:" + block, text: block })
                for (const link of links.filter(candidate => candidate.block === block))
                    out.push(Object.assign({ type: "link", key: "link:" + link.page }, link))
            }
            return out
        }
        if (links.length > 0) out.push({ type: "gap", key: "gap:links" })
        for (const link of links) out.push(Object.assign({ type: "link", key: "link:" + link.label }, link))
        return out
    }
    // Whether a column entry is where you are, and the line it answers with: one reading for the column and a Design's.
    function navHoldsPage(entry: var): bool { return entry?.type === "link" && entry.page !== undefined && root.wideEnough }
    function navSelected(entry: var): bool {
        const row = ["group", "you", "link"].includes(entry?.type)
        if (root.navHoldsPage(entry)) return root.advancedPage >= 0 && root.pageIndexOf(String(entry.page)) === root.advancedPage
        if (!row || entry.type === "link" || root.advancedPage >= 0) return false
        if (root.generalHome) return entry.type === "you" ? root.group.length === 0 : root.group === String(entry.title)
        return root.readGroup === String(entry.key)
    }
    function navDetail(entry: var): string {
        if (entry?.type === "group" && entry.rows !== undefined) return root.summaryOf(entry)
        if (root.navHoldsPage(entry) && entry.detail !== undefined) return String(entry.detail)
        if (entry?.type === "you") return [ShellUpdates.localVersion.length > 0 ? "iNiR " + ShellUpdates.localVersion : "iNiR",
            SystemInfo.distroName !== "Unknown" ? SystemInfo.distroName : ""].filter(part => part.length > 0).join(" · ")
        return ""
    }
    // An entry's mark: its own glyph, its group's, or the section's.
    function navGlyph(entry: var): string {
        return String(entry?.glyph ?? IrisOptions.groupGlyphs[String(entry?.key ?? "")] ?? IrisOptions.groupGlyphs[String(entry?.title ?? "")]
            ?? root.currentSection.icon ?? "settings")
    }
    // An entry's part number in the column (indexed Designs): rows only, captions and air are not parts.
    function navGroupIndex(entry: var): int {
        const rows = root.navEntries.filter(candidate => ["group", "link"].includes(candidate.type))
        return rows.findIndex(candidate => candidate.key === entry?.key)
    }
    readonly property var navLinks: root.section === "system"
        ? root.morePages.map(entry => ({ label: Translation.tr(entry.label), detail: Translation.tr(entry.detail), glyph: entry.icon,
            tintName: entry.tintName, page: entry.key, block: Translation.tr(entry.group) }))
        : root.section === "general"
        ? [{ label: Translation.tr("About iNiR"), glyph: "info", tintName: "lavender", page: "about" },
            { label: Translation.tr("Keyboard shortcuts"), glyph: "keyboard", tintName: "indigo", page: "shortcuts" }].filter(link => root.pages.some(page => page.key === link.page))
        : root.section === "sidebars"
        ? [{ label: Translation.tr("Open Focus"), glyph: "dock_to_left", tintName: "green", run: "focus" },
            { label: Translation.tr("Open Today"), glyph: "dock_to_right", tintName: "orange", run: "today" }]
        : root.section === "desktop" ? [{ label: Translation.tr("Edit desktop widgets"), glyph: "edit", tintName: "yellow", run: "widgets" }]
        : []
    function openNav(entry: var): void {
        if (entry.type === "link") {
            if (entry.page) { root.go({ section: root.section, group: "", advancedPage: root.pageIndexOf(entry.page) }); return }
            GlobalStates.settingsOverlayOpen = false
            if (entry.run === "focus") GlobalStates.openSidebarLeft("")
            else if (entry.run === "today") GlobalStates.openSidebarRight("")
            else if (entry.run === "widgets") GlobalStates.setWidgetEditMode(true)
            return
        }
        if (root.generalHome) {
            root.go({ section: "general", group: entry.type === "you" ? "" : String(entry.title), advancedPage: -1 })
            return
        }
        if (root.advancedPage >= 0) {
            root.go({ section: root.section, group: "", advancedPage: -1 })
            root.pendingGroup = String(entry.key)
            pendingScroll.restart()
            return
        }
        root.scrollToGroup(String(entry.key))
    }
    Timer { id: spyPace; interval: 90; onTriggered: root.spy() }
    onFlatSectionChanged: spyPace.restart()
    function sectionIsFlat(id: string): bool {
        const rows = root.specifications.filter(spec => spec.section === id && root.shown(spec))
        const groups = new Set(rows.map(spec => String(spec.group ?? "")))
        return id !== "system" && groups.size > 1 && ((root.sceneDrawn && root.paneable) || (!root.sceneDrawn && root.wideEnough)
            || (rows.length <= 15 && !rows.some(spec => ["widgets", "pieces", "niriMotion", "list"].includes(spec.kind) && spec.bare !== true)))
    }
    function openResult(spec: var, land: bool): void {
        searchField.text = ""
        root.landingPath = land ? String(spec.path ?? "") : ""
        landingClear.restart()
        root.go({ section: spec.section, group: root.sectionIsFlat(spec.section) ? "" : Translation.tr(spec.group ?? ""), advancedPage: -1 })
    }
    function reveal(row: Item): void {
        const top = row.mapToItem(settingsRows, 0, 0).y
        const end = Math.max(0, settingsFlick.contentHeight - settingsFlick.height)
        revealMotion.to = Math.max(0, Math.min(end, top - settingsFlick.height * 0.3))
        revealMotion.restart()
    }
    Timer { id: landingClear; interval: 2400; onTriggered: root.landingPath = "" }
    function pageIndexOf(key: string): int { return root.pages.findIndex(page => page.key === key) }
    function moreLink(entry: var): var {
        return { label: Translation.tr(entry.label), value: Translation.tr(entry.detail), icon: entry.icon, tint: entry.tint,
            action: () => { searchField.text = ""; root.go({ section: entry.home ?? "system", group: "", advancedPage: root.pageIndexOf(entry.key) }) } }
    }
    function pageTitle(index: int): string {
        const entry = root.ownPages.concat(IrisOptions.morePages).find(candidate => candidate.key === root.pages[index]?.key)
        return entry ? Translation.tr(entry.label) : ""
    }
    // What a Design's page offers at its foot, and its name for the page: the toolbar's, as this layout reads them.
    readonly property var pageActions: [rehearseAction, customizeAction, restoreAction].filter(action => action.shown)
    readonly property string titleText: pageTitle.text
    function close(): void { GlobalStates.settingsOverlayOpen = false }
    readonly property var editTargets: ({ bar: "island", player: "bodies", bubbles: "pieces", dock: "dock", appearance: "material", colour: "colour",
        motion: "motion", desktop: "desktop", sidebars: "places", spotlight: "places", controlCenter: "bodies" })
    readonly property var studioTargets: ({ bar: "island", bubbles: "pieces", dock: "dock", appearance: "material", colour: "colour", motion: "motion",
        desktop: "desktop", sidebars: "places", controlCenter: "bodies", spotlight: "places", sound: "transients", notifications: "transients", player: "bodies" })

    function here(): var { return { section: root.section, group: root.group, advancedPage: root.advancedPage } }
    function same(a: var, b: var): bool {
        return a.section === b.section && a.group === b.group && a.advancedPage === b.advancedPage
    }
    function arrive(place: var, direction: int): void {
        root.travel = direction
        root.section = place.section
        root.advancedPage = root.landingPage(place.section, place.advancedPage)
        root.showGroup(place.group)
        if (searchField.text.length > 0) searchField.text = ""
    }
    // The Hub entry in columns opens on its first page: the pane never stands empty beside its index.
    function landingPage(section: string, page: int): int {
        return section === "system" && page < 0 && root.wideEnough && root.morePages.length > 0 ? root.pageIndexOf(root.morePages[0].key) : page
    }
    function go(place: var, direction: var): void {
        const now = root.here()
        if (root.same(now, place) && !root.searching) return
        root.backStack = root.backStack.concat([now]).slice(-40)
        root.forwardStack = []
        root.arrive(place, direction === -1 ? -1 : 1)
    }
    function goBack(): void {
        if (root.backStack.length === 0) return
        const place = root.backStack[root.backStack.length - 1]
        root.forwardStack = root.forwardStack.concat([root.here()])
        root.backStack = root.backStack.slice(0, -1)
        root.arrive(place, -1)
    }
    function goForward(): void {
        if (root.forwardStack.length === 0) return
        const place = root.forwardStack[root.forwardStack.length - 1]
        root.backStack = root.backStack.concat([root.here()])
        root.forwardStack = root.forwardStack.slice(0, -1)
        root.arrive(place, 1)
    }
    function selectSection(id: string): void { root.go({ section: id, group: "", advancedPage: -1 }) }
    function openGroupNamed(title: string): void { root.go({ section: root.section, group: title, advancedPage: -1 }) }
    function leaveGroup(): void {
        if (root.group.length > 0) root.go({ section: root.section, group: "", advancedPage: -1 })
    }

    property string requestedGroup: ""
    Timer {
        id: groupRequest
        property int tries: 0
        interval: 60
        repeat: true
        onRunningChanged: if (running) tries = 0
        onTriggered: {
            const wanted = root.requestedGroup.toLowerCase()
            const match = root.groups.find(group => group.title.toLowerCase() === wanted || group.key.toLowerCase() === wanted)
            if (match || ++tries > 20) {
                stop()
                root.requestedGroup = ""
                if (match) root.showGroup(match.title)
            }
        }
    }
    // A link written before a topic got its own section (appearance/Accent, lock/Login screen, desktop/Wallpaper gallery)
    // still lands: a group asked for where it no longer is opens in the section that holds it now.
    readonly property var renamedGroups: ({ "appearance/wallpaper": "Wallpaper tint", "player/on the edges": "Frame music", "player/finish": "Frame finish" })
    // A section folded into a sister keeps its old links: Frame Music lives in Now Playing.
    readonly property var renamedSections: ({ frameMusic: "player" })
    function followMovedGroup(): void {
        let wanted = root.requestedGroup.toLowerCase()
        if (wanted.length === 0) return
        const holds = (section, name) => root.specifications.some(spec => spec.section === section && String(spec.group ?? "").toLowerCase() === name)
        if (holds(root.requestedSection, wanted)) return
        const renamed = String(root.renamedGroups[root.requestedSection + "/" + wanted] ?? "")
        if (renamed.length > 0) { root.requestedGroup = renamed; wanted = renamed.toLowerCase() }
        const home = root.specifications.find(spec => String(spec.group ?? "").toLowerCase() === wanted)
        if (home) root.requestedSection = home.section
    }
    function runCommand(verb: string): bool {
        if (verb === "back") root.goBack()
        else if (verb === "forward") root.goForward()
        else if (verb === "next") root.stepSection(1)
        else if (verb === "prev") root.stepSection(-1)
        else if (verb.startsWith("search:")) { searchField.text = verb.slice(7); root.query = searchField.text }
        else if (verb === "open") root.openFirstResult()
        else if (verb === "tune:open" || verb === "tune:close") root.tuneAll = verb === "tune:open"
        // `list:<row label>` opens that row's choices in place on the current page; `list:` closes it.
        else if (verb.startsWith("list:")) {
            const name = verb.slice(5).toLowerCase()
            const spec = root.entries.find(entry => String(entry.label ?? "").toLowerCase() === name)
            IrisOptions.openList = spec ? String(spec.path ?? "") + "|" + String(spec.section ?? "") + "|" + String(spec.label ?? "") : ""
        }
        else return false
        return true
    }
    // Material's pages iRiS draws in its own sections: a request for one (the desktop's "Widget settings") lands there.
    readonly property var nativePages: ({
        widgets: asked => asked === "Organic edge" ? "player/Edge wave" : "widgets",
        wallpaper: () => "wallpaper",
        tools: () => "capture",
        advanced: () => "colour/App colours",
        monitors: () => "display/Screens",
        themes: () => "colour/Colour theme",
        autostart: () => "general/At login",
        services: () => "sources/Calendar",
        orbit: () => "orbit",
        dock: () => "dock",
        sidebars: () => "sidebars"
    })
    // A request names a page: "iris" (or any page iRiS has no copy of) opens its sections, at the place or verb the
    // section part carries; one of its own pages opens that page.
    function applyRequest(): void {
        // Switching hosts, the one leaving still hears the request and took it: the other opened on General.
        if (root.windowed !== ((Config.options?.iris?.appearance?.settingsHost ?? "overlay") === "window")) return
        let key = String(GlobalStates.settingsOverlayRequestedKey ?? "")
        if (key.length === 0) return
        let asked = String(GlobalStates.settingsOverlayRequestedSection ?? "")
        const landing = root.nativePages[key]
        if (landing) { asked = landing(asked); key = "iris" }
        GlobalStates.settingsOverlayCurrentPage = GlobalStates.settingsPageKeys.indexOf(key)
        GlobalStates.settingsOverlayRequestedSection = ""
        GlobalStates.settingsOverlayRequestedPage = -1
        GlobalStates.settingsOverlayRequestedKey = ""
        if (key === "iris" && root.runCommand(asked)) return
        root.group = ""
        const request = asked.split("/")
        root.requestedSection = root.renamedSections[request[0] ?? ""] ?? (request[0] ?? "")
        if (request.length > 1) {
            root.requestedGroup = request.slice(1).join("/")
            groupRequest.restart()
        } else if (request[0].length > 0) {
            // A new place without a group drops a group still waiting from the last request.
            groupRequest.stop()
            root.requestedGroup = ""
        }
        root.followMovedGroup()
        // The place is worked out first and set once: every write to section or advancedPage rebuilds the page, and
        // setting "general" on the way to the asked section built General's page on each request.
        const own = root.pageIndexOf(key)
        let section = own >= 0 ? String(root.ownPages.concat(root.morePages).find(entry => entry.key === key)?.home ?? "system")
            : "general"
        if (own < 0 && root.sections.some(s => s.id === root.requestedSection)) {
            section = root.requestedSection
            // A place asked for by name is where you want to be, not a filter over it.
            if (searchField.text.length > 0) searchField.text = ""
        }
        // A category's name (`inir iris settings look`, links from before DI49g) opens its first area.
        const named = own < 0 && !root.sections.some(s => s.id === root.requestedSection)
            ? IrisOptions.categories.find(category => category.id === root.requestedSection) : null
        if (named) section = named.sections.find(id => root.sections.some(s => s.id === id)) ?? section
        root.advancedPage = root.landingPage(section, own)
        root.section = section
        root.backStack = []
        root.forwardStack = []
    }
    Component.onCompleted: {
        IrisNiri.ensure()
        if (GlobalStates.settingsOverlayOpen) root.applyRequest()
        // The window host is built on open: the page takes the keys then, or ↑ ↓ and typing reached nothing (DI49a).
        if (root.windowed) root.forceActiveFocus()
    }
    Connections {
        target: GlobalStates
        function onSettingsOverlayRequestedKeyChanged(): void { Qt.callLater(root.applyRequest) }
        function onSettingsOverlayOpenChanged(): void {
            if (!GlobalStates.settingsOverlayOpen) return
            IrisNiri.ensure()
            root.applyRequest()
            if (!searchField.activeFocus) root.forceActiveFocus()
        }
    }
    // A Design's scene sets its own page; the engine's slide would only move chrome nobody sees.
    function enterPage(): void { if (!root.sceneDesigned) pageEnter.restart() }
    onSectionChanged: { root.readChunk = 0; settingsFlick.contentY = 0; root.heldGroup = ""; root.tuneAll = false; IrisOptions.openList = ""; root.enterPage(); spyPace.restart() }
    onPageKeyChanged: Qt.callLater(root.feedPage)
    onOpenGroupChanged: { settingsFlick.contentY = 0; root.enterPage() }
    onAdvancedPageChanged: root.enterPage()

    Shortcut {
        sequence: "Escape"
        enabled: GlobalStates.settingsOverlayOpen
        onActivated: {
            // An open list of choices closes first, as a menu would (DI49a: Esc left it open).
            if (IrisOptions.openList.length > 0) IrisOptions.openList = ""
            else if (root.searching) searchField.text = ""
            else if (root.group.length > 0 && (!root.split || root.generalHome)) root.leaveGroup()
            else if (root.advancedPage >= 0 && !root.pageInPane) root.go({ section: root.section, group: "", advancedPage: -1 })
            else if (!root.windowed) GlobalStates.settingsOverlayOpen = false
        }
    }
    Shortcut { sequence: "Ctrl+F"; enabled: GlobalStates.settingsOverlayOpen; onActivated: searchField.forceActiveFocus() }
    // Typing anywhere on the page searches: a letter no control takes reaches the page and goes to the field.
    // ↑ and ↓ walk the sidebar's areas when nothing on the page holds the keys (DI49a: they did nothing).
    Keys.onUpPressed: event => { if (event.modifiers === Qt.NoModifier) root.stepSection(-1); else event.accepted = false }
    Keys.onDownPressed: event => { if (event.modifiers === Qt.NoModifier) root.stepSection(1); else event.accepted = false }
    Keys.onPressed: event => typeAhead.take(event)
    IrisTypeAhead { id: typeAhead; field: searchField }
    // The other host opens where this one stands.
    function switchHost(): void {
        GlobalStates.settingsOverlayRequestedSection = root.advancedPage < 0 ? root.section + (root.group.length > 0 ? "/" + root.group : "") : ""
        GlobalStates.settingsOverlayRequestedKey = root.advancedPage < 0 ? "iris" : root.pages[root.advancedPage].key
        Config.setNestedValue("iris.appearance.settingsHost", root.windowed ? "overlay" : "window")
    }
    function stepSection(delta: int): void {
        const index = root.sections.findIndex(section => section.id === root.section)
        const next = root.sections[Math.max(0, Math.min(root.sections.length - 1, index + delta))]
        if (next) root.selectSection(next.id)
    }
    Shortcut { sequence: "Ctrl+Down"; enabled: GlobalStates.settingsOverlayOpen; onActivated: root.stepSection(1) }
    Shortcut { sequence: "Ctrl+Up"; enabled: GlobalStates.settingsOverlayOpen; onActivated: root.stepSection(-1) }
    Shortcut { sequences: ["Alt+Left", "Ctrl+["]; enabled: GlobalStates.settingsOverlayOpen; onActivated: root.goBack() }
    Shortcut { sequences: ["Alt+Right", "Ctrl+]"]; enabled: GlobalStates.settingsOverlayOpen; onActivated: root.goForward() }
    MouseArea { anchors.fill: parent; enabled: !root.windowed; onClicked: GlobalStates.settingsOverlayOpen = false }

    // A textured material (Afterglow's bevel, Light leak's lit rim) must follow the corners Niri clips the window to.
    readonly property bool windowField: root.windowed && IrisStyle.textured
    onWindowFieldChanged: if (root.windowField) IrisNiri.reload(["window-rules"])
    // In a window Niri owns the shape, the corners and the open motion: the body fills it, already open.
    IrisMorphSurface {
        motionSurface: "settings"
        settles: true
        windowOffset: Qt.point(IrisFrame.band, IrisFrame.band)
        ownField: !root.windowed || root.windowField
        // A window cannot know where it sits on screen, so it never samples the wallpaper: Blur asks Niri, else solid.
        glass: !root.windowed || IrisStyle.glassCompositor
        id: frame
        compositorBlurred: true
        energy: root.windowed && GlobalStates.settingsWindowBehind ? 0 : 1
        contentReady: !root.sceneDesigned || root.sceneDrawn
        open: root.windowed || GlobalStates.settingsOverlayOpen
        color: IrisStyle.surface
        light: IrisStyle.surfaceLight("settings", IrisStyle.wallpaperLight)
        radius: root.windowField ? Number(IrisNiri.data["window-rules"]?.corner_radius ?? 16)
            : root.windowed ? 0 : IrisStyle.surfaceRadius("settings", IrisStyle.radiusPanel)
        onClosed: GlobalStates.irisMorphOwner = ""
        // Whole pixels: a body centred on a half pixel draws every line of its text soft.
        x: root.windowed ? 0 : Math.round((parent.width - width) / 2)
        y: root.windowed ? 0 : Math.round((parent.height - height) / 2)
        width: root.windowed ? parent.width
            // Wide enough for the columns to breathe (the group column and a pane where rows keep their answer column), never
            // more than four fifths of the screen: Settings sits on the desktop, it does not replace it.
            : Math.round(Math.min(parent.width - 32 - IrisFrame.musicReach("left") - IrisFrame.musicReach("right"),
                Math.max(1000 * root.d, parent.width * 0.8), 1560 * root.d))
        height: root.windowed ? parent.height
            // Most of the screen's height, and never shorter than the sidebar's list: measured by the list alone, ten
            // categories left a 640 px strip that cut every page at its second row.
            : Math.round(Math.min(parent.height - 48 - IrisFrame.musicReach("top") - IrisFrame.musicReach("bottom"),
                Math.max(640 * root.d, parent.height * 0.86, root.sidebarNeed)))
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.BackButton | Qt.ForwardButton
            onPressed: mouse => {
                if (mouse.button === Qt.BackButton) root.goBack()
                else if (mouse.button === Qt.ForwardButton) root.goForward()
            }
        }


        IrisSkin { id: pageScene; part: "settingsPage"; wanted: root.sceneFits; host: root }
        RowLayout {
            anchors.fill: parent
            visible: !root.sceneDesigned
            spacing: 0

            Item {
                id: sidebarSlot
                z: 2
                Layout.fillHeight: true
                Layout.preferredWidth: root.sidebarFull
            Rectangle {
                id: sidebar
                // A pane of its own floating inside the window (macOS 26): inset on three sides, concentric with the
                // window's corners, its edge a hairline all round instead of a rule between it and the page.
                readonly property int inset: Math.round(8 * root.d)
                readonly property int pad: IrisStyle.concentricPad(sidebar.radius, 10 * root.d)
                x: sidebar.inset
                y: sidebar.inset
                height: parent.height - 2 * sidebar.inset
                width: sidebarSlot.width - sidebar.inset
                clip: true
                radius: IrisStyle.fieldChamfer ? 0 : Math.max(IrisStyle.radiusTile, frame.radius - sidebar.inset)
                color: IrisStyle.readingSidebar
                border.width: 1
                border.color: IrisStyle.hairline
                Rectangle {
                    visible: false
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: IrisStyle.hairline
                }
                ColumnLayout {
                    id: sidebarLayout
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: sidebar.pad
                    anchors.topMargin: sidebar.pad
                    anchors.bottomMargin: sidebar.pad
                    width: root.sidebarFull - 2 * sidebar.pad + 4 * root.d
                    spacing: 0

                    Item {
                        id: sideSearchSlot
                        visible: !root.sceneDrawn
                        Layout.fillWidth: true
                        Layout.rightMargin: 4 * root.d
                        Layout.bottomMargin: 6 * root.d
                        implicitHeight: Math.round(32 * root.d)
                    }
                    // One search field: in the sidebar when there is one, in the header otherwise.
                    Rectangle {
                        id: searchPlate
                        // What a Design's skin draws the field from; the input, its keys and its focus stay here.
                        readonly property bool focused: searchField.activeFocus
                        readonly property bool hovered: searchHover.hovered
                        readonly property bool skinned: searchSkin.active
                        parent: root.sceneDrawn ? root.scene.searchSlot : sideSearchSlot
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width
                        radius: Math.min(height / 2, Math.max(IrisStyle.radiusRow, frame.radius - sidebar.pad))
                        color: searchPlate.skinned ? "transparent" : searchField.activeFocus ? IrisStyle.fill : IrisStyle.fillQuiet
                        border.width: searchField.activeFocus && !searchPlate.skinned ? 1 : 0
                        border.color: IrisStyle.tintBorder(IrisStyle.accent)
                        HoverHandler { id: searchHover; cursorShape: Qt.IBeamCursor }
                        TapHandler { onTapped: searchField.forceActiveFocus() }
                        IrisSkin { id: searchSkin; part: "settingsSearch"; host: searchPlate }
                        MaterialSymbol {
                            id: searchGlyph
                            anchors.left: parent.left
                            anchors.leftMargin: 10 * root.d
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search"
                            iconSize: Math.round(16 * root.d)
                            color: searchSkin.item?.glyphColour ?? IrisStyle.muted
                        }
                        TextInput {
                            id: searchField
                            anchors.left: searchGlyph.right
                            anchors.leftMargin: 6 * root.d
                            anchors.right: clearSearch.left
                            anchors.rightMargin: 4 * root.d
                            anchors.verticalCenter: parent.verticalCenter
                            color: IrisStyle.text
                            selectionColor: searchSkin.item?.selectionColour ?? IrisStyle.accentContainer
                            selectedTextColor: searchSkin.item?.selectedTextColour ?? IrisStyle.text
                            font.family: IrisStyle.fontMain
                            font.pixelSize: IrisStyle.typeLabel
                            clip: true
                            onTextChanged: {
                                if (text.length === 0) { searchDelay.stop(); root.query = ""; return }
                                root.advancedPage = -1
                                searchDelay.restart()
                            }
                            Keys.onReturnPressed: root.openFirstResult()
                            // The field holds the keys while Settings is open: with nothing typed, ↑ ↓ walk the areas from here too.
                            Keys.onUpPressed: event => { if (text.length === 0) root.stepSection(-1); else event.accepted = false }
                            Keys.onDownPressed: event => { if (text.length === 0) root.stepSection(1); else event.accepted = false }
                            Timer { id: searchDelay; interval: 160; onTriggered: root.query = searchField.text }
                            IrisText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: searchField.text.length === 0
                                text: Translation.tr("Search settings")
                                color: searchSkin.item?.placeholderColour ?? IrisStyle.muted
                                font.pixelSize: searchField.font.pixelSize
                            }
                        }
                        MaterialSymbol {
                            id: clearSearch
                            anchors.right: parent.right
                            anchors.rightMargin: 8 * root.d
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchField.text.length > 0
                            width: visible ? implicitWidth : 0
                            text: "cancel"
                            fill: 1
                            iconSize: Math.round(15 * root.d)
                            color: IrisStyle.muted
                            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: searchField.text = "" }
                        }
                    }

                    Flickable {
                        id: sidebarFlick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        // As tall as the list, so the foot follows it instead of leaving a hole above itself (DI38); a short
                        // window still scrolls it.
                        Layout.maximumHeight: sidebarColumn.implicitHeight
                        clip: true
                        contentHeight: sidebarColumn.implicitHeight
                        // What the list asks for: the window's height comes from it (`root.sidebarNeed`).
                        implicitHeight: sidebarColumn.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: IrisScrollBar {}
                        // The list itself fades under the footer: a gradient painted over it read as a square
                        // shadow on glass.
                        layer.enabled: sidebarEdge.active
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: sidebarEdge.mask
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                        }

                        // Where you are travels from row to row on the morph curve (the gallery's ring does the same) instead of
                        // fading out on one row and in on the next. Under the rows; the footer keeps its own wash.
                        Rectangle {
                            id: travelWash
                            readonly property Item row: root.travelRow
                            readonly property bool shown: travelWash.row !== null && travelWash.row.selected
                            property bool travels: false
                            x: sidebarColumn.x
                            width: sidebarColumn.width
                            y: travelWash.row ? sidebarColumn.y + travelWash.row.y + travelWash.row.washY : 0
                            height: travelWash.row ? travelWash.row.rowHeight : 0
                            radius: IrisStyle.plateSelection ? 0 : travelWash.row ? travelWash.row.washRadius : 0
                            // A plate-selection Design (AIRISU) puts where you are on the solid plate of the accent.
                            color: IrisStyle.plateSelection ? IrisStyle.selectionFill
                                : IrisStyle.tintFillHover(travelWash.row?.own ?? IrisStyle.accent)
                            opacity: travelWash.shown ? 1 : 0
                            // It lands where it first appears and travels from then on. Moving the selection hides it for a
                            // moment (the old row lets go before the new one takes it): only a hide that lasts stops the travel.
                            onShownChanged: if (travelWash.shown) { washDisarm.stop(); if (!travelWash.travels) washArm.restart() }
                                else washDisarm.restart()
                            Timer { id: washArm; interval: 0; onTriggered: travelWash.travels = IrisStyle.motionEnabled }
                            Timer { id: washDisarm; interval: 150; onTriggered: if (!travelWash.shown) travelWash.travels = false }
                            Behavior on y { enabled: travelWash.travels; NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                            Behavior on height { enabled: travelWash.travels; NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                        }

                        // Where you are stays in the list: a section opened from search, a link or the CLI below the fold
                        // scrolls its row into view, with a row of air past it.
                        onHeightChanged: sideFollow.restart()
                        onContentHeightChanged: sideFollow.restart()
                        Connections {
                            target: root
                            function onTravelRowChanged(): void { sideFollow.restart() }
                        }
                        Timer {
                            id: sideFollow
                            interval: 0
                            onTriggered: {
                                const row = root.travelRow
                                if (!row || !row.selected) return
                                const top = sidebarColumn.y + row.y + row.height - 2 * row.rowHeight
                                const bottom = sidebarColumn.y + row.y + row.height + row.rowHeight
                                const end = Math.max(0, sidebarFlick.contentHeight - sidebarFlick.height)
                                // The first block keeps the profile above it in view.
                                const to = top < sidebarFlick.contentY ? (row.modelData.cluster === root.sections[0]?.cluster ? 0 : top)
                                    : bottom > sidebarFlick.contentY + sidebarFlick.height ? bottom - sidebarFlick.height : sidebarFlick.contentY
                                sideScroll.to = Math.max(0, Math.min(end, to))
                                if (sideScroll.to !== sidebarFlick.contentY) sideScroll.restart()
                            }
                        }
                        NumberAnimation { id: sideScroll; target: sidebarFlick; property: "contentY"; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }

                        Column {
                            id: sidebarColumn
                            width: sidebarFlick.width - 4 * root.d
                            spacing: 0

                            Repeater {
                                model: root.sceneDesigned ? [] : root.sideSections
                                SectionRow { list: root.sideSections }
                            }
                        }

                        IrisScrollEdge {
                            id: sidebarEdge
                            parent: sidebarFlick
                            flick: sidebarFlick
                            anchors.fill: parent
                            // Inside the masked list a blurred band would be masked away with it: the fade alone.
                            blurs: false
                            reach: Math.round(28 * root.d)
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: sidebarLayout.width - 4 * root.d
                        Layout.topMargin: 4 * root.d
                        Layout.bottomMargin: 4 * root.d
                        implicitHeight: 1
                        color: IrisStyle.hairline
                    }

                    Column {
                        Layout.fillWidth: true
                        Layout.rightMargin: 4 * root.d
                        spacing: 0
                        Repeater {
                            model: root.sceneDesigned ? [] : root.sections.filter(section => section.cluster >= root.footerCluster)
                            SectionRow { list: []; gapAbove: false }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                RowLayout {
                    id: headRow
                    Layout.fillWidth: true
                    Layout.leftMargin: 20 * root.d
                    Layout.rightMargin: IrisStyle.concentricPad(frame.radius, 14 * root.d)
                    Layout.topMargin: IrisStyle.concentricPad(frame.radius, 14 * root.d)
                    Layout.preferredHeight: Math.round(52 * root.d)
                    spacing: 4 * root.d
                    // What the name and the actions share: the row less every fixed control in it. Measured from the
                    // row, never from the name or the actions, whose widths move with the folding (that loop froze the shell).
                    readonly property real sharedRoom: {
                        let fixed = 0
                        for (const child of headRow.children)
                            if (child.visible && child !== titleColumn && child !== toolbarActions) fixed += child.width + headRow.spacing
                        return headRow.width - fixed - headRow.spacing - 6 * root.d
                    }
                    IrisIconButton {
                        materialIcon: "chevron_left"
                        enabled: root.backStack.length > 0
                        opacity: enabled ? 1 : 0.35
                        onClicked: root.goBack()
                        Accessible.name: Translation.tr("Back")
                    }
                    IrisIconButton {
                        materialIcon: "chevron_right"
                        enabled: root.forwardStack.length > 0
                        opacity: enabled ? 1 : 0.35
                        onClicked: root.goForward()
                        Accessible.name: Translation.tr("Forward")
                    }
                    ColumnLayout {
                        id: titleColumn
                        Layout.fillWidth: true
                        Layout.leftMargin: 6 * root.d
                        spacing: 0
                        IrisText {
                            id: pageTitle
                            Layout.fillWidth: true
                            text: root.searching ? Translation.tr("Results for “%1”").arg(root.query)
                                : root.advancedPage >= 0 ? root.pageTitle(root.advancedPage)
                                : root.columns ? Translation.tr(root.currentSection.title)
                                : root.openGroup.length > 0 ? root.openGroup
                                : Translation.tr(root.currentSection.title)
                            font.family: IrisStyle.fontTitle
                            font.pixelSize: IrisStyle.lowerTitles ? IrisStyle.typeDisplay : IrisStyle.typeTitleLarge
                            font.weight: IrisStyle.lowerTitles ? Font.ExtraBold : IrisStyle.weight(Font.Bold)
                            font.capitalization: IrisStyle.lowerTitles && !root.searching ? Font.AllLowercase : Font.MixedCase
                            font.letterSpacing: IrisStyle.lowerTitles ? -Math.round(IrisStyle.typeDisplay * 0.03) : 0
                            elide: Text.ElideRight
                        }
                        IrisText {
                            Layout.fillWidth: true
                            visible: !root.searching && !root.columns && root.advancedPage < 0
                                && root.openGroup.length > 0 && root.openGroup !== Translation.tr(root.currentSection.title)
                            text: Translation.tr(root.currentSection.title)
                            color: IrisStyle.muted
                            font.pixelSize: IrisStyle.typeMeta
                            elide: Text.ElideRight
                        }
                    }
                    // The actions keep their words while the page's name still reads whole beside them (up to 260·d of
                    // it); measured in the language on screen, never a fixed window width.
                    RowLayout {
                        id: toolbarActions
                        spacing: 4 * root.d
                        // Fold one at a time, the least used first, only as many as the name needs.
                        readonly property var foldOrder: [restoreAction, customizeAction, rehearseAction].filter(action => action.shown)
                        readonly property var folded: {
                            const room = headRow.sharedRoom - Math.min(pageTitle.implicitWidth, 260 * root.d)
                            let need = toolbarActions.foldOrder.reduce((sum, action) => sum + action.fullWidth, 0)
                                + Math.max(0, toolbarActions.foldOrder.length - 1) * spacing
                            const out = []
                            for (const action of toolbarActions.foldOrder) {
                                if (need <= room) break
                                need -= action.fullWidth - action.implicitHeight
                                out.push(action)
                            }
                            return out
                        }
                    ToolbarAction {
                        id: rehearseAction
                        readonly property bool rehearses: root.section === "lock"
                        readonly property bool arranges: root.section === "controlCenter"
                        shown: !root.searching && root.advancedPage < 0 && (rehearses || arranges)
                        glyph: rehearses ? "visibility" : "dashboard_customize"
                        label: rehearses ? Translation.tr("Rehearse it") : Translation.tr("Arrange it")
                        onClicked: {
                            GlobalStates.settingsOverlayOpen = false
                            if (rehearses) { GlobalStates.irisLockEdit = true; return }
                            GlobalStates.irisMorphOwner = ""
                            GlobalStates.controlPanelOpen = true
                            GlobalStates.irisControlEdit = true
                        }
                    }
                    ToolbarAction {
                        id: customizeAction
                        readonly property string studioTarget: root.studioTargets[root.section] ?? ""
                        readonly property string target: studioTarget.length > 0 ? studioTarget : (root.editTargets[root.section] ?? "")
                        shown: !root.searching && root.advancedPage < 0 && target.length > 0
                        glyph: "edit"
                        label: Translation.tr("Customize")
                        onClicked: {
                            GlobalStates.settingsOverlayOpen = false
                            GlobalStates.openIrisCustomize(target)
                        }
                    }
                    ToolbarAction {
                        id: restoreAction
                        readonly property var resettable: (root.openGroup.length > 0 ? (root.shownGroups[0]?.rows ?? []) : root.specifications
                            .filter(spec => spec.section === root.section)).filter(spec => String(spec.path).startsWith("iris."))
                        readonly property bool modified: {
                            Config.revision
                            return resettable.some(spec => IrisOptions.modified(spec))
                        }
                        shown: !root.searching && root.advancedPage < 0 && modified
                        glyph: "restart_alt"
                        label: Translation.tr("Restore defaults")
                        onClicked: resettable.forEach(spec => IrisOptions.commit(spec, spec.fallback))
                    }
                    }
                    IrisIconButton {
                        materialIcon: root.windowed ? "layers" : "web_asset"
                        onClicked: root.switchHost()
                        Accessible.name: root.windowed ? Translation.tr("Open over the desktop") : Translation.tr("Open as a window")
                    }
                    IrisIconButton {
                        materialIcon: "close"
                        onClicked: GlobalStates.settingsOverlayOpen = false
                        Accessible.name: Translation.tr("Close settings")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20 * root.d
                    Layout.rightMargin: IrisStyle.concentricPad(frame.radius, 14 * root.d)
                    Layout.bottomMargin: 8 * root.d
                    visible: IrisNiri.pending !== null
                    implicitHeight: Math.round(48 * root.d)
                    radius: IrisStyle.radiusTile
                    color: IrisStyle.tintFill(IrisStyle.accent)
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16 * root.d
                        anchors.rightMargin: 8 * root.d
                        spacing: 8 * root.d
                        MaterialSymbol { text: "monitor"; iconSize: Math.round(18 * root.d); color: IrisStyle.accent }
                        IrisText {
                            Layout.fillWidth: true
                            text: Translation.tr("Keep this display setting? It goes back in %1 s.").arg(IrisNiri.secondsLeft)
                            font.pixelSize: IrisStyle.typeLabel
                            elide: Text.ElideRight
                        }
                        IrisButton { text: Translation.tr("Revert"); quiet: true; buttonRadius: height / 2; onClicked: IrisNiri.revertDisplay() }
                        IrisButton { text: Translation.tr("Keep"); emphasized: true; buttonRadius: height / 2; onClicked: IrisNiri.keepDisplay() }
                    }
                }

                Item {
                    id: pageArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ParallelAnimation {
                        id: pageEnter
                        NumberAnimation { target: pageArea; property: "opacity"; from: 0.2; to: 1; duration: IrisStyle.duration(180); easing.type: IrisStyle.feedbackEasing }
                        NumberAnimation { target: pageShift; property: "x"; from: 22 * root.d * root.travel; to: 0; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
                    }
                    transform: Translate { id: pageShift }


                    Rectangle {
                        id: detailPane
                        readonly property real inset: root.split ? IrisStyle.concentricPad(frame.radius, 14 * root.d) : 0
                        x: 0
                        y: root.split ? Math.round(4 * root.d) : 0
                        width: pageArea.width - detailPane.x - detailPane.inset
                        height: pageArea.height - detailPane.y - detailPane.inset
                        radius: root.split ? Math.max(IrisStyle.radiusTile, frame.radius - detailPane.inset) : 0
                        color: root.split ? IrisStyle.readingCard : "transparent"

                        Item {
                            id: detailBody
                            parent: root.sceneDrawn ? root.scene.rowsSlot : detailPane
                            anchors.fill: parent

                            // A head that carries a scene stays in view while its rows scroll under it: every change is seen as it
                            // lands, however far down the row is. One head, moved between this slot and the top of the rows.
                            Item {
                                id: heroPinSlot
                                visible: settingsFlick.visible && root.heroPinned && !root.heroBeside
                                x: Math.round((detailBody.width - width) / 2)
                                y: root.split ? 0 : Math.round(6 * root.d)
                                // In the pane the stage runs edge to edge, concentric with the pane's corners.
                                width: root.split ? detailBody.width : settingsRows.width
                                height: visible ? pageHero.implicitHeight : 0
                                // The head is part of the page: the wheel over it scrolls the rows, as it would if it scrolled too.
                                WheelHandler {
                                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                    onWheel: event => {
                                        const step = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * 64 * root.d
                                        const end = Math.max(0, settingsFlick.contentHeight - settingsFlick.height)
                                        settingsFlick.contentY = Math.max(0, Math.min(end, settingsFlick.contentY - step))
                                    }
                                }
                            }

                            // Beside the rows when the window is wider than they read (`root.heroBeside`).
                            Item {
                                id: heroBesideSlot
                                visible: settingsFlick.visible && root.heroBeside
                                x: root.besideMargin
                                y: Math.round(6 * root.d)
                                width: root.besideSide
                                height: detailBody.height - y - Math.round(20 * root.d)

                                // Under the scene, the page's index: the group being read carries the area's pill, which travels
                                // on the morph curve as the rows scroll. A click scrolls the rows to the group; the page never
                                // changes. A short page keeps it too: it is the area's answers at a glance, and the column under
                                // the scene was left bare without it. Resting on a group shows its scene, as its rows do.
                                Flickable {
                                    id: indexFlick
                                    y: pageHero.height + Math.round(18 * root.d)
                                    width: parent.width
                                    height: Math.max(0, parent.height - y)
                                    visible: root.heroBeside
                                    contentHeight: indexColumn.height
                                    interactive: contentHeight > height
                                    boundsBehavior: Flickable.StopAtBounds
                                    clip: interactive
                                    // A block's name heads its groups as a caption does, with more air above it than under it.
                                    readonly property real blockHeight: Math.round(30 * root.d)
                                    readonly property real groupHeight: Math.round(30 * root.d)
                                    readonly property real answerHeight: Math.round(16 * root.d)
                                    function heightOf(entry: var): real {
                                        return (entry.block ? blockHeight : groupHeight) + (String(entry.detail ?? "").length > 0 ? answerHeight : 0)
                                    }
                                    function isCurrent(entry: var): bool {
                                        if (entry.list) return entry.chunk === root.readChunk
                                        if (entry.block) return entry.chunk === root.chunkOfKey(root.readGroup)
                                        return String(entry.key) === root.readGroup
                                    }
                                    // The pill rests on the group being read, or on its block when the block is closed or is that group.
                                    readonly property int pillAt: {
                                        const entries = root.heroBeside ? root.besideIndex : []
                                        const group = entries.findIndex(entry => !entry.block && indexFlick.isCurrent(entry))
                                        return group >= 0 ? group : entries.findIndex(entry => entry.block && indexFlick.isCurrent(entry))
                                    }
                                    readonly property real pillY: {
                                        let top = 0
                                        for (let at = 0; at < indexFlick.pillAt; at++) top += indexFlick.heightOf(root.besideIndex[at])
                                        return top
                                    }
                                    readonly property color tint: IrisStyle.plainMarks ? IrisStyle.accent : (root.currentSection?.tint ?? IrisStyle.accent)
                                    onPillYChanged: {
                                        if (!indexFlick.interactive) return
                                        const pillHeight = indexFlick.pillAt >= 0 ? indexFlick.heightOf(root.besideIndex[indexFlick.pillAt]) : 0
                                        if (indexFlick.pillY < indexFlick.contentY) indexFlick.contentY = indexFlick.pillY
                                        else if (indexFlick.pillY + pillHeight > indexFlick.contentY + indexFlick.height)
                                            indexFlick.contentY = indexFlick.pillY + pillHeight - indexFlick.height
                                    }
                                    Rectangle {
                                        id: indexPill
                                        property bool travels: false
                                        width: parent.width
                                        y: indexFlick.pillY
                                        height: indexFlick.pillAt >= 0 ? indexFlick.heightOf(root.besideIndex[indexFlick.pillAt]) : 0
                                        radius: IrisStyle.plateSelection ? 0 : Math.min(IrisStyle.radiusRow, height / 2)
                                        // The area's own colour, strong enough to read as it on black (a hover-light wash read grey).
                                        color: IrisStyle.plateSelection ? IrisStyle.selectionFill : ColorUtils.applyAlpha(indexFlick.tint, IrisStyle.fillAlpha(0.3))
                                        opacity: indexFlick.pillAt >= 0 ? 1 : 0
                                        // It lands where it first shows and travels from then on, as the sidebar's wash does.
                                        onOpacityChanged: if (opacity === 1) pillArm.restart()
                                        Timer { id: pillArm; interval: 0; onTriggered: indexPill.travels = IrisStyle.motionEnabled }
                                        Behavior on y { enabled: indexPill.travels; NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                                        Behavior on height { enabled: indexPill.travels; NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                                        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                                    }
                                    Column {
                                        id: indexColumn
                                        width: parent.width
                                        Repeater {
                                            model: root.heroBeside ? root.besideIndex : []
                                            MouseArea {
                                                id: indexEntry
                                                required property var modelData
                                                required property int index
                                                readonly property bool current: indexFlick.isCurrent(indexEntry.modelData)
                                                // A block's name reads as a caption until it is where you are.
                                                readonly property bool heading: indexEntry.modelData.block === true && !indexEntry.current
                                                width: parent.width
                                                height: indexFlick.heightOf(indexEntry.modelData)
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                Accessible.role: Accessible.Button
                                                Accessible.name: indexEntry.modelData.title
                                                onContainsMouseChanged: if (!indexEntry.modelData.list) root.hoverOver(String(indexEntry.modelData.key), indexEntry.containsMouse)
                                                onClicked: {
                                                    if (indexEntry.modelData.list) { root.scrollToChunk(indexEntry.modelData.chunk); return }
                                                    root.heldGroup = String(indexEntry.modelData.key)
                                                    root.readGroup = root.heldGroup
                                                    root.scrollToGroup(root.heldGroup)
                                                    // A page that does not scroll takes no reading from the scroll: the pick leads the scene now.
                                                    spyPace.restart()
                                                }
                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: Math.min(IrisStyle.radiusRow, height / 2)
                                                    color: indexEntry.containsMouse && indexFlick.pillAt !== indexEntry.index ? IrisStyle.fillQuiet : "transparent"
                                                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                                                }
                                                // Three voices (DI49i): a block's name as a caption, a group's name, and its answer in the area's
                                                // colour, so the index reads as a summary instead of a column of one grey.
                                                IrisText {
                                                    id: indexTitle
                                                    x: Math.round(14 * root.d)
                                                    width: parent.width - x - Math.round(10 * root.d)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.verticalCenterOffset: (indexAnswer.text.length > 0 ? -Math.round(indexFlick.answerHeight / 2) : 0)
                                                        + (indexEntry.heading ? Math.round(3 * root.d) : 0)
                                                    role: indexEntry.heading ? IrisText.Group : IrisText.Name
                                                    text: indexEntry.modelData.title
                                                    color: indexEntry.heading ? IrisStyle.textTertiary : indexEntry.current ? root.tintInk(indexFlick.tint) : IrisStyle.text
                                                    font.weight: IrisStyle.weight(indexEntry.heading ? Font.Bold : indexEntry.current ? Font.DemiBold : Font.Medium)
                                                    elide: Text.ElideRight
                                                }
                                                IrisText {
                                                    id: indexAnswer
                                                    x: indexTitle.x
                                                    y: indexTitle.y + indexTitle.height
                                                    width: indexTitle.width
                                                    text: String(indexEntry.modelData.detail ?? "")
                                                    visible: text.length > 0
                                                    // A closed block lists what is in it; a group says what it is set to.
                                                    role: indexEntry.modelData.block ? IrisText.Detail : IrisText.Value
                                                    tone: root.tintInk(indexFlick.tint)
                                                    font.pixelSize: IrisStyle.typeMeta
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            StageHero {
                                id: pageHero
                                readonly property bool groupPage: !root.searching && root.openGroup.length > 0 && root.advancedPage < 0
                                readonly property bool sectionPage: root.browsing && root.section !== "system" && root.section !== "general" && root.section !== "gaming"
                                readonly property bool spying: !pageHero.groupPage && root.leadGroup.length > 0
                                readonly property string key: pageHero.spying ? root.leadGroup : String(root.shownGroups[0]?.key ?? "")
                                // A group with no scene has no head: the toolbar already names it.
                                readonly property bool shown: pageHero.sectionPage || (pageHero.groupPage && pageHero.stageAvailable)
                                parent: root.stageInColumn ? root.scene.stageSlot : root.heroBeside ? heroBesideSlot : root.heroPinned ? heroPinSlot : heroFlowSlot
                                width: root.stageInColumn ? root.columnStageWidth : root.heroBeside ? heroBesideSlot.width
                                    : root.heroPinned ? heroPinSlot.width : settingsRows.width
                                // A Design's page names the page itself: the head is only its scene there.
                                visible: pageHero.shown && (!root.sceneDrawn || root.stageInColumn)
                                tint: pageHero.groupPage || pageHero.spying ? (IrisOptions.groupTints[pageHero.key] ?? root.currentSection.tint) : root.currentSection.tint
                                glyph: pageHero.groupPage || pageHero.spying ? (IrisOptions.groupGlyphs[pageHero.key] ?? root.currentSection.icon) : root.currentSection.icon
                                title: !pageHero.groupPage && !pageHero.spying ? Translation.tr(root.currentSection.subtitle)
                                    : pageHero.caption.length > 0 ? pageHero.caption : pageHero.spying ? Translation.tr(root.leadGroup) : root.openGroup
                                text: pageHero.groupPage ? "" : Translation.tr(root.currentSection.tip ?? "")
                                sceneSection: pageHero.sectionPage || pageHero.groupPage ? root.section : ""
                                sceneGroup: pageHero.groupPage || pageHero.spying ? pageHero.key : ""
                            }

                            NumberAnimation {
                                id: revealMotion
                                target: settingsFlick
                                property: "contentY"
                                duration: IrisStyle.morphDuration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: IrisStyle.morphCurve
                            }
                            Flickable {
                                id: settingsFlick
                                anchors.fill: parent
                                anchors.topMargin: root.heroPinned && !root.heroBeside ? heroPinSlot.y + heroPinSlot.height + Math.round(12 * root.d) : 0
                                // Beside the scene the rows end a margin short of the window's edge (their column is centred in this).
                                anchors.leftMargin: root.heroBeside ? detailBody.width - 2 * root.besideMargin - root.besideRows : 0
                                // The pane's corners stay its own: the last rows stop short of the curve.
                                anchors.bottomMargin: root.split ? Math.round(detailPane.radius / 2) : 0
                                // Rows pass under the pinned head, never over it.
                                clip: root.heroPinned || root.split
                                onMovingChanged: if (moving) root.heldGroup = ""
                                // and soften into the air under it instead of ending on a cut (IrisScrollEdge), and so does the
                                // pane's foot with rows past it.
                                layer.enabled: (root.heroPinned || root.split) && rowsEdge.active
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: rowsEdge.mask
                                    maskThresholdMin: 0.5
                                    maskSpreadAtMin: 1
                                }
                                visible: root.advancedPage < 0
                                onContentYChanged: if (root.flatSection) spyPace.start(); else if (root.heroBeside) root.spyChunk()
                                // Rows laid after the section changed (a Place opening, a fold) move every head: the reading is taken again.
                                onContentHeightChanged: if (root.flatSection) spyPace.restart()
                                contentHeight: settingsRows.implicitHeight + 32 * root.d
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: IrisScrollBar {}

                                ColumnLayout {
                                    id: settingsRows
                                    y: 6 * root.d
                                    // In the pane the rows run its width (their own inset keeps the text off its edge).
                                    width: root.split ? settingsFlick.width - Math.round(16 * root.d) : root.heroBeside ? root.besideRows : root.heroStacked ? root.stackWidth
                                        : Math.min(settingsFlick.width - 56 * root.d, root.generalHome ? root.columnMost : root.rowsMost)
                                    x: Math.round((settingsFlick.width - width) / 2)
                                    spacing: 18 * root.d

                                    // The head reads here only when it carries no scene, or the window is too short to keep one in view.
                                    Item {
                                        id: heroFlowSlot
                                        Layout.fillWidth: true
                                        visible: pageHero.shown && !root.heroPinned && !root.stageInColumn && !root.heroBeside && !root.sceneDrawn
                                        implicitHeight: visible ? pageHero.implicitHeight : 0
                                    }

                                    IrisGameModeCard {
                                        visible: root.section === "gaming" && (root.split || root.browsing)
                                    }

                                    IrisWallpaperCard {
                                        screen: root.screen
                                        visible: root.section === "general" && !root.generalHome && root.browsing
                                    }

                                    IrisGeneralHome {
                                        Layout.fillWidth: true
                                        Layout.topMargin: Math.round(2 * root.d)
                                        room: settingsFlick.height - Math.round(48 * root.d)
                                        screen: root.screen
                                        visible: root.generalHome && (root.browsing || root.openGroup.length > 0) && root.advancedPage < 0 && !root.searching
                                        only: root.browsing ? "" : String(root.shownGroups[0]?.key ?? "")
                                        facts: !root.sceneDrawn
                                        entries: !visible ? [] : root.groupChunks.reduce((all, chunk) => all.concat(chunk.groups), []).map(group => ({
                                            key: group.key, title: group.title, detail: root.summaryOf(group),
                                            glyph: IrisOptions.groupGlyphs[group.key] ?? "settings", tint: IrisOptions.groupTints[group.key] ?? root.currentSection.tint,
                                            action: () => root.go({ section: "general", group: group.title, advancedPage: -1 })
                                        })).concat(root.navLinks.map(link => ({
                                            key: "@" + link.page, title: link.label, detail: "", glyph: link.glyph, tint: IrisStyle.identity[link.tintName],
                                            action: () => root.go({ section: "general", group: "", advancedPage: root.pageIndexOf(link.page) })
                                        })))
                                    }

                                    IrisText {
                                        visible: root.searching && root.entries.length === 0 && root.pageMatches.length === 0
                                        Layout.topMargin: 24 * root.d
                                        Layout.alignment: Qt.AlignHCenter
                                        text: Translation.tr("No matching settings")
                                        color: IrisStyle.muted
                                    }

                                    Repeater {
                                        id: chunkRepeater
                                        model: ScriptModel { values: root.browsing && !root.flatSection && root.section !== "system" && !root.generalHome ? root.groupChunks : [] }
                                        GroupList {}
                                    }

                                    Repeater {
                                        model: root.searching && root.pagesFirst ? [Translation.tr("Pages")] : []
                                        MoreGroup {}
                                    }

                                    Repeater {
                                        id: blockRepeater
                                        model: ScriptModel { objectProp: "title"; values: root.fedGroups }
                                        // A block is built by the incubator in slices of a frame: one block of a heavy
                                        // Design (AIRISU's lacquered rows) took up to 400 ms built at once. A search or
                                        // a link to a row builds at once, since it scrolls to what it built.
                                        Loader {
                                            id: blockLoader
                                            required property var modelData
                                            Layout.fillWidth: true
                                            asynchronous: !root.searching && root.landingPath.length === 0
                                            sourceComponent: GroupBlock { modelData: blockLoader.modelData }
                                        }
                                    }

                                    IrisText {
                                        visible: root.searching && root.matches.length > root.entries.length
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.topMargin: 4 * root.d
                                        text: Translation.tr("%1 more — keep typing to narrow the results").arg(root.matches.length - root.entries.length)
                                        color: IrisStyle.muted
                                        font.pixelSize: IrisStyle.typeMeta
                                    }

                                    IrisLinkCard {
                                        visible: root.section === "sidebars" && root.browsing && !root.split
                                        links: [
                                            { label: Translation.tr("Open Focus"), icon: "dock_to_left", tint: IrisStyle.identity.green, action: () => { GlobalStates.settingsOverlayOpen = false; GlobalStates.openSidebarLeft("") } },
                                            { label: Translation.tr("Open Today"), icon: "dock_to_right", tint: IrisStyle.identity.orange, action: () => { GlobalStates.settingsOverlayOpen = false; GlobalStates.openSidebarRight("") } }
                                        ]
                                    }

                                    Repeater {
                                        id: editorRepeater
                                        model: root.section !== "sidebars" ? []
                                            : root.split ? ["left", "right"]
                                            : root.browsing ? ["left", "right"] : []
                                        ColumnLayout {
                                            id: panelEditor
                                            required property string modelData
                                            Layout.fillWidth: true
                                            spacing: 6 * root.d
                                            IrisText {
                                                Layout.leftMargin: 16 * root.d
                                                text: panelEditor.modelData === "left" ? Translation.tr("Focus sections") : Translation.tr("Today sections")
                                                color: IrisStyle.label
                                                font.family: IrisStyle.fontTitle
                                                font.pixelSize: IrisStyle.typeMeta
                                                font.weight: IrisStyle.weight(Font.DemiBold)
                                            }
                                            IrisSidebarEditor { Layout.fillWidth: true; side: panelEditor.modelData }
                                        }
                                    }

                                    IrisLinkCard {
                                        visible: root.section === "general" && root.browsing && !root.split && !root.generalHome
                                        tinted: true
                                        links: [
                                            { key: "about", label: Translation.tr("About iNiR"), icon: "info", tint: IrisStyle.identity.lavender },
                                            { key: "shortcuts", label: Translation.tr("Keyboard shortcuts"), icon: "keyboard", tint: IrisStyle.identity.indigo }
                                        ].filter(link => root.pages.some(page => page.key === link.key)).map(link => ({
                                            label: link.label, icon: link.icon, tint: link.tint,
                                            action: () => root.go({ section: "general", group: "", advancedPage: root.pageIndexOf(link.key) })
                                        }))
                                    }

                                    IrisLinkCard {
                                        visible: root.section === "desktop" && root.browsing && !root.split
                                        links: [{ label: Translation.tr("Edit desktop widgets"), icon: "edit", tint: IrisStyle.identity.yellow, action: () => { GlobalStates.settingsOverlayOpen = false; GlobalStates.setWidgetEditMode(true) } }]
                                    }

                                    Repeater {
                                        model: root.browsing && root.section === "system" ? root.moreGroups : root.searching && root.pageMatches.length > 0 && !root.pagesFirst ? [Translation.tr("Pages")] : []
                                        MoreGroup {}
                                    }
                                }
                            }
                            IrisScrollEdge {
                                id: rowsEdge
                                flick: settingsFlick
                                anchors.fill: settingsFlick
                                visible: settingsFlick.visible && (root.heroPinned || root.split)
                                reach: Math.round(28 * root.d)
                            }

                        }
                    }


                    // One of iRiS's own pages (About, Shortcuts, Hub): loaded while it is shown, gone when you leave it.
                    Loader {
                        id: pageHost
                        parent: root.sceneDrawn ? root.scene.rowsSlot : pageArea
                        // Beside its column the page reads in the pane, inside its curve; alone it takes the width.
                        x: root.sceneDrawn ? 0 : root.pageInPane ? detailPane.x + Math.round(4 * root.d) : Math.round(12 * root.d)
                        y: root.sceneDrawn ? 0 : root.pageInPane ? detailPane.y + Math.round(detailPane.radius / 3) : 0
                        width: root.sceneDrawn ? parent.width : root.pageInPane ? detailPane.width - Math.round(8 * root.d) : pageArea.width - Math.round(24 * root.d)
                        height: root.sceneDrawn ? parent.height : root.pageInPane ? detailPane.height - Math.round(2 * detailPane.radius / 3) : pageArea.height
                        visible: root.advancedPage >= 0
                        active: visible
                        source: String(root.pages[root.advancedPage]?.component ?? "")
                    }
                }
            }
        }
    }

    // The toolbar's actions: one anatomy, a quiet capsule with its glyph. None of them is the page's answer, so none
    // wears the accent; a change in Settings applies as it is made.
    FontMetrics {
        id: toolbarMetrics
        // Measures the label as it is drawn: a mono-captions Design sets it in spaced capitals.
        font.family: IrisStyle.monoCaptions ? IrisStyle.fontMono : IrisStyle.fontMain
        font.capitalization: IrisStyle.monoCaptions ? Font.AllUppercase : Font.MixedCase
        font.letterSpacing: IrisStyle.monoCaptions ? Math.round(IrisStyle.typeMeta * 0.12) : 0
        font.pixelSize: IrisStyle.monoCaptions ? IrisStyle.typeMeta : IrisStyle.typeLabel
        font.weight: IrisStyle.weight(Font.Medium)
    }
    component ToolbarAction: IrisButton {
        id: action
        property string glyph: ""
        property string label: ""
        property bool shown: true
        visible: action.shown
        // When the page's name would lose its room, actions fold to their glyphs one at a time (toolbarActions.folded).
        readonly property bool folded: toolbarActions.folded.includes(action)
        readonly property real fullWidth: Math.ceil(toolbarMetrics.advanceWidth(action.label)) + Math.round((16 + 6 + 24) * root.d)
        buttonRadius: IrisStyle.capsule(height)
        // Under a Design's skin the plate is the skin's (AIRISU: a blade-cut outline): no capsule under it.
        colBackground: action.skinned ? "transparent" : IrisStyle.controlPlated ? IrisStyle.plateFillFor(IrisStyle.controlPlate) : IrisStyle.fill
        colBackgroundHover: action.skinned ? "transparent" : IrisStyle.fillHover
        implicitHeight: Math.round(30 * root.d)
        implicitWidth: action.folded ? implicitHeight : actionRow.implicitWidth + Math.round(24 * root.d)
        Accessible.name: action.label
        Row {
            id: actionRow
            anchors.centerIn: parent
            spacing: Math.round(6 * root.d)
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: action.glyph
                iconSize: Math.round(16 * root.d)
                color: IrisStyle.subtext
            }
            IrisText {
                visible: !action.folded
                anchors.verticalCenter: parent.verticalCenter
                text: action.label
                font.family: IrisStyle.monoCaptions ? IrisStyle.fontMono : IrisStyle.fontMain
                font.capitalization: IrisStyle.monoCaptions ? Font.AllUppercase : Font.MixedCase
                font.letterSpacing: IrisStyle.monoCaptions ? Math.round(IrisStyle.typeMeta * 0.12) : 0
                font.pixelSize: IrisStyle.monoCaptions ? IrisStyle.typeMeta : IrisStyle.typeLabel
                font.weight: IrisStyle.weight(Font.Medium)
            }
        }
    }


    component SectionRow: MouseArea {
        id: sectionRow
        required property var modelData
        required property int index
        property var list: root.sections
        property bool gapAbove: true
        // A break between groups of areas: air, and the group's name when it has one (Appearance over Style … Motion).
        readonly property bool clusterStart: sectionRow.gapAbove && sectionRow.index > 0
            && sectionRow.list[sectionRow.index - 1]?.cluster !== sectionRow.modelData.cluster
        readonly property string caption: sectionRow.clusterStart || (sectionRow.gapAbove && sectionRow.index === 0)
            ? String(sectionRow.modelData.caption ?? "") : ""
        readonly property bool selected: !root.searching && root.section === sectionRow.modelData.id
        // Main-list rows hand their selection to the travelling wash (travelWash); footer rows paint their own.
        readonly property bool travels: sectionRow.gapAbove
        // Where you are speaks one colour, the area's own: its glyph fills, the wash under it takes a tint of it and so
        // does its name, a step heavier (DI49i: the chosen row reads at a glance, not only by its wash).
        readonly property color own: IrisStyle.plainMarks ? IrisStyle.accent : sectionRow.modelData.tint
        readonly property real washRadius: Math.min(sectionRow.rowHeight / 2, IrisStyle.iconRadius(sectionMark.width) + sectionMark.x)
        onSelectedChanged: if (sectionRow.selected && sectionRow.travels) root.travelRow = sectionRow
        Component.onCompleted: if (sectionRow.selected && sectionRow.travels) root.travelRow = sectionRow
        Component.onDestruction: if (root.travelRow === sectionRow) root.travelRow = null
        readonly property bool dimmed: root.searching && !root.matchedSections.has(sectionRow.modelData.id)
        // Twenty-seven areas and their captions fit a 1080p window's sidebar without scrolling (DI49g). A caption
        // heads the group under it: more air above than below, or it reads as the foot of the row before.
        readonly property real rowHeight: Math.round(26 * root.d * Math.max(1, IrisStyle.typeScale))
        readonly property real captionHeight: Math.round(22 * root.d * Math.max(1, IrisStyle.typeScale))
        // Where the row's own line starts under the air or the caption of a break; the wash lands there.
        readonly property real washY: sectionRow.caption.length > 0 ? sectionRow.captionHeight : sectionRow.clusterStart ? Math.round(8 * root.d) : 0
        width: parent ? parent.width : 0
        height: sectionRow.washY + sectionRow.rowHeight
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: Translation.tr(sectionRow.modelData.title)
        onClicked: root.selectSection(sectionRow.modelData.id)
        opacity: sectionRow.dimmed ? 0.4 : 1
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
        IrisText {
            visible: sectionRow.caption.length > 0
            x: Math.round(8 * root.d)
            anchors.bottom: rowPlate.top
            anchors.bottomMargin: Math.round(2 * root.d)
            width: sectionRow.width - x
            role: IrisText.Group
            text: Translation.tr(sectionRow.caption)
            elide: Text.ElideRight
        }
        Rectangle {
            id: rowPlate
            anchors.left: parent.left
            y: sectionRow.washY
            width: parent.width
            height: sectionRow.rowHeight
            // Concentric with the mark it holds; where you are is a wash of the area's colour, as light as a hover, never a
            // solid block heavier than the buttons around it.
            radius: IrisStyle.plateSelection ? 0 : sectionRow.washRadius
            color: sectionRow.selected && !sectionRow.travels ? (IrisStyle.plateSelection ? IrisStyle.selectionFill : IrisStyle.tintFillHover(sectionRow.own))
                : sectionRow.selected ? "transparent"
                : sectionRow.containsMouse ? IrisStyle.fillQuiet : "transparent"
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
            // The area's glyph in its own colour, without a tile under it: a column of coloured squares is every
            // settings app's sidebar, and the colour alone already tells the areas apart.
            Item {
                id: sectionMark
                // An indexed Design numbers the areas instead (a parts catalogue).
                readonly property bool numbered: IrisStyle.indexed
                x: Math.round(6 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(20 * root.d)
                height: width
                MaterialSymbol {
                    visible: !sectionMark.numbered
                    anchors.centerIn: parent
                    text: sectionRow.modelData.icon
                    iconSize: Math.round(18 * root.d)
                    fill: sectionRow.selected ? 1 : 0
                    color: sectionRow.selected && IrisStyle.plateSelection ? IrisStyle.selectionInk
                        : IrisStyle.plainMarks ? IrisStyle.textSecondary : sectionRow.modelData.tint
                    Behavior on fill { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                }
            }
            IrisText {
                visible: sectionMark.numbered
                anchors.centerIn: sectionMark
                // The folio runs on through the footer, as a catalogue's pages do: Sources follows the last area.
                text: IrisStyle.indexLabel(sectionRow.gapAbove ? sectionRow.index : root.sideSections.length + sectionRow.index)
                color: sectionRow.selected && IrisStyle.plateSelection ? IrisStyle.selectionDetail : IrisStyle.textTertiary
                font.family: IrisStyle.fontMono
                font.pixelSize: IrisStyle.typeFootnote
                font.weight: Font.Medium
            }
            IrisText {
                x: sectionMark.x + sectionMark.width + Math.round(10 * root.d)
                width: sectionRow.width - x - Math.round(8 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                role: IrisText.Name
                text: Translation.tr(sectionRow.modelData.title)
                // Where you are takes the area's colour, lifted to read on the wash; on a plate (AIRISU) the plate's ink.
                color: sectionRow.selected && IrisStyle.plateSelection ? IrisStyle.selectionLabel
                    : sectionRow.selected ? root.tintInk(sectionRow.own) : IrisStyle.text
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                font.weight: IrisStyle.weight(sectionRow.selected ? Font.Bold : Font.Medium)
                elide: Text.ElideRight
            }
        }
    }

    component StageHero: Rectangle {
        id: hero
        property color tint: IrisStyle.identity.gray
        property string glyph: "settings"
        property string title: ""
        property string text: ""
        property string sceneSection: ""
        property string sceneGroup: ""
        readonly property int pad: Math.round(12 * root.d)
        readonly property bool stageAvailable: stageLoader.item?.available ?? false
        readonly property string caption: stageLoader.item?.caption ?? ""
        // In the group column: the scene at the column's width, its line under it.
        readonly property bool column: root.stageInColumn || root.heroBeside
        readonly property real wordsHeight: heroText.implicitHeight
        // Beside the rows the words under the scene keep one box, two lines of name and two of line, whatever the group
        // the hover shows: the index under them never jumps.
        readonly property real wordsBox: root.heroBeside ? Math.max(heroText.implicitHeight, Math.round(84 * root.d)) : heroText.implicitHeight
        // Measured on the pane, not on itself: its width follows whether it is pinned, which follows this.
        readonly property bool staged: hero.stageAvailable && (root.stageInColumn || (root.split ? detailBody.width : detailBody.width - 56 * root.d) > 560 * root.d)
        // In the pane or the column: the scene across the top, its line under it.
        // On iRiS's own page too (DI24b): the scene across the head at a size that shows it, its words on a band of their
        // own under it, never over the picture nor squeezed beside a thumbnail.
        readonly property bool wideHead: !root.sceneDrawn && !hero.column && !root.split && hero.staged
        readonly property bool banner: (root.split && hero.staged) || hero.column || hero.wideHead
        readonly property real stageH: hero.column ? (root.heroBeside ? root.besideStageHeight : root.columnStageHeight) : root.stageHeight
        // On a Design's page the scene stands alone: the page already says what it shows.
        readonly property bool bare: root.sceneDrawn && hero.column
        Layout.fillWidth: true
        implicitHeight: hero.bare ? hero.stageH : hero.banner ? (hero.column ? 0 : hero.pad) + hero.stageH + Math.round(10 * root.d) + hero.wordsBox + Math.round(6 * root.d)
            // Beside the scene the words decide the height when they need more than the scene's: a head never cuts its line.
            : hero.staged ? Math.max(Math.round(150 * root.d) + 2 * hero.pad, heroText.implicitHeight + 2 * hero.pad) : heroText.implicitHeight + 28 * root.d
        radius: hero.column ? IrisStyle.radiusTile : root.split ? detailPane.radius : IrisStyle.radiusTile
        color: root.split || hero.column ? "transparent" : IrisStyle.readingCard

        RowLayout {
            id: heroText
            visible: !hero.bare
            // The same inset as the rows below, so every mark on the page sits on one column.
            x: hero.column ? Math.round(4 * root.d) : hero.banner ? Math.round(24 * root.d) : Math.round(14 * root.d)
            y: hero.banner ? stageLoader.y + stageLoader.height + Math.round(10 * root.d) : Math.round((hero.height - height) / 2)
            width: hero.banner ? hero.width - x - (hero.column ? 0 : Math.round(16 * root.d))
                : (stageLoader.visible ? stageLoader.x : hero.width) - x - Math.round(16 * root.d)
            spacing: (hero.banner ? 12 : 14) * root.d
            IrisSquircle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Math.round((hero.banner ? 30 : 44) * root.d)
                implicitHeight: implicitWidth
                tint: hero.tint
                glyph: hero.glyph
                glyphShare: 0.58
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3 * root.d
                IrisText {
                    Layout.fillWidth: true
                    text: hero.title
                    font.family: IrisStyle.fontTitle
                    font.pixelSize: IrisStyle.typeHeadline
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    // A half-screen window leaves the title beside the scene a third of the page: it wraps, never cuts.
                    wrapMode: Text.WordWrap
                    maximumLineCount: root.heroBeside ? 2 : 4
                    elide: Text.ElideRight
                }
                IrisText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: hero.text
                    color: IrisStyle.subtext
                    font.pixelSize: IrisStyle.typeLabel
                    wrapMode: Text.WordWrap
                    maximumLineCount: root.heroBeside ? 2 : 6
                    elide: Text.ElideRight
                }
            }
        }
        Loader {
            id: stageLoader
            x: hero.column ? 0 : hero.banner ? hero.pad : hero.width - hero.pad - width
            y: hero.column ? 0 : hero.banner ? hero.pad : Math.round((hero.height - height) / 2)
            width: hero.column ? hero.width : hero.banner ? hero.width - 2 * hero.pad : Math.round(300 * root.d)
            height: hero.banner ? hero.stageH : Math.round(150 * root.d)
            active: hero.sceneSection.length > 0
            visible: hero.staged
            sourceComponent: IrisGroupPreview {
                compact: true
                niriValue: (section, key) => IrisNiri.value(IrisOptions.settings.find(spec => spec.niri === section && spec.key === key) ?? { niri: section, key: key })
                niriRevision: IrisNiri.revision
                radius: hero.column ? IrisStyle.radiusTile : Math.max(IrisStyle.radiusMicro, hero.radius - hero.pad)
                section: hero.sceneSection
                group: hero.sceneGroup
                playing: hero.visible && hero.staged && GlobalStates.settingsOverlayOpen
            }
        }
    }

    component GroupList: ColumnLayout {
        id: list
        required property var modelData
        Layout.fillWidth: true
        spacing: 6 * root.d
        IrisText {
            visible: text.length > 0
            Layout.leftMargin: 16 * root.d
            text: list.modelData.caption
            color: IrisStyle.text
            font.family: IrisStyle.fontTitle
            font.pixelSize: IrisStyle.typeBody
            font.weight: IrisStyle.weight(Font.DemiBold)
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: listColumn.implicitHeight
            radius: IrisStyle.radiusTile
            color: IrisStyle.fieldChamfer ? "transparent" : IrisStyle.readingCard
            IrisCutPlate { anchors.fill: parent; visible: IrisStyle.fieldChamfer; color: IrisStyle.readingCard }
            Column {
                id: listColumn
                width: parent.width
                Repeater {
                    model: ScriptModel { objectProp: "title"; values: list.modelData.groups }
                    GroupRow { last: index === list.modelData.groups.length - 1 }
                }
            }
        }
    }

    component GroupRow: Item {
        id: groupRow
        required property var modelData
        required property int index
        property bool last: false
        readonly property string summary: root.summaryOf(groupRow.modelData)
        readonly property bool modified: root.modifiedIn(groupRow.modelData)
        readonly property var rows: {
            Config.revision
            IrisNiri.revision
            return groupRow.modelData.rows.filter(spec => root.shown(spec))
        }
        readonly property bool staged: sceneProbe.sceneFor(root.section, String(groupRow.modelData.key)).length > 0
        readonly property bool lone: !groupRow.staged && groupRow.rows.length === 1 && groupRow.rows[0].kind === "switch"
        // A group opens in place when what it needs at once fits in a few rows: only its essentials count, the
        // fine-tuning waits behind its own row inside the fold (as on the group's page). Wallpaper › Transition was a
        // whole page for a switch, a style and a duration. A group with a scene folds too: the scene still shows on
        // hover. A gallery or an editable list keeps its page, it needs the width.
        readonly property var tuned: groupRow.rows.filter(spec => IrisOptions.fineTune(spec) && !IrisOptions.changed(spec))
        readonly property bool tuneFolds: groupRow.tuned.length >= 2
        readonly property var essentials: groupRow.tuneFolds ? groupRow.rows.filter(spec => !groupRow.tuned.includes(spec)) : groupRow.rows
        readonly property bool folds: !groupRow.lone && groupRow.essentials.length <= 3
            && !groupRow.rows.some(spec => ["widgets", "pieces", "niriMotion", "list"].includes(spec.kind))
        readonly property string tuneKey: "tune:" + root.section + "/" + String(groupRow.modelData.key ?? groupRow.modelData.title)
        readonly property bool tuneOpen: groupRow.tuneFolds && (root.tuneAll || (root.unfolded[groupRow.tuneKey] ?? false))
        readonly property string foldKey: root.section + "/" + groupRow.modelData.title
        readonly property bool unfolded: groupRow.folds && (root.unfolded[groupRow.foldKey] ?? false)
        readonly property bool loneOn: {
            if (!groupRow.lone) return false
            const spec = groupRow.rows[0]
            const value = IrisOptions.currentValue(spec)
            return spec.invert ? !Boolean(value) : Boolean(value)
        }
        width: parent ? parent.width : 0
        implicitHeight: header.height + (groupRow.unfolded ? foldColumn.implicitHeight : 0)
        clip: true

        MouseArea {
            id: header
            width: parent.width
            height: Math.round(50 * root.d)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // The keyboard walks the rows as the pointer does: Tab or the arrows move, Enter or Space opens, and a row
            // in focus previews its scene as a rested pointer does.
            activeFocusOnTab: true
            readonly property bool groupHeader: true
            function wanted(): void {
                const key = String(groupRow.modelData.key)
                if ((header.containsMouse || header.activeFocus) && groupRow.staged) root.hoverWanted = key
                else if (root.hoverWanted === key) root.hoverWanted = ""
            }
            function activate(): void {
                if (groupRow.lone) IrisOptions.commit(groupRow.rows[0], groupRow.rows[0].invert ? groupRow.loneOn : !groupRow.loneOn)
                else if (groupRow.folds) root.fold(groupRow.foldKey)
                else root.openGroupNamed(groupRow.modelData.title)
            }
            onContainsMouseChanged: header.wanted()
            onActiveFocusChanged: {
                header.wanted()
                if (header.activeFocus) root.reveal(groupRow)
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    header.activate()
                    event.accepted = true
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                    // The arrows go row to row; a row's own switch is for Tab.
                    let next = header.nextItemInFocusChain(event.key === Qt.Key_Down)
                    for (let hops = 0; next && next !== header && next.groupHeader !== true && hops < 64; hops++)
                        next = next.nextItemInFocusChain(event.key === Qt.Key_Down)
                    if (next && next.groupHeader === true) next.forceActiveFocus(event.key === Qt.Key_Down ? Qt.TabFocusReason : Qt.BacktabFocusReason)
                    event.accepted = true
                }
            }
            Component.onDestruction: if (root.hoverWanted === String(groupRow.modelData.key)) root.hoverWanted = ""
            Accessible.role: Accessible.Button
            Accessible.name: groupRow.modelData.title
            Accessible.description: groupRow.summary
            onClicked: header.activate()
            // Concentric with the card the rows lie in; cut like it under a chamfer.
            IrisCutPlate {
                anchors.fill: headerPlate
                visible: IrisStyle.fieldChamfer
                cutLength: IrisStyle.nestedCut(IrisStyle.chamferCut, headerPlate.anchors.margins)
                color: headerPlate.color
            }
            Rectangle {
                id: headerPlate
                anchors.fill: parent
                anchors.margins: 3 * root.d
                visible: !IrisStyle.fieldChamfer
                radius: IrisStyle.concentric(IrisStyle.radiusTile, headerPlate.anchors.margins, IrisStyle.radiusRow)
                color: header.pressed ? IrisStyle.fillActive : header.containsMouse || header.activeFocus ? IrisStyle.fillQuiet : "transparent"
                border.width: header.activeFocus ? Math.max(1, Math.round(1.5 * root.d)) : 0
                border.color: IrisStyle.tintBorder(IrisStyle.accent)
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
            }
            // No mark per row (DI24b): fifteen squircles of one hue said nothing the names do not; the scene beside the
            // rows shows what a group is, on the hover.
            IrisText {
                id: groupTitle
                anchors.left: parent.left
                anchors.leftMargin: 16 * root.d
                anchors.verticalCenter: parent.verticalCenter
                // The summary gets the rest of the row; with nothing to summarise (a lone switch) the name takes it all.
                width: Math.ceil(Math.min(implicitWidth, groupRow.lone || groupRow.summary.length === 0
                    ? parent.width - x - trailing.width - Math.round(28 * root.d) : parent.width * 0.42))
                text: groupRow.lone && !root.sharedLoneLabels[groupRow.rows[0].label] ? Translation.tr(groupRow.rows[0].label) : groupRow.modelData.title
                font.pixelSize: IrisStyle.typeBody
                font.weight: IrisStyle.weight(groupRow.unfolded ? Font.DemiBold : Font.Normal)
                elide: Text.ElideRight
            }
            IrisText {
                anchors.left: groupTitle.right
                anchors.leftMargin: 16 * root.d
                anchors.right: changedDot.left
                anchors.rightMargin: 8 * root.d
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                visible: !groupRow.lone && !groupRow.unfolded
                text: groupRow.summary
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeLabel
                elide: Text.ElideRight
            }
            Rectangle {
                id: changedDot
                anchors.right: trailing.left
                anchors.rightMargin: groupRow.modified ? 8 * root.d : 0
                anchors.verticalCenter: parent.verticalCenter
                width: groupRow.modified ? Math.round(6 * root.d) : 0
                height: width
                radius: IrisStyle.capsule(width)
                color: IrisStyle.accent
                Accessible.name: Translation.tr("Changed")
            }
            Item {
                id: trailing
                anchors.right: parent.right
                anchors.rightMargin: 12 * root.d
                anchors.verticalCenter: parent.verticalCenter
                width: groupRow.lone ? loneSwitch.width : chevron.width
                height: parent.height
                IrisSwitch {
                    id: loneSwitch
                    visible: groupRow.lone
                    anchors.verticalCenter: parent.verticalCenter
                    on: groupRow.loneOn
                    name: groupTitle.text
                    onToggled: IrisOptions.commit(groupRow.rows[0], groupRow.rows[0].invert ? groupRow.loneOn : !groupRow.loneOn)
                }
                MaterialSymbol {
                    id: chevron
                    visible: !groupRow.lone
                    anchors.verticalCenter: parent.verticalCenter
                    text: "chevron_right"
                    iconSize: Math.round(18 * root.d)
                    color: header.containsMouse ? IrisStyle.text : IrisStyle.textTertiary
                    rotation: groupRow.unfolded ? 90 : 0
                    Behavior on rotation { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                }
            }
        }
        Column {
            id: foldColumn
            y: header.height
            x: Math.round(36 * root.d)
            width: parent.width - x
            visible: groupRow.unfolded
            Repeater {
                model: ScriptModel { objectProp: "modelKey"; values: !groupRow.unfolded ? [] : groupRow.tuneOpen ? groupRow.rows : groupRow.essentials }
                IrisSetting {
                    required property var modelData
                    required property int index
                    width: foldColumn.width
                    spec: modelData
                    last: true
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 16 * root.d
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 1
                        color: IrisStyle.hairline
                    }
                }
            }
            FineTuneRow {
                visible: groupRow.unfolded && groupRow.tuneFolds
                width: foldColumn.width
                open: groupRow.tuneOpen
                names: groupRow.tuned.map(spec => Translation.tr(String(spec.label ?? "")))
                onClicked: root.fold(groupRow.tuneKey)
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 16 * root.d
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    color: IrisStyle.hairline
                }
            }
        }
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: groupTitle.x
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            visible: !groupRow.last
            color: IrisStyle.hairline
        }
    }

    component MoreGroup: ColumnLayout {
        id: moreGroup
        required property string modelData
        readonly property var links: (root.searching ? root.pageMatches : root.morePages.filter(entry => Translation.tr(entry.group) === moreGroup.modelData)).map(entry => root.moreLink(entry))
        Layout.fillWidth: true
        spacing: 6 * root.d
        IrisText {
            Layout.leftMargin: 16 * root.d
            text: moreGroup.modelData
            color: IrisStyle.label
            font.family: IrisStyle.fontTitle
            font.pixelSize: IrisStyle.typeMeta
            font.weight: IrisStyle.weight(Font.DemiBold)
        }
        IrisLinkCard { tinted: true; links: moreGroup.links }
    }

    // The foot of a group that folds its fine-tuning: what it holds, by name, and a chevron that turns as it opens.
    component FineTuneRow: MouseArea {
        id: tune
        property bool open: false
        property var names: []
        implicitHeight: Math.round((tune.open ? 44 : 54) * root.d)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: tune.open ? Translation.tr("Fewer settings") : Translation.tr("Fine-tune")
        Accessible.description: tune.names.join(", ")
        IrisCutPlate {
            anchors.fill: tunePlate
            visible: IrisStyle.fieldChamfer
            cutLength: IrisStyle.nestedCut(IrisStyle.chamferCut, tunePlate.anchors.margins)
            color: tunePlate.color
        }
        Rectangle {
            id: tunePlate
            anchors.fill: parent
            anchors.margins: Math.round(4 * root.d)
            visible: !IrisStyle.fieldChamfer
            radius: IrisStyle.concentric(IrisStyle.radiusTile, tunePlate.anchors.margins, IrisStyle.radiusRow)
            color: tune.pressed ? IrisStyle.fillActive : tune.containsMouse ? IrisStyle.fillQuiet : "transparent"
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
        }
        ColumnLayout {
            anchors.left: parent.left
            anchors.leftMargin: Math.round(16 * root.d)
            anchors.right: chevron.left
            anchors.rightMargin: Math.round(12 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(2 * root.d)
            IrisText {
                Layout.fillWidth: true
                text: tune.open ? Translation.tr("Fewer settings") : Translation.tr("Fine-tune")
                color: tune.containsMouse ? IrisStyle.text : IrisStyle.textSecondary
                font.pixelSize: IrisStyle.typeLabel
                font.weight: IrisStyle.weight(Font.Medium)
                elide: Text.ElideRight
            }
            IrisText {
                Layout.fillWidth: true
                visible: !tune.open
                text: tune.names.join(", ")
                color: IrisStyle.textTertiary
                font.pixelSize: IrisStyle.typeFootnote
                elide: Text.ElideRight
            }
        }
        MaterialSymbol {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: Math.round(16 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            text: "expand_more"
            iconSize: Math.round(18 * root.d)
            color: tune.containsMouse ? IrisStyle.text : IrisStyle.textTertiary
            rotation: tune.open ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
        }
    }

    component GroupBlock: ColumnLayout {
        id: group
        required property var modelData
        Layout.fillWidth: true
        spacing: 6 * root.d
        HoverHandler {
            enabled: root.flatSection && root.heroBeside
            onHoveredChanged: root.hoverOver(String(group.modelData.key ?? ""), hovered)
        }
        Component.onDestruction: if (root.hoverWanted === String(group.modelData.key ?? "")) root.hoverWanted = ""
        MouseArea {
            id: resultSection
            readonly property var section: IrisOptions.sectionById(String(group.modelData.rows[0]?.section ?? ""))
            visible: root.searching
            Layout.leftMargin: 14 * root.d
            implicitWidth: resultCaption.implicitWidth
            implicitHeight: resultCaption.implicitHeight
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Link
            Accessible.name: group.modelData.title
            onClicked: root.openResult(group.modelData.rows[0], false)
            Row {
                id: resultCaption
                spacing: 8 * root.d
                IrisSquircle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(18 * root.d)
                    height: width
                    tint: resultSection.section.tint ?? IrisStyle.identity.gray
                    glyph: resultSection.section.icon ?? "settings"
                }
                IrisText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: group.modelData.title
                    // A Design whose marks are plain glyphs tells a section by its words, never by a hue of its own.
                    color: resultSection.containsMouse ? IrisStyle.text : IrisStyle.plainMarks ? IrisStyle.label : (resultSection.section.tint ?? IrisStyle.label)
                    font.family: IrisStyle.fontTitle
                    font.pixelSize: IrisStyle.typeMeta
                    font.weight: IrisStyle.weight(Font.DemiBold)
                }
                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "chevron_right"
                    iconSize: Math.round(14 * root.d)
                    color: IrisStyle.label
                    opacity: resultSection.containsMouse ? 1 : 0
                }
            }
        }
        // A page read whole opens each group on its name, the rows' size a weight above them, over its card (a 12 px
        // caption read smaller than the rows under it; a coloured mark on every head was one rainbow too many).
        // A Design may open each group its own way (AIRISU: the name wide, the sticker stripe, the count in mono, a rule).
        Item {
            id: groupHead
            readonly property string title: String(group.modelData.caption ?? "")
            readonly property int count: group.modelData.rows.length
            // The head holds the group's one switch: the skin makes room for it on its line.
            readonly property bool lone: group.loneSwitch
            readonly property real switchHeight: headSwitch.implicitHeight
            // The group being read, and its part number in the column, for a Design that sets the one in focus apart.
            readonly property bool reading: root.readGroup === String(group.modelData.key ?? "")
            readonly property int folio: root.navGroupIndex(group.modelData)
            readonly property string glyph: root.navGlyph(group.modelData)
            visible: root.flatSection && groupHead.title.length > 0 && headSkin.active
            Layout.fillWidth: true
            // The rows' own inset, so the head's switch stands in their control column.
            Layout.leftMargin: 16 * root.d
            Layout.rightMargin: 16 * root.d
            Layout.topMargin: 18 * root.d
            Layout.bottomMargin: 4 * root.d
            implicitHeight: headSkin.item?.implicitHeight ?? 0
            IrisSkin { id: headSkin; part: "groupHeader"; host: groupHead }
            IrisSwitch {
                id: headSwitch
                visible: group.loneSwitch && headSkin.active
                anchors.right: parent.right
                anchors.top: parent.top
                on: group.loneSwitch && (group.shownRows[0].invert ? !Boolean(IrisOptions.currentValue(group.shownRows[0])) : Boolean(IrisOptions.currentValue(group.shownRows[0])))
                name: groupHead.title
                onToggled: IrisOptions.commit(group.shownRows[0], group.shownRows[0].invert ? on : !on)
            }
        }
        RowLayout {
            visible: root.flatSection && String(group.modelData.caption ?? "").length > 0 && !headSkin.active
            Layout.leftMargin: 16 * root.d
            Layout.topMargin: 10 * root.d
            spacing: 10 * root.d
            IrisText {
                Layout.fillWidth: true
                text: String(group.modelData.caption ?? "")
                color: IrisStyle.text
                font.family: IrisStyle.fontTitle
                font.pixelSize: IrisStyle.typeBody
                font.weight: IrisStyle.weight(Font.DemiBold)
                elide: Text.ElideRight
            }
            IrisSwitch {
                visible: group.loneSwitch
                // On the rows' column: a row's switch sits 16·d in from the card's edge.
                Layout.rightMargin: 16 * root.d
                on: group.loneSwitch && (group.shownRows[0].invert ? !Boolean(IrisOptions.currentValue(group.shownRows[0])) : Boolean(IrisOptions.currentValue(group.shownRows[0])))
                name: String(group.modelData.caption ?? "")
                onToggled: IrisOptions.commit(group.shownRows[0], group.shownRows[0].invert ? on : !on)
            }
        }
        // A long group reads as captioned cards, one per `part` its rows name; search shows one card. Keyed by caption,
        // so a write (a slider mid-drag) never rebuilds a card under the pointer.
        function partOf(spec: var): string { return root.searching ? "" : String(spec.part ?? "") }
        // Essentials first: the group's fine-tuning (IrisOptions.fineTune) waits behind one row at its foot that names
        // what it holds. Only worth it with two or more such rows; a group that is all fine-tuning (Spotlight's prefixes)
        // is its caption over that one row. A search shows everything, and a row you changed stays out where you left it.
        readonly property string tuneKey: "tune:" + root.section + "/" + String(group.modelData.key ?? group.modelData.title)
        readonly property var tuned: {
            Config.revision
            if (root.searching) return []
            return group.modelData.rows.filter(spec => IrisOptions.fineTune(spec) && !IrisOptions.changed(spec))
        }
        readonly property bool folds: group.tuned.length >= 2
        readonly property bool tuneOpen: group.folds && (root.tuneAll || (root.unfolded[group.tuneKey] ?? false))
        readonly property var shownRows: group.folds && !group.tuneOpen ? group.modelData.rows.filter(spec => !group.tuned.includes(spec)) : group.modelData.rows
        // A search result or a link to a folded row opens the fold first, so the row can glow where it lives.
        readonly property bool landsInFold: root.landingPath.length > 0 && group.tuned.some(spec => String(spec.path ?? "") === root.landingPath)
        onLandsInFoldChanged: if (group.landsInFold && !group.tuneOpen) root.fold(group.tuneKey)
        // A group that is all fine-tuning still has one card: its Fine-tune row.
        readonly property var parts: group.shownRows.length === 0 ? [""] : [...new Set(group.shownRows.map(spec => group.partOf(spec)))]
        // A group that is only a switch (a widget not on the desktop) is its head: the name and its switch, no card.
        readonly property bool loneSwitch: {
            Config.revision
            return root.flatSection && String(group.modelData.caption ?? "").length > 0 && !group.folds
                && group.shownRows.length === 1 && group.shownRows[0].kind === "switch"
        }
        Repeater {
            model: ScriptModel { values: group.loneSwitch ? [] : group.parts }
            ColumnLayout {
                id: part
                required property string modelData
                required property int index
                readonly property var rows: group.shownRows.filter(spec => group.partOf(spec) === part.modelData)
                readonly property bool lastPart: part.index === group.parts.length - 1
                Layout.fillWidth: true
                Layout.topMargin: part.index > 0 ? 12 * root.d : 0
                spacing: 6 * root.d
                IrisText {
                    visible: text.length > 0
                    Layout.leftMargin: 16 * root.d
                    text: part.modelData.length > 0 ? Translation.tr(part.modelData) : ""
                    color: IrisStyle.monoCaptions ? IrisStyle.textTertiary : IrisStyle.label
                    font.family: IrisStyle.monoCaptions ? IrisStyle.fontMono : IrisStyle.fontTitle
                    font.pixelSize: IrisStyle.monoCaptions ? IrisStyle.typeCaption : IrisStyle.typeMeta
                    font.weight: IrisStyle.monoCaptions ? Font.Medium : IrisStyle.weight(Font.DemiBold)
                    font.capitalization: IrisStyle.monoCaptions ? Font.AllUppercase : Font.MixedCase
                    font.letterSpacing: IrisStyle.monoCaptions ? Math.round(IrisStyle.typeCaption * 0.16) : 0
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: groupRows.implicitHeight
                    radius: IrisStyle.radiusTile
                    // In the pane the pane is the card: rows sit on it, parts apart by their caption and air.
                    color: root.split || IrisStyle.fieldChamfer ? "transparent" : IrisStyle.readingCard
                    IrisCutPlate { anchors.fill: parent; visible: !root.split && IrisStyle.fieldChamfer; color: IrisStyle.readingCard }
                    ColumnLayout {
                        id: groupRows
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 0
                        Repeater {
                            model: ScriptModel { objectProp: "modelKey"; values: part.rows }
                            IrisSetting {
                                id: settingRow
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                spec: modelData
                                highlight: root.query
                                last: index === part.rows.length - 1 && !(part.lastPart && group.folds)
                                landing: root.landingPath.length > 0 && String(modelData.path ?? "") === root.landingPath
                                onLandingChanged: if (landing) landingReveal.restart()
                                // A row unfolded under the pointer arrives softly; one created already landed still glows.
                                Component.onCompleted: {
                                    if (landing) landingReveal.restart()
                                    if (group.tuned.includes(modelData) && group.tuneOpen) arrive.restart()
                                }
                                NumberAnimation { id: arrive; target: settingRow; property: "opacity"; from: 0; to: 1; duration: IrisStyle.duration(220); easing.type: IrisStyle.feedbackEasing }
                                Timer { id: landingReveal; interval: 120; onTriggered: root.reveal(settingRow) }
                            }
                        }
                        FineTuneRow {
                            visible: part.lastPart && group.folds
                            Layout.fillWidth: true
                            open: group.tuneOpen
                            names: group.tuned.map(spec => Translation.tr(String(spec.label ?? "")))
                            onClicked: root.fold(group.tuneKey)
                        }
                    }
                }
            }
        }
    }

}
