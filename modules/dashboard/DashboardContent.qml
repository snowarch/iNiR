pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import qs.modules.sidebarRight.events

/**
 * Dashboard hub composition. Three widget columns driven by
 * Config.options.dashboard.layout.{left,center,right} — same modular pattern
 * as bar.layout: the arrays are the source of truth, any widget id can live
 * in any column, empty columns collapse.
 */
Item {
    id: root
    property int screenWidth: 1920
    property int screenHeight: 1080

    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool angelEverywhere: Appearance.angelEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere
    readonly property bool zzzEverywhere: Appearance.zzzEverywhere
    readonly property bool showHeader: Config.options?.dashboard?.showHeader ?? true

    // ═══ Modular widget registry ═══════════════════════════════════════
    readonly property var _widgetMap: ({
        "welcome": welcomeComponent,
        "clock": clockComponent,
        "weather": weatherComponent,
        "calendar": calendarComponent,
        "media": mediaComponent,
        "notifications": notificationsComponent,
        "todo": todoComponent,
        "system": systemComponent,
        "github": githubComponent,
        "agenda": agendaComponent,
        "notes": notesComponent,
    })
    // Widgets that absorb the column's remaining height. Kept minimal: only the
    // notepad (a writing surface) benefits from stretching. List widgets size to
    // their content instead — compact when empty, growing (and scrolling the
    // column) when full — so a column never shows two half-empty stretched cards.
    readonly property var _fillIds: ["notes"]

    // ═══ Shared events dialog (agenda + calendar widgets) ══════════════
    property var _agendaEditEvent: null
    property var _agendaPrefillDate: null
    property bool _agendaDialogShown: false
    property bool _agendaDialogLoaded: false
    // Accepts: an event object (edit), a Date (new event prefilled to that day),
    // or null (blank new event). Calendar day-clicks pass a Date; agenda rows
    // pass the event — both land in one shared dialog.
    function openAgendaDialog(arg) {
        const isDate = arg instanceof Date
        root._agendaEditEvent = (arg && !isDate) ? arg : null
        root._agendaPrefillDate = isDate ? arg : null
        root._agendaDialogLoaded = true
        if (agendaDialogLoader.item) {
            if (root._agendaEditEvent) agendaDialogLoader.item.loadEvent(root._agendaEditEvent)
            else {
                agendaDialogLoader.item.resetForm()
                if (root._agendaPrefillDate) agendaDialogLoader.item.eventDate = root._agendaPrefillDate
            }
        }
        root._agendaDialogShown = true
    }

    function _column(name, fallback) {
        // Respect a stored column even when empty (user cleared it in edit mode);
        // fall back only when the key is absent entirely.
        const a = Config.options?.dashboard?.layout?.[name]
        return (a && a.length >= 0) ? a : fallback
    }

    // ═══ In-panel edit mode — direct manipulation ══════════════════════
    // Edit mode turns the REAL widget cards into draggable tiles, pointer-
    // driven (preventStealing MouseArea + floating ghost + geometry hit-test) —
    // the engine proven in DashLayoutEditor, no Qt Drag/DropArea. The separate
    // editor sheet is gone from the panel; Settings still embeds DashLayoutEditor
    // for the same Config.dashboard.layout model.
    property bool editMode: false
    onEditModeChanged: if (!editMode) root._endDrag()

    readonly property string availableZone: "__available__"
    readonly property var zones: ["left", "center", "right"]
    readonly property var _defaults: ({
        left: ["welcome", "clock", "system"],
        center: ["notifications", "todo"],
        right: ["media", "weather", "calendar"]
    })
    // Mirror of DashLayoutEditor.catalog (icon + tr label). Kept local so the
    // i18n extractor still sees the literal tr() strings — same msgids → shared
    // translations. Add a widget → update BOTH catalogs.
    readonly property var _catalog: ({
        welcome:       { icon: "waving_hand",       label: Translation.tr("Welcome") },
        clock:         { icon: "schedule",          label: Translation.tr("Clock") },
        system:        { icon: "monitoring",        label: Translation.tr("System usage") },
        github:        { icon: "deployed_code",     label: Translation.tr("GitHub activity") },
        notifications: { icon: "notifications",     label: Translation.tr("Notifications") },
        todo:          { icon: "checklist",         label: Translation.tr("To Do") },
        media:         { icon: "music_note",        label: Translation.tr("Media player") },
        weather:       { icon: "partly_cloudy_day", label: Translation.tr("Weather") },
        calendar:      { icon: "calendar_month",    label: Translation.tr("Calendar") },
        agenda:        { icon: "event_upcoming",    label: Translation.tr("Agenda") },
        notes:         { icon: "edit_note",         label: Translation.tr("Notes") }
    })
    readonly property var _allIds: ["welcome", "clock", "system", "github", "notifications", "todo", "media", "weather", "calendar", "agenda", "notes"]
    function _icon(id) { return (root._catalog[id]?.icon) ?? "widgets" }
    function _label(id) { return (root._catalog[id]?.label) ?? id }

    readonly property var leftIds: root._column("left", root._defaults.left)
    readonly property var centerIds: root._column("center", root._defaults.center)
    readonly property var rightIds: root._column("right", root._defaults.right)

    function _zoneItems(name) { return root._column(name, root._defaults[name] ?? []) }
    function _placedIds() {
        let s = []
        for (const z of root.zones) s = s.concat(root._zoneItems(z))
        return s
    }
    readonly property var availableIds: root._allIds.filter(id => root._placedIds().indexOf(id) === -1)

    // ─── Per-leaf Config mutators (never assign a whole layout object) ───
    function _addToZone(id, toZone, atIndex) {
        const dst = root._zoneItems(toZone).slice()
        if (dst.indexOf(id) !== -1) return
        const idx = (atIndex === undefined || atIndex < 0) ? dst.length : Math.max(0, Math.min(atIndex, dst.length))
        dst.splice(idx, 0, id)
        Config.setNestedValue("dashboard.layout." + toZone, dst)
    }
    function _removeFrom(zone, idx) {
        const arr = root._zoneItems(zone).slice()
        arr.splice(idx, 1)
        Config.setNestedValue("dashboard.layout." + zone, arr)
    }
    function _dropMove(srcZone, srcIdx, srcId, dstZone, dstIdx) {
        if (srcZone === root.availableZone) { root._addToZone(srcId, dstZone, dstIdx); return }
        if (srcZone === dstZone) {
            const arr = root._zoneItems(srcZone).slice()
            const [m] = arr.splice(srcIdx, 1)
            arr.splice(Math.max(0, Math.min(dstIdx, arr.length)), 0, m)
            Config.setNestedValue("dashboard.layout." + srcZone, arr)
        } else {
            const src = root._zoneItems(srcZone).slice()
            const dst = root._zoneItems(dstZone).slice()
            const [m] = src.splice(srcIdx, 1)
            dst.splice(Math.max(0, Math.min(dstIdx, dst.length)), 0, m)
            let u = {}
            u["dashboard.layout." + srcZone] = src
            u["dashboard.layout." + dstZone] = dst
            Config.setNestedValues(u)
        }
    }
    function _resetLayout() {
        Config.setNestedValues({
            "dashboard.layout.left": root._defaults.left,
            "dashboard.layout.center": root._defaults.center,
            "dashboard.layout.right": root._defaults.right
        })
    }

    // ─── Drag state (pointer-driven, operates on the real cards) ────────
    property var dragInfo: null        // { zone, index, id } of the lifted card
    property string dragId: ""
    property string dropZone: ""
    property int dropIndex: -1
    property bool dragging: false
    property point dragScene: Qt.point(0, 0)   // cursor position in root coords
    readonly property real rowGap: 12          // == column spacing
    readonly property real dragThreshold: 6

    // Cursor (root coords) → {dropZone, dropIndex}, hit-testing the real columns
    // then the tray. The 3 columns answer their own geometry queries.
    function _updateDrop(sp) {
        const cols = [leftCol, centerCol, rightCol]
        for (const c of cols) {
            if (c && c.visible && c.containsScene(sp)) {
                root.dropZone = c.zoneName
                root.dropIndex = c.dropIndexForScene(sp)
                return
            }
        }
        if (availTray && availTray.visible && availTray.containsScene(sp)) {
            root.dropZone = root.availableZone; root.dropIndex = -1; return
        }
        root.dropZone = ""; root.dropIndex = -1
    }
    function _arm(zone, index, id) {
        // Record intent on press; the drag only begins past the threshold so a
        // plain tap (chip add, hide button) is never hijacked.
        root.dragInfo = { zone: zone, index: index, id: id }; root.dragId = id; root.dragging = false
    }
    function _begin(sp) { root.dragging = true; root.dragScene = sp; root._updateDrop(sp) }
    function _move(sp) { root.dragScene = sp; root._updateDrop(sp) }
    function _commit() {
        if (root.dragging && root.dragInfo) {
            if (root.dropZone === root.availableZone) {
                if (root.dragInfo.zone !== root.availableZone) root._removeFrom(root.dragInfo.zone, root.dragInfo.index)
            } else if (root.dropZone !== "" && root.dropIndex >= 0) {
                root._dropMove(root.dragInfo.zone, root.dragInfo.index, root.dragInfo.id, root.dropZone, root.dropIndex)
            }
        }
        root._endDrag()
    }
    function _endDrag() { root.dragInfo = null; root.dragId = ""; root.dragging = false; root.dropZone = ""; root.dropIndex = -1 }

    Component { id: welcomeComponent; DashWelcome {} }
    Component { id: clockComponent; DashClock {} }
    Component { id: weatherComponent; DashWeather {} }
    Component {
        id: calendarComponent
        DashCalendar {
            onRequestEventsDialog: arg => root.openAgendaDialog(arg)
        }
    }
    Component { id: mediaComponent; DashMedia {} }
    Component { id: notificationsComponent; DashNotifications {} }
    Component { id: todoComponent; DashTodo {} }
    Component { id: systemComponent; DashSystem {} }
    Component { id: githubComponent; DashGithub {} }
    Component { id: notesComponent; DashNotes {} }
    Component {
        id: agendaComponent
        DashAgenda {
            onRequestEventsDialog: evt => root.openAgendaDialog(evt)
        }
    }

    readonly property string wallpaperUrl: Wallpapers.effectiveWallpaperUrl
    readonly property bool useWallpaperBackdrop: root.auroraEverywhere && !root.inirEverywhere && !Appearance.gameModeMinimal && root.wallpaperUrl.length > 0

    ColorQuantizer {
        id: wallpaperColorQuantizer
        source: (Appearance.auroraEverywhere || Appearance.angelEverywhere) ? root.wallpaperUrl : ""
        depth: 0
        rescaleSize: 10
    }

    readonly property color wallpaperDominantColor: (wallpaperColorQuantizer?.colors?.[0] ?? Appearance.colors.colPrimary)
    readonly property QtObject blendedColors: AdaptedMaterialScheme {
        color: ColorUtils.mix(root.wallpaperDominantColor, Appearance.colors.colPrimaryContainer, 0.8) || Appearance.colors.colSecondaryContainer
    }

    // Shadow
    StyledRectangularShadow {
        target: background
        visible: (Appearance.angelEverywhere || (!root.inirEverywhere && !root.auroraEverywhere)) && !Appearance.gameModeMinimal
    }

    ZzzPlate {
        anchors.fill: background
        visible: Appearance.zzzEverywhere
        fillColor: Appearance.colors.colLayer0
        strokeColor: Appearance.zzz.hairlineStrong
        strokeWidth: Appearance.zzz.hairlineThick
        chamfer: Appearance.zzz.cutCorner
    }

    Rectangle {
        id: background
        anchors.fill: parent

        color: Appearance.zzzEverywhere ? "transparent"
             : root.inirEverywhere ? Appearance.inir.colLayer0
             : root.auroraEverywhere ? ColorUtils.applyAlpha((root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0), 1)
             : Appearance.colors.colLayer0

        radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
            : root.angelEverywhere ? Appearance.angel.roundingLarge
            : root.inirEverywhere ? Appearance.inir.roundingLarge
            : Appearance.rounding.large

        border.width: Appearance.zzzEverywhere ? 0 : 1
        border.color: Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong
                    : root.angelEverywhere ? Appearance.angel.colBorder
                    : root.inirEverywhere ? Appearance.inir.colBorder
                    : root.auroraEverywhere ? Appearance.aurora.colTooltipBorder
                    : Appearance.colors.colLayer0Border

        Behavior on radius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on border.width {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        clip: true

        // ZZZ: mask to rounded shape so children never re-square the corners.
        layer.enabled: root.useWallpaperBackdrop || (root.zzzEverywhere && !Appearance.gameModeMinimal)
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: background.width
                height: background.height
                radius: background.radius
            }
        }

        // Aurora blurred wallpaper backdrop
        Image {
            id: blurredWallpaper
            anchors.centerIn: parent
            width: root.screenWidth
            height: root.screenHeight
            visible: root.useWallpaperBackdrop
            source: root.useWallpaperBackdrop ? root.wallpaperUrl : ""
            fillMode: Image.PreserveAspectCrop
            cache: true
            sourceSize.width: root.screenWidth
            sourceSize.height: root.screenHeight
            asynchronous: true

            layer.enabled: Appearance.effectsEnabled && root.auroraEverywhere && !root.inirEverywhere
            layer.effect: MultiEffect {
                source: blurredWallpaper
                anchors.fill: source
                saturation: root.angelEverywhere
                    ? Appearance.angel.blurSaturation
                    : (Appearance.effectsEnabled ? 0.2 : 0)
                blurEnabled: Appearance.effectsEnabled
                blurMax: 64
                blur: Appearance.effectsEnabled ? 1 : 0
            }

            Rectangle {
                anchors.fill: parent
                color: root.angelEverywhere
                    ? ColorUtils.transparentize((root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.angel.overlayOpacity)
                    : ColorUtils.transparentize((root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), Appearance.aurora.overlayTransparentize)
            }
        }

        // Angel inset glow — top edge
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Appearance.angel.insetGlowHeight
            visible: root.angelEverywhere
            color: Appearance.angel.colInsetGlow
            z: 10
        }

        ZzzPanelBackdrop {
            anchors.fill: parent
            label: "AUTONOMIC STRIDER"
            index: "52"
            ghostText: "DASH"
            accentColor: Appearance.zzz.accent
            burstTriad: true
            burstScale: 0.52
            showTicks: false
            showGrid: false
            horizontalBias: 0.1
            verticalBias: -0.06
            ghostWidthFactor: 0.78
            ghostStrength: 0.7
            z: 0
        }

        ColumnLayout {
            readonly property bool compact: (Config.options?.dashboard?.appearance?.density ?? "comfortable") === "compact"
            anchors.fill: parent
            anchors.margins: compact ? 12 : 16
            spacing: compact ? 8 : 12

            Loader {
                Layout.fillWidth: true
                active: root.showHeader
                visible: active
                sourceComponent: DashboardHeader {}
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 12

                // A column is a scrollable stack: cards keep their natural height
                // (never squished), the stack FILLS the viewport when content fits
                // (fill-widgets stretch) and GROWS + scrolls when it doesn't — so an
                // overloaded column never collides or spills out of the panel.
                component WidgetColumn: Item {
                    id: widgetColumn
                    property var ids: []
                    property string zoneName: "center"
                    property real widthWeight: 1
                    readonly property bool hasFill: ids.some(id => root._fillIds.indexOf(id) !== -1)
                    readonly property bool dropActive: root.dragging && root.dropZone === zoneName
                    visible: ids.length > 0 || root.editMode
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 100 * widthWeight

                    // Cursor (root coords) inside this column's viewport?
                    function containsScene(sp) {
                        const o = colFlick.mapToItem(root, 0, 0)
                        return sp.x >= o.x && sp.x <= o.x + colFlick.width
                            && sp.y >= o.y && sp.y <= o.y + colFlick.height
                    }
                    // Live (non-source) card wrappers, in model order.
                    function _liveCards() {
                        const out = []
                        for (let i = 0; i < colStack.children.length; i++) {
                            const ch = colStack.children[i]
                            if (ch && ch._isCard && !ch.isSource) out.push(ch)
                        }
                        out.sort((a, b) => a.cardIndex - b.cardIndex)
                        return out
                    }
                    // Insert index for a cursor point (root coords), by card midpoint.
                    function dropIndexForScene(sp) {
                        const p = root.mapToItem(colStack, sp.x, sp.y)
                        const cards = widgetColumn._liveCards()
                        let i = 0
                        for (const c of cards) { if (p.y < c.y + c.height / 2) return i; i++ }
                        return i
                    }
                    // Y (colStack coords) of the drop indicator for an insert index.
                    function slotY(idx) {
                        const cards = widgetColumn._liveCards()
                        if (cards.length === 0) return 2
                        if (idx <= 0) return Math.max(0, cards[0].y - root.rowGap / 2)
                        if (idx >= cards.length) { const l = cards[cards.length - 1]; return l.y + l.height + root.rowGap / 2 }
                        return cards[idx].y - root.rowGap / 2
                    }

                    StyledFlickable {
                        id: colFlick
                        anchors.fill: parent
                        contentWidth: width
                        contentHeight: contentWrap.height
                        clip: true

                        Item {
                            id: contentWrap
                            width: colFlick.width
                            height: colStack.height

                            ColumnLayout {
                                id: colStack
                                width: contentWrap.width
                                // Fill the viewport when content fits, grow past it (→ scroll)
                                // when it doesn't. Never below content's natural height.
                                height: Math.max(colFlick.height, implicitHeight)
                                spacing: root.rowGap

                                Repeater {
                                    model: widgetColumn.ids
                                    delegate: Item {
                                        id: cardWrap
                                        required property string modelData
                                        required property int index
                                        readonly property bool _isCard: true
                                        readonly property int cardIndex: index
                                        readonly property bool isSource: root.dragging && root.dragInfo
                                            && root.dragInfo.zone === widgetColumn.zoneName && root.dragInfo.index === index
                                        property point _pressScene: Qt.point(0, 0)

                                        Layout.fillWidth: true
                                        Layout.fillHeight: !isSource && root._fillIds.indexOf(modelData) !== -1
                                        implicitHeight: cardLoader.implicitHeight
                                        // Collapse out of flow while lifted, so the column
                                        // reflows to live order and drop-slot math stays exact.
                                        Layout.preferredHeight: isSource ? 0 : implicitHeight
                                        opacity: isSource ? 0 : 1
                                        visible: cardLoader.sourceComponent !== null
                                        clip: true
                                        Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }

                                        Loader {
                                            id: cardLoader
                                            width: cardWrap.width
                                            height: cardWrap.height
                                            sourceComponent: root._widgetMap[cardWrap.modelData] ?? null
                                            // Live widget stops taking input while editing so
                                            // the drag gesture owns the card; dims slightly.
                                            enabled: !root.editMode
                                            opacity: root.editMode ? 0.9 : 1
                                            Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                                        }

                                        // Editable outline — accents on hover.
                                        Rectangle {
                                            anchors.fill: parent
                                            visible: root.editMode && !cardWrap.isSource
                                            color: dragMa.containsMouse
                                                ? ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 0.82)
                                                : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 0.9)
                                            radius: Appearance.rounding.normal
                                            border.width: dragMa.containsMouse ? 1 : 0
                                            border.color: Appearance.colors.colPrimary
                                            Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                                            Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                                        }

                                        MouseArea {
                                            id: dragMa
                                            anchors.fill: parent
                                            enabled: root.editMode
                                            hoverEnabled: true
                                            // preventStealing: the card sits inside the column
                                            // Flickable; without this the scroll steals the drag.
                                            preventStealing: true
                                            cursorShape: (root.dragging && cardWrap.isSource) ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                            onPressed: mouse => {
                                                cardWrap._pressScene = mapToItem(root, mouse.x, mouse.y)
                                                root._arm(widgetColumn.zoneName, cardWrap.cardIndex, cardWrap.modelData)
                                            }
                                            onPositionChanged: mouse => {
                                                if (!root.dragInfo) return
                                                const sp = mapToItem(root, mouse.x, mouse.y)
                                                if (!root.dragging) {
                                                    if (Math.hypot(sp.x - cardWrap._pressScene.x, sp.y - cardWrap._pressScene.y) < root.dragThreshold) return
                                                    root._begin(sp)
                                                } else root._move(sp)
                                            }
                                            onReleased: { if (root.dragging) root._commit(); else root._endDrag() }
                                            onCanceled: root._endDrag()
                                        }

                                        // Grab hint (top-left).
                                        Rectangle {
                                            anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 6
                                            visible: root.editMode && !cardWrap.isSource && !root.dragging
                                            implicitWidth: 26; implicitHeight: 26
                                            radius: Appearance.rounding.full
                                            color: Appearance.colors.colPrimaryContainer
                                            z: 5
                                            MaterialSymbol { anchors.centerIn: parent; text: "drag_indicator"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnPrimaryContainer }
                                        }
                                        // Hide button (top-right).
                                        RippleButton {
                                            anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 6
                                            visible: root.editMode && !cardWrap.isSource && !root.dragging
                                            implicitWidth: 26; implicitHeight: 26
                                            buttonRadius: Appearance.rounding.full
                                            colBackground: Appearance.colors.colLayer2
                                            z: 5
                                            onClicked: root._removeFrom(widgetColumn.zoneName, cardWrap.cardIndex)
                                            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }
                                            StyledToolTip { text: Translation.tr("Hide from dashboard") }
                                        }
                                    }
                                }

                                // Soak up slack so cards stay top-aligned when none fills.
                                Item {
                                    Layout.fillHeight: true
                                    visible: !widgetColumn.hasFill
                                }
                            }

                            // Empty-column drop hint (edit mode only).
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                visible: widgetColumn.ids.length === 0 && root.editMode
                                radius: Appearance.rounding.normal
                                color: widgetColumn.dropActive ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9) : "transparent"
                                border.width: 1
                                border.color: widgetColumn.dropActive ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                                Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    MaterialSymbol { Layout.alignment: Qt.AlignHCenter; text: widgetColumn.dropActive ? "download" : "add"; iconSize: Appearance.font.pixelSize.larger; color: widgetColumn.dropActive ? Appearance.colors.colPrimary : Appearance.colors.colSubtext }
                                    StyledText { Layout.alignment: Qt.AlignHCenter; text: widgetColumn.dropActive ? Translation.tr("Release to drop") : Translation.tr("Drop widgets here"); font.pixelSize: Appearance.font.pixelSize.smaller; color: widgetColumn.dropActive ? Appearance.colors.colPrimary : Appearance.colors.colSubtext }
                                }
                            }

                            // Drop indicator — animates between insert positions.
                            Rectangle {
                                id: dropSlot
                                visible: widgetColumn.dropActive && root.dropIndex >= 0 && widgetColumn.ids.length > 0
                                x: 2
                                width: contentWrap.width - 4
                                height: 3
                                radius: 2
                                color: Appearance.colors.colPrimary
                                y: widgetColumn.slotY(root.dropIndex)
                                z: 40
                                Behavior on y { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                                Rectangle { width: 8; height: 8; radius: 4; color: parent.color; anchors.verticalCenter: parent.verticalCenter; x: -3 }
                                Rectangle { width: 8; height: 8; radius: 4; color: parent.color; anchors.verticalCenter: parent.verticalCenter; x: parent.width - 5 }
                            }
                        }
                    }
                }

                // Side/center weights follow the reference composition (27/46/27)
                WidgetColumn { id: leftCol; ids: root.leftIds; zoneName: "left"; widthWeight: 27 }
                WidgetColumn { id: centerCol; ids: root.centerIds; zoneName: "center"; widthWeight: 46 }
                WidgetColumn { id: rightCol; ids: root.rightIds; zoneName: "right"; widthWeight: 27 }
            }
        }

        // Hidden-widgets tray — edit mode only. Tap a chip to add it to the
        // emptiest column, or drag it onto a column. Doubles as the remove
        // target: drag a placed card here to hide it. Morphs up from the bottom.
        Rectangle {
            id: availTray
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 14
            anchors.rightMargin: 64
            anchors.bottomMargin: 14
            z: 22
            visible: opacity > 0
            opacity: root.editMode ? 1 : 0
            implicitHeight: trayCol.implicitHeight + 20
            radius: root.inirEverywhere ? Appearance.inir.roundingLarge : Appearance.rounding.large
            color: root.inirEverywhere ? Appearance.inir.colLayer1 : Appearance.colors.colLayer1
            border.width: 1
            readonly property bool removeActive: root.dragging && root.dragInfo
                && root.dragInfo.zone !== root.availableZone && root.dropZone === root.availableZone
            border.color: removeActive ? Appearance.colors.colError
                : (root.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border)
            // Grow from the bottom edge (origin) — organic morph.
            transform: Translate { y: root.editMode ? 0 : 20 }
            Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
            Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

            function containsScene(sp) {
                const o = availTray.mapToItem(root, 0, 0)
                return sp.x >= o.x && sp.x <= o.x + availTray.width && sp.y >= o.y && sp.y <= o.y + availTray.height
            }

            StyledRectangularShadow { target: availTray }
            MouseArea { anchors.fill: parent } // swallow background clicks

            ColumnLayout {
                id: trayCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Rectangle {
                        implicitWidth: 24; implicitHeight: 24
                        radius: Appearance.rounding.full
                        color: ColorUtils.transparentize(availTray.removeActive ? Appearance.colors.colError : Appearance.colors.colPrimary, 0.85)
                        MaterialSymbol { anchors.centerIn: parent; text: availTray.removeActive ? "delete" : "add_box"; iconSize: Appearance.font.pixelSize.small; color: availTray.removeActive ? Appearance.colors.colError : Appearance.colors.colPrimary }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: availTray.removeActive ? Translation.tr("Release to hide")
                            : (root.availableIds.length > 0 ? Translation.tr("Hidden widgets — tap or drag to add") : Translation.tr("All widgets shown"))
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: availTray.removeActive ? Appearance.colors.colError : Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                    }
                    RippleButton {
                        implicitWidth: 28; implicitHeight: 28
                        buttonRadius: Appearance.rounding.full
                        onClicked: root._resetLayout()
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "restart_alt"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1 }
                        StyledToolTip { text: Translation.tr("Reset dashboard layout") }
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
                            readonly property bool isSource: root.dragging && root.dragInfo
                                && root.dragInfo.zone === root.availableZone && root.dragInfo.id === modelData
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
                                    root._arm(root.availableZone, -1, chip.modelData)
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
                                    for (const z of root.zones) { const n = root._zoneItems(z).length; if (n < best) { best = n; target = z } }
                                    root._addToZone(chip.modelData, target, -1)
                                }
                            }

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6
                                MaterialSymbol { text: root._icon(chip.modelData); iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1 }
                                StyledText { text: root._label(chip.modelData); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer1 }
                                MaterialSymbol { text: "add"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colSubtext }
                            }
                        }
                    }
                }
            }
        }

        // Floating drag ghost — follows the cursor above every column and the tray.
        Item {
            anchors.fill: parent
            z: 60
            visible: root.dragging
            Rectangle {
                id: ghost
                visible: root.dragging && root.dragId.length > 0
                width: 184
                height: 46
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer2
                border.color: Appearance.colors.colPrimary
                border.width: 1
                opacity: root.dragging ? 0.97 : 0
                scale: root.dragging ? 1.0 : 0.92
                rotation: root.dragging ? 1.0 : 0
                x: root.dragScene.x - width / 2
                y: root.dragScene.y - height / 2
                Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                Behavior on scale { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                Behavior on rotation { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                StyledRectangularShadow { target: ghost; z: -1 }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8
                    MaterialSymbol { text: "drag_indicator"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colSubtext }
                    MaterialSymbol { text: root._icon(root.dragId); iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnLayer2 }
                    StyledText { Layout.fillWidth: true; text: root._label(root.dragId); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer2; elide: Text.ElideRight }
                }
            }
        }

        // Edit-mode toggle: morphs between edit and done
        RippleButton {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 14
            z: 25
            implicitWidth: 40
            implicitHeight: 40
            buttonRadius: root.editMode ? Appearance.rounding.normal : Appearance.rounding.full
            Behavior on buttonRadius {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            colBackground: root.editMode ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
            colBackgroundHover: root.editMode ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover
            colRipple: root.editMode ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer2Active
            onClicked: root.editMode = !root.editMode
            StyledToolTip { text: root.editMode ? Translation.tr("Done") : Translation.tr("Edit layout") }
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: root.editMode ? "done" : "edit"
                iconSize: Appearance.font.pixelSize.larger
                color: root.editMode ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // Events dialog overlay (created on first use, covers the panel)
        Loader {
            id: agendaDialogLoader
            anchors.fill: parent
            z: 30
            active: root._agendaDialogLoaded
            sourceComponent: EventsDialog {}
            onLoaded: {
                item.show = Qt.binding(() => root._agendaDialogShown)
                if (root._agendaEditEvent) item.loadEvent(root._agendaEditEvent)
                else {
                    item.resetForm()
                    if (root._agendaPrefillDate) item.eventDate = root._agendaPrefillDate
                }
                item.forceActiveFocus()
            }
            Connections {
                target: agendaDialogLoader.item
                function onDismiss() { root._agendaDialogShown = false }
            }
        }
    }
}
