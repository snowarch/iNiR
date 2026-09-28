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

PanelWindow {
    id: root
    property string section: "general"
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
    readonly property int footerCluster: 5
    readonly property var specifications: IrisOptions.settings
    readonly property var currentSection: IrisOptions.sectionById(root.section)
    readonly property bool searching: root.query.length > 0
    // A section with a single group has nothing to choose between: it opens on that group.
    readonly property string openGroup: root.searching ? ""
        : root.group.length > 0 ? root.group
        : root.groups.length === 1 ? root.groups[0].title : ""
    readonly property bool browsing: !root.searching && root.openGroup.length === 0 && root.advancedPage < 0
    function shown(spec: var): bool { return IrisOptions.shown(spec) }

    readonly property int searchLimit: 24
    readonly property var searchIndex: root.specifications.map(spec => {
        const label = Translation.tr(spec.label).toLowerCase()
        const sectionTitle = Translation.tr(IrisOptions.sectionById(spec.section).title)
        return { spec: spec, label: label, section: sectionTitle.toLowerCase(), rest: [Translation.tr(spec.group ?? ""), sectionTitle, Translation.tr(spec.description ?? ""), ...(spec.keywords ?? [])].join(" ").toLowerCase() }
    })
    function searchScore(entry: var, terms: var): int {
        if (!terms.every(term => entry.label.includes(term) || entry.rest.includes(term))) return 99
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
    readonly property var groupChunks: {
        const size = root.groups.length > 7 ? Math.ceil(root.groups.length / Math.ceil(root.groups.length / 6)) : root.groups.length
        const out = []
        for (let i = 0; i < root.groups.length; i += Math.max(1, size)) out.push(root.groups.slice(i, i + size))
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
        case "choice":
            if (spec.fallback === "" && value === "") return ""
            return Translation.tr(String(IrisOptions.choicesOf(spec).find(choice => IrisOptions.same(choice.value, value))?.label ?? ""))
        case "range":
            if (spec.fallback !== undefined && IrisOptions.same(value, spec.fallback)) return ""
            return Translation.tr(spec.label) + " " + Translation.tr(IrisOptions.rangeText(spec, value))
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
    readonly property var editTargets: ({ bar: "island", player: "bodies", bubbles: "pieces", dock: "dock", appearance: "material",
        motion: "motion", desktop: "desktop", sidebars: "places", spotlight: "places", controlCenter: "bodies" })
    readonly property var studioTargets: ({ bar: "island", bubbles: "pieces", dock: "dock", appearance: "material", motion: "motion",
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
        }
        GlobalStates.settingsOverlayRequestedSection = ""
        const page = GlobalStates.settingsOverlayRequestedPage
        if (page >= 0) {
            const irisPage = page === root.irisPageIndex
            root.advancedPage = irisPage ? -1 : page
            root.section = irisPage || root.irisPageFor(String(root.pages[page]?.key ?? "")).length > 0 ? "general" : "system"
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
    onSectionChanged: pageEnter.restart()
    onOpenGroupChanged: { settingsFlick.contentY = 0; pageEnter.restart() }
    onAdvancedPageChanged: pageEnter.restart()

    visible: GlobalStates.settingsOverlayOpen || frame.progress > 0
    IrisOutputHold {
        id: outputHold
        wanted: GlobalStates.focusedScreen
        live: root.visible
    }
    screen: outputHold.output
    color: "transparent"
    anchors { left: true; right: true; top: true; bottom: true }
    margins {
        left: IrisFrame.band
        right: IrisFrame.band
        top: IrisFrame.band
        bottom: IrisFrame.band
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:iris-settings"
    Field.IrisBlurRegion {
        id: placeBlur
        window: root
        shapes: frame.blurShapes
        windowWidth: root.width
        windowHeight: root.height
    }
    WlrLayershell.layer: GlobalStates.settingsNativeDialogOpen ? WlrLayer.Bottom : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: GlobalStates.settingsNativeDialogOpen ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
    mask: GlobalStates.settingsOverlayOpen && frame.armed ? null : frameRegion
    Region { id: frameRegion; item: frame }
    Shortcut {
        sequence: "Escape"
        enabled: GlobalStates.settingsOverlayOpen
        onActivated: {
            if (root.searching) searchField.text = ""
            else if (root.group.length > 0) root.leaveGroup()
            else if (root.advancedPage >= 0) root.go({ section: root.section, group: "", advancedPage: -1 })
            else GlobalStates.settingsOverlayOpen = false
        }
    }
    Shortcut { sequence: "Ctrl+F"; enabled: GlobalStates.settingsOverlayOpen; onActivated: searchField.forceActiveFocus() }
    function stepSection(delta: int): void {
        const index = root.sections.findIndex(section => section.id === root.section)
        const next = root.sections[Math.max(0, Math.min(root.sections.length - 1, index + delta))]
        if (next) root.selectSection(next.id)
    }
    Shortcut { sequence: "Ctrl+Down"; enabled: GlobalStates.settingsOverlayOpen; onActivated: root.stepSection(1) }
    Shortcut { sequence: "Ctrl+Up"; enabled: GlobalStates.settingsOverlayOpen; onActivated: root.stepSection(-1) }
    Shortcut { sequences: ["Alt+Left", "Ctrl+["]; enabled: GlobalStates.settingsOverlayOpen; onActivated: root.goBack() }
    Shortcut { sequences: ["Alt+Right", "Ctrl+]"]; enabled: GlobalStates.settingsOverlayOpen; onActivated: root.goForward() }
    MouseArea { anchors.fill: parent; onClicked: GlobalStates.settingsOverlayOpen = false }

    IrisMorphSurface {
        motionSurface: "settings"
        settles: true
        windowOffset: Qt.point(IrisFrame.band, IrisFrame.band)
        ownField: true
        id: frame
        compositorBlurred: true
        open: GlobalStates.settingsOverlayOpen
        light: IrisStyle.surfaceLight("settings", IrisStyle.wallpaperLight)
        radius: IrisStyle.surfaceRadius("settings", IrisStyle.radiusPanel)
        onClosed: GlobalStates.irisMorphOwner = ""
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: Math.min(parent.width - 32 - IrisFrame.musicReach("left") - IrisFrame.musicReach("right"), 1180 * root.d)
        height: Math.min(parent.height - 48 - IrisFrame.musicReach("top") - IrisFrame.musicReach("bottom"), 820 * root.d)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.BackButton | Qt.ForwardButton
            onPressed: mouse => {
                if (mouse.button === Qt.BackButton) root.goBack()
                else if (mouse.button === Qt.ForwardButton) root.goForward()
            }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                id: sidebar
                readonly property int pad: IrisStyle.concentricPad(frame.radius, 12 * root.d)
                Layout.fillHeight: true
                Layout.preferredWidth: Math.min(272 * root.d, frame.width * 0.3)
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

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.rightMargin: 4 * root.d
                        Layout.bottomMargin: 10 * root.d
                        implicitHeight: Math.round(32 * root.d)
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
                            GlobalStates.irisStudioTarget = target
                            GlobalStates.irisEditTarget = target
                            GlobalStates.irisEdit = true
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

                    Flickable {
                        id: settingsFlick
                        anchors.fill: parent
                        visible: root.advancedPage < 0
                        contentHeight: settingsRows.implicitHeight + 32 * root.d
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: IrisScrollBar {}

                        ColumnLayout {
                            id: settingsRows
                            y: 6 * root.d
                            width: Math.min(settingsFlick.width - 56 * root.d, 820 * root.d)
                            x: Math.round((settingsFlick.width - width) / 2)
                            spacing: 18 * root.d

                            StageHero {
                                visible: root.browsing && root.section !== "system" && root.section !== "general" && root.section !== "gaming"
                                tint: root.currentSection.tint
                                glyph: root.currentSection.icon
                                title: Translation.tr(root.currentSection.subtitle)
                                text: Translation.tr(root.currentSection.tip ?? "")
                                sceneSection: root.browsing ? root.section : ""
                                sceneGroup: ""
                            }

                            IrisGameModeCard {
                                visible: root.browsing && root.section === "gaming"
                            }

                            IrisWallpaperCard {
                                screen: root.screen
                                visible: root.browsing && root.section === "general"
                            }

                            StageHero {
                                id: groupHero
                                readonly property string key: String(root.shownGroups[0]?.key ?? "")
                                visible: !root.searching && root.openGroup.length > 0 && root.advancedPage < 0 && stageAvailable
                                tint: IrisOptions.groupTints[groupHero.key] ?? root.currentSection.tint
                                glyph: IrisOptions.groupGlyphs[groupHero.key] ?? root.currentSection.icon
                                title: groupHero.caption.length > 0 ? groupHero.caption : root.openGroup
                                text: Translation.tr(root.currentSection.tip ?? "")
                                sceneSection: !root.searching && root.openGroup.length > 0 && root.advancedPage < 0 ? root.section : ""
                                sceneGroup: groupHero.key
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
        readonly property bool dimmed: root.searching && !root.matchedSections.has(sectionRow.modelData.id)
        width: parent ? parent.width : 0
        height: Math.round(27 * root.d) + (sectionRow.clusterStart ? Math.round(8 * root.d) : 0)
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
            height: Math.round(27 * root.d)
            radius: IrisStyle.radiusRow
            color: sectionRow.selected ? IrisStyle.accent
                : sectionRow.containsMouse ? IrisStyle.fillHover : "transparent"
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
            IrisSquircle {
                id: sectionMark
                anchors.left: parent.left
                anchors.leftMargin: 6 * root.d
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(20 * root.d)
                height: width
                tint: sectionRow.modelData.tint
                glyph: sectionRow.modelData.icon
            }
            IrisText {
                anchors.left: sectionMark.right
                anchors.leftMargin: 10 * root.d
                anchors.right: parent.right
                anchors.rightMargin: 8 * root.d
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr(sectionRow.modelData.title)
                color: sectionRow.selected ? IrisStyle.onAccent : IrisStyle.text
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

    component GroupList: Rectangle {
        id: list
        required property var modelData
        Layout.fillWidth: true
        implicitHeight: listColumn.implicitHeight
        radius: IrisStyle.radiusTile
        color: IrisStyle.readingCard
        Column {
            id: listColumn
            width: parent.width
            Repeater {
                model: ScriptModel { objectProp: "title"; values: list.modelData }
                GroupRow { last: index === list.modelData.length - 1 }
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
                    color: resultSection.containsMouse ? IrisStyle.text : IrisStyle.label
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
                    model: ScriptModel { objectProp: "modelKey"; values: group.modelData.rows }
                    IrisSetting {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spec: modelData
                        highlight: root.query
                        last: index === group.modelData.rows.length - 1
                    }
                }
            }
        }
    }

}
