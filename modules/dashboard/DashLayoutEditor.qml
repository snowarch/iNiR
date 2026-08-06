import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

/**
 * Drag-and-drop dashboard layout editor. Three zones (left, center, right) plus
 * an "Available" tray. Widgets reorder within a zone, move across zones, get
 * removed (drop on the tray) or added (drag a chip onto a zone, or tap it).
 *
 * Drag mechanism — pointer-driven, NOT Qt's Drag/DropArea. The previous version
 * reparented the real row into a floating layer and relied on DropArea event
 * delivery; nested inside two Flickables (the Settings ContentPage scroll and
 * the in-panel edit sheet) that delivery is unreliable and the gesture was
 * silently stolen, so drags never committed. This version instead:
 *   • owns the gesture on a `preventStealing` MouseArea (no Flickable steal),
 *   • floats a lightweight GHOST that follows the cursor (the real row just
 *     collapses in place, keeping the column geometry stable),
 *   • computes the target zone + insert index by hit-testing the cursor against
 *     each zone's registered geometry every move — fully deterministic, no
 *     dependence on DropArea entered/dropped signals firing.
 * Writes still go per-leaf through Config (never assign a whole object to the
 * dashboard.layout JsonObject). Used in BOTH the Settings page and the in-panel
 * edit sheet, so the editing model is identical wherever the user reaches it.
 */
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 12

    readonly property int rowH: 38
    readonly property int rowGap: 4
    readonly property real pitch: rowH + rowGap
    readonly property real dragThreshold: 6
    readonly property string availableZone: "__available__"
    readonly property var zones: ["left", "center", "right"]

    // Widget catalog — id → display metadata. Single source for the editor.
    readonly property var catalog: ({
        welcome:       { icon: "waving_hand",         label: Translation.tr("Welcome") },
        clock:         { icon: "schedule",            label: Translation.tr("Clock") },
        system:        { icon: "monitoring",          label: Translation.tr("System usage") },
        github:        { icon: "deployed_code",       label: Translation.tr("GitHub activity") },
        notifications: { icon: "notifications",       label: Translation.tr("Notifications") },
        todo:          { icon: "checklist",           label: Translation.tr("To Do") },
        media:         { icon: "music_note",          label: Translation.tr("Media player") },
        weather:       { icon: "partly_cloudy_day",   label: Translation.tr("Weather") },
        calendar:      { icon: "calendar_month",      label: Translation.tr("Calendar") },
        agenda:        { icon: "event_upcoming",      label: Translation.tr("Agenda") },
        notes:         { icon: "edit_note",           label: Translation.tr("Notes") }
    })
    readonly property var allIds: Object.keys(catalog)

    function _meta(id) { return root.catalog[id] ?? ({ icon: "widgets", label: id }) }
    function _icon(id) { return root._meta(id).icon }
    function _label(id) { return root._meta(id).label }
    function _zoneLabel(z) {
        return ({ left: Translation.tr("Left"), center: Translation.tr("Center"),
            right: Translation.tr("Right") })[z] || z
    }
    function _zoneIcon(z) {
        return ({ left: "align_horizontal_left", center: "align_horizontal_center",
            right: "align_horizontal_right" })[z] || "widgets"
    }

    // ─── Reactive layout view ───────────────────────────────────────────
    readonly property var _defaults: ({
        left: ["welcome", "clock", "system"],
        center: ["notifications", "todo"],
        right: ["media", "weather", "calendar"]
    })
    function _getZone(name) {
        // list<string> from QML is array-LIKE (has .length / indices) but NOT a
        // real Array, so Array.isArray() is false for it — never use it here, it
        // would always fall through to defaults. `.length >= 0` is the guard.
        const a = Config.options?.dashboard?.layout?.[name]
        return (a && a.length >= 0) ? a : (root._defaults[name] ?? [])
    }
    function _placed() {
        let s = []
        for (let i = 0; i < root.zones.length; i++) s = s.concat(root._getZone(root.zones[i]))
        return s
    }
    readonly property var placedIds: root._placed()
    readonly property var availableIds: root.allIds.filter(id => root.placedIds.indexOf(id) === -1)

    // ─── Mutators (per-leaf only) ───────────────────────────────────────
    function _addToZone(id, toZone, atIndex) {
        const dst = root._getZone(toZone).slice()
        if (dst.indexOf(id) !== -1) return
        const idx = (atIndex === undefined || atIndex < 0) ? dst.length : Math.max(0, Math.min(atIndex, dst.length))
        dst.splice(idx, 0, id)
        Config.setNestedValue("dashboard.layout." + toZone, dst)
    }
    function _remove(zone, idx) {
        const arr = root._getZone(zone).slice()
        arr.splice(idx, 1)
        Config.setNestedValue("dashboard.layout." + zone, arr)
    }
    function _dropMove(srcZone, srcIdx, srcId, dstZone, dstIdx) {
        if (srcZone === root.availableZone) { root._addToZone(srcId, dstZone, dstIdx); return }
        if (srcZone === dstZone) {
            // dstIdx is computed against liveCount (already excludes the lifted
            // row), so no srcIdx adjustment is needed after the splice.
            const arr = root._getZone(srcZone).slice()
            const [m] = arr.splice(srcIdx, 1)
            arr.splice(Math.max(0, Math.min(dstIdx, arr.length)), 0, m)
            Config.setNestedValue("dashboard.layout." + srcZone, arr)
        } else {
            const src = root._getZone(srcZone).slice()
            const dst = root._getZone(dstZone).slice()
            const [m] = src.splice(srcIdx, 1)
            dst.splice(Math.max(0, Math.min(dstIdx, dst.length)), 0, m)
            let u = {}
            u["dashboard.layout." + srcZone] = src
            u["dashboard.layout." + dstZone] = dst
            Config.setNestedValues(u)
        }
    }
    function _resetToDefaults() {
        Config.setNestedValues({
            "dashboard.layout.left": root._defaults.left,
            "dashboard.layout.center": root._defaults.center,
            "dashboard.layout.right": root._defaults.right
        })
    }

    // ─── Drag state (pointer-driven) ────────────────────────────────────
    property var dragInfo: null      // { zone, index, id } of the lifted item
    property string dragId: ""       // id being dragged (for the ghost)
    property string dropZone: ""     // zone currently under the cursor
    property int dropIndex: -1       // insert slot in dropZone
    property bool dragging: false
    property point dragScene: Qt.point(0, 0)   // cursor position in root coords

    // Per-zone hit regions, registered by each zone delegate. 3 fixed zones,
    // never destroyed during a session, so registration is one-shot.
    property var _zoneRegions: ({})
    property var _trayRegion: null

    function _indexFromY(y, count) { return Math.max(0, Math.min(Math.round(y / root.pitch), count)) }
    function _liveCount(zone) {
        return root._getZone(zone).length - ((root.dragInfo && root.dragInfo.zone === zone) ? 1 : 0)
    }

    // Cursor (root coords) → {dropZone, dropIndex}. Zone match first, then tray.
    function _updateDrop(sp) {
        for (let i = 0; i < root.zones.length; i++) {
            const zn = root.zones[i]
            const reg = root._zoneRegions[zn]
            if (!reg) continue
            const o = reg.mapToItem(root, 0, 0)
            if (sp.x >= o.x && sp.x <= o.x + reg.width && sp.y >= o.y && sp.y <= o.y + reg.height) {
                root.dropZone = zn
                root.dropIndex = root._indexFromY(sp.y - o.y, root._liveCount(zn))
                return
            }
        }
        if (root._trayRegion) {
            const t = root._trayRegion.mapToItem(root, 0, 0)
            if (sp.x >= t.x && sp.x <= t.x + root._trayRegion.width
                && sp.y >= t.y && sp.y <= t.y + root._trayRegion.height) {
                root.dropZone = root.availableZone
                root.dropIndex = -1
                return
            }
        }
        root.dropZone = ""
        root.dropIndex = -1
    }

    function _arm(zone, index, id) {
        // Record intent on press; the drag only "begins" past the threshold so a
        // plain tap/click (chip add, remove button) is never hijacked.
        root.dragInfo = { zone: zone, index: index, id: id }
        root.dragId = id
        root.dragging = false
    }
    function _begin(sp) {
        root.dragging = true
        root.dragScene = sp
        root._updateDrop(sp)
    }
    function _move(sp) {
        root.dragScene = sp
        root._updateDrop(sp)
    }
    function _commit() {
        if (root.dragging && root.dragInfo) {
            if (root.dropZone === root.availableZone) {
                if (root.dragInfo.zone !== root.availableZone) root._remove(root.dragInfo.zone, root.dragInfo.index)
            } else if (root.dropZone !== "" && root.dropIndex >= 0) {
                root._dropMove(root.dragInfo.zone, root.dragInfo.index, root.dragInfo.id, root.dropZone, root.dropIndex)
            }
        }
        root._endDrag()
    }
    function _endDrag() {
        root.dragInfo = null; root.dragId = ""; root.dragging = false
        root.dropZone = ""; root.dropIndex = -1
    }

    // Floating overlay: holds the ghost so it travels above every zone/tray.
    // Sits in a zero-height layout slot at the top; its local coords ≈ root's.
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 0
        z: 100
        clip: false
        Item {
            id: dragLayer
            width: root.width
            height: root.height

            // The lifted item, rendered as a single bright row that follows the
            // cursor. The source row collapses in place while this is visible.
            Rectangle {
                id: ghost
                visible: root.dragging && root.dragId.length > 0
                width: root.width
                height: root.rowH
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                border.color: Appearance.colors.colPrimary
                border.width: 1
                scale: root.dragging ? 1.03 : 0.96
                rotation: root.dragging ? 0.6 : 0
                opacity: root.dragging ? 0.97 : 0
                z: 300
                property point _c: root.mapToItem(dragLayer, root.dragScene.x, root.dragScene.y)
                x: _c.x - width / 2
                y: _c.y - height / 2
                Behavior on scale { enabled: Appearance.animationsEnabled; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }

                StyledRectangularShadow { target: ghost; z: -1 }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 6
                    spacing: 8
                    MaterialSymbol { text: "drag_indicator"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colSubtext }
                    MaterialSymbol { text: root._icon(root.dragId); iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnLayer2 }
                    StyledText {
                        Layout.fillWidth: true
                        text: root._label(root.dragId)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer2
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // ─── Header ─────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Drag widgets between columns, or drag from the tray to add. Drop a widget on the tray to remove it.")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
            wrapMode: Text.WordWrap
        }
        RippleButton {
            implicitWidth: 30; implicitHeight: 30
            buttonRadius: Appearance.rounding.full
            onClicked: root._resetToDefaults()
            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "restart_alt"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1 }
            StyledToolTip { text: Translation.tr("Reset dashboard layout to defaults") }
        }
    }

    // ─── Draggable row ──────────────────────────────────────────────────
    component WidgetRow: Rectangle {
        id: rowRoot
        property string widgetId: ""
        property string zone: ""
        property int rowIndex: -1
        readonly property bool isSource: root.dragging && root.dragInfo
            && root.dragInfo.zone === zone && root.dragInfo.index === rowIndex
        property point _pressScene: Qt.point(0, 0)

        width: parent ? parent.width : implicitWidth
        // Collapse out of the flow while this row is the lift source, so the
        // column reflows to liveCount and the drop-slot math stays exact.
        height: isSource ? 0 : root.rowH
        opacity: isSource ? 0 : 1
        clip: true
        radius: Appearance.rounding.small
        color: dragMa.containsMouse ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1
        border.color: Appearance.colors.colOutlineVariant
        border.width: 1
        Behavior on height { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

        MouseArea {
            id: dragMa
            anchors.fill: parent
            hoverEnabled: true
            // preventStealing: the editor is nested inside Flickables (the
            // settings scroll + the in-panel edit sheet). Without this the
            // Flickable steals the vertical gesture and the drag never starts.
            preventStealing: true
            cursorShape: (root.dragging && rowRoot.isSource) ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPressed: mouse => {
                rowRoot._pressScene = mapToItem(root, mouse.x, mouse.y)
                root._arm(rowRoot.zone, rowRoot.rowIndex, rowRoot.widgetId)
            }
            onPositionChanged: mouse => {
                if (!root.dragInfo) return
                const sp = mapToItem(root, mouse.x, mouse.y)
                if (!root.dragging) {
                    if (Math.hypot(sp.x - rowRoot._pressScene.x, sp.y - rowRoot._pressScene.y) < root.dragThreshold) return
                    root._begin(sp)
                } else root._move(sp)
            }
            onReleased: { if (root.dragging) root._commit(); else root._endDrag() }
            onCanceled: root._endDrag()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 6
            spacing: 8
            visible: !rowRoot.isSource
            MaterialSymbol { text: "drag_indicator"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colSubtext }
            MaterialSymbol { text: root._icon(rowRoot.widgetId); iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnLayer1 }
            StyledText {
                Layout.fillWidth: true
                text: root._label(rowRoot.widgetId)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
                elide: Text.ElideRight
            }
            RippleButton {
                implicitWidth: 26; implicitHeight: 26
                buttonRadius: Appearance.rounding.full
                onClicked: root._remove(rowRoot.zone, rowRoot.rowIndex)
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "do_not_disturb_on"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }
                StyledToolTip { text: Translation.tr("Remove from layout") }
            }
        }
    }

    // ─── Zones ──────────────────────────────────────────────────────────
    Repeater {
        model: root.zones
        delegate: Rectangle {
            id: zoneCard
            required property string modelData
            readonly property string zoneName: modelData
            readonly property var zoneItems: root._getZone(zoneName)
            readonly property bool dropActive: root.dragging && root.dropZone === zoneName

            Layout.fillWidth: true
            implicitHeight: zoneInner.implicitHeight + 16
            radius: Appearance.rounding.normal
            color: dropActive ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.92)
                : Appearance.colors.colLayer0
            border.color: dropActive ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
            border.width: 1
            Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
            Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

            ColumnLayout {
                id: zoneInner
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle {
                        implicitWidth: 24; implicitHeight: 24
                        radius: Appearance.rounding.full
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
                        MaterialSymbol { anchors.centerIn: parent; text: root._zoneIcon(zoneCard.zoneName); iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colPrimary }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root._zoneLabel(zoneCard.zoneName)
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                    }
                    Rectangle {
                        implicitHeight: 18
                        implicitWidth: Math.max(22, countLabel.implicitWidth + 12)
                        radius: Appearance.rounding.full
                        color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.92)
                        StyledText {
                            id: countLabel
                            anchors.centerIn: parent
                            text: zoneCard.zoneItems.length + ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                // Hit/index region — registered with root for cursor hit-testing.
                Item {
                    id: zoneDrop
                    Layout.fillWidth: true
                    implicitHeight: Math.max(rowCol.implicitHeight, root.rowH)
                    Component.onCompleted: root._zoneRegions[zoneCard.zoneName] = zoneDrop

                    Rectangle {
                        visible: zoneCard.zoneItems.length === 0
                        anchors.fill: parent
                        radius: Appearance.rounding.small
                        color: zoneCard.dropActive ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9) : "transparent"
                        border.color: zoneCard.dropActive ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                        border.width: 1
                        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                text: zoneCard.dropActive ? "download" : "drag_handle"
                                iconSize: Appearance.font.pixelSize.normal
                                color: zoneCard.dropActive ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                            }
                            StyledText {
                                text: zoneCard.dropActive ? Translation.tr("Release to drop") : Translation.tr("Drop widgets here")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: zoneCard.dropActive ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                            }
                        }
                    }

                    Column {
                        id: rowCol
                        width: parent.width
                        spacing: root.rowGap
                        Repeater {
                            model: zoneCard.zoneItems
                            delegate: WidgetRow {
                                required property string modelData
                                required property int index
                                widgetId: modelData
                                zone: zoneCard.zoneName
                                rowIndex: index
                            }
                        }
                    }

                    // Drop slot indicator — animates between insert positions.
                    Rectangle {
                        id: dropSlot
                        visible: zoneCard.dropActive && root.dropIndex >= 0 && root._liveCount(zoneCard.zoneName) > 0
                        x: 6
                        width: parent.width - 12
                        height: 4
                        radius: 2
                        color: Appearance.colors.colPrimary
                        y: Math.min(root.dropIndex, root._liveCount(zoneCard.zoneName)) * root.pitch - root.rowGap / 2 - height / 2
                        z: 50
                        Behavior on y {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        Rectangle { width: 8; height: 8; radius: 4; color: parent.color; anchors.verticalCenter: parent.verticalCenter; x: -4 }
                        Rectangle { width: 8; height: 8; radius: 4; color: parent.color; anchors.verticalCenter: parent.verticalCenter; x: parent.width - 4 }
                    }
                }
            }
        }
    }

    // ─── Available (unplaced) widgets — chip tray, also a remove target ──
    Rectangle {
        id: tray
        Layout.fillWidth: true
        Layout.topMargin: 4
        readonly property bool removeActive: root.dragging && root.dragInfo
            && root.dragInfo.zone !== root.availableZone && root.dropZone === root.availableZone
        implicitHeight: trayInner.implicitHeight + 16
        radius: Appearance.rounding.normal
        color: removeActive ? ColorUtils.transparentize(Appearance.colors.colError, 0.9) : Appearance.colors.colLayer0
        border.color: removeActive ? Appearance.colors.colError : Appearance.colors.colOutlineVariant
        border.width: 1
        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
        Component.onCompleted: root._trayRegion = tray

        ColumnLayout {
            id: trayInner
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                    implicitWidth: 24; implicitHeight: 24
                    radius: Appearance.rounding.full
                    color: ColorUtils.transparentize(tray.removeActive ? Appearance.colors.colError : Appearance.colors.colPrimary, 0.85)
                    MaterialSymbol { anchors.centerIn: parent; text: tray.removeActive ? "delete" : "add_box"; iconSize: Appearance.font.pixelSize.small; color: tray.removeActive ? Appearance.colors.colError : Appearance.colors.colPrimary }
                }
                StyledText {
                    Layout.fillWidth: true
                    text: tray.removeActive ? Translation.tr("Release to remove")
                        : (root.availableIds.length > 0 ? Translation.tr("Available widgets") : Translation.tr("All widgets placed"))
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: tray.removeActive ? Appearance.colors.colError : Appearance.colors.colOnLayer0
                }
            }

            Flow {
                Layout.fillWidth: true
                visible: root.availableIds.length > 0
                spacing: 6
                Repeater {
                    model: root.availableIds
                    delegate: Rectangle {
                        id: chip
                        required property string modelData
                        readonly property string widgetId: modelData
                        readonly property bool isSource: root.dragging && root.dragInfo
                            && root.dragInfo.zone === root.availableZone && root.dragInfo.id === widgetId
                        property point _pressScene: Qt.point(0, 0)

                        implicitHeight: 32
                        implicitWidth: chipRow.implicitWidth + 18
                        radius: Appearance.rounding.full
                        color: chipMa.containsMouse
                            ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
                            : ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.95)
                        border.color: Appearance.colors.colOutlineVariant
                        border.width: 1
                        opacity: isSource ? 0.35 : 1
                        Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

                        MouseArea {
                            id: chipMa
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: (root.dragging && chip.isSource) ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            onPressed: mouse => {
                                chip._pressScene = mapToItem(root, mouse.x, mouse.y)
                                root._arm(root.availableZone, -1, chip.widgetId)
                            }
                            onPositionChanged: mouse => {
                                if (!root.dragInfo) return
                                const sp = mapToItem(root, mouse.x, mouse.y)
                                if (!root.dragging) {
                                    if (Math.hypot(sp.x - chip._pressScene.x, sp.y - chip._pressScene.y) < root.dragThreshold) return
                                    root._begin(sp)
                                } else root._move(sp)
                            }
                            onReleased: { if (root.dragging) root._commit(); else root._endDrag() }
                            onCanceled: root._endDrag()
                            // Tap (no drag) adds to the emptiest column — fast path.
                            onClicked: {
                                if (root.dragging) return
                                let target = "center", best = Infinity
                                for (const z of root.zones) {
                                    const n = root._getZone(z).length
                                    if (n < best) { best = n; target = z }
                                }
                                root._addToZone(chip.widgetId, target, -1)
                            }
                        }

                        RowLayout {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol { text: root._icon(chip.widgetId); iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1 }
                            StyledText {
                                text: root._label(chip.widgetId)
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnLayer1
                            }
                            MaterialSymbol { text: "add"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }
                        }
                    }
                }
            }
        }
    }
}
