pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import qs.services
import "root:"

Item {
    id: root
    implicitHeight: hasPlayer ? card.implicitHeight + Appearance.sizes.elevationMargin : 0
    visible: hasPlayer

    property MprisPlayer player: MprisController.activePlayer
    readonly property bool isYtMusicPlayer: MprisController.isYtMusicActive
    readonly property bool hasPlayer: (player && player.trackTitle) || (isYtMusicPlayer && YtMusic.currentVideoId)
    
    readonly property string effectiveTitle: isYtMusicPlayer ? YtMusic.currentTitle : (player?.trackTitle ?? "")
    readonly property string effectiveArtist: isYtMusicPlayer ? YtMusic.currentArtist : (player?.trackArtist ?? "")
    readonly property string effectiveArtUrl: isYtMusicPlayer ? YtMusic.currentThumbnail : (player?.trackArtUrl ?? "")
    readonly property real effectivePosition: isYtMusicPlayer ? YtMusic.currentPosition : (player?.position ?? 0)
    readonly property real effectiveLength: isYtMusicPlayer ? YtMusic.currentDuration : (player?.length ?? 0)
    readonly property bool effectiveIsPlaying: isYtMusicPlayer ? YtMusic.isPlaying : (player?.isPlaying ?? false)
    readonly property bool effectiveCanSeek: isYtMusicPlayer ? YtMusic.canSeek : (player?.canSeek ?? false)
    
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: effectiveArtUrl ? Qt.md5(effectiveArtUrl) : ""
    property string artFilePath: artFileName ? `${artDownloadLocation}/${artFileName}` : ""
    property bool downloaded: false
    property string displayedArtFilePath: downloaded ? Qt.resolvedUrl(artFilePath) : ""
    property int _downloadRetryCount: 0
    readonly property int _maxRetries: 3

    // Cava visualizer - using shared CavaProcess component
    CavaProcess {
        id: cavaProcess
        active: root.visible && root.hasPlayer && GlobalStates.sidebarLeftOpen && Appearance.effectsEnabled
    }

    property list<real> visualizerPoints: cavaProcess.points

    function checkAndDownloadArt() {
        if (!root.effectiveArtUrl) {
            downloaded = false
            _downloadRetryCount = 0
            return
        }
        artExistsChecker.running = true
    }

    function retryDownload() {
        if (_downloadRetryCount < _maxRetries && root.effectiveArtUrl) {
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
    
    onEffectiveArtUrlChanged: {
        _downloadRetryCount = 0
        checkAndDownloadArt()
    }
    
    // Re-check cover art when becoming visible
    onVisibleChanged: {
        if (visible && hasPlayer && artFilePath) {
            checkAndDownloadArt()
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
    
    // Inir uses fixed colors instead of adaptive
    readonly property color jiraColText: Appearance.inir.colText
    readonly property color jiraColTextSecondary: Appearance.inir.colTextSecondary
    readonly property color jiraColPrimary: Appearance.inir.colPrimary
    readonly property color jiraColLayer1: Appearance.inir.colLayer1
    readonly property color jiraColLayer2: Appearance.inir.colLayer2

    StyledRectangularShadow { target: card }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width - Appearance.sizes.elevationMargin
        implicitHeight: 130
        radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
            : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
            : Appearance.rounding.normal
        color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
             : Appearance.inirEverywhere ? Appearance.inir.colLayer1 
             : Appearance.auroraEverywhere ? ColorUtils.transparentize(blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.7)
             : (blendedColors?.colLayer0 ?? Appearance.colors.colLayer0)
        border.width: Appearance.angelEverywhere ? 0 : (Appearance.inirEverywhere ? 1 : 0)
        border.color: Appearance.angelEverywhere ? "transparent"
            : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
        clip: true

        AngelPartialBorder { targetRadius: card.radius; coverage: 0.5 }

        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle { width: card.width; height: card.height; radius: card.radius }
        }

        // Cover art background - subtle for inir, more transparent for aurora
        Image {
            id: bgArt
            anchors.fill: parent
            source: root.displayedArtFilePath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: Appearance.angelEverywhere ? 0.2 : (Appearance.inirEverywhere ? 0.15 : (Appearance.auroraEverywhere ? 0.25 : 0.5))
            visible: root.displayedArtFilePath !== ""

            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: Appearance.inirEverywhere ? 0.3 : 0.15
                blurMax: 16
                saturation: Appearance.inirEverywhere ? 0.1 : 0.3
            }
        }

        // Dark overlay for controls visibility - only for Material
        Rectangle {
            anchors.fill: parent
            visible: !Appearance.inirEverywhere && !Appearance.auroraEverywhere
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.35; color: ColorUtils.transparentize(blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.3) }
                GradientStop { position: 1.0; color: ColorUtils.transparentize(blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.15) }
            }
        }

        // Visualizer at bottom
        WaveVisualizer {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 30
            live: root.effectiveIsPlaying
            points: root.visualizerPoints
            maxVisualizerValue: 1000
            smoothing: 2
            color: ColorUtils.transparentize(
                Appearance.angelEverywhere ? Appearance.angel.colPrimary
                : Appearance.inirEverywhere ? root.jiraColPrimary : (blendedColors?.colPrimary ?? Appearance.colors.colPrimary), 
                0.6
            )
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            // Cover art thumbnail
            Rectangle {
                id: coverArtContainer
                Layout.preferredWidth: 110
                Layout.preferredHeight: 110
                radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                    : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
                color: "transparent"
                clip: true

                layer.enabled: true
                layer.effect: GE.OpacityMask {
                    maskSource: Rectangle { 
                        width: 110
                        height: 110
                        radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                            : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small 
                    }
                }

                // Cover art with blur transition
                Image {
                    id: coverArt
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    
                    layer.enabled: Appearance.effectsEnabled
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: coverArtContainer.transitioning ? 1 : 0
                        blurMax: 32
                        Behavior on blur {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                property bool transitioning: false
                property string pendingSource: ""
                
                Timer {
                    id: blurInTimer
                    interval: 150
                    onTriggered: {
                        coverArt.source = coverArtContainer.pendingSource
                        blurOutTimer.start()
                    }
                }
                
                Timer {
                    id: blurOutTimer
                    interval: 50
                    onTriggered: coverArtContainer.transitioning = false
                }
                
                Connections {
                    target: root
                    function onDisplayedArtFilePathChanged() {
                        if (!root.displayedArtFilePath) return
                        if (!coverArt.source.toString()) {
                            coverArt.source = root.displayedArtFilePath
                            return
                        }
                        coverArtContainer.pendingSource = root.displayedArtFilePath
                        coverArtContainer.transitioning = true
                        blurInTimer.start()
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                        : Appearance.inirEverywhere ? root.jiraColLayer2 : (blendedColors?.colLayer1 ?? Appearance.colors.colLayer1)
                    visible: !root.downloaded
                    
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "music_note"
                        iconSize: 32
                        color: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                            : Appearance.inirEverywhere ? root.jiraColTextSecondary : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
                    }
                }
            }

            // Info & controls column
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 2

                // Title
                StyledText {
                    Layout.fillWidth: true
                    text: StringUtils.cleanMusicTitle(root.effectiveTitle) || "—"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.angelEverywhere ? Appearance.angel.colText
                        : Appearance.inirEverywhere ? root.jiraColText : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                    elide: Text.ElideRight
                    animateChange: true
                    animationDistanceX: 6
                }

                // Artist
                StyledText {
                    Layout.fillWidth: true
                    text: root.effectiveArtist || ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                        : Appearance.inirEverywhere ? root.jiraColTextSecondary : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
                    elide: Text.ElideRight
                    visible: text !== ""
                }

                Item { Layout.fillHeight: true }

                // Progress bar
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 16

                    Loader {
                        anchors.fill: parent
                        active: root.effectiveCanSeek
                        sourceComponent: StyledSlider {
                            configuration: StyledSlider.Configuration.Wavy
                            wavy: root.effectiveIsPlaying
                            animateWave: root.effectiveIsPlaying
                            highlightColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                                : Appearance.inirEverywhere ? root.jiraColPrimary : (blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
                            trackColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                : Appearance.inirEverywhere ? Appearance.inir.colLayer2 : (blendedColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer)
                            handleColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                                : Appearance.inirEverywhere ? root.jiraColPrimary : (blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
                            value: root.effectiveLength > 0 ? root.effectivePosition / root.effectiveLength : 0
                            onMoved: {
                                if (root.isYtMusicPlayer) {
                                    YtMusic.seek(value * root.effectiveLength)
                                } else if (root.player) {
                                    root.player.position = value * root.player.length
                                }
                            }
                            scrollable: true
                        }
                    }

                    Loader {
                        anchors.fill: parent
                        active: !root.effectiveCanSeek
                        sourceComponent: StyledProgressBar {
                            wavy: root.effectiveIsPlaying
                            animateWave: root.effectiveIsPlaying
                            highlightColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                                : Appearance.inirEverywhere ? root.jiraColPrimary : (blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
                            trackColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                : Appearance.inirEverywhere ? Appearance.inir.colLayer2 : (blendedColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer)
                            value: root.effectiveLength > 0 ? root.effectivePosition / root.effectiveLength : 0
                        }
                    }
                }

                // Time + controls row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(root.effectivePosition)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: Appearance.angelEverywhere ? Appearance.angel.colText
                            : Appearance.inirEverywhere ? root.jiraColText : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                    }

                    Item { Layout.fillWidth: true }

                    // Controls
                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                            : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover : ColorUtils.transparentize(blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5)
                        colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active : (blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active)
                        onClicked: MprisController.previous()

                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_previous"
                                iconSize: 22
                                fill: 1
                                color: Appearance.angelEverywhere ? Appearance.angel.colText
                                    : Appearance.inirEverywhere ? root.jiraColText : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                            }
                        }

                        StyledToolTip { text: Translation.tr("Previous") }
                    }

                    RippleButton {
                        id: playPauseButton
                        implicitWidth: 40
                        implicitHeight: 40
                        buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                            : Appearance.inirEverywhere 
                            ? Appearance.inir.roundingSmall 
                            : (root.effectiveIsPlaying ? Appearance.rounding.normal : Appearance.rounding.full)
                        colBackground: Appearance.angelEverywhere
                            ? "transparent"
                            : Appearance.inirEverywhere
                            ? "transparent"
                            : Appearance.auroraEverywhere
                                ? "transparent"
                                : (root.effectiveIsPlaying 
                                    ? (blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
                                    : (blendedColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer))
                        colBackgroundHover: Appearance.angelEverywhere
                            ? Appearance.angel.colGlassCardHover
                            : Appearance.inirEverywhere
                            ? Appearance.inir.colLayer2Hover
                            : Appearance.auroraEverywhere
                                ? ColorUtils.transparentize(blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5)
                                : (root.effectiveIsPlaying 
                                    ? (blendedColors?.colPrimaryHover ?? Appearance.colors.colPrimaryHover)
                                    : (blendedColors?.colSecondaryContainerHover ?? Appearance.colors.colSecondaryContainerHover))
                        colRipple: Appearance.angelEverywhere
                            ? Appearance.angel.colGlassCardActive
                            : Appearance.inirEverywhere
                            ? Appearance.inir.colLayer2Active
                            : Appearance.auroraEverywhere
                                ? (blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active)
                                : (root.effectiveIsPlaying 
                                    ? (blendedColors?.colPrimaryActive ?? Appearance.colors.colPrimaryActive)
                                    : (blendedColors?.colSecondaryContainerActive ?? Appearance.colors.colSecondaryContainerActive))
                        onClicked: MprisController.togglePlaying()

                        Behavior on buttonRadius {
                            enabled: Appearance.animationsEnabled && !Appearance.inirEverywhere
                            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                        }

                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: root.effectiveIsPlaying ? "pause" : "play_arrow"
                                iconSize: 24
                                fill: 1
                                color: Appearance.angelEverywhere
                                    ? Appearance.angel.colPrimary
                                    : Appearance.inirEverywhere
                                    ? root.jiraColPrimary
                                    : Appearance.auroraEverywhere
                                        ? (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                                        : (root.effectiveIsPlaying 
                                            ? (blendedColors?.colOnPrimary ?? Appearance.colors.colOnPrimary)
                                            : (blendedColors?.colOnSecondaryContainer ?? Appearance.colors.colOnSecondaryContainer))

                                Behavior on color {
                                    enabled: Appearance.animationsEnabled
                                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                }
                            }
                        }

                        StyledToolTip { text: root.effectiveIsPlaying ? Translation.tr("Pause") : Translation.tr("Play") }
                    }

                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                            : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover : ColorUtils.transparentize(blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5)
                        colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active : (blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active)
                        onClicked: MprisController.next()

                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_next"
                                iconSize: 22
                                fill: 1
                                color: Appearance.angelEverywhere ? Appearance.angel.colText
                                    : Appearance.inirEverywhere ? root.jiraColText : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                            }
                        }

                        StyledToolTip { text: Translation.tr("Next") }
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(root.effectiveLength)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: Appearance.angelEverywhere ? Appearance.angel.colText
                            : Appearance.inirEverywhere ? root.jiraColText : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                    }
                }
            }
        }
    }

    Timer {
        running: root.effectiveIsPlaying
        interval: 1000
        repeat: true
        onTriggered: {
            if (!root.isYtMusicPlayer && root.player) {
                root.player.positionChanged()
            }
        }
    }
}
