pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

/**
 * Compact media widget for lock screen - Material You style
 */
Item {
    id: root
    required property MprisPlayer player
    property var artUrl: player?.trackArtUrl
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`
    property color artDominantColor: ColorUtils.mix(
        (colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary), 
        Appearance.colors.colPrimaryContainer, 
        0.8
    ) || Appearance.m3colors.m3secondaryContainer
    property bool downloaded: false
    property int _downloadRetryCount: 0
    readonly property int _maxRetries: 3
    property real radius: Appearance.rounding.large

    property string displayedArtFilePath: root.downloaded ? Qt.resolvedUrl(artFilePath) : ""

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

    Timer {
        running: root.player?.playbackState == MprisPlaybackState.Playing
        interval: Config.options?.resources?.updateInterval ?? 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    onArtFilePathChanged: {
        _downloadRetryCount = 0
        checkAndDownloadArt()
    }

    // Re-check cover art when becoming visible (important for lock screen)
    onVisibleChanged: {
        if (visible && artFilePath) {
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
                coverArtDownloader.targetFile = root.artUrl
                coverArtDownloader.artFilePath = root.artFilePath
                coverArtDownloader.running = true
            }
        }
    }

    Process {
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
        depth: 0
        rescaleSize: 1
    }

    property QtObject blendedColors: AdaptedMaterialScheme {
        color: artDominantColor
    }

    // Shadow
    StyledRectangularShadow {
        target: background
    }

    Rectangle {
        id: background
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin
        color: ColorUtils.applyAlpha(blendedColors.colLayer0, 0.95)
        radius: root.radius

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: background.width
                height: background.height
                radius: background.radius
            }
        }

        // Blurred album art background
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
            opacity: 0.4

            layer.enabled: Appearance.effectsEnabled
            layer.effect: StyledBlurEffect {
                source: blurredArt
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12

            // Album art - fixed size square
            Rectangle {
                id: artBackground
                Layout.preferredWidth: background.height - 20
                Layout.preferredHeight: background.height - 20
                Layout.alignment: Qt.AlignVCenter
                radius: Appearance.rounding.small
                color: ColorUtils.transparentize(blendedColors.colLayer1, 0.5)

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: artBackground.width
                        height: artBackground.height
                        radius: artBackground.radius
                    }
                }

                StyledImage {
                    id: mediaArt
                    anchors.fill: parent
                    source: root.displayedArtFilePath
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    antialiasing: true
                    sourceSize.width: parent.width
                    sourceSize.height: parent.height
                }
                
                // Fallback icon
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "music_note"
                    iconSize: 32
                    color: blendedColors.colSubtext
                    visible: root.displayedArtFilePath.length === 0
                }
            }

            // Track info and controls
            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                spacing: 2

                Item { Layout.fillHeight: true; Layout.maximumHeight: 4 }

                // Title
                StyledText {
                    id: trackTitle
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Medium
                    color: blendedColors.colOnLayer0
                    elide: Text.ElideRight
                    text: StringUtils.cleanMusicTitle(root.player?.trackTitle) || "Untitled"
                    animateChange: true
                    animationDistanceX: 6
                    animationDistanceY: 0
                }

                // Artist
                StyledText {
                    id: trackArtist
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: blendedColors.colSubtext
                    elide: Text.ElideRight
                    text: root.player?.trackArtist ?? ""
                    animateChange: true
                    animationDistanceX: 6
                    animationDistanceY: 0
                    visible: text.length > 0
                }

                Item { Layout.fillHeight: true }

                // Controls row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    MediaControlButton {
                        Layout.alignment: Qt.AlignVCenter
                        icon: "skip_previous"
                        blendedColors: root.blendedColors
                        onClicked: root.player?.previous()
                    }

                    MediaControlButton {
                        Layout.alignment: Qt.AlignVCenter
                        icon: root.player?.isPlaying ? "pause" : "play_arrow"
                        filled: true
                        size: 36
                        blendedColors: root.blendedColors
                        onClicked: root.player?.togglePlaying()
                    }

                    MediaControlButton {
                        Layout.alignment: Qt.AlignVCenter
                        icon: "skip_next"
                        blendedColors: root.blendedColors
                        onClicked: root.player?.next()
                    }

                    Item { Layout.fillWidth: true }

                    // Time
                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: blendedColors.colSubtext
                        text: `${StringUtils.friendlyTimeForSeconds(root.player?.position ?? 0)} / ${StringUtils.friendlyTimeForSeconds(root.player?.length ?? 0)}`
                    }
                }
                
                Item { Layout.fillHeight: true; Layout.maximumHeight: 4 }
            }
        }
    }

    // Media control button component
    component MediaControlButton: Rectangle {
        id: mediaBtn
        required property string icon
        required property QtObject blendedColors
        property bool filled: false
        property real size: 32
        
        signal clicked()
        
        implicitWidth: size
        implicitHeight: size
        radius: filled ? Appearance.rounding.normal : size / 2
        
        color: {
            if (filled) {
                if (mediaBtnMouse.pressed) return blendedColors.colPrimaryActive
                if (mediaBtnMouse.containsMouse) return blendedColors.colPrimaryHover
                return blendedColors.colPrimary
            } else {
                if (mediaBtnMouse.pressed) return blendedColors.colSecondaryContainerActive
                if (mediaBtnMouse.containsMouse) return blendedColors.colSecondaryContainerHover
                return ColorUtils.transparentize(blendedColors.colSecondaryContainer, 1)
            }
        }
        
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
        Behavior on radius {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.OutCubic
            }
        }
        
        MaterialSymbol {
            anchors.centerIn: parent
            text: mediaBtn.icon
            iconSize: mediaBtn.filled ? 22 : 18
            fill: 1
            color: mediaBtn.filled 
                ? mediaBtn.blendedColors.colOnPrimary 
                : mediaBtn.blendedColors.colOnSecondaryContainer
            
            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
        
        MouseArea {
            id: mediaBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mediaBtn.clicked()
        }
    }
}
