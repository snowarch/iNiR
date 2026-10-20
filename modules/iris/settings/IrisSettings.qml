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
    // A section about hardware this machine lacks is not offered (Battery on a desktop); `inir battery simulate` brings it back.
    readonly property var sections: IrisOptions.sections.filter(section => section.id !== "battery" || Battery.available)
    // Sources and the Community Hub sit in a footer under the list, always in view.
    readonly property int footerCluster: 6
    readonly property var specifications: IrisOptions.settings
    readonly property var currentSection: IrisOptions.sectionById(root.section)
    // The sidebar lists ten categories (DI24, after macOS System Settings): a category of one area opens it, one of
    // several opens a page of its own that lists them. An area keeps owning its rows, its search hits, its IPC name and
    // its history; a category only groups them. Areas this machine does not offer (Battery on a desktop) drop out.
    readonly property var categories: IrisOptions.categories.map(category => Object.assign({}, category, {
        tint: category.tint, sections: category.sections.filter(id => root.sections.some(section => section.id === id)) }))
    readonly property var mainCategories: root.categories.filter(category => !category.foot)
    readonly property var currentCategory: root.categories.find(category => category.sections.includes(root.section)) ?? root.categories[0]
    // A category's own page holds its first area underneath, so every binding on the section stays valid while it shows.
    property string category: ""
    readonly property bool landing: root.category.length > 0 && !root.searching && root.advancedPage < 0
    readonly property var landingCategory: root.categories.find(category => category.id === root.category) ?? null
    // The areas of a category are chosen in the toolbar, on a capsule whose glass puck slides between them (the Island's
    // own gesture), with the category as the page's name; a group page keeps its own name and the area under it.
    readonly property bool areaChoice: !root.searching && !root.landing && root.advancedPage < 0
        && root.group.length === 0 && root.currentCategory.sections.length > 1
    readonly property bool areaSwitchShown: !root.sceneDrawn && root.areaChoice
    function openCategory(id: string): void {
        const category = root.categories.find(entry => entry.id === id)
        if (!category || category.sections.length === 0) return
        if (category.sections.length === 1) root.selectSection(category.sections[0])
        else root.go({ section: category.sections[0], group: "", advancedPage: -1, category: id })
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
    readonly property bool stageInColumn: root.sceneDrawn && !root.landing && pageHero.shown && pageHero.stageAvailable
    readonly property bool heroPinned: !root.stageInColumn && pageHero.shown && pageHero.staged
        && detailBody.height >= (root.split ? root.stageMin + root.stageCaption : pageHero.implicitHeight) + Math.round(260 * root.d)
    // In the pane the scene is a stage across its width that takes the room the rows leave: a short group shows what it
    // makes large, a long one keeps it small and in view while the rows pass under it.
    readonly property real stageCaption: Math.round(52 * root.d)
    readonly property real stageMin: Math.round(168 * root.d)
    readonly property real stageHeight: {
        if (!root.split || !root.heroPinned) return Math.round(150 * root.d)
        // A scene is a picture of the screen: it may grow to the screen's own proportions, never taller.
        const screen = GlobalStates.focusedScreen
        const most = Math.round((detailPane.width - Math.round(24 * root.d)) * (screen ? screen.height / Math.max(1, screen.width) : 0.5625))
        const room = detailBody.height - settingsRows.implicitHeight - root.stageCaption - Math.round(48 * root.d)
        return Math.round(Math.max(root.stageMin, Math.min(most, room)))
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
    // A section reads whole (its groups under captions) up to about fifteen rows; a longer one lists its groups and opens
    // one at a time, as the compact window of 2026-10-05 did. A Design's scene reads whole beside its own index.
    readonly property bool readsWhole: root.columns || root.essentialCount <= 15
    // Beside its index a long section reads one of its blocks at a time, the index pointing into every block: read whole,
    // AIRISU's pane put Appearance's 61 rows or the Lock's 58 on one scroll (the maintainer: "tantos settings juntos en
    // una pantallita te volés loco"). General, the side panels and the Hub keep their own panes.
    readonly property bool pagesPane: root.columns && root.essentialCount > 15 && root.groupChunks.length > 1
        && !["general", "sidebars", "system"].includes(root.section)
    property int paneChunk: 0
    readonly property int shownChunk: root.pagesPane ? Math.min(root.paneChunk, root.groupChunks.length - 1) : -1
    function chunkOf(wanted: string): int {
        const lower = wanted.toLowerCase()
        return root.groupChunks.findIndex(chunk => chunk.groups.some(entry => entry.key === wanted || entry.title === wanted
            || entry.key.toLowerCase() === lower || entry.title.toLowerCase() === lower))
    }
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
            for (const chunk of root.shownChunk >= 0 ? [root.groupChunks[root.shownChunk]] : root.groupChunks)
                for (const group of chunk.groups)
                    out.push({ title: group.title, caption: group.title, key: group.key, rows: group.rows.slice(), loose: false })
            return out
        }
        for (const group of root.groups) {
            const single = group.rows.length === 1
            const previous = out[out.length - 1]
            if (single && previous?.loose && !root.split) { previous.rows = previous.rows.concat(group.rows); continue }
            out.push({ title: single ? "\u200b" + group.key : group.title, caption: single ? "" : group.title, key: group.key, rows: group.rows.slice(), loose: single })
        }
        return out
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
    readonly property var fedGroups: {
        if (root.searching || root.landingPath.length > 0) return root.shownGroups
        const shown = root.fedPage === root.pageKey ? root.blocksShown : 1
        return shown >= root.shownGroups.length ? root.shownGroups : root.shownGroups.slice(0, shown)
    }
    function feedPage(): void {
        root.fedPage = root.pageKey
        root.blocksShown = 1
        blockFeed.restart()
    }
    Timer {
        id: blockFeed
        interval: 16
        repeat: true
        onTriggered: {
            if (root.blocksShown >= root.shownGroups.length) stop()
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
        const value = IrisOptions.currentValue(spec)
        switch (spec.kind) {
        case "switch": {
            const on = spec.invert ? !value : value
            if (spec.label === spec.group) return on ? "" : Translation.tr("Off")
            // A switch's name answers when it is short; a sentence ("Close the shell around the screen") reads as On.
            const name = Translation.tr(spec.label)
            return !on ? "" : name.length <= 24 ? name : Translation.tr("On")
        }
        case "text": return spec.numeric && Number(value ?? 0) === 0 ? "" : String(value ?? "")
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
        if (parts.length === 0 && rows.length > 0 && rows.every(spec => spec.kind === "switch")) return Translation.tr("Off")
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
    function spy(): void {
        if (!root.flatSection) { root.spyGroup = ""; root.readGroup = ""; return }
        let found = ""
        // At the foot of the page the last groups can never rise to the reading line: the last one in view wins.
        const atEnd = settingsFlick.contentY >= settingsFlick.contentHeight - settingsFlick.height - 2 && settingsFlick.contentY > 0
        const targets = root.spyTargets()
        // Before any head reaches the line, the first block on the page is the one being read (the column's order).
        if (root.section !== "general" && targets.length > 0) found = targets[0].key
        for (const target of targets) {
            const top = target.item.mapToItem(settingsFlick.contentItem, 0, 0).y - settingsFlick.contentY
            // The group whose head has reached the upper fifth is the one being read; at the foot, the last one in view.
            if (top > settingsFlick.height * (atEnd ? 0.92 : 0.2)) break
            if (target.key.length > 0) found = target.key
        }
        if (found.length === 0) found = root.section === "general" ? "@welcome" : String(root.groups[0]?.key ?? "")
        if (root.heldGroup.length === 0) root.readGroup = found
        // The scene follows only where the head already carries one: one appearing mid-scroll would pin the head and move the rows.
        root.spyGroup = sceneProbe.sceneFor(root.section, "").length > 0 && found.length > 0
            && sceneProbe.sceneFor(root.section, found).length > 0 ? found : ""
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
        const chunk = root.pagesPane ? root.chunkOf(wanted) : -1
        if (chunk >= 0 && chunk !== root.shownChunk) {
            root.paneChunk = chunk
            settingsFlick.contentY = 0
            root.pendingGroup = wanted
            pendingScroll.restart()
            return
        }
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
        if (!root.columns || root.landing) return []
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
        return id !== "system" && groups.size > 1 && ((root.sceneDrawn && root.paneable)
            || (rows.length <= 15 && !rows.some(spec => ["widgets", "pieces", "niriMotion", "list"].includes(spec.kind))))
    }
    function openResult(spec: var, land: bool): void {
        searchField.text = ""
        root.landingPath = land ? String(spec.path ?? "") : ""
        landingClear.restart()
        root.go({ section: spec.section, group: root.sectionIsFlat(spec.section) ? "" : Translation.tr(spec.group ?? ""), advancedPage: -1 })
        if (root.pagesPane) root.paneChunk = Math.max(0, root.chunkOf(Translation.tr(spec.group ?? "")))
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
    readonly property var pageActions: root.landing ? [] : [rehearseAction, customizeAction, restoreAction].filter(action => action.shown)
    readonly property string titleText: pageTitle.text
    function close(): void { GlobalStates.settingsOverlayOpen = false }
    readonly property var editTargets: ({ bar: "island", player: "bodies", bubbles: "pieces", dock: "dock", appearance: "material", colour: "colour",
        motion: "motion", desktop: "desktop", sidebars: "places", spotlight: "places", controlCenter: "bodies" })
    readonly property var studioTargets: ({ bar: "island", bubbles: "pieces", dock: "dock", appearance: "material", colour: "colour", motion: "motion",
        desktop: "desktop", sidebars: "places", controlCenter: "bodies", spotlight: "places", sound: "transients", notifications: "transients", player: "bodies" })

    function here(): var { return { section: root.section, group: root.group, advancedPage: root.advancedPage, category: root.landing ? root.category : "" } }
    function same(a: var, b: var): bool {
        return a.section === b.section && a.group === b.group && a.advancedPage === b.advancedPage && (a.category ?? "") === (b.category ?? "")
    }
    function arrive(place: var, direction: int): void {
        root.travel = direction
        root.category = place.category ?? ""
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
        // A category's name opens its page (`inir iris settings look`); an area's own name always wins.
        const named = own < 0 && !root.sections.some(s => s.id === root.requestedSection)
            ? root.categories.find(category => category.id === root.requestedSection && category.sections.length > 1) : null
        if (named) section = named.sections[0]
        root.category = named ? named.id : ""
        root.advancedPage = root.landingPage(section, own)
        root.section = section
        root.backStack = []
        root.forwardStack = []
    }
    Component.onCompleted: {
        IrisNiri.ensure()
        if (GlobalStates.settingsOverlayOpen) root.applyRequest()
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
    onSectionChanged: { root.paneChunk = 0; settingsFlick.contentY = 0; root.heldGroup = ""; root.tuneAll = false; IrisOptions.openList = ""; root.enterPage(); spyPace.restart() }
    onPageKeyChanged: Qt.callLater(root.feedPage)
    onOpenGroupChanged: { settingsFlick.contentY = 0; root.enterPage() }
    onAdvancedPageChanged: root.enterPage()

    Shortcut {
        sequence: "Escape"
        enabled: GlobalStates.settingsOverlayOpen
        onActivated: {
            if (root.searching) searchField.text = ""
            else if (root.group.length > 0 && (!root.split || root.generalHome)) root.leaveGroup()
            else if (root.advancedPage >= 0 && !root.pageInPane) root.go({ section: root.section, group: "", advancedPage: -1 })
            else if (!root.windowed) GlobalStates.settingsOverlayOpen = false
        }
    }
    Shortcut { sequence: "Ctrl+F"; enabled: GlobalStates.settingsOverlayOpen; onActivated: searchField.forceActiveFocus() }
    // Typing anywhere on the page searches: a letter no control takes reaches the page and goes to the field.
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
            // more than three quarters of the screen: Settings sits on the desktop, it does not replace it.
            : Math.round(Math.min(parent.width - 32 - IrisFrame.musicReach("left") - IrisFrame.musicReach("right"),
                Math.max(1000 * root.d, parent.width * 0.74), 1320 * root.d))
        height: root.windowed ? parent.height
            // As tall as the sidebar's list of every section (an area under the fold is an area nobody finds): its text
            // keeps its size at any density, so the height is measured, never a number; the screen is the limit.
            : Math.round(Math.min(parent.height - 48 - IrisFrame.musicReach("top") - IrisFrame.musicReach("bottom"),
                Math.max(640 * root.d, root.sidebarNeed)))
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.BackButton | Qt.ForwardButton
            onPressed: mouse => {
                if (mouse.button === Qt.BackButton) root.goBack()
                else if (mouse.button === Qt.ForwardButton) root.goForward()
            }
        }


        IrisSkin { id: pageScene; part: "settingsPage"; wanted: root.sceneFits; host: root }
        // A Design's page holds the capsule of areas in its own head, in its own parts (plate, cut).
        AreaSwitch {
            parent: root.scene?.switchSlot ?? frame
            visible: root.sceneDrawn && root.areaChoice && parent !== frame
            anchors.verticalCenter: parent.verticalCenter
        }

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
                readonly property int float: Math.round(8 * root.d)
                readonly property int pad: IrisStyle.concentricPad(sidebar.radius, 10 * root.d)
                x: sidebar.float
                y: sidebar.float
                height: parent.height - 2 * sidebar.float
                width: sidebarSlot.width - sidebar.float
                clip: true
                radius: IrisStyle.fieldChamfer ? 0 : Math.max(IrisStyle.radiusTile, frame.radius - sidebar.float)
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
                    anchors.topMargin: sidebar.pad + 4 * root.d
                    anchors.bottomMargin: sidebar.pad
                    width: root.sidebarFull - 2 * sidebar.pad + 4 * root.d
                    spacing: 0

                    Item {
                        id: sideSearchSlot
                        visible: !root.sceneDrawn
                        Layout.fillWidth: true
                        Layout.rightMargin: 4 * root.d
                        Layout.bottomMargin: 10 * root.d
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
                                : IrisStyle.tintFillHover(IrisStyle.accent)
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

                            MouseArea {
                                id: profile
                                width: parent.width
                                height: Math.round(50 * root.d)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                Accessible.role: Accessible.Button
                                Accessible.name: Translation.tr("General")
                                onClicked: root.selectSection("general")
                                Rectangle {
                                    height: parent.height
                                    width: parent.width
                                    radius: IrisStyle.radiusRow
                                    color: profile.containsMouse ? IrisStyle.fillHover : "transparent"
                                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                                }
                                FaceAvatar {
                                    id: profileAvatar
                                    x: Math.round(6 * root.d)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.round(40 * root.d)
                                    height: width
                                }
                                Column {
                                    x: Math.round(6 * root.d + profileAvatar.width + 10 * root.d)
                                    width: parent.width - x - Math.round(6 * root.d)
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1
                                    IrisText {
                                        width: parent.width
                                        text: SystemInfo.displayName || SystemInfo.username
                                        font.pixelSize: IrisStyle.typeLabel
                                        font.weight: IrisStyle.weight(Font.DemiBold)
                                        elide: Text.ElideRight
                                    }
                                    Row {
                                        width: parent.width
                                        spacing: 5 * root.d
                                        IrisMark { id: familyMark; implicitSize: Math.round(13 * root.d); anchors.verticalCenter: parent.verticalCenter }
                                        IrisText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.min(implicitWidth, parent.width - familyMark.width - parent.spacing)
                                            elide: Text.ElideRight
                                            // The family, or the Design it wears (AIRISU's spec line in mono).
                                            text: IrisDesign.custom ? `iRiS · ${IrisDesign.name}` : Translation.tr("iRiS · Island family")
                                            color: IrisStyle.muted
                                            font.family: IrisStyle.monoCaptions ? IrisStyle.fontMono : IrisStyle.fontMain
                                            font.capitalization: IrisStyle.monoCaptions ? Font.AllUppercase : Font.MixedCase
                                            font.pixelSize: IrisStyle.monoCaptions ? IrisStyle.typeFootnote : IrisStyle.typeMeta
                                        }
                                    }
                                }
                            }

                            Repeater {
                                model: root.sceneDesigned ? [] : root.mainCategories
                                SectionRow { list: root.mainCategories }
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
                        Layout.topMargin: 6 * root.d
                        Layout.bottomMargin: 6 * root.d
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
                        // With no history (opened by name), back climbs to the category the area belongs to.
                        readonly property bool climbs: root.backStack.length === 0 && !root.landing && !root.searching
                            && root.advancedPage < 0 && root.currentCategory.sections.length > 1
                        materialIcon: "chevron_left"
                        enabled: root.backStack.length > 0 || climbs
                        opacity: enabled ? 1 : 0.35
                        onClicked: climbs ? root.openCategory(root.currentCategory.id) : root.goBack()
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
                                : root.landing ? Translation.tr(root.landingCategory?.title ?? "")
                                : root.areaSwitchShown ? Translation.tr(root.currentCategory.title)
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
                            visible: !root.searching && !root.columns && !root.landing && !root.areaSwitchShown && root.advancedPage < 0
                                && root.openGroup.length > 0 && root.openGroup !== Translation.tr(root.currentSection.title)
                            text: Translation.tr(root.currentSection.title)
                            color: IrisStyle.muted
                            font.pixelSize: IrisStyle.typeMeta
                            elide: Text.ElideRight
                        }
                    }
                    AreaSwitch {
                        visible: root.areaSwitchShown
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: Math.round(6 * root.d)
                    }
                    // The actions keep their words while the page's name still reads whole beside them (up to 260·d of
                    // it); measured in the language on screen, never a fixed window width.
                    RowLayout {
                        id: toolbarActions
                        // A category's page changes nothing itself: its areas carry the actions.
                        visible: !root.landing
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
                                visible: settingsFlick.visible && root.heroPinned
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

                            StageHero {
                                id: pageHero
                                readonly property bool groupPage: !root.searching && root.openGroup.length > 0 && root.advancedPage < 0
                                readonly property bool sectionPage: root.browsing && root.section !== "system" && root.section !== "general" && root.section !== "gaming"
                                readonly property bool spying: !pageHero.groupPage && root.spyGroup.length > 0
                                readonly property string key: pageHero.spying ? root.spyGroup : String(root.shownGroups[0]?.key ?? "")
                                // A group with no scene has no head: the toolbar already names it.
                                readonly property bool shown: pageHero.sectionPage || (pageHero.groupPage && pageHero.stageAvailable)
                                parent: root.stageInColumn ? root.scene.stageSlot : root.heroPinned ? heroPinSlot : heroFlowSlot
                                width: root.stageInColumn ? root.columnStageWidth : root.split && root.heroPinned ? detailBody.width : settingsRows.width
                                // A Design's page names the page itself: the head is only its scene there.
                                visible: pageHero.shown && !root.landing && (!root.sceneDrawn || root.stageInColumn)
                                tint: pageHero.groupPage || pageHero.spying ? (IrisOptions.groupTints[pageHero.key] ?? root.currentSection.tint) : root.currentSection.tint
                                glyph: pageHero.groupPage || pageHero.spying ? (IrisOptions.groupGlyphs[pageHero.key] ?? root.currentSection.icon) : root.currentSection.icon
                                title: !pageHero.groupPage && !pageHero.spying ? Translation.tr(root.currentSection.subtitle)
                                    : pageHero.caption.length > 0 ? pageHero.caption : pageHero.spying ? Translation.tr(root.spyGroup) : root.openGroup
                                text: pageHero.groupPage ? "" : Translation.tr(root.currentSection.tip ?? "")
                                sceneSection: pageHero.sectionPage || pageHero.groupPage ? root.section : ""
                                sceneGroup: pageHero.groupPage || pageHero.spying ? pageHero.key : ""
                            }

                            CategoryPage {
                                anchors.fill: parent
                                visible: root.landing
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
                                anchors.topMargin: root.heroPinned ? heroPinSlot.y + heroPinSlot.height + Math.round(12 * root.d) : 0
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
                                visible: root.advancedPage < 0 && !root.landing
                                onContentYChanged: if (root.flatSection) spyPace.start()
                                // Rows laid after the section changed (a Place opening, a fold) move every head: the reading is taken again.
                                onContentHeightChanged: if (root.flatSection) spyPace.restart()
                                contentHeight: settingsRows.implicitHeight + 32 * root.d
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: IrisScrollBar {}

                                ColumnLayout {
                                    id: settingsRows
                                    y: 6 * root.d
                                    // In the pane the rows run its width (their own inset keeps the text off its edge).
                                    width: root.split ? settingsFlick.width - Math.round(16 * root.d) : Math.min(settingsFlick.width - 56 * root.d, 820 * root.d)
                                    x: Math.round((settingsFlick.width - width) / 2)
                                    spacing: 18 * root.d

                                    // The head reads here only when it carries no scene, or the window is too short to keep one in view.
                                    Item {
                                        id: heroFlowSlot
                                        Layout.fillWidth: true
                                        visible: pageHero.shown && !root.heroPinned && !root.stageInColumn && !root.sceneDrawn
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
        // The profile above is a cluster of its own: the first row takes the same air as every other break.
        readonly property bool clusterStart: sectionRow.gapAbove && (sectionRow.index === 0
            || sectionRow.list[sectionRow.index - 1]?.cluster !== sectionRow.modelData.cluster)
        // A category row stands for every area it groups; a footer row for its own.
        readonly property var members: sectionRow.modelData.sections ?? [sectionRow.modelData.id]
        readonly property bool selected: !root.searching && sectionRow.members.includes(root.section)
        // Main-list rows hand their selection to the travelling wash (travelWash); footer rows paint their own.
        readonly property bool travels: sectionRow.gapAbove
        readonly property real washRadius: Math.min(sectionRow.rowHeight / 2, IrisStyle.iconRadius(sectionMark.width) + sectionMark.x)
        onSelectedChanged: if (sectionRow.selected && sectionRow.travels) root.travelRow = sectionRow
        Component.onCompleted: if (sectionRow.selected && sectionRow.travels) root.travelRow = sectionRow
        Component.onDestruction: if (root.travelRow === sectionRow) root.travelRow = null
        readonly property bool dimmed: root.searching && !sectionRow.members.some(id => root.matchedSections.has(id))
        readonly property real rowHeight: Math.round(28 * root.d * Math.max(1, IrisStyle.typeScale))
        // Where the row's own line starts under the air of a break; the wash lands there.
        readonly property real washY: sectionRow.clusterStart ? Math.round(8 * root.d) : 0
        width: parent ? parent.width : 0
        height: sectionRow.washY + sectionRow.rowHeight
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: Translation.tr(sectionRow.modelData.title)
        onClicked: sectionRow.modelData.sections ? root.openCategory(sectionRow.modelData.id) : root.selectSection(sectionRow.modelData.id)
        opacity: sectionRow.dimmed ? 0.4 : 1
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
        Rectangle {
            anchors.left: parent.left
            y: sectionRow.washY
            width: parent.width
            height: sectionRow.rowHeight
            // Concentric with the mark it holds; where you are is a wash of the accent, as light as a hover, never a
            // solid block heavier than the buttons around it.
            radius: IrisStyle.plateSelection ? 0 : sectionRow.washRadius
            color: sectionRow.selected && !sectionRow.travels ? (IrisStyle.plateSelection ? IrisStyle.selectionFill : IrisStyle.tintFillHover(IrisStyle.accent))
                : sectionRow.selected ? "transparent"
                : sectionRow.containsMouse ? IrisStyle.fillQuiet : "transparent"
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
            IrisSquircle {
                id: sectionMark
                // An indexed Design numbers the areas instead (a parts catalogue).
                readonly property bool numbered: IrisStyle.indexed
                visible: !sectionMark.numbered
                x: Math.round(6 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(22 * root.d)
                height: width
                tint: sectionRow.modelData.tint
                glyph: sectionRow.modelData.icon
                ink: sectionRow.selected && IrisStyle.plateSelection ? IrisStyle.selectionInk : IrisStyle.plainMarks ? IrisStyle.textSecondary : IrisStyle.onTint
            }
            IrisText {
                visible: sectionMark.numbered
                anchors.centerIn: sectionMark
                // The folio runs on through the footer, as a catalogue's pages do: Sources follows the last area.
                text: IrisStyle.indexLabel(sectionRow.modelData.sections ? sectionRow.index : root.mainCategories.length + sectionRow.index)
                color: sectionRow.selected && IrisStyle.plateSelection ? IrisStyle.selectionDetail : IrisStyle.textTertiary
                font.family: IrisStyle.fontMono
                font.pixelSize: IrisStyle.typeFootnote
                font.weight: Font.Medium
            }
            IrisText {
                x: sectionMark.x + sectionMark.width + Math.round(10 * root.d)
                width: sectionRow.width - x - Math.round(8 * root.d)
                anchors.rightMargin: 8 * root.d
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr(sectionRow.modelData.title)
                // Where you are reads in the accent and a step heavier; the wash under it only supports that. On a plate
                // (AIRISU) it is the plate's own ink.
                color: sectionRow.selected ? (IrisStyle.plateSelection ? IrisStyle.selectionLabel : IrisStyle.accent) : IrisStyle.text
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                font.pixelSize: IrisStyle.typeLabel
                font.weight: IrisStyle.weight(sectionRow.selected ? Font.DemiBold : Font.Medium)
                elide: Text.ElideRight
            }
        }
    }

    // A category's own page (DI24): its areas as a mosaic of their own live scenes, each tile the shell doing what that
    // area changes, its name over the picture. You choose by what you see, not by a list of icons.
    component CategoryPage: Flickable {
        id: categoryPage
        readonly property var areas: (root.landingCategory?.sections ?? []).map(id => IrisOptions.sectionById(id)).filter(area => !!area)
        clip: true
        contentHeight: mosaic.implicitHeight + Math.round(40 * root.d)
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: IrisScrollBar {}
        GridLayout {
            id: mosaic
            y: Math.round(8 * root.d)
            width: root.split ? categoryPage.width - Math.round(16 * root.d) : Math.min(categoryPage.width - 56 * root.d, 860 * root.d)
            x: Math.round((categoryPage.width - width) / 2)
            columns: 2
            columnSpacing: Math.round(12 * root.d)
            rowSpacing: Math.round(12 * root.d)
            Repeater {
                model: categoryPage.areas
                // An odd count leads with one tile across the page: the mosaic never ends on a hole.
                AreaTile { wide: categoryPage.areas.length % 2 === 1 && index === 0 }
            }
        }
    }

    component AreaTile: MouseArea {
        id: tile
        required property var modelData
        required property int index
        property bool wide: false
        readonly property bool pictured: scene.item?.available ?? false
        readonly property real round: IrisStyle.fieldChamfer ? 0 : IrisStyle.radiusTile + Math.round(6 * root.d)
        readonly property real inset: Math.round(6 * root.d)
        readonly property real band: Math.round(76 * root.d)
        Layout.columnSpan: tile.wide ? 2 : 1
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: Math.round((tile.wide ? 250 : 210) * root.d)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: Translation.tr(tile.modelData.title)
        Accessible.description: Translation.tr(tile.modelData.subtitle ?? "")
        onClicked: root.selectSection(tile.modelData.id)
        scale: tile.pressed ? 0.985 : 1
        Behavior on scale { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }

        Rectangle {
            anchors.fill: parent
            radius: tile.round
            color: tile.containsMouse ? IrisStyle.fillQuiet : IrisStyle.readingCard
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
        }
        // An area with no scene of its own wears its hue as a wash with its mark large in it.
        Rectangle {
            anchors.fill: scene
            radius: IrisStyle.concentric(tile.round, tile.inset, IrisStyle.radiusRow)
            visible: !tile.pictured
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: IrisStyle.tintFillHover(tile.modelData.tint) }
                GradientStop { position: 1; color: IrisStyle.readingCard }
            }
            MaterialSymbol {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -Math.round(18 * root.d)
                text: tile.modelData.icon
                fill: 1
                iconSize: Math.round(64 * root.d)
                color: tile.modelData.tint
            }
        }
        Loader {
            id: scene
            // The scene inset in the tile like a picture in its mount, concentric with it; the words have the band under it.
            anchors.fill: parent
            anchors.margins: tile.inset
            anchors.bottomMargin: tile.band
            asynchronous: true
            sourceComponent: IrisGroupPreview {
                compact: true
                niriValue: (section, key) => IrisNiri.value(IrisOptions.settings.find(spec => spec.niri === section && spec.key === key) ?? { niri: section, key: key })
                niriRevision: IrisNiri.revision
                radius: IrisStyle.concentric(tile.round, tile.inset, IrisStyle.radiusRow)
                section: tile.modelData.id
                group: ""
                playing: tile.containsMouse && root.landing && GlobalStates.settingsOverlayOpen
            }
        }
        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            // Hung from the top of the band: neighbours' names stay on one line whatever their lines wrap to.
            anchors.top: scene.bottom
            anchors.topMargin: Math.round(10 * root.d)
            anchors.leftMargin: Math.round(14 * root.d)
            anchors.rightMargin: Math.round(14 * root.d)
            id: tileWords
            spacing: Math.round(2 * root.d)
            RowLayout {
                spacing: Math.round(8 * root.d)
                IrisSquircle {
                    implicitWidth: Math.round(22 * root.d)
                    implicitHeight: implicitWidth
                    tint: tile.modelData.tint
                    glyph: tile.modelData.icon
                }
                IrisText {
                    Layout.fillWidth: true
                    text: Translation.tr(tile.modelData.title)
                    font.family: IrisStyle.fontTitle
                    font.pixelSize: IrisStyle.typeTitle
                    font.weight: IrisStyle.weight(Font.Bold)
                    font.capitalization: IrisStyle.lowerTitles ? Font.AllLowercase : Font.MixedCase
                    elide: Text.ElideRight
                }
            }
            IrisText {
                Layout.fillWidth: true
                text: Translation.tr(tile.modelData.subtitle ?? "")
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeMeta
                // The whole line, on two lines when the tile is narrow: a cut-off line says less than none.
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }
        }
        // Hover lights the tile's edge in the accent, as a focused body is lit.
        Rectangle {
            anchors.fill: parent
            radius: tile.round
            color: "transparent"
            border.width: Math.max(1, Math.round(1.5 * root.d))
            border.color: tile.containsMouse ? IrisStyle.tintBorder(IrisStyle.accent) : IrisStyle.hairline
            Behavior on border.color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
        }
    }

    // The areas of the open category on one capsule: a glass puck slides to the one you read, with the morph's curve.
    component AreaSwitch: Item {
        id: areaSwitch
        readonly property var areas: root.currentCategory.sections.map(id => IrisOptions.sectionById(id)).filter(area => !!area)
        readonly property int chosen: areaSwitch.areas.findIndex(area => area.id === root.section)
        readonly property real pad: Math.round(3 * root.d)
        // The segment being read hands itself over (as a sidebar row hands the wash its place): a lookup by index ran
        // before the row had laid its segments out and left the puck nowhere.
        property Item chosenItem: null
        implicitHeight: Math.round(32 * root.d)
        implicitWidth: switchRow.implicitWidth + 2 * areaSwitch.pad
        Rectangle {
            anchors.fill: parent
            radius: IrisStyle.fieldChamfer ? 0 : height / 2
            color: IrisStyle.fillQuiet
            border.width: 1
            border.color: IrisStyle.hairline
        }
        Rectangle {
            id: puck
            visible: areaSwitch.chosenItem !== null
            y: areaSwitch.pad
            height: parent.height - 2 * areaSwitch.pad
            x: areaSwitch.pad + (areaSwitch.chosenItem?.x ?? 0)
            width: areaSwitch.chosenItem?.width ?? 0
            radius: IrisStyle.fieldChamfer ? 0 : height / 2
            color: IrisStyle.plateSelection ? IrisStyle.selectionFill : IrisStyle.tintFillHover(IrisStyle.accent)
            border.width: 1
            border.color: IrisStyle.plateSelection ? "transparent" : IrisStyle.tintBorder(IrisStyle.accent)
            Behavior on x { enabled: IrisStyle.motionEnabled; NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
            Behavior on width { enabled: IrisStyle.motionEnabled; NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
        }
        Row {
            id: switchRow
            x: areaSwitch.pad
            y: areaSwitch.pad
            height: parent.height - 2 * areaSwitch.pad
            Repeater {
                id: switchRepeater
                model: areaSwitch.areas
                MouseArea {
                    id: segment
                    required property var modelData
                    required property int index
                    readonly property bool here: segment.index === areaSwitch.chosen
                    onHereChanged: if (segment.here) areaSwitch.chosenItem = segment
                    Component.onCompleted: if (segment.here) areaSwitch.chosenItem = segment
                    Component.onDestruction: if (areaSwitch.chosenItem === segment) areaSwitch.chosenItem = null
                    width: segmentLabel.implicitWidth + Math.round(26 * root.d)
                    height: switchRow.height
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: Translation.tr(segment.modelData.title)
                    onClicked: root.selectSection(segment.modelData.id)
                    IrisText {
                        id: segmentLabel
                        anchors.centerIn: parent
                        text: Translation.tr(segment.modelData.title)
                        color: segment.here ? (IrisStyle.plateSelection ? IrisStyle.selectionLabel : IrisStyle.text)
                            : segment.containsMouse ? IrisStyle.text : IrisStyle.muted
                        font.pixelSize: IrisStyle.typeMeta
                        font.weight: IrisStyle.weight(segment.here ? Font.DemiBold : Font.Medium)
                        Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                    }
                }
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
        readonly property bool column: root.stageInColumn
        // Measured on the pane, not on itself: its width follows whether it is pinned, which follows this.
        readonly property bool staged: hero.stageAvailable && (hero.column || (root.split ? detailBody.width : settingsRows.width) > 560 * root.d)
        // In the pane or the column: the scene across the top, its line under it.
        // On iRiS's own page too (DI24b): the scene across the head at a size that shows it, its words on a band of their
        // own under it, never over the picture nor squeezed beside a thumbnail.
        readonly property bool wideHead: !root.sceneDrawn && !hero.column && !root.split && hero.staged
        readonly property bool banner: (root.split && hero.staged) || hero.column || hero.wideHead
        readonly property real stageH: hero.column ? root.columnStageHeight : hero.wideHead ? Math.round(196 * root.d) : root.stageHeight
        // On a Design's page the scene stands alone: the page already says what it shows.
        readonly property bool bare: root.sceneDrawn && hero.column
        Layout.fillWidth: true
        implicitHeight: hero.bare ? hero.stageH : hero.banner ? (hero.column ? 0 : hero.pad) + hero.stageH + Math.round(10 * root.d) + heroText.implicitHeight + Math.round(6 * root.d)
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
            width: hero.banner ? hero.width - x - Math.round(16 * root.d)
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
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }
                IrisText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: hero.text
                    color: IrisStyle.subtext
                    font.pixelSize: IrisStyle.typeLabel
                    wrapMode: Text.WordWrap
                    maximumLineCount: 6
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
            // A block whose groups feed one another (colour: source, mode, accent, material, apps) threads its marks
            // together, under them, from the first to the last.
            Rectangle {
                visible: list.modelData.flow ?? false
                x: Math.round(27 * root.d - width / 2)
                y: Math.round(23 * root.d)
                width: Math.max(1, Math.round(2 * root.d))
                height: Math.max(0, parent.height - 46 * root.d)
                radius: IrisStyle.capsule(width)
                color: IrisStyle.hairlineStrong
            }
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
        readonly property bool folds: !groupRow.staged && !groupRow.lone && groupRow.rows.length <= 3
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
            height: Math.round(46 * root.d)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: groupRow.modelData.title
            Accessible.description: groupRow.summary
            onClicked: {
                if (groupRow.lone) IrisOptions.commit(groupRow.rows[0], groupRow.rows[0].invert ? groupRow.loneOn : !groupRow.loneOn)
                else if (groupRow.folds) root.fold(groupRow.foldKey)
                else root.openGroupNamed(groupRow.modelData.title)
            }
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
                color: header.pressed ? IrisStyle.fillActive : header.containsMouse ? IrisStyle.fillQuiet : "transparent"
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
            }
            IrisSquircle {
                id: groupMark
                anchors.left: parent.left
                anchors.leftMargin: 14 * root.d
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(26 * root.d)
                height: width
                // One hue per page, the section's: the sidebar is where colour tells areas apart.
                tint: root.currentSection.tint
                glyph: IrisOptions.groupGlyphs[groupRow.modelData.key] ?? root.currentSection.icon
            }
            IrisText {
                id: groupTitle
                anchors.left: groupMark.right
                anchors.leftMargin: 12 * root.d
                anchors.verticalCenter: parent.verticalCenter
                // The summary gets the rest of the row; with nothing to summarise (a lone switch) the name takes it all.
                width: Math.ceil(Math.min(implicitWidth, groupRow.lone || groupRow.summary.length === 0
                    ? parent.width - x - trailing.width - Math.round(28 * root.d) : parent.width * 0.42))
                text: groupRow.lone ? Translation.tr(groupRow.rows[0].label) : groupRow.modelData.title
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
                model: ScriptModel { objectProp: "modelKey"; values: groupRow.unfolded ? groupRow.rows : [] }
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
