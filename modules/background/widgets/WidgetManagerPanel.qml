pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    // Canvas bounds for clamping
    property real canvasWidth: 800
    property real canvasHeight: 600

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

    // Block clicks from reaching desktop
    MouseArea { anchors.fill: parent; z: -1; acceptedButtons: Qt.AllButtons; propagateComposedEvents: false }

    // ── Shadow + Background card ──
    StyledRectangularShadow { target: _bgCard }

    Rectangle {
        id: _bgCard
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border { width: 1; color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.08) }
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
            WidgetCard { widgetKey: "weather"; widgetIcon: "cloud"; widgetLabel: Translation.tr("Weather"); defaultEnabled: true }
            WidgetCard { widgetKey: "mediaControls"; widgetIcon: "album"; widgetLabel: Translation.tr("Media Controls"); defaultEnabled: true }
            WidgetCard { widgetKey: "visualizer"; widgetIcon: "graphic_eq"; widgetLabel: Translation.tr("Visualizer"); defaultEnabled: false }
            WidgetCard { widgetKey: "systemMonitor"; widgetIcon: "monitor_heart"; widgetLabel: Translation.tr("System Monitor"); defaultEnabled: false }
            WidgetCard { widgetKey: "battery"; widgetIcon: "battery_full"; widgetLabel: Translation.tr("Battery"); defaultEnabled: false }
            WidgetCard { widgetKey: "notes"; widgetIcon: "sticky_note_2"; widgetLabel: Translation.tr("Notes"); defaultEnabled: false }
            WidgetCard { widgetKey: "calendarUpcoming"; widgetIcon: "event"; widgetLabel: Translation.tr("Upcoming Events"); defaultEnabled: false }

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
                        color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.3)
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "~/.config/inir/widgets/"
                        color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.2)
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

        readonly property string _cfgPrefix: isCustom ? ("background.widgets.custom." + widgetKey) : ("background.widgets." + widgetKey)
        readonly property bool _enabled: Boolean(Config.getNestedValue(card._cfgPrefix + ".enable", card.defaultEnabled))
        readonly property bool _locked: Boolean(Config.getNestedValue(card._cfgPrefix + ".locked", false))
        // Whether this widget uses WidgetSurface for its background. Weather and
        // mediaControls have custom surfaces (pill, album-art card) so the universal
        // background/blur/border controls don't apply to them — hide that section to
        // avoid silent setNestedValue failures (their schemas don't expose those keys).
        readonly property bool _supportsAppearance: !isCustom && [
            "clock", "visualizer", "systemMonitor", "battery", "notes", "calendarUpcoming"
        ].indexOf(widgetKey) !== -1
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
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
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
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        StyledText {
                            text: card.widgetLabel
                            color: card._enabled ? Appearance.colors.colOnLayer1 : ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.5)
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                        }
                        Row {
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
                                text: Math.round(Config.getNestedValue(card._cfgPrefix + ".widgetScale", 100)) + "%" + " · " + Math.round(Config.getNestedValue(card._cfgPrefix + ".widgetOpacity", 100)) + "% op"
                                color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.35)
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.family: Appearance.font.family.numbers
                            }
                        }
                    }
                }

                Row {
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 4

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
                                Config.setNestedValue(card._cfgPrefix + ".enable", checked)
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
                                    Config.setNestedValue(card._cfgPrefix + ".locked", checked)
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
                            color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.7)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 50; to: 200; stepSize: 10
                            configuration: StyledSlider.Configuration.XS
                            stopIndicatorValues: []
                            value: Config.getNestedValue(card._cfgPrefix + ".widgetScale", 100)
                            tooltipContent: Math.round(value) + "%"
                            onMoved: Config.setNestedValue(card._cfgPrefix + ".widgetScale", Math.round(value))
                        }
                    }

                    // Opacity slider
                    RowLayout {
                        width: parent.width
                        spacing: 8

                        MaterialSymbol { text: "opacity"; iconSize: 16; color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.5) }
                        StyledText {
                            text: Translation.tr("Opacity")
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
                            text: Translation.tr("Dim")
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
                        visible: card._supportsAppearance && (Appearance.auroraEverywhere || Appearance.angelEverywhere) && Appearance.effectsEnabled
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
                            text: Translation.tr("BG opacity")
                            color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.7)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: 0; to: 100; stepSize: 1
                            configuration: StyledSlider.Configuration.XS
                            stopIndicatorValues: []
                            value: Math.round((Config.getNestedValue(card._cfgPrefix + ".backgroundOpacity", 0.06)) * 100)
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
