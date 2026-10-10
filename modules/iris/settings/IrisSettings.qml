pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings
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
    readonly property real d: IrisStyle.density
    readonly property var sections: IrisOptions.sections
    // Sources and More Settings sit in a footer under the list, always in view.
    readonly property int footerCluster: 6
    readonly property var specifications: IrisOptions.settings
    readonly property var currentSection: IrisOptions.sectionById(root.section)
    readonly property bool searching: root.query.length > 0
    // Sidebar (every area beside the page), Rail (only their marks) or Home (every area on one page, each opened full width).
    readonly property string layoutStyle: String(Config.options?.iris?.appearance?.settingsLayout ?? "sidebar")
    readonly property bool railLayout: root.layoutStyle === "rail"
    readonly property bool homeLayout: root.layoutStyle === "home"
    readonly property bool atHome: root.homeLayout && root.section === "home" && !root.searching && root.advancedPage < 0
    onHomeLayoutChanged: if (!root.homeLayout && root.section === "home") root.section = "general"
    // The section a rail mark is pointed at: its name shows on a capsule beside the rail.
    property var railHint: null
    // A section with a single group has nothing to choose between: it opens on that group.
    readonly property string openGroup: root.searching ? ""
        : root.group.length > 0 ? root.group
        : root.groups.length === 1 ? root.groups[0].title : ""
    readonly property bool browsing: !root.searching && root.openGroup.length === 0 && root.advancedPage < 0
    // The page's head stays in view while its rows scroll when it shows a scene, unless the window is so short that the
    // rows would be left a sliver: then it scrolls with them.
    readonly property bool heroPinned: pageHero.shown && pageHero.staged
        && pageArea.height >= pageHero.implicitHeight + Math.round(260 * root.d)
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
            .filter(hit => hit.score < 99 && root.shown(hit.spec))
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
            const title = root.searching
                ? Translation.tr(IrisOptions.sectionById(spec.section).title)
                : Translation.tr(spec.group ?? "")
            let group = out.find(entry => entry.title === title)
            if (!group) { group = { title: title, key: String(spec.group ?? ""), rows: [] }; out.push(group) }
            group.rows.push(spec)
        }
        return out
    }
    readonly property var shownGroups: root.searching ? root.groups
        : root.openGroup.length > 0 ? root.groups.filter(entry => entry.title === root.openGroup) : []
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
            return on ? Translation.tr(spec.label) : ""
        }
        case "text": return String(value ?? "")
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
        return parts.slice(0, 2).join(", ")
    }
    function modifiedIn(entry: var): bool {
        Config.revision
        return entry.rows.some(spec => IrisOptions.modified(spec))
    }
    readonly property var pages: SettingsPageRegistry.pages.map(page => Object.assign({}, page, { component: Quickshell.shellPath(root.irisPageFor(page.key) || page.component) }))
    function irisPageFor(key: string): string {
        if (key === "about") return "modules/iris/settings/IrisAboutPage.qml"
        if (key === "shortcuts") return "modules/iris/settings/IrisShortcutsPage.qml"
        if (key === "hub") return "modules/iris/settings/IrisHubPage.qml"
        return ""
    }
    property var unfolded: ({})
    function fold(key: string): void {
        const next = Object.assign({}, root.unfolded)
        next[key] = !next[key]
        root.unfolded = next
    }
    IrisGroupPreview { id: sceneProbe; visible: false; section: ""; group: "" }
    readonly property int irisPageIndex: root.pages.findIndex(page => page.key === "iris")
    readonly property var morePages: IrisOptions.morePages.filter(entry => root.pages.some(page => page.key === entry.key))
    readonly property var moreGroups: [...new Set(root.morePages.map(entry => Translation.tr(entry.group)))]
    readonly property var pageMatches: {
        const terms = root.query.toLowerCase().split(/\s+/).filter(term => term.length > 0)
        if (terms.length === 0) return []
        return root.morePages.filter(entry => {
            const text = [Translation.tr(entry.label), Translation.tr(entry.detail), ...(entry.keywords ?? [])].join(" ").toLowerCase()
            return terms.every(term => text.includes(term))
        })
    }
    readonly property bool pagesFirst: root.pageMatches.some(entry => Translation.tr(entry.label).toLowerCase().startsWith(root.query.trim().toLowerCase()))
    function openFirstResult(): void {
        if (root.pageMatches.length > 0 && (root.pagesFirst || root.matches.length === 0)) {
            root.moreLink(root.pageMatches[0]).action()
            return
        }
        const spec = root.matches[0]
        if (!spec) return
        searchField.text = ""
        root.go({ section: spec.section, group: Translation.tr(spec.group ?? ""), advancedPage: -1 })
    }
    function pageIndexOf(key: string): int { return root.pages.findIndex(page => page.key === key) }
    function moreLink(entry: var): var {
        return { label: Translation.tr(entry.label), value: Translation.tr(entry.detail), icon: entry.icon, tint: entry.tint,
            action: () => { searchField.text = ""; root.go({ section: "system", group: "", advancedPage: root.pageIndexOf(entry.key) }) } }
    }
    function pageTitle(index: int): string {
        const page = root.pages[index]
        const entry = IrisOptions.morePages.find(candidate => candidate.key === page?.key)
        return entry ? Translation.tr(entry.label) : String(page?.name ?? page?.title ?? "")
    }
    readonly property var editTargets: ({ bar: "island", player: "bodies", bubbles: "pieces", dock: "dock", appearance: "material", colour: "colour",
        motion: "motion", desktop: "desktop", sidebars: "places", spotlight: "places", controlCenter: "bodies" })
    readonly property var studioTargets: ({ bar: "island", bubbles: "pieces", dock: "dock", appearance: "material", colour: "colour", motion: "motion",
        desktop: "desktop", sidebars: "places", controlCenter: "bodies", spotlight: "places", sound: "transients", notifications: "transients", player: "bodies" })

    function here(): var { return { section: root.section, group: root.group, advancedPage: root.advancedPage } }
    function same(a: var, b: var): bool { return a.section === b.section && a.group === b.group && a.advancedPage === b.advancedPage }
    function arrive(place: var, direction: int): void {
        root.travel = direction
        root.section = place.section
        root.group = place.group
        root.advancedPage = place.advancedPage
        if (searchField.text.length > 0) searchField.text = ""
    }
    function go(place: var): void {
        const now = root.here()
        if (root.same(now, place) && !root.searching) return
        root.backStack = root.backStack.concat([now]).slice(-40)
        root.forwardStack = []
        root.arrive(place, 1)
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
                if (match) root.group = match.title
            }
        }
    }
    // A link written before a topic got its own section (appearance/Accent, lock/Login screen, desktop/Wallpaper gallery)
    // still lands: a group asked for where it no longer is opens in the section that holds it now.
    readonly property var renamedGroups: ({ "appearance/wallpaper": "Wallpaper tint" })
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
        else return false
        return true
    }
    function applyRequest(): void {
        const verb = String(GlobalStates.settingsOverlayRequestedSection ?? "")
        if (GlobalStates.settingsOverlayRequestedPage === root.irisPageIndex && root.runCommand(verb)) {
            GlobalStates.settingsOverlayRequestedSection = ""
            GlobalStates.settingsOverlayCurrentPage = GlobalStates.settingsOverlayRequestedPage
            GlobalStates.settingsOverlayRequestedPage = -1
            return
        }
        if (GlobalStates.settingsOverlayRequestedPage >= 0) root.group = ""
        const request = String(GlobalStates.settingsOverlayRequestedSection ?? "").split("/")
        root.requestedSection = request[0] ?? ""
        if (request.length > 1) {
            root.requestedGroup = request.slice(1).join("/")
            groupRequest.restart()
        } else if (request[0].length > 0) {
            // A new place without a group drops a group still waiting from the last request.
            groupRequest.stop()
            root.requestedGroup = ""
        }
        GlobalStates.settingsOverlayRequestedSection = ""
        root.followMovedGroup()
        const page = GlobalStates.settingsOverlayRequestedPage
        if (page >= 0) {
            const irisPage = page === root.irisPageIndex
            root.advancedPage = irisPage ? -1 : page
            root.section = irisPage || root.irisPageFor(String(root.pages[page]?.key ?? "")).length > 0 ? (root.homeLayout ? "home" : "general") : "system"
            if (irisPage && root.sections.some(s => s.id === root.requestedSection))
                root.section = root.requestedSection
            GlobalStates.settingsOverlayCurrentPage = page
            GlobalStates.settingsOverlayRequestedPage = -1
            root.backStack = []
            root.forwardStack = []
        }
    }
    Component.onCompleted: {
        IrisNiri.ensure()
        if (GlobalStates.settingsOverlayOpen) root.applyRequest()
    }
    Connections {
        target: GlobalStates
        function onSettingsOverlayRequestedPageChanged(): void { Qt.callLater(root.applyRequest) }
        function onSettingsOverlayOpenChanged(): void {
            if (!GlobalStates.settingsOverlayOpen) return
            IrisNiri.ensure()
            root.applyRequest()
        }
    }
    onSectionChanged: { settingsFlick.contentY = 0; pageEnter.restart() }
    onOpenGroupChanged: { settingsFlick.contentY = 0; pageEnter.restart() }
    onAdvancedPageChanged: pageEnter.restart()

    Shortcut {
        sequence: "Escape"
        enabled: GlobalStates.settingsOverlayOpen
        onActivated: {
            if (root.searching) searchField.text = ""
            else if (root.group.length > 0) root.leaveGroup()
            else if (root.advancedPage >= 0) root.go({ section: root.section, group: "", advancedPage: -1 })
            else if (!root.windowed) GlobalStates.settingsOverlayOpen = false
        }
    }
    Shortcut { sequence: "Ctrl+F"; enabled: GlobalStates.settingsOverlayOpen; onActivated: searchField.forceActiveFocus() }
    // The other host opens where this one stands.
    function switchHost(): void {
        if (root.advancedPage < 0) {
            GlobalStates.settingsOverlayRequestedSection = root.section + (root.group.length > 0 ? "/" + root.group : "")
            GlobalStates.settingsOverlayRequestedPage = root.irisPageIndex
        } else {
            GlobalStates.settingsOverlayRequestedPage = root.advancedPage
        }
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
        open: root.windowed || GlobalStates.settingsOverlayOpen
        color: IrisStyle.surface
        light: IrisStyle.surfaceLight("settings", IrisStyle.wallpaperLight)
        radius: root.windowField ? Number(IrisNiri.data["window-rules"]?.corner_radius ?? 16)
            : root.windowed ? 0 : IrisStyle.surfaceRadius("settings", IrisStyle.radiusPanel)
        onClosed: GlobalStates.irisMorphOwner = ""
        x: root.windowed ? 0 : (parent.width - width) / 2
        y: root.windowed ? 0 : (parent.height - height) / 2
        width: root.windowed ? parent.width
            : Math.min(parent.width - 32 - IrisFrame.musicReach("left") - IrisFrame.musicReach("right"), 1180 * root.d)
        height: root.windowed ? parent.height
            : Math.min(parent.height - 48 - IrisFrame.musicReach("top") - IrisFrame.musicReach("bottom"), 820 * root.d)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.BackButton | Qt.ForwardButton
            onPressed: mouse => {
                if (mouse.button === Qt.BackButton) root.goBack()
                else if (mouse.button === Qt.ForwardButton) root.goForward()
            }
        }

        // A rail mark's name, on a capsule beside the rail while it is pointed at.
        Rectangle {
            z: 2
            visible: root.railLayout && root.railHint !== null
            x: Math.round(sidebar.width + 6 * root.d)
            y: Math.round((root.railHint?.y ?? 0) - height / 2)
            width: Math.round(railCaption.implicitWidth + 20 * root.d)
            height: Math.round(26 * root.d)
            radius: height / 2
            color: IrisStyle.bodySurface
            IrisText {
                id: railCaption
                anchors.centerIn: parent
                text: root.railHint?.title ?? ""
                font.pixelSize: IrisStyle.typeMeta
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                id: sidebar
                readonly property int pad: IrisStyle.concentricPad(frame.radius, 12 * root.d)
                visible: !root.homeLayout
                Layout.fillHeight: true
                Layout.preferredWidth: root.railLayout ? Math.round(76 * root.d) : Math.min(272 * root.d, frame.width * 0.3)
                topLeftRadius: frame.radius
                bottomLeftRadius: frame.radius
                color: IrisStyle.readingSidebar
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: IrisStyle.hairline
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: sidebar.pad
                    anchors.topMargin: sidebar.pad + 4 * root.d
                    anchors.rightMargin: sidebar.pad - 4 * root.d
                    spacing: 0

                    Item {
                        id: sideSearchSlot
                        visible: root.layoutStyle === "sidebar"
                        Layout.fillWidth: true
                        Layout.rightMargin: 4 * root.d
                        Layout.bottomMargin: 10 * root.d
                        implicitHeight: Math.round(32 * root.d)
                    }
                    // One search field: in the sidebar when there is one, in the header otherwise.
                    Rectangle {
                        parent: root.layoutStyle === "sidebar" ? sideSearchSlot : headSearchSlot
                        anchors.fill: parent
                        radius: Math.min(height / 2, Math.max(IrisStyle.radiusRow, frame.radius - sidebar.pad))
                        color: searchField.activeFocus ? IrisStyle.fill : IrisStyle.fillQuiet
                        border.width: searchField.activeFocus ? 1 : 0
                        border.color: IrisStyle.tintBorder(IrisStyle.accent)
                        MaterialSymbol {
                            id: searchGlyph
                            anchors.left: parent.left
                            anchors.leftMargin: 10 * root.d
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search"
                            iconSize: Math.round(16 * root.d)
                            color: IrisStyle.muted
                        }
                        TextInput {
                            id: searchField
                            anchors.left: searchGlyph.right
                            anchors.leftMargin: 6 * root.d
                            anchors.right: clearSearch.left
                            anchors.rightMargin: 4 * root.d
                            anchors.verticalCenter: parent.verticalCenter
                            color: IrisStyle.text
                            selectionColor: IrisStyle.accentContainer
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
                                color: IrisStyle.muted
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
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: IrisScrollBar {}
                        // The list itself fades under the footer: a gradient painted over it read as a square
                        // shadow on glass.
                        readonly property bool fades: sidebarFlick.contentY + sidebarFlick.height < sidebarFlick.contentHeight - 1
                        layer.enabled: sidebarFlick.fades
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: sidebarFade
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
                            y: travelWash.row ? sidebarColumn.y + travelWash.row.y + travelWash.row.height - travelWash.row.rowHeight : 0
                            height: travelWash.row ? travelWash.row.rowHeight : 0
                            radius: travelWash.row ? travelWash.row.washRadius : 0
                            color: IrisStyle.tintFillHover(travelWash.row?.compact ? travelWash.row.modelData.tint : IrisStyle.accent)
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

                        Column {
                            id: sidebarColumn
                            width: sidebarFlick.width - 4 * root.d
                            spacing: 0

                            MouseArea {
                                id: profile
                                visible: !root.railLayout
                                width: parent.width
                                height: visible ? Math.round(50 * root.d) : 0
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                Accessible.role: Accessible.Button
                                Accessible.name: Translation.tr("General")
                                onClicked: root.selectSection("general")
                                Rectangle {
                                    anchors.fill: parent
                                    radius: IrisStyle.radiusRow
                                    color: profile.containsMouse ? IrisStyle.fillHover : "transparent"
                                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                                }
                                FaceAvatar {
                                    id: profileAvatar
                                    anchors.left: parent.left
                                    anchors.leftMargin: 6 * root.d
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.round(40 * root.d)
                                    height: width
                                }
                                Column {
                                    anchors.left: profileAvatar.right
                                    anchors.leftMargin: 10 * root.d
                                    anchors.right: parent.right
                                    anchors.rightMargin: 6 * root.d
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
                                        spacing: 5 * root.d
                                        IrisMark { implicitSize: Math.round(13 * root.d); anchors.verticalCenter: parent.verticalCenter }
                                        IrisText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Translation.tr("iRiS · Island family")
                                            color: IrisStyle.muted
                                            font.pixelSize: IrisStyle.typeMeta
                                        }
                                    }
                                }
                            }

                            Repeater {
                                model: root.sections.filter(section => section.cluster < root.footerCluster)
                                SectionRow { list: root.sections.filter(section => section.cluster < root.footerCluster) }
                            }
                        }

                        Item {
                            id: sidebarFade
                            parent: sidebarFlick
                            anchors.fill: parent
                            visible: false
                            layer.enabled: true
                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    GradientStop { position: 0; color: "white" }
                                    GradientStop { position: Math.max(0, 1 - 28 * root.d / Math.max(1, sidebarFade.height)); color: "white" }
                                    GradientStop { position: 1; color: "transparent" }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.rightMargin: 4 * root.d
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
                            model: root.sections.filter(section => section.cluster >= root.footerCluster)
                            SectionRow { list: []; gapAbove: false }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 20 * root.d
                    Layout.rightMargin: IrisStyle.concentricPad(frame.radius, 14 * root.d)
                    Layout.topMargin: IrisStyle.concentricPad(frame.radius, 14 * root.d)
                    Layout.preferredHeight: Math.round(52 * root.d)
                    spacing: 4 * root.d
                    IrisIconButton {
                        visible: root.homeLayout
                        materialIcon: "grid_view"
                        enabled: !root.atHome
                        opacity: enabled ? 1 : 0.35
                        onClicked: root.selectSection("home")
                        Accessible.name: Translation.tr("Every area")
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
                        Layout.fillWidth: true
                        Layout.leftMargin: 6 * root.d
                        spacing: 0
                        IrisText {
                            Layout.fillWidth: true
                            text: root.searching ? Translation.tr("Results for “%1”").arg(root.query)
                                : root.advancedPage >= 0 ? root.pageTitle(root.advancedPage)
                                : root.openGroup.length > 0 ? root.openGroup
                                : root.atHome ? Translation.tr("Settings")
                                : Translation.tr(root.currentSection.title)
                            font.family: IrisStyle.fontTitle
                            font.pixelSize: IrisStyle.typeTitleLarge
                            font.weight: IrisStyle.weight(Font.Bold)
                            elide: Text.ElideRight
                        }
                        IrisText {
                            Layout.fillWidth: true
                            visible: !root.searching && root.openGroup.length > 0 && root.advancedPage < 0
                                && root.openGroup !== Translation.tr(root.currentSection.title)
                            text: Translation.tr(root.currentSection.title)
                            color: IrisStyle.muted
                            font.pixelSize: IrisStyle.typeMeta
                            elide: Text.ElideRight
                        }
                    }
                    Item {
                        id: headSearchSlot
                        visible: root.layoutStyle !== "sidebar"
                        Layout.preferredWidth: Math.round(240 * root.d)
                        implicitHeight: Math.round(32 * root.d)
                    }
                    IrisButton {
                        readonly property bool rehearses: root.section === "lock"
                        readonly property bool arranges: root.section === "controlCenter"
                        visible: !root.searching && root.advancedPage < 0 && (rehearses || arranges)
                        quiet: !rehearses
                        emphasized: rehearses
                        text: rehearses ? Translation.tr("Rehearse it") : Translation.tr("Arrange it")
                        buttonRadius: height / 2
                        onClicked: {
                            GlobalStates.settingsOverlayOpen = false
                            if (rehearses) { GlobalStates.irisLockEdit = true; return }
                            GlobalStates.irisMorphOwner = ""
                            GlobalStates.controlPanelOpen = true
                            GlobalStates.irisControlEdit = true
                        }
                    }
                    IrisButton {
                        readonly property string studioTarget: root.studioTargets[root.section] ?? ""
                        readonly property string target: studioTarget.length > 0 ? studioTarget : (root.editTargets[root.section] ?? "")
                        visible: !root.searching && root.advancedPage < 0 && target.length > 0
                        emphasized: true
                        text: Translation.tr("Customize")
                        buttonRadius: height / 2
                        onClicked: {
                            GlobalStates.settingsOverlayOpen = false
                            GlobalStates.openIrisCustomize(target)
                        }
                    }
                    IrisButton {
                        readonly property var resettable: (root.openGroup.length > 0 ? (root.shownGroups[0]?.rows ?? []) : root.specifications
                            .filter(spec => spec.section === root.section)).filter(spec => String(spec.path).startsWith("iris."))
                        readonly property bool modified: {
                            Config.revision
                            return resettable.some(spec => IrisOptions.modified(spec))
                        }
                        visible: !root.searching && root.advancedPage < 0 && modified
                        quiet: true
                        text: Translation.tr("Restore defaults")
                        buttonRadius: height / 2
                        onClicked: resettable.forEach(spec => IrisOptions.commit(spec, spec.fallback))
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

                    // A head that carries a scene stays in view while its rows scroll under it: every change is seen as it
                    // lands, however far down the row is. One head, moved between this slot and the top of the rows.
                    Item {
                        id: heroPinSlot
                        visible: settingsFlick.visible && root.heroPinned
                        x: Math.round((pageArea.width - width) / 2)
                        y: Math.round(6 * root.d)
                        width: settingsRows.width
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
                        readonly property string key: String(root.shownGroups[0]?.key ?? "")
                        // A group with no scene has no head: the toolbar already names it.
                        readonly property bool shown: pageHero.sectionPage || (pageHero.groupPage && pageHero.stageAvailable)
                        parent: root.heroPinned ? heroPinSlot : heroFlowSlot
                        width: settingsRows.width
                        visible: pageHero.shown
                        tint: pageHero.groupPage ? (IrisOptions.groupTints[pageHero.key] ?? root.currentSection.tint) : root.currentSection.tint
                        glyph: pageHero.groupPage ? (IrisOptions.groupGlyphs[pageHero.key] ?? root.currentSection.icon) : root.currentSection.icon
                        title: !pageHero.groupPage ? Translation.tr(root.currentSection.subtitle)
                            : pageHero.caption.length > 0 ? pageHero.caption : root.openGroup
                        text: Translation.tr(root.currentSection.tip ?? "")
                        sceneSection: pageHero.sectionPage || pageHero.groupPage ? root.section : ""
                        sceneGroup: pageHero.groupPage ? pageHero.key : ""
                    }

                    Flickable {
                        id: settingsFlick
                        anchors.fill: parent
                        anchors.topMargin: root.heroPinned ? heroPinSlot.y + heroPinSlot.height + Math.round(12 * root.d) : 0
                        // Rows pass under the pinned head, never over it.
                        clip: root.heroPinned
                        // and fade into the air under it instead of ending on a cut, as the sidebar's list does at its foot.
                        layer.enabled: root.heroPinned && settingsFlick.contentY > 1
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: rowsFade
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                        }
                        Item {
                            id: rowsFade
                            parent: settingsFlick
                            anchors.fill: parent
                            visible: false
                            layer.enabled: true
                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    GradientStop { position: 0; color: "transparent" }
                                    GradientStop { position: Math.min(1, 18 * root.d / Math.max(1, rowsFade.height)); color: "white" }
                                    GradientStop { position: 1; color: "white" }
                                }
                            }
                        }
                        visible: root.advancedPage < 0 && !root.atHome
                        contentHeight: settingsRows.implicitHeight + 32 * root.d
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: IrisScrollBar {}

                        ColumnLayout {
                            id: settingsRows
                            y: 6 * root.d
                            width: Math.min(settingsFlick.width - 56 * root.d, 820 * root.d)
                            x: Math.round((settingsFlick.width - width) / 2)
                            spacing: 18 * root.d

                            // The head reads here only when it carries no scene, or the window is too short to keep one in view.
                            Item {
                                id: heroFlowSlot
                                Layout.fillWidth: true
                                visible: pageHero.shown && !root.heroPinned
                                implicitHeight: visible ? pageHero.implicitHeight : 0
                            }

                            IrisGameModeCard {
                                visible: root.browsing && root.section === "gaming"
                            }

                            IrisWallpaperCard {
                                screen: root.screen
                                visible: root.browsing && root.section === "general"
                            }

                            IrisText {
                                visible: root.searching && root.entries.length === 0 && root.pageMatches.length === 0
                                Layout.topMargin: 24 * root.d
                                Layout.alignment: Qt.AlignHCenter
                                text: Translation.tr("No matching settings")
                                color: IrisStyle.muted
                            }

                            Repeater {
                                model: ScriptModel { values: root.browsing && root.section !== "system" ? root.groupChunks : [] }
                                GroupList {}
                            }

                            Repeater {
                                model: root.searching && root.pagesFirst ? [Translation.tr("Pages")] : []
                                MoreGroup {}
                            }

                            Repeater {
                                model: ScriptModel { objectProp: "title"; values: root.shownGroups }
                                GroupBlock {}
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
                                visible: root.section === "sidebars" && root.browsing
                                links: [
                                    { label: Translation.tr("Open Focus"), icon: "dock_to_left", action: () => { GlobalStates.settingsOverlayOpen = false; GlobalStates.openSidebarLeft("") } },
                                    { label: Translation.tr("Open Today"), icon: "dock_to_right", action: () => { GlobalStates.settingsOverlayOpen = false; GlobalStates.openSidebarRight("") } }
                                ]
                            }

                            Repeater {
                                model: root.section === "sidebars" && root.browsing ? ["left", "right"] : []
                                ColumnLayout {
                                    id: panelEditor
                                    required property string modelData
                                    Layout.fillWidth: true
                                    spacing: 8 * root.d
                                    IrisText { text: panelEditor.modelData === "left" ? Translation.tr("Focus sections") : Translation.tr("Today sections"); color: IrisStyle.label; font.weight: IrisStyle.weight(Font.DemiBold) }
                                    IrisSidebarEditor { Layout.fillWidth: true; side: panelEditor.modelData }
                                }
                            }

                            IrisLinkCard {
                                visible: root.section === "general" && root.browsing
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
                                visible: root.section === "desktop" && root.browsing
                                links: [{ label: Translation.tr("Edit desktop widgets"), icon: "edit", action: () => { GlobalStates.settingsOverlayOpen = false; GlobalStates.setWidgetEditMode(true) } }]
                            }

                            Repeater {
                                model: root.browsing && root.section === "system" ? root.moreGroups : root.searching && root.pageMatches.length > 0 && !root.pagesFirst ? [Translation.tr("Pages")] : []
                                MoreGroup {}
                            }
                        }
                    }

                    // Home: every area at once, in the sidebar's clusters, each one card of marks to open.
                    Flickable {
                        id: homeFlick
                        anchors.fill: parent
                        visible: root.atHome
                        contentHeight: homeColumn.implicitHeight + 32 * root.d
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: IrisScrollBar {}
                        ColumnLayout {
                            id: homeColumn
                            y: 6 * root.d
                            width: Math.min(homeFlick.width - 56 * root.d, 820 * root.d)
                            x: Math.round((homeFlick.width - width) / 2)
                            spacing: 14 * root.d
                            Repeater {
                                model: Array.from(new Set(root.sections.map(section => section.cluster)))
                                Rectangle {
                                    id: cluster
                                    required property int modelData
                                    readonly property var members: root.sections.filter(section => section.cluster === cluster.modelData)
                                    Layout.fillWidth: true
                                    implicitHeight: tiles.implicitHeight + 16 * root.d
                                    radius: IrisStyle.radiusTile
                                    color: IrisStyle.readingCard
                                    Flow {
                                        id: tiles
                                        readonly property real tileWidth: Math.floor((tiles.width - 2 * tiles.spacing) / 3)
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 8 * root.d
                                        spacing: 2 * root.d
                                        Repeater {
                                            model: cluster.members
                                            MouseArea {
                                                id: tile
                                                required property var modelData
                                                // A third each, whatever the cluster's count: every mark on the page sits in one grid.
                                                width: tiles.tileWidth
                                                height: Math.round(58 * root.d)
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                Accessible.role: Accessible.Button
                                                Accessible.name: Translation.tr(tile.modelData.title)
                                                onClicked: root.selectSection(tile.modelData.id)
                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: IrisStyle.radiusRow
                                                    color: tile.pressed ? IrisStyle.fillActive : tile.containsMouse ? IrisStyle.fillHover : "transparent"
                                                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                                                }
                                                IrisSquircle {
                                                    id: tileMark
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 10 * root.d
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: Math.round(34 * root.d)
                                                    height: width
                                                    tint: tile.modelData.tint
                                                    glyph: tile.modelData.icon
                                                }
                                                Column {
                                                    anchors.left: tileMark.right
                                                    anchors.leftMargin: 10 * root.d
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 8 * root.d
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 2 * root.d
                                                    IrisText {
                                                        width: parent.width
                                                        text: Translation.tr(tile.modelData.title)
                                                        font.pixelSize: IrisStyle.typeLabel
                                                        font.weight: IrisStyle.weight(Font.DemiBold)
                                                        elide: Text.ElideRight
                                                    }
                                                    IrisText {
                                                        width: parent.width
                                                        text: Translation.tr(tile.modelData.subtitle ?? "")
                                                        color: IrisStyle.muted
                                                        font.pixelSize: IrisStyle.typeFootnote
                                                        wrapMode: Text.WordWrap
                                                        maximumLineCount: 2
                                                        elide: Text.ElideRight
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    SettingsPageHost {
                        id: pageHost
                        anchors.fill: parent
                        anchors.leftMargin: 12 * root.d
                        anchors.rightMargin: 12 * root.d
                        onCurrentItemChanged: {
                            if (currentItem && root.requestedSection.length > 0
                                && SettingsSearchRegistry.activatePageSection(currentItem, root.requestedSection))
                                root.requestedSection = ""
                        }
                        onCurrentIndexChanged: {
                            if (currentIndex >= 0) GlobalStates.settingsOverlayCurrentPage = currentIndex
                        }
                        visible: root.advancedPage >= 0
                        pages: root.pages
                        requestedIndex: root.advancedPage
                        loadEnabled: visible
                        directNavigation: true
                    }
                }
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
        readonly property bool selected: !root.searching && root.section === sectionRow.modelData.id
        // Main-list rows hand their selection to the travelling wash (travelWash); footer rows paint their own.
        readonly property bool travels: sectionRow.gapAbove
        readonly property real washRadius: Math.min(sectionRow.rowHeight / 2, IrisStyle.iconRadius(sectionMark.width) + sectionMark.x)
        onSelectedChanged: if (sectionRow.selected && sectionRow.travels) root.travelRow = sectionRow
        Component.onCompleted: if (sectionRow.selected && sectionRow.travels) root.travelRow = sectionRow
        Component.onDestruction: if (root.travelRow === sectionRow) root.travelRow = null
        readonly property bool dimmed: root.searching && !root.matchedSections.has(sectionRow.modelData.id)
        readonly property bool compact: root.railLayout
        readonly property real rowHeight: Math.round((sectionRow.compact ? 36 : 27) * root.d * Math.max(1, IrisStyle.typeScale))
        width: parent ? parent.width : 0
        height: sectionRow.rowHeight + (sectionRow.clusterStart ? Math.round(8 * root.d) : 0)
        onContainsMouseChanged: {
            if (sectionRow.compact && sectionRow.containsMouse) {
                const at = sectionRow.mapToItem(frame, 0, sectionRow.height - sectionRow.rowHeight / 2)
                root.railHint = { title: Translation.tr(sectionRow.modelData.title), y: at.y }
            } else if (root.railHint?.title === Translation.tr(sectionRow.modelData.title)) root.railHint = null
        }
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: Translation.tr(sectionRow.modelData.title)
        onClicked: root.selectSection(sectionRow.modelData.id)
        opacity: sectionRow.dimmed ? 0.4 : 1
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: sectionRow.rowHeight
            // Concentric with the mark it holds; where you are is a wash of the accent, as light as a hover, never a
            // solid block heavier than the buttons around it.
            radius: sectionRow.washRadius
            color: sectionRow.selected && !sectionRow.travels ? IrisStyle.tintFillHover(sectionRow.compact ? sectionRow.modelData.tint : IrisStyle.accent)
                : sectionRow.selected ? "transparent"
                : sectionRow.containsMouse ? IrisStyle.fillHover : "transparent"
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
            IrisSquircle {
                id: sectionMark
                x: sectionRow.compact ? Math.round((parent.width - width) / 2) : Math.round(6 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round((sectionRow.compact ? 24 : 20) * root.d)
                height: width
                tint: sectionRow.modelData.tint
                glyph: sectionRow.modelData.icon
            }
            IrisText {
                visible: !sectionRow.compact
                anchors.left: sectionMark.right
                anchors.leftMargin: 10 * root.d
                anchors.right: parent.right
                anchors.rightMargin: 8 * root.d
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr(sectionRow.modelData.title)
                color: IrisStyle.text
                font.pixelSize: IrisStyle.typeLabel
                font.weight: IrisStyle.weight(sectionRow.selected ? Font.DemiBold : Font.Medium)
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
        readonly property bool staged: hero.stageAvailable && hero.width > 560 * root.d
        Layout.fillWidth: true
        implicitHeight: hero.staged ? Math.round(150 * root.d) + 2 * hero.pad : heroText.implicitHeight + 28 * root.d
        radius: IrisStyle.radiusTile
        color: IrisStyle.readingCard

        RowLayout {
            id: heroText
            anchors.left: parent.left
            anchors.right: stageLoader.visible ? stageLoader.left : parent.right
            anchors.verticalCenter: parent.verticalCenter
            // The same inset as the group rows below, so every mark on the page sits on one column.
            anchors.leftMargin: 14 * root.d
            anchors.rightMargin: 16 * root.d
            spacing: 14 * root.d
            IrisSquircle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: Math.round(44 * root.d)
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
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                IrisText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: hero.text
                    color: IrisStyle.subtext
                    font.pixelSize: IrisStyle.typeLabel
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
            }
        }
        Loader {
            id: stageLoader
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: hero.pad
            width: Math.round(300 * root.d)
            height: Math.round(150 * root.d)
            active: hero.sceneSection.length > 0
            visible: hero.staged
            sourceComponent: IrisGroupPreview {
                compact: true
                radius: Math.max(IrisStyle.radiusMicro, hero.radius - hero.pad)
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
            color: IrisStyle.label
            font.family: IrisStyle.fontTitle
            font.pixelSize: IrisStyle.typeMeta
            font.weight: IrisStyle.weight(Font.DemiBold)
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: listColumn.implicitHeight
            radius: IrisStyle.radiusTile
            color: IrisStyle.readingCard
            // A block whose groups feed one another (colour: source, mode, accent, material, apps) threads its marks
            // together, under them, from the first to the last.
            Rectangle {
                visible: list.modelData.flow ?? false
                x: Math.round(27 * root.d - width / 2)
                y: Math.round(23 * root.d)
                width: Math.max(1, Math.round(2 * root.d))
                height: Math.max(0, parent.height - 46 * root.d)
                radius: width / 2
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
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3 * root.d
                radius: IrisStyle.radiusRow
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
                tint: IrisOptions.groupTints[groupRow.modelData.key] ?? root.currentSection.tint
                glyph: IrisOptions.groupGlyphs[groupRow.modelData.key] ?? root.currentSection.icon
            }
            IrisText {
                id: groupTitle
                anchors.left: groupMark.right
                anchors.leftMargin: 12 * root.d
                anchors.verticalCenter: parent.verticalCenter
                width: Math.ceil(Math.min(implicitWidth, parent.width * 0.42))
                text: groupRow.lone ? Translation.tr(groupRow.rows[0].label) : groupRow.modelData.title
                font.pixelSize: IrisStyle.typeLabel
                font.weight: IrisStyle.weight(groupRow.unfolded ? Font.DemiBold : Font.Medium)
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
                radius: width / 2
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
            onClicked: root.selectSection(resultSection.section.id)
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
                    color: resultSection.containsMouse ? IrisStyle.text : (resultSection.section.tint ?? IrisStyle.label)
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
        // A long group reads as captioned cards, one per `part` its rows name; search shows one card. Keyed by caption,
        // so a write (a slider mid-drag) never rebuilds a card under the pointer.
        function partOf(spec: var): string { return root.searching ? "" : String(spec.part ?? "") }
        readonly property var parts: [...new Set(group.modelData.rows.map(spec => group.partOf(spec)))]
        Repeater {
            model: ScriptModel { values: group.parts }
            ColumnLayout {
                id: part
                required property string modelData
                required property int index
                readonly property var rows: group.modelData.rows.filter(spec => group.partOf(spec) === part.modelData)
                Layout.fillWidth: true
                Layout.topMargin: part.index > 0 ? 12 * root.d : 0
                spacing: 6 * root.d
                IrisText {
                    visible: text.length > 0
                    Layout.leftMargin: 16 * root.d
                    text: part.modelData.length > 0 ? Translation.tr(part.modelData) : ""
                    color: IrisStyle.label
                    font.family: IrisStyle.fontTitle
                    font.pixelSize: IrisStyle.typeMeta
                    font.weight: IrisStyle.weight(Font.DemiBold)
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: groupRows.implicitHeight
                    radius: IrisStyle.radiusTile
                    color: IrisStyle.readingCard
                    ColumnLayout {
                        id: groupRows
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 0
                        Repeater {
                            model: ScriptModel { objectProp: "modelKey"; values: part.rows }
                            IrisSetting {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                spec: modelData
                                highlight: root.query
                                last: index === part.rows.length - 1
                            }
                        }
                    }
                }
            }
        }
    }

}
