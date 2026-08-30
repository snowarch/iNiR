pragma ComponentBehavior: Bound

import qs
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.background.widgets

/**
 * Desktop mascot widget: a pose from the catalog living on the wallpaper
 * layer, pose picked visually in Settings › Widgets › Mascot. Tapping her
 * pokes the live companion. Registered per the folder contract: import +
 * _builtinWidgets entry + FadeLoader + knownWidgets in Background.qml,
 * schema in Config.qml, defaults/config.json, DesktopWidgetsConfig section,
 * WidgetManagerPanel _supportsAppearance whitelist.
 */
AbstractBackgroundWidget {
    id: root

    configEntryName: "mascot"
    defaultConfig: ({
        placementStrategy: "free", contentWidth: 200,
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        showBackground: false, showBorder: false, backgroundOpacity: 0.16,
        borderWidth: 1, borderOpacity: 0.2, cornerRadius: -1, useBlur: false,
        pose: "reading", poseFilter: "all", posePickerMode: "buttons",
        customPath: "", anchorWidget: "",
        x: 120, y: 320
    })

    property int mascotContentSize: 200
    function _syncMascotContentSize(): void {
        const contentWidth = Number(root._readConfigKey("contentWidth") ?? 200)
        const baseScale = Number(root._baseScale)
        const next = Math.round(
            (Number.isFinite(contentWidth) ? contentWidth : 200)
            * (Number.isFinite(baseScale) ? baseScale : 1))
        if (root.mascotContentSize !== next)
            root.mascotContentSize = next
    }
    implicitWidth: root.mascotContentSize
    implicitHeight: root.mascotContentSize
    // She's an image — no ink to adapt — but her optional card is the shared
    // region-aware plate, so run the analysis only while the card is on.
    needsColText: widgetHasSurface
    resizableAxes: ({ uniform: "contentWidth" })
    resizeMinWidth: 96
    resizeMinHeight: 96

    readonly property string pose: root._readConfigKey("pose") ?? "reading"
    // Any user-supplied image/GIF replaces the catalog pose entirely
    readonly property string customPath: root._readConfigKey("customPath") ?? ""

    // ── Perching: sit on top of another widget instead of a free-floating spot ──
    readonly property string anchorWidget: root._readConfigKey("anchorWidget") ?? ""
    readonly property bool perched: root.anchorWidget.length > 0
    // Live sibling instead of its stored x/y: auto-placed widgets ("leastBusy")
    // never write the coordinates they actually render at, and a dragged anchor
    // only writes on release. Every widget is `Loader { WidgetX {} }` inside the
    // canvas, and the loaders sit at 0,0 — so the item's x/y are canvas coords.
    // Resolved imperatively: a binding over `canvas.children[i].item` re-runs
    // whenever any sibling loader re-sizes, which Qt reports as a binding loop.
    property Item _anchorItem: null
    function _resolveAnchorItem(): void {
        const canvas = root.perched ? (root.parent?.parent ?? null) : null
        if (!canvas) {
            root._anchorItem = null
            return
        }
        for (let i = 0; i < canvas.children.length; ++i) {
            const child = canvas.children[i]
            const item = child?.item ?? child
            if (item && item !== root && item.configEntryName === root.anchorWidget) {
                root._anchorItem = item
                return
            }
        }
        root._anchorItem = null
    }
    // Other enabled widgets she could perch on (built-ins + other mascot instances, excluding herself)
    readonly property var _anchorCandidates: {
        Config.revision
        const keys = ["clock", "weather", "mediaControls", "visualizer", "systemMonitor",
            "battery", "notes", "calendarUpcoming", "uptime", "newsTicker",
            "worldClock", "userCard"]
        const list = []
        for (const k of keys) {
            if (k === root.configEntryName) continue
            if (DesktopWidgetLayout.enabled(root.outputName, k,
                    Config.getNestedValue("background.widgets." + k + ".enable", false)))
                list.push(k)
        }
        const extra = Config.getNestedValue("background.widgets.mascotInstances", {}) ?? {}
        for (const id of Object.keys(extra)) {
            const key = "mascotInstances." + id
            if (key === root.configEntryName) continue
            if (DesktopWidgetLayout.enabled(root.outputName, key,
                    Config.getNestedValue("background.widgets." + key + ".enable", false)))
                list.push(key)
        }
        return list
    }
    function _cycleAnchor(dir: int): void {
        const options = root._anchorCandidates
        if (options.length === 0) return
        const cur = options.indexOf(root.anchorWidget)
        const next = options[((cur === -1 ? 0 : cur) + dir + options.length) % options.length]
        root._setOutputValue("anchorWidget", next)
    }
    function _toggleSeat(): void {
        root._setOutputValue("anchorWidget",
            root.perched ? "" : (root._anchorCandidates[0] ?? ""))
    }

    // How deep her bounding box sinks into the anchor's. Her sprite is letterboxed
    // (PreserveAspectFit + margins) and every widget's box is padded past its ink —
    // the clock's box top sits a whole line-box above the digits. Without the sink
    // she lands on those invisible edges and reads as floating.
    readonly property real _perchSink: 0.24
    // Re-entrancy guard: Config.setNestedValues() emits the GLOBAL configChanged
    // signal synchronously, which re-enters this function via the Connections
    // below BEFORE this call frame returns. Without this flag that's unbounded
    // synchronous recursion (hit live: stack overflow across the whole shell,
    // every Config consumer, not just this widget).
    property bool _syncingAnchor: false
    function _syncToAnchor(): void {
        if (root._syncingAnchor) return
        const anchor = root._anchorItem
        if (!anchor || anchor.width <= 0 || anchor.height <= 0) return
        const sink = Math.round(root.height * root._perchSink)
        // Perch on the anchor's top edge; if that would push her off the top of
        // the screen (anchor sits near the top edge), sit on its bottom instead.
        const above = anchor.y + sink - root.height
        const nx = Math.round(root._clampX(anchor.x + (anchor.width - root.width) / 2))
        const ny = Math.round(root._clampY(above >= 0 ? above : anchor.y + anchor.height - sink))
        if (Math.round(root.x) === nx && Math.round(root.y) === ny) return
        root._syncingAnchor = true
        root._setOutputValues({ x: nx, y: ny, placementStrategy: "free" })
        // "free" mode's live x/y aren't driven by a reactive Binding (see
        // AbstractBackgroundWidget's _autoPosition gate) — force the resync
        // the same way a drag-release does, or she won't visually move.
        root.syncFreePositionFromConfig()
        root._syncingAnchor = false
    }
    // Connections, not `onHeightChanged:` — AbstractBackgroundWidget already
    // declares those handlers and a redeclaration here would shadow them.
    Connections {
        target: root
        function on_AnchorItemChanged() { root._syncToAnchor() }
        function onWidthChanged() { root._syncToAnchor() }
        function onHeightChanged() { root._syncToAnchor() }
        function on_ResizePreviewValuesChanged() { root._syncMascotContentSize() }
        function on_IsResizingChanged() { root._syncMascotContentSize() }
    }
    Connections {
        target: root._anchorItem
        enabled: root._anchorItem !== null
        function onXChanged() { root._syncToAnchor() }
        function onYChanged() { root._syncToAnchor() }
        function onWidthChanged() { root._syncToAnchor() }
        function onHeightChanged() { root._syncToAnchor() }
    }
    // Anchor identity lives in config; the sibling it points at may only appear
    // later (its loader activates on the next revision), so re-resolve on both.
    Connections {
        target: Config
        function onConfigChanged() {
            root._syncMascotContentSize()
            root._resolveAnchorItem()
            root._syncToAnchor()
        }
    }
    // Deferred: the FadeLoader's `shown` binding tracks Config.revision, so a
    // synchronous Config write during instantiation re-enters that binding
    // mid-evaluation (logged as a binding loop on `shown`).
    Component.onCompleted: Qt.callLater(() => {
        root._syncMascotContentSize()
        root._resolveAnchorItem()
        root._syncToAnchor()
    })

    // Quick controls: cycle/shuffle the catalog pose right from the desktop.
    // Picking from the catalog clears a custom image on purpose.
    readonly property var _poseList: MascotCatalog.desktopWidgetSelectablePoses
    // Browse filter: art line or category. The shared catalog owns grouping so
    // Settings, every mascot instance and the full collection cannot drift.
    // Editorial/key-art scenes stay in the collection because this widget is a
    // square transparent-cutout surface. Manual-only art is visible here but
    // remains excluded from every automatic companion and chaos rotation.
    readonly property string poseFilter: root._readConfigKey("poseFilter") ?? "all"
    readonly property string posePickerMode:
        root._readConfigKey("posePickerMode") === "gallery" ? "gallery" : "buttons"
    readonly property var _poseGroups: [
        { f: "all", label: Translation.tr("All") },
        { f: "featured", label: Translation.tr("Featured") },
        { f: "pixel", label: Translation.tr("Pixel") },
        { f: "street", label: Translation.tr("Street") },
        { f: "chibi", label: Translation.tr("Chibi") },
        { f: "loops", label: Translation.tr("Loops") },
        { f: "manual", label: Translation.tr("Manual") }
    ]
    readonly property var _filteredPoses:
        MascotCatalog.desktopWidgetPosesForGroup(root.poseFilter)
    function _setFilter(f: string): void {
        Config.setNestedValue(root._configPath + ".poseFilter", f)
        // Land inside the new category right away so the choice is visible
        Qt.callLater(() => {
            if (root._filteredPoses.length > 0 && !root._filteredPoses.includes(root.pose))
                root._setPose(root._filteredPoses[0])
        })
    }
    function _setPosePickerMode(mode: string): void {
        Config.setNestedValue(root._configPath + ".posePickerMode",
            mode === "gallery" ? "gallery" : "buttons")
    }
    function _poseLabel(value: var): string {
        return MascotCatalog.displayName(String(value ?? ""))
    }
    function _poseSource(value: var): string {
        return MascotCatalog.ready ? MascotCatalog.sourceFor(String(value ?? "")) : ""
    }
    readonly property string _effectivePose: root._poseList.includes(root.pose)
        ? root.pose
        : (root._poseList[0] ?? "presence-idle-loop")
    function _setPose(next: string): void {
        const updates = {}
        updates[root._configPath + ".pose"] = next
        updates[root._configPath + ".customPath"] = ""
        Config.setNestedValues(updates)
    }
    function _cyclePose(dir: int): void {
        const list = root._filteredPoses.length > 0 ? root._filteredPoses : root._poseList
        if (list.length === 0) return
        const current = list.indexOf(root.pose)
        if (current === -1) {
            root._setPose(dir < 0 ? list[list.length - 1] : list[0])
            return
        }
        root._setPose(list[(current + dir + list.length) % list.length])
    }
    function _shufflePose(): void {
        const list = root._filteredPoses.length > 0 ? root._filteredPoses : root._poseList
        if (list.length === 0) return
        if (list.length === 1) {
            root._setPose(list[0])
            return
        }
        let next = root.pose
        while (next === root.pose)
            next = list[Math.floor(Math.random() * list.length)]
        root._setPose(next)
    }
    // Copy this widget into a new independent instance, offset so both stay
    // visible. The copy always starts free-floating: two widgets perched on
    // the same anchor would overlap exactly.
    function _duplicateWidget(): void {
        const cfg = Config.getNestedValue(root._configPath, {}) ?? {}
        const copy = JSON.parse(JSON.stringify(cfg))
        copy.enable = true
        copy.anchorWidget = ""
        copy.placementStrategy = "free"
        copy.x = Math.round(root._clampX(root.x + 48))
        copy.y = Math.round(root._clampY(root.y + 48))
        Config.addMascotInstance(copy)
    }

    editPopoverContent: Component {
        ColumnLayout {
            id: mascotQuickControls
            property bool browserOpen: false
            spacing: 6

            onVisibleChanged: if (!visible) browserOpen = false

            RowLayout {
                Layout.preferredWidth: Math.min(344, root.scaledScreenWidth - 48)
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 62
                    radius: Appearance.rounding.verysmall
                    color: Appearance.colors.colLayer2
                    border.width: 1
                    border.color: Appearance.colors.colOutlineVariant
                    clip: true

                    AnimatedImage {
                        anchors.fill: parent
                        anchors.margins: 3
                        source: root.customPath.length > 0
                            ? (root.customPath.startsWith("file://")
                                ? root.customPath : "file://" + root.customPath)
                            : root._poseSource(root._effectivePose)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        sourceSize.width: 128
                        sourceSize.height: 160
                        playing: false
                        cache: true
                        smooth: true
                        mipmap: true
                        antialiasing: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        Layout.fillWidth: true
                        text: root.customPath.length > 0
                            ? Translation.tr("Custom image")
                            : root._poseLabel(root.pose)
                        color: Appearance.colors.colOnLayer2
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        wrapMode: Text.NoWrap
                        elide: Text.ElideMiddle
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Available") + ": "
                            + root._filteredPoses.length
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.NoWrap
                    }
                }

                Row {
                    spacing: 2
                    SelectionGroupButton {
                        width: 32; height: 32
                        horizontalPadding: 6
                        verticalPadding: 5
                        leftmost: true; rightmost: true
                        buttonIcon: "chevron_left"
                        onClicked: root._cyclePose(-1)
                        StyledToolTip { text: Translation.tr("Previous") }
                    }
                    SelectionGroupButton {
                        width: 32; height: 32
                        horizontalPadding: 6
                        verticalPadding: 5
                        leftmost: true; rightmost: true
                        buttonIcon: "casino"
                        onClicked: root._shufflePose()
                        StyledToolTip { text: Translation.tr("Shuffle") }
                    }
                    SelectionGroupButton {
                        width: 32; height: 32
                        horizontalPadding: 6
                        verticalPadding: 5
                        leftmost: true; rightmost: true
                        buttonIcon: "chevron_right"
                        onClicked: root._cyclePose(1)
                        StyledToolTip { text: Translation.tr("Next") }
                    }
                }
            }

            Flow {
                Layout.preferredWidth: Math.min(344, root.scaledScreenWidth - 48)
                Layout.preferredHeight: childrenRect.height
                spacing: 3

                Repeater {
                    model: root._poseGroups
                    SelectionGroupButton {
                        required property var modelData
                        height: 30
                        horizontalPadding: 8
                        verticalPadding: 4
                        enableImplicitWidthAnimation: false
                        leftmost: true
                        rightmost: true
                        toggled: root.poseFilter === modelData.f
                        buttonText: modelData.label
                        onClicked: root._setFilter(modelData.f)
                    }
                }

                SelectionGroupButton {
                    width: 34; height: 30
                    horizontalPadding: 6
                    verticalPadding: 4
                    leftmost: true; rightmost: true
                    toggled: mascotQuickControls.browserOpen
                    buttonIcon: mascotQuickControls.browserOpen
                        ? "expand_less" : "grid_view"
                    onClicked: mascotQuickControls.browserOpen
                        = !mascotQuickControls.browserOpen
                    StyledToolTip {
                        text: mascotQuickControls.browserOpen
                            ? Translation.tr("Hide gallery")
                            : Translation.tr("Browse poses")
                    }
                }
            }

            RowLayout {
                visible: mascotQuickControls.browserOpen
                Layout.preferredWidth: Math.min(344, root.scaledScreenWidth - 48)
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    text: root.posePickerMode === "gallery"
                        ? Translation.tr("Gallery") : Translation.tr("Buttons")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }

                SelectionGroupButton {
                    width: 32; height: 28
                    horizontalPadding: 6
                    verticalPadding: 3
                    leftmost: true; rightmost: false
                    toggled: root.posePickerMode === "buttons"
                    buttonIcon: "view_list"
                    onClicked: root._setPosePickerMode("buttons")
                    StyledToolTip { text: Translation.tr("Buttons") }
                }
                SelectionGroupButton {
                    width: 32; height: 28
                    horizontalPadding: 6
                    verticalPadding: 3
                    leftmost: false; rightmost: true
                    toggled: root.posePickerMode === "gallery"
                    buttonIcon: "grid_view"
                    onClicked: root._setPosePickerMode("gallery")
                    StyledToolTip { text: Translation.tr("Gallery") }
                }
            }
            Rectangle {
                id: posePickerViewport
                visible: mascotQuickControls.browserOpen
                Layout.preferredWidth: Math.min(344, root.scaledScreenWidth - 48)
                Layout.preferredHeight: root.posePickerMode === "gallery" ? 224 : 168
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant

                GridView {
                    id: quickPoseButtons
                    anchors.fill: parent
                    anchors.margins: 6
                    visible: root.posePickerMode === "buttons"
                    clip: true
                    model: visible ? root._filteredPoses : []
                    cellWidth: Math.max(1, Math.floor(width / 2))
                    cellHeight: 36
                    cacheBuffer: cellHeight * 4
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: Math.max(0, root._filteredPoses.indexOf(root.pose))
                    onCurrentIndexChanged: {
                        if (visible && currentIndex >= 0)
                            Qt.callLater(() => positionViewAtIndex(currentIndex, GridView.Contain))
                    }

                    delegate: Item {
                        id: poseButtonCell
                        required property var modelData
                        required property int index
                        width: quickPoseButtons.cellWidth
                        height: quickPoseButtons.cellHeight
                        readonly property bool selected: String(modelData) === root.pose

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: Appearance.rounding.verysmall
                            color: poseButtonCell.selected
                                ? Appearance.colors.colPrimaryContainer
                                : poseButtonMouse.containsMouse
                                    ? Appearance.colors.colLayer2Hover : "transparent"
                            border.width: poseButtonCell.selected ? 2 : 1
                            border.color: poseButtonCell.selected
                                ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

                            StyledText {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                text: root._poseLabel(poseButtonCell.modelData)
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.NoWrap
                                elide: Text.ElideMiddle
                                color: poseButtonCell.selected
                                    ? Appearance.colors.colOnPrimaryContainer
                                    : Appearance.colors.colOnLayer2
                            }

                            MouseArea {
                                id: poseButtonMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root._setPose(String(poseButtonCell.modelData))
                            }
                        }
                    }
                }

                GridView {
                    id: quickPoseGallery
                    anchors.fill: parent
                    anchors.margins: 6
                    visible: root.posePickerMode === "gallery"
                    clip: true
                    model: visible ? root._filteredPoses : []
                    cellWidth: Math.max(1, Math.floor(width / 3))
                    cellHeight: 138
                    cacheBuffer: cellHeight * 2
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: Math.max(0, root._filteredPoses.indexOf(root.pose))
                    onCurrentIndexChanged: {
                        if (visible && currentIndex >= 0)
                            Qt.callLater(() => positionViewAtIndex(currentIndex, GridView.Contain))
                    }

                    delegate: Item {
                        id: poseCell
                        required property var modelData
                        required property int index
                        width: quickPoseGallery.cellWidth
                        height: quickPoseGallery.cellHeight
                        readonly property bool selected: String(modelData) === root.pose

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 3
                            radius: Appearance.rounding.verysmall
                            color: poseCell.selected
                                ? Appearance.colors.colPrimaryContainer
                                : poseHover.hovered ? Appearance.colors.colLayer2Hover : "transparent"
                            border.width: poseCell.selected ? 2 : 1
                            border.color: poseCell.selected
                                ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

                            AnimatedImage {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    bottom: poseLabel.top
                                    margins: 7
                                    bottomMargin: 3
                                }
                                source: root._poseSource(poseCell.modelData)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                sourceSize.width: 256
                                sourceSize.height: 320
                                playing: poseCell.selected && Appearance.animationsEnabled
                                cache: true
                                smooth: true
                                mipmap: true
                                antialiasing: true
                            }

                            StyledText {
                                id: poseLabel
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    bottom: parent.bottom
                                    leftMargin: 6
                                    rightMargin: 6
                                    bottomMargin: 5
                                }
                                height: 18
                                text: root._poseLabel(poseCell.modelData)
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.NoWrap
                                elide: Text.ElideMiddle
                                color: poseCell.selected
                                    ? Appearance.colors.colOnPrimaryContainer
                                    : Appearance.colors.colSubtext
                            }

                            HoverHandler { id: poseHover }
                            TapHandler {
                                onTapped: root._setPose(String(poseCell.modelData))
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    width: 3
                    radius: width / 2
                    visible: quickPoseButtons.visible
                        && quickPoseButtons.visibleArea.heightRatio < 1
                    height: Math.max(24,
                        quickPoseButtons.height * quickPoseButtons.visibleArea.heightRatio)
                    y: quickPoseButtons.y + quickPoseButtons.visibleArea.yPosition
                        * Math.max(0, quickPoseButtons.height - height)
                    color: Appearance.colors.colPrimary
                    opacity: 0.45
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    width: 3
                    radius: width / 2
                    visible: quickPoseGallery.visible
                        && quickPoseGallery.visibleArea.heightRatio < 1
                    height: Math.max(24,
                        quickPoseGallery.height * quickPoseGallery.visibleArea.heightRatio)
                    y: quickPoseGallery.y + quickPoseGallery.visibleArea.yPosition
                        * Math.max(0, quickPoseGallery.height - height)
                    color: Appearance.colors.colPrimary
                    opacity: 0.45
                }
            }
            RowLayout {
                Layout.preferredWidth: Math.min(344, root.scaledScreenWidth - 48)
                spacing: 4

                Row {
                    visible: root._anchorCandidates.length > 0
                    spacing: 2

                    SelectionGroupButton {
                        width: 30; height: 30
                        horizontalPadding: 5
                        verticalPadding: 4
                        leftmost: true; rightmost: true
                        enabled: root.perched
                        buttonIcon: "chevron_left"
                        onClicked: root._cycleAnchor(-1)
                    }
                    SelectionGroupButton {
                        height: 30
                        horizontalPadding: 8
                        verticalPadding: 4
                        leftmost: true; rightmost: true
                        toggled: root.perched
                        buttonIcon: "chair"
                        buttonText: root.perched
                            ? Translation.tr("Seated") : Translation.tr("Free")
                        onClicked: root._toggleSeat()
                    }
                    SelectionGroupButton {
                        width: 30; height: 30
                        horizontalPadding: 5
                        verticalPadding: 4
                        leftmost: true; rightmost: true
                        enabled: root.perched
                        buttonIcon: "chevron_right"
                        onClicked: root._cycleAnchor(1)
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.NoWrap
                    elide: Text.ElideMiddle
                    text: root.perched
                        ? (Translation.tr("Perched on") + " "
                            + root.anchorWidget.split(".").pop())
                        : Translation.tr("Free-floating")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }

                SelectionGroupButton {
                    width: 32; height: 30
                    horizontalPadding: 6
                    verticalPadding: 4
                    leftmost: true; rightmost: true
                    buttonIcon: "content_copy"
                    onClicked: root._duplicateWidget()
                    StyledToolTip { text: Translation.tr("Duplicate") }
                }
            }
        }
    }

    // MascotCatalog parses the manifest once for every surface and instance.
    // Keeping that ownership shared avoids one watched FileView per duplicate.

    // Click ladder: pokes escalate through the same manifest pose tiers as
    // the live companion (annoyed → pats → rage), reverting after a moment.
    // With a custom image the ladder is hers no more — clicks just poke the
    // companion instead.
    property string _reactPose: ""
    property int _clicks: 0
    Timer { id: _reactRevert; interval: 6000; onTriggered: root._reactPose = "" }
    Timer { id: _clickReset; interval: 1600; onTriggered: root._clicks = 0 }
    function _reactToClick(): void {
        root._clicks++
        _clickReset.restart()
        const tiers = MascotCatalog.clickTiers ?? ({})
        const tier = root._clicks >= 4 ? tiers.tier4 : (root._clicks >= 2 ? tiers.tier2 : tiers.tier1)
        const pool = tier?.poses ?? ["hand-on-hip"]
        root._reactPose = pool[Math.floor(Math.random() * pool.length)]
        _reactRevert.restart()
    }

    // Card chrome is off by default — she's a cutout living on the desktop.
    // Users can turn the card back on from the widget manager / settings.
    WidgetSurface {
        regionBrightness: root.regionBrightness
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.widgetCardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.widgetSurfaceInk
        colorMode: root.colorMode
        surfaceAccent: root.widgetAccent3
        surfaceFill: root.widgetPlateColor
        surfaceUseBlur: root.effectiveBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur
    }

    AnimatedImage {
        id: sprite
        anchors.fill: parent
        anchors.margins: Math.round(6 * root.scaleFactor)
        source: {
            if (root.customPath.length > 0)
                return root.customPath.startsWith("file://") ? root.customPath : "file://" + root.customPath
            if (!MascotCatalog.ready) return ""
            const p = root._reactPose.length > 0 ? root._reactPose : root._effectivePose
            return MascotCatalog.sourceFor(p)
        }
        playing: root.powerActive && Appearance.animationsEnabled
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        // Desktop widgets are freely resized and commonly minify 400-640 px
        // source art. High-quality filtering avoids the serrated street line
        // and the uneven shimmer that `smooth: false` produced while dragging.
        smooth: true
        mipmap: true
        antialiasing: true

        // Custom images render regardless of the mascot switch; catalog
        // poses stay gated behind it
        visible: (root.customPath.length > 0 || Boolean(root._readConfigKey("enable") ?? false)) && status !== Image.Error
    }
    MaterialSymbol {
        anchors.centerIn: parent
        visible: !sprite.visible
        text: "pets"
        iconSize: Math.round(42 * root.scaleFactor)
        color: root.widgetInk
    }

    // Tapping her reacts locally (pose ladder); custom images poke the
    // live companion instead
    TapHandler {
        enabled: !GlobalStates.widgetEditMode && sprite.visible
        onTapped: {
            if (root.customPath.length > 0) {
                Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "mascot", "poke"])
            } else {
                root._reactToClick()
            }
        }
    }
}
