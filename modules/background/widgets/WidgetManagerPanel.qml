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
    readonly property int _minWidth: 320
    readonly property int _maxWidth: 520
    readonly property int _minHeight: 200
    readonly property int _maxHeight: 700
    readonly property int _naturalHeight: Math.min(_scrollView.contentHeight + _header.height + 32, _maxHeight)

    width: _panelWidth
    height: _panelHeight

    property int _panelWidth: 380
    property int _panelHeight: _naturalHeight

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
        height: 52

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
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 16; rightMargin: 12; topMargin: 8; bottomMargin: 4 }
            spacing: 8

            MaterialSymbol {
                text: "widgets"
                iconSize: 22
                color: Appearance.colors.colPrimary
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Desktop Widgets")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
            }

            RippleButton {
                width: 32; height: 32
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.06)
                colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.10)
                downAction: () => {
                    if (Config.options?.settingsUi?.overlayMode !== false) {
                        GlobalStates.settingsOverlayRequestedPage = 14
                        GlobalStates.settingsOverlayOpen = true
                    } else {
                        Quickshell.execDetached(["/usr/bin/env", "QS_SETTINGS_PAGE=14", Quickshell.shellPath("scripts/inir"), "settings-window"])
                    }
                }
                contentItem: MaterialSymbol { anchors.centerIn: parent; text: "settings"; iconSize: 18; color: Appearance.colors.colOnLayer1 }
                StyledToolTip { text: Translation.tr("Open widget settings") }
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
            if (resizeRight) root._panelWidth = Math.max(root._minWidth, Math.min(root._maxWidth, _startW + dx));
            if (resizeLeft) {
                const newW = Math.max(root._minWidth, Math.min(root._maxWidth, _startW - dx));
                root.parent.x = Math.round(_startPX + (_startW - newW));
                root._panelWidth = newW;
            }
            if (resizeBottom) root._panelHeight = Math.max(root._minHeight, Math.min(root._maxHeight, _startH + dy));
            if (resizeTop) {
                const newH = Math.max(root._minHeight, Math.min(root._maxHeight, _startH - dy));
                root.parent.y = Math.round(_startPY + (_startH - newH));
                root._panelHeight = newH;
            }
        }
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
    ResizeEdge { anchors { right: parent.right; bottom: parent.bottom } width: 12; height: 12; resizeRight: true; resizeBottom: true }

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
                text: Translation.tr("Built-in")
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.45)
                leftPadding: 4
                bottomPadding: 4
            }

            WidgetCard { widgetKey: "clock"; widgetIcon: "schedule"; widgetLabel: Translation.tr("Clock"); defaultEnabled: true }
            WidgetCard { widgetKey: "weather"; widgetIcon: "cloud"; widgetLabel: Translation.tr("Weather"); defaultEnabled: false }
            WidgetCard { widgetKey: "customImage"; widgetIcon: "add_photo_alternate"; widgetLabel: Translation.tr("Custom image"); defaultEnabled: false }
            WidgetCard { widgetKey: "imageConverter"; widgetIcon: "transform"; widgetLabel: Translation.tr("Image converter"); defaultEnabled: false }
            WidgetCard { widgetKey: "mediaControls"; widgetIcon: "album"; widgetLabel: Translation.tr("Media Controls"); defaultEnabled: false }
            WidgetCard { widgetKey: "visualizer"; widgetIcon: "graphic_eq"; widgetLabel: Translation.tr("Visualizer"); defaultEnabled: false }
            WidgetCard { widgetKey: "systemMonitor"; widgetIcon: "monitor_heart"; widgetLabel: Translation.tr("System Monitor"); defaultEnabled: false }
            WidgetCard { widgetKey: "battery"; widgetIcon: "battery_full"; widgetLabel: Translation.tr("Battery"); defaultEnabled: false }
            WidgetCard { widgetKey: "notes"; widgetIcon: "sticky_note_2"; widgetLabel: Translation.tr("Notes"); defaultEnabled: false }
            WidgetCard { widgetKey: "calendarUpcoming"; widgetIcon: "event"; widgetLabel: Translation.tr("Upcoming Events"); defaultEnabled: false }
            WidgetCard { widgetKey: "uptime"; widgetIcon: "avg_pace"; widgetLabel: Translation.tr("System uptime"); defaultEnabled: false }
            WidgetCard { widgetKey: "newsTicker"; widgetIcon: "newspaper"; widgetLabel: Translation.tr("News Ticker"); defaultEnabled: false }
            WidgetCard { widgetKey: "mascot"; widgetIcon: "pets"; widgetLabel: Translation.tr("Mascot"); defaultEnabled: false }
            WidgetCard { widgetKey: "japaneseTypography"; widgetIcon: "translate"; widgetLabel: Translation.tr("Japanese Typography"); defaultEnabled: false }
            WidgetCard { widgetKey: "worldClock"; widgetIcon: "public"; widgetLabel: Translation.tr("World clock"); defaultEnabled: false }
            WidgetCard { widgetKey: "userCard"; widgetIcon: "account_circle"; widgetLabel: Translation.tr("User card"); defaultEnabled: false }

            // ── Extra mascot instances ── (each is its own WidgetCard, positioned/posed independently)
            Item { width: 1; height: 8 }

            Item {
                width: parent.width; height: 28
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
                    downAction: () => {
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
                visible: root._mascotInstanceIds.length === 0
                width: parent.width; height: 40
                StyledText {
                    anchors.centerIn: parent
                    text: Translation.tr("Add a second, third… mascot, each posed independently")
                    color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.5)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }

            // ── Custom widgets section ──
            Item { width: 1; height: 8 }

            Item {
                width: parent.width; height: 28
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
                        downAction: () => CustomWidgets.reload()
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "refresh"; iconSize: 16; color: Appearance.colors.colOnLayer1 }
                        StyledToolTip { text: Translation.tr("Reload custom widgets") }
                    }
                    RippleButton {
                        width: 28; height: 28; buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.06)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.10)
                        downAction: () => CustomWidgets.openWidgetDir("")
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "folder_open"; iconSize: 16; color: Appearance.colors.colOnLayer1 }
                        StyledToolTip { text: Translation.tr("Open widgets folder") }
                    }
                    RippleButton {
                        visible: !root._exampleInstalled
                        width: 28; height: 28; buttonRadius: Appearance.rounding.full
                        colBackground: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.08)
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.14)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                        downAction: () => { CustomWidgets.installExample(); CustomWidgets.reload() }
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
                visible: !CustomWidgets.ready || CustomWidgets.widgets.length === 0
                width: parent.width; height: 56
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

        width: parent.width
        height: _cardCol.implicitHeight
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
                    spacing: 4

                    // Remove button (extra mascot instances only — built-ins toggle off instead)
                    RippleButton {
                        visible: card.isMascotInstance
                        width: 30; height: 30
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colError, 0.10)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colError, 0.14)
                        downAction: () => Config.removeMascotInstance(card.widgetKey)
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
                        downAction: () => { card._expandToggle = !card._expandToggle }
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
                        onCheckedChanged: {
                            if (checked !== card._enabled)
                                DesktopWidgetLayout.setEnabled(
                                    root.outputName, card._layoutKey, checked)
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

                    // Lock toggle row
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        MaterialSymbol { text: "lock"; iconSize: 16; color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.5) }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Lock position")
                            color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.7)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                        StyledSwitch {
                            checked: card._locked
                            activeColor: Appearance.colors.colError
                            onCheckedChanged: {
                                if (checked !== card._locked)
                                    DesktopWidgetLayout.setValue(
                                        root.outputName, card._layoutKey,
                                        "locked", checked)
                            }
                        }
                    }

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
