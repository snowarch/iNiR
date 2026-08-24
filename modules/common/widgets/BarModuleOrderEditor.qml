import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

/**
 * Drag-and-drop per-zone bar layout editor.
 *
 * Five zones (left, centerLeft, center, centerRight, right) each render their
 * module rows inside a soft container card with a DropArea. Rows are draggable
 * across zones AND from the "Available" chip tray; uniform row height makes the
 * insert-index a simple `round(y / pitch)`. The dragged row reparents into
 * `dragLayer` (top z) and follows the cursor; a primary-coloured bar marks the
 * drop slot. Writes go through Config per-leaf (never assign a whole object to
 * the bar.layout JsonObject). The pivot module (workspaces in `center`) is not
 * draggable. Modules not in any zone appear as compact chips that can be
 * either dragged into a zone or added via a single popup menu trigger.
 */
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 12

    readonly property int rowH: 36
    readonly property int rowGap: 4
    readonly property real pitch: rowH + rowGap
    readonly property string availableZone: "__available__"

    // ─── Defaults / metadata ────────────────────────────────────────────
    readonly property var _defaultLayout: ({
        left: ["leftSidebarButton", "activeWindow"],
        centerLeft: ["resources", "media"],
        center: ["workspaces"],
        centerRight: ["clock", "utilButtons", "battery"],
        right: ["rightSidebarButton", "tray", "timer", "shellUpdate", "spacer", "weather"],
    })
    readonly property var _knownIds: [
        "leftSidebarButton", "activeWindow", "taskbar", "resources", "media", "workspaces",
        "clock", "utilButtons", "battery", "rightSidebarButton", "tray", "timer", "shellUpdate", "spacer", "weather"
    ]
    readonly property var _zones: ["left", "centerLeft", "center", "centerRight", "right"]
    readonly property var _visKeys: ({
        leftSidebarButton: "leftSidebarButton", activeWindow: "activeWindow",
        taskbar: "taskbar",
        resources: "resources", media: "media", workspaces: "workspaces", clock: "clock",
        utilButtons: "utilButtons", battery: "battery", rightSidebarButton: "rightSidebarButton",
        tray: "sysTray", weather: "weather",
    })

    function _metaIcon(id) {
        return ({ leftSidebarButton: "side_navigation", activeWindow: "window",
            taskbar: "dock_to_bottom",
            resources: "memory", media: "music_note", workspaces: "workspaces", clock: "schedule",
            utilButtons: "build", battery: "battery_full", rightSidebarButton: "call_to_action",
            tray: "shelf_auto_hide", timer: "timer", shellUpdate: "system_update", spacer: "space_bar",
            weather: "cloud" })[id] || "widgets"
    }
    function _metaLabel(id) {
        return ({ leftSidebarButton: Translation.tr("Left sidebar"), activeWindow: Translation.tr("Active window"),
            taskbar: Translation.tr("Taskbar"),
            resources: Translation.tr("Resources"), media: Translation.tr("Media"),
            workspaces: Translation.tr("Workspaces"), clock: Translation.tr("Clock"), utilButtons: Translation.tr("Utility buttons"),
            battery: Translation.tr("Battery"), rightSidebarButton: Translation.tr("Right sidebar"), tray: Translation.tr("System tray"),
            timer: Translation.tr("Timer"), shellUpdate: Translation.tr("Shell update"), spacer: Translation.tr("Flexible spacer"),
            weather: Translation.tr("Weather") })[id] || id
    }
    function _zoneLabel(z) {
        return ({ left: Translation.tr("Left edge"), centerLeft: Translation.tr("Center left"),
            center: Translation.tr("Center (pivot)"), centerRight: Translation.tr("Center right"),
            right: Translation.tr("Right edge") })[z] || z
    }
    function _zoneIcon(z) {
        return ({ left: "first_page", centerLeft: "align_horizontal_left", center: "align_horizontal_center",
            centerRight: "align_horizontal_right", right: "last_page" })[z] || "widgets"
    }

    // ─── Reactive layout view ───────────────────────────────────────────
    readonly property bool migrated: Config.options?.bar?.layout?.migrated === true
    function _getZone(name) {
        if (!root.migrated) return root._defaultLayout[name] ?? []
        const a = Config.options?.bar?.layout?.[name]
        return (a && a.length >= 0) ? a : (root._defaultLayout[name] ?? [])
    }
    function _placed() {
        let s = []
        for (let i = 0; i < root._zones.length; i++) s = s.concat(root._getZone(root._zones[i]))
        return s
    }
    function _available() {
        const placed = root._placed()
        // `spacer` is a reusable filler — always offered, can appear any number
        // of times in any zone.
        return root._knownIds.filter(id => id === "spacer" || placed.indexOf(id) === -1)
    }
    readonly property var availableIds: root._available()

    // ─── Mutators (per-leaf only) ───────────────────────────────────────
    function _ensureMigrated() {
        if (root.migrated) return
        const d = root._defaultLayout
        Config.setNestedValues({
            "bar.layout.left": d.left, "bar.layout.centerLeft": d.centerLeft, "bar.layout.center": d.center,
            "bar.layout.centerRight": d.centerRight, "bar.layout.right": d.right, "bar.layout.migrated": true })
    }
    function _resetToDefaults() {
        const d = root._defaultLayout
        Config.setNestedValues({
            "bar.layout.left": d.left, "bar.layout.centerLeft": d.centerLeft, "bar.layout.center": d.center,
            "bar.layout.centerRight": d.centerRight, "bar.layout.right": d.right, "bar.layout.migrated": true })
    }
    function _addToZone(id, toZone, atIndex) {
        root._ensureMigrated()
        const dst = root._getZone(toZone).slice()
        if (id !== "spacer" && dst.indexOf(id) !== -1) return
        const idx = (atIndex === undefined || atIndex < 0) ? dst.length : Math.max(0, Math.min(atIndex, dst.length))
        dst.splice(idx, 0, id)
        Config.setNestedValue("bar.layout." + toZone, dst)
    }
    function _remove(zone, idx) {
        root._ensureMigrated()
        const arr = root._getZone(zone).slice()
        arr.splice(idx, 1)
        Config.setNestedValue("bar.layout." + zone, arr)
    }
    // Move from (srcZone, srcIdx) to dstZone at dstIdx. Handles same- and
    // cross-zone with a single atomic write per affected zone. Source zone
    // `availableZone` means "add new from the tray, no source removal".
    function _dropMove(srcZone, srcIdx, srcId, dstZone, dstIdx) {
        root._ensureMigrated()
        if (srcZone === root.availableZone) {
            root._addToZone(srcId, dstZone, dstIdx)
            return
        }
        if (srcZone === dstZone) {
            // dstIdx is the insert position AMONG the remaining rows (the editor
            // computes it against liveCount, which already excludes the lifted
            // row), so no srcIdx adjustment is needed after the splice.
            const arr = root._getZone(srcZone).slice()
            const [m] = arr.splice(srcIdx, 1)
            arr.splice(Math.max(0, Math.min(dstIdx, arr.length)), 0, m)
            Config.setNestedValue("bar.layout." + srcZone, arr)
        } else {
            const src = root._getZone(srcZone).slice()
            const dst = root._getZone(dstZone).slice()
            const [m] = src.splice(srcIdx, 1)
            dst.splice(Math.max(0, Math.min(dstIdx, dst.length)), 0, m)
            let u = {}
            u["bar.layout." + srcZone] = src
            u["bar.layout." + dstZone] = dst
            Config.setNestedValues(u)
        }
    }

    // ─── Drag state ─────────────────────────────────────────────────────
    property var dragInfo: null      // { zone, index, id } of the row being dragged
    property string dropZone: ""     // zone currently hovered
    property int dropIndex: -1       // insert slot in dropZone
    readonly property bool dragging: dragInfo !== null
    function _indexFromY(y, count) { return Math.max(0, Math.min(Math.round(y / root.pitch), count)) }
    function _commitDrop(dstZone) {
        if (root.dragInfo && root.dropIndex >= 0)
            root._dropMove(root.dragInfo.zone, root.dragInfo.index, root.dragInfo.id, dstZone, root.dropIndex)
        root._endDrag()
    }
    function _endDrag() { root.dragInfo = null; root.dropZone = ""; root.dropIndex = -1 }

    // Floating layer the dragged row reparents into so it can follow the cursor
    // above every zone. Sits in a sibling overlay (not the layout flow) so its
    // anchors don't fight the ColumnLayout.
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 0
        z: 100
        clip: false
        Item { id: dragLayer; width: root.width; height: root.height }
    }

    // ─── Header ─────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Drag modules between zones, or drag from the tray below to add.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Workspaces stays as the centred pivot — it can't be moved.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                opacity: 0.7
                wrapMode: Text.WordWrap
            }
        }
        RippleButton {
            implicitWidth: 30; implicitHeight: 30
            buttonRadius: Appearance.rounding.full
            onClicked: root._resetToDefaults()
            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "restart_alt"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1 }
            StyledToolTip { text: Translation.tr("Reset bar layout to defaults") }
        }
    }

    // ─── Draggable row (reused) ─────────────────────────────────────────
    component ModuleRow: Rectangle {
        id: rowRoot
        property string moduleId: ""
        property string zone: ""
        property int rowIndex: -1
        property bool pivot: false
        property string visibilityKey: root._visKeys[moduleId] || ""
        readonly property bool beingDragged: root.dragInfo && root.dragInfo.id === moduleId && root.dragInfo.zone === zone && root.dragInfo.index === rowIndex

        width: parent ? parent.width : implicitWidth
        height: root.rowH
        radius: Appearance.rounding.small
        color: pivot ? Appearance.colors.colSecondaryContainer
            : (beingDragged ? Appearance.colors.colLayer2
            : (dragMa.containsMouse ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1))
        border.color: beingDragged ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
        border.width: pivot ? 0 : 1
        scale: beingDragged ? 1.03 : 1
        rotation: beingDragged ? 0.6 : 0
        Behavior on scale { enabled: Appearance.animationsEnabled; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on rotation { enabled: Appearance.animationsEnabled; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

        // Lift shadow while floating over the zones
        StyledRectangularShadow {
            target: rowRoot.beingDragged ? rowRoot : null
            visible: rowRoot.beingDragged
            z: -1
        }

        readonly property color _fg: pivot ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
        readonly property color _fgSubtle: pivot ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext

        // Drag plumbing — reparent into dragLayer while dragging so the row can
        // travel over other zones; Drag.drop() fires the hovered DropArea.
        Drag.active: dragMa.drag.active
        Drag.source: rowRoot
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        states: State {
            when: dragMa.drag.active
            ParentChange { target: rowRoot; parent: dragLayer }
            PropertyChanges { rowRoot { z: 200 } }
        }

        MouseArea {
            id: dragMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: !rowRoot.pivot
            cursorShape: rowRoot.pivot ? Qt.ArrowCursor : (drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
            drag.target: rowRoot
            drag.axis: Drag.XAndYAxis
            onPressed: root.dragInfo = { zone: rowRoot.zone, index: rowRoot.rowIndex, id: rowRoot.moduleId }
            onReleased: {
                if (rowRoot.Drag.target) rowRoot.Drag.drop()
                else root._endDrag()
            }
            onCanceled: root._endDrag()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 6
            spacing: 8
            MaterialSymbol {
                visible: !rowRoot.pivot
                text: "drag_indicator"
                iconSize: Appearance.font.pixelSize.normal
                color: rowRoot._fgSubtle
            }
            MaterialSymbol { text: root._metaIcon(rowRoot.moduleId); iconSize: Appearance.font.pixelSize.normal; color: rowRoot._fg }
            StyledText {
                Layout.fillWidth: true
                text: root._metaLabel(rowRoot.moduleId)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: rowRoot._fg
                elide: Text.ElideRight
            }
            // Visibility toggle (modules that have a bar.modules.<key> switch)
            RippleButton {
                visible: !rowRoot.pivot && rowRoot.visibilityKey.length > 0
                implicitWidth: 26; implicitHeight: 26
                buttonRadius: Appearance.rounding.full
                onClicked: {
                    const k = rowRoot.visibilityKey
                    Config.setNestedValue("bar.modules." + k, !(Config.options?.bar?.modules?.[k] ?? true))
                }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: (Config.options?.bar?.modules?.[rowRoot.visibilityKey] ?? true) ? "visibility" : "visibility_off"
                    iconSize: Appearance.font.pixelSize.small
                    color: (Config.options?.bar?.modules?.[rowRoot.visibilityKey] ?? true) ? rowRoot._fg : rowRoot._fgSubtle
                }
                StyledToolTip {
                    text: (Config.options?.bar?.modules?.[rowRoot.visibilityKey] ?? true)
                        ? Translation.tr("Hide from bar (keep in layout)") : Translation.tr("Show in bar")
                }
            }
            // Remove from layout
            RippleButton {
                visible: !rowRoot.pivot
                implicitWidth: 26; implicitHeight: 26
                buttonRadius: Appearance.rounding.full
                onClicked: root._remove(rowRoot.zone, rowRoot.rowIndex)
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "do_not_disturb_on"; iconSize: Appearance.font.pixelSize.small; color: rowRoot._fgSubtle }
                StyledToolTip { text: Translation.tr("Remove from layout") }
            }
        }
    }

    // ─── Zones ──────────────────────────────────────────────────────────
    Repeater {
        model: root._zones
        delegate: Rectangle {
            id: zoneCard
            required property string modelData
            required property int index
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

                DropArea {
                    id: zoneDrop
                    Layout.fillWidth: true
                    implicitHeight: Math.max(rowCol.implicitHeight, root.rowH)
                    readonly property string zoneName: zoneCard.zoneName
                    // Live count of rows actually laid out in this zone's Column
                    // (excludes the row currently lifted out of THIS zone).
                    readonly property int liveCount: zoneCard.zoneItems.length
                        - ((root.dragInfo && root.dragInfo.zone === zoneName) ? 1 : 0)
                    function _update(y) {
                        root.dropZone = zoneName
                        root.dropIndex = root._indexFromY(y, zoneDrop.liveCount)
                    }
                    onEntered: drag => zoneDrop._update(drag.y)
                    onPositionChanged: drag => zoneDrop._update(drag.y)
                    onExited: if (root.dropZone === zoneName) { root.dropZone = ""; root.dropIndex = -1 }
                    onDropped: root._commitDrop(zoneName)

                    Rectangle {
                        visible: zoneDrop.liveCount === 0
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
                                text: zoneCard.dropActive ? Translation.tr("Release to drop") : Translation.tr("Drop modules here")
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
                            delegate: ModuleRow {
                                required property string modelData
                                required property int index
                                moduleId: modelData
                                zone: zoneCard.zoneName
                                rowIndex: index
                                pivot: zoneCard.zoneName === "center" && modelData === "workspaces"
                            }
                        }
                        // Reserve the lifted row's height so the Column (and the
                        // drop-slot math, which is y/pitch) stays stable while a
                        // row from THIS zone is floating in dragLayer. Without
                        // this the Column collapses by one pitch mid-drag and the
                        // computed insert index jumps.
                        Item {
                            visible: root.dragInfo && root.dragInfo.zone === zoneDrop.zoneName
                            width: parent.width
                            height: visible ? root.rowH : 0
                        }
                    }

                    // Drop slot indicator — animates between insert positions.
                    Rectangle {
                        id: dropSlot
                        visible: zoneCard.dropActive && root.dropIndex >= 0 && zoneDrop.liveCount > 0
                        x: 6
                        width: parent.width - 12
                        height: 4
                        radius: 2
                        color: Appearance.colors.colPrimary
                        y: Math.min(root.dropIndex, zoneDrop.liveCount) * root.pitch - root.rowGap / 2 - height / 2
                        z: 50
                        Behavior on y {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        // End caps make the insert slot read as a slot, not a divider
                        Rectangle { width: 8; height: 8; radius: 4; color: parent.color; anchors.verticalCenter: parent.verticalCenter; x: -4 }
                        Rectangle { width: 8; height: 8; radius: 4; color: parent.color; anchors.verticalCenter: parent.verticalCenter; x: parent.width - 4 }
                    }
                }
            }
        }
    }

    // ─── Available (unplaced) modules — compact chip tray ──────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 4
        visible: root.availableIds.length > 0
        implicitHeight: trayInner.implicitHeight + 16
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer0
        border.color: Appearance.colors.colOutlineVariant
        border.width: 1

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
                    color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
                    MaterialSymbol { anchors.centerIn: parent; text: "add_box"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colPrimary }
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Available modules")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                }
                StyledText {
                    text: Translation.tr("drag onto a zone, or use the menu")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    opacity: 0.8
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: root.availableIds
                    delegate: Rectangle {
                        id: chip
                        required property string modelData
                        readonly property string moduleId: modelData
                        readonly property bool beingDragged: root.dragInfo && root.dragInfo.zone === root.availableZone && root.dragInfo.id === moduleId

                        implicitHeight: 30
                        implicitWidth: chipRow.implicitWidth + 16
                        radius: Appearance.rounding.full
                        color: chipMa.containsMouse || beingDragged
                            ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
                            : ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.95)
                        border.color: beingDragged ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                        border.width: 1
                        opacity: beingDragged ? 0.92 : 1
                        scale: beingDragged ? 1.04 : 1
                        Behavior on scale { enabled: Appearance.animationsEnabled; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

                        Drag.active: chipMa.drag.active
                        Drag.source: chip
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2
                        states: State {
                            when: chipMa.drag.active
                            ParentChange { target: chip; parent: dragLayer }
                            PropertyChanges { chip { z: 200 } }
                        }

                        MouseArea {
                            id: chipMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            drag.target: chip
                            drag.axis: Drag.XAndYAxis
                            onPressed: mouse => {
                                if (mouse.button === Qt.LeftButton)
                                    root.dragInfo = { zone: root.availableZone, index: -1, id: chip.moduleId }
                            }
                            onReleased: mouse => {
                                if (mouse.button !== Qt.LeftButton) return
                                if (chip.Drag.target) chip.Drag.drop()
                                else root._endDrag()
                            }
                            onCanceled: root._endDrag()
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) addMenu.popup()
                            }
                        }

                        RowLayout {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol { text: root._metaIcon(chip.moduleId); iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1 }
                            StyledText {
                                text: root._metaLabel(chip.moduleId)
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnLayer1
                            }
                            MaterialSymbol {
                                text: "more_vert"
                                iconSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    onClicked: addMenu.popup()
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }

                        Menu {
                            id: addMenu
                            Repeater {
                                model: root._zones
                                delegate: MenuItem {
                                    required property string modelData
                                    text: Translation.tr("Add to ") + root._zoneLabel(modelData)
                                    icon.name: root._zoneIcon(modelData)
                                    onTriggered: root._addToZone(chip.moduleId, modelData, -1)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
