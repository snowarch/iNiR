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

Item { // Player instance - Old style design
    id: root
    required property MprisPlayer player
    property list<real> visualizerPoints: []
    property real maxVisualizerValue: 1000
    property int visualizerSmoothing: 2
    property real radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal : Appearance.rounding.normal

    property var artUrl: player?.trackArtUrl
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: artUrl ? Qt.md5(artUrl) : ""
    property string artFilePath: artFileName ? `${artDownloadLocation}/${artFileName}` : ""
    property color artDominantColor: ColorUtils.mix((colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary), Appearance.colors.colPrimaryContainer, 0.8) || Appearance.m3colors.m3secondaryContainer
    property bool downloaded: false

    property string displayedArtFilePath: root.downloaded ? Qt.resolvedUrl(artFilePath) : ""

    component TrackChangeButton: RippleButton {
        implicitWidth: 24
        implicitHeight: 24

        property var iconName
        colBackground: Appearance.angelEverywhere ? "transparent"
            : Appearance.inirEverywhere ? "transparent"
            : Appearance.auroraEverywhere ? "transparent"
            : ColorUtils.transparentize(blendedColors.colSecondaryContainer, 1)
        colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
            : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
            : blendedColors.colSecondaryContainerHover
        colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
            : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
            : blendedColors.colSecondaryContainerActive

        contentItem: MaterialSymbol {
            iconSize: Appearance.font.pixelSize.huge
            fill: 1
            horizontalAlignment: Text.AlignHCenter
            color: Appearance.angelEverywhere ? Appearance.angel.colText
                : Appearance.inirEverywhere ? Appearance.inir.colText
                : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer0
                : blendedColors.colOnSecondaryContainer
            text: iconName

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }

    Timer { // Force update for position
        running: root.player?.playbackState == MprisPlaybackState.Playing
        interval: 1000
        repeat: true
        onTriggered: {
            root.player?.positionChanged()
        }
    }

    onArtFilePathChanged: {
        if (!root.artUrl || root.artUrl.length == 0) {
            root.artDominantColor = Appearance.m3colors.m3secondaryContainer
            return;
        }

        // Check if file exists first
        artExistsChecker.running = true
    }

    Process {
        id: artExistsChecker
        command: ["/usr/bin/test", "-f", root.artFilePath]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.downloaded = true
            } else {
                root.downloaded = false
                coverArtDownloader.targetFile = root.artUrl ?? ""
                coverArtDownloader.artFilePath = root.artFilePath
                coverArtDownloader.running = true
            }
        }
    }

    Process { // Cover art downloader
        id: coverArtDownloader
        property string targetFile
        property string artFilePath
        command: ["/usr/bin/bash", "-c", `
            target="$1"
            out="$2"
            dir="$3"
            if [ -f "$out" ]; then exit 0; fi
            mkdir -p "$dir"
            tmp="$out.tmp"
            /usr/bin/curl -sSL --connect-timeout 10 --max-time 30 "$target" -o "$tmp" && \
            [ -s "$tmp" ] && /usr/bin/mv -f "$tmp" "$out" || { rm -f "$tmp"; exit 1; }
        `,
        "_",
        targetFile,
        artFilePath,
        root.artDownloadLocation
        ]
        onExited: (exitCode) => {
            root.downloaded = (exitCode === 0)
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
        visible: Appearance.angelEverywhere || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere)
    }
    Rectangle { // Background
        id: background
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin
        color: Appearance.angelEverywhere ? "transparent"
             : Appearance.inirEverywhere ? Appearance.inir.colLayer1
             : Appearance.auroraEverywhere ? "transparent"
             : ColorUtils.applyAlpha(blendedColors.colLayer0, 1)
        radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
             : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : root.radius
        border.width: Appearance.angelEverywhere ? 0 : ((Appearance.inirEverywhere || Appearance.auroraEverywhere) ? 1 : 0)
        border.color: Appearance.angelEverywhere ? "transparent"
                    : Appearance.inirEverywhere ? Appearance.inir.colBorder
                    : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
                    : "transparent"
        clip: true

        AngelPartialBorder { targetRadius: background.radius; coverage: 0.5 }

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: background.width
                height: background.height
                radius: background.radius
            }
        }

        // Aurora glass wallpaper blur
        Image {
            id: auroraWallpaper
            anchors.fill: parent
            visible: Appearance.auroraEverywhere && !Appearance.inirEverywhere
            source: Wallpapers.effectiveWallpaperUrl
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: true

            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect {
                source: auroraWallpaper
                anchors.fill: source
                saturation: Appearance.angelEverywhere
                    ? Appearance.angel.blurSaturation
                    : (Appearance.effectsEnabled ? 0.2 : 0)
                blurEnabled: Appearance.effectsEnabled
                blurMax: 100
                blur: Appearance.effectsEnabled ? 1 : 0
            }
        }

        // Aurora tint overlay
        Rectangle {
            anchors.fill: parent
            visible: Appearance.auroraEverywhere && !Appearance.inirEverywhere
            color: Appearance.angelEverywhere
                ? ColorUtils.transparentize(blendedColors.colLayer0, Appearance.angel.overlayOpacity)
                : ColorUtils.transparentize(blendedColors.colLayer0, Appearance.aurora.popupTransparentize)
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
            opacity: Appearance.inirEverywhere ? 0.5 : 0.3
            visible: root.displayedArtFilePath !== ""

            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect {
                source: blurredArt
                anchors.fill: source
                saturation: Appearance.effectsEnabled ? 0.2 : 0
                blurEnabled: Appearance.effectsEnabled
                blurMax: 100
                blur: Appearance.effectsEnabled ? 1 : 0
            }

            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize(blendedColors.colLayer0, 0.3)
                radius: root.radius
                visible: !Appearance.auroraEverywhere
            }
        }

        CavaWavyLine {
            id: visualizerCanvas
            anchors.fill: parent
            visible: root.player?.isPlaying ?? false
            opacity: visible ? 1 : 0
            points: root.visualizerPoints
            color: blendedColors.colPrimary
            lineWidth: 3
            amplitudeScale: 1.2

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 13
            spacing: 15

            Rectangle { // Art background
                id: artBackground
                Layout.fillHeight: true
                implicitWidth: height
                radius: Appearance.rounding.verysmall
                color: ColorUtils.transparentize(blendedColors.colLayer1, 0.5)

                layer.enabled: true
                layer.effect: OpacityMask {
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
                    color: Appearance.inirEverywhere ? Appearance.inir.colText
                        : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer0
                        : blendedColors.colOnLayer0
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
                    color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
                        : Appearance.auroraEverywhere ? Appearance.aurora.colTextSecondary
                        : blendedColors.colSubtext
                    elide: Text.ElideRight
                    text: root.player?.trackArtist ?? ""
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
                        color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
                            : Appearance.auroraEverywhere ? Appearance.aurora.colTextSecondary
                            : blendedColors.colSubtext
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
                                    highlightColor: Appearance.inirEverywhere ? Appearance.inir.colPrimary
                                        : Appearance.auroraEverywhere ? Appearance.colors.colPrimary
                                        : blendedColors.colPrimary
                                    trackColor: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                                        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                                        : blendedColors.colSecondaryContainer
                                    handleColor: Appearance.inirEverywhere ? Appearance.inir.colPrimary
                                        : Appearance.auroraEverywhere ? Appearance.colors.colPrimary
                                        : blendedColors.colPrimary
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
                                    highlightColor: Appearance.inirEverywhere ? Appearance.inir.colPrimary
                                        : Appearance.auroraEverywhere ? Appearance.colors.colPrimary
                                        : blendedColors.colPrimary
                                    trackColor: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                                        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                                        : blendedColors.colSecondaryContainer
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

                        buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall
                            : Appearance.auroraEverywhere ? Appearance.rounding.normal
                            : (root.player?.isPlaying ? Appearance?.rounding.normal : size / 2)
                        colBackground: Appearance.inirEverywhere ? "transparent"
                            : Appearance.auroraEverywhere ? "transparent"
                            : (root.player?.isPlaying ? blendedColors.colPrimary : blendedColors.colSecondaryContainer)
                        colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                            : (root.player?.isPlaying ? blendedColors.colPrimaryHover : blendedColors.colSecondaryContainerHover)
                        colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
                            : (root.player?.isPlaying ? blendedColors.colPrimaryActive : blendedColors.colSecondaryContainerActive)

                        contentItem: MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.huge
                            fill: 1
                            horizontalAlignment: Text.AlignHCenter
                            color: Appearance.inirEverywhere ? Appearance.inir.colPrimary
                                : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer0
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
