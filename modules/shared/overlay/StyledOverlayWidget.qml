pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// One tool on the bench. A tool hands its face as `contentItem` (anchored to fill its holder); this gives it the rest:
// the header (glyph, title, one live fact, its own action, pin, close), the pinned footer (background, clickable), the
// plate, a move that snaps to the screen's edges and centre and to the other tools with guides (Esc puts it back),
// resizing from every edge, raise on touch, and the HUD it keeps when pinned and the bench closes: same place, the
// header gone, the plate closing in on the content, which never moves.
//
// A new tool: a folder with <Tool>.qml on this base, an entry in OverlayContext.availableWidgets, its state in
// Persistent.states.overlay (x/y -1: the bench finds it a free place), a DelegateChoice in OverlayWidgetDelegateChooser.
Item {
    id: root

    required property Item contentItem
    required property var modelData
    readonly property string identifier: root.modelData.identifier
    readonly property string materialSymbol: root.modelData.materialSymbol ?? "widgets"
    property string title: Translation.tr(root.modelData.title ?? root.identifier)
    // One live fact beside the title (a level, a timer); empty: none.
    property string fact: ""
    property color factColor: OverlayLook.colSubtext
    property string titlebarActionSymbol: ""
    property string titlebarActionTooltip: ""
    signal titlebarActionClicked()
    property bool showCenterButton: false
    property bool showClickabilityButton: true
    property bool resizable: true
    // false: once pinned only the content shows, no plate (the crosshair).
    property bool hudPlate: true
    // false: a pinned click-through tool keeps its full opacity (the crosshair has its own).
    property bool hudFades: true
    property real panelOpacityOverride: -1
    property real minimumWidth: root.contentItem.implicitWidth
    property real minimumHeight: root.contentItem.implicitHeight

    readonly property var persistentStateEntry: Persistent.states.overlay[root.identifier]
    readonly property bool pinned: root.persistentStateEntry?.pinned ?? false
    readonly property bool clickthrough: root.persistentStateEntry?.clickthrough ?? true
    readonly property bool benchOpen: GlobalStates.overlayOpen
    property bool dismissing: false
    readonly property bool actuallyPinned: root.pinned && !root.dismissing
    readonly property bool actuallyClickable: root.actuallyPinned && !root.clickthrough

    // Geometry. x/y are the grab band's corner (what is saved), width/height the content's.
    readonly property real d: OverlayLook.d
    readonly property real resizeMargin: 8
    readonly property real padding: Math.round(10 * root.d)
    readonly property real plateRadius: OverlayLook.plateRadius
    readonly property real contentRadius: Math.max(4, root.plateRadius - root.padding)
    readonly property real headerHeight: Math.round(44 * root.d)
    // The pinned footer only when it holds something (the crosshair has neither control).
    property real footerT: root.pinned && (root.hudPlate || root.showClickabilityButton) ? 1 : 0
    Behavior on footerT { NumberAnimation { duration: FamilyStyle.morphDuration; easing.type: Easing.OutCubic } }
    readonly property real footerHeight: Math.round(root.footerT * 44 * root.d)
    readonly property real canvasW: root.parent ? root.parent.width : 0
    readonly property real canvasH: root.parent ? root.parent.height : 0
    readonly property real chromeW: 2 * (root.resizeMargin + root.padding)
    readonly property real chromeH: 2 * root.resizeMargin + root.headerHeight + root.padding + root.footerHeight
    // A tool that doesn't resize is always its content's size, whatever was saved before.
    readonly property real contentW: Math.round(root.resizing ? root.liveW : root.fitW(root.resizable ? (root.persistentStateEntry?.width ?? 0) : 0))
    readonly property real contentH: Math.round(root.resizing ? root.liveH : root.fitH(root.resizable ? (root.persistentStateEntry?.height ?? 0) : 0))
    function fitW(w: real): real { return Math.max(root.minimumWidth, root.canvasW > 0 ? Math.min(w, root.canvasW - root.chromeW) : w) }
    function fitH(h: real): real { return Math.max(root.minimumHeight, root.canvasH > 0 ? Math.min(h, root.canvasH - root.chromeH) : h) }
    // The plate as it stands on the bench, in canvas pixels.
    readonly property real plateX: root.x + root.resizeMargin
    readonly property real plateY: root.y + root.resizeMargin
    readonly property real plateW: root.width - 2 * root.resizeMargin
    readonly property real plateH: root.height - 2 * root.resizeMargin
    // What a pinned, clickable tool takes from the screen once the bench closes.
    readonly property real hudX: root.plateX
    readonly property real hudY: root.plateY + root.headerHeight - root.padding
    readonly property real hudW: root.plateW
    readonly property real hudH: root.contentH + 2 * root.padding

    implicitWidth: root.contentW + root.chromeW
    implicitHeight: root.contentH + root.chromeH
    width: root.implicitWidth
    height: root.implicitHeight

    property bool moving: false
    property bool resizing: false
    property bool settled: false
    property bool putBack: false
    property real liveX: 0
    property real liveY: 0
    property real liveW: 0
    property real liveH: 0
    property var _start: ({})
    readonly property real placedX: Math.max(0, Math.min(root.persistentStateEntry?.x ?? 0, root.canvasW - root.width))
    readonly property real placedY: Math.max(0, Math.min(root.persistentStateEntry?.y ?? 0, root.canvasH - root.height))
    x: Math.round(root.moving || root.resizing ? root.liveX : root.placedX)
    y: Math.round(root.moving || root.resizing ? root.liveY : root.placedY)
    Behavior on x {
        enabled: root.settled && !root.moving && !root.resizing
        NumberAnimation { duration: FamilyStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: FamilyStyle.moveCurve }
    }
    Behavior on y {
        enabled: root.settled && !root.moving && !root.resizing
        NumberAnimation { duration: FamilyStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: FamilyStyle.moveCurve }
    }
    z: (OverlayContext.stack[root.identifier] ?? 0) + (root.moving || root.resizing ? 100000 : 0)

    // Presence: rises in when the bench opens (in the strip's order), recedes when it closes unless pinned.
    property real appear: 0
    readonly property bool wantShown: (root.benchOpen || root.actuallyPinned) && !root.dismissing
    // A tick later, so the bench's own open time is known when the stagger is chosen.
    onWantShownChanged: appearKick.restart()
    Timer { id: appearKick; interval: 0; onTriggered: root.animateAppear() }
    function animateAppear(): void {
        appearAnim.stop()
        const show = root.wantShown
        const order = Math.max(0, OverlayContext.openIds.indexOf(root.identifier))
        appearPause.duration = show && OverlayContext.justOpened() ? Math.min(120, order * 18) : 0
        appearNumber.to = show ? 1 : 0
        appearNumber.duration = show ? OverlayLook.openDuration : OverlayLook.closeDuration
        appearNumber.easing.bezierCurve = show ? FamilyStyle.emergeCurve : FamilyStyle.recedeCurve
        appearAnim.start()
    }
    SequentialAnimation {
        id: appearAnim
        PauseAnimation { id: appearPause; duration: 0 }
        NumberAnimation { id: appearNumber; target: root; property: "appear"; easing.type: Easing.BezierSpline }
        onFinished: if (root.dismissing) removeTimer.start()
    }
    // Leaves the open list after its exit, never inside the click that asked for it.
    Timer { id: removeTimer; interval: 0; onTriggered: OverlayContext.setOpen(root.identifier, false) }

    // Chrome: header and footer, there only while the bench is open.
    property real chrome: root.benchOpen ? 1 : 0
    Behavior on chrome { NumberAnimation { duration: OverlayLook.openDuration; easing.type: Easing.OutCubic } }
    readonly property real hudMorph: root.actuallyPinned ? 1 - root.chrome : 0

    // Plate opacity: the bench's on the bench, the tool's own once pinned; the footer slider previews it.
    property real previewBackground: -1
    readonly property real benchAlpha: {
        const o = Number(root.panelOpacityOverride)
        const v = isFinite(o) && o >= 0 ? o : Number(Config.options?.overlay?.backgroundOpacity ?? 0.9)
        return Math.max(0, Math.min(1, isFinite(v) ? v : 0.9))
    }
    readonly property real ownBackground: {
        const v = Number(root.persistentStateEntry?.background ?? -1)
        return isFinite(v) && v >= 0 ? Math.min(1, v) : -1
    }
    readonly property real hudAlpha: !root.hudPlate ? 0 : root.ownBackground >= 0 ? root.ownBackground : root.benchAlpha
    readonly property real plateAlpha: root.previewBackground >= 0 ? root.previewBackground
        : root.benchAlpha + (root.hudAlpha - root.benchAlpha) * root.hudMorph

    property real hudFade: root.hudFades && root.actuallyPinned && !root.benchOpen && root.clickthrough ? (Config.options?.overlay?.clickthroughOpacity ?? 0.8) : 1
    Behavior on hudFade { NumberAnimation { duration: OverlayLook.openDuration; easing.type: Easing.OutCubic } }

    visible: root.appear > 0.001
    opacity: root.appear * root.hudFade
    scale: OverlayLook.zoom ? 0.96 + 0.04 * root.appear : 1

    // Registration
    onActuallyPinnedChanged: OverlayContext.pin(root.identifier, root.actuallyPinned)
    onActuallyClickableChanged: OverlayContext.registerClickableWidget(root, root.actuallyClickable)
    Component.onCompleted: {
        OverlayContext.registerTool(root.identifier, root)
        OverlayContext.pin(root.identifier, root.actuallyPinned)
        OverlayContext.registerClickableWidget(root, root.actuallyClickable)
        appearKick.restart()
        placeTimer.start()
    }
    Component.onDestruction: {
        OverlayContext.registerClickableWidget(root, false)
        if (OverlayContext.unregisterTool(root.identifier, root))
            OverlayContext.pin(root.identifier, false)
    }
    // A tool never placed (x or y below 0) gets the first free place once its size is known.
    Timer {
        id: placeTimer
        interval: 0
        onTriggered: {
            const e = root.persistentStateEntry
            if (e && (e.x < 0 || e.y < 0) && root.canvasW > 0) {
                if (root.showCenterButton)
                    root.center()
                else
                    root.placeAt(OverlayContext.findSpot(root.plateW, root.plateH, OverlayContext.plates(root.identifier), root.canvasW, root.canvasH))
            }
            root.settled = true
        }
    }

    // Actions
    function dismiss(): void {
        if (root.dismissing) return
        root.dismissing = true
        if (!root.visible) removeTimer.start()
    }
    function close(): void { root.dismiss() }
    function togglePinned(): void { root.persistentStateEntry.pinned = !root.pinned }
    function toggleClickthrough(): void { root.persistentStateEntry.clickthrough = !root.clickthrough }
    function save(xPos: real, yPos: real, w: real, h: real): void {
        const e = root.persistentStateEntry
        e.x = Math.round(xPos)
        e.y = Math.round(yPos)
        e.width = root.resizable ? Math.round(w) : 0
        e.height = root.resizable ? Math.round(h) : 0
    }
    function savePosition(xPos = root.x, yPos = root.y, w = root.contentW, h = root.contentH): void { root.save(xPos, yPos, w, h) }
    // `spot` is the plate's corner.
    function placeAt(spot: var): void { root.save(spot.x - root.resizeMargin, spot.y - root.resizeMargin, root.contentW, root.contentH) }
    // The content's centre on the screen's (a crosshair lands on the middle).
    function center(): void {
        const cx = root.resizeMargin + root.padding + root.contentW / 2
        const cy = root.resizeMargin + root.headerHeight + root.contentH / 2
        root.save(root.canvasW / 2 - cx, root.canvasH / 2 - cy, root.contentW, root.contentH)
    }

    // Move with snapping
    function beginMove(): void {
        OverlayContext.raise(root.identifier)
        root._start = { x: root.x, y: root.y }
        root.liveX = root.x
        root.liveY = root.y
        root.moving = true
    }
    function snapAxis(pos: real, size: real, span: real, otherPos: real, otherSize: real, others: var, horizontal: bool): var {
        const edge = Math.round(16 * root.d)
        const gap = Math.round(12 * root.d)
        const reach = 10
        let best = null
        const consider = (value, line) => {
            const dist = Math.abs(pos - value)
            if (dist <= reach && (best === null || dist < best.dist))
                best = { value: value, line: line, dist: dist }
        }
        consider(edge, edge)
        consider(span - edge - size, span - edge)
        consider(Math.round((span - size) / 2), Math.round(span / 2))
        for (const o of others) {
            const a = horizontal ? o.x : o.y
            const s = horizontal ? o.w : o.h
            const b = horizontal ? o.y : o.x
            const bs = horizontal ? o.h : o.w
            consider(a, a)
            consider(a + s - size, a + s)
            // Side by side only when they face each other.
            if (otherPos < b + bs + 40 && otherPos + otherSize > b - 40) {
                consider(a + s + gap, a + s + gap / 2)
                consider(a - gap - size, a - gap / 2)
            }
        }
        return best
    }
    function moveTo(px: real, py: real): void {
        const m = root.resizeMargin
        let bx = px + m
        let by = py + m
        const others = OverlayContext.plates(root.identifier)
        const sx = root.snapAxis(bx, root.plateW, root.canvasW, by, root.plateH, others, true)
        const sy = root.snapAxis(by, root.plateH, root.canvasH, bx, root.plateW, others, false)
        if (sx) bx = sx.value
        if (sy) by = sy.value
        OverlayContext.guideX = sx ? sx.line : -1
        OverlayContext.guideY = sy ? sy.line : -1
        bx = Math.max(0, Math.min(bx, root.canvasW - root.plateW))
        by = Math.max(0, Math.min(by, root.canvasH - root.plateH))
        root.liveX = Math.round(bx - m)
        root.liveY = Math.round(by - m)
    }
    function endMove(): void {
        OverlayContext.guideX = -1
        OverlayContext.guideY = -1
        if (!root.putBack)
            root.save(root.liveX, root.liveY, root.contentW, root.contentH)
        root.putBack = false
        root.moving = false
    }

    // Resize from an edge or corner (xDir/yDir: -1 start, 0 none, 1 end)
    function beginResize(xDir: int, yDir: int, px: real, py: real): void {
        OverlayContext.raise(root.identifier)
        root._start = { x: root.x, y: root.y, w: root.contentW, h: root.contentH, px: px, py: py, xDir: xDir, yDir: yDir }
        root.liveX = root.x
        root.liveY = root.y
        root.liveW = root.contentW
        root.liveH = root.contentH
        root.resizing = true
    }
    function resizeTo(px: real, py: real): void {
        const s = root._start
        let w = s.w, h = s.h, x = s.x, y = s.y
        if (s.xDir !== 0) {
            w = Math.max(root.minimumWidth, s.w + (px - s.px) * s.xDir)
            if (s.xDir < 0) {
                x = s.x + s.w - w
                if (x < 0) { w += x; x = 0 }
            } else {
                w = Math.min(w, root.canvasW - root.chromeW - x)
            }
        }
        if (s.yDir !== 0) {
            h = Math.max(root.minimumHeight, s.h + (py - s.py) * s.yDir)
            if (s.yDir < 0) {
                y = s.y + s.h - h
                if (y < 0) { h += y; y = 0 }
            } else {
                h = Math.min(h, root.canvasH - root.chromeH - y)
            }
        }
        root.liveW = Math.round(w)
        root.liveH = Math.round(h)
        root.liveX = Math.round(x)
        root.liveY = Math.round(y)
    }
    function endResize(): void {
        if (!root.resizing) return
        if (!root.putBack)
            root.save(root.liveX, root.liveY, root.liveW, root.liveH)
        root.putBack = false
        root.resizing = false
    }

    DragHandler {
        id: moveHandler
        target: null
        enabled: root.benchOpen && !root.resizing && !dragEscape.letGo
        acceptedButtons: Qt.LeftButton
        // Never takes a press from a control, a list or a text field inside: the tool moves from its empty parts.
        grabPermissions: PointerHandler.TakeOverForbidden
        cursorShape: Qt.ClosedHandCursor
        onActiveChanged: moveHandler.active ? root.beginMove() : root.endMove()
        onActiveTranslationChanged: {
            if (moveHandler.active)
                root.moveTo(root._start.x + moveHandler.activeTranslation.x, root._start.y + moveHandler.activeTranslation.y)
        }
    }
    DragEscape {
        id: dragEscape
        active: root.moving || root.resizing
        onCancel: root.putBack = true
    }
    HoverHandler { id: hover }

    OverlayPlate {
        id: plate
        x: root.resizeMargin
        y: root.resizeMargin + root.hudMorph * (root.headerHeight - root.padding)
        width: root.plateW
        height: root.plateH - root.hudMorph * (root.headerHeight - root.padding + root.footerHeight)
        radius: root.plateRadius
        fillOpacity: root.plateAlpha
        screenX: root.x + plate.x
        screenY: root.y + plate.y
    }

    // Header
    Item {
        id: header
        x: root.resizeMargin
        y: root.resizeMargin
        width: root.plateW
        height: root.headerHeight
        opacity: root.chrome
        visible: opacity > 0.01
        HoverHandler { cursorShape: Qt.OpenHandCursor; enabled: root.benchOpen }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.padding + Math.round(4 * root.d)
            anchors.rightMargin: root.padding
            spacing: Math.round(8 * root.d)

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: root.materialSymbol
                iconSize: Math.round(18 * root.d)
                fill: 1
                color: OverlayLook.colPrimary
            }
            StyledText {
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: Math.max(40, header.width * 0.55)
                text: root.title
                elide: Text.ElideRight
                color: OverlayLook.colOnLayer1
                font.family: OverlayLook.fontMain
                font.pixelSize: OverlayLook.typeLabel
                font.weight: Font.DemiBold
            }
            StyledText {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                text: root.fact
                visible: root.fact.length > 0
                elide: Text.ElideRight
                color: root.factColor
                font.family: OverlayLook.fontNumbers
                font.features: ({ "tnum": 1 })
                font.pixelSize: OverlayLook.typeMeta
            }
            Item { Layout.fillWidth: true; visible: root.fact.length === 0 }

            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.round(2 * root.d)
                OverlayButton {
                    visible: root.titlebarActionSymbol.length > 0
                    size: Math.round(28 * root.d)
                    glyph: root.titlebarActionSymbol
                    tip: root.titlebarActionTooltip
                    onClicked: root.titlebarActionClicked()
                }
                OverlayButton {
                    visible: root.showCenterButton
                    size: Math.round(28 * root.d)
                    glyph: "recenter"
                    tip: Translation.tr("Center")
                    onClicked: root.center()
                }
                OverlayButton {
                    size: Math.round(28 * root.d)
                    glyph: "keep"
                    toggled: root.pinned
                    tip: root.pinned ? Translation.tr("Unpin") : Translation.tr("Pin")
                    onClicked: root.togglePinned()
                }
                OverlayButton {
                    size: Math.round(28 * root.d)
                    glyph: "close"
                    tip: Translation.tr("Close")
                    onClicked: root.dismiss()
                }
            }
        }
    }

    // Content
    Item {
        id: contentHolder
        x: root.resizeMargin + root.padding
        y: root.resizeMargin + root.headerHeight
        width: root.contentW
        height: root.contentH
        children: [root.contentItem]
    }

    // Footer: how it stays once pinned
    Item {
        id: footer
        x: root.resizeMargin
        y: root.resizeMargin + root.headerHeight + root.contentH + root.padding
        width: root.plateW
        height: root.footerHeight
        opacity: root.chrome * root.footerT
        visible: opacity > 0.01
        clip: true

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.padding
            anchors.rightMargin: root.padding
            height: 1
            color: OverlayLook.colHairline
        }
        RowLayout {
            anchors.fill: parent
            anchors.topMargin: 1
            anchors.leftMargin: root.padding + Math.round(4 * root.d)
            anchors.rightMargin: root.padding
            spacing: Math.round(10 * root.d)

            Item {
                id: opacityGlyph
                readonly property bool hovered: opacityHover.hovered
                Layout.alignment: Qt.AlignVCenter
                visible: root.hudPlate
                implicitWidth: Math.round(16 * root.d)
                implicitHeight: implicitWidth
                HoverHandler { id: opacityHover }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "opacity"
                    iconSize: Math.round(16 * root.d)
                    color: OverlayLook.colSubtext
                }
                StyledToolTip { text: Translation.tr("Background when pinned") }
            }
            OverlaySlider {
                id: backgroundSlider
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                visible: root.hudPlate
                value: root.hudAlpha
                onMoved: v => root.previewBackground = v
                onCommitted: v => {
                    root.persistentStateEntry.background = v
                    root.previewBackground = -1
                }
            }
            StyledText {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Math.round(34 * root.d)
                visible: root.hudPlate
                horizontalAlignment: Text.AlignRight
                text: Math.round((root.previewBackground >= 0 ? root.previewBackground : root.hudAlpha) * 100) + "%"
                color: OverlayLook.colSubtext
                font.family: OverlayLook.fontNumbers
                font.features: ({ "tnum": 1 })
                font.pixelSize: OverlayLook.typeMeta
            }
            Item { Layout.fillWidth: true; visible: !root.hudPlate }
            OverlayButton {
                Layout.alignment: Qt.AlignVCenter
                visible: root.showClickabilityButton
                size: Math.round(28 * root.d)
                glyph: "arrow_selector_tool"
                label: Translation.tr("Clickable")
                tip: Translation.tr("Clickable when pinned")
                toggled: !root.clickthrough
                onClicked: root.toggleClickthrough()
            }
        }
    }

    // Resize: each edge and corner with its own cursor, a grip shown in the corner under the pointer.
    component ResizeZone: MouseArea {
        id: zone
        required property int xDir
        required property int yDir
        enabled: root.resizable && root.benchOpen && !dragEscape.letGo
        hoverEnabled: true
        preventStealing: true
        cursorShape: zone.xDir === 0 ? Qt.SizeVerCursor : zone.yDir === 0 ? Qt.SizeHorCursor
            : zone.xDir === zone.yDir ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
        onPressed: mouse => {
            const p = zone.mapToItem(root.parent, mouse.x, mouse.y)
            root.beginResize(zone.xDir, zone.yDir, p.x, p.y)
        }
        onPositionChanged: mouse => {
            if (!zone.pressed || !root.resizing) return
            const p = zone.mapToItem(root.parent, mouse.x, mouse.y)
            root.resizeTo(p.x, p.y)
        }
        onReleased: root.endResize()
        onCanceled: root.endResize()
    }
    readonly property real band: root.resizeMargin * 2
    ResizeZone { xDir: -1; yDir: 0; x: 0; y: root.band; width: root.band; height: root.height - root.band * 2 }
    ResizeZone { xDir: 1; yDir: 0; x: root.width - root.band; y: root.band; width: root.band; height: root.height - root.band * 2 }
    ResizeZone { xDir: 0; yDir: -1; x: root.band; y: 0; width: root.width - root.band * 2; height: root.resizeMargin + 3 }
    ResizeZone { xDir: 0; yDir: 1; x: root.band; y: root.height - root.band; width: root.width - root.band * 2; height: root.band }
    ResizeZone { xDir: -1; yDir: -1; x: 0; y: 0; width: root.band; height: root.band }
    ResizeZone { xDir: 1; yDir: -1; x: root.width - root.band; y: 0; width: root.band; height: root.band }
    ResizeZone { xDir: -1; yDir: 1; x: 0; y: root.height - root.band; width: root.band; height: root.band }
    ResizeZone { xDir: 1; yDir: 1; x: root.width - root.band - 6; y: root.height - root.band - 6; width: root.band + 6; height: root.band + 6 }

    Item {
        id: grip
        x: root.width - root.resizeMargin - width - Math.round(5 * root.d)
        y: root.height - root.resizeMargin - height - Math.round(5 * root.d)
        width: Math.round(10 * root.d)
        height: width
        visible: root.resizable && root.benchOpen
        opacity: hover.hovered || root.resizing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: FamilyStyle.feedbackDuration } }
        // Two strokes from the corner, like a window's size grip.
        Repeater {
            model: [{ m: 0.6, l: 0.8 }, { m: 0.8, l: 0.4 }]
            Rectangle {
                required property var modelData
                width: grip.width * modelData.l * Math.SQRT2
                height: 1.5
                radius: 1
                antialiasing: true
                color: OverlayLook.colFaint
                rotation: -45
                x: grip.width * modelData.m - width / 2
                y: grip.height * modelData.m - height / 2
            }
        }
    }

    // A touch anywhere raises it; passive, so every control inside still gets its press.
    Item {
        anchors.fill: parent
        z: 1000
        PointHandler {
            id: touch
            acceptedButtons: Qt.AllButtons
            onActiveChanged: if (touch.active) OverlayContext.raise(root.identifier)
        }
    }
}
