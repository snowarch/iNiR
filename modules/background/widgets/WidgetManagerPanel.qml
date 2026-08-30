pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    // Canvas bounds for clamping
    property real canvasWidth: 800
    property real canvasHeight: 600
    required property string outputName
    signal closeRequested()
    signal focusWidgetRequested(string layoutKey)

    property string searchText: ""
    readonly property string filterMode: Persistent.states?.desktopWidgets?.managerFilter ?? "all"
    readonly property var _builtinWidgets: [
        { key: "clock", icon: "schedule", label: "Clock", defaultEnabled: true },
        { key: "weather", icon: "cloud", label: "Weather", defaultEnabled: false },
        { key: "customImage", icon: "add_photo_alternate", label: "Custom image", defaultEnabled: false },
        { key: "imageConverter", icon: "transform", label: "Image converter", defaultEnabled: false },
        { key: "mediaControls", icon: "album", label: "Media Controls", defaultEnabled: false },
        { key: "visualizer", icon: "graphic_eq", label: "Visualizer", defaultEnabled: false },
        { key: "systemMonitor", icon: "monitor_heart", label: "System Monitor", defaultEnabled: false },
        { key: "battery", icon: "battery_full", label: "Battery", defaultEnabled: false },
        { key: "notes", icon: "sticky_note_2", label: "Notes", defaultEnabled: false },
        { key: "calendarUpcoming", icon: "event", label: "Upcoming Events", defaultEnabled: false },
        { key: "uptime", icon: "avg_pace", label: "System uptime", defaultEnabled: false },
        { key: "newsTicker", icon: "newspaper", label: "News Ticker", defaultEnabled: false },
        { key: "mascot", icon: "pets", label: "Mascot", defaultEnabled: false },
        { key: "japaneseTypography", icon: "translate", label: "Japanese Typography", defaultEnabled: false },
        { key: "worldClock", icon: "public", label: "World clock", defaultEnabled: false },
        { key: "userCard", icon: "account_circle", label: "User card", defaultEnabled: false }
    ]

    function _setFilter(value: string): void {
        const next = ["all", "active", "locked", "custom"].includes(value) ? value : "all"
        if (Persistent.states?.desktopWidgets)
            Persistent.states.desktopWidgets.managerFilter = next
    }

    function _matchesSearch(label: string): bool {
        const query = root.searchText.trim().toLowerCase()
        return query.length === 0 || String(label ?? "").toLowerCase().includes(query)
    }

    function _cardVisible(label: string, enabled: bool, locked: bool, custom: bool): bool {
        if (!root._matchesSearch(label))
            return false
        switch (root.filterMode) {
        case "active": return enabled
        case "locked": return enabled && locked
        case "custom": return custom
        default: return true
        }
    }

    function _builtinState(item): var {
        const prefix = "background.widgets." + item.key
        return {
            enabled: DesktopWidgetLayout.enabled(root.outputName, item.key,
                Config.getNestedValue(prefix + ".enable", item.defaultEnabled)),
            locked: Boolean(DesktopWidgetLayout.value(root.outputName, item.key, "locked",
                Config.getNestedValue(prefix + ".locked", false)))
        }
    }

    readonly property int _activeCount: {
        Config.revision
        let count = 0
        for (const item of root._builtinWidgets) {
            if (root._builtinState(item).enabled)
                count++
        }
        for (const id of root._mascotInstanceIds) {
            if (DesktopWidgetLayout.enabled(root.outputName, "mascotInstances." + id, true))
                count++
        }
        if (CustomWidgets.ready) {
            for (const item of CustomWidgets.widgets) {
                if (DesktopWidgetLayout.enabled(root.outputName, "custom." + item.id,
                        Config.getNestedValue("background.widgets.custom." + item.id + ".enable", false)))
                    count++
            }
        }
        return count
    }

    readonly property int _builtinVisibleCount: {
        Config.revision
        let count = 0
        for (const item of root._builtinWidgets) {
            const state = root._builtinState(item)
            if (root._cardVisible(Translation.tr(item.label), state.enabled, state.locked, false))
                count++
        }
        return count
    }

    readonly property int _mascotVisibleCount: {
        Config.revision
        let count = 0
        for (let i = 0; i < root._mascotInstanceIds.length; ++i) {
            const id = root._mascotInstanceIds[i]
            const key = "mascotInstances." + id
            const prefix = "background.widgets.mascotInstances." + id
            const enabled = DesktopWidgetLayout.enabled(root.outputName, key,
                Config.getNestedValue(prefix + ".enable", true))
            const locked = Boolean(DesktopWidgetLayout.value(root.outputName, key, "locked",
                Config.getNestedValue(prefix + ".locked", false)))
            if (root._cardVisible(Translation.tr("Mascot") + " #" + (i + 1), enabled, locked, false))
                count++
        }
        return count
    }

    readonly property int _customVisibleCount: {
        Config.revision
        if (!CustomWidgets.ready)
            return 0
        let count = 0
        for (const item of CustomWidgets.widgets) {
            const key = "custom." + item.id
            const prefix = "background.widgets.custom." + item.id
            const enabled = DesktopWidgetLayout.enabled(root.outputName, key,
                Config.getNestedValue(prefix + ".enable", false))
            const locked = Boolean(DesktopWidgetLayout.value(root.outputName, key, "locked",
                Config.getNestedValue(prefix + ".locked", false)))
            if (root._cardVisible(item.name, enabled, locked, true))
                count++
        }
        return count
    }

    readonly property int _visibleCardCount: root._builtinVisibleCount
        + root._mascotVisibleCount + root._customVisibleCount

    // Output geometry for the glass backdrop. This panel floats straight on the
    // wallpaper, so under aurora and angel its translucent fill needs the blurred
    // crop behind it — without one the wallpaper reads through sharp.
    property real screenWidth: 1920
    property real screenHeight: 1080
    readonly property bool _widgetBlurAvailable: Appearance.effectsEnabled
        && (Appearance.angelEverywhere
            || (Appearance.auroraEverywhere && !Appearance.inirEverywhere)
            || (!Appearance.zzzEverywhere && !Appearance.cookieEverywhere
                && !Appearance.angelEverywhere && !Appearance.auroraEverywhere
                && !Appearance.inirEverywhere
                && (Config.options?.background?.widgets?.style ?? "panel") === "island"
                && (Config.options?.appearance?.island?.glass ?? true)
                && (Config.options?.appearance?.island?.opacity ?? 1) < 0.999))

    function _manifestSupportsSurface(configKeys) {
        const keys = configKeys ?? {};
        return ["showBackground", "backgroundOpacity", "useBlur", "showBorder",
            "borderWidth", "borderOpacity", "cornerRadius"].some(key => keys[key] !== undefined);
    }

    // Size constraints
    readonly property int _minWidth: 360
    readonly property int _maxWidth: Math.min(720, Math.max(_minWidth, root.canvasWidth - 24))
    readonly property int _minHeight: 280
    readonly property int _maxHeight: Math.min(820, Math.max(_minHeight, root.canvasHeight - 24))

    width: _panelWidth
    height: _panelHeight

    property int _panelWidth: Math.max(_minWidth, Math.min(_maxWidth,
        Persistent.states?.desktopWidgets?.managerWidth ?? 440))
    property int _panelHeight: Math.max(_minHeight, Math.min(_maxHeight,
        Persistent.states?.desktopWidgets?.managerHeight ?? 520))

    function persistGeometry(): void {
        if (!Persistent.states?.desktopWidgets || !root.parent)
            return
        const maxX = Math.max(1, root.canvasWidth - root.width)
        const maxY = Math.max(1, root.canvasHeight - root.height)
        Persistent.states.desktopWidgets.managerXRatio = Math.max(0, Math.min(1,
            Number(root.parent.x) / maxX))
        Persistent.states.desktopWidgets.managerYRatio = Math.max(0, Math.min(1,
            Number(root.parent.y) / maxY))
        Persistent.states.desktopWidgets.managerWidth = Math.round(root.width)
        Persistent.states.desktopWidgets.managerHeight = Math.round(root.height)
    }

    function clampToCanvas(): void {
        root._panelWidth = Math.max(root._minWidth,
            Math.min(root._maxWidth, root._panelWidth))
        root._panelHeight = Math.max(root._minHeight,
            Math.min(root._maxHeight, root._panelHeight))
        if (!root.parent)
            return
        root.parent.x = Math.max(0, Math.min(root.canvasWidth - root.width,
            Number(root.parent.x) || 0))
        root.parent.y = Math.max(0, Math.min(root.canvasHeight - root.height,
            Number(root.parent.y) || 0))
    }

    onCanvasWidthChanged: Qt.callLater(root.clampToCanvas)
    onCanvasHeightChanged: Qt.callLater(root.clampToCanvas)

    readonly property bool _exampleInstalled: {
        if (!CustomWidgets.ready) return false;
        for (let i = 0; i < CustomWidgets.widgets.length; i++)
            if (CustomWidgets.widgets[i].id === "example-widget") return true;
        return false;
    }

    readonly property var _mascotInstanceIds: {
        Config.revision;
        const obj = Config.getNestedValue("background.widgets.mascotInstances", {});
        return Object.keys(obj ?? {}).sort();
    }

    // Block clicks from reaching desktop
    MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons; propagateComposedEvents: false }

    // ── Shadow + Background card ──
    StyledRectangularShadow {
        target: _bgCard
        visible: !Appearance.zzzEverywhere && !Appearance.auroraEverywhere
    }

    PanelSurface {
        id: _bgCard
        anchors.fill: parent
        elevation: 1
        wallpaperBackdrop: true
        // mapToItem is a plain call, not a tracked dependency: the panel is
        // positioned by its Loader, so the binding has to name what moves it.
        readonly property point _screenPos: {
            void root.x; void root.y; void root.width; void root.height;
            void (root.parent?.x ?? 0); void (root.parent?.y ?? 0);
            return _bgCard.mapToItem(null, 0, 0)
        }
        backdropScreenX: _screenPos.x
        backdropScreenY: _screenPos.y
        backdropScreenWidth: root.screenWidth
        backdropScreenHeight: root.screenHeight
        radiusOverride: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
            : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
            : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
            : Appearance.rounding.normal
        // No frameLabel: the header right below already titles the panel; the
        // corner tape label overlapped it (registration marks alone suffice).
        techFrame: Appearance.zzzEverywhere
    }

    // ZZZ alone owns the technical drafting language. Other global styles
    // keep this utility panel quiet instead of inheriting a foreign texture.
    DotGridCanvas {
        anchors.fill: parent
        anchors.margins: 10
        visible: Appearance.zzzEverywhere
        gridSize: 24
        dotAlpha: 0.07
    }

    // ── Header (drag handle) ──
    Item {
        id: _header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 126

        // Drag via the header — use canvas-space coords to avoid feedback loop
        MouseArea {
            id: _dragArea
            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property real _canvasStartX: 0
            property real _canvasStartY: 0
            property real _parentStartX: 0
            property real _parentStartY: 0
            onPressed: (mouse) => {
                const mapped = mapToItem(root.parent.parent, mouse.x, mouse.y);
                _canvasStartX = mapped.x;
                _canvasStartY = mapped.y;
                _parentStartX = root.parent.x;
                _parentStartY = root.parent.y;
            }
            onPositionChanged: (mouse) => {
                if (!pressed) return;
                const mapped = mapToItem(root.parent.parent, mouse.x, mouse.y);
                const dx = mapped.x - _canvasStartX;
                const dy = mapped.y - _canvasStartY;
                const newX = Math.max(0, Math.min(root.canvasWidth - root.width, _parentStartX + dx));
                const newY = Math.max(0, Math.min(root.canvasHeight - root.height, _parentStartY + dy));
                root.parent.x = Math.round(newX);
                root.parent.y = Math.round(newY);
            }
            onReleased: root.persistGeometry()
        }

        ColumnLayout {
            anchors { fill: parent; leftMargin: 14; rightMargin: 10; topMargin: 8; bottomMargin: 8 }
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                spacing: 8

                MaterialSymbol {
                    text: "widgets"
                    iconSize: 22
                    color: Appearance.colors.colPrimary
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        text: Translation.tr("Desktop Widgets")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: Translation.tr("%1 active on this display").arg(root._activeCount)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.55)
                    }
                }

                RippleButton {
                    width: 30; height: 30
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.06)
                    colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.10)
                    releaseAction: () => {
                        if (Config.options?.settingsUi?.overlayMode !== false) {
                            GlobalStates.settingsOverlayRequestedPage = 14
                            GlobalStates.settingsOverlayOpen = true
                        } else {
                            Quickshell.execDetached(["/usr/bin/env", "QS_SETTINGS_PAGE=14", Quickshell.shellPath("scripts/inir"), "settings-window"])
                        }
                    }
                    cancelAction: () => {}
                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: "settings"; iconSize: 17; color: Appearance.colors.colOnLayer1 }
                    StyledToolTip { text: Translation.tr("Open full widget settings") }
                }

                RippleButton {
                    width: 30; height: 30
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.06)
                    colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.10)
                    releaseAction: () => root.closeRequested()
                    cancelAction: () => {}
                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: "close"; iconSize: 17; color: Appearance.colors.colOnLayer1 }
                    StyledToolTip { text: Translation.tr("Close widget manager") }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                spacing: 6

                MaterialSymbol {
                    text: "search"
                    iconSize: 17
                    color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.52)
                }
                MaterialTextField {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    enableSettingsSearch: false
                    placeholderText: Translation.tr("Search widgets")
                    text: root.searchText
                    onTextChanged: if (root.searchText !== text) root.searchText = text
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }

            Row {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                spacing: 4

                Repeater {
                    model: [
                        { key: "all", label: Translation.tr("All"), icon: "apps" },
                        { key: "active", label: Translation.tr("Active"), icon: "visibility" },
                        { key: "locked", label: Translation.tr("Locked"), icon: "lock" },
                        { key: "custom", label: Translation.tr("Custom"), icon: "extension" }
                    ]
                    RippleButton {
                        id: filterButton
                        required property var modelData
                        width: filterLabel.implicitWidth + 34
                        height: 28
                        buttonRadius: Appearance.rounding.full
                        toggled: root.filterMode === modelData.key
                        colBackground: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.03)
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.07)
                        colBackgroundToggled: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.14)
                        colBackgroundToggledHover: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.20)
                        releaseAction: () => root._setFilter(filterButton.modelData.key)
                        cancelAction: () => {}
                        contentItem: Row {
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialSymbol {
                                text: filterButton.modelData.icon
                                iconSize: 13
                                color: filterButton.toggled ? Appearance.colors.colPrimary
                                    : ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.58)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                id: filterLabel
                                text: filterButton.modelData.label
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: filterButton.toggled ? Font.DemiBold : Font.Normal
                                color: filterButton.toggled ? Appearance.colors.colPrimary
                                    : ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.72)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }
        }

        // Bottom divider
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 16; rightMargin: 16 }
            height: 1
            color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.06)
        }
    }

    // ── Resize handles ──
    component ResizeEdge: MouseArea {
        id: rEdge
        z: 30
        property bool resizeLeft: false
        property bool resizeRight: false
        property bool resizeTop: false
        property bool resizeBottom: false
        property real _startMouseX: 0
        property real _startMouseY: 0
        property int _startW: 0
        property int _startH: 0
        property real _startPX: 0
        property real _startPY: 0
        cursorShape: {
            if ((resizeLeft && resizeTop) || (resizeRight && resizeBottom)) return Qt.SizeFDiagCursor;
            if ((resizeRight && resizeTop) || (resizeLeft && resizeBottom)) return Qt.SizeBDiagCursor;
            if (resizeLeft || resizeRight) return Qt.SizeHorCursor;
            return Qt.SizeVerCursor;
        }
        preventStealing: true
        onPressed: (mouse) => {
            const mapped = mapToItem(root.parent, mouse.x, mouse.y);
            _startMouseX = mapped.x;
            _startMouseY = mapped.y;
            _startW = root._panelWidth;
            _startH = root._panelHeight;
            _startPX = root.parent.x;
            _startPY = root.parent.y;
        }
        onPositionChanged: (mouse) => {
            if (!pressed) return;
            const mapped = mapToItem(root.parent, mouse.x, mouse.y);
            const dx = mapped.x - _startMouseX;
            const dy = mapped.y - _startMouseY;
            if (resizeRight) {
                const maxW = Math.max(root._minWidth,
                    Math.min(root._maxWidth, root.canvasWidth - root.parent.x))
                root._panelWidth = Math.max(root._minWidth, Math.min(maxW, _startW + dx))
            }
            if (resizeLeft) {
                const maxW = Math.max(root._minWidth,
                    Math.min(root._maxWidth, _startPX + _startW))
                const newW = Math.max(root._minWidth, Math.min(maxW, _startW - dx));
                root.parent.x = Math.round(_startPX + (_startW - newW));
                root._panelWidth = newW;
            }
            if (resizeBottom) {
                const maxH = Math.max(root._minHeight,
                    Math.min(root._maxHeight, root.canvasHeight - root.parent.y))
                root._panelHeight = Math.max(root._minHeight, Math.min(maxH, _startH + dy))
            }
            if (resizeTop) {
                const maxH = Math.max(root._minHeight,
                    Math.min(root._maxHeight, _startPY + _startH))
                const newH = Math.max(root._minHeight, Math.min(maxH, _startH - dy));
                root.parent.y = Math.round(_startPY + (_startH - newH));
                root._panelHeight = newH;
            }
        }
        onReleased: root.persistGeometry()
    }

    // Edge resize areas (6px wide)
    ResizeEdge { anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 6; resizeLeft: true }
    ResizeEdge { anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 6; resizeRight: true }
    ResizeEdge { anchors { top: parent.top; left: parent.left; right: parent.right } height: 6; resizeTop: true }
    ResizeEdge { anchors { bottom: parent.bottom; left: parent.left; right: parent.right } height: 6; resizeBottom: true }
    // Corner resize areas
    ResizeEdge { anchors { left: parent.left; top: parent.top } width: 12; height: 12; resizeLeft: true; resizeTop: true }
    ResizeEdge { anchors { right: parent.right; top: parent.top } width: 12; height: 12; resizeRight: true; resizeTop: true }
    ResizeEdge { anchors { left: parent.left; bottom: parent.bottom } width: 12; height: 12; resizeLeft: true; resizeBottom: true }
    ResizeEdge { anchors { right: parent.right; bottom: parent.bottom } width: 14; height: 14; resizeRight: true; resizeBottom: true }

    // Visible resize affordance; the actual pointer target is the ResizeEdge
    // above it, so this adds discoverability without another gesture owner.
    Item {
        z: 29
        anchors { right: parent.right; bottom: parent.bottom; margins: 5 }
        width: 14; height: 14
        opacity: 0.42
        Repeater {
            model: 3
            Rectangle {
                required property int index
                width: 3; height: 3; radius: 1.5
                x: 2 + index * 4
                y: 10 - index * 4
                color: Appearance.colors.colOnLayer1
            }
        }
    }

    // ── Scrollable content ──
    StyledFlickable {
        id: _scrollView
        anchors { top: _header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 4 }
        contentHeight: _contentCol.implicitHeight + 16
        clip: true

        Column {
            id: _contentCol
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8; leftMargin: 12; rightMargin: 12 }
            spacing: 2

            // ── Built-in widgets ──
            StyledText {
                visible: root._builtinVisibleCount > 0
                text: Translation.tr("Built-in")
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.45)
                leftPadding: 4
                bottomPadding: 4
            }

            Repeater {
                model: root._builtinWidgets
                WidgetCard {
                    required property var modelData
                    widgetKey: modelData.key
                    widgetIcon: modelData.icon
                    widgetLabel: Translation.tr(modelData.label)
                    defaultEnabled: modelData.defaultEnabled
                }
            }

            // ── Extra mascot instances ── (each is its own WidgetCard, positioned/posed independently)
            Item { visible: (root.filterMode === "all" && root.searchText.length === 0) || root._mascotVisibleCount > 0; width: 1; height: visible ? 8 : 0 }

            Item {
                visible: (root.filterMode === "all" && root.searchText.length === 0)
                    || root._mascotVisibleCount > 0
                width: parent.width; height: visible ? 28 : 0
                StyledText {
                    text: Translation.tr("More mascots")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                    color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.45)
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 4
                }
                RippleButton {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 28; height: 28; buttonRadius: Appearance.rounding.full
                    colBackground: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.08)
                    colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.14)
                    colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                    releaseAction: () => {
                        const n = root._mascotInstanceIds.length
                        // Perch-flavored poses read as "sitting on something" out of
                        // the box, since a fresh instance usually lands on/near a widget
                        const perchPoses = ["panel-sitter", "dock-hang", "bottom-corner-lean"]
                        Config.addMascotInstance({
                            pose: perchPoses[n % perchPoses.length], placementStrategy: "free",
                            x: 160 + (n % 4) * 40, y: 360 + (n % 4) * 40,
                            contentWidth: 200
                        })
                    }
                    cancelAction: () => {}
                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: "add"; iconSize: 16; color: Appearance.colors.colPrimary }
                    StyledToolTip { text: Translation.tr("Add another mascot") }
                }
            }

            Repeater {
                model: root._mascotInstanceIds
                WidgetCard {
                    required property string modelData
                    required property int index
                    widgetKey: modelData
                    widgetIcon: "pets"
                    widgetLabel: Translation.tr("Mascot") + " #" + (index + 1)
                    defaultEnabled: true
                    isMascotInstance: true
                }
            }

            Item {
                visible: root.filterMode === "all" && root.searchText.length === 0
                    && root._mascotInstanceIds.length === 0
                width: parent.width; height: visible ? 40 : 0
                StyledText {
                    anchors.centerIn: parent
                    text: Translation.tr("Add a second, third… mascot, each posed independently")
                    color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.5)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }

            // ── Custom widgets section ──
            Item { visible: (root.filterMode === "all" && root.searchText.length === 0) || root.filterMode === "custom" || root._customVisibleCount > 0; width: 1; height: visible ? 8 : 0 }

            Item {
                visible: (root.filterMode === "all" && root.searchText.length === 0)
                    || root.filterMode === "custom" || root._customVisibleCount > 0
                width: parent.width; height: visible ? 28 : 0
                StyledText {
                    text: Translation.tr("Custom")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                    color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.45)
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 4
                }
                Row {
                    spacing: 4
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }

                    RippleButton {
                        width: 28; height: 28; buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.06)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.10)
                        releaseAction: () => CustomWidgets.reload()
                        cancelAction: () => {}
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "refresh"; iconSize: 16; color: Appearance.colors.colOnLayer1 }
                        StyledToolTip { text: Translation.tr("Reload custom widgets") }
                    }
                    RippleButton {
                        width: 28; height: 28; buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.06)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.10)
                        releaseAction: () => CustomWidgets.openWidgetDir("")
                        cancelAction: () => {}
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "folder_open"; iconSize: 16; color: Appearance.colors.colOnLayer1 }
                        StyledToolTip { text: Translation.tr("Open widgets folder") }
                    }
                    RippleButton {
                        visible: !root._exampleInstalled
                        width: 28; height: 28; buttonRadius: Appearance.rounding.full
                        colBackground: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.08)
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.14)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                        releaseAction: () => { CustomWidgets.installExample(); CustomWidgets.reload() }
                        cancelAction: () => {}
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "download"; iconSize: 16; color: Appearance.colors.colPrimary }
                        StyledToolTip { text: Translation.tr("Install example widget") }
                    }
                }
            }

            // Custom widget cards
            Repeater {
                model: CustomWidgets.ready ? CustomWidgets.widgets : []
                WidgetCard {
                    required property var modelData
                    widgetKey: modelData.id
                    widgetIcon: modelData.icon || "widgets"
                    widgetLabel: modelData.name
                    defaultEnabled: false
                    isCustom: true
                    customConfigKeys: modelData.configKeys ?? ({})
                }
            }

            // Empty state
            Item {
                visible: (root.filterMode === "all" || root.filterMode === "custom")
                    && root.searchText.length === 0
                    && (!CustomWidgets.ready || CustomWidgets.widgets.length === 0)
                width: parent.width; height: visible ? 56 : 0
                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Translation.tr("No custom widgets found")
                        color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.65)
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "~/.config/inir/widgets/"
                        color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.48)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.family: Appearance.font.family.monospace
                    }
                }
            }

            Item {
                visible: root._visibleCardCount === 0
                    && !((root.filterMode === "all" || root.filterMode === "custom")
                        && root.searchText.length === 0
                        && (!CustomWidgets.ready || CustomWidgets.widgets.length === 0))
                width: parent.width
                height: visible ? 84 : 0
                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.filterMode === "locked" ? "lock_open" : "search_off"
                        iconSize: 22
                        color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.45)
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.filterMode === "locked"
                            ? Translation.tr("No locked widgets on this display")
                            : Translation.tr("No widgets match this view")
                        color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.62)
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }
        }
    }

    // ── Widget Card Component ─────────────────────────────────
    component WidgetCard: Rectangle {
        id: card
        required property string widgetKey
        required property string widgetIcon
        required property string widgetLabel
        required property bool defaultEnabled
        property bool isCustom: false
        property var customConfigKeys: ({})
        // An extra mascot instance (Settings › Widgets › Mascot › "+"); widgetKey
        // is the instance id, config lives under background.widgets.mascotInstances.<id>
        property bool isMascotInstance: false

        readonly property string _cfgPrefix: isMascotInstance
            ? ("background.widgets.mascotInstances." + widgetKey)
            : (isCustom ? ("background.widgets.custom." + widgetKey) : ("background.widgets." + widgetKey))
        readonly property string _layoutKey: isMascotInstance
            ? ("mascotInstances." + widgetKey)
            : (isCustom ? ("custom." + widgetKey) : widgetKey)
        readonly property bool _enabled: DesktopWidgetLayout.enabled(
            root.outputName, card._layoutKey,
            Config.getNestedValue(card._cfgPrefix + ".enable", card.defaultEnabled))
        readonly property bool _locked: Boolean(DesktopWidgetLayout.value(
            root.outputName, card._layoutKey, "locked",
            Config.getNestedValue(card._cfgPrefix + ".locked", false)))
        readonly property real _scale: Number(DesktopWidgetLayout.value(
            root.outputName, card._layoutKey, "widgetScale",
            Config.getNestedValue(card._cfgPrefix + ".widgetScale", 100)))
        // Surface controls are shown only while the active renderer consumes
        // WidgetSurface. Cookie Clock, Weather Shape and Media Controls own
        // different backgrounds, so exposing these controls there is misleading.
        readonly property bool _supportsAppearance: card.isMascotInstance
            || (card.isCustom && root._manifestSupportsSurface(card.customConfigKeys))
            || (!card.isCustom && (
                (card.widgetKey === "clock"
                    && Config.getNestedValue(card._cfgPrefix + ".style", "cookie") === "digital")
                || (card.widgetKey === "weather"
                    && Config.getNestedValue(card._cfgPrefix + ".style", "pill") === "card")
                || ["imageConverter", "visualizer", "systemMonitor", "battery", "notes",
                    "calendarUpcoming", "uptime", "newsTicker", "mascot",
                    "japaneseTypography", "worldClock", "userCard"].indexOf(card.widgetKey) !== -1
            ))
        readonly property bool _expanded: card._enabled && _expandToggle
        property bool _expandToggle: false

        visible: root._cardVisible(card.widgetLabel, card._enabled, card._locked, card.isCustom)
        width: parent.width
        height: visible ? _cardCol.implicitHeight : 0
        radius: Appearance.rounding.small
        color: card._enabled
            ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.04)
            : ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.02)
        border {
            width: card._enabled ? 1 : 0
            color: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.10)
        }

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        Column {
            id: _cardCol
            anchors { left: parent.left; right: parent.right }
            padding: 0

            // ── Main row: icon + name + lock badge + switch ──
            Item {
                width: parent.width; height: 44

                Row {
                    id: _identityRow
                    anchors {
                        left: parent.left
                        right: _actionsRow.left
                        leftMargin: 12
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 10

                    Rectangle {
                        width: 30; height: 30
                        radius: Appearance.rounding.verysmall
                        color: card._enabled
                            ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.10)
                            : ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.05)
                        anchors.verticalCenter: parent.verticalCenter

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: card.widgetIcon
                            iconSize: 18
                            color: card._enabled ? Appearance.colors.colPrimary : ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.4)
                        }
                    }

                    Column {
                        id: _labelColumn
                        width: Math.max(0, _identityRow.width - 40)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        StyledText {
                            width: parent.width
                            text: card.widgetLabel
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            color: card._enabled ? Appearance.colors.colOnLayer1 : ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.68)
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                        }
                        Row {
                            width: parent.width
                            spacing: 4
                            visible: card._enabled
                            MaterialSymbol {
                                visible: card._locked
                                text: "lock"
                                iconSize: 10
                                color: Appearance.colors.colError
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                visible: card._locked
                                text: Translation.tr("Locked")
                                color: ColorUtils.applyAlpha(Appearance.colors.colError, 0.7)
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                            StyledText {
                                visible: !card._locked && card._enabled
                                width: Math.max(0, parent.width - (card._locked ? 14 : 0))
                                text: Math.round(card._scale) + "%" + " · " + Math.round(Config.getNestedValue(card._cfgPrefix + ".widgetOpacity", 100)) + "% op"
                                color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.58)
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.family: Appearance.font.family.numbers
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                            }
                        }
                    }
                }

                Row {
                    id: _actionsRow
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 3

                    // Locate/select on the actual desktop canvas. This keeps the
                    // manager useful as navigation, not only as a settings list.
                    RippleButton {
                        visible: card._enabled
                        width: 30; height: 30
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.08)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                        releaseAction: () => root.focusWidgetRequested(card._layoutKey)
                        cancelAction: () => {}
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "my_location"
                            iconSize: 16
                            color: Appearance.colors.colPrimary
                        }
                        StyledToolTip { text: Translation.tr("Select this widget on the desktop") }
                    }

                    // Lock is a first-class row action so a locked widget never
                    // requires opening a nested settings block just to free it.
                    RippleButton {
                        visible: card._enabled
                        width: 30; height: 30
                        buttonRadius: Appearance.rounding.full
                        toggled: card._locked
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.06)
                        colBackgroundToggled: ColorUtils.applyAlpha(Appearance.colors.colError, 0.12)
                        colBackgroundToggledHover: ColorUtils.applyAlpha(Appearance.colors.colError, 0.18)
                        releaseAction: () => DesktopWidgetLayout.setValue(
                            root.outputName, card._layoutKey, "locked", !card._locked)
                        cancelAction: () => {}
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: card._locked ? "lock" : "lock_open"
                            iconSize: 16
                            color: card._locked ? Appearance.colors.colError
                                : ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.62)
                        }
                        StyledToolTip {
                            text: card._locked ? Translation.tr("Unlock position")
                                : Translation.tr("Lock position")
                        }
                    }

                    // Remove button (extra mascot instances only — built-ins toggle off instead)
                    RippleButton {
                        visible: card.isMascotInstance
                        width: 30; height: 30
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colError, 0.10)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colError, 0.14)
                        releaseAction: () => Config.removeMascotInstance(card.widgetKey)
                        cancelAction: () => {}
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "delete"; iconSize: 16; color: ColorUtils.applyAlpha(Appearance.colors.colError, 0.85) }
                        StyledToolTip { text: Translation.tr("Remove this mascot") }
                    }

                    // Expand button
                    RippleButton {
                        visible: card._enabled
                        width: 30; height: 30
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.06)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.10)
                        releaseAction: () => { card._expandToggle = !card._expandToggle }
                        cancelAction: () => {}
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: card._expandToggle ? "keyboard_arrow_up" : "tune"
                            iconSize: 18
                            color: card._expandToggle ? Appearance.colors.colPrimary : ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.6)
                        }
                        StyledToolTip { text: card._expandToggle ? Translation.tr("Collapse") : Translation.tr("Quick settings") }
                    }

                    // Enable switch
                    StyledSwitch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: card._enabled
                        onClicked: {
                            DesktopWidgetLayout.setGloballyEnabled(
                                card._layoutKey, !card._enabled)
                            checked = Qt.binding(() => card._enabled)
                        }
                    }
                }
            }

            // ── Expanded controls ──
            Item {
                width: parent.width
                height: card._expanded ? _expandContent.implicitHeight + 12 : 0
                clip: true
                visible: height > 0

                Behavior on height {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                Column {
                    id: _expandContent
                    anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 4; leftMargin: 12; rightMargin: 12 }
                    spacing: 8

                    // Divider
                    Rectangle { width: parent.width; height: 1; color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.06) }

                    // Scale slider
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        MaterialSymbol { text: "zoom_in"; iconSize: 16; color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.5) }
                        StyledText {
                            text: Translation.tr("Scale")
                            Layout.preferredWidth: 80
                            color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.7)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 50; to: 200; stepSize: 10
                            configuration: StyledSlider.Configuration.XS
                            stopIndicatorValues: []
                            value: card._scale
                            tooltipContent: Math.round(value) + "%"
                            onMoved: DesktopWidgetLayout.setValue(
                                root.outputName, card._layoutKey,
                                "widgetScale", Math.round(value))
                        }
                    }

                    // Opacity slider
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        MaterialSymbol { text: "opacity"; iconSize: 16; color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.5) }
                        StyledText {
                            text: Translation.tr("Opacity")
                            Layout.preferredWidth: 80
                            color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.7)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 10; to: 100; stepSize: 5
                            configuration: StyledSlider.Configuration.XS
                            stopIndicatorValues: []
                            value: Config.getNestedValue(card._cfgPrefix + ".widgetOpacity", 100)
                            tooltipContent: Math.round(value) + "%"
                            onMoved: Config.setNestedValue(card._cfgPrefix + ".widgetOpacity", Math.round(value))
                        }
                    }

                    // Dim slider
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        MaterialSymbol { text: "contrast"; iconSize: 16; color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.5) }
                        StyledText {
                            text: Translation.tr("Dimming")
                            Layout.preferredWidth: 80
                            color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.7)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 0; to: 100; stepSize: 5
                            configuration: StyledSlider.Configuration.XS
                            stopIndicatorValues: []
                            value: Config.getNestedValue(card._cfgPrefix + ".dim", 0)
                            tooltipContent: Math.round(value) + "%"
                            onMoved: Config.setNestedValue(card._cfgPrefix + ".dim", Math.round(value))
                        }
                    }

                    // Divider before appearance toggles
                    Rectangle { visible: card._supportsAppearance; width: parent.width; height: 1; color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.06) }

                    // Background toggle (per-widget granularity — some users want a flat
                    // resources widget but a frosted-glass clock, etc.)
                    RowLayout {
                        visible: card._supportsAppearance
                        width: parent.width
                        spacing: 8
                        MaterialSymbol { text: "format_color_fill"; iconSize: 16; color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.5) }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Background")
                            color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.7)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                        StyledSwitch {
                            checked: Config.getNestedValue(card._cfgPrefix + ".showBackground", true)
                            onCheckedChanged: {
                                if (checked !== Config.getNestedValue(card._cfgPrefix + ".showBackground", true))
                                    Config.setNestedValue(card._cfgPrefix + ".showBackground", checked)
                            }
                        }
                    }

                    // Blur toggle (only meaningful when current style supports blur —
                    // aurora / angel. Hidden on material/inir to avoid a no-op control.)
                    RowLayout {
                        width: parent.width
                        spacing: 8
                        visible: card._supportsAppearance && root._widgetBlurAvailable
                            && Config.getNestedValue(card._cfgPrefix + ".showBackground", true)
                        MaterialSymbol { text: "blur_on"; iconSize: 16; color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.5) }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Blur background")
                            color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.7)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                        StyledSwitch {
                            checked: Config.getNestedValue(card._cfgPrefix + ".useBlur", false)
                            onCheckedChanged: {
                                if (checked !== Config.getNestedValue(card._cfgPrefix + ".useBlur", false))
                                    Config.setNestedValue(card._cfgPrefix + ".useBlur", checked)
                            }
                        }
                    }

                    // Background opacity slider — tunes how visible the background fill is
                    RowLayout {
                        width: parent.width
                        spacing: 8
                        visible: card._supportsAppearance && Config.getNestedValue(card._cfgPrefix + ".showBackground", true)
                        MaterialSymbol { text: "opacity"; iconSize: 16; color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.5) }
                        StyledText {
                            text: Translation.tr("Background")
                            Layout.preferredWidth: 80
                            color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.7)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 0; to: 100; stepSize: 1
                            configuration: StyledSlider.Configuration.XS
                            stopIndicatorValues: []
                            value: {
                                const raw = Number(Config.getNestedValue(card._cfgPrefix + ".backgroundOpacity", 0.06));
                                if (!Number.isFinite(raw)) return 6;
                                return Math.max(0, Math.min(100, Math.round(raw <= 1 ? raw * 100 : raw)));
                            }
                            tooltipContent: Math.round(value) + "%"
                            onMoved: Config.setNestedValue(card._cfgPrefix + ".backgroundOpacity", Math.round(value) / 100)
                        }
                    }

                    // Border toggle
                    RowLayout {
                        visible: card._supportsAppearance
                        width: parent.width
                        spacing: 8
                        MaterialSymbol { text: "border_style"; iconSize: 16; color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.5) }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Border")
                            color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.7)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                        StyledSwitch {
                            checked: Config.getNestedValue(card._cfgPrefix + ".showBorder", true)
                            onCheckedChanged: {
                                if (checked !== Config.getNestedValue(card._cfgPrefix + ".showBorder", true))
                                    Config.setNestedValue(card._cfgPrefix + ".showBorder", checked)
                            }
                        }
                    }
                }
            }
        }
    }
}
