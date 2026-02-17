pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import "root:"

Item {
    id: root
    Layout.fillWidth: true
    implicitHeight: visible ? card.implicitHeight : 0
    visible: hasPlayer
    
    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool isYtMusicActive: MprisController.isYtMusicActive
    readonly property bool hasPlayer: (player && player.trackTitle) || (isYtMusicActive && YtMusic.currentVideoId)
    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere

    readonly property string effectiveArtUrl: isYtMusicActive && YtMusic.currentThumbnail ? YtMusic.currentThumbnail : (player?.trackArtUrl ?? "")
    readonly property string effectiveTitle: isYtMusicActive && YtMusic.currentTitle ? YtMusic.currentTitle : (player?.trackTitle ?? "")
    readonly property string effectiveArtist: isYtMusicActive && YtMusic.currentArtist ? YtMusic.currentArtist : (player?.trackArtist ?? "")
    readonly property bool effectiveIsPlaying: isYtMusicActive ? YtMusic.isPlaying : (player?.isPlaying ?? false)

    property string artDownloadLocation: Directories.coverArt
    property string artFileName: effectiveArtUrl ? Qt.md5(effectiveArtUrl) : ""
    property string artFilePath: artFileName ? `${artDownloadLocation}/${artFileName}` : ""
    property bool downloaded: false
    property string displayedArtFilePath: downloaded ? Qt.resolvedUrl(artFilePath) : ""
    property int _downloadRetryCount: 0
    readonly property int _maxRetries: 3

    function checkAndDownloadArt() {
        if (!effectiveArtUrl) {
            downloaded = false
            _downloadRetryCount = 0
            return
        }
        artExistsChecker.running = true
    }

    function retryDownload() {
        if (_downloadRetryCount < _maxRetries && player?.trackArtUrl) {
            _downloadRetryCount++
            retryTimer.start()
        }
    }

    Timer {
        id: retryTimer
        interval: 1000 * root._downloadRetryCount
        repeat: false
        onTriggered: {
            if (root.effectiveArtUrl && !root.downloaded) {
                coverArtDownloader.targetFile = root.effectiveArtUrl
                coverArtDownloader.artFilePath = root.artFilePath
                coverArtDownloader.running = true
            }
        }
    }

    onArtFilePathChanged: {
        _downloadRetryCount = 0
        checkAndDownloadArt()
    }
    
    Connections {
        target: root.player
        function onTrackArtUrlChanged() {
            if (!root.isYtMusicActive) {
                root._downloadRetryCount = 0
                root.checkAndDownloadArt()
            }
        }
    }

    Connections {
        target: YtMusic
        function onCurrentThumbnailChanged() {
            if (root.isYtMusicActive) {
                root._downloadRetryCount = 0
                root.checkAndDownloadArt()
            }
        }
    }

    Process {
        id: artExistsChecker
        command: ["/usr/bin/test", "-f", root.artFilePath]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.downloaded = true
                root._downloadRetryCount = 0
            } else {
                root.downloaded = false
                coverArtDownloader.targetFile = root.effectiveArtUrl ?? ""
                coverArtDownloader.artFilePath = root.artFilePath
                coverArtDownloader.running = true
            }
        }
    }

    Process {
        id: coverArtDownloader
        property string targetFile
        property string artFilePath
        command: ["/usr/bin/bash", "-c", `
            if [ -f '${artFilePath}' ]; then exit 0; fi
            mkdir -p '${root.artDownloadLocation}'
            tmp='${artFilePath}.tmp'
            /usr/bin/curl -sSL --connect-timeout 10 --max-time 30 '${targetFile}' -o "$tmp" && \
            [ -s "$tmp" ] && /usr/bin/mv -f "$tmp" '${artFilePath}' || { rm -f "$tmp"; exit 1; }
        `]
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.downloaded = true
                root._downloadRetryCount = 0
            } else {
                root.downloaded = false
                root.retryDownload()
            }
        }
    }

    // Cava audio visualizer
    CavaProcess {
        id: cavaProcess
        active: root.visible && root.hasPlayer && GlobalStates.controlPanelOpen
    }
    
    property list<real> visualizerPoints: cavaProcess.points

    ColorQuantizer {
        id: colorQuantizer
        source: root.displayedArtFilePath
        depth: 0
        rescaleSize: 1
    }

    property color artDominantColor: ColorUtils.mix(
        colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary,
        Appearance.colors.colPrimaryContainer, 0.7
    )

    property QtObject blendedColors: AdaptedMaterialScheme { color: root.artDominantColor }
    
    readonly property color jiraColText: Appearance.inir.colText
    readonly property color jiraColTextSecondary: Appearance.inir.colTextSecondary
    readonly property color jiraColPrimary: Appearance.inir.colPrimary
    readonly property color jiraColLayer1: Appearance.inir.colLayer1
    readonly property color jiraColLayer2: Appearance.inir.colLayer2

    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: 160
        radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
             : root.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
        color: Appearance.angelEverywhere ? "transparent"
             : root.inirEverywhere ? Appearance.inir.colLayer1 
             : root.auroraEverywhere ? ColorUtils.transparentize(root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.7)
             : (root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0)
        border.width: Appearance.angelEverywhere ? 0 : (root.inirEverywhere ? 1 : 0)
        border.color: Appearance.angelEverywhere ? "transparent"
                    : root.inirEverywhere ? Appearance.inir.colBorder : "transparent"
        clip: true

        AngelPartialBorder { targetRadius: card.radius; coverage: 0.5 }

        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle { width: card.width; height: card.height; radius: card.radius }
        }

        // Cover art background
        Image {
            id: bgArt
            anchors.fill: parent
            source: root.displayedArtFilePath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            opacity: root.inirEverywhere ? 0.15 : (root.auroraEverywhere ? 0.25 : 0.5)
            visible: root.displayedArtFilePath !== ""

            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: root.inirEverywhere ? 0.3 : 0.15
                blurMax: 16
                saturation: root.inirEverywhere ? 0.1 : 0.3
            }
        }

        // Dark overlay for Material
        Rectangle {
            anchors.fill: parent
            visible: !root.inirEverywhere && !root.auroraEverywhere
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.35; color: ColorUtils.transparentize(root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.3) }
                GradientStop { position: 1.0; color: ColorUtils.transparentize(root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.15) }
            }
        }

        // Wave Visualizer at bottom
        WaveVisualizer {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 40
            live: root.player?.isPlaying ?? false
            points: root.visualizerPoints
            maxVisualizerValue: 1000
            smoothing: 2
            color: ColorUtils.transparentize(
                Appearance.angelEverywhere ? Appearance.angel.colPrimary
                : root.inirEverywhere ? root.jiraColPrimary : (root.blendedColors?.colPrimary ?? Appearance.colors.colPrimary), 
                0.6
            )
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // Cover art
            Rectangle {
                id: coverArtContainer
                Layout.preferredWidth: 136
                Layout.preferredHeight: 136
                radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                    : root.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
                color: "transparent"
                clip: true

                layer.enabled: true
                layer.effect: GE.OpacityMask {
                    maskSource: Rectangle { 
                        width: 136
                        height: 136
                        radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                            : root.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small 
                    }
                }

                Image {
                    id: coverArt
                    anchors.fill: parent
                    source: root.displayedArtFilePath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    mipmap: true
                    sourceSize.width: 272
                    sourceSize.height: 272
                }

                Rectangle {
                    anchors.fill: parent
                    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                        : root.inirEverywhere ? root.jiraColLayer2 : (root.blendedColors?.colLayer1 ?? Appearance.colors.colLayer1)
                    visible: !root.downloaded
                    
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "music_note"
                        iconSize: 48
                        color: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                            : root.inirEverywhere ? root.jiraColTextSecondary : (root.blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
                    }
                }
            }

            // Info & controls
            ColumnLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: StringUtils.cleanMusicTitle(root.effectiveTitle) || "—"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.angelEverywhere ? Appearance.angel.colText
                        : root.inirEverywhere ? root.jiraColText : (root.blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.effectiveArtist || ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                        : root.inirEverywhere ? root.jiraColTextSecondary : (root.blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
                    elide: Text.ElideRight
                    visible: text !== ""
                    opacity: 0.7
                }

                Item { Layout.fillHeight: true }

                // Progress bar
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 16

                    Loader {
                        anchors.fill: parent
                        active: root.player?.canSeek ?? false
                        sourceComponent: StyledSlider {
                            configuration: StyledSlider.Configuration.Wavy
                            wavy: root.player?.isPlaying ?? false
                            animateWave: root.player?.isPlaying ?? false
                            highlightColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                                : root.inirEverywhere ? root.jiraColPrimary : (root.blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
                            trackColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                : root.inirEverywhere ? Appearance.inir.colLayer2 : (root.blendedColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer)
                            handleColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                                : root.inirEverywhere ? root.jiraColPrimary : (root.blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
                            value: root.player?.length > 0 ? root.player.position / root.player.length : 0
                            onMoved: root.player.position = value * root.player.length
                            scrollable: true
                        }
                    }

                    Loader {
                        anchors.fill: parent
                        active: !(root.player?.canSeek ?? false)
                        sourceComponent: StyledProgressBar {
                            wavy: root.player?.isPlaying ?? false
                            animateWave: root.player?.isPlaying ?? false
                            highlightColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                                : root.inirEverywhere ? root.jiraColPrimary : (root.blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
                            trackColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                : root.inirEverywhere ? Appearance.inir.colLayer2 : (root.blendedColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer)
                            value: root.player?.length > 0 ? root.player.position / root.player.length : 0
                        }
                    }
                }

                // Time + controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(root.player?.position ?? 0)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: Appearance.angelEverywhere ? Appearance.angel.colText
                            : root.inirEverywhere ? root.jiraColText : (root.blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                    }

                    Item { Layout.fillWidth: true }

                    // Controls
                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                            : root.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                            : root.inirEverywhere ? Appearance.inir.colLayer2Hover : ColorUtils.transparentize(root.blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5)
                        colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
                            : root.inirEverywhere ? Appearance.inir.colLayer2Active : (root.blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active)
                        onClicked: MprisController.previous()

                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_previous"
                                iconSize: 22
                                fill: 1
                                color: Appearance.angelEverywhere ? Appearance.angel.colText
                                    : root.inirEverywhere ? root.jiraColText : (root.blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                            }
                        }

                        StyledToolTip { text: Translation.tr("Previous") }
                    }

                    RippleButton {
                        id: playPauseButton
                        implicitWidth: 44
                        implicitHeight: 44
                        buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                            : root.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.angelEverywhere
                            ? Appearance.angel.colGlassCardHover
                            : root.inirEverywhere
                            ? Appearance.inir.colLayer2Hover
                            : root.auroraEverywhere
                                ? ColorUtils.transparentize(root.blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5)
                                : Appearance.colors.colLayer1Hover
                        colRipple: Appearance.angelEverywhere
                            ? Appearance.angel.colGlassCardActive
                            : root.inirEverywhere
                            ? Appearance.inir.colLayer2Active
                            : root.auroraEverywhere
                                ? (root.blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active)
                                : Appearance.colors.colLayer1Active
                        onClicked: MprisController.togglePlaying()

                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: root.player?.isPlaying ? "pause" : "play_arrow"
                                iconSize: 26
                                fill: 1
                                color: Appearance.angelEverywhere
                                    ? Appearance.angel.colPrimary
                                    : root.inirEverywhere
                                    ? root.jiraColPrimary
                                    : root.auroraEverywhere
                                        ? (root.blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                                        : Appearance.colors.colOnLayer1
                            }
                        }

                        StyledToolTip { text: root.player?.isPlaying ? Translation.tr("Pause") : Translation.tr("Play") }
                    }

                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                            : root.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                            : root.inirEverywhere ? Appearance.inir.colLayer2Hover : ColorUtils.transparentize(root.blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5)
                        colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
                            : root.inirEverywhere ? Appearance.inir.colLayer2Active : (root.blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active)
                        onClicked: MprisController.next()

                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_next"
                                iconSize: 22
                                fill: 1
                                color: Appearance.angelEverywhere ? Appearance.angel.colText
                                    : root.inirEverywhere ? root.jiraColText : (root.blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                            }
                        }

                        StyledToolTip { text: Translation.tr("Next") }
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(root.player?.length ?? 0)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: Appearance.angelEverywhere ? Appearance.angel.colText
                            : root.inirEverywhere ? root.jiraColText : (root.blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                    }
                }
            }
        }
    }

    Timer {
        running: root.player?.playbackState === MprisPlaybackState.Playing
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }
}
