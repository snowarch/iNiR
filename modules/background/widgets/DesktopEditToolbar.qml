pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.settings
import qs.modules.iris.components
import qs.modules.iris.field as IrisFieldModule

Item {
    id: root

    required property real availableWidth
    required property real availableHeight
    property bool libraryOpen: false
    property string outputName: ""
    property bool hasSelection: false
    property bool gridExpanded: false
    property bool attachedTopEdge: false
    // iRiS draws the body in the chassis field, joined to the frame; the toolbar keeps only its controls.
    property bool bodyless: false

    signal libraryRequested()
    signal settingsRequested()
    signal edgeSettingsRequested()
    signal doneRequested()

    readonly property int gridSize: Config.getNestedValue("background.widgets.editGrid.size", 32)
    readonly property bool snap: Config.getNestedValue("background.widgets.editGrid.snap", true)
    readonly property bool compact: availableWidth < 760
    readonly property int railItemStride: 34
    readonly property int railSlots: Math.max(4, Math.min(root.iris ? 12 : 14,
        Math.floor(Math.max(railStride * 4, availableWidth - (root.compact ? 330 : 470)) / railStride)))
    readonly property real railWidth: railSlots * railStride - (root.iris ? root.irisRailSpacing : 0)
    readonly property int irisRailSpacing: Math.round(4 * root.d)
    readonly property var builtinWidgets: [
        { key: "weather", icon: "cloud", label: "Weather", defaultOn: false },
        { key: "customImage", icon: "add_photo_alternate", label: "Custom Image", defaultOn: false },
        { key: "imageConverter", icon: "transform", label: "Image Converter", defaultOn: false },
        { key: "clock", icon: "schedule", label: "Clock", defaultOn: true },
        { key: "mediaControls", icon: "album", label: "Media", defaultOn: false },
        { key: "japaneseTypography", icon: "translate", label: "Japanese Typography", defaultOn: false },
        { key: "visualizer", icon: "graphic_eq", label: "Visualizer", defaultOn: false },
        { key: "systemMonitor", icon: "monitor_heart", label: "System Monitor", defaultOn: false },
        { key: "battery", icon: "battery_full", label: "Battery", defaultOn: false },
        { key: "notes", icon: "sticky_note_2", label: "Notes", defaultOn: false },
        { key: "calendarUpcoming", icon: "event", label: "Upcoming Events", defaultOn: false },
        { key: "monthCalendar", icon: "calendar_month", label: "Month Calendar", defaultOn: false },
        { key: "todo", icon: "checklist", label: "Todo", defaultOn: false },
        { key: "timers", icon: "timer", label: "Timers", defaultOn: false },
        { key: "dayProgress", icon: "timelapse", label: "Day progress", defaultOn: false },
        { key: "uptime", icon: "avg_pace", label: "System Uptime", defaultOn: false },
        { key: "shape", icon: "category", label: "Decorative Shape", defaultOn: false },
        { key: "dateBadge", icon: "today", label: "Date Badge", defaultOn: false },
        { key: "editorial", icon: "text_fields", label: "Editorial", defaultOn: false },
        { key: "mascot", icon: "pets", label: "Mascot", defaultOn: false },
        { key: "newsTicker", icon: "newspaper", label: "News Ticker", defaultOn: false },
        { key: "worldClock", icon: "public", label: "World Clock", defaultOn: false },
        { key: "userCard", icon: "account_circle", label: "User Card", defaultOn: false },
        { key: "controls", icon: "toggle_on", label: "Controls", defaultOn: false, irisOnly: true },
        { key: "screenTime", icon: "hourglass_bottom", label: "Screen Time", defaultOn: false, irisOnly: true }
    ]

    readonly property bool iris: (Config.options?.panelFamily ?? "ii") === "iris"
    readonly property real d: root.iris ? IrisStyle.density : 1
    readonly property real irisSlot: Math.round(30 * root.d)
    readonly property real controlHeight: Math.round(38 * root.d)
    readonly property real railStride: root.iris ? root.irisSlot + root.irisRailSpacing : root.railItemStride
    readonly property var irisEntries: {
        const out = root.builtinWidgets.map(widget => ({ key: widget.key, icon: widget.icon, label: widget.label,
            tint: IrisStyle.identityOf(DesktopWidgetIdentity.tint(widget.key)),
            on: DesktopWidgetLayout.enabled(root.outputName, widget.key,
                Config.getNestedValue("background.widgets." + widget.key + ".enable", widget.defaultOn)) }))
        for (const custom of (CustomWidgets.ready ? CustomWidgets.widgets : [])) {
            const key = "custom." + custom.id
            out.push({ key: key, icon: custom.icon || "widgets", label: custom.name, tint: IrisStyle.identityOf(DesktopWidgetIdentity.customTint),
                on: DesktopWidgetLayout.enabled(root.outputName, key,
                    Config.getNestedValue("background.widgets.custom." + custom.id + ".enable", false)) })
        }
        return out
    }
    readonly property int irisOnCount: root.irisEntries.filter(entry => entry.on).length
    // ── Finding a widget (iRiS) ───────────────────────────────────────────
    // Spotlight's grammar in the bar's own tiles: the shell's forgiving matcher (IrisSearch), a selection that slides
    // between tiles, ↑/↓/Tab/←/→ to move, ↵ to take it, Escape to clear and then close.
    readonly property string searchText: GlobalStates.widgetSearchText
    property int searchIndex: 0
    property bool pointerArmed: false
    property point lastPointer: Qt.point(-1, -1)
    readonly property bool searching: root.iris && GlobalStates.widgetSearchOpen && GlobalStates.widgetEditMode
        && (GlobalStates.focusedScreen?.name ?? root.outputName) === root.outputName
    readonly property var searchResults: {
        if (!root.searching) return []
        const entries = IrisSearch.entries().filter(entry => entry.kind === "widget")
        const query = root.searchText.trim()
        const hits = []
        entries.forEach((entry, order) => {
            const score = query.length === 0 ? 1 : IrisSearch.score(query, entry)
            if (score > 0) hits.push({ entry: entry, score: score, order: order })
        })
        hits.sort((a, b) => b.score - a.score || (b.entry.on ? 1 : 0) - (a.entry.on ? 1 : 0) || a.order - b.order)
        return hits.map(hit => hit.entry)
    }
    readonly property var chosen: root.searchResults[Math.min(root.searchIndex, root.searchResults.length - 1)] ?? null
    onSearchTextChanged: root.searchIndex = 0
    function openSearch(): void {
        GlobalStates.widgetSearchOpen = true
        root.searchIndex = 0
        root.pointerArmed = false
        root.lastPointer = Qt.point(-1, -1)
        focusTimer.restart()
    }
    function closeSearch(): void {
        GlobalStates.widgetSearchOpen = false
        GlobalStates.widgetSearchText = ""
    }
    // Escape clears what was typed, then closes.
    function escapeSearch(): void {
        if (root.searchText.length > 0) GlobalStates.widgetSearchText = ""
        else root.closeSearch()
    }
    function moveSearch(step: int): void {
        root.pointerArmed = false
        root.searchIndex = Math.max(0, Math.min(root.searchResults.length - 1, root.searchIndex + step))
    }
    function takeResult(index: int): void {
        const entry = root.searchResults[index]
        if (!entry) return
        root.closeSearch()
        entry.run()
    }
    // A hover only picks a result once the pointer has really moved, so a still pointer never fights the keys.
    function pointerOver(index: int, x: real, y: real): void {
        const moved = root.lastPointer.x >= 0 && (Math.abs(x - root.lastPointer.x) > 0.5 || Math.abs(y - root.lastPointer.y) > 0.5)
        root.lastPointer = Qt.point(x, y)
        if (moved) root.pointerArmed = true
        if (root.pointerArmed && root.searchIndex !== index) root.searchIndex = index
    }
    Connections {
        target: GlobalStates
        function onWidgetSearchCommand(verb: string): void {
            if (!root.searching) return
            if (verb === "next") root.moveSearch(1)
            else if (verb === "previous") root.moveSearch(-1)
            else if (verb === "take") root.takeResult(root.searchIndex)
        }
    }
    Timer { id: focusTimer; interval: 60; onTriggered: searchInput.forceActiveFocus() }
    property var irisOrder: []
    function irisResort(): void {
        const on = root.irisEntries.filter(entry => entry.on).map(entry => entry.key)
        const off = root.irisEntries.filter(entry => !entry.on).map(entry => entry.key)
        root.irisOrder = on.length > 0 && off.length > 0 ? on.concat(["|"], off) : on.concat(off)
    }
    onIrisOnCountChanged: if (!railHover.hovered) root.irisResort()
    Component.onCompleted: root.irisResort()
    readonly property real bodyHeight: root.iris ? Math.round(56 * root.d) : 48
    readonly property real bodyRadius: root.iris ? Math.min(IrisStyle.radius, root.bodyHeight / 2) : 0
    readonly property real fillet: root.iris ? Math.round(root.bodyRadius * 0.62) : 0
    readonly property string inwardTooltipPosition: root.attachedTopEdge ? "bottom" : "top"
    // Searching swaps the middle of the bar for the field and its results; the body keeps the width it had.
    property real idleRowWidth: 0
    Binding { target: root; property: "idleRowWidth"; value: toolbarRow.implicitWidth; when: !root.searching; restoreMode: Binding.RestoreNone }
    readonly property real rowWidth: root.searching ? root.idleRowWidth : toolbarRow.implicitWidth
    readonly property real bodyWidth: root.iris
        ? Math.min(Math.max(280, availableWidth - 2 * root.fillet),
            Math.max(320, root.rowWidth + 20))
        : Math.min(availableWidth, Math.max(320, root.rowWidth + 12))
    width: root.bodyWidth + (root.iris ? 2 * root.fillet : 0)
    height: root.bodyHeight

    Item {
        id: bodyFrame
        x: root.iris ? root.fillet : 0
        width: root.bodyWidth
        height: root.height
    }

    Toolbar {
        anchors.fill: bodyFrame
        padding: 6
        spacing: 4
        transparent: root.iris
        screenX: root.x
        screenY: root.y
    }

    IrisFieldModule.IrisField {
        id: irisNotchField
        visible: root.iris && !root.bodyless
        readonly property real pad: IrisStyle.fuseEdge
        readonly property real deep: Math.max(8, IrisStyle.fuseEdge)
        readonly property real bodyTop: root.attachedTopEdge ? irisNotchField.deep - root.bodyRadius : 0
        x: -irisNotchField.pad
        y: root.attachedTopEdge ? -irisNotchField.deep : 0
        width: root.width + 2 * irisNotchField.pad
        height: root.height + irisNotchField.deep
        framed: false
        tint: IrisStyle.surface
        shapes: !root.iris ? [] : [
            { x: 0, y: root.attachedTopEdge ? 0 : root.height, width: irisNotchField.width, height: irisNotchField.deep,
                radius: 0, paints: true, fuse: 0, id: "edge" },
            { x: irisNotchField.pad + bodyFrame.x, y: irisNotchField.bodyTop, width: root.bodyWidth,
                height: root.bodyHeight + root.bodyRadius, radius: root.bodyRadius, paints: true,
                fuse: IrisStyle.fuseEdge, id: "toolbar", joins: "edge" }
        ]
    }

    // Grid is one control: off, then each lattice size, then off again.
    readonly property var gridSteps: [0, 16, 32, 48, 64]
    function cycleGrid(): void {
        const current = root.snap ? root.gridSize : 0
        const next = root.gridSteps[(Math.max(0, root.gridSteps.indexOf(current)) + 1) % root.gridSteps.length]
        if (next === 0)
            Config.setNestedValue("background.widgets.editGrid.snap", false)
        else
            Config.setNestedValues({ "background.widgets.editGrid.snap": true, "background.widgets.editGrid.size": next })
    }

    // A small round arrow at an end of the rail that scrolls on.
    component RailArrow: Rectangle {
        id: arrow
        property bool leading: true
        property bool shown: false
        property bool usable: true
        signal activated()
        enabled: arrow.usable
        width: root.iris ? Math.round(24 * root.d) : 26
        height: width
        radius: width / 2
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: arrowHover.hovered ? (root.iris ? IrisStyle.fillActive : Appearance.colors.colLayer2Hover)
            : (root.iris ? IrisStyle.fillHover : Appearance.colors.colLayer2)
        opacity: !arrow.shown ? 0 : arrow.usable ? 1 : 0.35
        visible: opacity > 0
        scale: arrowTap.pressed ? 0.92 : 1
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 110 } }
        MaterialSymbol {
            anchors.centerIn: parent
            text: arrow.leading ? "chevron_left" : "chevron_right"
            iconSize: root.iris ? Math.round(15 * root.d) : 17
            color: root.iris ? IrisStyle.text : Appearance.colors.colOnLayer2
        }
        HoverHandler { id: arrowHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: arrowTap; gesturePolicy: TapHandler.WithinBounds; onTapped: arrow.activated() }
        StyledToolTip {
            text: arrow.leading ? Translation.tr("Previous widgets") : Translation.tr("More widgets")
            extraVisibleCondition: arrowHover.hovered
            position: root.iris ? root.inwardTooltipPosition : "bottom"
        }
    }

    MouseArea {
        anchors.fill: bodyFrame
        z: -1
        acceptedButtons: Qt.AllButtons
    }

    RowLayout {
        id: toolbarRow
        anchors.fill: bodyFrame
        anchors.margins: root.iris ? Math.round(9 * root.d) : 6
        anchors.leftMargin: root.iris ? Math.round(10 * root.d) : 6
        anchors.rightMargin: root.iris ? Math.round(8 * root.d) : 6
        spacing: root.iris ? Math.round(8 * root.d) : 4

        WidgetEditAction {
            id: libraryAction
            visible: !root.searching
            plate: true
            iconName: "add"
            label: Translation.tr("Add widgets")
            compact: root.compact
            toggled: root.libraryOpen
            tooltip: Translation.tr("Browse every widget")
            tooltipPosition: root.iris ? root.inwardTooltipPosition : "bottom"
            onClicked: root.libraryRequested()
        }

        Rectangle {
            id: railBox
            visible: !root.searching
            Layout.fillWidth: true
            Layout.minimumWidth: root.railStride * 3
            Layout.preferredWidth: root.railWidth + (root.iris ? 8 : 0)
            Layout.maximumWidth: root.railWidth + (root.iris ? 8 : 0)
            Layout.preferredHeight: root.iris ? root.controlHeight : 34
            radius: height / 2
            color: root.iris ? IrisStyle.fillQuiet : "transparent"
            // Measured against the box, not the rail, so reserving the arrow slots cannot feed back.
            readonly property bool overflows: widgetRow.implicitWidth > railBox.width - (root.iris ? 8 : 0)

            Flickable {
                id: widgetRail
                // Arrows take their own slot at an end that scrolls, so they never sit on a tile, and the
                // view is a whole number of slots so no tile is cut at its edge.
                readonly property real room: railBox.width - 2 * (root.iris ? 4 : 0) - (railBox.overflows ? 60 : 0)
                width: railBox.overflows
                    ? Math.max(root.railStride, Math.floor((widgetRail.room + (root.iris ? root.irisRailSpacing : 0)) / root.railStride) * root.railStride
                        - (root.iris ? root.irisRailSpacing : 0))
                    : widgetRail.room
                height: railBox.height
                x: Math.round((railBox.width - widgetRail.width) / 2)
                contentWidth: widgetRow.implicitWidth
                contentHeight: height
                clip: true
                interactive: contentWidth > width
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick
                readonly property bool canBack: widgetRail.contentX > 1
                readonly property bool canForward: widgetRail.contentX < Math.max(0, widgetRail.contentWidth - widgetRail.width) - 1

                function snapContentX(value: real): real {
                    const maxX = Math.max(0, contentWidth - width)
                    const snapped = Math.round(value / root.railStride) * root.railStride
                    return Math.max(0, Math.min(maxX, snapped))
                }

                function scrollPage(direction: int): void {
                    const page = Math.max(root.railStride, Math.floor(width / root.railStride - 1) * root.railStride)
                    contentX = snapContentX(contentX + direction * page)
                }

                Behavior on contentX {
                    enabled: !widgetRail.moving
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
                onMovementEnded: contentX = snapContentX(contentX)
                onWidthChanged: railSnapSettle.restart()
                onContentWidthChanged: railSnapSettle.restart()

                Timer {
                    id: railSnapSettle
                    interval: 0
                    onTriggered: widgetRail.contentX = widgetRail.snapContentX(widgetRail.contentX)
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const horizontal = event.angleDelta.x
                        const vertical = event.angleDelta.y
                        const delta = Math.abs(horizontal) > Math.abs(vertical) ? -horizontal : -vertical
                        if (delta !== 0)
                            widgetRail.contentX = widgetRail.snapContentX(widgetRail.contentX
                                + (delta > 0 ? root.railStride * 3 : -root.railStride * 3))
                        event.accepted = true
                    }
                }

                HoverHandler {
                    id: railHover
                    onHoveredChanged: if (!hovered) root.irisResort()
                }

                Row {
                    id: widgetRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.iris ? root.irisRailSpacing : 2

                    Repeater {
                        model: root.iris ? root.irisOrder : []
                        Item {
                            id: irisSlot
                            required property string modelData
                            readonly property var entry: root.irisEntries.find(item => item.key === irisSlot.modelData) ?? null
                            width: root.irisSlot
                            height: railBox.height
                            Rectangle {
                                visible: !irisSlot.entry
                                anchors.centerIn: parent
                                width: 1
                                height: Math.round(16 * root.d)
                                color: IrisStyle.hairlineStrong
                            }
                            WidgetEditAction {
                                visible: irisSlot.entry !== null
                                compact: true
                                tileTint: irisSlot.entry?.tint ?? "transparent"
                                iconName: irisSlot.entry?.icon ?? ""
                                label: Translation.tr(irisSlot.entry?.label ?? "")
                                tooltip: (irisSlot.entry?.on ? Translation.tr("%1 · on, click to remove") : Translation.tr("%1 · click to add"))
                                    .arg(Translation.tr(irisSlot.entry?.label ?? ""))
                                tooltipPosition: root.inwardTooltipPosition
                                toggled: irisSlot.entry?.on ?? false
                                onClicked: DesktopWidgetLayout.setGloballyEnabled(irisSlot.modelData, !(irisSlot.entry?.on ?? false))
                            }
                        }
                    }

                    Repeater {
                        model: root.iris ? [] : root.builtinWidgets.filter(widget => !widget.irisOnly)
                        WidgetEditAction {
                            required property var modelData
                            readonly property bool widgetEnabled: DesktopWidgetLayout.enabled(
                                root.outputName, modelData.key,
                                Config.getNestedValue("background.widgets." + modelData.key + ".enable", modelData.defaultOn))
                            compact: true
                            iconName: modelData.icon
                            label: Translation.tr(modelData.label)
                            tooltip: Translation.tr(modelData.label)
                            tooltipPosition: "bottom"
                            toggled: widgetEnabled
                            onClicked: DesktopWidgetLayout.setGloballyEnabled(modelData.key, !widgetEnabled)
                        }
                    }

                    Repeater {
                        model: !root.iris && CustomWidgets.ready ? CustomWidgets.widgets : []
                        WidgetEditAction {
                            required property var modelData
                            readonly property string layoutKey: "custom." + modelData.id
                            readonly property bool widgetEnabled: DesktopWidgetLayout.enabled(
                                root.outputName, layoutKey,
                                Config.getNestedValue("background.widgets.custom." + modelData.id + ".enable", false))
                            compact: true
                            iconName: modelData.icon || "widgets"
                            label: modelData.name
                            tooltip: modelData.name
                            tooltipPosition: "bottom"
                            toggled: widgetEnabled
                            onClicked: DesktopWidgetLayout.setGloballyEnabled(layoutKey, !widgetEnabled)
                        }
                    }
                }
            }

            RailArrow {
                id: backArrow
                anchors.left: parent.left
                anchors.leftMargin: 6
                leading: true
                shown: railBox.overflows
                usable: widgetRail.canBack
                onActivated: widgetRail.scrollPage(-1)
            }
            RailArrow {
                id: forwardArrow
                anchors.right: parent.right
                anchors.rightMargin: 6
                leading: false
                shown: railBox.overflows
                usable: widgetRail.canForward
                onActivated: widgetRail.scrollPage(1)
            }
        }

        // Grid, screen edges and settings share one quiet pill, concentric with the rail beside it.
        Rectangle {
            id: toolsBox
            visible: !root.searching
            Layout.preferredHeight: root.iris ? root.controlHeight : 34
            Layout.preferredWidth: toolsRow.implicitWidth + (root.iris ? Math.round(8 * root.d) : 0)
            radius: height / 2
            color: root.iris ? IrisStyle.fillQuiet : "transparent"

            RowLayout {
                id: toolsRow
                anchors.centerIn: parent
                spacing: root.iris ? Math.round(2 * root.d) : 4

                WidgetEditAction {
                    visible: root.iris
                    compact: true
                    inPill: true
                    iconName: "search"
                    label: Translation.tr("Search widgets")
                    tooltip: Translation.tr("Search widgets (Ctrl+F)")
                    tooltipPosition: root.inwardTooltipPosition
                    toggled: root.searching
                    onClicked: root.searching ? root.closeSearch() : root.openSearch()
                }

                WidgetEditAction {
                    id: gridAction
                    inPill: true
                iconName: "grid_on"
                    label: root.snap ? Translation.tr("Grid %1").arg(root.gridSize) : Translation.tr("No grid")
                    compact: root.compact
                    toggled: root.snap
                    tooltip: root.snap ? Translation.tr("Widgets snap to a %1 px grid · click for the next size").arg(root.gridSize)
                        : Translation.tr("Widgets move freely · click to snap them to a grid")
                    tooltipPosition: root.iris ? root.inwardTooltipPosition : "bottom"
                    onClicked: root.cycleGrid()
                }

                WidgetEditAction {
                    compact: true
                    iconName: "border_outer"
                    label: Translation.tr("Screen edges")
                    tooltip: Translation.tr("Organic edge settings")
                    tooltipPosition: root.iris ? root.inwardTooltipPosition : "bottom"
                    onClicked: root.edgeSettingsRequested()
                }

                WidgetEditAction {
                    compact: true
                    iconName: "settings"
                    label: Translation.tr("Widget settings")
                    tooltip: Translation.tr("Every widget option in Settings")
                    tooltipPosition: root.iris ? root.inwardTooltipPosition : "bottom"
                    onClicked: root.settingsRequested()
                }
            }
        }

        Rectangle {
            id: searchBox
            visible: root.searching
            Layout.fillWidth: true
            Layout.preferredHeight: root.controlHeight
            radius: height / 2
            color: IrisStyle.fillQuiet

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.round(14 * root.d)
                anchors.rightMargin: Math.round(12 * root.d)
                spacing: Math.round(8 * root.d)

                MaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    text: "search"
                    iconSize: Math.round(18 * root.d)
                    color: root.searchText.length > 0 ? IrisStyle.accent : IrisStyle.subtext
                }
                TextInput {
                    id: searchInput
                    Layout.preferredWidth: Math.round(184 * root.d)
                    Layout.alignment: Qt.AlignVCenter
                    text: root.searchText
                    color: IrisStyle.text
                    selectionColor: IrisStyle.accentContainer
                    selectedTextColor: IrisStyle.inkOnAccentContainer
                    font.family: IrisStyle.fontMain
                    font.pixelSize: IrisStyle.typeBody
                    clip: true
                    onTextChanged: if (GlobalStates.widgetSearchText !== text) GlobalStates.widgetSearchText = text
                    Keys.onPressed: event => {
                        const atEnd = searchInput.cursorPosition >= searchInput.text.length && searchInput.selectedText.length === 0
                        const atStart = searchInput.cursorPosition === 0 && searchInput.selectedText.length === 0
                        if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (event.key === Qt.Key_Right && atEnd))
                            root.moveSearch(1)
                        else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (event.key === Qt.Key_Left && atStart))
                            root.moveSearch(-1)
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            root.takeResult(root.searchIndex)
                        else if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier))
                            searchInput.selectAll()
                        else
                            return
                        event.accepted = true
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text.length === 0
                        text: Translation.tr("Search widgets")
                        color: IrisStyle.muted
                        font.family: searchInput.font.family
                        font.pixelSize: searchInput.font.pixelSize
                    }
                }
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Math.round(20 * root.d)
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    opacity: root.searchText.length > 0 ? 1 : 0
                    enabled: root.searchText.length > 0
                    color: clearHover.hovered ? IrisStyle.fillActive : IrisStyle.fillHover
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.feedbackDuration } }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: Math.round(13 * root.d)
                        color: IrisStyle.textSecondary
                    }
                    HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { GlobalStates.widgetSearchText = ""; searchInput.forceActiveFocus() } }
                    Accessible.role: Accessible.Button
                    Accessible.name: Translation.tr("Clear")
                }
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: Math.round(4 * root.d)
                    Layout.rightMargin: Math.round(4 * root.d)
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: Math.round(16 * root.d)
                    color: IrisStyle.hairlineStrong
                }

                // The widgets that answer, in the rail's own tiles, in whole slots; the selection slides between them.
                Item {
                    id: resultsBox
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Flickable {
                        id: resultsView
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height
                        // Room at both ends for the selection to breathe, so a tile is never pressed against the edge of
                        // the view: whole slots between two equal margins, centred in what the name leaves.
                        // As wide as the gap between tiles, so the next tile never shows as a sliver at the edge.
                        readonly property real pad: root.irisRailSpacing
                        readonly property int fits: Math.max(1, Math.floor((resultsBox.width - 2 * resultsView.pad + root.irisRailSpacing) / root.railStride))
                        leftMargin: resultsView.pad
                        rightMargin: resultsView.pad
                        width: Math.min(root.searchResults.length, resultsView.fits) * root.railStride - root.irisRailSpacing + 2 * resultsView.pad
                        x: Math.round((resultsBox.width - width) / 2)
                        contentWidth: root.searchResults.length * root.railStride - root.irisRailSpacing
                        contentHeight: height
                        clip: true
                        interactive: root.searchResults.length > resultsView.fits
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds

                        readonly property real plateX: root.searchIndex * root.railStride - Math.round(2 * root.d)
                        Behavior on contentX {
                            enabled: !resultsView.moving
                            NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing }
                        }
                        function reveal(): void {
                            const plate = root.irisSlot + Math.round(4 * root.d)
                            const room = resultsView.pad - Math.round(2 * root.d)
                            const low = -resultsView.leftMargin
                            const high = Math.max(low, resultsView.contentWidth + resultsView.rightMargin - resultsView.width)
                            let target = resultsView.contentX
                            if (resultsView.plateX - room < target) target = resultsView.plateX - room
                            else if (resultsView.plateX + plate + room > target + resultsView.width) target = resultsView.plateX + plate + room - resultsView.width
                            resultsView.contentX = Math.max(low, Math.min(high, target))
                        }
                        Connections { target: root; function onSearchIndexChanged(): void { resultsView.reveal() } }

                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => {
                                const delta = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) ? -event.angleDelta.x : -event.angleDelta.y
                                const low = -resultsView.leftMargin
                                const high = Math.max(low, resultsView.contentWidth + resultsView.rightMargin - resultsView.width)
                                resultsView.contentX = Math.max(low, Math.min(high,
                                    resultsView.contentX + (delta > 0 ? 1 : -1) * root.railStride * 2))
                                event.accepted = true
                            }
                        }

                        // Spotlight's selection: the accent wash, one radius wider than what it holds.
                        Rectangle {
                            visible: root.searchResults.length > 0
                            x: resultsView.plateX
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.irisSlot + Math.round(4 * root.d)
                            height: width
                            radius: IrisStyle.radiusRow
                            color: IrisStyle.tintFill(IrisStyle.accent)
                            Behavior on x { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                        }

                        Row {
                            id: resultsRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: root.irisRailSpacing

                            Repeater {
                                model: ScriptModel { values: root.searchResults; objectProp: "name" }

                                Item {
                                    id: hit
                                    required property var modelData
                                    required property int index
                                    width: root.irisSlot
                                    height: railBox.height

                                    WidgetEditAction {
                                        compact: true
                                        badge: false
                                        tileTint: hit.modelData.tint
                                        iconName: hit.modelData.icon
                                        label: hit.modelData.name
                                        toggled: hit.modelData.on
                                        tooltip: hit.modelData.name
                                        tooltipPosition: root.inwardTooltipPosition
                                        onClicked: root.takeResult(hit.index)
                                    }
                                    HoverHandler {
                                        onPointChanged: root.pointerOver(hit.index, point.scenePosition.x, point.scenePosition.y)
                                    }
                                }
                            }
                        }
                    }

                    IrisText {
                        visible: root.searchResults.length === 0
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: Translation.tr("No widget called “%1”").arg(root.searchText.trim())
                        color: IrisStyle.textSecondary
                        font.pixelSize: IrisStyle.typeLabel
                    }
                }

                // What ↵ will do, as Spotlight says it: the name, the verb and the key.
                RowLayout {
                    visible: root.chosen !== null
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: false
                    // As wide as the longest name among the results, so it does not move while the selection does.
                    Layout.preferredWidth: Math.min(Math.round(230 * root.d), Math.ceil(nameMetrics.width + verbMetrics.width + Math.round((24 + 16 + 4) * root.d)))
                    spacing: Math.round(8 * root.d)

                    TextMetrics {
                        id: nameMetrics
                        font.family: IrisStyle.fontMain
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.DemiBold)
                        text: root.searchResults.reduce((longest, entry) => entry.name.length > longest.length ? entry.name : longest, "")
                    }
                    TextMetrics {
                        id: verbMetrics
                        font.family: IrisStyle.fontMain
                        font.pixelSize: IrisStyle.typeMeta
                        text: Translation.tr("Show").length > Translation.tr("Add").length ? Translation.tr("Show") : Translation.tr("Add")
                    }

                    IrisText {
                        Layout.fillWidth: true
                        text: root.chosen?.name ?? ""
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.DemiBold)
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                    }
                    IrisText {
                        text: root.chosen ? (root.chosen.on ? Translation.tr("Show") : Translation.tr("Add")) : ""
                        color: IrisStyle.subtext
                        font.pixelSize: IrisStyle.typeMeta
                    }
                    Rectangle {
                        Layout.preferredWidth: Math.round(24 * root.d)
                        Layout.preferredHeight: Math.round(20 * root.d)
                        radius: IrisStyle.radiusChip
                        color: IrisStyle.fill
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "keyboard_return"
                            iconSize: Math.round(14 * root.d)
                            color: IrisStyle.text
                        }
                    }
                }
            }
        }

        WidgetEditAction {
            id: doneAction
            iconName: "check"
            label: Translation.tr("Done")
            compact: root.availableWidth < 560
            primary: true
            tooltip: Translation.tr("Done editing")
            tooltipPosition: root.iris ? root.inwardTooltipPosition : "bottom"
            onClicked: root.doneRequested()
        }
    }
}
