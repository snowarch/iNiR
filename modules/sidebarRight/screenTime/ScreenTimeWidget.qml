import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property int margin: 10
    property int selectedRange: 0

    readonly property var rangeOptions: [
        { label: Translation.tr("Today"), icon: "today" },
        { label: Translation.tr("3 days"), icon: "date_range" },
        { label: Translation.tr("14 days"), icon: "calendar_view_month" }
    ]

    readonly property int currentDays: [1, 3, 14][selectedRange]
    property var _displayData: null
    property var _appList: []
    property bool _loadingRange: false

    property string _tooltipText: ""
    property bool _tooltipVisible: false
    property real _tooltipX: 0
    property real _tooltipY: 0

    // Hour drill-down: -1 = none selected
    property int _selectedHour: -1
    property var _hourApps: []

    function _selectHour(hour) {
        if (root._selectedHour === hour) {
            root._selectedHour = -1
            root._hourApps = []
        } else {
            root._selectedHour = hour
            root._hourApps = ScreenTime.getHourBreakdown(hour, root.currentDays)
        }
    }

    function _clearHour() {
        root._selectedHour = -1
        root._hourApps = []
    }

    readonly property real maxHourAppSeconds: {
        let m = 0
        for (let i = 0; i < _hourApps.length; i++) {
            if (_hourApps[i].seconds > m) m = _hourApps[i].seconds
        }
        return m > 0 ? m : 1
    }

    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colTextSecondary: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colBg: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer0
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer0
    readonly property color colBorder: Appearance.angelEverywhere ? Appearance.angel.colBorder
        : Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border
    readonly property int borderWidth: (Appearance.angelEverywhere || Appearance.inirEverywhere) ? 1 : (Appearance.auroraEverywhere ? 0 : 1)
    readonly property real radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal

    readonly property real maxAppSeconds: {
        let m = 0
        for (let i = 0; i < _appList.length; i++) {
            if (_appList[i].seconds > m) m = _appList[i].seconds
        }
        return m > 0 ? m : 1
    }

    Connections {
        target: ScreenTime
        function onDataChanged() { root._refreshData() }
        function onRangeLoaded(days: int, data: var) {
            if (days !== root.currentDays)
                return
            root._loadingRange = false
            root._refreshData()
        }
    }

    function _refreshData(): void {
        if (root.currentDays <= 1) {
            root._loadingRange = false
            root._displayData = ScreenTime.getToday()
        } else {
            const cached = ScreenTime.getCachedDays(root.currentDays)
            if (cached) {
                root._loadingRange = false
                root._displayData = cached
            } else {
                root._loadingRange = true
                root._displayData = null
                root._appList = []
                ScreenTime.requestDays(root.currentDays)
                return
            }
        }
        root._appList = ScreenTime.getAppList(root.currentDays)
        // Keep the open hour breakdown in sync with fresh data
        if (root._selectedHour >= 0)
            root._hourApps = ScreenTime.getHourBreakdown(root._selectedHour, root.currentDays)
    }

    Component.onCompleted: root._refreshData()
    onSelectedRangeChanged: { root._clearHour(); root._refreshData() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        SecondaryTabBar {
            id: tabBar
            Layout.fillWidth: true
            Layout.leftMargin: root.margin
            Layout.rightMargin: root.margin
            Layout.topMargin: root.margin
            currentIndex: root.selectedRange
            onCurrentIndexChanged: root.selectedRange = currentIndex
            bottomBorderVisible: false

            Repeater {
                model: root.rangeOptions
                delegate: SecondaryTabButton {
                    selected: index === root.selectedRange
                    buttonText: modelData.label
                    buttonIcon: modelData.icon
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: root.margin
            radius: root.radius
            color: root.colBg
            border.width: root.borderWidth
            border.color: root.colBorder
            clip: true

            Flickable {
                id: mainFlickable
                anchors.fill: parent
                contentHeight: contentColumn.implicitHeight + 20
                clip: true
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 4 }
                boundsBehavior: Flickable.StopAtBounds
                onContentYChanged: root._tooltipVisible = false

                ColumnLayout {
                    id: contentColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 14

                    // Total time display
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        MaterialSymbol {
                            text: "av_timer"
                            iconSize: 22
                            fill: 1
                            color: Appearance.colors.colPrimary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                text: root._displayData
                                    ? ScreenTime.formatDuration(root._displayData.totalSeconds || 0)
                                    : "0s"
                                font.pixelSize: Appearance.font.pixelSize.larger
                                font.weight: Font.Bold
                                font.family: Appearance.font.family.numbers
                                color: Appearance.colors.colPrimary
                            }

                            StyledText {
                                text: root.currentDays <= 1
                                    ? Translation.tr("today")
                                    : Translation.tr("last %1 days").arg(root.currentDays)
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: root.colTextSecondary
                            }
                        }
                    }

                    // Hourly bar chart
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: root._displayData && (root._displayData.totalSeconds || 0) > 0

                        StyledText {
                            text: Translation.tr("Hourly activity")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: root.colTextSecondary
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            clip: true

                            Row {
                                id: hourlyBarRow
                                anchors.fill: parent
                                anchors.bottomMargin: 12
                                spacing: 2

                                Repeater {
                                    model: 24
                                    delegate: Item {
                                        id: hourSlot
                                        required property int index
                                        width: (parent.width - 46) / 24
                                        height: parent.height

                                        readonly property bool selected: root._selectedHour === index
                                        readonly property bool dimmed: root._selectedHour >= 0 && !selected

                                        property real value: {
                                            if (!root._displayData || !root._displayData.hourly) return 0
                                            return root._displayData.hourly[index] || 0
                                        }
                                        property real maxVal: {
                                            if (!root._displayData || !root._displayData.hourly) return 1
                                            let m = 0
                                            for (let i = 0; i < 24; i++) {
                                                const v = root._displayData.hourly[i] || 0
                                                if (v > m) m = v
                                            }
                                            return m > 0 ? m : 1
                                        }
                                        property real barH: value > 0 ? Math.max(4, (value / maxVal) * parent.height) : 2

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: parent.selected ? 6 : 4
                                            height: barH
                                            radius: Math.min(width, height) / 2
                                            color: value > 0 ? Appearance.colors.colPrimary : root.colBorder
                                            opacity: {
                                                if (value <= 0) return 0.15
                                                if (parent.dimmed) return 0.25
                                                return 0.4 + (value / maxVal) * 0.6
                                            }

                                            Behavior on width {
                                                enabled: Appearance.animationsEnabled
                                                animation: NumberAnimation {
                                                    duration: Appearance.animation.elementMoveFast.duration
                                                    easing.type: Appearance.animation.elementMoveFast.type
                                                }
                                            }
                                            Behavior on height {
                                                enabled: Appearance.animationsEnabled
                                                animation: NumberAnimation {
                                                    duration: Appearance.animation.elementResize.duration
                                                    easing.type: Appearance.animation.elementResize.type
                                                    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                                                }
                                            }
                                            Behavior on opacity {
                                                enabled: Appearance.animationsEnabled
                                                animation: NumberAnimation {
                                                    duration: Appearance.animation.elementMoveFast.duration
                                                    easing.type: Appearance.animation.elementMoveFast.type
                                                }
                                            }
                                        }

                                        HoverHandler {
                                            id: hourHover
                                            enabled: hourSlot.value > 0
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onHoveredChanged: {
                                                if (!hovered) {
                                                    root._tooltipVisible = false
                                                    return
                                                }
                                                const mapped = hourSlot.mapToItem(root,
                                                    hourSlot.width / 2, 0)
                                                root._tooltipX = mapped.x
                                                root._tooltipY = mapped.y - 4
                                                root._tooltipText = hourSlot.index + ":00 – "
                                                    + (hourSlot.index + 1) + ":00  •  "
                                                    + ScreenTime.formatDuration(hourSlot.value)
                                                root._tooltipVisible = true
                                            }
                                        }

                                        TapHandler {
                                            enabled: hourSlot.value > 0
                                            gesturePolicy: TapHandler.ReleaseWithinBounds
                                            onTapped: {
                                                root._tooltipVisible = false
                                                root._selectHour(hourSlot.index)
                                            }
                                        }
                                    }
                                }
                            }

                            Row {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: 0

                                Repeater {
                                    model: 4
                                    delegate: StyledText {
                                        width: parent.width / 4
                                        text: (index * 6) + ":00"
                                        font.pixelSize: Appearance.font.pixelSize.smaller - 1
                                        color: root.colTextSecondary
                                        horizontalAlignment: index === 0 ? Text.AlignLeft : Text.AlignHCenter
                                    }
                                }
                            }
                        }
                    }

                    // Hour breakdown panel — shown when an hourly bar is selected
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: root._selectedHour >= 0

                        // Header: hour range + total + close
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            MaterialSymbol {
                                text: "schedule"
                                iconSize: 16
                                color: Appearance.colors.colPrimary
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: root._selectedHour >= 0
                                    ? (root._selectedHour + ":00 – " + (root._selectedHour + 1) + ":00")
                                    : ""
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.DemiBold
                                color: root.colText
                            }

                            StyledText {
                                text: {
                                    if (root._selectedHour < 0 || !root._displayData || !root._displayData.hourly) return ""
                                    return ScreenTime.formatDuration(root._displayData.hourly[root._selectedHour] || 0)
                                }
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.family: Appearance.font.family.numbers
                                color: root.colTextSecondary
                            }

                            RippleButton {
                                implicitWidth: 22
                                implicitHeight: 22
                                buttonRadius: Appearance.rounding.full
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: root._clearHour()
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: 14
                                    color: root.colTextSecondary
                                }
                            }
                        }

                        // App rows for this hour
                        Repeater {
                            model: root._hourApps
                            delegate: RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                SmartAppIcon {
                                    icon: AppSearch.guessIcon(
                                        (modelData.name || "").toLowerCase()
                                        || (modelData.originalId && modelData.originalId !== modelData.id ? modelData.originalId : "")
                                        || modelData.id
                                    )
                                    iconSize: 22
                                    implicitWidth: 22
                                    implicitHeight: 22
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    spacing: 2

                                    StyledText {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        text: modelData.name || modelData.id
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: root.colText
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                    }

                                    Rectangle {
                                        implicitHeight: 2
                                        radius: 1
                                        color: Appearance.colors.colPrimary
                                        opacity: 0.15
                                        width: parent.width * (modelData.seconds / root.maxHourAppSeconds)

                                        Behavior on width {
                                            enabled: Appearance.animationsEnabled
                                            animation: NumberAnimation {
                                                duration: Appearance.animation.elementResize.duration
                                                easing.type: Appearance.animation.elementResize.type
                                                easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                                            }
                                        }
                                    }
                                }

                                StyledText {
                                    text: ScreenTime.formatDuration(modelData.seconds)
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.family: Appearance.font.family.numbers
                                    color: root.colTextSecondary
                                }
                            }
                        }

                        // No per-app detail available (older data without per-hour breakdown)
                        StyledText {
                            visible: root._hourApps.length === 0
                            Layout.fillWidth: true
                            text: Translation.tr("Per-app detail isn't available for this period")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: root.colTextSecondary
                            wrapMode: Text.WordWrap
                        }
                    }

                    // App list
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: root._appList.length > 0 && root._selectedHour < 0

                        StyledText {
                            text: Translation.tr("Most used")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: root.colTextSecondary
                        }

                        Repeater {
                            model: root._appList.slice(0, 8)
                            delegate: RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                SmartAppIcon {
                                    icon: AppSearch.guessIcon(
                                        (modelData.name || "").toLowerCase()
                                        || (modelData.originalId && modelData.originalId !== modelData.id ? modelData.originalId : "")
                                        || modelData.id
                                    )
                                    iconSize: 24
                                    implicitWidth: 24
                                    implicitHeight: 24
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    spacing: 2

                                    StyledText {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        text: modelData.name || modelData.id
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: root.colText
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                    }

                                    Rectangle {
                                        implicitHeight: 2
                                        radius: 1
                                        color: Appearance.colors.colPrimary
                                        opacity: 0.15
                                        width: parent.width * (modelData.seconds / root.maxAppSeconds)

                                        Behavior on width {
                                            enabled: Appearance.animationsEnabled
                                            animation: NumberAnimation {
                                                duration: Appearance.animation.elementResize.duration
                                                easing.type: Appearance.animation.elementResize.type
                                                easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                                            }
                                        }
                                    }
                                }

                                StyledText {
                                    text: ScreenTime.formatDuration(modelData.seconds)
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.family: Appearance.font.family.numbers
                                    color: root.colTextSecondary
                                }
                            }
                        }
                    }

                    // Empty state
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 16
                        visible: !root._displayData || (root._displayData.totalSeconds || 0) === 0
                        spacing: 8

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "av_timer"
                            iconSize: 28
                            fill: 1
                            color: root.colTextSecondary
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            text: !ScreenTime.enabled
                                ? Translation.tr("Enable Screen Time in Settings to start tracking")
                                : (root._loadingRange || !ScreenTime.ready)
                                    ? Translation.tr("Loading screen time history…")
                                    : Translation.tr("No screen time data yet")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: root.colTextSecondary
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }

    // Shared tooltip overlay — single instance, positioned via mapToItem
    Rectangle {
        id: tooltipOverlay
        z: 9999
        visible: root._tooltipVisible
        opacity: root._tooltipVisible ? 1 : 0
        x: Math.max(8, Math.min(root.width - width - 8,
            root._tooltipX - width / 2))
        y: Math.max(8, root._tooltipY - implicitHeight - 4)
        implicitWidth: Math.min(Math.max(80, root.width - 16),
            tooltipLabel.implicitWidth + 16)
        implicitHeight: tooltipLabel.implicitHeight + 8
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2
        border.width: 1
        border.color: root.colBorder

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
            }
        }

        StyledText {
            id: tooltipLabel
            anchors.centerIn: parent
            width: Math.max(0, parent.width - 16)
            text: root._tooltipText
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.family: Appearance.font.family.numbers
            color: Appearance.colors.colOnLayer2
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }
    }
}
