pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.actionCenter

Item {
    id: root

    property int selectedRange: 0
    readonly property var rangeOptions: [
        { label: Translation.tr("Today"), days: 1 },
        { label: Translation.tr("3 days"), days: 3 },
        { label: Translation.tr("14 days"), days: 14 }
    ]
    readonly property int currentDays: rangeOptions[selectedRange].days
    property var _displayData: null
    property var _appList: []
    property bool _loadingRange: false

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

    readonly property real maxAppSeconds: {
        let m = 0
        for (let i = 0; i < _appList.length; i++) {
            if (_appList[i].seconds > m) m = _appList[i].seconds
        }
        return m > 0 ? m : 1
    }

    readonly property real maxHourAppSeconds: {
        let m = 0
        for (let i = 0; i < _hourApps.length; i++) {
            if (_hourApps[i].seconds > m) m = _hourApps[i].seconds
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
        if (root._selectedHour >= 0)
            root._hourApps = ScreenTime.getHourBreakdown(root._selectedHour, root.currentDays)
    }

    Component.onCompleted: root._refreshData()
    onSelectedRangeChanged: { root._clearHour(); root._refreshData() }

    WPanelPageColumn {
        anchors.fill: parent

        BodyRectangle {
            implicitHeight: 400
            implicitWidth: 50

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                HeaderRow {
                    Layout.fillWidth: true
                    title: Translation.tr("Screen Time")
                }

                StyledFlickable {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    contentHeight: contentLayout.implicitHeight
                    contentWidth: width
                    clip: true

                    ColumnLayout {
                        id: contentLayout
                        width: parent.width
                        spacing: Looks.dp(4)

                        // Range tabs
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: Looks.dp(12)
                            Layout.rightMargin: Looks.dp(12)
                            Layout.topMargin: Looks.dp(4)
                            spacing: Looks.dp(4)

                            Repeater {
                                model: root.rangeOptions
                                delegate: WBorderlessButton {
                                    required property int index
                                    required property var modelData
                                    Layout.fillWidth: true
                                    property bool isSelected: root.selectedRange === index

                                    onClicked: root.selectedRange = index

                                    contentItem: WText {
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData.label
                                        font.pixelSize: Looks.font.pixelSize.small
                                        font.weight: isSelected ? Font.DemiBold : Font.Normal
                                        color: isSelected ? Looks.colors.fg : Looks.colors.subfg

                                        Behavior on color {
                                            enabled: Looks.transition.enabled
                                            animation: NumberAnimation {
                                                duration: Looks.transition.duration.normal
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Total time
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: Looks.dp(16)
                            Layout.rightMargin: Looks.dp(16)
                            Layout.topMargin: Looks.dp(8)
                            spacing: 0

                            WText {
                                text: root._displayData
                                    ? ScreenTime.formatDuration(root._displayData.totalSeconds || 0)
                                    : "0s"
                                font.pixelSize: Looks.dp(32)
                                font.weight: Font.Bold
                                font.family: Looks.font.family.monospace
                                color: Looks.colors.accent
                            }

                            WText {
                                text: root.currentDays <= 1
                                    ? Translation.tr("today")
                                    : Translation.tr("last %1 days").arg(root.currentDays)
                                font.pixelSize: Looks.font.pixelSize.small
                                color: Looks.colors.subfg
                            }
                        }

                        // Hourly bar chart
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: Looks.dp(12)
                            Layout.rightMargin: Looks.dp(12)
                            spacing: Looks.dp(6)
                            visible: root._displayData && (root._displayData.totalSeconds || 0) > 0

                            WPanelSeparator { color: Looks.colors.bg2Hover }

                            SectionText {
                                text: Translation.tr("Hourly activity")
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Looks.dp(64)
                                Layout.leftMargin: Looks.dp(4)
                                Layout.rightMargin: Looks.dp(4)
                                clip: true

                                Row {
                                    anchors.fill: parent
                                    anchors.bottomMargin: Looks.dp(14)
                                    spacing: Looks.dp(2)

                                    Repeater {
                                        model: 24
                                        delegate: Item {
                                            id: waffleBar
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
                                            property real barH: value > 0 ? Math.max(3, (value / maxVal) * parent.height) : 2

                                            Rectangle {
                                                anchors.bottom: parent.bottom
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: Math.max(parent.width - 2, 2)
                                                height: barH
                                                radius: Math.min(width, height) / 2
                                                color: value > 0 ? Looks.colors.accent : Looks.colors.subfg
                                                opacity: {
                                                    if (value <= 0) return 0.15
                                                    if (waffleBar.dimmed) return 0.22
                                                    return 0.35 + (value / waffleBar.maxVal) * 0.65
                                                }

                                                Behavior on height {
                                                    enabled: Looks.transition.enabled
                                                    animation: NumberAnimation {
                                                        duration: Looks.transition.duration.medium
                                                        easing.type: Easing.BezierSpline
                                                        easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
                                                    }
                                                }
                                                Behavior on opacity {
                                                    enabled: Looks.transition.enabled
                                                    animation: NumberAnimation {
                                                        duration: Looks.transition.duration.normal
                                                        easing.type: Easing.BezierSpline
                                                        easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
                                                    }
                                                }
                                            }

                                            HoverHandler {
                                                enabled: waffleBar.value > 0
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            }

                                            TapHandler {
                                                enabled: waffleBar.value > 0
                                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                                onTapped: root._selectHour(waffleBar.index)
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
                                        delegate: WText {
                                            required property int index
                                            width: parent.width / 4
                                            text: (index * 6) + ":00"
                                            font.pixelSize: Looks.dp(9)
                                            color: Looks.colors.subfg
                                            horizontalAlignment: index === 0 ? Text.AlignLeft : Text.AlignHCenter
                                        }
                                    }
                                }
                            }
                        }

                        // Hour breakdown panel — shown when an hourly bar is selected
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: Looks.dp(12)
                            Layout.rightMargin: Looks.dp(12)
                            spacing: Looks.dp(4)
                            visible: root._selectedHour >= 0

                            WPanelSeparator { color: Looks.colors.bg2Hover }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: Looks.dp(4)
                                Layout.rightMargin: Looks.dp(4)
                                spacing: Looks.dp(8)

                                WText {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: root._selectedHour >= 0
                                        ? (root._selectedHour + ":00 – " + (root._selectedHour + 1) + ":00")
                                        : ""
                                    font.weight: Font.DemiBold
                                    color: Looks.colors.fg
                                }

                                WText {
                                    text: {
                                        if (root._selectedHour < 0 || !root._displayData || !root._displayData.hourly) return ""
                                        return ScreenTime.formatDuration(root._displayData.hourly[root._selectedHour] || 0)
                                    }
                                    font.family: Looks.font.family.monospace
                                    color: Looks.colors.subfg
                                }

                                Rectangle {
                                    implicitWidth: Looks.dp(22)
                                    implicitHeight: Looks.dp(22)
                                    radius: Looks.radius.small
                                    color: closeHover.containsMouse ? Looks.colors.bg2Hover : "transparent"

                                    Behavior on color {
                                        enabled: Looks.transition.enabled
                                        animation: ColorAnimation {
                                            duration: Looks.transition.duration.normal
                                            easing.type: Easing.BezierSpline
                                            easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
                                        }
                                    }

                                    FluentIcon {
                                        anchors.centerIn: parent
                                        icon: "dismiss"
                                        implicitSize: Looks.dp(13)
                                        color: Looks.colors.subfg
                                    }

                                    MouseArea {
                                        id: closeHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root._clearHour()
                                    }
                                }
                            }

                            Repeater {
                                model: root._hourApps
                                delegate: ColumnLayout {
                                    required property int index
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.leftMargin: Looks.dp(4)
                                    Layout.rightMargin: Looks.dp(4)
                                    spacing: Looks.dp(2)

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Looks.dp(10)

                                        Rectangle {
                                            implicitWidth: Looks.dp(6)
                                            implicitHeight: Looks.dp(6)
                                            radius: Looks.dp(3)
                                            color: Looks.colors.accent
                                            opacity: 1 - (index * 0.08)
                                        }

                                        WText {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            text: modelData.name || modelData.id
                                            elide: Text.ElideRight
                                            wrapMode: Text.NoWrap
                                        }

                                        WText {
                                            text: ScreenTime.formatDuration(modelData.seconds)
                                            font.family: Looks.font.family.monospace
                                            color: Looks.colors.subfg
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: Looks.dp(2)
                                        radius: Looks.dp(1)
                                        color: Looks.colors.accent
                                        opacity: 0.12
                                        width: parent.width * (modelData.seconds / root.maxHourAppSeconds)

                                        Behavior on width {
                                            enabled: Looks.transition.enabled
                                            animation: NumberAnimation {
                                                duration: Looks.transition.duration.medium
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
                                            }
                                        }
                                    }
                                }
                            }

                            WText {
                                visible: root._hourApps.length === 0
                                Layout.fillWidth: true
                                Layout.leftMargin: Looks.dp(4)
                                Layout.rightMargin: Looks.dp(4)
                                text: Translation.tr("Per-app detail isn't available for this period")
                                color: Looks.colors.subfg
                                wrapMode: Text.WordWrap
                            }
                        }

                        // App list
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: Looks.dp(12)
                            Layout.rightMargin: Looks.dp(12)
                            spacing: Looks.dp(4)
                            visible: root._appList.length > 0 && root._selectedHour < 0

                            WPanelSeparator { color: Looks.colors.bg2Hover }

                            SectionText {
                                text: Translation.tr("Most used")
                            }

                            Repeater {
                                model: root._appList.slice(0, 8)
                                delegate: ColumnLayout {
                                    required property int index
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.leftMargin: Looks.dp(4)
                                    Layout.rightMargin: Looks.dp(4)
                                    spacing: Looks.dp(2)

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Looks.dp(10)

                                        Rectangle {
                                            implicitWidth: Looks.dp(6)
                                            implicitHeight: Looks.dp(6)
                                            radius: Looks.dp(3)
                                            color: Looks.colors.accent
                                            opacity: 1 - (index * 0.08)
                                        }

                                        WText {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            text: modelData.name || modelData.id
                                            elide: Text.ElideRight
                                            wrapMode: Text.NoWrap
                                        }

                                        WText {
                                            text: ScreenTime.formatDuration(modelData.seconds)
                                            font.family: Looks.font.family.monospace
                                            color: Looks.colors.subfg
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: Looks.dp(2)
                                        radius: Looks.dp(1)
                                        color: Looks.colors.accent
                                        opacity: 0.12
                                        width: parent.width * (modelData.seconds / root.maxAppSeconds)

                                        Behavior on width {
                                            enabled: Looks.transition.enabled
                                            animation: NumberAnimation {
                                                duration: Looks.transition.duration.medium
                                                easing.type: Easing.BezierSpline
                                                easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Empty state
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Looks.dp(24)
                            visible: !root._displayData || (root._displayData.totalSeconds || 0) === 0
                            spacing: Looks.dp(8)

                            FluentIcon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: "timer"
                                implicitSize: Looks.dp(28)
                                color: Looks.colors.subfg
                            }

                            WText {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter
                                text: !ScreenTime.enabled
                                    ? Translation.tr("Enable Screen Time in Settings to start tracking")
                                    : (root._loadingRange || !ScreenTime.ready)
                                        ? Translation.tr("Loading screen time history…")
                                        : Translation.tr("No screen time data yet")
                                color: Looks.colors.subfg
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }

        WPanelSeparator {}

        FooterRectangle {}
    }
}
