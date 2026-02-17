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

/**
 * Media player widget for lock screen - reuses sidebar MediaPlayerWidget design
 */
Item {
    id: root
    implicitHeight: hasPlayer ? card.implicitHeight + Appearance.sizes.elevationMargin : 0
    visible: hasPlayer

    required property MprisPlayer player
    readonly property bool hasPlayer: player && player.trackTitle
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: player?.trackArtUrl ? Qt.md5(player.trackArtUrl) : ""
    property string artFilePath: artFileName ? `${artDownloadLocation}/${artFileName}` : ""
    property bool downloaded: false
    property string displayedArtFilePath: downloaded ? Qt.resolvedUrl(artFilePath) : ""
    property int _downloadRetryCount: 0
    readonly property int _maxRetries: 3

    // Cava visualizer
    CavaProcess {
        id: cavaProcess
        active: root.visible && root.hasPlayer && (root.player?.isPlaying ?? false) && Appearance.effectsEnabled
    }

    property list<real> visualizerPoints: cavaProcess.points

    function checkAndDownloadArt() {
        if (!player?.trackArtUrl) {
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
            if (root.player?.trackArtUrl && !root.downloaded) {
                coverArtDownloader.targetFile = root.player.trackArtUrl
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
            root._downloadRetryCount = 0
            root.checkAndDownloadArt()
        }
    }

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
                coverArtDownloader.targetFile = root.player?.trackArtUrl ?? ""
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

    StyledRectangularShadow { target: card; visible: Appearance.angelEverywhere || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere) }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width - Appearance.sizes.elevationMargin
        implicitHeight: 130
        radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
            : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
        color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
             : Appearance.inirEverywhere ? Appearance.inir.colLayer1
             : Appearance.auroraEverywhere ? ColorUtils.transparentize(blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.7)
             : (blendedColors?.colLayer0 ?? Appearance.colors.colLayer0)
        border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
            : Appearance.inirEverywhere ? 1 : 0
        border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
            : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
        clip: true

        layer.enabled: Appearance.effectsEnabled
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
            opacity: Appearance.inirEverywhere ? 0.2 : (Appearance.auroraEverywhere ? 0.3 : 0.6)
            visible: root.displayedArtFilePath !== ""

            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: Appearance.inirEverywhere ? 0.5 : 0.4
                blurMax: 32
                saturation: Appearance.inirEverywhere ? 0.1 : 0.4
            }
        }

        // Dark overlay for controls visibility
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: ColorUtils.transparentize(blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.7) }
                GradientStop { position: 0.3; color: ColorUtils.transparentize(blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.4) }
                GradientStop { position: 1.0; color: ColorUtils.transparentize(blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.2) }
            }
        }

        // Visualizer at bottom
        WaveVisualizer {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 30
            live: root.player?.isPlaying ?? false
            points: root.visualizerPoints
            maxVisualizerValue: 1000
            smoothing: 2
            color: ColorUtils.transparentize(
                Appearance.inirEverywhere ? root.jiraColPrimary : (blendedColors?.colPrimary ?? Appearance.colors.colPrimary),
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
                Layout.alignment: Qt.AlignVCenter
                radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
                color: "transparent"
                clip: true

                layer.enabled: Appearance.effectsEnabled
                layer.effect: GE.OpacityMask {
                    maskSource: Rectangle {
                        width: 110
                        height: 110
                        radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
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
                    color: Appearance.inirEverywhere ? root.jiraColLayer2 : (blendedColors?.colLayer1 ?? Appearance.colors.colLayer1)
                    visible: !root.downloaded

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "music_note"
                        iconSize: 32
                        color: Appearance.inirEverywhere ? root.jiraColTextSecondary : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
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
                    text: StringUtils.cleanMusicTitle(root.player?.trackTitle) || "—"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.inirEverywhere ? root.jiraColText : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                    elide: Text.ElideRight
                    animateChange: true
                    animationDistanceX: 6
                }

                // Artist
                StyledText {
                    Layout.fillWidth: true
                    text: root.player?.trackArtist || ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.inirEverywhere ? root.jiraColTextSecondary : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
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
                        active: root.player?.canSeek ?? false
                        sourceComponent: StyledSlider {
                            configuration: StyledSlider.Configuration.Wavy
                            wavy: root.player?.isPlaying ?? false
                            animateWave: root.player?.isPlaying ?? false
                            highlightColor: Appearance.inirEverywhere ? root.jiraColPrimary : (blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
                            trackColor: Appearance.inirEverywhere ? Appearance.inir.colLayer2 : (blendedColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer)
                            handleColor: Appearance.inirEverywhere ? root.jiraColPrimary : (blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
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
                            highlightColor: Appearance.inirEverywhere ? root.jiraColPrimary : (blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
                            trackColor: Appearance.inirEverywhere ? Appearance.inir.colLayer2 : (blendedColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer)
                            value: root.player?.length > 0 ? root.player.position / root.player.length : 0
                        }
                    }
                }

                // Time + controls row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(root.player?.position ?? 0)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: Appearance.inirEverywhere ? root.jiraColText : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                    }

                    Item { Layout.fillWidth: true }

                    // Controls
                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover : ColorUtils.transparentize(blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5)
                        colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer2Active : (blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active)
                        onClicked: root.player?.previous()

                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_previous"
                                iconSize: 22
                                fill: 1
                                color: Appearance.inirEverywhere ? root.jiraColText : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                            }
                        }
                    }

                    RippleButton {
                        id: playPauseButton
                        implicitWidth: 40
                        implicitHeight: 40
                        buttonRadius: Appearance.inirEverywhere
                            ? Appearance.inir.roundingSmall
                            : (root.player?.isPlaying ? Appearance.rounding.normal : Appearance.rounding.full)
                        colBackground: Appearance.inirEverywhere
                            ? "transparent"
                            : Appearance.auroraEverywhere
                                ? "transparent"
                                : (root.player?.isPlaying
                                    ? (blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
                                    : (blendedColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer))
                        colBackgroundHover: Appearance.inirEverywhere
                            ? Appearance.inir.colLayer2Hover
                            : Appearance.auroraEverywhere
                                ? ColorUtils.transparentize(blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5)
                                : (root.player?.isPlaying
                                    ? (blendedColors?.colPrimaryHover ?? Appearance.colors.colPrimaryHover)
                                    : (blendedColors?.colSecondaryContainerHover ?? Appearance.colors.colSecondaryContainerHover))
                        colRipple: Appearance.inirEverywhere
                            ? Appearance.inir.colLayer2Active
                            : Appearance.auroraEverywhere
                                ? (blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active)
                                : (root.player?.isPlaying
                                    ? (blendedColors?.colPrimaryActive ?? Appearance.colors.colPrimaryActive)
                                    : (blendedColors?.colSecondaryContainerActive ?? Appearance.colors.colSecondaryContainerActive))
                        onClicked: root.player?.togglePlaying()

                        Behavior on buttonRadius {
                            enabled: Appearance.animationsEnabled && !Appearance.inirEverywhere
                            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                        }

                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: root.player?.isPlaying ? "pause" : "play_arrow"
                                iconSize: 24
                                fill: 1
                                color: Appearance.inirEverywhere
                                    ? root.jiraColPrimary
                                    : Appearance.auroraEverywhere
                                        ? (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                                        : (root.player?.isPlaying
                                            ? (blendedColors?.colOnPrimary ?? Appearance.colors.colOnPrimary)
                                            : (blendedColors?.colOnSecondaryContainer ?? Appearance.colors.colOnSecondaryContainer))

                                Behavior on color {
                                    enabled: Appearance.animationsEnabled
                                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                }
                            }
                        }
                    }

                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover : ColorUtils.transparentize(blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5)
                        colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer2Active : (blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active)
                        onClicked: root.player?.next()

                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_next"
                                iconSize: 22
                                fill: 1
                                color: Appearance.inirEverywhere ? root.jiraColText : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(root.player?.length ?? 0)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: Appearance.inirEverywhere ? root.jiraColText : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
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
