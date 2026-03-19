pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks

WBarAttachedPanelContent {
    id: root

    revealFromSides: true
    revealFromLeft: true

    Component.onCompleted: {
        if (GlobalStates.waffleWidgetsOpen)
            ResourceUsage.ensureRunning()
    }

    Connections {
        target: GlobalStates
        function onWaffleWidgetsOpenChanged() {
            if (GlobalStates.waffleWidgetsOpen) {
                ResourceUsage.ensureRunning()
            }
        }
    }

    readonly property bool barAtBottom: Config.options?.waffles?.bar?.bottom ?? false
    readonly property list<string> defaultQuickActionIds: ["files", "terminal", "settings", "wallpaper", "screenshot", "screenRecord", "session"]
    readonly property var quickActionDefinitions: [
        { id: "files", icon: "folder", label: Translation.tr("Files") },
        { id: "terminal", icon: "terminal", label: Translation.tr("Terminal") },
        { id: "settings", icon: "settings", label: Translation.tr("Settings") },
        { id: "wallpaper", icon: "image", label: Translation.tr("Wallpaper") },
        { id: "screenshot", icon: "screenshot", label: Translation.tr("Screenshot") },
        { id: "screenRecord", icon: "record", label: RecorderStatus.isRecording ? Translation.tr("Stop") : Translation.tr("Record") },
        { id: "session", icon: "power", label: Translation.tr("Session") }
    ]
    readonly property var configuredQuickActionIds: {
        const configured = Config.options?.waffles?.widgetsPanel?.quickActions
        return Array.isArray(configured) ? configured : defaultQuickActionIds
    }
    readonly property var enabledQuickActions: configuredQuickActionIds
        .map(actionId => quickActionDefinitions.find(action => action.id === actionId))
        .filter(action => !!action)

    function runQuickAction(actionId: string): void {
        switch (actionId) {
        case "files":
            Quickshell.execDetached(["/usr/bin/nautilus"])
            break
        case "terminal":
            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "terminal"])
            break
        case "settings":
            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings"])
            break
        case "wallpaper": {
            const useMain = Config.options?.waffles?.background?.useMainWallpaper ?? true
            Config.setNestedValue("wallpaperSelector.selectionTarget", useMain ? "main" : "waffle")
            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "wallpaperSelector", "toggle"])
            break
        }
        case "screenshot":
            GlobalStates.regionSelectorOpen = true
            break
        case "screenRecord":
            GlobalActions.runById("screen-record", "")
            break
        case "session":
            GlobalStates.sessionOpen = true
            break
        default:
            return
        }

        GlobalStates.waffleWidgetsOpen = false
    }

    contentItem: ColumnLayout {
        anchors {
            left: parent.left
            right: parent.right
            top: root.barAtBottom ? undefined : parent.top
            bottom: root.barAtBottom ? parent.bottom : undefined
            margins: root.visualMargin
            bottomMargin: 0
        }
        spacing: 12

        WPane {
            Layout.fillWidth: true
            screenX: root.panelScreenX + root.visualMargin * 2
            screenY: root.panelScreenY + root.visualMargin * 2
            screenWidth: root._screenW
            screenHeight: root._screenH
            contentItem: WidgetsPaneContent {}
        }
    }

    component WidgetsPaneContent: Rectangle {
        id: paneContent
        implicitWidth: 380
        implicitHeight: Math.max(contentColumn.implicitHeight, 80)
        color: Looks.colors.bgPanelBody

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            spacing: 0

            // Header
            BodyRectangle {
                Layout.fillWidth: true
                implicitHeight: 56

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16

                    WText {
                        text: Translation.tr("Widgets")
                        font.pixelSize: Looks.font.pixelSize.larger
                        font.weight: Font.DemiBold
                    }

                    Item { Layout.fillWidth: true }

                    WBorderlessButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        contentItem: FluentIcon {
                            anchors.centerIn: parent
                            icon: "settings"
                            implicitSize: 16
                        }
                        onClicked: {
                            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings"])
                            GlobalStates.waffleWidgetsOpen = false
                        }
                    }
                }
            }

            WPanelSeparator { visible: Config.options?.waffles?.widgetsPanel?.showDateTime ?? true }

            // Date & Time widget
            BodyRectangle {
                Layout.fillWidth: true
                implicitHeight: dateTimeContent.implicitHeight + 36
                visible: Config.options?.waffles?.widgetsPanel?.showDateTime ?? true

                RowLayout {
                    id: dateTimeContent
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    ColumnLayout {
                        spacing: 4
                        WText {
                            text: DateTime.time
                            font.pixelSize: 46
                            font.weight: Font.DemiBold
                        }
                        WText {
                            text: Qt.locale().toString(DateTime.clock.date, "dddd, MMMM d")
                            font.pixelSize: Looks.font.pixelSize.normal
                            color: Looks.colors.fg1
                        }
                    }

                    Item { Layout.fillWidth: true }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 6
                        WText {
                            text: Translation.tr("Uptime")
                            font.pixelSize: Looks.font.pixelSize.tiny
                            color: Looks.colors.subfg
                            font.weight: Font.Medium
                        }
                        WText {
                            text: DateTime.uptime || "--"
                            font.pixelSize: Looks.font.pixelSize.large
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            WPanelSeparator { visible: (Config.options?.waffles?.widgetsPanel?.showWeather ?? true) && Weather.data.temp !== undefined && Weather.data.temp !== "" }

            // Weather widget
            BodyRectangle {
                Layout.fillWidth: true
                implicitHeight: weatherContent.implicitHeight + 32
                visible: (Config.options?.waffles?.widgetsPanel?.showWeather ?? true) && Weather.data.temp !== undefined && Weather.data.temp !== ""

                ColumnLayout {
                    id: weatherContent
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        FluentIcon {
                            icon: Weather.isNightNow() ? "weather-moon" : "weather-sunny"
                            implicitSize: 48
                            color: Weather.isNightNow() ? Looks.colors.accent : Looks.colors.fg
                        }

                        ColumnLayout {
                            spacing: 2
                            WText {
                                text: Weather.data.temp || "--°"
                                font.pixelSize: 32
                                font.weight: Font.DemiBold
                            }
                            WText {
                                text: Weather.showVisibleCity ? Weather.visibleCity : Translation.tr("Weather")
                                color: Looks.colors.fg1
                            }
                        }

                        Item { Layout.fillWidth: true }

                        ColumnLayout {
                            spacing: 2
                            WText {
                                text: Translation.tr("Feels ") + (Weather.data.tempFeelsLike || "--")
                                font.pixelSize: Looks.font.pixelSize.small
                                color: Looks.colors.fg1
                            }
                            WText {
                                text: Weather.data.humidity || ""
                                font.pixelSize: Looks.font.pixelSize.small
                                color: Looks.colors.fg1
                            }
                        }
                    }

                    // Extra weather info row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        ColumnLayout {
                            spacing: 2
                            WText { text: Translation.tr("Wind"); font.pixelSize: Looks.font.pixelSize.tiny; color: Looks.colors.fg1 }
                            WText { text: Weather.data.wind + " " + Weather.data.windDir; font.pixelSize: Looks.font.pixelSize.small }
                        }
                        ColumnLayout {
                            spacing: 2
                            WText { text: Translation.tr("UV"); font.pixelSize: Looks.font.pixelSize.tiny; color: Looks.colors.fg1 }
                            WText { text: String(Weather.data.uv); font.pixelSize: Looks.font.pixelSize.small }
                        }
                        ColumnLayout {
                            spacing: 2
                            WText { text: "☀"; font.pixelSize: Looks.font.pixelSize.tiny; color: Looks.colors.fg1 }
                            WText { text: Weather.data.sunrise; font.pixelSize: Looks.font.pixelSize.small }
                        }
                        ColumnLayout {
                            spacing: 2
                            WText { text: "☾"; font.pixelSize: Looks.font.pixelSize.tiny; color: Looks.colors.fg1 }
                            WText { text: Weather.data.sunset; font.pixelSize: Looks.font.pixelSize.small }
                        }
                    }
                }
            }

            WPanelSeparator { visible: Config.options?.waffles?.widgetsPanel?.showSystem ?? true }

            // System Resources widget
            BodyRectangle {
                Layout.fillWidth: true
                implicitHeight: sysContent.implicitHeight + 36
                visible: Config.options?.waffles?.widgetsPanel?.showSystem ?? true

                ColumnLayout {
                    id: sysContent
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        WText {
                            text: Translation.tr("System")
                            font.pixelSize: Looks.font.pixelSize.large
                            font.weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: true }
                        WBorderlessButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            contentItem: FluentIcon { anchors.centerIn: parent; icon: "open"; implicitSize: 14 }
                            onClicked: {
                                Quickshell.execDetached(["missioncenter"])
                                GlobalStates.waffleWidgetsOpen = false
                            }
                        }
                    }

                    // CPU
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            WText { text: Translation.tr("CPU"); font.pixelSize: Looks.font.pixelSize.small; font.weight: Font.Medium }
                            Item { Layout.fillWidth: true }
                            WText {
                                text: Math.round(ResourceUsage.cpuUsage * 100) + "%"
                                font.pixelSize: Looks.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: ResourceUsage.cpuUsage > 0.8 ? Looks.colors.danger : Looks.colors.fg1
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true; height: 8; radius: 4; color: Looks.colors.bg1Base
                            Rectangle {
                                width: parent.width * Math.min(1, ResourceUsage.cpuUsage); height: parent.height; radius: 4
                                color: ResourceUsage.cpuUsage > 0.8 ? Looks.colors.danger : Looks.colors.accent
                                Behavior on width {
                                    animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                                }
                            }
                        }
                    }

                    // Memory
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            WText { text: Translation.tr("RAM"); font.pixelSize: Looks.font.pixelSize.small; font.weight: Font.Medium }
                            Item { Layout.fillWidth: true }
                            WText {
                                readonly property string used: (ResourceUsage.memoryUsed / (1024 * 1024)).toFixed(1)
                                readonly property string total: ResourceUsage.maxAvailableMemoryString
                                text: used + " / " + total
                                font.pixelSize: Looks.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: ResourceUsage.memoryUsedPercentage > 0.9 ? Looks.colors.danger : Looks.colors.fg1
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true; height: 8; radius: 4; color: Looks.colors.bg1Base
                            Rectangle {
                                width: parent.width * Math.min(1, ResourceUsage.memoryUsedPercentage); height: parent.height; radius: 4
                                color: ResourceUsage.memoryUsedPercentage > 0.9 ? Looks.colors.danger : Looks.colors.accent
                                Behavior on width {
                                    animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                                }
                            }
                        }
                    }

                    // Swap (if available)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: ResourceUsage.swapTotal > 1
                        RowLayout {
                            Layout.fillWidth: true
                            WText { text: Translation.tr("Swap"); font.pixelSize: Looks.font.pixelSize.small; font.weight: Font.Medium }
                            Item { Layout.fillWidth: true }
                            WText {
                                readonly property string used: (ResourceUsage.swapUsed / (1024 * 1024)).toFixed(1)
                                readonly property string total: ResourceUsage.maxAvailableSwapString
                                text: used + " / " + total
                                font.pixelSize: Looks.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: ResourceUsage.swapUsedPercentage > 0.8 ? Looks.colors.danger : Looks.colors.fg1
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true; height: 8; radius: 4; color: Looks.colors.bg1Base
                            Rectangle {
                                width: parent.width * Math.min(1, ResourceUsage.swapUsedPercentage); height: parent.height; radius: 4
                                color: ResourceUsage.swapUsedPercentage > 0.8 ? Looks.colors.danger : Looks.colors.accent
                                Behavior on width {
                                    animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                                }
                            }
                        }
                    }
                }
            }

            WPanelSeparator { visible: (Config.options?.waffles?.widgetsPanel?.showMedia ?? true) && MprisController.activePlayer !== null }

            // Media widget (if playing)
            BodyRectangle {
                id: mediaWidget
                Layout.fillWidth: true
                implicitHeight: mediaContent.implicitHeight
                visible: (Config.options?.waffles?.widgetsPanel?.showMedia ?? true) && MprisController.activePlayer !== null
                color: "transparent"

                // Volume feedback overlay
                Rectangle {
                    id: mediaVolumeOverlay
                    anchors.centerIn: parent
                    width: 80
                    height: 80
                    radius: Looks.radius.medium
                    color: ColorUtils.transparentize(Looks.colors.bg0, 0.15)
                    opacity: 0
                    visible: opacity > 0
                    z: 100

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        FluentIcon {
                            Layout.alignment: Qt.AlignHCenter
                            icon: MprisController.activePlayer?.volume > 0 ? "speaker" : "speaker-mute"
                            implicitSize: 24
                        }

                        WText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Math.round((MprisController.activePlayer?.volume ?? 0) * 100) + "%"
                            font.pixelSize: Looks.font.pixelSize.normal
                            font.weight: Font.DemiBold
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }

                    Timer {
                        id: mediaVolumeHideTimer
                        interval: 1000
                        onTriggered: mediaVolumeOverlay.opacity = 0
                    }
                }

                // Scroll to change player volume
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => {
                        if (!MprisController.activePlayer?.volumeSupported) return
                        const step = 0.05
                        if (wheel.angleDelta.y > 0)
                            MprisController.activePlayer.volume = Math.min(1, MprisController.activePlayer.volume + step)
                        else if (wheel.angleDelta.y < 0)
                            MprisController.activePlayer.volume = Math.max(0, MprisController.activePlayer.volume - step)

                        // Show volume feedback
                        mediaVolumeOverlay.opacity = 1
                        mediaVolumeHideTimer.restart()
                    }
                }

                Rectangle {
                    id: mediaContent
                    anchors.fill: parent
                    implicitHeight: 140
                    color: Looks.colors.bgPanelBody
                    clip: true

                    // Blurred album art background
                    Image {
                        id: bgArt
                        anchors.fill: parent
                        source: MprisController.activePlayer?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }
                    FastBlur {
                        anchors.fill: parent
                        source: bgArt
                        radius: 64
                        visible: bgArt.source != ""
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: Looks.colors.bgPanelFooterBase
                        opacity: 0.75
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16

                        // Album art
                        Rectangle {
                            Layout.preferredWidth: 108
                            Layout.preferredHeight: 108
                            radius: Looks.radius.xLarge
                            color: Looks.colors.bg1Base
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: MprisController.activePlayer?.trackArtUrl ?? ""
                                fillMode: Image.PreserveAspectCrop
                                visible: source != ""
                            }
                            FluentIcon {
                                anchors.centerIn: parent
                                icon: "music-note-2"
                                implicitSize: 40
                                visible: !MprisController.activePlayer?.trackArtUrl
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 4

                            Item { Layout.fillHeight: true }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                WText {
                                    Layout.fillWidth: true
                                    text: StringUtils.cleanMusicTitle(MprisController.activePlayer?.trackTitle) ?? Translation.tr("No media")
                                    font.pixelSize: Looks.font.pixelSize.large
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                // Player app icon
                                IconImage {
                                    id: playerAppIcon
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    source: {
                                        const de = MprisController.activePlayer?.desktopEntry ?? "";
                                        const identity = (MprisController.activePlayer?.identity ?? "").toLowerCase();

                                        // Special cases for common players
                                        if (identity.includes("spotify")) return Quickshell.iconPath("spotify", "");
                                        if (identity.includes("firefox")) return Quickshell.iconPath("firefox", "");
                                        if (identity.includes("chrome")) return Quickshell.iconPath("google-chrome", "");
                                        if (identity.includes("chromium")) return Quickshell.iconPath("chromium", "");
                                        if (identity.includes("vlc")) return Quickshell.iconPath("vlc", "");
                                        if (identity.includes("mpv")) return Quickshell.iconPath("mpv", "");
                                        if (identity.includes("youtube")) return Quickshell.iconPath("youtube", "");

                                        // Try desktop entry icon
                                        const entry = DesktopEntries.byId(de) ?? DesktopEntries.heuristicLookup(de);
                                        if (entry?.icon) return Quickshell.iconPath(entry.icon, "");

                                        // Fallback to identity as icon name
                                        if (identity) return Quickshell.iconPath(identity, "");

                                        return "";
                                    }
                                    // Only show if loaded successfully
                                    visible: status === Image.Ready
                                }
                            }

                            WText {
                                Layout.fillWidth: true
                                text: MprisController.activePlayer?.trackArtist ?? ""
                                font.pixelSize: Looks.font.pixelSize.normal
                                color: Looks.colors.fg1
                                elide: Text.ElideRight
                                visible: text !== ""
                            }

                            Item { Layout.fillHeight: true }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                WBorderlessButton {
                                    implicitWidth: 40
                                    implicitHeight: 40
                                    contentItem: FluentIcon { anchors.centerIn: parent; icon: "previous"; implicitSize: 18 }
                                    onClicked: MprisController.activePlayer?.previous()
                                }
                                WBorderlessButton {
                                    implicitWidth: 48
                                    implicitHeight: 48
                                    contentItem: FluentIcon {
                                        anchors.centerIn: parent
                                        icon: MprisController.activePlayer?.isPlaying ? "pause" : "play"
                                        implicitSize: 24
                                    }
                                    onClicked: MprisController.activePlayer?.togglePlaying()
                                }
                                WBorderlessButton {
                                    implicitWidth: 40
                                    implicitHeight: 40
                                    contentItem: FluentIcon { anchors.centerIn: parent; icon: "next"; implicitSize: 18 }
                                    onClicked: MprisController.activePlayer?.next()
                                }
                            }
                        }
                    }
                }
            }

            WPanelSeparator { visible: Config.options?.waffles?.widgetsPanel?.showQuickActions ?? true }

            // Quick actions
            BodyRectangle {
                Layout.fillWidth: true
                implicitHeight: actionsContent.implicitHeight + 36
                visible: Config.options?.waffles?.widgetsPanel?.showQuickActions ?? true

                ColumnLayout {
                    id: actionsContent
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14

                    WText {
                        text: Translation.tr("Quick Actions")
                        font.pixelSize: Looks.font.pixelSize.large
                        font.weight: Font.DemiBold
                    }

                    Grid {
                        Layout.fillWidth: true
                        columns: 3
                        spacing: 10

                        Repeater {
                            model: root.enabledQuickActions

                            delegate: QuickActionButton {
                                required property var modelData
                                width: (parent.width - 16) / 3
                                iconName: modelData.icon
                                label: modelData.label
                                onClicked: root.runQuickAction(modelData.id)
                            }
                        }
                    }
                }
            }

            // Bottom padding
            Item { Layout.fillWidth: true; implicitHeight: 8 }
        }
    }

    component QuickActionButton: Rectangle {
        id: actionBtn
        required property string iconName
        required property string label
        signal clicked()

        implicitHeight: 72
        radius: Looks.radius.large
        color: actionMa.containsMouse ? Looks.colors.bg2Hover : Looks.colors.bg1Base
        border.width: 1
        border.color: actionMa.containsMouse ? Looks.colors.bg2Border : "transparent"

        scale: actionMa.pressed ? 0.96 : 1.0
        Behavior on scale { animation: NumberAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.OutQuad } }
        Behavior on color { animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard } }

        MouseArea {
            id: actionMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionBtn.clicked()
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8

            FluentIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: actionBtn.iconName
                implicitSize: 20
                color: actionMa.containsMouse ? Looks.colors.accent : Looks.colors.fg
                Behavior on color { animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard } }
            }

            WText {
                Layout.alignment: Qt.AlignHCenter
                text: actionBtn.label
                font.pixelSize: Looks.font.pixelSize.small
                font.weight: actionMa.containsMouse ? Font.Medium : Font.Normal
                color: actionMa.containsMouse ? Looks.colors.fg : Looks.colors.fg1
            }
        }
    }
}
