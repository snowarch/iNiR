pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.style
import qs.modules.iris.preview

// Settings is a map of your own desktop: point at a piece and its inspector grows out of it, with every row of the
// areas that shape it. What has no piece on screen is a room under the map. Hosted by IrisSettingsOverlay (a layer
// over the desktop) or IrisSettingsWindow (a Niri window).
Item {
    id: root
    property bool windowed: false
    readonly property alias frame: frame
    readonly property var screen: root.QsWindow.window?.screen ?? null
    readonly property real d: IrisStyle.settingsDensity

    // ── Where you are ────────────────────────────────────────────────────
    property string selected: "general"
    property string area: ""
    property string landingGroup: ""
    property string landingPath: ""
    property string query: ""
    property bool tuneAll: false
    property var backStack: []
    property var forwardStack: []
    readonly property bool searching: root.query.trim().length > 0
    readonly property var entry: IrisOptions.entryById(root.selected) ?? IrisOptions.rooms[1]
    readonly property string page: String(root.entry?.page ?? "")
    readonly property var pageUrls: ({
        about: Qt.resolvedUrl("IrisAboutPage.qml"), shortcuts: Qt.resolvedUrl("IrisShortcutsPage.qml"),
        hub: Qt.resolvedUrl("IrisHubPage.qml"), errors: Qt.resolvedUrl("IrisErrorsPage.qml")
    })
    readonly property var searchEntry: ({ id: "search", label: Translation.tr("Results"), glyph: "search", tintName: "gray",
        areas: IrisOptions.sectionOrder })
    // Every area in reading order, for next/prev: the map's pieces first, then the rooms.
    readonly property var areaOrder: IrisOptions.pieces.concat(IrisOptions.rooms).reduce((all, one) => all.concat(one.areas ?? []), [])
        .filter((id, at, all) => all.indexOf(id) === at && (id !== "battery" || Battery.available))
    readonly property string currentArea: inspector.currentArea

    function here(): var { return { selected: root.selected, area: root.currentArea } }
    function go(place: var, from: var): void {
        const now = root.here()
        if (now.selected !== place.selected || now.area !== place.area) {
            root.backStack = root.backStack.concat([now]).slice(-40)
            root.forwardStack = []
        }
        root.arrive(place, from)
    }
    function arrive(place: var, from: var): void {
        const changed = place.selected !== root.selected
        root.selected = place.selected
        root.area = place.area ?? ""
        root.landingGroup = place.group ?? ""
        root.landingPath = place.path ?? ""
        if (place.path) landingClear.restart()
        if (searchField.text.length > 0 && !place.keepSearch) searchField.text = ""
        if (changed) root.grow(from)
    }
    function goBack(): void {
        if (root.backStack.length === 0) return
        root.forwardStack = root.forwardStack.concat([root.here()])
        const place = root.backStack[root.backStack.length - 1]
        root.backStack = root.backStack.slice(0, -1)
        root.arrive(place, null)
    }
    function goForward(): void {
        if (root.forwardStack.length === 0) return
        root.backStack = root.backStack.concat([root.here()])
        const place = root.forwardStack[root.forwardStack.length - 1]
        root.forwardStack = root.forwardStack.slice(0, -1)
        root.arrive(place, null)
    }
    // An area by name lands in the entry that holds it, on its tab.
    function openArea(section: string, group: string, path: string): void {
        const owner = IrisOptions.ownerOf(section, group)
        if (!owner) return
        root.go({ selected: owner.id, area: section, group: group, path: path }, mapView.rectOf(owner.id))
    }
    function stepArea(delta: int): void {
        const at = root.areaOrder.indexOf(root.currentArea)
        const next = root.areaOrder[Math.max(0, Math.min(root.areaOrder.length - 1, at + delta))]
        if (next && next !== root.currentArea) root.openArea(next, "", "")
    }
    Timer { id: landingClear; interval: 2400; onTriggered: root.landingPath = "" }

    // ── Growing out of the piece ─────────────────────────────────────────
    // The panel is a body that grows from where you touched (the piece on the map, a room) to its place.
    property rect growFrom: Qt.rect(0, 0, 0, 0)
    function grow(from: var): void {
        if (!from || from.width <= 0) { growth.jump(); return }
        const origin = (from.item ?? mapView).mapToItem(panelSlot, from.x, from.y)
        root.growFrom = Qt.rect(origin.x, origin.y, from.width, from.height)
        growth.to = 0
        growth.jump()
        growth.to = 1
    }
    IrisSpring { id: growth; surface: "cards"; intent: "auto"; to: 1; value: 1; minimum: 0 }
    readonly property real grown: Math.max(0, Math.min(1, growth.value))

    // ── Requests (IPC, links, other surfaces) ────────────────────────────
    function runCommand(verb: string): bool {
        if (verb === "back") root.goBack()
        else if (verb === "forward") root.goForward()
        else if (verb === "next") root.stepArea(1)
        else if (verb === "prev") root.stepArea(-1)
        else if (verb.startsWith("search:")) { searchField.text = verb.slice(7); root.query = searchField.text }
        else if (verb === "open") root.openFirstResult()
        else if (verb === "tune:open" || verb === "tune:close") root.tuneAll = verb === "tune:open"
        // `list:<row label>` opens that row's choices in place in the open area; `list:` closes it.
        else if (verb.startsWith("list:")) {
            const name = verb.slice(5).toLowerCase()
            const spec = IrisOptions.settings.find(one => one.section === root.currentArea && String(one.label ?? "").toLowerCase() === name)
            IrisOptions.openList = spec ? String(spec.path ?? "") + "|" + String(spec.section ?? "") + "|" + String(spec.label ?? "") : ""
        }
        else return false
        return true
    }
    function openFirstResult(): void {
        const first = inspector.hits[0]
        if (first) root.openArea(String(first.section), String(first.group ?? ""), String(first.path ?? ""))
    }
    // Material's pages iRiS draws in its own areas: a request for one (the desktop's "Widget settings") lands there.
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
    // Links written before a topic moved still land where it lives now.
    readonly property var renamedGroups: ({ "appearance/wallpaper": "Wallpaper tint", "player/on the edges": "Frame music", "player/finish": "Frame finish" })
    readonly property var renamedSections: ({ frameMusic: "player" })
    function applyRequest(): void {
        // Switching hosts, the one leaving still hears the request: only the wanted host takes it.
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
        root.backStack = []
        root.forwardStack = []
        if (IrisOptions.entryById(key)?.page) { root.arrive({ selected: key }, null); return }
        const parts = asked.split("/")
        let section = root.renamedSections[parts[0]] ?? parts[0]
        let group = parts.slice(1).join("/")
        // An entry's own id (`inir iris settings island`) or a category's (`look`) opens it.
        const named = IrisOptions.entryById(section)
        if (named && !IrisOptions.sections.some(one => one.id === section)) { root.arrive({ selected: named.id }, null); return }
        const category = IrisOptions.categories.find(one => one.id === section)
        if (category && !IrisOptions.sections.some(one => one.id === section)) section = category.sections[0]
        if (group.length > 0) {
            const wanted = group.toLowerCase()
            const holds = (id, name) => IrisOptions.settings.some(spec => spec.section === id && String(spec.group ?? "").toLowerCase() === name)
            if (!holds(section, wanted)) {
                const renamed = String(root.renamedGroups[section + "/" + wanted] ?? "")
                if (renamed.length > 0) group = renamed
                const home = IrisOptions.settings.find(spec => String(spec.group ?? "").toLowerCase() === group.toLowerCase())
                if (home) section = home.section
            }
            const exact = IrisOptions.settings.find(spec => spec.section === section && String(spec.group ?? "").toLowerCase() === group.toLowerCase())
            if (exact) group = String(exact.group)
        }
        if (!IrisOptions.sections.some(one => one.id === section)) section = "general"
        const owner = IrisOptions.ownerOf(section, group)
        root.arrive({ selected: owner?.id ?? "general", area: section, group: group }, null)
    }
    Component.onCompleted: {
        IrisNiri.ensure()
        if (GlobalStates.settingsOverlayOpen) root.applyRequest()
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
    function switchHost(): void {
        GlobalStates.settingsOverlayRequestedSection = root.page.length > 0 ? "" : root.currentArea
        GlobalStates.settingsOverlayRequestedKey = root.page.length > 0 ? root.page : "iris"
        Config.setNestedValue("iris.appearance.settingsHost", root.windowed ? "overlay" : "window")
    }

    // ── Keys ─────────────────────────────────────────────────────────────
    Shortcut {
        sequence: "Escape"
        enabled: GlobalStates.settingsOverlayOpen
        onActivated: {
            if (IrisOptions.openList.length > 0) IrisOptions.openList = ""
            else if (searchField.text.length > 0) searchField.text = ""
            else if (!root.windowed) GlobalStates.settingsOverlayOpen = false
        }
    }
    Shortcut { sequence: "Ctrl+F"; enabled: GlobalStates.settingsOverlayOpen; onActivated: searchField.forceActiveFocus() }
    Shortcut { sequence: "Ctrl+Down"; enabled: GlobalStates.settingsOverlayOpen; onActivated: root.stepArea(1) }
    Shortcut { sequence: "Ctrl+Up"; enabled: GlobalStates.settingsOverlayOpen; onActivated: root.stepArea(-1) }
    Shortcut { sequences: ["Alt+Left", "Ctrl+["]; enabled: GlobalStates.settingsOverlayOpen; onActivated: root.goBack() }
    Shortcut { sequences: ["Alt+Right", "Ctrl+]"]; enabled: GlobalStates.settingsOverlayOpen; onActivated: root.goForward() }
    // Typing anywhere searches: a letter no control takes reaches the page and goes to the field.
    Keys.onUpPressed: event => { if (event.modifiers === Qt.NoModifier) root.stepArea(-1); else event.accepted = false }
    Keys.onDownPressed: event => { if (event.modifiers === Qt.NoModifier) root.stepArea(1); else event.accepted = false }
    Keys.onPressed: event => typeAhead.take(event)
    IrisTypeAhead { id: typeAhead; field: searchField }
    MouseArea { anchors.fill: parent; enabled: !root.windowed; onClicked: GlobalStates.settingsOverlayOpen = false }

    // A textured material (Afterglow's bevel, Light leak's lit rim) must follow the corners Niri clips the window to.
    readonly property bool windowField: root.windowed && IrisStyle.textured
    onWindowFieldChanged: if (root.windowField) IrisNiri.reload(["window-rules"])
    IrisMorphSurface {
        id: frame
        motionSurface: "settings"
        settles: true
        windowOffset: Qt.point(IrisFrame.band, IrisFrame.band)
        ownField: !root.windowed || root.windowField
        // A window cannot know where it sits on screen, so it never samples the wallpaper: Blur asks Niri, else solid.
        glass: !root.windowed || IrisStyle.glassCompositor
        compositorBlurred: true
        energy: root.windowed && GlobalStates.settingsWindowBehind ? 0 : 1
        contentReady: true
        open: root.windowed || GlobalStates.settingsOverlayOpen
        color: IrisStyle.surface
        light: IrisStyle.surfaceLight("settings", IrisStyle.wallpaperLight)
        radius: root.windowField ? Number(IrisNiri.data["window-rules"]?.corner_radius ?? 16)
            : root.windowed ? 0 : IrisStyle.surfaceRadius("settings", IrisStyle.radiusPanel)
        onClosed: GlobalStates.irisMorphOwner = ""
        x: root.windowed ? 0 : Math.round((parent.width - width) / 2)
        y: root.windowed ? 0 : Math.round((parent.height - height) / 2)
        width: root.windowed ? parent.width
            : Math.round(Math.min(parent.width - 32 - IrisFrame.musicReach("left") - IrisFrame.musicReach("right"), 1240 * root.d))
        height: root.windowed ? parent.height
            : Math.round(Math.min(parent.height - 48 - IrisFrame.musicReach("top") - IrisFrame.musicReach("bottom"), Math.max(640 * root.d, parent.height * 0.86)))
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.BackButton | Qt.ForwardButton
            onPressed: mouse => {
                if (mouse.button === Qt.BackButton) root.goBack()
                else if (mouse.button === Qt.ForwardButton) root.goForward()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: IrisStyle.concentricPad(frame.radius, 14 * root.d)
            spacing: Math.round(12 * root.d)

            // ── Toolbar ──────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(6 * root.d)
                IrisIconButton {
                    visible: root.backStack.length > 0
                    materialIcon: "chevron_left"
                    Accessible.name: Translation.tr("Back")
                    onClicked: root.goBack()
                }
                IrisIconButton {
                    visible: root.forwardStack.length > 0
                    materialIcon: "chevron_right"
                    Accessible.name: Translation.tr("Forward")
                    onClicked: root.goForward()
                }
                Item {
                    Layout.preferredWidth: Math.round(Math.min(420 * root.d, frame.width * 0.4))
                    Layout.preferredHeight: Math.round(36 * root.d)
                    IrisCutPlate { anchors.fill: parent; visible: IrisStyle.fieldChamfer; cutLength: Math.max(2, Math.min(8, Math.round(height / 4))); color: IrisStyle.fillQuiet }
                    Rectangle {
                        anchors.fill: parent
                        visible: !IrisStyle.fieldChamfer
                        radius: IrisStyle.capsule(height)
                        color: IrisStyle.fillQuiet
                        border.width: searchField.activeFocus ? Math.max(1, Math.round(root.d)) : 0
                        border.color: IrisStyle.accent
                    }
                    MaterialSymbol {
                        id: lens
                        anchors.left: parent.left
                        anchors.leftMargin: Math.round(12 * root.d)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        iconSize: Math.round(17 * root.d)
                        color: IrisStyle.textTertiary
                    }
                    TextInput {
                        id: searchField
                        anchors.left: lens.right
                        anchors.leftMargin: Math.round(8 * root.d)
                        anchors.right: clearSearch.left
                        anchors.rightMargin: Math.round(6 * root.d)
                        anchors.verticalCenter: parent.verticalCenter
                        color: IrisStyle.text
                        selectionColor: IrisStyle.accentContainer
                        selectedTextColor: IrisStyle.text
                        font.family: IrisStyle.fontMain
                        font.pixelSize: IrisStyle.typeLabel
                        clip: true
                        onTextChanged: { if (text.length === 0) { searchDelay.stop(); root.query = "" } else searchDelay.restart() }
                        Keys.onReturnPressed: root.openFirstResult()
                        Keys.onUpPressed: event => { if (text.length === 0) root.stepArea(-1); else event.accepted = false }
                        Keys.onDownPressed: event => { if (text.length === 0) root.stepArea(1); else event.accepted = false }
                        Timer { id: searchDelay; interval: 140; onTriggered: root.query = searchField.text }
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
                        anchors.rightMargin: Math.round(10 * root.d)
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
                Item { Layout.fillWidth: true }
                IrisButton {
                    visible: ShellErrors.count > 0 && root.selected !== "errors"
                    quiet: true
                    text: ShellErrors.count === 1 ? Translation.tr("1 error") : Translation.tr("%1 errors").arg(ShellErrors.count)
                    buttonRadius: IrisStyle.capsule(height)
                    onClicked: root.go({ selected: "errors" }, null)
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

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(24 * root.d)

                // ── The map ──────────────────────────────────────────
                ColumnLayout {
                    id: mapColumn
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: Math.round(Math.max(260 * root.d, Math.min(600 * root.d, frame.width * 0.44)))
                    Layout.maximumWidth: Layout.preferredWidth
                    Layout.fillHeight: true
                    spacing: Math.round(18 * root.d)

                    Item {
                        id: map
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(width * mapView.screenH / mapView.screenW)
                        // The pieces of your desktop, in its own coordinates. Panels and transient surfaces show where
                        // they open; a hovered map shows them all, the one under the pointer lit.
                        readonly property var pieces: {
                            const S = mapView.screenW, H = mapView.screenH, b = IrisFrame.band
                            const isl = mapView.island
                            const bottom = isl.edge === "bottom"
                            const below = bottom ? isl.y - 8 : isl.y + isl.height + 8
                            const out = [{ id: "island", rect: Qt.rect(isl.x, isl.y, isl.width, isl.height), radius: Math.min(isl.width, isl.height) / 2 }]
                            for (const slot of mapView.satellites) {
                                if (!mapView.kinds[slot]) continue
                                const r = mapView.satelliteRect(slot)
                                if (r && r.width > 0) out.push({ id: "bubble", rect: Qt.rect(r.x, r.y, r.width, r.height), radius: r.width / 2 })
                            }
                            const dock = mapView.dock
                            if (dock) out.push({ id: "dock", rect: Qt.rect(dock.x, dock.y, dock.width, dock.height), radius: Number(dock.radius ?? 16) })
                            const ghost = (id, x, y, w, h) => out.push({ id: id, rect: Qt.rect(x, y, w, h), radius: 18, ghost: true })
                            ghost("notifications", isl.x + isl.width / 2 - S * 0.13, bottom ? below - H * 0.08 : below, S * 0.26, H * 0.08)
                            ghost("controlCenter", S - b - 12 - S * 0.22, bottom ? H - b - 12 - H * 0.44 - isl.height : b + 12 + isl.height, S * 0.22, H * 0.44)
                            ghost("sidebars", b + 12, b + 12, S * 0.2, H - 2 * b - 24)
                            ghost("spotlight", S * 0.32, H * 0.3, S * 0.36, H * 0.1)
                            ghost("windows", S * 0.24, H * 0.22, S * 0.52, H * 0.56)
                            return out
                        }
                        function pieceAt(x: real, y: real): var {
                            const sx = x / mapView.s + mapView.view.x, sy = y / mapView.s + mapView.view.y
                            let best = null
                            for (const piece of map.pieces) {
                                const r = piece.rect
                                if (sx < r.x || sy < r.y || sx > r.x + r.width || sy > r.y + r.height) continue
                                if (!best || r.width * r.height < best.rect.width * best.rect.height) best = piece
                            }
                            if (best) return best
                            const edge = Math.max(IrisFrame.band, 10) + 6
                            if (sx < edge || sy < edge || sx > mapView.screenW - edge || sy > mapView.screenH - edge)
                                return { id: "frame", rect: Qt.rect(0, 0, mapView.screenW, mapView.screenH), radius: frame.radius, ring: true }
                            return { id: "desktop", rect: Qt.rect(0, 0, mapView.screenW, mapView.screenH), radius: 0, whole: true }
                        }
                        readonly property var hovered: mapPointer.containsMouse ? map.pieceAt(mapPointer.mouseX, mapPointer.mouseY) : null
                        // The areas a hovered row lands on, lit on the map.
                        property var reached: []
                        function lights(id: string): bool {
                            const entry = IrisOptions.entryById(id)
                            return (entry?.areas ?? []).some(area => map.reached.includes(area))
                        }

                        IrisScreenPreview {
                            id: mapView
                            anchors.fill: parent
                            screen: root.screen
                            radius: IrisStyle.fieldChamfer ? 0 : IrisStyle.radiusTile
                            function rectOf(id: string): var {
                                const piece = map.pieces.find(one => one.id === id)
                                const r = piece ? piece.rect : (id === "desktop" || id === "frame") ? Qt.rect(0, 0, mapView.screenW, mapView.screenH) : null
                                if (!r) return null
                                return { item: mapView, x: (r.x - mapView.view.x) * mapView.s, y: (r.y - mapView.view.y) * mapView.s, width: r.width * mapView.s, height: r.height * mapView.s }
                            }
                        }
                        Repeater {
                            model: map.pieces
                            Item {
                                id: mark
                                required property var modelData
                                readonly property bool isHovered: map.hovered?.id === mark.modelData.id
                                readonly property bool isSelected: !root.searching && root.selected === mark.modelData.id
                                readonly property bool isReached: map.lights(mark.modelData.id)
                                readonly property bool shown: mark.isHovered || mark.isSelected || mark.isReached || (mapPointer.containsMouse && Boolean(mark.modelData.ghost))
                                x: Math.round((mark.modelData.rect.x - mapView.view.x) * mapView.s)
                                y: Math.round((mark.modelData.rect.y - mapView.view.y) * mapView.s)
                                width: Math.round(mark.modelData.rect.width * mapView.s)
                                height: Math.round(mark.modelData.rect.height * mapView.s)
                                opacity: mark.shown ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                                IrisCutPlate {
                                    anchors.fill: parent
                                    visible: IrisStyle.fieldChamfer
                                    cutLength: Math.max(2, Math.min(8, Math.round(height / 4)))
                                    color: mark.isHovered || mark.isSelected ? Qt.alpha(IrisStyle.accent, 0.28) : mark.isReached ? Qt.alpha(IrisStyle.accent, 0.18) : Qt.alpha(IrisStyle.text, 0.10)
                                    stroke: mark.isHovered || mark.isSelected ? IrisStyle.accent : Qt.alpha(IrisStyle.text, 0.35)
                                    strokeWidth: Math.max(1, Math.round(1.5 * root.d))
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    visible: !IrisStyle.fieldChamfer
                                    radius: Math.min(height / 2, mark.modelData.radius * mapView.s + 2)
                                    color: mark.isHovered || mark.isSelected ? Qt.alpha(IrisStyle.accent, 0.28) : mark.isReached ? Qt.alpha(IrisStyle.accent, 0.18) : Qt.alpha(IrisStyle.text, 0.10)
                                    border.width: Math.max(1, Math.round(1.5 * root.d))
                                    border.color: mark.isHovered || mark.isSelected ? IrisStyle.accent : Qt.alpha(IrisStyle.text, 0.35)
                                }
                            }
                        }
                        // The frame and the bare desktop light as the whole map: a ring inside its edge, or its outline.
                        Rectangle {
                            readonly property bool lit: !root.searching && (map.hovered?.id === "frame" || (!map.hovered && root.selected === "frame") || map.lights("frame"))
                            anchors.fill: parent
                            radius: mapView.radius
                            color: "transparent"
                            border.width: Math.max(3, Math.round(IrisFrame.band * mapView.s + 3))
                            border.color: Qt.alpha(IrisStyle.accent, 0.45)
                            opacity: lit ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                        }
                        Rectangle {
                            readonly property bool lit: !root.searching && (map.hovered?.id === "desktop" || (!map.hovered && root.selected === "desktop") || map.lights("desktop"))
                            anchors.fill: parent
                            radius: mapView.radius
                            color: "transparent"
                            border.width: Math.max(2, Math.round(2 * root.d))
                            border.color: IrisStyle.accent
                            opacity: lit ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                        }
                        // What the pointer is over, named beside it.
                        Rectangle {
                            id: nameTag
                            readonly property var piece: map.hovered
                            visible: piece !== null
                            x: Math.round(Math.max(4, Math.min(map.width - width - 4, mapPointer.mouseX + 14 * root.d)))
                            y: Math.round(Math.max(4, Math.min(map.height - height - 4, mapPointer.mouseY + 14 * root.d)))
                            width: Math.round(tagText.implicitWidth + 20 * root.d)
                            height: Math.round(26 * root.d)
                            radius: IrisStyle.fieldChamfer ? 0 : IrisStyle.capsule(height)
                            color: IrisStyle.bodySurface
                            border.width: Math.max(1, Math.round(root.d))
                            border.color: IrisStyle.hairline
                            IrisText {
                                id: tagText
                                anchors.centerIn: parent
                                text: IrisOptions.entryLabel(IrisOptions.entryById(String(nameTag.piece?.id ?? "")))
                                font.pixelSize: IrisStyle.typeMeta
                                font.weight: IrisStyle.weight(Font.DemiBold)
                            }
                        }
                        MouseArea {
                            id: mapPointer
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                const piece = map.pieceAt(mouse.x, mouse.y)
                                root.go({ selected: piece.id }, piece.whole || piece.ring
                                    ? { item: map, x: mouse.x - 20, y: mouse.y - 20, width: 40, height: 40 } : mapView.rectOf(piece.id))
                            }
                        }
                    }

                    // ── Rooms: what has no piece on screen ───────────
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: rooms.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        GridLayout {
                            id: rooms
                            width: parent.width
                            columns: width >= 420 * root.d ? 3 : 2
                            rowSpacing: Math.round(2 * root.d)
                            columnSpacing: Math.round(4 * root.d)
                            Repeater {
                                model: IrisOptions.rooms.concat([IrisOptions.entryById("orbit")])
                                    .filter(one => one.id !== "battery" || Battery.available)
                                MouseArea {
                                    id: room
                                    required property var modelData
                                    readonly property bool isSelected: !root.searching && root.selected === room.modelData.id
                                    readonly property bool isReached: (room.modelData.areas ?? []).some(area => map.reached.includes(area))
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    implicitHeight: Math.round(38 * root.d)
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    Accessible.role: Accessible.Button
                                    Accessible.name: roomLabel.text
                                    onClicked: root.go({ selected: room.modelData.id }, { item: room, x: 0, y: 0, width: room.width, height: room.height })
                                    IrisCutPlate {
                                        anchors.fill: parent
                                        visible: IrisStyle.fieldChamfer
                                        cutLength: Math.max(2, Math.min(8, Math.round(height / 4)))
                                        color: plate.color
                                    }
                                    Rectangle {
                                        id: plate
                                        anchors.fill: parent
                                        visible: !IrisStyle.fieldChamfer
                                        radius: IrisStyle.radiusRow
                                        color: room.isSelected ? IrisStyle.rowSelectionFill : room.pressed ? IrisStyle.fillActive
                                            : room.containsMouse || room.isReached ? IrisStyle.fillQuiet : "transparent"
                                        Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                                    }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Math.round(8 * root.d)
                                        anchors.rightMargin: Math.round(8 * root.d)
                                        spacing: Math.round(10 * root.d)
                                        IrisSquircle {
                                            Layout.preferredWidth: Math.round(22 * root.d)
                                            Layout.preferredHeight: Math.round(22 * root.d)
                                            tint: IrisOptions.entryTint(room.modelData)
                                            glyph: IrisOptions.entryGlyph(room.modelData)
                                        }
                                        IrisText {
                                            id: roomLabel
                                            Layout.fillWidth: true
                                            text: IrisOptions.entryLabel(room.modelData)
                                            color: room.isSelected && IrisStyle.plateSelection ? IrisStyle.selectionInk : IrisStyle.text
                                            font.pixelSize: IrisStyle.typeLabel
                                            font.weight: IrisStyle.weight(room.isSelected ? Font.DemiBold : Font.Medium)
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── The inspector of what you touched ────────────────
                Item {
                    id: panelSlot
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.maximumWidth: Math.round(760 * root.d)
                    // The body it grows as: from the piece to its place, then the rows take over.
                    Item {
                        visible: root.grown < 0.999
                        readonly property real p: root.grown
                        x: root.growFrom.x + (0 - root.growFrom.x) * p
                        y: root.growFrom.y + (0 - root.growFrom.y) * p
                        width: root.growFrom.width + (panelSlot.width - root.growFrom.width) * p
                        height: root.growFrom.height + (panelSlot.height - root.growFrom.height) * p
                        opacity: 1 - IrisStyle.contentAt(p)
                        IrisCutPlate { anchors.fill: parent; visible: IrisStyle.fieldChamfer; color: IrisStyle.readingCard; stroke: Qt.alpha(IrisStyle.accent, 0.5); strokeWidth: Math.max(1, Math.round(root.d)) }
                        Rectangle {
                            anchors.fill: parent
                            visible: !IrisStyle.fieldChamfer
                            radius: IrisStyle.radiusCard
                            color: IrisStyle.readingCard
                            border.width: Math.max(1, Math.round(root.d))
                            border.color: Qt.alpha(IrisStyle.accent, 0.5)
                        }
                    }
                    IrisInspector {
                        id: inspector
                        anchors.fill: parent
                        visible: root.page.length === 0 || root.searching
                        opacity: IrisStyle.contentAt(root.grown)
                        pad: 0
                        entry: root.searching ? root.searchEntry : root.entry
                        area: root.area
                        query: root.query
                        searchAll: true
                        showSearch: false
                        landingGroup: root.landingGroup
                        landingPath: root.landingPath
                        tuneAll: root.tuneAll
                        onReaching: sections => map.reached = sections
                        onOpenArea: (section, group, path) => root.openArea(section, group, path)
                        extra: Component {
                            IrisIconButton {
                                // The real piece, on the real desktop.
                                visible: IrisOptions.pieces.some(one => one.id === root.selected) && root.selected !== "windows"
                                materialIcon: "ads_click"
                                Accessible.name: Translation.tr("Edit on the desktop")
                                onClicked: {
                                    GlobalStates.settingsOverlayOpen = false
                                    GlobalStates.irisEditTarget = root.selected === "frame" || root.selected === "desktop" ? root.selected + "@" : root.selected
                                    GlobalStates.irisEdit = true
                                }
                            }
                        }
                    }
                    Loader {
                        anchors.fill: parent
                        active: root.page.length > 0 && !root.searching
                        visible: active
                        opacity: IrisStyle.contentAt(root.grown)
                        source: root.page.length > 0 ? root.pageUrls[root.page] : ""
                    }
                }
            }
        }
    }
}
