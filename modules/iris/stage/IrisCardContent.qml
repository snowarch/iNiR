pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Bluetooth
import Quickshell.Widgets
import qs
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.pieces
import qs.modules.iris.bar
import qs.modules.iris.bar.island
import qs.modules.iris.sidebar

Item {
    id: root

    property string kind: ""
    property string screenName: ""
    property bool contentActive: true
    readonly property real d: IrisStyle.density
    readonly property bool bleeds: root.kind === "weather" || root.kind === "notifications"
        || root.kind === "media" || root.kind === "calendar"
    readonly property real contentHeight: body.item?.implicitHeight ?? 0
    readonly property color light: {
        switch (root.kind) {
        case "weather": return IrisStyle.skyLight(Icons.getWeatherIcon(Weather.data.wCode, Weather.isNightNow()) ?? "")
        case "sound": return IrisStyle.identity.indigo
        case "mic": return IrisStyle.identity.orange
        case "tools": return IrisStyle.secondaryAccent
        case "tray": return IrisStyle.identity.teal
        case "calendar": return IrisStyle.identity.red
        case "media": return "transparent"
        case "network": return IrisStyle.identity.blue
        case "bluetooth": return IrisStyle.identity.sky
        case "vitals": return IrisStyle.identity.teal
        case "workspaces": return IrisStyle.identity.purple
        case "updates": return IrisStyle.secondaryAccent
        case "anime": return IrisStyle.identity.pink
        case "watching": return IrisStyle.identity.pink
        case "shellUpdate": return IrisStyle.secondaryAccent
        case "vpn": return IrisStyle.identity.green
        default: return IrisStyle.wallpaperLight
        }
    }
    signal navigate()
    function close(): void { root.navigate() }

    implicitHeight: root.contentHeight

    Loader {
        id: body
        width: root.width
        active: root.kind.length > 0
        sourceComponent: {
            switch (root.kind) {
            case "weather": return weatherCard
            case "notifications": return notificationsCard
            case "calendar": return calendarCard
            case "sound": return soundCard
            case "mic": return micCard
            case "tools": return toolsCard
            case "tray": return trayCard
            case "media": return mediaCard
            case "network": return networkCard
            case "bluetooth": return bluetoothCard
            case "vitals": return vitalsCard
            case "workspaces": return workspacesCard
            case "updates": return updatesCard
            case "anime": return animeCard
            case "watching": return watchingCard
            case "shellUpdate": return shellUpdateCard
            case "vpn": return vpnCard
            default: return null
            }
        }
    }

    component VpnRow: MouseArea {
        id: vpnRow
        property string label: ""
        property string detail: ""
        property bool on: false
        signal toggled()
        implicitHeight: Math.round(42 * root.d)
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        enabled: !Vpn.busy
        Accessible.role: Accessible.CheckBox
        Accessible.name: vpnRow.label
        Accessible.checked: vpnRow.on
        onClicked: vpnRow.toggled()
        Rectangle {
            anchors.fill: parent
            radius: IrisStyle.radiusTile
            color: vpnRow.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.round(12 * root.d)
            anchors.rightMargin: Math.round(10 * root.d)
            spacing: 10 * root.d
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                IrisText {
                    Layout.fillWidth: true
                    text: vpnRow.label
                    elide: Text.ElideRight
                    font.pixelSize: IrisStyle.typeLabel
                    font.weight: vpnRow.on ? Font.DemiBold : Font.Normal
                }
                IrisText {
                    Layout.fillWidth: true
                    visible: vpnRow.detail.length > 0
                    text: vpnRow.detail
                    color: IrisStyle.muted
                    elide: Text.ElideRight
                    font.pixelSize: IrisStyle.typeFootnote
                }
            }
            Rectangle {
                implicitWidth: Math.round(38 * root.d)
                implicitHeight: Math.round(22 * root.d)
                radius: height / 2
                color: vpnRow.on ? IrisStyle.identity.green : IrisStyle.fillHover
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                Rectangle {
                    y: Math.round(3 * root.d)
                    x: vpnRow.on ? parent.width - width - Math.round(3 * root.d) : Math.round(3 * root.d)
                    width: parent.height - Math.round(6 * root.d)
                    height: width
                    radius: width / 2
                    color: IrisStyle.onTint
                    Behavior on x { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                }
            }
        }
    }

    // One fact of a connection: its name quiet on the left, the value on the right; a tap copies it.
    component VpnFact: MouseArea {
        id: fact
        property string label: ""
        property string value: ""
        property string shown: fact.value
        property string glyph: "content_copy"
        signal copy(string value)
        implicitHeight: Math.round(28 * root.d)
        hoverEnabled: true
        cursorShape: fact.value.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
        visible: fact.value.length > 0
        onClicked: fact.copy(fact.value)
        Accessible.role: Accessible.Button
        Accessible.name: fact.label + " " + fact.shown
        Rectangle {
            anchors.fill: parent
            radius: IrisStyle.radiusRow
            color: fact.containsMouse ? IrisStyle.fillHover : ColorUtils.applyAlpha(IrisStyle.fillHover, 0)
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.round(10 * root.d)
            anchors.rightMargin: Math.round(8 * root.d)
            spacing: Math.round(8 * root.d)
            IrisText {
                text: fact.label
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeMeta
            }
            IrisText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: fact.shown
                elide: Text.ElideMiddle
                font.pixelSize: IrisStyle.typeMeta
                font.features: ({ "tnum": 1 })
            }
            MaterialSymbol {
                visible: fact.glyph.length > 0
                text: fact.glyph
                iconSize: Math.round(14 * root.d)
                color: IrisStyle.muted
                opacity: fact.containsMouse ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
            }
        }
    }
    // A connection's facts rest on one quiet fill under its row.
    component VpnFacts: Rectangle {
        default property alias facts: factColumn.data
        implicitHeight: factColumn.implicitHeight + Math.round(8 * root.d)
        radius: IrisStyle.radiusTile
        color: IrisStyle.fillQuiet
        ColumnLayout {
            id: factColumn
            anchors.fill: parent
            anchors.margins: Math.round(4 * root.d)
            spacing: 0
        }
    }

    component SectionCard: IrisSidebarSection {
        bare: true
        expanded: true
        contentActive: root.contentActive
        onNavigate: root.close()
    }


    readonly property var cardOptions: Config.options?.iris?.appearance?.surfaces?.cards ?? ({})
    component ColumnStrip: Item {
        id: strip
        property int workspaceId: -1
        property var windows: []
        property bool active: false
        readonly property real outputWidth: Math.max(1, Number(NiriService.outputs?.[root.screenName]?.logical?.width ?? 1920))
        readonly property real unit: strip.width / strip.outputWidth
        readonly property real gap: Math.round(4 * root.d)
        readonly property var floating: strip.windows.filter(window => window.workspace_id === strip.workspaceId && window.is_floating)
        readonly property var columns: {
            const grouped = {}
            for (const window of strip.windows) {
                if (window.workspace_id !== strip.workspaceId || window.is_floating) continue
                const pos = window.layout?.pos_in_scrolling_layout
                const column = Array.isArray(pos) ? Number(pos[0]) : 1
                if (!grouped[column]) grouped[column] = { index: column, width: 0, tiles: [] }
                const size = window.layout?.tile_size
                grouped[column].width = Math.max(grouped[column].width, Array.isArray(size) ? Number(size[0]) : strip.outputWidth / 2)
                grouped[column].tiles.push({ window: window, row: Array.isArray(pos) ? Number(pos[1]) : 1 })
            }
            const list = Object.values(grouped).sort((a, b) => a.index - b.index)
            let x = 0
            for (const column of list) {
                column.tiles.sort((a, b) => a.row - b.row)
                column.focused = column.tiles.some(tile => tile.window.is_focused)
                column.x = x
                column.w = Math.max(Math.round(30 * root.d), column.width * strip.unit - strip.gap)
                x += column.w + strip.gap
            }
            return list
        }
        readonly property real total: strip.columns.length > 0
            ? strip.columns[strip.columns.length - 1].x + strip.columns[strip.columns.length - 1].w : 0
        readonly property real offset: {
            if (strip.total <= strip.width) return 0
            const focus = strip.columns.find(column => column.focused) ?? strip.columns[strip.columns.length - 1]
            return Math.max(0, Math.min(strip.total - strip.width, focus.x + focus.w - strip.width))
        }
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: IrisStyle.radiusRow
            color: IrisStyle.fillQuiet
            visible: strip.columns.length === 0
            IrisText {
                anchors.centerIn: parent
                text: Translation.tr("Empty")
                role: IrisText.Meta
            }
        }
        Repeater {
            model: strip.columns
            Item {
                id: columnItem
                required property var modelData
                x: columnItem.modelData.x - strip.offset
                width: columnItem.modelData.w
                height: strip.height
                Behavior on x { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
                Repeater {
                    model: columnItem.modelData.tiles
                    MouseArea {
                        id: tileTap
                        required property var modelData
                        required property int index
                        readonly property int count: columnItem.modelData.tiles.length
                        readonly property bool focused: tileTap.modelData.window.is_focused ?? false
                        x: 0
                        y: tileTap.index * (strip.height + strip.gap) / tileTap.count
                        width: columnItem.width
                        height: (strip.height + strip.gap) / tileTap.count - strip.gap
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: String(tileTap.modelData.window.title ?? tileTap.modelData.window.app_id ?? "")
                        onClicked: { root.close(); NiriService.focusWindow(tileTap.modelData.window.id) }
                        Rectangle {
                            anchors.fill: parent
                            radius: Math.min(IrisStyle.radiusRow, height / 2)
                            color: tileTap.focused ? IrisStyle.tintFill(IrisStyle.accent)
                                : tileTap.containsMouse ? IrisStyle.fillHover : IrisStyle.fill
                            border.width: tileTap.focused ? 1 : 0
                            border.color: IrisStyle.accent
                            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                            Row {
                                anchors.centerIn: parent
                                spacing: Math.round(6 * root.d)
                                SmartAppIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: IrisPieces.appIcon(String(tileTap.modelData.window.app_id ?? ""))
                                    fallback: "application-x-executable"
                                    iconSize: Math.max(10, Math.min(Math.round(22 * root.d), tileTap.height - Math.round(8 * root.d), tileTap.width - Math.round(8 * root.d)))
                                }
                                IrisText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: tileTap.width > Math.round(96 * root.d)
                                    width: Math.min(implicitWidth, tileTap.width - Math.round(44 * root.d))
                                    text: AppSearch.lookupDesktopEntry(String(tileTap.modelData.window.app_id ?? ""))?.name
                                        ?? String(tileTap.modelData.window.app_id ?? "")
                                    font.pixelSize: IrisStyle.typeFootnote
                                    color: tileTap.focused ? IrisStyle.text : IrisStyle.subtext
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            visible: strip.floating.length > 0
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Math.round(3 * root.d)
            implicitWidth: floatingLabel.implicitWidth + Math.round(12 * root.d)
            implicitHeight: Math.round(18 * root.d)
            radius: height / 2
            color: IrisStyle.surfaceHighOpaque
            IrisText {
                id: floatingLabel
                anchors.centerIn: parent
                text: Translation.tr("%1 floating").arg(strip.floating.length)
                font.pixelSize: IrisStyle.typeCaption
                color: IrisStyle.subtext
            }
        }
    }

    component LevelCard: ColumnLayout {
        id: level
        property bool input: false
        readonly property bool muted: level.input ? Audio.micMuted : (Audio.sink?.audio?.muted ?? false)
        readonly property real value: Math.min(1, (level.input ? Audio.micVolume : Audio.value) ?? 0)
        spacing: 12 * root.d
        CardHeader {
            visible: root.cardOptions?.header ?? true
            glyph: level.input ? "mic" : "volume_up"
            tint: level.input ? IrisStyle.identity.orange : IrisStyle.identity.indigo
            title: level.input ? Translation.tr("Microphone") : Translation.tr("Sound")
            detail: Audio.friendlyDeviceName(level.input ? Audio.source : Audio.defaultSink)
            IrisNumber {
                text: Math.round(level.value * 100) + "%"
                color: IrisStyle.subtext
                pixelSize: IrisStyle.typeLabel
                weight: Font.DemiBold
            }
        }
        IrisCapsuleSlider {
            Layout.fillWidth: true
            implicitHeight: Math.round(48 * root.d)
            muted: level.muted
            icon: level.input ? (level.muted ? "mic_off" : "mic")
                : level.muted ? "volume_off" : level.value < 0.34 ? "volume_mute" : level.value < 0.67 ? "volume_down" : "volume_up"
            value: level.value
            Accessible.name: level.input ? Translation.tr("Microphone") : Translation.tr("Volume")
            onMoved: next => level.input ? Audio.setSourceVolume(next) : Audio.setSinkVolume(next)
            onIconClicked: level.input ? Audio.toggleMicMute() : Audio.toggleMute()
        }
        IrisDeviceList {
            visible: root.cardOptions?.devices ?? true
            Layout.fillWidth: true
            Layout.leftMargin: -6 * root.d
            Layout.rightMargin: -6 * root.d
            outputs: !level.input
            inputs: level.input
        }
    }

    Component {
        id: weatherCard
        SectionCard { kind: "weather" }
    }
    Component {
        id: notificationsCard
        SectionCard { kind: "notifications" }
    }
    Component {
        id: calendarCard
        SectionCard { kind: "calendar" }
    }
    Component {
        id: soundCard
        ColumnLayout {
            spacing: 6 * root.d
            LevelCard { Layout.fillWidth: true }
            SectionCard {
                visible: root.cardOptions?.mixer ?? true
                Layout.fillWidth: true
                Layout.leftMargin: -14 * root.d
                Layout.rightMargin: -14 * root.d
                kind: "mixer"
            }
        }
    }
    Component {
        id: micCard
        LevelCard { input: true }
    }
    Component {
        id: toolsCard
        ColumnLayout {
            spacing: 14 * root.d
            CardHeader {
                glyph: "timer"
                tint: IrisStyle.identity.orange
                title: Translation.tr("Timers")
                detail: TimerService.countdownRunning || TimerService.pomodoroRunning || TimerService.stopwatchRunning
                    ? Translation.tr("Running") : Translation.tr("Tap a dial to start, scroll to adjust")
            }
            IrisTools {
                Layout.fillWidth: true
                onActivityRequested: { root.close(); GlobalStates.irisIslandPageRequest = "activity" }
            }
        }
    }
    Component {
        id: trayCard
        ColumnLayout {
            id: tray
            readonly property var items: SystemTray.items.values.filter(item => item && item.id
                && (!(Config.options?.iris?.tray?.hidePassive ?? false) || item.status !== Status.Passive))
            spacing: 12 * root.d
            CardHeader {
                glyph: "apps"
                tint: IrisStyle.identity.teal
                title: Translation.tr("Tray")
                detail: tray.items.length > 0 ? Translation.tr("%1 background apps").arg(tray.items.length) : Translation.tr("Background apps")
            }
            IrisTray { Layout.fillWidth: true; showHeader: false; items: tray.items }
        }
    }

    Component {
        id: networkCard
        ColumnLayout {
            spacing: 10 * root.d
            CardHeader {
                glyph: Network.ethernet ? "lan" : Network.wifiEnabled ? "wifi" : "wifi_off"
                tint: IrisStyle.identity.blue
                title: Translation.tr("Network")
                detail: Network.ethernet ? Translation.tr("Ethernet")
                    : !Network.wifiEnabled ? Translation.tr("Wi-Fi off")
                    : Network.networkName.length > 0 ? Network.networkName : Translation.tr("Not connected")
                IrisIconButton {
                    materialIcon: "refresh"
                    enabled: Network.wifiEnabled
                    Accessible.name: Translation.tr("Scan for networks")
                    onClicked: Network.rescanWifi()
                }
                IrisIconButton {
                    materialIcon: Network.wifiEnabled ? "wifi" : "wifi_off"
                    selected: Network.wifiEnabled
                    Accessible.name: Translation.tr("Wi-Fi")
                    onClicked: Network.toggleWifi()
                }
            }
            IrisNetworkList {
                Layout.fillWidth: true
                Layout.leftMargin: -6 * root.d
                Layout.rightMargin: -6 * root.d
            }
        }
    }
    Component {
        id: bluetoothCard
        ColumnLayout {
            spacing: 10 * root.d
            CardHeader {
                glyph: BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                tint: IrisStyle.identity.sky
                title: Translation.tr("Bluetooth")
                detail: BluetoothStatus.activeDeviceSummary() || (BluetoothStatus.enabled
                    ? Translation.tr("Nothing connected") : Translation.tr("Off"))
                IrisIconButton {
                    materialIcon: BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                    selected: BluetoothStatus.enabled
                    enabled: BluetoothStatus.available
                    Accessible.name: Translation.tr("Bluetooth")
                    onClicked: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                }
            }
            IrisBluetoothList {
                Layout.fillWidth: true
                Layout.leftMargin: -6 * root.d
                Layout.rightMargin: -6 * root.d
            }
        }
    }
    Component {
        id: vitalsCard
        ColumnLayout {
            id: vitalsBody
            spacing: 10 * root.d
            ResourceUsageMonitor { target: vitalsBody; active: root.contentActive }
            CardHeader {
                glyph: "monitoring"
                tint: IrisStyle.identity.teal
                title: Translation.tr("Vitals")
                detail: Translation.tr("What this machine is doing")
            }
            Repeater {
                model: [
                    { label: Translation.tr("Processor"), glyph: "memory", level: ResourceUsage.cpuUsage, value: Math.round(ResourceUsage.cpuUsage * 100), unit: "%", warn: 0.85 },
                    { label: Translation.tr("Memory"), glyph: "memory_alt", level: ResourceUsage.memoryUsedPercentage, value: Math.round(ResourceUsage.memoryUsedPercentage * 100), unit: "%", warn: 0.85 },
                    { label: Translation.tr("Heat"), glyph: "device_thermostat", level: ResourceUsage.tempPercentage, value: ResourceUsage.maxTemp, unit: "°", warn: ResourceUsage.tempWarningThreshold / 100 },
                    { label: Translation.tr("Disk"), glyph: "hard_drive", level: ResourceUsage.diskUsedPercentage, value: Math.round(ResourceUsage.diskUsedPercentage * 100), unit: "%", warn: 0.9 }
                ]
                RowLayout {
                    id: vital
                    required property var modelData
                    readonly property real level: Math.max(0, Math.min(1, Number(vital.modelData.level) || 0))
                    readonly property color tint: vital.level >= vital.modelData.warn ? IrisStyle.danger : IrisStyle.accent
                    Layout.fillWidth: true
                    spacing: 10 * root.d
                    Accessible.name: vital.modelData.label + ", " + vital.modelData.value + vital.modelData.unit
                    Item {
                        Layout.preferredWidth: Math.round(30 * root.d)
                        Layout.preferredHeight: Layout.preferredWidth
                        ProgressRing {
                            anchors.fill: parent
                            stroke: Math.max(2, 2.4 * root.d)
                            tint: vital.tint
                            progress: vital.level
                            Behavior on progress { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
                        }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: vital.modelData.glyph
                            fill: 1
                            iconSize: Math.round(13 * root.d)
                            color: vital.tint
                        }
                    }
                    IrisText {
                        Layout.fillWidth: true
                        text: vital.modelData.label
                        elide: Text.ElideRight
                    }
                    Metric {
                        value: vital.modelData.value
                        unit: vital.modelData.unit
                        pixelSize: IrisStyle.typeHeadline
                        weight: Font.Bold
                        color: vital.tint
                    }
                }
            }
        }
    }
    Component {
        id: workspacesCard
        ColumnLayout {
            id: workspaceBody
            readonly property var workspaces: (NiriService.allWorkspaces ?? [])
                .filter(ws => ws.output === root.screenName)
                .slice().sort((a, b) => Number(a.idx ?? 0) - Number(b.idx ?? 0))
            readonly property var windows: (NiriService.windows ?? [])
                .filter(window => workspaceBody.workspaces.some(ws => ws.id === window.workspace_id))
            spacing: 10 * root.d
            CardHeader {
                glyph: "grid_view"
                tint: IrisStyle.identity.purple
                title: Translation.tr("Workspaces")
                detail: Translation.tr("%1 workspaces · %2 windows").arg(workspaceBody.workspaces.length).arg(workspaceBody.windows.length)
                IrisIconButton {
                    materialIcon: "space_dashboard"
                    Accessible.name: Translation.tr("Open overview")
                    onClicked: { root.close(); NiriService.toggleOverview() }
                }
            }
            Repeater {
                model: workspaceBody.workspaces
                RowLayout {
                    id: workspaceRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8 * root.d
                    Rectangle {
                        Layout.preferredWidth: Math.round(44 * root.d)
                        Layout.preferredHeight: Layout.preferredWidth
                        radius: IrisStyle.iconRadius(width)
                        color: workspaceRow.modelData.is_active ? IrisStyle.tintFill(IrisStyle.accent) : IrisStyle.fillQuiet
                        border.width: workspaceRow.modelData.is_active ? 0 : 1
                        border.color: IrisStyle.border
                        IrisText {
                            anchors.centerIn: parent
                            text: workspaceRow.modelData.idx ?? "–"
                            color: workspaceRow.modelData.is_active ? IrisStyle.accent : IrisStyle.text
                            font.family: IrisStyle.fontNumbers
                            font.features: ({ "tnum": 1 })
                            font.pixelSize: IrisStyle.typeBody
                            font.weight: IrisStyle.weight(Font.Bold)
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.close()
                                NiriService.switchToWorkspaceById(workspaceRow.modelData.id)
                            }
                        }
                    }
                    ColumnStrip {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(44 * root.d)
                        workspaceId: workspaceRow.modelData.id
                        windows: workspaceBody.windows
                        active: workspaceRow.modelData.is_active ?? false
                    }
                }
            }
        }
    }
    Component {
        id: updatesCard
        ColumnLayout {
            spacing: 10 * root.d
            CardHeader {
                glyph: Updates.count > 0 ? "deployed_code_update" : "task_alt"
                tint: Updates.count > 0 ? IrisStyle.secondaryAccent : IrisStyle.identity.green
                title: Translation.tr("Updates")
                detail: Updates.count > 0
                    ? Translation.tr("%1 packages waiting").arg(Updates.count)
                    : Translation.tr("Everything is up to date")
                IrisIconButton {
                    materialIcon: "refresh"
                    Accessible.name: Translation.tr("Check again")
                    onClicked: Updates.refresh()
                }
            }
            IrisNumber {
                Layout.alignment: Qt.AlignHCenter
                text: Updates.count
                pixelSize: 44 * IrisStyle.typeScale
                weight: Font.Bold
                color: Updates.count > 0 ? IrisStyle.secondaryAccent : IrisStyle.identity.green
            }
            IrisButton {
                Layout.fillWidth: true
                visible: Updates.count > 0
                text: Translation.tr("Update now")
                buttonRadius: IrisStyle.radiusTile
                implicitHeight: Math.round(38 * root.d)
                onClicked: {
                    root.close()
                    ShellExec.execCmd(Config.options?.apps?.update ?? "kitty -e sudo pacman -Syu")
                }
            }
        }
    }
    Component {
        id: vpnCard
        ColumnLayout {
            id: vpn
            spacing: 8 * root.d
            Component.onCompleted: Vpn.keepAlive()
            Component.onDestruction: Vpn.releaseKeepAlive()
            // Hides addresses and the account for a screenshot; the values still copy whole.
            property bool masked: true
            property bool copied: false
            // A window the card hands off to (a file chooser, NetworkManager's editor, a terminal) opens with the card gone.
            Connections {
                target: Vpn
                function onHandOff(): void { GlobalStates.irisBubbleCard = null }
            }
            Timer { id: copiedTimer; interval: 1400; onTriggered: vpn.copied = false }
            function copy(value: string): void {
                Quickshell.clipboardText = value
                vpn.copied = true
                copiedTimer.restart()
            }
            function hide(value: string): string {
                if (!vpn.masked || value.length === 0) return value
                if (/^\d+\.\d+\.\d+\.\d+/.test(value)) return value.replace(/^(\d+\.\d+)\.\d+\.\d+/, "$1.•••.•••")
                if (value.includes("@")) return value.slice(0, 2) + "•••" + value.slice(value.indexOf("@"))
                if (value.includes(":")) return value.split(":")[0] + ":••••:••••"
                return value.split(".")[0] + ".•••"
            }
            function rate(bytes: real): string {
                return bytes >= 1048576 ? (bytes / 1048576).toFixed(1) + " MB/s"
                    : bytes >= 1024 ? (bytes / 1024).toFixed(1) + " KB/s" : Math.round(bytes) + " B/s"
            }
            function traffic(dev: string): string {
                const r = Vpn.rates[dev]
                return r ? "↓ " + vpn.rate(r.down) + "   ↑ " + vpn.rate(r.up) : ""
            }
            CardHeader {
                glyph: Vpn.connected ? "vpn_lock" : "vpn_key_off"
                tint: Vpn.connected ? IrisStyle.identity.green : IrisStyle.muted
                title: Translation.tr("VPN")
                detail: vpn.copied ? Translation.tr("Copied")
                    : Vpn.busy ? Translation.tr("Working…")
                    : Vpn.connected ? Translation.tr("On through %1").arg(Vpn.activeName)
                    : Translation.tr("Not connected")
                IrisIconButton {
                    visible: Vpn.details
                    materialIcon: vpn.masked ? "visibility_off" : "visibility"
                    selected: vpn.masked
                    Accessible.name: vpn.masked ? Translation.tr("Show addresses") : Translation.tr("Hide addresses")
                    onClicked: vpn.masked = !vpn.masked
                }
                IrisIconButton {
                    materialIcon: "info"
                    selected: Vpn.details
                    Accessible.name: Vpn.details ? Translation.tr("Hide details") : Translation.tr("Show details")
                    onClicked: Vpn.setDetails(!Vpn.details)
                }
                IrisIconButton {
                    materialIcon: "refresh"
                    Accessible.name: Translation.tr("Check again")
                    onClicked: Vpn.refresh()
                }
            }
            IrisText {
                Layout.fillWidth: true
                visible: Vpn.profiles.length === 0
                text: Vpn.available
                    ? Translation.tr("OpenVPN and WireGuard profiles you add in NetworkManager show up here too.")
                    : Translation.tr("No VPN yet. Add an OpenVPN or WireGuard profile in NetworkManager, or install Tailscale.")
                color: IrisStyle.muted
                wrapMode: Text.WordWrap
                font.pixelSize: IrisStyle.typeMeta
            }
            VpnRow {
                Layout.fillWidth: true
                visible: Vpn.tailscaleInstalled
                label: "Tailscale"
                detail: Vpn.tailscaleUp ? vpn.hide(Vpn.tailscaleAddress)
                    : Vpn.tailscaleSignedOut ? Translation.tr("Signed out") : Translation.tr("Off")
                on: Vpn.tailscaleUp
                onToggled: Vpn.toggleTailscale()
            }
            IrisButton {
                Layout.fillWidth: true
                visible: Vpn.tailscaleSignedOut
                enabled: !Vpn.signingIn
                emphasized: true
                text: Vpn.signingIn ? Translation.tr("Finish in your browser…") : Translation.tr("Sign in to Tailscale")
                buttonRadius: IrisStyle.radiusTile
                implicitHeight: Math.round(34 * root.d)
                onClicked: Vpn.signInTailscale()
            }
            VpnFacts {
                Layout.fillWidth: true
                visible: Vpn.details && Vpn.tailscaleInstalled && Vpn.tailscaleAddress.length > 0
                VpnFact { Layout.fillWidth: true; label: Translation.tr("IPv4"); value: Vpn.tailscaleAddress; shown: vpn.hide(value); onCopy: value => vpn.copy(value) }
                VpnFact { Layout.fillWidth: true; label: Translation.tr("IPv6"); value: Vpn.tailscaleAddress6; shown: vpn.hide(value); onCopy: value => vpn.copy(value) }
                VpnFact { Layout.fillWidth: true; label: Translation.tr("Name"); value: Vpn.tailscaleDns; shown: vpn.hide(value); onCopy: value => vpn.copy(value) }
                VpnFact { Layout.fillWidth: true; label: Translation.tr("Account"); value: Vpn.tailscaleAccount; shown: vpn.hide(value); onCopy: value => vpn.copy(value) }
                VpnFact { Layout.fillWidth: true; label: Translation.tr("Exit node"); value: Vpn.tailscaleExitName.length > 0 ? Vpn.tailscaleExitName : Translation.tr("None, direct"); onCopy: value => vpn.copy(value) }
                VpnFact { Layout.fillWidth: true; label: Translation.tr("Traffic"); value: Vpn.tailscaleUp ? vpn.traffic("tailscale0") : ""; onCopy: value => vpn.copy(value) }
            }
            ColumnLayout {
                Layout.fillWidth: true
                visible: Vpn.details && Vpn.tailscaleDevices.length > 0
                spacing: Math.round(2 * root.d)
                IrisText {
                    Layout.leftMargin: Math.round(4 * root.d)
                    Layout.topMargin: Math.round(4 * root.d)
                    text: Translation.tr("Devices · %1 of %2 online").arg(Vpn.tailscaleOnline).arg(Vpn.tailscaleDevices.length)
                    color: IrisStyle.muted
                    font.pixelSize: IrisStyle.typeFootnote
                    font.weight: IrisStyle.weight(Font.Medium)
                }
                Repeater {
                    model: Vpn.tailscaleDevices.slice(0, 6)
                    MouseArea {
                        id: device
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: Math.round(36 * root.d)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: vpn.copy(device.modelData.address)
                        Accessible.role: Accessible.Button
                        Accessible.name: device.modelData.name
                        Rectangle {
                            anchors.fill: parent
                            radius: IrisStyle.radiusRow
                            color: device.containsMouse ? IrisStyle.fillHover : ColorUtils.applyAlpha(IrisStyle.fillHover, 0)
                            Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(10 * root.d)
                            anchors.rightMargin: Math.round(8 * root.d)
                            spacing: Math.round(10 * root.d)
                            Rectangle {
                                implicitWidth: Math.round(8 * root.d)
                                implicitHeight: implicitWidth
                                radius: width / 2
                                color: device.modelData.online ? IrisStyle.identity.green : IrisStyle.fillActive
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                IrisText {
                                    Layout.fillWidth: true
                                    text: device.modelData.name
                                    elide: Text.ElideRight
                                    font.pixelSize: IrisStyle.typeLabel
                                    color: device.modelData.online ? IrisStyle.text : IrisStyle.textSecondary
                                }
                                IrisText {
                                    Layout.fillWidth: true
                                    text: [vpn.hide(device.modelData.address), device.modelData.os].filter(part => part.length > 0).join(" · ")
                                    elide: Text.ElideRight
                                    color: IrisStyle.muted
                                    font.pixelSize: IrisStyle.typeFootnote
                                    font.features: ({ "tnum": 1 })
                                }
                            }
                            IrisChip {
                                visible: Vpn.tailscaleUp && (device.modelData.exitOption || device.modelData.exitNode)
                                selected: device.modelData.exitNode
                                glyph: "logout"
                                label: device.modelData.exitNode ? Translation.tr("Exit node") : Translation.tr("Use as exit")
                                Accessible.name: device.modelData.exitNode ? Translation.tr("Stop using %1 as exit node").arg(device.modelData.name)
                                    : Translation.tr("Send traffic through %1").arg(device.modelData.name)
                                onClicked: Vpn.setExitNode(device.modelData.exitNode ? "" : device.modelData.address)
                            }
                        }
                    }
                }
                IrisText {
                    Layout.leftMargin: Math.round(10 * root.d)
                    visible: Vpn.tailscaleDevices.length > 6
                    text: Translation.tr("+%1 more").arg(Vpn.tailscaleDevices.length - 6)
                    color: IrisStyle.muted
                    font.pixelSize: IrisStyle.typeFootnote
                }
            }
            Repeater {
                model: Vpn.profiles
                ColumnLayout {
                    id: profile
                    required property var modelData
                    readonly property var facts: Vpn.profileDetails[profile.modelData.uuid] ?? null
                    Layout.fillWidth: true
                    spacing: Math.round(4 * root.d)
                    VpnRow {
                        Layout.fillWidth: true
                        label: profile.modelData.name
                        detail: profile.modelData.active && profile.facts?.address ? profile.modelData.type + " · " + vpn.hide(profile.facts.address) : profile.modelData.type
                        on: profile.modelData.active
                        onToggled: Vpn.toggleProfile(profile.modelData.uuid)
                    }
                    VpnFacts {
                        Layout.fillWidth: true
                        visible: Vpn.details && profile.modelData.active && profile.facts !== null
                        VpnFact { Layout.fillWidth: true; label: Translation.tr("Address"); value: profile.facts?.address ?? ""; shown: vpn.hide(value); onCopy: value => vpn.copy(value) }
                        VpnFact { Layout.fillWidth: true; label: Translation.tr("Gateway"); value: profile.facts?.gateway ?? ""; shown: vpn.hide(value); onCopy: value => vpn.copy(value) }
                        VpnFact { Layout.fillWidth: true; label: Translation.tr("DNS"); value: profile.facts?.dns ?? ""; shown: vpn.hide(value); onCopy: value => vpn.copy(value) }
                        VpnFact { Layout.fillWidth: true; label: Translation.tr("Interface"); value: profile.facts?.device ?? ""; onCopy: value => vpn.copy(value) }
                        VpnFact { Layout.fillWidth: true; label: Translation.tr("Traffic"); value: vpn.traffic(profile.facts?.device ?? ""); onCopy: value => vpn.copy(value) }
                    }
                    VpnFacts {
                        Layout.fillWidth: true
                        visible: Vpn.details
                        VpnFact {
                            Layout.fillWidth: true
                            label: Translation.tr("Connect automatically")
                            glyph: ""
                            value: profile.modelData.autoconnect ? Translation.tr("On") : Translation.tr("Off")
                            onCopy: Vpn.setAutoconnect(profile.modelData.uuid, !profile.modelData.autoconnect)
                        }
                        VpnFact {
                            Layout.fillWidth: true
                            visible: Vpn.canCreate
                            label: Translation.tr("Settings")
                            glyph: "open_in_new"
                            value: Vpn.hasEditor ? Translation.tr("NetworkManager") : "nmtui"
                            onCopy: Vpn.editProfile(profile.modelData.uuid)
                        }
                    }
                }
            }
            IrisText {
                Layout.fillWidth: true
                visible: Vpn.errorText.length > 0
                text: Vpn.errorText
                color: IrisStyle.danger
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                font.pixelSize: IrisStyle.typeMeta
            }
            IrisText {
                Layout.fillWidth: true
                visible: Vpn.hasNmcli && !Vpn.canCreate
                text: Vpn.missingEditorText
                color: IrisStyle.muted
                wrapMode: Text.WordWrap
                font.pixelSize: IrisStyle.typeMeta
            }
            RowLayout {
                Layout.fillWidth: true
                visible: Vpn.hasNmcli
                spacing: Math.round(6 * root.d)
                IrisButton {
                    Layout.fillWidth: true
                    visible: Vpn.canCreate
                    enabled: !Vpn.busy
                    text: Vpn.hasEditor ? Translation.tr("New WireGuard…") : Translation.tr("New VPN…")
                    buttonRadius: IrisStyle.radiusTile
                    implicitHeight: Math.round(34 * root.d)
                    onClicked: Vpn.newProfile("wireguard")
                }
                IrisButton {
                    Layout.fillWidth: true
                    visible: Vpn.hasEditor && Vpn.hasVpnPlugins
                    enabled: !Vpn.busy
                    text: Translation.tr("Other VPN…")
                    buttonRadius: IrisStyle.radiusTile
                    implicitHeight: Math.round(34 * root.d)
                    onClicked: Vpn.newProfile("vpn")
                }
                IrisButton {
                    Layout.fillWidth: true
                    enabled: !Vpn.busy
                    text: Translation.tr("Import a file…")
                    buttonRadius: IrisStyle.radiusTile
                    implicitHeight: Math.round(34 * root.d)
                    onClicked: Vpn.chooseProfileFile()
                }
            }
            IrisButton {
                Layout.fillWidth: true
                visible: Vpn.needsTailscaleOperator
                enabled: !Vpn.busy
                text: Translation.tr("Let me control Tailscale")
                buttonRadius: IrisStyle.radiusTile
                implicitHeight: Math.round(34 * root.d)
                onClicked: Vpn.fixTailscaleOperator()
            }
        }
    }
    Component {
        id: shellUpdateCard
        ColumnLayout {
            spacing: 10 * root.d
            CardHeader {
                glyph: "rocket_launch"
                tint: IrisStyle.secondaryAccent
                title: ShellUpdates.remoteVersion.length > 0
                    ? Translation.tr("iNiR %1").arg(ShellUpdates.remoteVersion) : Translation.tr("New iNiR")
                detail: ShellUpdates.repoDiverged
                    ? Translation.tr("Upstream history changed; your local work is kept")
                    : ShellUpdates.commitsBehind > 0
                        ? Translation.tr("%1 commits behind").arg(ShellUpdates.commitsBehind)
                        : Translation.tr("Ready to update")
            }
            IrisText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: ShellUpdates.latestMessage
                color: IrisStyle.subtext
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                font.pixelSize: IrisStyle.typeMeta
            }
            IrisButton {
                Layout.fillWidth: true
                enabled: !ShellUpdates.isUpdating
                text: ShellUpdates.isUpdating
                    ? Translation.tr("Updating…") : Translation.tr("Update now")
                buttonRadius: IrisStyle.radiusTile
                implicitHeight: Math.round(38 * root.d)
                onClicked: { root.close(); ShellUpdates.performUpdate() }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * root.d
                IrisButton {
                    Layout.fillWidth: true
                    quiet: true
                    text: Translation.tr("What changed")
                    buttonRadius: IrisStyle.radiusTile
                    implicitHeight: Math.round(32 * root.d)
                    onClicked: { root.close(); ShellUpdates.openOverlay() }
                }
                IrisButton {
                    Layout.fillWidth: true
                    quiet: true
                    text: Translation.tr("Not now")
                    buttonRadius: IrisStyle.radiusTile
                    implicitHeight: Math.round(32 * root.d)
                    onClicked: { root.close(); ShellUpdates.dismiss() }
                }
            }
        }
    }
    Component {
        id: animeCard
        ColumnLayout {
            id: airing
            readonly property var shows: IrisPieces.animeUpcoming.slice(0,
                Math.max(3, Math.min(8, Number(Config.options?.iris?.anime?.shows ?? 5))))
            readonly property var next: IrisPieces.animeNext
            spacing: 8 * root.d
            Component.onCompleted: AnimeService.fetchTopAiring()
            CardHeader {
                glyph: IrisPieces.glyphOf("anime", "")
                tint: IrisStyle.identity.pink
                title: Translation.tr("Airing")
                detail: airing.next
                    ? Translation.tr("Ep %1 in %2").arg(airing.next.nextEpisode).arg(IrisPieces.animeWait(airing.next.airingAt))
                    : !Network.online ? Network.offlineReason
                    : AnimeService.lastError.length > 0 && !AnimeService.loading ? Translation.tr("AniList didn't answer (´・ω・`)")
                    : Translation.tr("Nothing scheduled yet")
                IrisIconButton {
                    enabled: Network.online
                    materialIcon: "refresh"
                    Accessible.name: Translation.tr("Check again")
                    onClicked: { AnimeService.invalidateTopCache(); AnimeService.fetchTopAiring() }
                }
            }
            Repeater {
                model: airing.shows
                MouseArea {
                    id: showRow
                    required property var modelData
                    readonly property bool followed: IrisPieces.animeFollows(showRow.modelData.id)
                    Layout.fillWidth: true
                    implicitHeight: Math.round(46 * root.d)
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    Accessible.role: Accessible.CheckBox
                    Accessible.checked: showRow.followed
                    Accessible.name: Translation.tr("Follow %1").arg(showRow.modelData.title)
                    onClicked: IrisPieces.animeToggleFollow(showRow.modelData.id)
                    Rectangle {
                        anchors.fill: parent
                        radius: IrisStyle.radiusTile
                        color: showRow.containsMouse ? IrisStyle.fillHover : "transparent"
                        Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.round(6 * root.d)
                        anchors.rightMargin: Math.round(8 * root.d)
                        spacing: 10 * root.d
                        ClippingRectangle {
                            implicitWidth: Math.round(28 * root.d)
                            implicitHeight: Math.round(38 * root.d)
                            radius: IrisStyle.iconRadius(width)
                            color: IrisStyle.fillQuiet
                            IrisImage {
                                anchors.fill: parent
                                source: String(showRow.modelData.imageSmall ?? showRow.modelData.image ?? "")
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            IrisText {
                                Layout.fillWidth: true
                                text: showRow.modelData.title
                                elide: Text.ElideRight
                                font.pixelSize: IrisStyle.typeLabel
                                font.weight: showRow.followed ? Font.DemiBold : Font.Normal
                            }
                            IrisText {
                                Layout.fillWidth: true
                                text: Translation.tr("Ep %1").arg(showRow.modelData.nextEpisode)
                                color: IrisStyle.muted
                                elide: Text.ElideRight
                                font.pixelSize: IrisStyle.typeFootnote
                            }
                        }
                        IrisText {
                            text: IrisPieces.animeWait(showRow.modelData.airingAt)
                            color: showRow.followed ? IrisStyle.identity.pink : IrisStyle.subtext
                            font.family: IrisStyle.fontNumbers
                            font.features: ({ "tnum": 1 })
                            font.pixelSize: IrisStyle.typeMeta
                            font.weight: IrisStyle.weight(Font.DemiBold)
                        }
                        MaterialSymbol {
                            opacity: showRow.followed ? 1 : showRow.containsMouse ? 0.5 : 0
                            text: "bookmark"
                            fill: showRow.followed ? 1 : 0
                            iconSize: Math.round(15 * root.d)
                            color: showRow.followed ? IrisStyle.identity.pink : IrisStyle.subtext
                            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                        }
                    }
                }
            }
            IrisText {
                Layout.fillWidth: true
                visible: airing.shows.length > 0
                text: IrisPieces.animeFollowing.length > 0
                    ? Translation.tr("The bubble shows what you follow first")
                    : Translation.tr("Tap a show to follow it")
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeMeta
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
    Component {
        id: watchingCard
        IrisWatchingCard {
            onCloseRequested: root.close()
        }
    }
    Component {
        id: mediaCard
        Item {
            id: player
            ColorQuantizer {
                id: tintQuantizer
                source: MediaArtwork.displaySource
                depth: 2
                rescaleSize: 48
            }
            readonly property color tint: {
                const colors = tintQuantizer.colors ?? []
                let best = null
                let bestScore = -1
                for (let i = 0; i < colors.length; i++) {
                    const c = colors[i]
                    const score = Math.max(0, c.hslSaturation) * (1 - Math.abs(c.hslLightness - 0.5))
                    if (score > bestScore) { bestScore = score; best = c }
                }
                if (!best || best.hslSaturation < 0.14 || best.hslHue < 0) return IrisStyle.text
                return Qt.hsla(best.hslHue, Math.max(0.5, best.hslSaturation),
                    Math.max(0.64, Math.min(0.76, best.hslLightness + 0.22)), 1)
            }
            readonly property real frameInset: IrisStyle.radiusSheet - IrisStyle.radiusCard
            implicitHeight: card.implicitHeight + player.frameInset * 2
            Loader {
                anchors.fill: parent
                active: (Config.options?.iris?.player?.artworkBackground ?? true)
                    && MediaArtwork.displaySource.length > 0
                sourceComponent: Item {
                    IrisMediaBackdrop { anchors.fill: parent; source: MediaArtwork.displaySource; strength: 0.9 }
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: IrisStyle.tintFill(player.tint) }
                            GradientStop { position: 1; color: "transparent" }
                        }
                    }
                }
            }
            Rectangle {
                id: playerFrame
                anchors.fill: parent
                anchors.margins: player.frameInset
                radius: IrisStyle.radiusCard
                color: IrisStyle.fillQuiet
            }
            IrisMediaCard {
                id: card
                anchors.left: playerFrame.left
                anchors.right: playerFrame.right
                anchors.top: playerFrame.top
                showBackground: false
                active: root.contentActive
                tint: player.tint
            }
        }
    }
}
