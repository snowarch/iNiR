pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

ColumnLayout {
    id: root

    onVisibleChanged: if (visible) Brightness.getMonitorForScreen(root.targetScreen)?.refresh()
    property var targetScreen
    readonly property real d: IrisStyle.density
    readonly property real blockRadius: IrisStyle.radiusPlate
    readonly property color blockColor: IrisStyle.fillQuiet
    readonly property string picker: grid.picker
    readonly property string hint: grid.hint
    property string shownHint: ""
    onHintChanged: {
        if (root.hint.length > 0) { hintRelease.stop(); root.shownHint = root.hint }
        else hintRelease.restart()
    }
    Timer { id: hintRelease; interval: 180; onTriggered: root.shownHint = "" }
    readonly property bool editing: GlobalStates.irisControlEdit
    readonly property real libraryWidth: Math.round(IrisControlOptions.libraryWidth * root.d)
    readonly property real paneGap: Math.round(20 * root.d)
    readonly property string libraryTab: GlobalStates.irisControlTab
    spacing: Math.round(10 * root.d)
    opacity: IrisStyle.recompose

    onEditingChanged: if (!root.editing) IrisControlOptions.forget()

    readonly property var panelRows: {
        Config.revision
        const width = Number(IrisControlOptions.options?.width ?? 360)
        const widths = [340, 360, 400, 440]
        const nearest = widths.reduce((best, each) => Math.abs(each - width) < Math.abs(best - width) ? each : best, widths[0])
        return [
            { key: "columns", label: "Columns", current: IrisControlOptions.columns,
                options: [3, 4, 5, 6].map(value => ({ value: value, label: String(value) })) },
            { key: "controls", label: "Shape", current: IrisControlOptions.roundControls ? "round" : "tiles",
                options: [{ value: "tiles", label: "Tiles" }, { value: "round", label: "Round" }] },
            { key: "labels", label: "Names under the controls", current: IrisControlOptions.labelled,
                options: [{ value: true, label: "Shown" }, { value: false, label: "Hidden" }] },
            { key: "width", label: "Width", current: nearest,
                options: [{ value: 340, label: "Slim" }, { value: 360, label: "Regular" }, { value: 400, label: "Roomy" }, { value: 440, label: "Broad" }] },
            { key: "accent", label: "Accent", current: IrisControlOptions.accentMode,
                options: [{ value: "system", label: "iRiS" }, { value: "accent", label: "Accent" }, { value: "colourful", label: "Colourful" }, { value: "mono", label: "Mono" }] },
            { key: "sliders", label: "Slider fill", current: IrisControlOptions.accentSliders ? "accent" : "neutral",
                options: [{ value: "neutral", label: "Neutral" }, { value: "accent", label: "Accent" }] },
            { key: "opens", label: "Opens as", current: String(IrisControlOptions.options?.opens ?? "island"),
                options: [{ value: "island", label: "The Island" }, { value: "panel", label: "A panel" }] }
        ]
    }

    component Block: Rectangle {
        radius: root.blockRadius
        color: root.blockColor
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4 * root.d
        Layout.rightMargin: 2 * root.d
        spacing: 8 * root.d
        ColumnLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: Number.POSITIVE_INFINITY
            spacing: 0
            // At rest the panel is named by the day, not by itself.
            Item {
                Layout.fillWidth: true
                implicitHeight: editTitle.implicitHeight
                IrisText {
                    id: editTitle
                    visible: root.editing
                    width: parent.width
                    text: Translation.tr("Arrange the Control Center")
                    role: IrisText.Title
                    elide: Text.ElideRight
                }
                RowLayout {
                    visible: !root.editing
                    width: parent.width
                    spacing: Math.round(6 * root.d)
                    IrisText {
                        text: {
                            const day = Translation.locale.toString(DateTime.clock.date, "dddd")
                            return day.charAt(0).toUpperCase() + day.slice(1)
                        }
                        role: IrisText.Title
                    }
                    IrisText {
                        text: Qt.formatDate(DateTime.clock.date, "d")
                        role: IrisText.Title
                        color: IrisStyle.secondaryAccent
                        font.family: IrisStyle.fontNumbers
                        font.weight: IrisStyle.weight(Font.Bold)
                    }
                    Item { Layout.fillWidth: true }
                }
            }
            // The line under the title answers the pointer: it holds a moment between controls so it never
            // flashes empty in between, and every change crossfades on the feedback curve.
            Item {
                id: subtitle
                Layout.fillWidth: true
                implicitHeight: lineA.implicitHeight
                readonly property string line: root.shownHint.length > 0 ? root.shownHint
                    : root.editing ? Translation.tr("Drag to reorder, drag a corner to resize, − takes it out")
                    : Translation.locale.toString(DateTime.clock.date, "MMMM yyyy")
                property bool frontA: true
                Component.onCompleted: lineA.text = subtitle.line
                onLineChanged: {
                    if (subtitle.line.length === 0) return
                    if (subtitle.frontA) lineB.text = subtitle.line
                    else lineA.text = subtitle.line
                    subtitle.frontA = !subtitle.frontA
                }
                IrisText {
                    id: lineA
                    readonly property bool front: subtitle.frontA
                    width: subtitle.width
                    role: IrisText.Meta
                    color: root.shownHint.length > 0 ? IrisStyle.text : IrisStyle.textSecondary
                    elide: Text.ElideRight
                    font.pixelSize: IrisStyle.typeMeta
                    readonly property bool shown: lineA.front && lineA.text.length > 0
                    opacity: lineA.shown ? 1 : 0
                    y: lineA.shown ? 0 : Math.round(3 * root.d)
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                    Behavior on y { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                }
                IrisText {
                    id: lineB
                    readonly property bool front: !subtitle.frontA
                    width: subtitle.width
                    role: IrisText.Meta
                    color: root.shownHint.length > 0 ? IrisStyle.text : IrisStyle.textSecondary
                    elide: Text.ElideRight
                    font.pixelSize: IrisStyle.typeMeta
                    readonly property bool shown: lineB.front && lineB.text.length > 0
                    opacity: lineB.shown ? 1 : 0
                    y: lineB.shown ? 0 : Math.round(3 * root.d)
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                    Behavior on y { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                }
            }
        }
        IrisIconButton {
            visible: root.editing
            enabled: IrisControlOptions.canUndo
            materialIcon: "undo"
            Accessible.name: Translation.tr("Undo")
            onClicked: IrisControlOptions.undo()
        }
        IrisButton {
            visible: root.editing
            emphasized: true
            text: Translation.tr("Done")
            buttonRadius: height / 2
            onClicked: GlobalStates.irisControlEdit = false
        }
        IrisControlPlate {
            id: headerTools
            visible: !root.editing
            Layout.alignment: Qt.AlignVCenter
            controlHeight: Math.round(34 * root.d)
            RowLayout {
                spacing: headerTools.framed ? Math.round(2 * root.d) : 8 * root.d
                IrisIconButton {
                    buttonRadius: headerTools.framed ? headerTools.controlRadius : IrisStyle.radiusSmall
                    buttonRadiusPressed: headerTools.framed ? headerTools.controlRadius : Math.max(3, IrisStyle.radiusSmall - 2)
                    materialIcon: "dashboard_customize"
                    Accessible.name: Translation.tr("Arrange the controls")
                    onClicked: GlobalStates.irisControlEdit = true
                }
                IrisIconButton {
                    buttonRadius: headerTools.framed ? headerTools.controlRadius : IrisStyle.radiusSmall
                    buttonRadiusPressed: headerTools.framed ? headerTools.controlRadius : Math.max(3, IrisStyle.radiusSmall - 2)
                    materialIcon: "lock"
                    Accessible.name: Translation.tr("Lock")
                    onClicked: {
                        GlobalStates.controlPanelOpen = false
                        Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "lock", "activate"])
                    }
                }
                IrisIconButton {
                    id: settingsButton
                    buttonRadius: headerTools.framed ? headerTools.controlRadius : IrisStyle.radiusSmall
                    buttonRadiusPressed: headerTools.framed ? headerTools.controlRadius : Math.max(3, IrisStyle.radiusSmall - 2)
                    materialIcon: "settings"
                    Accessible.name: Translation.tr("Settings")
                    onClicked: {
                        GlobalStates.controlPanelOpen = false
                        const p = settingsButton.mapToItem(null, 0, 0)
                        GlobalStates.irisMorphOrigin = { x: p.x, y: p.y, width: settingsButton.width, height: settingsButton.height,
                            radius: headerTools.framed ? headerTools.controlRadius : settingsButton.height / 2, screen: GlobalStates.focusedScreen?.name ?? "" }
                        GlobalStates.irisMorphOwner = "control"
                        GlobalStates.openSettings()
                    }
                }
                IrisIconButton {
                    buttonRadius: headerTools.framed ? headerTools.controlRadius : IrisStyle.radiusSmall
                    buttonRadiusPressed: headerTools.framed ? headerTools.controlRadius : Math.max(3, IrisStyle.radiusSmall - 2)
                    materialIcon: "power_settings_new"
                    Accessible.name: Translation.tr("Session")
                    onClicked: { GlobalStates.controlPanelOpen = false; GlobalStates.sessionOpen = true }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 0

        ColumnLayout {
            id: main
            Layout.fillWidth: true
            Layout.maximumWidth: Number.POSITIVE_INFINITY
            Layout.alignment: Qt.AlignTop
            z: grid.carrying.length > 0 ? 2 : 0
            spacing: Math.round(10 * root.d)

            IrisControlGrid {
                id: grid
                Layout.fillWidth: true
                Layout.topMargin: 2 * root.d
                targetScreen: root.targetScreen
                removeZone: library
            }

            Block {
                Layout.fillWidth: true
                visible: implicitHeight > 1 && root.picker !== ""
                clip: true
                implicitHeight: root.picker !== "" ? pickerStack.implicitHeight + 12 * root.d : 0
                Behavior on implicitHeight { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                Item {
                    id: pickerStack
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6 * root.d
                    implicitHeight: root.picker === "network" ? networkList.implicitHeight
                        : root.picker === "bluetooth" ? bluetoothList.implicitHeight
                        : root.picker === "display" ? displayList.implicitHeight
                        : root.picker === "system" ? systemList.implicitHeight : deviceList.implicitHeight
                    IrisDeviceList { id: deviceList; width: parent.width; visible: root.picker === "devices" }
                    IrisDisplayList { id: displayList; width: parent.width; visible: root.picker === "display"; targetScreen: root.targetScreen }
                    IrisSystemList { id: systemList; width: parent.width; visible: root.picker === "system" }
                    IrisNetworkList { id: networkList; width: parent.width; visible: root.picker === "network" }
                    IrisBluetoothList { id: bluetoothList; width: parent.width; visible: root.picker === "bluetooth" }
                }
            }

            Block {
                Layout.fillWidth: true
                visible: IrisControlOptions.modules.includes("notifications")
                implicitHeight: notificationColumn.implicitHeight + 20 * root.d
                Behavior on implicitHeight { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                IrisControlMark {
                    id: notificationsMark
                    visible: root.editing
                    x: -Math.round(width / 3)
                    y: -Math.round(height / 3)
                    danger: true
                    label: Translation.tr("Take %1 out").arg(Translation.tr("Notifications"))
                    onHoveredOver: hovered => grid.hint = hovered ? notificationsMark.label : ""
                    onActivated: IrisControlOptions.remove("notifications")
                }
                // Empty, it is one quiet row the height of a control; full, the newest groups as rows with
                // hairlines on the text column, up to three, the rest one tap away in Today.
                ColumnLayout {
                    id: notificationColumn
                    readonly property int total: Notifications.appNameList.length
                    readonly property bool empty: Notifications.list.length === 0
                    readonly property var shown: Notifications.appNameList.slice(0, 3)
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10 * root.d
                    anchors.leftMargin: 14 * root.d
                    anchors.rightMargin: 10 * root.d
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(28 * root.d)
                        spacing: Math.round(6 * root.d)
                        IrisText {
                            text: Translation.tr("Notifications")
                            role: IrisText.Title
                            font.pixelSize: IrisStyle.typeLabel
                        }
                        Rectangle {
                            visible: !notificationColumn.empty
                            implicitWidth: Math.max(implicitHeight, totalLabel.implicitWidth + Math.round(10 * root.d))
                            implicitHeight: Math.round(17 * root.d)
                            radius: height / 2
                            color: IrisStyle.tintFill(IrisStyle.secondaryAccent)
                            IrisText {
                                id: totalLabel
                                anchors.centerIn: parent
                                text: Notifications.list.length
                                color: IrisStyle.secondaryAccent
                                font.family: IrisStyle.fontNumbers
                                font.features: ({ "tnum": 1 })
                                font.weight: IrisStyle.weight(Font.DemiBold)
                                font.pixelSize: IrisStyle.typeFootnote
                            }
                        }
                        Item { Layout.fillWidth: true }
                        IrisText {
                            visible: notificationColumn.empty
                            text: Translation.tr("All caught up")
                            role: IrisText.Meta
                            color: IrisStyle.muted
                        }
                        IrisButton {
                            visible: !notificationColumn.empty && !root.editing
                            quiet: true
                            text: Translation.tr("Clear")
                            implicitHeight: Math.round(24 * root.d)
                            buttonRadius: height / 2
                            onClicked: Notifications.discardAllNotifications()
                        }
                    }
                    Repeater {
                        model: notificationColumn.shown
                        Item {
                            id: groupRow
                            required property string modelData
                            required property int index
                            readonly property var group: Notifications.groupsByAppName[groupRow.modelData]
                            readonly property var newest: groupRow.group?.notifications?.[groupRow.group.notifications.length - 1] ?? null
                            readonly property int count: groupRow.group?.notifications?.length ?? 0
                            Layout.fillWidth: true
                            Layout.topMargin: groupRow.index === 0 ? Math.round(6 * root.d) : 0
                            implicitHeight: rowBody.implicitHeight + Math.round(16 * root.d)
                            function open(): void {
                                const actions = groupRow.newest?.actions ?? []
                                const preferred = actions.find(action => action.identifier === "default")
                                if (preferred) Notifications.attemptInvokeAction(groupRow.newest.notificationId, preferred.identifier)
                                else GlobalStates.openSidebarRight(root.targetScreen?.name ?? "")
                            }
                            Rectangle {
                                visible: groupRow.index > 0
                                x: rowBody.x + icon.width + rowBody.spacing
                                width: groupRow.width - x
                                height: 1
                                color: IrisStyle.hairline
                            }
                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: -Math.round(6 * root.d)
                                radius: IrisStyle.radiusRow
                                color: rowHover.hovered && !root.editing ? IrisStyle.fillHover : "transparent"
                                Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                            }
                            HoverHandler { id: rowHover; cursorShape: root.editing ? Qt.ArrowCursor : Qt.PointingHandCursor }
                            TapHandler { enabled: !root.editing; onTapped: groupRow.open() }
                            RowLayout {
                                id: rowBody
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10 * root.d
                                IrisNotificationIcon {
                                    id: icon
                                    Layout.alignment: Qt.AlignTop
                                    size: Math.round(30 * root.d)
                                    showImage: false
                                    appName: String(groupRow.modelData ?? "")
                                    appIcon: String(groupRow.group?.appIcon ?? "")
                                    summary: String(groupRow.newest?.summary ?? "")
                                    critical: String(groupRow.newest?.urgency ?? "") === "critical"
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: Number.POSITIVE_INFINITY
                                    spacing: 1
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Math.round(6 * root.d)
                                        IrisText {
                                            Layout.fillWidth: true
                                            text: String(groupRow.newest?.summary || groupRow.modelData || "")
                                            font.pixelSize: IrisStyle.typeLabel
                                            font.weight: IrisStyle.weight(Font.DemiBold)
                                            elide: Text.ElideRight
                                        }
                                        Rectangle {
                                            visible: groupRow.count > 1 && !rowHover.hovered
                                            implicitWidth: Math.max(implicitHeight, countLabel.implicitWidth + Math.round(10 * root.d))
                                            implicitHeight: Math.round(16 * root.d)
                                            radius: height / 2
                                            color: IrisStyle.fill
                                            IrisText {
                                                id: countLabel
                                                anchors.centerIn: parent
                                                text: groupRow.count
                                                font.family: IrisStyle.fontNumbers
                                                font.features: ({ "tnum": 1 })
                                                font.pixelSize: IrisStyle.typeCaption
                                                font.weight: IrisStyle.weight(Font.DemiBold)
                                            }
                                        }
                                        IrisIconButton {
                                            visible: rowHover.hovered && !root.editing
                                            materialIcon: "close"
                                            iconSize: Math.round(14 * root.d)
                                            implicitWidth: Math.round(20 * root.d)
                                            implicitHeight: Math.round(20 * root.d)
                                            Accessible.name: Translation.tr("Dismiss")
                                            onClicked: (groupRow.group?.notifications ?? []).slice().forEach(n => Notifications.discardNotification(n.notificationId))
                                        }
                                    }
                                    IrisText {
                                        Layout.fillWidth: true
                                        visible: text.length > 0
                                        text: String(groupRow.newest?.body ?? "").replace(/<[^>]*>/g, "")
                                        textFormat: Text.PlainText
                                        maximumLineCount: notificationColumn.shown.length > 2 ? 1 : 2
                                        wrapMode: Text.WordWrap
                                        elide: Text.ElideRight
                                        role: IrisText.Meta
                                    }
                                }
                            }
                        }
                    }
                    IrisButton {
                        visible: notificationColumn.total > notificationColumn.shown.length && !root.editing
                        Layout.fillWidth: true
                        Layout.topMargin: Math.round(4 * root.d)
                        quiet: true
                        implicitHeight: Math.round(28 * root.d)
                        buttonRadius: height / 2
                        text: Translation.tr("+%1 more in Today").arg(notificationColumn.total - notificationColumn.shown.length)
                        onClicked: GlobalStates.openSidebarRight(root.targetScreen?.name ?? "")
                    }
                }
            }
        }

        Rectangle {
            visible: root.editing
            Layout.fillHeight: true
            Layout.leftMargin: root.paneGap / 2
            Layout.rightMargin: root.paneGap / 2
            implicitWidth: 1
            color: IrisStyle.hairline
        }

        ColumnLayout {
            id: library
            visible: root.editing
            Layout.preferredWidth: root.libraryWidth
            Layout.maximumWidth: root.libraryWidth
            Layout.preferredHeight: Math.max(Math.round(360 * root.d), main.implicitHeight)
            Layout.alignment: Qt.AlignTop
            spacing: Math.round(10 * root.d)

            Rectangle {
                id: removeDrop
                readonly property bool shown: grid.carrying.length > 0 && !grid.carryingNew
                visible: removeDrop.shown
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: IrisStyle.radiusPlate
                color: grid.overRemove ? IrisStyle.tintFill(IrisStyle.danger) : IrisStyle.fillQuiet
                border.width: Math.max(1, Math.round(1.5 * root.d))
                border.color: grid.overRemove ? IrisStyle.danger : IrisStyle.border
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Math.round(6 * root.d)
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "delete"
                        iconSize: Math.round(26 * root.d)
                        color: grid.overRemove ? IrisStyle.danger : IrisStyle.muted
                    }
                    IrisText {
                        Layout.alignment: Qt.AlignHCenter
                        text: grid.overRemove ? Translation.tr("Let go to take it out") : Translation.tr("Drop here to take it out")
                        color: grid.overRemove ? IrisStyle.danger : IrisStyle.muted
                        font.pixelSize: IrisStyle.typeMeta
                    }
                }
            }

            IrisSegmented {
                visible: !removeDrop.shown
                Layout.fillWidth: true
                options: [
                    { value: "controls", label: Translation.tr("Controls") },
                    { value: "layouts", label: Translation.tr("Layouts") },
                    { value: "panel", label: Translation.tr("Panel") }
                ]
                current: root.libraryTab
                onPicked: value => GlobalStates.irisControlTab = value
            }

            Flickable {
                id: shelf
                visible: !removeDrop.shown
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: shelfColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                interactive: grid.carrying.length === 0
                ScrollBar.vertical: IrisScrollBar {}

                Column {
                    id: shelfColumn
                    width: shelf.width
                    spacing: Math.round(14 * root.d)

                    Repeater {
                        model: root.libraryTab === "controls" ? IrisControlOptions.categories : []
                        delegate: Column {
                            id: category
                            required property var modelData
                            width: shelfColumn.width
                            spacing: Math.round(6 * root.d)
                            IrisText {
                                text: Translation.tr(category.modelData.label)
                                role: IrisText.Meta
                                font.weight: IrisStyle.weight(Font.DemiBold)
                                font.pixelSize: IrisStyle.typeMeta
                            }
                            Flow {
                                width: category.width
                                spacing: Math.round(4 * root.d)
                                Repeater {
                                    model: IrisControlOptions.catalogue.filter(entry => entry.category === category.modelData.id)
                                    delegate: LibraryTile {}
                                }
                            }
                        }
                    }

                    Repeater {
                        model: root.libraryTab === "layouts" ? IrisControlOptions.presets : []
                        delegate: PresetCard {}
                    }

                    Repeater {
                        model: root.libraryTab === "panel" ? [
                            { key: "platter", label: "On the Connections plate", ids: IrisControlOptions.toggleIds, limit: 4 },
                            { key: "levels", label: "In Levels", ids: IrisControlOptions.levelKinds, limit: 0 }
                        ] : []
                        delegate: ColumnLayout {
                            id: pickRow
                            required property var modelData
                            readonly property var chosen: pickRow.modelData.key === "platter" ? IrisControlOptions.platterIds : IrisControlOptions.levelIds
                            width: shelfColumn.width
                            spacing: Math.round(6 * root.d)
                            IrisText {
                                Layout.fillWidth: true
                                text: Translation.tr(pickRow.modelData.label)
                                font.pixelSize: IrisStyle.typeLabel
                                font.weight: IrisStyle.weight(Font.DemiBold)
                            }
                            Flow {
                                Layout.fillWidth: true
                                spacing: Math.round(5 * root.d)
                                Repeater {
                                    model: pickRow.modelData.ids
                                    delegate: IrisButton {
                                        id: pick
                                        required property string modelData
                                        readonly property bool on: pickRow.chosen.includes(pick.modelData)
                                        text: Translation.tr(IrisControlOptions.labelOf(pick.modelData))
                                        quiet: !pick.on
                                        selected: pick.on
                                        implicitHeight: Math.round(28 * root.d)
                                        buttonRadius: height / 2
                                        onClicked: IrisControlOptions.toggleIn(pickRow.modelData.key, pick.modelData, pickRow.modelData.limit)
                                    }
                                }
                            }
                        }
                    }
                    Repeater {
                        model: ScriptModel {
                            objectProp: "key"
                            values: root.libraryTab === "panel" ? root.panelRows : []
                        }
                        delegate: ColumnLayout {
                            id: panelRow
                            required property var modelData
                            width: shelfColumn.width
                            spacing: Math.round(6 * root.d)
                            IrisText {
                                Layout.fillWidth: true
                                text: Translation.tr(panelRow.modelData.label)
                                font.pixelSize: IrisStyle.typeLabel
                                font.weight: IrisStyle.weight(Font.DemiBold)
                            }
                            IrisSegmented {
                                Layout.fillWidth: true
                                options: panelRow.modelData.options.map(option => ({ value: String(option.value), label: Translation.tr(option.label) }))
                                current: String(panelRow.modelData.current)
                                onPicked: value => {
                                    const option = panelRow.modelData.options.find(entry => String(entry.value) === value)
                                    if (option) IrisControlOptions.setPanel(panelRow.modelData.key, option.value)
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    component LibraryTile: Item {
        id: tile
        required property var modelData
        readonly property string moduleId: tile.modelData.id
        readonly property bool on: IrisControlOptions.modules.includes(tile.moduleId)
        width: Math.floor((shelfColumn.width - 3 * Math.round(4 * root.d)) / 4)
        height: Math.round(66 * root.d)
        Rectangle {
            id: tileFace
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(4 * root.d)
            width: Math.round(38 * root.d)
            height: width
            radius: IrisStyle.iconRadius(width)
            color: tile.on ? (tileArea.containsMouse ? IrisStyle.tintFillHover(IrisStyle.accent) : IrisStyle.tintFill(IrisStyle.accent))
                : tileArea.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet
            border.width: tile.on ? 1 : 0
            border.color: IrisStyle.tintBorder(IrisStyle.accent)
            scale: tileArea.pressed ? IrisStyle.pressScale(0.92) : 1
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
            Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
            MaterialSymbol {
                anchors.centerIn: parent
                text: tile.modelData.glyph
                fill: tile.on ? 1 : 0
                iconSize: Math.round(19 * root.d)
                color: tile.on ? IrisStyle.accent : IrisStyle.text
            }
        }
        IrisText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: tileFace.bottom
            anchors.topMargin: Math.round(4 * root.d)
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Translation.tr(tile.modelData.label)
            color: tile.on ? IrisStyle.text : IrisStyle.subtext
            font.pixelSize: IrisStyle.typeCaption
            elide: Text.ElideRight
        }
        MouseArea {
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: tile.on || tile.modelData.kind === "list" ? Qt.PointingHandCursor : Qt.OpenHandCursor
            Accessible.role: Accessible.CheckBox
            Accessible.name: Translation.tr(tile.modelData.label)
            Accessible.checked: tile.on
            property bool moved: false
            property point origin: Qt.point(0, 0)
            onEntered: grid.hint = Translation.tr(tile.modelData.label) + " · " + Translation.tr(tile.modelData.description)
            onExited: grid.hint = ""
            onPressed: mouse => { tileArea.moved = false; tileArea.origin = Qt.point(mouse.x, mouse.y) }
            onPositionChanged: mouse => {
                if (!tileArea.pressed || tile.on || tile.modelData.kind === "list") return
                const point = tileArea.mapToItem(grid, mouse.x, mouse.y)
                if (!tileArea.moved) {
                    if (Math.hypot(mouse.x - tileArea.origin.x, mouse.y - tileArea.origin.y) < 6 * root.d) return
                    tileArea.moved = true
                    const shape = grid.shapes[tile.moduleId]
                    const size = grid.rectOf({ col: 0, row: 0, w: shape.w, h: shape.h })
                    grid.beginCarry(tile.moduleId, point, Qt.point(size.width / 2, size.height / 2), true)
                    return
                }
                grid.moveCarry(point)
            }
            onReleased: {
                if (tileArea.moved) grid.endCarry()
                else if (tile.on) IrisControlOptions.remove(tile.moduleId)
                else IrisControlOptions.add(tile.moduleId, -1)
                tileArea.moved = false
            }
            onCanceled: { tileArea.moved = false; grid.endCarry() }
        }
    }

    component PresetCard: Rectangle {
        id: card
        required property var modelData
        readonly property bool current: IrisControlOptions.presetId === card.modelData.id
        readonly property int columns: card.modelData.columns
        readonly property var ids: IrisControlOptions.expand(card.modelData.modules).filter(id => IrisControlOptions.kindOf(id) !== "list")
        readonly property var chosen: IrisControlOptions.chosenShapes(card.modelData.sizes)
        readonly property var packed: {
            const shapes = ({})
            for (const id of card.ids) shapes[id] = IrisControlOptions.resolveShape(id, card.chosen[id] ?? "", card.columns)
            return IrisControlOptions.pack(card.ids, shapes, card.columns)
        }
        readonly property bool listed: card.modelData.modules.includes("notifications")
        readonly property real miniWidth: Math.round(92 * root.d)
        readonly property real miniGap: Math.max(1, Math.round(2 * root.d))
        readonly property real miniCell: (card.miniWidth - (card.columns - 1) * card.miniGap) / card.columns
        readonly property real miniUnit: card.miniCell * (card.modelData.labels ? 0.85 : 0.78)
        readonly property real miniHeight: card.packed.rows * card.miniUnit + Math.max(0, card.packed.rows - 1) * card.miniGap
            + (card.listed ? card.miniUnit + card.miniGap : 0)

        width: shelfColumn.width
        height: Math.max(cardText.implicitHeight, card.miniHeight) + Math.round(24 * root.d)
        radius: IrisStyle.radiusTile
        color: card.current ? IrisStyle.tintFill(IrisStyle.accent) : cardArea.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet
        border.width: card.current ? Math.max(1, Math.round(1.5 * root.d)) : 0
        border.color: IrisStyle.tintBorder(IrisStyle.accent)
        Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }

        Item {
            id: mini
            x: Math.round(12 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            width: card.miniWidth
            height: card.miniHeight
            Repeater {
                model: card.ids
                Item {
                    id: miniCell
                    required property string modelData
                    readonly property var spot: card.packed.placed[miniCell.modelData]
                    readonly property string kind: IrisControlOptions.kindOf(miniCell.modelData)
                    readonly property bool round: card.modelData.controls === "round"
                    readonly property bool single: miniCell.spot.w === 1 && miniCell.spot.h === 1
                    readonly property real dot: Math.round(Math.min(width, height) * 0.62)
                    x: miniCell.spot.col * (card.miniCell + card.miniGap)
                    y: miniCell.spot.row * (card.miniUnit + card.miniGap)
                    width: miniCell.spot.w * card.miniCell + (miniCell.spot.w - 1) * card.miniGap
                    height: miniCell.spot.h * card.miniUnit + (miniCell.spot.h - 1) * card.miniGap
                    Rectangle {
                        visible: miniCell.kind !== "levels" && !(miniCell.round && miniCell.single && miniCell.kind !== "level")
                        anchors.fill: parent
                        radius: miniCell.kind === "level" || (miniCell.round && miniCell.kind !== "platter" && miniCell.kind !== "media")
                            ? Math.min(width, height) / 2 : Math.max(2, Math.round(3 * root.d))
                        color: miniCell.kind === "platter" || miniCell.kind === "media" ? IrisStyle.fillActive : IrisStyle.fill
                    }
                    Rectangle {
                        visible: miniCell.round && miniCell.single && miniCell.kind !== "level"
                        anchors.centerIn: parent
                        width: miniCell.dot
                        height: width
                        radius: width / 2
                        color: IrisStyle.fill
                    }
                    Grid {
                        visible: miniCell.kind === "platter"
                        anchors.centerIn: parent
                        columns: miniCell.width > miniCell.height * 1.8 ? 4 : 2
                        spacing: Math.max(1, Math.round(3 * root.d))
                        Repeater {
                            model: 4
                            Rectangle {
                                width: Math.round(Math.min(miniCell.width, miniCell.height) * 0.3)
                                height: width
                                radius: width / 2
                                color: IrisStyle.textTertiary
                            }
                        }
                    }
                    Row {
                        id: levelMini
                        visible: miniCell.kind === "levels"
                        anchors.centerIn: parent
                        spacing: Math.max(1, Math.round(3 * root.d))
                        readonly property int count: Math.max(1, (card.modelData.levels ?? []).length)
                        readonly property bool upright: miniCell.height >= miniCell.width * 0.6
                        Repeater {
                            model: levelMini.count
                            Rectangle {
                                readonly property bool upright: levelMini.upright
                                width: upright ? Math.round(Math.min(9 * root.d, miniCell.width / 4)) : (miniCell.width - 6 * root.d) / levelMini.count
                                height: upright ? miniCell.height : Math.min(miniCell.height, Math.round(8 * root.d))
                                radius: Math.min(width, height) / 2
                                color: IrisStyle.fill
                                Rectangle {
                                    width: parent.upright ? parent.width : parent.width * 0.6
                                    height: parent.upright ? parent.height * 0.6 : parent.height
                                    y: parent.upright ? parent.height - height : 0
                                    radius: parent.radius
                                    color: IrisStyle.textTertiary
                                }
                            }
                        }
                    }
                    Rectangle {
                        visible: miniCell.kind === "level"
                        readonly property bool upright: miniCell.height > miniCell.width
                        width: upright ? parent.width : parent.width * 0.6
                        height: upright ? parent.height * 0.6 : parent.height
                        y: upright ? parent.height - height : 0
                        radius: Math.min(parent.width, parent.height) / 2
                        color: IrisStyle.textTertiary
                    }
                    Rectangle {
                        visible: miniCell.kind === "media"
                        x: Math.round(3 * root.d)
                        y: miniCell.height < card.miniUnit * 1.5 ? Math.round((parent.height - height) / 2) : Math.round(3 * root.d)
                        width: Math.min(parent.height - 6 * root.d, Math.round(10 * root.d))
                        height: width
                        radius: width / 2
                        color: IrisStyle.textTertiary
                    }
                }
            }
            Rectangle {
                visible: card.listed
                y: card.packed.rows * (card.miniUnit + card.miniGap)
                width: card.miniWidth
                height: card.miniUnit
                radius: Math.max(2, Math.round(3 * root.d))
                color: IrisStyle.fillQuiet
                border.width: 1
                border.color: IrisStyle.border
            }
        }

        ColumnLayout {
            id: cardText
            anchors.left: mini.right
            anchors.leftMargin: Math.round(12 * root.d)
            anchors.right: parent.right
            anchors.rightMargin: Math.round(12 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(2 * root.d)
            IrisText {
                Layout.fillWidth: true
                text: Translation.tr(card.modelData.label)
                font.pixelSize: IrisStyle.typeLabel
                font.weight: IrisStyle.weight(Font.DemiBold)
                color: card.current ? IrisStyle.accent : IrisStyle.text
                elide: Text.ElideRight
            }
            IrisText {
                Layout.fillWidth: true
                text: Translation.tr(card.modelData.description)
                role: IrisText.Meta
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: cardArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.RadioButton
            Accessible.name: Translation.tr(card.modelData.label)
            Accessible.checked: card.current
            onClicked: IrisControlOptions.applyPreset(card.modelData.id)
        }
    }
}
