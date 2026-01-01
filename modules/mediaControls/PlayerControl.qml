pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects as GE
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item { // Player instance
    id: root
    required property MprisPlayer player
    property var artUrl: player?.trackArtUrl
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`
    property color artDominantColor: ColorUtils.mix((colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary), Appearance.colors.colPrimaryContainer, 0.8) || Appearance.m3colors.m3secondaryContainer
    property bool downloaded: false
    property int _downloadRetryCount: 0
    readonly property int _maxRetries: 3
    property list<real> visualizerPoints: []
    property real maxVisualizerValue: 1000 // Max value in the data points
    property int visualizerSmoothing: 2 // Number of points to average for smoothing
    property real radius

    property string displayedArtFilePath: root.downloaded ? Qt.resolvedUrl(artFilePath) : ""

    // Inir colors
    readonly property color jiraColText: Appearance.inir.colText
    readonly property color jiraColTextSecondary: Appearance.inir.colTextSecondary
    readonly property color jiraColPrimary: Appearance.inir.colPrimary
    readonly property color jiraColLayer1: Appearance.inir.colLayer1
    readonly property color jiraColLayer2: Appearance.inir.colLayer2

    function checkAndDownloadArt() {
        if (!artUrl || artUrl.length === 0) {
            downloaded = false
            _downloadRetryCount = 0
            return
        }
        artExistsChecker.running = true
    }

    function retryDownload() {
        if (_downloadRetryCount < _maxRetries && artUrl) {
            _downloadRetryCount++
            retryTimer.start()
        }
    }

    Timer {
        id: retryTimer
        interval: 1000 * root._downloadRetryCount
        repeat: false
        onTriggered: {
            if (root.artUrl && !root.downloaded) {
                coverArtDownloader.targetFile = root.artUrl
                coverArtDownloader.artFilePath = root.artFilePath
                coverArtDownloader.running = true
            }
        }
    }

    component TrackChangeButton: RippleButton {
        implicitWidth: 24
        implicitHeight: 24

        property var iconName
        colBackground: "transparent"
        colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover : blendedColors.colSecondaryContainerHover
        colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer2Active : blendedColors.colSecondaryContainerActive
        buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full

        contentItem: MaterialSymbol {
            iconSize: Appearance.font.pixelSize.huge
            fill: 1
            horizontalAlignment: Text.AlignHCenter
            color: Appearance.inirEverywhere ? root.jiraColText : blendedColors.colOnSecondaryContainer
            text: iconName

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }

    Timer { // Force update for revision
        running: root.player?.playbackState == MprisPlaybackState.Playing
        interval: Config.options?.resources?.updateInterval ?? 3000
        repeat: true
        onTriggered: {
            root.player?.positionChanged()
        }
    }

    onArtFilePathChanged: {
        _downloadRetryCount = 0
        checkAndDownloadArt()
    }

    // Re-check cover art when becoming visible
    onVisibleChanged: {
        if (visible && artFilePath) {
            checkAndDownloadArt()
        }
    }

    Process { // Check if cover art exists
        id: artExistsChecker
        command: ["/usr/bin/test", "-f", root.artFilePath]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.downloaded = true
                root._downloadRetryCount = 0
            } else {
                root.downloaded = false
                coverArtDownloader.targetFile = root.artUrl
                coverArtDownloader.artFilePath = root.artFilePath
                coverArtDownloader.running = true
            }
        }
    }

    Process { // Cover art downloader
        id: coverArtDownloader
        property string targetFile: root.artUrl
        property string artFilePath: root.artFilePath
        command: ["/usr/bin/bash", "-c", `
            if [ -f '${artFilePath}' ]; then
                exit 0
            fi
            mkdir -p '${root.artDownloadLocation}'
            tmp='${artFilePath}.tmp'
            /usr/bin/curl -sSL --connect-timeout 10 --max-time 30 '${targetFile}' -o "$tmp" && \
            [ -s "$tmp" ] && /usr/bin/mv -f "$tmp" '${artFilePath}' || { rm -f "$tmp"; exit 1; }
        `]
        onExited: (exitCode, exitStatus) => {
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
        depth: 0 // 2^0 = 1 color
        rescaleSize: 1 // Rescale to 1x1 pixel for faster processing
    }

    property QtObject blendedColors: AdaptedMaterialScheme {
        color: artDominantColor
    }

    StyledRectangularShadow {
        target: background
        visible: !Appearance.inirEverywhere
    }
    Rectangle { // Background
        id: background
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin
        color: Appearance.inirEverywhere ? root.jiraColLayer1 : ColorUtils.applyAlpha(blendedColors.colLayer0, 1)
        radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : root.radius
        border.width: Appearance.inirEverywhere ? 1 : 0
        border.color: Appearance.inir.colBorder

        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: background.width
                height: background.height
                radius: background.radius
            }
        }

        Image {
            id: blurredArt
            anchors.fill: parent
            source: root.displayedArtFilePath
            sourceSize.width: background.width
            sourceSize.height: background.height
            fillMode: Image.PreserveAspectCrop
            cache: false
            antialiasing: true
            asynchronous: true
            opacity: Appearance.inirEverywhere ? 0.15 : 1

            layer.enabled: Appearance.effectsEnabled
            layer.effect: StyledBlurEffect {
                source: blurredArt
            }

            Rectangle {
                anchors.fill: parent
                visible: !Appearance.inirEverywhere
                color: ColorUtils.transparentize(blendedColors.colLayer0, 0.3)
                radius: root.radius
            }
        }

        WaveVisualizer {
            id: visualizerCanvas
            anchors.fill: parent
            live: root.player?.isPlaying
            points: root.visualizerPoints
            maxVisualizerValue: root.maxVisualizerValue
            smoothing: root.visualizerSmoothing
            color: Appearance.inirEverywhere ? root.jiraColPrimary : blendedColors.colPrimary
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 13
            spacing: 15

            Rectangle { // Art background
                id: artBackground
                Layout.fillHeight: true
                implicitWidth: height
                radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.verysmall
                color: Appearance.inirEverywhere ? root.jiraColLayer2 : ColorUtils.transparentize(blendedColors.colLayer1, 0.5)

                layer.enabled: true
                layer.effect: GE.OpacityMask {
                    maskSource: Rectangle {
                        width: artBackground.width
                        height: artBackground.height
                        radius: artBackground.radius
                    }
                }

                StyledImage { // Art image
                    id: mediaArt
                    property int size: parent.height
                    anchors.fill: parent

                    source: root.displayedArtFilePath
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    antialiasing: true

                    width: size
                    height: size
                    sourceSize.width: size
                    sourceSize.height: size
                }
            }

            ColumnLayout { // Info & controls
                Layout.fillHeight: true
                spacing: 2

                StyledText {
                    id: trackTitle
                    Layout.fillWidth: true
                    Layout.rightMargin: playPauseButton.size + 8
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: Appearance.inirEverywhere ? root.jiraColText : blendedColors.colOnLayer0
                    elide: Text.ElideRight
                    text: StringUtils.cleanMusicTitle(root.player?.trackTitle) || "Untitled"
                    animateChange: true
                    animationDistanceX: 6
                    animationDistanceY: 0
                }
                StyledText {
                    id: trackArtist
                    Layout.fillWidth: true
                    Layout.rightMargin: playPauseButton.size + 8
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.inirEverywhere ? root.jiraColTextSecondary : blendedColors.colSubtext
                    elide: Text.ElideRight
                    text: root.player?.trackArtist
                    animateChange: true
                    animationDistanceX: 6
                    animationDistanceY: 0
                }
                Item { Layout.fillHeight: true }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: trackTime.implicitHeight + sliderRow.implicitHeight

                    StyledText {
                        id: trackTime
                        anchors.bottom: sliderRow.top
                        anchors.bottomMargin: 5
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.rightMargin: playPauseButton.size + 8
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.inirEverywhere ? root.jiraColTextSecondary : blendedColors.colSubtext
                        elide: Text.ElideRight
                        text: `${StringUtils.friendlyTimeForSeconds(root.player?.position)} / ${StringUtils.friendlyTimeForSeconds(root.player?.length)}`
                    }
                    RowLayout {
                        id: sliderRow
                        anchors {
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                        }
                        TrackChangeButton {
                            iconName: "skip_previous"
                            downAction: () => root.player?.previous()
                        }
                        Item {
                            id: progressBarContainer
                            Layout.fillWidth: true
                            implicitHeight: Math.max(sliderLoader.implicitHeight, progressBarLoader.implicitHeight)

                            Loader {
                                id: sliderLoader
                                anchors.fill: parent
                                active: root.player?.canSeek ?? false
                                sourceComponent: StyledSlider { 
                                    configuration: StyledSlider.Configuration.Wavy
                                    highlightColor: Appearance.inirEverywhere ? root.jiraColPrimary : blendedColors.colPrimary
                                    trackColor: Appearance.inirEverywhere ? root.jiraColLayer2 : blendedColors.colSecondaryContainer
                                    handleColor: Appearance.inirEverywhere ? root.jiraColPrimary : blendedColors.colPrimary
                                    value: root.player?.position / root.player?.length
                                    onMoved: {
                                        root.player.position = value * root.player.length;
                                    }
                                }
                            }

                            Loader {
                                id: progressBarLoader
                                anchors {
                                    verticalCenter: parent.verticalCenter
                                    left: parent.left
                                    right: parent.right
                                }
                                active: !(root.player?.canSeek ?? false)
                                sourceComponent: StyledProgressBar { 
                                    wavy: root.player?.isPlaying
                                    highlightColor: Appearance.inirEverywhere ? root.jiraColPrimary : blendedColors.colPrimary
                                    trackColor: Appearance.inirEverywhere ? root.jiraColLayer2 : blendedColors.colSecondaryContainer
                                    value: root.player?.position / root.player?.length
                                }
                            }

                            
                        }
                        TrackChangeButton {
                            iconName: "skip_next"
                            downAction: () => root.player?.next()
                        }
                    }

                    RippleButton {
                        id: playPauseButton
                        anchors.right: parent.right
                        anchors.bottom: sliderRow.top
                        anchors.bottomMargin: 5
                        property real size: 44
                        implicitWidth: size
                        implicitHeight: size
                        downAction: () => root.player?.togglePlaying();

                        buttonRadius: Appearance.inirEverywhere 
                            ? Appearance.inir.roundingSmall 
                            : (root.player?.isPlaying ? Appearance?.rounding.normal : size / 2)
                        colBackground: Appearance.inirEverywhere 
                            ? "transparent" 
                            : (root.player?.isPlaying ? blendedColors.colPrimary : blendedColors.colSecondaryContainer)
                        colBackgroundHover: Appearance.inirEverywhere 
                            ? Appearance.inir.colLayer2Hover 
                            : (root.player?.isPlaying ? blendedColors.colPrimaryHover : blendedColors.colSecondaryContainerHover)
                        colRipple: Appearance.inirEverywhere 
                            ? Appearance.inir.colLayer2Active 
                            : (root.player?.isPlaying ? blendedColors.colPrimaryActive : blendedColors.colSecondaryContainerActive)

                        contentItem: MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.huge
                            fill: 1
                            horizontalAlignment: Text.AlignHCenter
                            color: Appearance.inirEverywhere 
                                ? root.jiraColPrimary 
                                : (root.player?.isPlaying ? blendedColors.colOnPrimary : blendedColors.colOnSecondaryContainer)
                            text: root.player?.isPlaying ? "pause" : "play_arrow"

                            Behavior on color {
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }
                        }
                    }
                }
            }
        }
    }
}