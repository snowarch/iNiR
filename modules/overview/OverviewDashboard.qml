pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import Qt5Compat.GraphicalEffects as GE
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "root:"

Item {
    id: root

    readonly property bool angelStyle: Appearance.angelEverywhere
    readonly property bool inirStyle: Appearance.inirEverywhere
    readonly property bool auroraStyle: Appearance.auroraEverywhere
    
    // ── Screen & wallpaper for blur (angel/aurora) ──
    property int screenWidth: root.QsWindow?.window?.screen?.width ?? 1920
    property int screenHeight: root.QsWindow?.window?.screen?.height ?? 1080
    readonly property string wallpaperUrl: Wallpapers.effectiveWallpaperUrl

    // ── Config shortcuts ──
    readonly property var dashCfg: Config.options?.overview?.dashboard
    readonly property bool cfgToggles: dashCfg?.showToggles ?? true
    readonly property bool cfgMedia: dashCfg?.showMedia ?? true
    readonly property bool cfgVolume: dashCfg?.showVolume ?? true
    readonly property bool cfgWeather: dashCfg?.showWeather ?? true
    readonly property bool cfgSystem: dashCfg?.showSystem ?? true

    // ── Brightness ──
    property var screen: root.QsWindow?.window?.screen ?? null
    property var brightnessMonitor: screen ? Brightness.getMonitorForScreen(screen) : null
    property bool hasBrightness: brightnessMonitor !== null

    // ── Greeting based on time ──
    readonly property string greeting: {
        const hour = new Date().getHours()
        if (hour < 6) return Translation.tr("Good night")
        if (hour < 12) return Translation.tr("Good morning")
        if (hour < 18) return Translation.tr("Good afternoon")
        return Translation.tr("Good evening")
    }

    // ── Media player state (MediaSection pattern) ──
    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool isYtMusic: MprisController.isYtMusicActive
    readonly property bool hasPlayer: (player && player.trackTitle) || (isYtMusic && YtMusic.currentVideoId)
    readonly property string effectiveTitle: isYtMusic ? YtMusic.currentTitle : (player?.trackTitle ?? "")
    readonly property string effectiveArtist: isYtMusic ? YtMusic.currentArtist : (player?.trackArtist ?? "")
    readonly property string effectiveArtUrl: isYtMusic && YtMusic.currentThumbnail ? YtMusic.currentThumbnail : (player?.trackArtUrl ?? "")
    readonly property bool effectiveIsPlaying: isYtMusic ? YtMusic.isPlaying : (player?.isPlaying ?? false)
    readonly property real effectivePosition: isYtMusic ? YtMusic.currentPosition : (player?.position ?? 0)
    readonly property real effectiveLength: isYtMusic ? YtMusic.currentDuration : (player?.length ?? 0)
    readonly property bool effectiveCanSeek: isYtMusic ? YtMusic.canSeek : (player?.canSeek ?? false)

    // ── Cover art download ──
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: effectiveArtUrl ? Qt.md5(effectiveArtUrl) : ""
    property string artFilePath: artFileName ? `${artDownloadLocation}/${artFileName}` : ""
    property bool downloaded: false
    property string displayedArtFilePath: downloaded ? Qt.resolvedUrl(artFilePath) : ""
    property int _downloadRetryCount: 0

    function checkAndDownloadArt(): void {
        if (!effectiveArtUrl) { downloaded = false; _downloadRetryCount = 0; return }
        artExistsChecker.running = true
    }
    onArtFilePathChanged: { _downloadRetryCount = 0; checkAndDownloadArt() }
    onEffectiveArtUrlChanged: { _downloadRetryCount = 0; checkAndDownloadArt() }

    Process {
        id: artExistsChecker
        command: ["/usr/bin/test", "-f", root.artFilePath]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) { root.downloaded = true }
            else {
                root.downloaded = false
                artDownloader.targetFile = root.effectiveArtUrl ?? ""
                artDownloader.artPath = root.artFilePath
                artDownloader.running = true
            }
        }
    }
    Process {
        id: artDownloader
        property string targetFile
        property string artPath
        command: ["/usr/bin/bash", "-c", `
            if [ -f '${artPath}' ]; then exit 0; fi
            mkdir -p '${root.artDownloadLocation}'
            tmp='${artPath}.tmp'
            /usr/bin/curl -sSL --connect-timeout 8 --max-time 20 '${targetFile}' -o "$tmp" && \
            [ -s "$tmp" ] && /usr/bin/mv -f "$tmp" '${artPath}' || { rm -f "$tmp"; exit 1; }
        `]
        onExited: (exitCode) => {
            if (exitCode === 0) root.downloaded = true
            else if (root._downloadRetryCount < 2) { root._downloadRetryCount++; retryTimer.start() }
        }
    }
    Timer { id: retryTimer; interval: 1500; onTriggered: root.checkAndDownloadArt() }

    // ── Adaptive colors from album art ──
    ColorQuantizer {
        id: colorQuantizer
        source: root.displayedArtFilePath
        depth: 0; rescaleSize: 1
    }
    property color artDominantColor: ColorUtils.mix(
        colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary,
        Appearance.colors.colPrimaryContainer, 0.7
    )
    property QtObject blendedColors: AdaptedMaterialScheme { color: root.artDominantColor }

    // ── Style tokens ──
    readonly property color colText: angelStyle ? Appearance.angel.colText : inirStyle ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colSubtext: angelStyle ? Appearance.angel.colTextSecondary : inirStyle ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colCardBg: angelStyle 
        ? ColorUtils.transparentize(blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base, Appearance.angel.overlayOpacity)
        : inirStyle ? Appearance.inir.colLayer0
        : auroraStyle ? ColorUtils.applyAlpha(blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 1)
        : Appearance.colors.colLayer0
    readonly property color colCard: angelStyle 
        ? ColorUtils.transparentize(blendedColors?.colLayer1 ?? Appearance.colors.colLayer1Base, Appearance.angel.overlayOpacity)
        : inirStyle ? Appearance.inir.colLayer1
        : auroraStyle ? ColorUtils.applyAlpha(blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 1)
        : Appearance.colors.colLayer1
    readonly property color colBorder: angelStyle ? Appearance.angel.colBorder : inirStyle ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border
    readonly property color colPrimary: angelStyle ? Appearance.angel.colPrimary : inirStyle ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
    readonly property color colOnPrimary: angelStyle ? Appearance.angel.colOnPrimary : inirStyle ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary
    readonly property color colCardHover: angelStyle ? Appearance.angel.colGlassCardHover : inirStyle ? Appearance.inir.colLayer2Hover
        : auroraStyle ? (Appearance.aurora?.colSubSurfaceHover ?? Appearance.colors.colLayer2Hover) : Appearance.colors.colLayer2Hover
    readonly property color colLayer2: angelStyle ? Appearance.angel.colGlassCard : inirStyle ? Appearance.inir.colLayer2
        : auroraStyle ? (Appearance.aurora?.colSubSurface ?? Appearance.colors.colLayer2) : Appearance.colors.colLayer2
    readonly property real cardRadius: angelStyle ? Appearance.angel.roundingSmall : inirStyle ? Appearance.inir.roundingSmall : Appearance.rounding.small
    readonly property real containerRadius: angelStyle ? Appearance.angel.roundingNormal : inirStyle ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    readonly property int bw: (angelStyle || inirStyle) ? 1 : (auroraStyle ? 0 : 1)

    // ── Media-adaptive colors ──
    readonly property color mediaBg: {
        if (!hasPlayer) return colCard
        if (angelStyle) return Appearance.angel.colGlassCard
        if (inirStyle) return Appearance.inir.colLayer1
        if (auroraStyle) return ColorUtils.transparentize(blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.7)
        return blendedColors?.colLayer0 ?? Appearance.colors.colLayer0
    }
    readonly property color mediaText: hasPlayer ? (angelStyle ? Appearance.angel.colText : inirStyle ? Appearance.inir.colText
        : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)) : colText
    readonly property color mediaSub: hasPlayer ? (angelStyle ? Appearance.angel.colTextSecondary : inirStyle ? Appearance.inir.colTextSecondary
        : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)) : colSubtext
    readonly property color mediaAccent: hasPlayer ? (angelStyle ? Appearance.angel.colPrimary : inirStyle ? Appearance.inir.colPrimary
        : (blendedColors?.colPrimary ?? Appearance.colors.colPrimary)) : colPrimary
    readonly property color mediaTrack: angelStyle ? Appearance.angel.colGlassCard : inirStyle ? Appearance.inir.colLayer2
        : (blendedColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer)
    readonly property color mediaHover: angelStyle ? Appearance.angel.colGlassCardHover : inirStyle ? Appearance.inir.colLayer2Hover
        : ColorUtils.transparentize(blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5)

    implicitWidth: dashContainer.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: dashContainer.implicitHeight + Appearance.sizes.elevationMargin * 2

    Component.onCompleted: ResourceUsage.ensureRunning()
    Component.onDestruction: ResourceUsage.stop()

    Timer {
        running: root.effectiveIsPlaying
        interval: 1000; repeat: true
        onTriggered: { if (!root.isYtMusic && root.player) root.player.positionChanged() }
    }

    StyledRectangularShadow { visible: false; target: dashContainer }

    // ── Inline component: Blurred wallpaper card background (angel/aurora) ──
    // Matches ControlPanelContent pattern exactly
    component BlurredCardBg: Item {
        id: blurBg
        required property Item targetCard
        anchors.fill: parent
        visible: (root.angelStyle || root.auroraStyle) && !root.inirStyle

        Image {
            id: blurBgImage
            anchors.centerIn: parent
            width: root.screenWidth
            height: root.screenHeight
            source: root.wallpaperUrl
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: true

            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect {
                source: blurBgImage
                anchors.fill: source
                saturation: root.angelStyle ? Appearance.angel.blurSaturation : 0.2
                blurEnabled: Appearance.effectsEnabled
                blurMax: 100
                blur: Appearance.effectsEnabled ? 1 : 0
            }

            // Dark overlay (same as ControlPanelContent)
            Rectangle {
                anchors.fill: parent
                color: root.angelStyle
                    ? ColorUtils.transparentize(root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base, Appearance.angel.overlayOpacity)
                    : ColorUtils.transparentize(root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base, Appearance.aurora.overlayTransparentize)
            }
        }
    }

    // ═══════════════════════════════════════════════════
    // MAIN CONTAINER — transparent, no floating panel
    // ═══════════════════════════════════════════════════
    Rectangle {
        id: dashContainer
        anchors.centerIn: parent
        implicitWidth: mainCol.implicitWidth + 28
        implicitHeight: mainCol.implicitHeight + 24
        radius: root.containerRadius
        color: "transparent"
        border.width: 0
        border.color: "transparent"

        AngelPartialBorder { visible: false; targetRadius: dashContainer.radius; coverage: 0.4 }

        ColumnLayout {
            id: mainCol
            anchors.centerIn: parent
            spacing: 10
            width: 480

            // ═══════════════════════════════════════
            // 0. HEADER: Time + Greeting + Actions
            // ═══════════════════════════════════════
            Rectangle {
                id: headerCard
                Layout.fillWidth: true
                implicitHeight: headerRow.implicitHeight + 16
                radius: root.cardRadius
                color: root.inirStyle ? root.colCard : "transparent"
                border.width: root.bw
                border.color: root.colBorder
                clip: true

                layer.enabled: (root.angelStyle || root.auroraStyle) && !root.inirStyle
                layer.effect: GE.OpacityMask {
                    maskSource: Rectangle { width: headerCard.width; height: headerCard.height; radius: headerCard.radius }
                }

                // Blurred wallpaper background (angel/aurora)
                Image {
                    anchors.centerIn: parent
                    width: root.screenWidth
                    height: root.screenHeight
                    visible: (root.angelStyle || root.auroraStyle) && !root.inirStyle
                    source: root.wallpaperUrl
                    fillMode: Image.PreserveAspectCrop
                    cache: true
                    asynchronous: true

                    layer.enabled: Appearance.effectsEnabled
                    layer.effect: MultiEffect {
                        saturation: root.angelStyle ? Appearance.angel.blurSaturation : 0.2
                        blurEnabled: Appearance.effectsEnabled
                        blurMax: 100
                        blur: 1
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: root.angelStyle
                            ? ColorUtils.transparentize(root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base, Appearance.angel.overlayOpacity)
                            : ColorUtils.transparentize(root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base, Appearance.aurora.overlayTransparentize)
                    }
                }

                // Solid background for material/inir
                Rectangle {
                    anchors.fill: parent
                    radius: headerCard.radius
                    visible: !root.angelStyle && !root.auroraStyle
                    color: root.colCard
                }

                AngelPartialBorder { targetRadius: parent.radius; coverage: 0.45 }

                RowLayout {
                    id: headerRow
                    anchors { fill: parent; margins: 10 }
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: DateTime.time
                            font {
                                pixelSize: Appearance.font.pixelSize.huge * 1.8
                                weight: Font.Light
                                family: Appearance.font.family.numbers
                            }
                            color: root.colText
                        }
                        StyledText {
                            text: root.greeting
                            font { pixelSize: Appearance.font.pixelSize.normal; weight: Font.Medium }
                            color: root.colPrimary
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        spacing: 2

                        StyledText {
                            Layout.alignment: Qt.AlignRight
                            text: Qt.formatDate(new Date(), "dddd, MMMM d")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: root.colSubtext
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            spacing: 8
                            visible: Notifications.list.length > 0 || Notifications.silent

                            Row {
                                spacing: 4
                                visible: Notifications.list.length > 0
                                MaterialSymbol {
                                    text: "notifications"
                                    iconSize: 14
                                    color: root.colSubtext
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: Notifications.list.length.toString()
                                    font { pixelSize: Appearance.font.pixelSize.smallest; family: Appearance.font.family.numbers }
                                    color: root.colSubtext
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Row {
                                spacing: 4
                                visible: Notifications.silent
                                MaterialSymbol {
                                    text: "do_not_disturb_on"
                                    iconSize: 14
                                    fill: 1
                                    color: root.colPrimary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: Translation.tr("DND")
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: root.colPrimary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: root.angelStyle ? Appearance.angel.roundingSmall : 16
                        colBackground: "transparent"
                        colBackgroundHover: root.colCardHover
                        onClicked: Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "settings", "open"])
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "settings"
                            iconSize: 18
                            color: root.colSubtext
                        }
                        StyledToolTip { text: Translation.tr("Settings") }
                    }
                }
            }

              // ═══════════════════════════════════════
              // 1. QUICK TOGGLES (with labels)
              // ═══════════════════════════════════════
              Rectangle {
                  id: togglesCard
                  Layout.fillWidth: true
                  visible: root.cfgToggles
                  implicitHeight: togglesGrid.implicitHeight + 20
                  radius: root.cardRadius
                  color: root.inirStyle ? root.colCard : "transparent"
                  border.width: root.bw
                  border.color: root.colBorder
                  clip: true

                  layer.enabled: (root.angelStyle || root.auroraStyle) && !root.inirStyle
                  layer.effect: GE.OpacityMask {
                      maskSource: Rectangle { width: togglesCard.width; height: togglesCard.height; radius: togglesCard.radius }
                  }

                  BlurredCardBg { targetCard: togglesCard }
                  Rectangle { anchors.fill: parent; radius: togglesCard.radius; visible: !root.angelStyle && !root.auroraStyle; color: root.colCard }

                  GridLayout {
                      id: togglesGrid
                      anchors { fill: parent; margins: 10 }
                      columns: 4
                      rowSpacing: 10
                      columnSpacing: 10

                      QuickToggle {
                          icon: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                          label: Translation.tr("Sound")
                          active: !(Audio.sink?.audio?.muted ?? true)
                          onClicked: { if (Audio.sink?.audio) Audio.sink.audio.toggleMute() }
                      }
                      QuickToggle {
                          icon: Network.wifiEnabled ? "wifi" : "wifi_off"
                          label: Translation.tr("Wi-Fi")
                          active: Network.wifiEnabled
                          onClicked: Network.toggleWifi()
                      }
                      QuickToggle {
                          icon: BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                          label: Translation.tr("Bluetooth")
                          active: BluetoothStatus.enabled
                          visible: BluetoothStatus.available
                          onClicked: BluetoothStatus.toggle()
                      }
                      QuickToggle {
                          icon: Notifications.silent ? "notifications_off" : "notifications"
                          label: Translation.tr("DND")
                          active: Notifications.silent
                          onClicked: Notifications.toggleSilent()
                      }
                      QuickToggle {
                          icon: "dark_mode"
                          label: Appearance.m3colors.darkmode ? Translation.tr("Dark") : Translation.tr("Light")
                          active: Appearance.m3colors.darkmode
                          onClicked: Appearance.toggleDarkMode()
                      }
                      QuickToggle {
                          icon: "coffee"
                          label: Translation.tr("Caffeine")
                          active: Idle.inhibit
                          onClicked: Idle.toggleInhibit()
                      }
                      QuickToggle {
                          icon: "sports_esports"
                          label: Translation.tr("Gaming")
                          active: GameMode.active
                          onClicked: GameMode.toggle()
                      }
                      QuickToggle {
                          icon: "nightlight"
                          label: Translation.tr("Night")
                          active: Hyprsunset.active
                          onClicked: Hyprsunset.toggle()
                      }
                  }
              }

            // ═══════════════════════════════════════
            // 2. SLIDERS: Volume + Brightness (MiniSlider pattern)
            // ═══════════════════════════════════════
            Rectangle {
                id: slidersCard
                Layout.fillWidth: true
                visible: root.cfgVolume
                implicitHeight: slidersRow.implicitHeight + 12
                radius: root.cardRadius
                color: root.inirStyle ? root.colCard : "transparent"
                border.width: root.bw
                border.color: root.colBorder
                clip: true

                layer.enabled: (root.angelStyle || root.auroraStyle) && !root.inirStyle
                layer.effect: GE.OpacityMask {
                    maskSource: Rectangle { width: slidersCard.width; height: slidersCard.height; radius: slidersCard.radius }
                }

                BlurredCardBg { targetCard: slidersCard }
                Rectangle { anchors.fill: parent; radius: slidersCard.radius; visible: !root.angelStyle && !root.auroraStyle; color: root.colCard }
                AngelPartialBorder { targetRadius: parent.radius; coverage: 0.45 }

                RowLayout {
                    id: slidersRow
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 4

                    // Brightness
                    Loader {
                        Layout.fillWidth: true
                        visible: active
                        active: root.hasBrightness
                        sourceComponent: DashMiniSlider {
                            icon: {
                                const b = root.brightnessMonitor?.brightness ?? 0
                                return b < 0.33 ? "brightness_4" : b < 0.66 ? "brightness_5" : "brightness_7"
                            }
                            value: root.brightnessMonitor?.brightness ?? 0
                            onMoved: (val) => { if (root.brightnessMonitor) root.brightnessMonitor.setBrightness(val) }
                        }
                    }

                    // Volume
                    Loader {
                        Layout.fillWidth: true
                        visible: active
                        active: true
                        sourceComponent: DashMiniSlider {
                            icon: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                            value: Audio.sink?.audio?.volume ?? 0
                            onMoved: (val) => { if (Audio.sink?.audio) Audio.sink.audio.volume = val }
                            onIconClicked: { if (Audio.sink?.audio) Audio.sink.audio.toggleMute() }
                        }
                    }
                }
            }

            // ═══════════════════════════════════════
            // 3. MEDIA PLAYER
            // ═══════════════════════════════════════
            Rectangle {
                id: mediaCard
                Layout.fillWidth: true
                visible: root.cfgMedia && root.hasPlayer
                implicitHeight: mediaContent.implicitHeight + 24
                radius: root.cardRadius
                color: root.inirStyle ? root.colCard : "transparent"
                border.width: root.bw
                border.color: root.colBorder
                clip: true

                layer.enabled: true
                layer.effect: GE.OpacityMask {
                    maskSource: Rectangle { width: mediaCard.width; height: mediaCard.height; radius: mediaCard.radius }
                }

                // Blurred wallpaper background (angel/aurora)
                BlurredCardBg { targetCard: mediaCard }
                
                // Solid background for material/inir
                Rectangle { anchors.fill: parent; radius: mediaCard.radius; visible: !root.angelStyle && !root.auroraStyle; color: root.colCard }

                // Blurred album art overlay
                Image {
                    anchors.fill: parent
                    source: root.displayedArtFilePath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: root.displayedArtFilePath !== ""
                    opacity: root.inirStyle ? 0.15 : (root.auroraStyle ? 0.25 : 0.4)
                    layer.enabled: Appearance.effectsEnabled
                    layer.effect: MultiEffect { blurEnabled: true; blur: 0.4; blurMax: 40; saturation: 0.3 }
                }

                RowLayout {
                    id: mediaContent
                    anchors { fill: parent; margins: 12 }
                    spacing: 14

                    // Cover art — larger (96px) with subtle shadow
                    Item {
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: 96
                        Layout.alignment: Qt.AlignVCenter

                        // Shadow under art
                        Rectangle {
                            anchors { fill: artImage; margins: -2 }
                            radius: artImage.radius + 2
                            color: "transparent"
                            visible: root.downloaded
                            layer.enabled: true
                            layer.effect: GE.DropShadow {
                                horizontalOffset: 0; verticalOffset: 2
                                radius: 8; samples: 17
                                color: Qt.rgba(0, 0, 0, 0.35)
                                spread: 0
                            }
                        }

                        Rectangle {
                            id: artImage
                            width: 96; height: 96
                            radius: root.cardRadius
                            color: "transparent"
                            clip: true

                            layer.enabled: true
                            layer.effect: GE.OpacityMask {
                                maskSource: Rectangle { width: 96; height: 96; radius: artImage.radius }
                            }

                            Image {
                                anchors.fill: parent
                                source: root.displayedArtFilePath
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize { width: 192; height: 192 }
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: !root.downloaded
                                color: root.angelStyle ? Appearance.angel.colGlassCard
                                    : root.inirStyle ? Appearance.inir.colLayer2
                                    : (root.blendedColors?.colLayer1 ?? Appearance.colors.colLayer1)
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "music_note"
                                    iconSize: 36
                                    color: root.mediaSub
                                }
                            }
                        }
                    }

                    // Track info + controls
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        // Title
                        StyledText {
                            Layout.fillWidth: true
                            text: StringUtils.cleanMusicTitle(root.effectiveTitle) || Translation.tr("No media")
                            font { pixelSize: Appearance.font.pixelSize.normal; weight: Font.SemiBold }
                            color: root.mediaText
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        // Artist
                        StyledText {
                            Layout.fillWidth: true
                            visible: root.effectiveArtist.length > 0
                            text: root.effectiveArtist
                            font { pixelSize: Appearance.font.pixelSize.smaller; weight: Font.Normal }
                            color: root.mediaSub
                            elide: Text.ElideRight
                        }

                        Item { Layout.preferredHeight: 6 }

                        // Seekable slider
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            StyledSlider {
                                id: mediaSeekSlider
                                Layout.fillWidth: true
                                Layout.preferredHeight: 16
                                configuration: StyledSlider.Configuration.Wavy
                                wavy: root.effectiveIsPlaying
                                animateWave: root.effectiveIsPlaying
                                highlightColor: root.mediaAccent
                                trackColor: root.mediaTrack
                                handleColor: root.mediaAccent
                                scrollable: true
                                enabled: root.effectiveCanSeek
                                value: root.effectiveLength > 0 ? root.effectivePosition / root.effectiveLength : 0
                                onMoved: {
                                    if (root.isYtMusic) YtMusic.seek(value * root.effectiveLength)
                                    else if (root.player) root.player.position = value * root.player.length
                                }

                                Binding {
                                    target: mediaSeekSlider
                                    property: "value"
                                    value: root.effectiveLength > 0 ? root.effectivePosition / root.effectiveLength : 0
                                    when: !mediaSeekSlider.pressed && !mediaSeekSlider._userInteracting
                                    restoreMode: Binding.RestoreNone
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                StyledText {
                                    text: StringUtils.friendlyTimeForSeconds(root.effectivePosition)
                                    font { pixelSize: Appearance.font.pixelSize.smallest; family: Appearance.font.family.numbers }
                                    color: root.mediaSub
                                }
                                Item { Layout.fillWidth: true }
                                StyledText {
                                    text: StringUtils.friendlyTimeForSeconds(root.effectiveLength)
                                    font { pixelSize: Appearance.font.pixelSize.smallest; family: Appearance.font.family.numbers }
                                    color: root.mediaSub
                                }
                            }
                        }

                        // Controls
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            spacing: 4

                            Item { Layout.fillWidth: true }

                            RippleButton {
                                implicitWidth: 36
                                implicitHeight: 36
                                buttonRadius: 18
                                colBackground: "transparent"
                                colBackgroundHover: root.mediaHover
                                onClicked: MprisController.previous()
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "skip_previous"
                                    iconSize: 22
                                    fill: 1
                                    color: root.mediaText
                                }
                            }

                            RippleButton {
                                implicitWidth: 48
                                implicitHeight: 48
                                buttonRadius: 24
                                colBackground: ColorUtils.transparentize(root.mediaAccent, 0.82)
                                colBackgroundHover: ColorUtils.transparentize(root.mediaAccent, 0.7)
                                onClicked: MprisController.togglePlaying()
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: root.effectiveIsPlaying ? "pause" : "play_arrow"
                                    iconSize: 26
                                    fill: 1
                                    color: root.mediaAccent
                                    Behavior on color {
                                        enabled: Appearance.animationsEnabled
                                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                    }
                                }
                            }

                            RippleButton {
                                implicitWidth: 36
                                implicitHeight: 36
                                buttonRadius: 18
                                colBackground: "transparent"
                                colBackgroundHover: root.mediaHover
                                onClicked: MprisController.next()
                                contentItem: MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "skip_next"
                                    iconSize: 22
                                    fill: 1
                                    color: root.mediaText
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }

            // ═══════════════════════════════════════
            // 4. WEATHER — full-width rich card
            // ═══════════════════════════════════════
            Rectangle {
                id: weatherCard
                Layout.fillWidth: true
                visible: root.cfgWeather && Weather.enabled && (Weather.data?.temp ?? "") !== "" && !(Weather.data?.temp ?? "").startsWith("--")
                implicitHeight: weatherContent.implicitHeight + 20
                radius: root.cardRadius
                color: root.inirStyle ? root.colCard : "transparent"
                border.width: root.bw
                border.color: root.colBorder
                clip: true

                layer.enabled: (root.angelStyle || root.auroraStyle) && !root.inirStyle
                layer.effect: GE.OpacityMask {
                    maskSource: Rectangle { width: weatherCard.width; height: weatherCard.height; radius: weatherCard.radius }
                }

                BlurredCardBg { targetCard: weatherCard }
                Rectangle { anchors.fill: parent; radius: weatherCard.radius; visible: !root.angelStyle && !root.auroraStyle; color: root.colCard }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: Weather.getData()
                }

                ColumnLayout {
                    id: weatherContent
                    anchors { fill: parent; margins: 12 }
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        MaterialSymbol {
                            text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                            iconSize: 32
                            color: root.colPrimary
                        }

                        StyledText {
                            text: Weather.data?.temp ?? "--°"
                            font {
                                pixelSize: Appearance.font.pixelSize.huge * 1.2
                                weight: Font.Medium
                                family: Appearance.font.family.numbers
                            }
                            color: root.colText
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: Weather.data?.description ?? Translation.tr("Weather")
                                font { pixelSize: Appearance.font.pixelSize.small; weight: Font.Medium }
                                color: root.colText
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: Weather.data?.city ?? ""
                                visible: (Weather.data?.city ?? "").length > 0
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: root.colSubtext
                                elide: Text.ElideRight
                            }
                        }

                        RippleButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            buttonRadius: root.angelStyle ? Appearance.angel.roundingSmall
                                : root.inirStyle ? Appearance.inir.roundingSmall : Appearance.rounding.full
                            colBackground: "transparent"
                            colBackgroundHover: root.colCardHover
                            onClicked: Weather.fetchWeather()
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "refresh"
                                iconSize: 16
                                color: root.colSubtext
                            }
                            StyledToolTip { text: Translation.tr("Refresh") }
                        }
                    }

                    // Weather details row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        WeatherChip { icon: "thermostat"; value: Translation.tr("Feels %1").arg(Weather.data?.tempFeelsLike ?? "--"); visible: (Weather.data?.tempFeelsLike ?? "").length > 0 && !(Weather.data?.tempFeelsLike ?? "").startsWith("--") }
                        WeatherChip { icon: "humidity_percentage"; value: Weather.data?.humidity ?? "" }
                        WeatherChip { icon: "air"; value: Weather.data?.wind ?? "" }
                        WeatherChip { icon: "wb_twilight"; value: Weather.data?.sunset ?? ""; visible: (Weather.data?.sunset ?? "") !== "--:--" }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ═══════════════════════════════════════
            // 5. SYSTEM STATS — compact progress bars
            // ═══════════════════════════════════════
            Rectangle {
                id: sysCard
                Layout.fillWidth: true
                visible: root.cfgSystem
                implicitHeight: sysContent.implicitHeight + 16
                radius: root.cardRadius
                color: root.inirStyle ? root.colCard : "transparent"
                border.width: root.bw
                border.color: root.colBorder
                clip: true

                layer.enabled: (root.angelStyle || root.auroraStyle) && !root.inirStyle
                layer.effect: GE.OpacityMask {
                    maskSource: Rectangle { width: sysCard.width; height: sysCard.height; radius: sysCard.radius }
                }

                BlurredCardBg { targetCard: sysCard }
                Rectangle { anchors.fill: parent; radius: sysCard.radius; visible: !root.angelStyle && !root.auroraStyle; color: root.colCard }

                ColumnLayout {
                    id: sysContent
                    anchors { fill: parent; margins: 12 }
                    spacing: 8

                    // CPU + RAM side by side
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        // CPU
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                CircularProgress {
                                    implicitSize: 32
                                    lineWidth: 3
                                    value: ResourceUsage.cpuUsage
                                    colPrimary: ResourceUsage.cpuUsage > 0.8 ? Appearance.m3colors.m3error : root.colPrimary
                                    colSecondary: root.angelStyle ? Appearance.angel.colGlassCard
                                        : root.inirStyle ? Appearance.inir.colLayer2
                                        : Appearance.colors.colSecondaryContainer
                                    enableAnimation: Appearance.animationsEnabled
                                    animationDuration: 600
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        StyledText {
                                            text: "CPU"
                                            font { pixelSize: Appearance.font.pixelSize.smallest; weight: Font.Medium }
                                            color: root.colText
                                        }
                                        Item { Layout.fillWidth: true }
                                        StyledText {
                                            text: Math.round(ResourceUsage.cpuUsage * 100) + "%"
                                            font { pixelSize: Appearance.font.pixelSize.smallest; family: Appearance.font.family.numbers; weight: Font.Bold }
                                            color: ResourceUsage.cpuUsage > 0.8 ? Appearance.m3colors.m3error : root.colPrimary
                                        }
                                    }

                                    StyledText {
                                        visible: ResourceUsage.cpuTemp > 0
                                        text: ResourceUsage.cpuTemp + "°C"
                                        font { pixelSize: Appearance.font.pixelSize.smallest; family: Appearance.font.family.numbers }
                                        color: ResourceUsage.cpuTemp > 80 ? Appearance.m3colors.m3error
                                            : ResourceUsage.cpuTemp > 60 ? Appearance.colors.colTertiary
                                            : root.colSubtext
                                    }
                                }
                            }

                            Graph {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24
                                values: ResourceUsage.cpuUsageHistory
                                points: Math.min(ResourceUsage.cpuUsageHistory.length, 30)
                                color: ResourceUsage.cpuUsage > 0.8 ? Appearance.m3colors.m3error : root.colPrimary
                                fillOpacity: 0.15
                                alignment: Graph.Alignment.Right
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            color: root.colBorder
                            opacity: 0.4
                        }

                        // RAM
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                CircularProgress {
                                    implicitSize: 32
                                    lineWidth: 3
                                    value: ResourceUsage.memoryUsedPercentage
                                    colPrimary: ResourceUsage.memoryUsedPercentage > 0.85 ? Appearance.m3colors.m3error : Appearance.colors.colSecondary
                                    colSecondary: root.angelStyle ? Appearance.angel.colGlassCard
                                        : root.inirStyle ? Appearance.inir.colLayer2
                                        : Appearance.colors.colSecondaryContainer
                                    enableAnimation: Appearance.animationsEnabled
                                    animationDuration: 600
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        StyledText {
                                            text: "RAM"
                                            font { pixelSize: Appearance.font.pixelSize.smallest; weight: Font.Medium }
                                            color: root.colText
                                        }
                                        Item { Layout.fillWidth: true }
                                        StyledText {
                                            text: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%"
                                            font { pixelSize: Appearance.font.pixelSize.smallest; family: Appearance.font.family.numbers; weight: Font.Bold }
                                            color: ResourceUsage.memoryUsedPercentage > 0.85 ? Appearance.m3colors.m3error : Appearance.colors.colSecondary
                                        }
                                    }

                                    StyledText {
                                        text: ResourceUsage.kbToGbString(ResourceUsage.memoryUsed) + " / " + ResourceUsage.maxAvailableMemoryString
                                        font { pixelSize: Appearance.font.pixelSize.smallest; family: Appearance.font.family.numbers }
                                        color: root.colSubtext
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            Graph {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24
                                values: ResourceUsage.memoryUsageHistory
                                points: Math.min(ResourceUsage.memoryUsageHistory.length, 30)
                                color: ResourceUsage.memoryUsedPercentage > 0.85 ? Appearance.m3colors.m3error : Appearance.colors.colSecondary
                                fillOpacity: 0.15
                                alignment: Graph.Alignment.Right
                            }
                        }
                    }

                    // Disk + Battery compact row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: ResourceUsage.diskTotal > 1 || Battery.available

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: root.colBorder
                            opacity: 0.4
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: ResourceUsage.diskTotal > 1 || Battery.available

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            visible: ResourceUsage.diskTotal > 1

                            MaterialSymbol {
                                text: "storage"
                                iconSize: 14
                                color: root.colSubtext
                            }
                            StyledText {
                                text: Translation.tr("Disk")
                                font { pixelSize: Appearance.font.pixelSize.smallest; weight: Font.Medium }
                                color: root.colSubtext
                            }
                            Item { Layout.fillWidth: true }
                            StyledText {
                                text: Math.round(ResourceUsage.diskUsedPercentage * 100) + "%"
                                font { pixelSize: Appearance.font.pixelSize.smallest; family: Appearance.font.family.numbers; weight: Font.Medium }
                                color: ResourceUsage.diskUsedPercentage > 0.9 ? Appearance.m3colors.m3error : root.colSubtext
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 12
                            visible: ResourceUsage.diskTotal > 1 && Battery.available
                            color: root.colBorder
                            opacity: 0.4
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: Battery.available
                            spacing: 5

                            MaterialSymbol {
                                text: Battery.isCharging ? "battery_charging_full"
                                    : Battery.percentage > 80 ? "battery_full"
                                    : Battery.percentage > 60 ? "battery_5_bar"
                                    : Battery.percentage > 40 ? "battery_3_bar"
                                    : Battery.percentage > 20 ? "battery_2_bar" : "battery_1_bar"
                                iconSize: 14
                                fill: 1
                                color: Battery.percentage <= 20 && !Battery.isCharging ? Appearance.m3colors.m3error
                                    : Battery.isCharging ? Appearance.colors.colTertiary
                                    : root.colSubtext
                            }
                            StyledText {
                                text: Battery.percentage + "%"
                                font { pixelSize: Appearance.font.pixelSize.smallest; family: Appearance.font.family.numbers; weight: Font.Medium }
                                color: Battery.percentage <= 20 && !Battery.isCharging ? Appearance.m3colors.m3error
                                    : Battery.isCharging ? Appearance.colors.colTertiary
                                    : root.colSubtext
                            }
                            StyledText {
                                visible: Battery.isCharging
                                text: "· " + Translation.tr("Charging")
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colTertiary
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════
    // INLINE COMPONENTS
    // ═══════════════════════════════════════

    component QuickToggle: Rectangle {
        id: toggle
        property string icon
        property string label
        property bool active: false
        signal clicked()

        Layout.fillWidth: true
        implicitHeight: toggleCol.implicitHeight + 16
        radius: root.angelStyle ? Appearance.angel.roundingSmall : root.inirStyle ? Appearance.inir.roundingSmall : Appearance.rounding.small

        color: toggleArea.containsMouse
            ? (active ? ColorUtils.transparentize(root.colPrimary, 0.25) : root.colCardHover)
            : (active ? root.colPrimary : root.colLayer2)

        border.width: root.bw
        border.color: root.angelStyle ? "transparent"
            : root.inirStyle ? (active ? Appearance.inir.colPrimary : Appearance.inir.colBorderSubtle)
            : "transparent"

        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        ColumnLayout {
            id: toggleCol
            anchors.centerIn: parent
            spacing: 3

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: toggle.icon
                iconSize: 22
                fill: toggle.active ? 1 : 0
                color: toggle.active ? root.colOnPrimary
                    : (root.angelStyle ? Appearance.angel.colText
                        : root.inirStyle ? Appearance.inir.colText
                        : Appearance.colors.colOnLayer1)

                Behavior on fill {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: toggle.label
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: toggle.active ? root.colOnPrimary
                    : (root.angelStyle ? Appearance.angel.colTextSecondary
                        : root.inirStyle ? Appearance.inir.colTextSecondary
                        : Appearance.colors.colSubtext)

                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
            }
        }

        MouseArea {
            id: toggleArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.clicked()
        }
    }

    component DashMiniSlider: RowLayout {
        id: miniSlider
        property string icon
        property real value: 0
        signal moved(real val)
        signal iconClicked()

        spacing: 4

        RippleButton {
            implicitWidth: 28
            implicitHeight: 28
            buttonRadius: root.angelStyle ? Appearance.angel.roundingSmall
                : root.inirStyle ? Appearance.inir.roundingSmall : Appearance.rounding.full
            colBackground: "transparent"
            colBackgroundHover: root.angelStyle ? Appearance.angel.colGlassCardHover
                : root.inirStyle ? Appearance.inir.colLayer2Hover
                : root.auroraStyle ? (Appearance.aurora?.colSubSurfaceHover ?? Appearance.colors.colLayer2Hover)
                : Appearance.colors.colLayer2Hover
            onClicked: miniSlider.iconClicked()
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: miniSlider.icon
                iconSize: 16
                color: root.angelStyle ? Appearance.angel.colText
                    : root.inirStyle ? Appearance.inir.colText
                    : root.auroraStyle ? (Appearance.m3colors?.m3onSurface ?? Appearance.colors.colOnLayer1)
                    : Appearance.colors.colOnLayer1
            }
        }

        StyledSlider {
            id: dashSlider
            Layout.fillWidth: true
            configuration: StyledSlider.Configuration.M
            stopIndicatorValues: []
            scrollable: true
            value: miniSlider.value
            onMoved: miniSlider.moved(value)

            Binding {
                target: dashSlider
                property: "value"
                value: miniSlider.value
                when: !dashSlider.pressed && !dashSlider._userInteracting
                restoreMode: Binding.RestoreNone
            }
        }
    }

    component WeatherChip: Row {
        property string icon
        property string value
        spacing: 4

        MaterialSymbol {
            text: icon
            iconSize: 13
            color: root.colSubtext
            anchors.verticalCenter: parent.verticalCenter
        }
        StyledText {
            text: value
            font { pixelSize: Appearance.font.pixelSize.smallest; family: Appearance.font.family.numbers }
            color: root.colSubtext
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
