pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import "root:"

Item {
    id: root
    implicitHeight: column.implicitHeight

    property bool animateIn: false

    // Exposed so WidgetsView / SwipeView can block swiping early
    property bool dragPending: false

    property var widgetOrder: {
        const saved = Config.options?.sidebar?.widgets?.widgetOrder
        if (!saved) return defaultOrder
        const missing = defaultOrder.filter(id => !saved.includes(id))
        return [...saved, ...missing]
    }
    readonly property var defaultOrder: ["media", "week", "context", "note", "launch", "controls", "status", "crypto", "wallpaper"]
    readonly property int widgetSpacing: Config.options?.sidebar?.widgets?.spacing ?? 8

    readonly property bool showMedia: Config.options?.sidebar?.widgets?.media ?? true
    readonly property bool showWeek: Config.options?.sidebar?.widgets?.week ?? true
    readonly property bool showContext: Config.options?.sidebar?.widgets?.context ?? true
    readonly property bool showNote: Config.options?.sidebar?.widgets?.note ?? true
    readonly property bool showLaunch: Config.options?.sidebar?.widgets?.launch ?? true
    readonly property bool showControls: Config.options?.sidebar?.widgets?.controls ?? true
    readonly property bool showStatus: Config.options?.sidebar?.widgets?.status ?? true
    readonly property bool showCrypto: Config.options?.sidebar?.widgets?.crypto ?? false
    readonly property bool showWallpaper: Config.options?.sidebar?.widgets?.wallpaper ?? false

    readonly property var visibleWidgets: {
        const order = widgetOrder ?? defaultOrder
        return order.filter(id => {
            switch (id) {
            case "media": return showMedia
            case "week": return showWeek
            case "context": return showContext
            case "note": return showNote
            case "launch": return showLaunch
            case "controls": return showControls
            case "status": return showStatus
            case "crypto": return showCrypto
            case "wallpaper": return showWallpaper
            default: return false
            }
        })
    }

    // ─── Drag state ──────────────────────────────────────────────────────
    property int dragIndex: -1
    property int hoverIndex: -1
    property bool editMode: false
    property real dragStartY: 0
    property real dragCurrentY: 0
    property var _itemHeights: []

    function _cacheItemHeights(): void {
        const heights = []
        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i)
            heights.push(item && item.visible ? item.height : 0)
        }
        _itemHeights = heights
    }

    function getDisplacementY(itemIndex: int): real {
        if (!editMode || dragIndex < 0 || hoverIndex < 0) return 0
        if (itemIndex === dragIndex) return 0

        if (dragIndex < hoverIndex) {
            if (itemIndex > dragIndex && itemIndex <= hoverIndex) {
                const h = _itemHeights[dragIndex] ?? 0
                return -(h + column.spacing)
            }
        } else if (dragIndex > hoverIndex) {
            if (itemIndex >= hoverIndex && itemIndex < dragIndex) {
                const h = _itemHeights[dragIndex] ?? 0
                return h + column.spacing
            }
        }
        return 0
    }

    // Pixel offset the dragged widget should move to follow the cursor
    function getDragFollowY(): real {
        if (!editMode || dragIndex < 0) return 0
        return dragCurrentY - dragStartY
    }

    function moveWidget(fromIdx: int, toIdx: int): void {
        if (fromIdx === toIdx || fromIdx < 0 || toIdx < 0) return
        const fromId = visibleWidgets[fromIdx]
        const toId = visibleWidgets[toIdx]

        let newOrder = [...(widgetOrder ?? defaultOrder)]
        const realFrom = newOrder.indexOf(fromId)
        const realTo = newOrder.indexOf(toId)

        newOrder.splice(realFrom, 1)
        newOrder.splice(realTo, 0, fromId)

        Config.setNestedValue("sidebar.widgets.widgetOrder", newOrder)
    }

    function startDrag(index: int, mouseY: real): void {
        _cacheItemHeights()
        dragIndex = index
        hoverIndex = index
        dragStartY = mouseY
        dragCurrentY = mouseY
        editMode = true
        dragPending = false // Now fully in drag mode
    }

    function updateDrag(mouseY: real): void {
        if (dragIndex < 0) return
        dragCurrentY = mouseY

        let accY = 0
        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i)
            if (!item || !item.visible) continue
            const itemCenter = accY + item.height / 2
            if (mouseY < itemCenter) {
                hoverIndex = i
                return
            }
            accY += item.height + column.spacing
        }
        hoverIndex = repeater.count - 1
    }

    function endDrag(): void {
        if (dragIndex >= 0 && hoverIndex >= 0 && dragIndex !== hoverIndex) {
            moveWidget(dragIndex, hoverIndex)
        }
        _resetDrag()
    }

    function cancelDrag(): void {
        _resetDrag()
    }

    function _resetDrag(): void {
        dragIndex = -1
        hoverIndex = -1
        editMode = false
        dragPending = false
        dragStartY = 0
        dragCurrentY = 0
        _itemHeights = []
    }

    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged() {
            if (!GlobalStates.sidebarLeftOpen) {
                root.cancelDrag()
            }
        }
    }

    ColumnLayout {
        id: column
        width: parent.width
        spacing: root.widgetSpacing

        Repeater {
            id: repeater
            model: root.visibleWidgets

            delegate: Item {
                id: widgetWrapper
                required property string modelData
                required property int index

                Layout.fillWidth: true
                Layout.preferredHeight: contentLoader.item?.implicitHeight ?? 0
                Layout.leftMargin: needsMargin ? 12 : 0
                Layout.rightMargin: needsMargin ? 12 : 0
                visible: Layout.preferredHeight > 0

                readonly property bool needsMargin: ["context", "note", "media", "crypto", "wallpaper"].includes(modelData)
                readonly property bool isBeingDragged: root.dragIndex === index
                readonly property bool isDropTarget: root.hoverIndex === index && root.dragIndex !== index && root.dragIndex >= 0
                readonly property real displacementY: root.getDisplacementY(index)
                readonly property real dragFollowY: root.getDragFollowY()

                // ─── Staggered entrance animation ────────────────────
                readonly property int staggerDelay: 45
                property bool animatedIn: false

                onVisibleChanged: if (!visible) animatedIn = false

                Timer {
                    id: staggerTimer
                    interval: widgetWrapper.index * widgetWrapper.staggerDelay + 20
                    running: root.animateIn && !widgetWrapper.animatedIn
                    onTriggered: widgetWrapper.animatedIn = true
                }

                opacity: animatedIn ? 1 : 0
                scale: animatedIn ? 1 : 0.96
                transformOrigin: Item.Center

                // Combine entrance, displacement and drag-follow transforms
                transform: Translate {
                    y: {
                        if (!widgetWrapper.animatedIn) return 24
                        if (widgetWrapper.isBeingDragged) return widgetWrapper.dragFollowY
                        return widgetWrapper.displacementY
                    }

                    Behavior on y {
                        enabled: Appearance.animationsEnabled && !widgetWrapper.isBeingDragged
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }
                Behavior on scale {
                    enabled: Appearance.animationsEnabled && !widgetWrapper.isBeingDragged
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                // ─── Drop indicator bar (tri-style aware) ────────────
                Rectangle {
                    id: dropGhostTop
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: -root.widgetSpacing / 2 - height / 2
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    height: 3
                    radius: 1.5
                    color: Appearance.inirEverywhere ? Appearance.inir.colPrimary
                         : Appearance.colors.colPrimary
                    opacity: widgetWrapper.isDropTarget && root.hoverIndex < root.dragIndex ? 0.85 : 0
                    visible: opacity > 0
                    z: 10

                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }

                    // Subtle glow (hidden in inir style)
                    Rectangle {
                        visible: !Appearance.inirEverywhere
                        anchors.centerIn: parent
                        width: parent.width + 6
                        height: 10
                        radius: 5
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.82)
                        z: -1
                    }
                }

                Rectangle {
                    id: dropGhostBottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -root.widgetSpacing / 2 - height / 2
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    height: 3
                    radius: 1.5
                    color: Appearance.inirEverywhere ? Appearance.inir.colPrimary
                         : Appearance.colors.colPrimary
                    opacity: widgetWrapper.isDropTarget && root.hoverIndex > root.dragIndex ? 0.85 : 0
                    visible: opacity > 0
                    z: 10

                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        visible: !Appearance.inirEverywhere
                        anchors.centerIn: parent
                        width: parent.width + 6
                        height: 10
                        radius: 5
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.82)
                        z: -1
                    }
                }

                // ─── Content + visual feedback ───────────────────────
                Item {
                    id: contentContainer
                    anchors.fill: parent

                    // Elevated shadow when dragging
                    StyledRectangularShadow {
                        target: contentLoader
                        anchors.fill: contentLoader
                        opacity: widgetWrapper.isBeingDragged ? 0.6 : 0
                        blur: 28
                        spread: 0.18
                        color: Appearance.colors.colShadow

                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                        }
                    }

                    Loader {
                        id: contentLoader
                        width: parent.width

                        // Visual feedback when dragging
                        scale: widgetWrapper.isBeingDragged ? 1.02 : 1
                        opacity: widgetWrapper.isBeingDragged ? 0.9
                               : (root.editMode && !widgetWrapper.isDropTarget ? 0.65 : 1)

                        Behavior on scale {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                        }
                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }

                        sourceComponent: {
                            switch (widgetWrapper.modelData) {
                            case "media": return mediaWidget
                            case "week": return weekWidget
                            case "context": return contextWidget
                            case "note": return noteWidget
                            case "launch": return launchWidget
                            case "controls": return controlsWidget
                            case "status": return statusWidget
                            case "crypto": return cryptoWidget
                            case "wallpaper": return wallpaperWidget
                            default: return null
                            }
                        }
                    }

                    // Accent tint overlay when dragging (tri-style)
                    Rectangle {
                        anchors.fill: contentLoader
                        radius: contentLoader.item?.radius ?? Appearance.rounding.small
                        color: Appearance.inirEverywhere ? Appearance.inir.colPrimary
                             : Appearance.colors.colPrimary
                        opacity: widgetWrapper.isBeingDragged ? 0.05 : 0

                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: 180 }
                        }
                    }

                    // Selection border when dragging (tri-style)
                    Rectangle {
                        anchors.fill: contentLoader
                        radius: contentLoader.item?.radius ?? Appearance.rounding.small
                        color: "transparent"
                        border.width: widgetWrapper.isBeingDragged ? 1.5 : 0
                        border.color: Appearance.inirEverywhere
                            ? Appearance.inir.colBorderFocus
                            : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.4)

                        Behavior on border.width {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: 180 }
                        }
                    }

                    // ─── Drag handle: small grip button (top-right) ──
                    // Only covers a tiny area so widget content is never blocked.
                    // Appears on hover over the widget; always visible in edit mode.
                    Rectangle {
                        id: dragHandle
                        anchors.top: contentLoader.top
                        anchors.right: contentLoader.right
                        anchors.topMargin: 4
                        anchors.rightMargin: 4
                        width: 30
                        height: 22
                        radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall
                              : Appearance.rounding.verysmall
                        z: 10

                        color: handleMouseArea.containsMouse || widgetWrapper.isBeingDragged
                            ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                               : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
                               : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                               : Appearance.colors.colLayer1Hover)
                            : ColorUtils.transparentize(
                                Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                    : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                                    : Appearance.colors.colLayer1, 0.15)

                        border.width: Appearance.inirEverywhere ? 1 : 0
                        border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"

                        opacity: (handleHoverDetector.containsMouse || root.editMode) ? 1 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: 120 }
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "drag_indicator"
                            iconSize: 14
                            color: handleMouseArea.containsMouse || widgetWrapper.isBeingDragged
                                ? (Appearance.inirEverywhere ? Appearance.inir.colOnLayer1
                                    : Appearance.colors.colOnLayer1)
                                : (Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
                                    : Appearance.colors.colSubtext)
                        }

                        MouseArea {
                            id: handleMouseArea
                            anchors.fill: parent
                            anchors.margins: -3 // Slightly larger hit area
                            z: 20
                            hoverEnabled: true
                            cursorShape: root.editMode && root.dragIndex === widgetWrapper.index
                                ? Qt.ClosedHandCursor
                                : Qt.OpenHandCursor
                            acceptedButtons: Qt.LeftButton

                            property real pressY: 0
                            property bool dragStarted: false

                            onPressed: (mouse) => {
                                dragStarted = false
                                pressY = mapToItem(column, mouse.x, mouse.y).y
                                root.dragPending = true
                                handleDragStartTimer.restart()
                            }

                            onPositionChanged: (mouse) => {
                                if (root.editMode && root.dragIndex === widgetWrapper.index) {
                                    const globalY = mapToItem(column, mouse.x, mouse.y).y
                                    root.updateDrag(globalY)
                                } else if (!dragStarted) {
                                    const globalY = mapToItem(column, mouse.x, mouse.y).y
                                    if (Math.abs(globalY - pressY) > 5) {
                                        handleDragStartTimer.stop()
                                        dragStarted = true
                                        root.startDrag(widgetWrapper.index, globalY)
                                    }
                                }
                            }

                            onReleased: {
                                handleDragStartTimer.stop()
                                if (root.editMode) {
                                    root.endDrag()
                                }
                                dragStarted = false
                                root.dragPending = false
                            }

                            onCanceled: {
                                handleDragStartTimer.stop()
                                if (root.editMode) {
                                    root.cancelDrag()
                                }
                                dragStarted = false
                                root.dragPending = false
                            }

                            Timer {
                                id: handleDragStartTimer
                                interval: 150
                                onTriggered: {
                                    handleMouseArea.dragStarted = true
                                    const globalY = handleMouseArea.mapToItem(column, handleMouseArea.mouseX, handleMouseArea.mouseY).y
                                    root.startDrag(widgetWrapper.index, globalY)
                                }
                            }
                        }
                    }

                    // Hover detector covering the whole widget to reveal the grip button
                    HoverHandler {
                        id: handleHoverDetector
                    }
                }

                // ─── Long press to drag (fallback, behind content) ───
                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    z: -1
                    acceptedButtons: Qt.LeftButton

                    property bool longPressTriggered: false
                    property real pressY: 0

                    onWheel: (wheel) => wheel.accepted = false

                    onPressed: (mouse) => {
                        longPressTriggered = false
                        pressY = mapToItem(column, mouse.x, mouse.y).y
                        longPressTimer.restart()
                    }

                    onPositionChanged: (mouse) => {
                        if (root.editMode && root.dragIndex === widgetWrapper.index) {
                            const globalY = mapToItem(column, mouse.x, mouse.y).y
                            root.updateDrag(globalY)
                        } else if (!longPressTriggered) {
                            const globalY = mapToItem(column, mouse.x, mouse.y).y
                            if (Math.abs(globalY - pressY) > 10) {
                                longPressTimer.stop()
                            }
                        }
                    }

                    onReleased: {
                        longPressTimer.stop()
                        if (root.editMode) {
                            root.endDrag()
                        }
                        longPressTriggered = false
                    }

                    onCanceled: {
                        longPressTimer.stop()
                        if (root.editMode) {
                            root.cancelDrag()
                        }
                        longPressTriggered = false
                    }

                    Timer {
                        id: longPressTimer
                        interval: 300
                        onTriggered: {
                            dragArea.longPressTriggered = true
                            const globalY = dragArea.mapToItem(column, dragArea.mouseX, dragArea.mouseY).y
                            root.startDrag(widgetWrapper.index, globalY)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: mediaWidget
        MediaPlayerWidget {}
    }
    Component {
        id: weekWidget
        WeekStrip {}
    }
    Component {
        id: contextWidget
        ContextCard {}
    }
    Component {
        id: noteWidget
        QuickNote {}
    }
    Component {
        id: launchWidget
        QuickLaunch {}
    }
    Component {
        id: controlsWidget
        ControlsCard {}
    }
    Component {
        id: statusWidget
        StatusRings {}
    }
    Component {
        id: cryptoWidget
        CryptoWidget {}
    }
    Component {
        id: wallpaperWidget
        QuickWallpaper {}
    }
}
