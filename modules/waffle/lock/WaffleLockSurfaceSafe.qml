pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtMultimedia
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.lock
import qs.modules.waffle.looks
import qs.modules.background.widgets.clock as BackgroundClock
import Quickshell
import Quickshell.Widgets

MouseArea {
    id: root
    required property LockContext context

    // States: "lock" (clock view) or "login" (password entry)
    property string currentView: "lock"
    property bool showLoginView: currentView === "login"
    readonly property bool requirePasswordToPower: Config.options?.lock?.security?.requirePasswordToPower ?? true

    property bool hasAttemptedUnlock: false
    property bool oskVisible: false

    readonly property color textColor: Looks.colors.fg
    readonly property color textShadowColor: Looks.colors.shadow
    readonly property real clockFontSize: 96 * Looks.fontScale
    readonly property real dateFontSize: 20 * Looks.fontScale

    readonly property bool blurEnabled: Config.options?.lock?.blur?.enable ?? true
    readonly property real blurAmount: 0.8
    readonly property real blurMax: Config.options?.lock?.blur?.radius ?? 64

    function safeLockNotificationImage(source): string {
        const value = String(source ?? "")
        return value.startsWith("image://qsimage/") ? "" : value
    }

    readonly property color smokeColor: ColorUtils.transparentize(Looks.colors.bg0Opaque, 0.5)

    readonly property MprisPlayer activePlayer: MprisController.activePlayer

    readonly property string _wallpaperPath: {
        const wBg = Config.options?.waffles?.background
        if (wBg?.useMainWallpaper ?? true) return Config.options?.background?.wallpaperPath ?? ""
        return wBg?.wallpaperPath ?? Config.options?.background?.wallpaperPath ?? ""
    }
    readonly property bool enableAnimation: Config.options?.lock?.enableAnimation ?? false
    readonly property bool wallpaperIsVideo: {
        const lp = _wallpaperPath.toLowerCase();
        return lp.endsWith(".mp4") || lp.endsWith(".webm") || lp.endsWith(".mkv") || lp.endsWith(".avi") || lp.endsWith(".mov");
    }
    readonly property bool wallpaperIsGif: _wallpaperPath.toLowerCase().endsWith(".gif")

    // Safe base background
    Rectangle {
        anchors.fill: parent
        color: Looks.colors.bg0
        z: -2
    }

     // Wallpaper (piped through MultiEffect for blur)
     Image {
         id: backgroundWallpaperSource
         anchors.fill: parent
         source: (!root.wallpaperIsGif && !root.wallpaperIsVideo) ? root._wallpaperPath : ""
         fillMode: Image.PreserveAspectCrop
         asynchronous: true
         visible: false
         z: -2
     }

     // Animated GIF wallpaper — first frame when animation disabled
     AnimatedImage {
         id: gifWallpaperSource
         anchors.fill: parent
         source: root.wallpaperIsGif ? root._wallpaperPath : ""
         fillMode: Image.PreserveAspectCrop
         asynchronous: true
         cache: false
         playing: visible && root.enableAnimation
         visible: false
         z: -2
     }

     // Video wallpaper — first frame (paused) when animation disabled
     Video {
         id: videoWallpaperSource
         anchors.fill: parent
         visible: false
         z: -2
         source: {
             if (!root.wallpaperIsVideo || !root._wallpaperPath) return "";
             const path = root._wallpaperPath;
             return path.startsWith("file://") ? path : ("file://" + path);
         }
         fillMode: VideoOutput.PreserveAspectCrop
         loops: MediaPlayer.Infinite
         muted: true
         autoPlay: true

         readonly property bool shouldPlay: root.enableAnimation

         function pauseAndShowFirstFrame() {
             pause()
             seek(0)
         }

         onPlaybackStateChanged: {
             if (playbackState === MediaPlayer.PlayingState && !shouldPlay)
                 pauseAndShowFirstFrame()
             if (playbackState === MediaPlayer.StoppedState && visible && shouldPlay)
                 play()
         }

         onShouldPlayChanged: {
             if (root.wallpaperIsVideo) {
                 if (shouldPlay) play()
                 else pauseAndShowFirstFrame()
             }
         }
     }

     MultiEffect {
         id: backgroundWallpaper
         anchors.fill: parent
         source: root.wallpaperIsGif ? gifWallpaperSource
               : root.wallpaperIsVideo ? videoWallpaperSource
               : backgroundWallpaperSource
         visible: true
         z: -1

         blurEnabled: root.blurEnabled
         blur: root.blurAmount
         blurMax: root.blurMax
         saturation: 0.5
     }

    // Dim overlay to keep text readable without shadows
    Rectangle {
        anchors.fill: parent
        color: ColorUtils.transparentize(Looks.colors.bg0Opaque, 0.65)
        opacity: root.showLoginView ? 0.75 : 0.25
        Behavior on opacity {
            animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
        }
    }

    // Smoke overlay (login)
    Rectangle {
        anchors.fill: parent
        color: root.smokeColor
        opacity: root.showLoginView ? 1 : 0
        Behavior on opacity {
            animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.panel : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate }
        }
    }

    // Wallpaper dim overlay
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: (Config.options?.lock?.dim?.enable ?? false) ? (Config.options?.lock?.dim?.opacity ?? 0.3) : 0
        z: 0

        Behavior on opacity {
            NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate }
        }
    }

    // ===== LOCK VIEW =====
    Item {
        id: lockView
        anchors.fill: parent
        opacity: root.showLoginView ? 0 : 1
        visible: opacity > 0
        scale: root.showLoginView ? 0.95 : 1

        Behavior on opacity {
            animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.panel : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
            }
        }

        // Bottom left widgets row (Weather + Media)
        RowLayout {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: 48
            anchors.leftMargin: 48
            spacing: 24

            Loader {
                active: (Weather.data?.temp?.length ?? 0) > 0
                visible: active

                sourceComponent: Row {
                    spacing: 12

                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const icon = Icons.getWeatherIcon(Weather.data?.wCode ?? "113", Weather.isNightNow())
                            return icon ? icon : "cloud"
                        }
                        iconSize: 48
                        color: root.textColor
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            text: Weather.data?.temp ?? ""
                            font.pixelSize: 24 * Looks.fontScale
                            font.weight: Looks.font.weight.thin
                            font.family: Looks.font.family.ui
                            color: root.textColor
                        }

                        Text {
                            text: Weather.visibleCity
                            visible: Weather.showVisibleCity
                            font.pixelSize: Looks.font.pixelSize.small
                            font.family: Looks.font.family.ui
                            color: Looks.colors.subfg
                        }
                    }
                }
            }

            Loader {
                active: root.activePlayer !== null &&
                        root.activePlayer.playbackState !== MprisPlaybackState.Stopped &&
                        (root.activePlayer.trackTitle?.length > 0 ?? false)
                visible: active

                sourceComponent: Rectangle {
                    id: mediaWidget
                    width: Math.max(320, mediaRow.implicitWidth + 32)
                    height: 80
                    radius: Looks.radius.xLarge
                    color: ColorUtils.transparentize(Looks.colors.bg1Base, 0.15)
                    border.color: ColorUtils.transparentize(Looks.colors.bg1Border, 0.5)
                    border.width: 1

                    readonly property MprisPlayer player: root.activePlayer
                    readonly property string effectiveArtUrl: MprisController.isYtMusicActive ? YtMusic.currentThumbnail : (player?.trackArtUrl ?? "")
                    readonly property string effectiveTitle: MprisController.isYtMusicActive ? YtMusic.currentTitle : (player?.trackTitle ?? "")
                    readonly property string effectiveArtist: MprisController.isYtMusicActive ? YtMusic.currentArtist : (player?.trackArtist ?? "")

                    MediaArtworkResolver {
                        id: artworkResolver
                        sourceUrl: mediaWidget.effectiveArtUrl
                        title: mediaWidget.effectiveTitle
                        artist: mediaWidget.effectiveArtist
                        album: mediaWidget.player?.trackAlbum ?? ""
                        cacheDirectory: Directories.coverArt
                    }

                    RowLayout {
                        id: mediaRow
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16

                        Rectangle {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            Layout.alignment: Qt.AlignVCenter
                            radius: Looks.radius.medium
                            color: Looks.colors.bg2Base
                            clip: true

                            Image {
                                id: mediaArtImage
                                anchors.fill: parent
                                source: artworkResolver.displaySource
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                visible: artworkResolver.ready && status === Image.Ready
                            }

                            FluentIcon {
                                anchors.centerIn: parent
                                icon: "music-note-2"
                                implicitSize: 24
                                color: Looks.colors.subfg
                                visible: !artworkResolver.ready || mediaArtImage.status !== Image.Ready
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 4

                            Text {
                                Layout.fillWidth: true
                                text: StringUtils.cleanMusicTitle(mediaWidget.player?.trackTitle ?? "")
                                font.pixelSize: Looks.font.pixelSize.large
                                font.weight: Looks.font.weight.regular
                                font.family: Looks.font.family.ui
                                color: root.textColor
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: mediaWidget.player?.trackArtist ?? ""
                                font.pixelSize: Looks.font.pixelSize.normal
                                font.family: Looks.font.family.ui
                                color: Looks.colors.subfg
                                elide: Text.ElideRight
                                visible: text.length > 0
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 8

                            WaffleLockMediaButton {
                                icon: "previous"
                                enabled: MprisController.canGoPrevious
                                onClicked: MprisController.previous()
                            }

                            WaffleLockMediaButton {
                                icon: mediaWidget.player?.isPlaying ? "pause" : "play"
                                size: 40
                                onClicked: MprisController.togglePlaying()
                            }

                            WaffleLockMediaButton {
                                icon: "next"
                                enabled: MprisController.canGoNext
                                onClicked: MprisController.next()
                            }
                        }
                    }
                }
            }
        }

        // Config-driven clock properties
        readonly property string clockStyle: Config.options?.lock?.clock?.style ?? "default"
        readonly property string clockPosition: Config.options?.lock?.clock?.position ?? "center"
        readonly property bool statusEnabled: Config.options?.lock?.status?.enable ?? true

        // Status row
        Loader {
            active: lockView.statusEnabled
            anchors {
                top: parent.top
                topMargin: 24
                horizontalCenter: parent.horizontalCenter
            }

            sourceComponent: Row {
                spacing: 16

                Row {
                    spacing: 4
                    visible: Network.wifiEnabled

                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Network.materialSymbol ?? "signal_wifi_off"
                        iconSize: 16
                        color: root.textColor
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Network.networkName ?? ""
                        visible: text.length > 0 && text.length < 16
                        font.pixelSize: Looks.font.pixelSize.small
                        font.family: Looks.font.family.ui
                        color: root.textColor
                    }
                }

                MaterialSymbol {
                    visible: BluetoothStatus.enabled
                    anchors.verticalCenter: parent.verticalCenter
                    text: BluetoothStatus.connected ? "bluetooth_connected" : "bluetooth"
                    iconSize: 16
                    color: root.textColor
                }

                Row {
                    spacing: 4

                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Audio.value <= 0 ? "volume_off"
                            : Audio.value < 0.33 ? "volume_mute"
                            : Audio.value < 0.66 ? "volume_down"
                            : "volume_up"
                        iconSize: 16
                        color: root.textColor
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(Audio.value * 100) + "%"
                        font.pixelSize: Looks.font.pixelSize.small
                        font.family: Looks.font.family.ui
                        color: root.textColor
                    }
                }

                Row {
                    spacing: 4
                    visible: UPower.displayDevice?.isPresent ?? false

                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const pct = UPower.displayDevice?.percentage ?? 0
                            const charging = UPower.displayDevice?.state === UPowerDeviceState.Charging
                            if (charging) return "battery_charging_full"
                            if (pct <= 10) return "battery_alert"
                            if (pct <= 30) return "battery_2_bar"
                            if (pct <= 60) return "battery_4_bar"
                            if (pct <= 80) return "battery_5_bar"
                            return "battery_full"
                        }
                        iconSize: 16
                        color: {
                            const pct = UPower.displayDevice?.percentage ?? 0
                            return pct <= 15 ? Looks.colors.danger : root.textColor
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(UPower.displayDevice?.percentage ?? 0) + "%"
                        font.pixelSize: Looks.font.pixelSize.small
                        font.family: Looks.font.family.ui
                        color: root.textColor
                    }
                }
            }
        }

        // Clock container - position-aware
        Item {
            id: sClockContainer
            width: sClockContent.implicitWidth
            height: sClockContent.implicitHeight

            states: [
                State {
                    name: "center"; when: lockView.clockPosition === "center"
                    AnchorChanges {
                        target: sClockContainer
                        anchors.horizontalCenter: lockView.horizontalCenter
                        anchors.verticalCenter: lockView.verticalCenter
                    }
                    PropertyChanges { target: sClockContainer; anchors.verticalCenterOffset: -60 }
                },
                State {
                    name: "topLeft"; when: lockView.clockPosition === "topLeft"
                    AnchorChanges {
                        target: sClockContainer
                        anchors.left: lockView.left
                        anchors.top: lockView.top
                    }
                    PropertyChanges { target: sClockContainer; anchors.leftMargin: 48; anchors.topMargin: 80 }
                },
                State {
                    name: "bottomLeft"; when: lockView.clockPosition === "bottomLeft"
                    AnchorChanges {
                        target: sClockContainer
                        anchors.left: lockView.left
                        anchors.bottom: lockView.bottom
                    }
                    PropertyChanges { target: sClockContainer; anchors.leftMargin: 48; anchors.bottomMargin: 140 }
                }
            ]

            ColumnLayout {
                id: sClockContent
                visible: lockView.clockStyle !== "analog"
                spacing: 4

                Text {
                    id: clockText
                    Layout.alignment: lockView.clockPosition === "center" ? Qt.AlignHCenter : Qt.AlignLeft
                    text: DateTime.time
                    font.pixelSize: lockView.clockStyle === "minimal" ? Math.round(72 * Looks.fontScale) : root.clockFontSize
                    font.weight: Looks.font.weight.thin
                    font.family: Looks.font.family.ui
                    color: root.textColor
                }

                Text {
                    id: dateText
                    Layout.alignment: lockView.clockPosition === "center" ? Qt.AlignHCenter : Qt.AlignLeft
                    text: Qt.formatDate(new Date(), "dddd, MMMM d")
                    font.pixelSize: lockView.clockStyle === "minimal" ? Math.round(14 * Looks.fontScale) : root.dateFontSize
                    font.weight: Looks.font.weight.regular
                    font.family: Looks.font.family.ui
                    color: root.textColor

                    Timer {
                        interval: 60000; running: true; repeat: true
                        onTriggered: dateText.text = Qt.formatDate(new Date(), "dddd, MMMM d")
                    }
                }
            }

            // Analog clock - CookieClock from background widgets (no DropShadow - safe variant)
            Loader {
                active: lockView.clockStyle === "analog"
                anchors.centerIn: parent

                sourceComponent: Item {
                    id: sAnalogRoot
                    width: sCookieClock.implicitSize + sDateAnalog.implicitHeight + 20
                    height: width

                    BackgroundClock.CookieClock {
                        id: sCookieClock
                        implicitSize: Math.round(230 * Looks.fontScale)
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        id: sDateAnalog
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            top: sCookieClock.bottom
                            topMargin: 16
                        }
                        text: Qt.formatDate(new Date(), "dddd, MMMM d")
                        font.pixelSize: Math.round(14 * Looks.fontScale)
                        font.weight: Looks.font.weight.regular
                        font.family: Looks.font.family.ui
                        color: root.textColor

                        Timer {
                            interval: 60000; running: true; repeat: true
                            onTriggered: sDateAnalog.text = Qt.formatDate(new Date(), "dddd, MMMM d")
                        }
                    }
                }
            }
        }

        // Lock screen notifications - grouped by app, read-only
        Loader {
            id: safeLockNotificationsLoader
            readonly property bool lockNotifEnabled: Config.options?.lock?.notifications?.enable ?? false
            readonly property int lockNotifMaxCount: Config.options?.lock?.notifications?.maxCount ?? 3
            readonly property bool lockNotifShowBody: Config.options?.lock?.notifications?.showBody ?? true
            readonly property string lockNotifPosition: {
                const pos = Config.options?.lock?.notifications?.position ?? "auto"
                return pos === "auto" ? "right" : pos
            }
            active: lockNotifEnabled && Notifications.list.length > 0

            anchors {
                bottom: parent.bottom
                bottomMargin: 100
            }
            width: Math.min(340, parent.width * 0.3)

            states: [
                State {
                    name: "center"; when: safeLockNotificationsLoader.lockNotifPosition === "center"
                    AnchorChanges {
                        target: safeLockNotificationsLoader
                        anchors.horizontalCenter: lockView.horizontalCenter
                    }
                },
                State {
                    name: "left"; when: safeLockNotificationsLoader.lockNotifPosition === "left"
                    AnchorChanges {
                        target: safeLockNotificationsLoader
                        anchors.left: lockView.left
                    }
                    PropertyChanges { target: safeLockNotificationsLoader; anchors.leftMargin: 48 }
                },
                State {
                    name: "right"; when: safeLockNotificationsLoader.lockNotifPosition === "right"
                    AnchorChanges {
                        target: safeLockNotificationsLoader
                        anchors.right: lockView.right
                    }
                    PropertyChanges { target: safeLockNotificationsLoader; anchors.rightMargin: 48 }
                }
            ]

            sourceComponent: Column {
                spacing: 6
                clip: true

                Repeater {
                    model: {
                        const apps = Notifications.appNameList
                        const max = safeLockNotificationsLoader.lockNotifMaxCount
                        return apps.length > max ? apps.slice(0, max) : apps
                    }

                    delegate: Item {
                        id: safeGroupDelegate
                        required property var modelData
                        readonly property var group: Notifications.groupsByAppName[modelData] ?? null
                        readonly property var latestNotif: group?.notifications?.[0] ?? null
                        readonly property int groupCount: group?.notifications?.length ?? 0
                        property bool expanded: false

                        width: parent.width
                        height: safeGroupCol.implicitHeight
                        visible: latestNotif !== null

                        Column {
                            id: safeGroupCol
                            width: parent.width
                            spacing: 3

                            // Main card — clickable to expand
                            Rectangle {
                                id: safeGroupCard
                                width: parent.width
                                height: safeGroupContent.implicitHeight + 14
                                radius: Looks.radius.large
                                color: safeGroupMouse.containsMouse
                                    ? ColorUtils.transparentize(Looks.colors.bg1Hover, 0.06)
                                    : ColorUtils.transparentize(Looks.colors.bg1Base, 0.06)
                                border.color: ColorUtils.transparentize(Looks.colors.bg1Border, 0.5)
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Looks.transition.enabled ? Looks.transition.duration.chromeHover : 0
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
                                    }
                                }

                                MouseArea {
                                    id: safeGroupMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: safeGroupDelegate.groupCount > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (safeGroupDelegate.groupCount > 1) safeGroupDelegate.expanded = !safeGroupDelegate.expanded
                                    }
                                }

                                RowLayout {
                                    id: safeGroupContent
                                    anchors {
                                        left: parent.left; right: parent.right
                                        verticalCenter: parent.verticalCenter
                                        margins: 10
                                    }
                                    spacing: 10

                                    // App icon
                                    Item {
                                        Layout.alignment: Qt.AlignTop
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Looks.radius.medium
                                            color: "transparent"
                                            clip: true

                                            IconImage {
                                                id: safeGroupAppIcon
                                                anchors.fill: parent
                                                implicitSize: 28
                                                asynchronous: true
                                                source: {
                                                    const img = root.safeLockNotificationImage(safeGroupDelegate.latestNotif?.image)
                                                    const icon = safeGroupDelegate.latestNotif?.appIcon ?? ""
                                                    if (img && img !== "") return img
                                                    if (icon && icon !== "") return Quickshell.iconPath(icon, "image-missing")
                                                    return Quickshell.iconPath("preferences-desktop-notification", "image-missing")
                                                }
                                            }

                                            FluentIcon {
                                                anchors.centerIn: parent
                                                icon: "alert"
                                                implicitSize: 16
                                                color: Looks.colors.accentFg
                                                visible: safeGroupAppIcon.status === Image.Error || safeGroupAppIcon.status === Image.Null
                                            }
                                        }

                                        // Count badge
                                        Rectangle {
                                            visible: safeGroupDelegate.groupCount > 1
                                            anchors {
                                                right: parent.right
                                                top: parent.top
                                                rightMargin: -3
                                                topMargin: -3
                                            }
                                            width: Math.max(14, safeBadgeText.implicitWidth + 6)
                                            height: 14
                                            radius: 7
                                            color: Looks.colors.accent
                                            z: 1

                                            Text {
                                                id: safeBadgeText
                                                anchors.centerIn: parent
                                                text: safeGroupDelegate.groupCount
                                                font.pixelSize: 8
                                                font.weight: Font.Bold
                                                font.family: Looks.font.family.ui
                                                color: Looks.colors.accentFg
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        RowLayout {
                                            Layout.fillWidth: true

                                            Text {
                                                Layout.fillWidth: true
                                                text: safeGroupDelegate.modelData ?? ""
                                                font.pixelSize: Looks.font.pixelSize.tiny
                                                font.weight: Looks.font.weight.regular
                                                font.family: Looks.font.family.ui
                                                color: Looks.colors.subfg
                                                elide: Text.ElideRight
                                                visible: text.length > 0
                                            }

                                            FluentIcon {
                                                visible: safeGroupDelegate.groupCount > 1
                                                icon: safeGroupDelegate.expanded ? "chevron-up" : "chevron-down"
                                                implicitSize: 12
                                                color: Looks.colors.subfg
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: safeGroupDelegate.latestNotif?.summary ?? ""
                                            font.pixelSize: Looks.font.pixelSize.small
                                            font.weight: Looks.font.weight.regular
                                            font.family: Looks.font.family.ui
                                            color: root.textColor
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: safeLockNotificationsLoader.lockNotifShowBody && text.length > 0
                                            text: safeGroupDelegate.latestNotif?.body ?? ""
                                            font.pixelSize: Looks.font.pixelSize.tiny
                                            font.family: Looks.font.family.ui
                                            color: Looks.colors.subfg
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }
                            }

                            // Expanded notifications
                            Column {
                                width: parent.width - 12
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 2
                                visible: safeGroupDelegate.expanded
                                clip: true

                                Repeater {
                                    model: safeGroupDelegate.expanded ? (safeGroupDelegate.group?.notifications?.slice(1) ?? []) : []

                                    delegate: Rectangle {
                                        id: safeExpandedCard
                                        required property var modelData
                                        width: parent.width
                                        height: safeExpandedContent.implicitHeight + 10
                                        radius: Looks.radius.medium
                                        color: ColorUtils.transparentize(Looks.colors.bg1Base, 0.1)
                                        border.color: ColorUtils.transparentize(Looks.colors.bg1Border, 0.6)
                                        border.width: 1

                                        RowLayout {
                                            id: safeExpandedContent
                                            anchors {
                                                left: parent.left; right: parent.right
                                                verticalCenter: parent.verticalCenter
                                                margins: 8
                                            }
                                            spacing: 8

                                            IconImage {
                                                Layout.alignment: Qt.AlignTop
                                                Layout.preferredWidth: 20
                                                Layout.preferredHeight: 20
                                                implicitSize: 20
                                                asynchronous: true
                                                source: {
                                                    const icon = safeExpandedCard.modelData?.appIcon ?? ""
                                                    if (icon && icon !== "") return Quickshell.iconPath(icon, "image-missing")
                                                    return Quickshell.iconPath("preferences-desktop-notification", "image-missing")
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: safeExpandedCard.modelData?.summary ?? ""
                                                    font.pixelSize: Looks.font.pixelSize.tiny
                                                    font.weight: Looks.font.weight.regular
                                                    font.family: Looks.font.family.ui
                                                    color: root.textColor
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 1
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    visible: safeLockNotificationsLoader.lockNotifShowBody && text.length > 0
                                                    text: safeExpandedCard.modelData?.body ?? ""
                                                    font.pixelSize: Looks.font.pixelSize.tiny
                                                    font.family: Looks.font.family.ui
                                                    color: Looks.colors.subfg
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 2
                                                    wrapMode: Text.WordWrap
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Overflow indicator for remaining app groups
                Text {
                    visible: Notifications.appNameList.length > safeLockNotificationsLoader.lockNotifMaxCount
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "+" + (Notifications.appNameList.length - safeLockNotificationsLoader.lockNotifMaxCount) + " " + Translation.tr("more")
                    font.pixelSize: Looks.font.pixelSize.tiny
                    font.family: Looks.font.family.ui
                    color: Looks.colors.subfg
                }
            }
        }

        // Bottom hint
        Rectangle {
            id: hintContainer
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 48
            anchors.horizontalCenter: parent.horizontalCenter
            width: hintText.implicitWidth + 32
            height: 36
            radius: height / 2
            color: ColorUtils.transparentize(Looks.colors.bg1Base, 0.25)
            border.color: Looks.colors.bg1Border
            border.width: 1
            opacity: hintOpacity

            property real hintOpacity: 1

            Text {
                id: hintText
                anchors.centerIn: parent
                text: Translation.tr("Press any key or click to unlock")
                font.pixelSize: Looks.font.pixelSize.normal
                font.weight: Looks.font.weight.regular
                font.family: Looks.font.family.ui
                color: root.textColor
            }

            Timer {
                id: hintFadeTimer
                interval: 4000
                running: lockView.visible
                onTriggered: hintContainer.hintOpacity = 0
            }

            Connections {
                target: lockView
                function onVisibleChanged() {
                    if (lockView.visible) {
                        hintContainer.hintOpacity = 1
                        hintFadeTimer.restart()
                    }
                }
            }

            Behavior on hintOpacity {
                animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
            }
        }
    }

    // ===== LOGIN VIEW =====
    Item {
        id: loginView
        anchors.fill: parent
        opacity: root.showLoginView ? 1 : 0
        visible: opacity > 0
        scale: root.showLoginView ? 1 : 1.05

        Behavior on opacity {
            animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.panel : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16

            // Avatar (Material-like ring + circular clip, no OpacityMask)
            Item {
                id: avatarContainer
                Layout.alignment: Qt.AlignHCenter
                width: 120
                height: 120

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 8
                    height: parent.height + 8
                    radius: width / 2
                    color: "transparent"
                    border.color: Looks.colors.accent
                    border.width: 3
                }

                Rectangle {
                    id: avatarCircle
                    anchors.fill: parent
                    radius: width / 2
                    color: Looks.colors.accent

                    // Sources (kept invisible, rendered via masked MultiEffect below)
                    Image {
                        id: avatarImage
                        anchors.fill: parent
                        source: safeLockAvatarResolver.resolvedSource
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        smooth: true
                        mipmap: true
                        sourceSize.width: avatarCircle.width * 2
                        sourceSize.height: avatarCircle.height * 2
                        visible: false
                    }

                    QtObject {
                        id: safeLockAvatarResolver
                        property int avatarIndex: 0
                        readonly property string resolvedSource: Directories.avatarSourceAt(avatarIndex)
                        readonly property string primaryWatch: Directories.userAvatarSourcePrimary
                        onPrimaryWatchChanged: avatarIndex = 0
                        readonly property int imgStatus: avatarImage.status
                        onImgStatusChanged: {
                            if (imgStatus === Image.Error) {
                                const nextIdx = avatarIndex + 1
                                if (nextIdx < Directories.userAvatarPaths.length)
                                    avatarIndex = nextIdx
                            }
                        }
                    }

                    ShaderEffectSource {
                        id: avatarMaskSource
                        visible: false
                        sourceItem: Rectangle {
                            width: avatarCircle.width
                            height: avatarCircle.height
                            radius: width / 2
                            color: "white"
                        }
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: avatarImage
                        maskEnabled: true
                        maskSource: avatarMaskSource
                        visible: avatarImage.status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        text: (SystemInfo.displayName || SystemInfo.username || "?").charAt(0).toUpperCase()
                        font.pixelSize: 48 * Looks.fontScale
                        font.weight: Looks.font.weight.regular
                        font.family: Looks.font.family.ui
                        color: Looks.colors.accentFg
                        visible: avatarImage.status !== Image.Ready
                    }
                }
            }

            // Display name
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                text: SystemInfo.displayName || SystemInfo.username
                font.pixelSize: 24 * Looks.fontScale
                font.weight: Looks.font.weight.regular
                font.family: Looks.font.family.ui
                color: root.textColor
            }

            Rectangle {
                id: passwordContainer
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                width: 280
                height: 40
                radius: Looks.radius.medium
                color: Looks.colors.inputBg
                border.color: passwordField.activeFocus ? Looks.colors.accent : Looks.colors.accentUnfocused
                border.width: passwordField.activeFocus ? 2 : 1

                Behavior on border.color { animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard } }
                Behavior on border.width { animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.medium : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 8

                    Loader {
                        Layout.alignment: Qt.AlignVCenter
                        active: root.context.fingerprintsConfigured
                        visible: active

                        sourceComponent: FluentIcon {
                            icon: "fingerprint"
                            implicitSize: 20
                            color: Looks.colors.subfg
                        }
                    }

                    TextInput {
                        id: passwordField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalAlignment: Text.AlignVCenter
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData
                        font.pixelSize: Looks.font.pixelSize.large
                        font.family: Looks.font.family.ui
                        color: root.textColor
                        selectionColor: Looks.colors.selection
                        selectedTextColor: Looks.colors.accentFg
                        enabled: !root.context.unlockInProgress

                        property string placeholder: GlobalStates.screenUnlockFailed
                            ? Translation.tr("Incorrect password")
                            : Translation.tr("Password")

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: passwordField.placeholder
                            font: passwordField.font
                            color: GlobalStates.screenUnlockFailed ? Looks.colors.danger : Looks.colors.subfg
                            visible: passwordField.text.length === 0
                        }

                        onTextChanged: root.context.currentText = text
                        onAccepted: {
                            root.hasAttemptedUnlock = true
                            root.context.tryUnlock(root.ctrlHeld)
                        }

                        Connections {
                            target: root.context
                            function onCurrentTextChanged() {
                                passwordField.text = root.context.currentText
                            }
                        }

                        Keys.onPressed: event => {
                            root.context.resetClearTimer()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: Looks.radius.medium
                        color: submitMouseArea.pressed
                            ? Looks.colors.accentActive
                            : submitMouseArea.containsMouse
                                ? Looks.colors.accentHover
                                : Looks.colors.accent

                        Behavior on color { animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard } }

                        FluentIcon {
                            anchors.centerIn: parent
                            icon: {
                                if (root.context.targetAction === LockContext.ActionEnum.Unlock) {
                                    return root.ctrlHeld ? "drink-coffee" : "chevron-right"
                                } else if (root.context.targetAction === LockContext.ActionEnum.Poweroff) {
                                    return "power"
                                } else if (root.context.targetAction === LockContext.ActionEnum.Reboot) {
                                    return "arrow-counterclockwise"
                                }
                                return "chevron-right"
                            }
                            implicitSize: 16
                            color: Looks.colors.accentFg
                        }

                        MouseArea {
                            id: submitMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.context.unlockInProgress
                            onClicked: {
                                root.hasAttemptedUnlock = true
                                root.context.tryUnlock(root.ctrlHeld)
                            }
                        }
                    }
                }

                // Shake animation on wrong password
                property real shakeOffset: 0
                transform: Translate { x: passwordContainer.shakeOffset }

                SequentialAnimation {
                    id: wrongPasswordShakeAnim
                    NumberAnimation { target: passwordContainer; property: "shakeOffset"; to: -20; duration: 50 }
                    NumberAnimation { target: passwordContainer; property: "shakeOffset"; to: 20; duration: 50 }
                    NumberAnimation { target: passwordContainer; property: "shakeOffset"; to: -10; duration: 40 }
                    NumberAnimation { target: passwordContainer; property: "shakeOffset"; to: 10; duration: 40 }
                    NumberAnimation { target: passwordContainer; property: "shakeOffset"; to: 0; duration: 30 }
                }

                Connections {
                    target: GlobalStates
                    function onScreenUnlockFailedChanged() {
                        if (GlobalStates.screenUnlockFailed && root.hasAttemptedUnlock) {
                            wrongPasswordShakeAnim.restart()
                        }
                    }
                }
            }

            Loader {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                active: root.context.unlockInProgress
                visible: active
                sourceComponent: WIndeterminateProgressBar { width: 120 }
            }

            Loader {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                active: root.context.fingerprintsConfigured && !root.context.unlockInProgress
                visible: active
                sourceComponent: Text {
                    text: Translation.tr("Touch sensor to unlock")
                    font.pixelSize: Looks.font.pixelSize.small
                    font.family: Looks.font.family.ui
                    color: Looks.colors.subfg
                }
            }
        }

        // Bottom right: Power options
        RowLayout {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.bottomMargin: 24
            anchors.rightMargin: 24
            spacing: 8

            WaffleLockButton {
                icon: "weather-moon"
                tooltip: Translation.tr("Sleep")
                onClicked: Session.suspend()
            }

            WaffleLockButton {
                icon: "power"
                tooltip: Translation.tr("Shut down")
                toggled: root.context.targetAction === LockContext.ActionEnum.Poweroff
                onClicked: {
                    if (!root.requirePasswordToPower) {
                        root.context.unlocked(LockContext.ActionEnum.Poweroff)
                        return
                    }
                    if (root.context.targetAction === LockContext.ActionEnum.Poweroff) {
                        root.context.resetTargetAction()
                    } else {
                        root.context.targetAction = LockContext.ActionEnum.Poweroff
                        root.context.shouldReFocus()
                    }
                }
            }

            WaffleLockButton {
                icon: "arrow-counterclockwise"
                tooltip: Translation.tr("Restart")
                toggled: root.context.targetAction === LockContext.ActionEnum.Reboot
                onClicked: {
                    if (!root.requirePasswordToPower) {
                        root.context.unlocked(LockContext.ActionEnum.Reboot)
                        return
                    }
                    if (root.context.targetAction === LockContext.ActionEnum.Reboot) {
                        root.context.resetTargetAction()
                    } else {
                        root.context.targetAction = LockContext.ActionEnum.Reboot
                        root.context.shouldReFocus()
                    }
                }
            }
        }

        // Bottom left: Battery
        Row {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: 24
            anchors.leftMargin: 24
            spacing: 16

            Loader {
                active: UPower.displayDevice.isLaptopBattery
                visible: active
                anchors.verticalCenter: parent.verticalCenter
                sourceComponent: Row {
                    spacing: 6

                    FluentIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Battery.isCharging ? "battery-charging" : "battery-full"
                        implicitSize: 20
                        color: (Battery.isLow && !Battery.isCharging)
                            ? Looks.colors.danger
                            : root.textColor
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(Battery.percentage * 100) + "%"
                        font.pixelSize: Looks.font.pixelSize.normal
                        font.family: Looks.font.family.ui
                        color: (Battery.isLow && !Battery.isCharging)
                            ? Looks.colors.danger
                            : root.textColor
                    }
                }
            }
            
            // On-screen keyboard toggle
            WaffleLockButton {
                icon: "keyboard"
                tooltip: Translation.tr("Virtual keyboard")
                toggled: root.oskVisible
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.oskVisible = !root.oskVisible
            }
        }
    }

    // On-screen keyboard
    LockKeyboard {
        id: lockKeyboard
        visible: root.oskVisible
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 80
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width * 0.6, 640)

        // Waffle theme overrides
        themeBgColor: ColorUtils.transparentize(Looks.colors.bg1Base, 0.15)
        themeKeySurfaceColor: ColorUtils.transparentize(Looks.colors.bg2Base, 0.3)
        themeTextColor: root.textColor
        themeSubtextColor: ColorUtils.transparentize(root.textColor, 0.4)
        themeAccentColor: Looks.colors.accent
        themeAccentActiveColor: Qt.darker(Looks.colors.accent, 1.15)
        themeAccentTextColor: Looks.colors.accentFg
        themeRounding: Looks.radius.large
        themeKeyRounding: Looks.radius.medium
        themeAnimDuration: Looks.transition.enabled ? 70 : 0
        themeFontSize: Looks.font.pixelSize.normal
        themeFontSizeLarge: Looks.font.pixelSize.large
        themeFontSizeSmall: Looks.font.pixelSize.small
        themeFontFamily: Looks.font.family.ui

        onKeyClicked: key => {
            passwordField.text += key
            passwordField.forceActiveFocus()
        }
        onBackspaceClicked: {
            if (passwordField.text.length > 0) {
                passwordField.text = passwordField.text.slice(0, -1)
            }
            passwordField.forceActiveFocus()
        }
        onEnterClicked: {
            if (root.context.currentText.length > 0) {
                root.hasAttemptedUnlock = true
                root.context.tryUnlock(root.ctrlHeld)
            }
        }
        onCloseRequested: root.oskVisible = false
    }

    // ===== INPUT HANDLING =====

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    focus: true
    activeFocusOnTab: true

    property bool ctrlHeld: false

    function forceFieldFocus(): void {
        if (root.showLoginView && loginView.visible) {
            passwordField.forceActiveFocus()
        }
    }

    function switchToLogin(): void {
        root.currentView = "login"
        Qt.callLater(() => passwordField.forceActiveFocus())
    }

    Connections {
        target: context
        function onShouldReFocus() {
            forceFieldFocus()
        }
    }

    onClicked: mouse => {
        if (!root.showLoginView) {
            root.switchToLogin()
        } else {
            root.forceFieldFocus()
        }
    }

    onPositionChanged: mouse => {
        if (root.showLoginView) {
            root.forceFieldFocus()
        }
    }

    Keys.onPressed: event => {
        root.context.resetClearTimer()

        if (event.key === Qt.Key_Control) {
            root.ctrlHeld = true
            return
        }

        if (event.key === Qt.Key_Escape) {
            if (root.context.currentText.length > 0) {
                root.context.currentText = ""
            } else if (root.showLoginView && root.currentView === "login") {
                root.currentView = "lock"
            }
            return
        }

        const isPrintable = event.text.length > 0 && !event.modifiers && event.text.charCodeAt(0) >= 32
        const capturedChar = isPrintable ? event.text : ""

        if (!root.showLoginView) {
            root.currentView = "login"
            if (capturedChar.length > 0) {
                Qt.callLater(() => {
                    root.context.currentText += capturedChar
                    passwordField.forceActiveFocus()
                })
                event.accepted = true
            } else {
                Qt.callLater(() => passwordField.forceActiveFocus())
            }
            return
        }

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.hasAttemptedUnlock = true
            root.context.tryUnlock(root.ctrlHeld)
            event.accepted = true
            return
        }

        if (!passwordField.activeFocus) {
            passwordField.forceActiveFocus()
        }

        if (isPrintable && passwordField.activeFocus) {
            event.accepted = false
        }
    }

    Keys.onReleased: event => {
        if (event.key === Qt.Key_Control) {
            root.ctrlHeld = false
        }
        forceFieldFocus()
    }

    Component.onCompleted: {
        root.currentView = "lock"
        GlobalStates.screenUnlockFailed = false
        root.hasAttemptedUnlock = false
        Qt.callLater(() => root.forceActiveFocus())
    }

    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked) {
                root.currentView = "lock"
                root.hasAttemptedUnlock = false
                GlobalStates.screenUnlockFailed = false
                Qt.callLater(() => root.forceActiveFocus())
            }
        }
    }

    Timer {
        id: focusEnsureTimer
        interval: 100
        running: GlobalStates.screenLocked && root.visible
        repeat: false
        onTriggered: {
            if (!root.activeFocus && !passwordField.activeFocus) {
                root.forceActiveFocus()
            }
        }
    }

    component WaffleLockButton: Rectangle {
        id: lockBtn
        required property string icon
        property string tooltip: ""
        property bool toggled: false

        signal clicked()

        width: 44
        height: 44
        radius: Looks.radius.medium

        color: {
            if (lockBtn.toggled) return Looks.colors.accent
            if (btnMouseArea.pressed) return Looks.colors.bg1Active
            if (btnMouseArea.containsMouse) return Looks.colors.bg1Hover
            return Looks.colors.bg1Base
        }

        border.color: Looks.colors.bg1Border
        border.width: 1

        Behavior on color { animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard } }
        Behavior on border.color { animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard } }

        FluentIcon {
            anchors.centerIn: parent
            icon: lockBtn.icon
            implicitSize: 20
            color: lockBtn.toggled ? Looks.colors.accentFg : root.textColor
        }

        MouseArea {
            id: btnMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: lockBtn.clicked()
        }
    }

    component WaffleLockMediaButton: Rectangle {
        id: mediaBtn
        required property string icon
        property bool filled: false
        property int size: 32

        signal clicked()

        width: size
        height: size
        radius: filled ? Looks.radius.medium : width / 2

        color: {
            if (filled) {
                if (mediaMouseArea.pressed) return Looks.colors.accentActive
                if (mediaMouseArea.containsMouse) return Looks.colors.accentHover
                return Looks.colors.accent
            }
            if (mediaMouseArea.pressed) return Looks.colors.bg2Active
            if (mediaMouseArea.containsMouse) return Looks.colors.bg2Hover
            return Looks.colors.bg2Base
        }

        Behavior on color { animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard } }

        FluentIcon {
            anchors.centerIn: parent
            icon: mediaBtn.icon
            implicitSize: mediaBtn.filled ? 20 : 16
            color: filled ? Looks.colors.accentFg : root.textColor
        }

        MouseArea {
            id: mediaMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mediaBtn.clicked()
        }
    }
}
