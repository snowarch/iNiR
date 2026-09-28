pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
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
    readonly property int railSlots: Math.max(4, Math.min(14,
        Math.floor(Math.max(railStride * 4, availableWidth - (root.compact ? 330 : 470)) / railStride)))
    readonly property real railWidth: railSlots * railStride - (root.iris ? root.irisRailSpacing : 0)
    readonly property int irisRailSpacing: 4
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
    readonly property real railStride: root.iris ? 36 + root.irisRailSpacing : root.railItemStride
    readonly property var irisEntries: {
        const out = root.builtinWidgets.map(widget => ({ key: widget.key, icon: widget.icon, label: widget.label,
            tint: DesktopWidgetIdentity.tint(widget.key),
            on: DesktopWidgetLayout.enabled(root.outputName, widget.key,
                Config.getNestedValue("background.widgets." + widget.key + ".enable", widget.defaultOn)) }))
        for (const custom of (CustomWidgets.ready ? CustomWidgets.widgets : [])) {
            const key = "custom." + custom.id
            out.push({ key: key, icon: custom.icon || "widgets", label: custom.name, tint: DesktopWidgetIdentity.customTint,
                on: DesktopWidgetLayout.enabled(root.outputName, key,
                    Config.getNestedValue("background.widgets.custom." + custom.id + ".enable", false)) })
        }
        return out
    }
    readonly property int irisOnCount: root.irisEntries.filter(entry => entry.on).length
    property var irisOrder: []
    function irisResort(): void {
        const on = root.irisEntries.filter(entry => entry.on).map(entry => entry.key)
        const off = root.irisEntries.filter(entry => !entry.on).map(entry => entry.key)
        root.irisOrder = on.length > 0 && off.length > 0 ? on.concat(["|"], off) : on.concat(off)
    }
    onIrisOnCountChanged: if (!railHover.hovered) root.irisResort()
    Component.onCompleted: root.irisResort()
    readonly property real bodyHeight: root.iris ? 60 : 48
    readonly property real bodyRadius: root.iris ? Math.min(IrisStyle.radius, root.bodyHeight / 2) : 0
    readonly property real fillet: root.iris ? Math.round(root.bodyRadius * 0.62) : 0
    readonly property string inwardTooltipPosition: root.attachedTopEdge ? "bottom" : "top"
    readonly property real bodyWidth: root.iris
        ? Math.min(Math.max(280, availableWidth - 2 * root.fillet),
            Math.max(320, toolbarRow.implicitWidth + 20))
        : Math.min(availableWidth, Math.max(320, toolbarRow.implicitWidth + 12))
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
        width: 26
        height: 26
        radius: 13
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
            iconSize: 17
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
        anchors.margins: root.iris ? 8 : 6
        anchors.leftMargin: root.iris ? 10 : 6
        anchors.rightMargin: root.iris ? 8 : 6
        spacing: root.iris ? 8 : 4

        WidgetEditAction {
            id: libraryAction
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
            Layout.fillWidth: true
            Layout.minimumWidth: root.railStride * 3
            Layout.preferredWidth: root.railWidth + (root.iris ? 8 : 0)
            Layout.maximumWidth: root.railWidth + (root.iris ? 8 : 0)
            Layout.preferredHeight: root.iris ? 44 : 34
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
                            width: 36
                            height: 40
                            Rectangle {
                                visible: !irisSlot.entry
                                anchors.centerIn: parent
                                width: 1
                                height: 22
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

        WidgetEditAction {
            id: gridAction
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
