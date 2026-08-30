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
    required property MprisPlayer player
    required property list<real> visualizerPoints
    property real radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal : Appearance.rounding.large
    // Track-change slide direction: +1 next/forward (new content enters from the
    // right), -1 previous (enters from the left). Set by the prev/next handlers
    // before the track advances so the cross-slide reads as directed.
    property int slideDirection: 1
    
    // Use centralized YtMusic detection from MprisController
    readonly property bool isYtMusicPlayer: {
        if (!player) return false
        // Direct match with YtMusic.mpvPlayer
        if (YtMusic.mpvPlayer && player === YtMusic.mpvPlayer) return true
        // Use MprisController's detection for consistency
        return MprisController._isYtMusicMpv(player)
    }
    
    function doTogglePlaying(): void {
        if (isYtMusicPlayer) {
            YtMusic.togglePlaying()
        } else {
            player?.togglePlaying()
        }
    }
    
    function doPrevious(): void {
        root.slideDirection = -1
        MprisController.previousForPlayer(root.player)
    }
    
    function doNext(): void {
        root.slideDirection = 1
        MprisController.nextForPlayer(root.player)
    }
    
    // Screen position for aurora glass effect
    property real screenX: 0
    property real screenY: 0

    readonly property string effectiveArtUrl: isYtMusicPlayer ? YtMusic.currentThumbnail : MprisController.effectiveArtUrl(player)
    readonly property string effectiveTitle: isYtMusicPlayer ? YtMusic.currentTitle : (player?.trackTitle ?? "")
    readonly property string effectiveArtist: isYtMusicPlayer ? YtMusic.currentArtist : (player?.trackArtist ?? "")
    // Only the artwork identity may trigger cover motion. Title/artist often
    // arrive before the real art URL and caused the same cover to slide twice.
    readonly property string mediaTransitionKey: (root.effectiveArtUrl ?? "").split("?")[0].split("#")[0]
    property string artDownloadLocation: Directories.coverArt
    readonly property string resolverDisplaySource: artworkResolver.displaySource
    readonly property bool downloaded: root.displayedArtFilePath !== ""
    property string displayedArtFilePath: ""
    readonly property bool effectiveCanGoPrevious: isYtMusicPlayer ? YtMusic.canGoPrevious : MprisController.canGoPreviousForPlayer(root.player)
    readonly property bool effectiveCanGoNext: isYtMusicPlayer ? YtMusic.canGoNext : MprisController.canGoNextForPlayer(root.player)

    function checkAndDownloadArt() {
        artworkResolver.refresh()
    }

    Connections {
        target: root.player
        function onTrackArtUrlChanged() {
            if (!root.isYtMusicPlayer)
                root.checkAndDownloadArt()
        }
        function onTrackTitleChanged() {
            Qt.callLater(root.checkAndDownloadArt)
        }
        function onTrackArtistChanged() {
            Qt.callLater(root.checkAndDownloadArt)
        }
        function onTrackAlbumChanged() {
            Qt.callLater(root.checkAndDownloadArt)
        }
    }

    onResolverDisplaySourceChanged: {
        const src = root.resolverDisplaySource
        if (src && src.length > 0) {
            clearArtTimer.stop()
            root.displayedArtFilePath = src
        } else {
            clearArtTimer.restart()
        }
    }

    MediaArtworkResolver {
        id: artworkResolver
        sourceUrl: root.effectiveArtUrl
        title: root.effectiveTitle
        artist: root.effectiveArtist
        album: root.player?.trackAlbum ?? ""
        cacheDirectory: root.artDownloadLocation
    }

    Timer {
        id: clearArtTimer
        interval: 1600
        onTriggered: {
            if (!root.resolverDisplaySource || root.resolverDisplaySource.length === 0)
                root.displayedArtFilePath = ""
        }
    }

    Component.onCompleted: {
        if (root.resolverDisplaySource && root.resolverDisplaySource.length > 0)
            root.displayedArtFilePath = root.resolverDisplaySource
    }

    Timer {
        running: root.player?.playbackState === MprisPlaybackState.Playing
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
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

    // Inir fixed colors
    readonly property color inirText: Appearance.inir.colText
    readonly property color inirTextSecondary: Appearance.inir.colTextSecondary
    readonly property color inirPrimary: Appearance.inir.colPrimary
    readonly property color inirLayer1: Appearance.inir.colLayer1
    readonly property color inirLayer2: Appearance.inir.colLayer2

    StyledRectangularShadow { target: card; visible: Appearance.angelEverywhere || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere) }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width - Appearance.sizes.elevationMargin
        height: parent.height - Appearance.sizes.elevationMargin
        radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
             : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
             : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : root.radius
        Behavior on radius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        color: Appearance.zzzEverywhere ? Appearance.zzz.bg0
             : Appearance.angelEverywhere ? "transparent"
             : Appearance.inirEverywhere ? root.inirLayer1
             : Appearance.auroraEverywhere ? "transparent"
             : (blendedColors?.colLayer0 ?? Appearance.colors.colLayer0)
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        border.width: Appearance.zzzEverywhere ? Appearance.zzz.borderThick
                    : (Appearance.angelEverywhere || Appearance.inirEverywhere || Appearance.auroraEverywhere) ? 1 : 0
        Behavior on border.width {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        border.color: Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong
                    : Appearance.angelEverywhere ? Appearance.angel.colBorder
                    : Appearance.inirEverywhere ? Appearance.inir.colBorder
                    : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder
                    : "transparent"
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        clip: true

        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle { width: card.width; height: card.height; radius: card.radius }
        }

        // Aurora glass wallpaper blur
        Image {
            id: auroraWallpaper
            x: -root.screenX - (card.x + (root.width - card.width) / 2)
            y: -root.screenY - (card.y + (root.height - card.height) / 2)
            width: Quickshell.screens[0]?.width ?? 1920
            height: Quickshell.screens[0]?.height ?? 1080
            visible: Appearance.auroraEverywhere && !Appearance.inirEverywhere
            source: visible ? Wallpapers.effectiveWallpaperUrl : ""
            fillMode: Image.PreserveAspectCrop
            cache: true
            sourceSize.width: Quickshell.screens[0]?.width ?? 1920
            sourceSize.height: Quickshell.screens[0]?.height ?? 1080
            smooth: true
            mipmap: true
            asynchronous: true

            layer.enabled: Appearance.effectsEnabled && Appearance.auroraEverywhere && !Appearance.inirEverywhere
            layer.effect: MultiEffect {
                source: auroraWallpaper
                anchors.fill: source
                saturation: Appearance.angelEverywhere
                    ? Appearance.angel.blurSaturation
                    : (Appearance.effectsEnabled ? 0.2 : 0)
                blurEnabled: Appearance.effectsEnabled
                blurMax: 64
                blur: Appearance.effectsEnabled ? 1 : 0
            }
        }

        // Aurora tint overlay
        Rectangle {
            anchors.fill: parent
            visible: Appearance.auroraEverywhere && !Appearance.inirEverywhere
            color: Appearance.angelEverywhere
                ? ColorUtils.transparentize(blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base, Appearance.angel.overlayOpacity)
                : ColorUtils.transparentize(blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base, Appearance.aurora.popupTransparentize)
        }

        // Card-level art wash follows the loaded art without sliding. Only the
        // visible cover moves, so a track change has one clear motion.
        MediaCrossSlideImage {
            id: bgArt
            anchors.fill: parent
            source: root.displayedArtFilePath
            transitionKey: "player-card-wash"
            downloaded: root.downloaded
            slideDirection: root.slideDirection
            animateChanges: false
            artRadius: card.radius
            placeholderColor: Appearance.zzzEverywhere ? Appearance.zzz.bg0
                : Appearance.inirEverywhere ? root.inirLayer1
                : (blendedColors?.colLayer0 ?? Appearance.colors.colLayer0)
            iconColor: "transparent"
            opacity: Appearance.zzzEverywhere ? 0.20
                : Appearance.inirEverywhere ? 0.15
                : (Appearance.auroraEverywhere ? 0.2 : 0.5)
            visible: root.displayedArtFilePath !== ""
            effectEnabled: Appearance.effectsEnabled
            blurEnabled: true
            blur: Appearance.inirEverywhere ? 0.3 : 0.15
            blurMax: 16
            saturation: Appearance.zzzEverywhere ? 0.14 : (Appearance.inirEverywhere ? 0.1 : 0.3)
        }

        // Gradient overlay for Material only — a material-tinted wash that
        // clashes with the flat ZZZ console plate, so exclude it there.
        Rectangle {
            anchors.fill: parent
            visible: !Appearance.zzzEverywhere && !Appearance.inirEverywhere && !Appearance.auroraEverywhere
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
            height: 35
            live: root.player?.isPlaying ?? false
            points: root.visualizerPoints
            maxVisualizerValue: 1000
            smoothing: 2
            color: ColorUtils.transparentize(
                Appearance.zzzEverywhere ? Appearance.zzz.metricFill
                    : Appearance.inirEverywhere ? root.inirPrimary : (blendedColors?.colPrimary ?? Appearance.colors.colPrimary),
                0.6
            )
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // Cover art — direction-aware cross-slide (one leaves, one enters)
            MediaCrossSlideImage {
                id: coverArtContainer
                Layout.preferredWidth: card.height - 24
                Layout.preferredHeight: card.height - 24
                artRadius: Appearance.zzzEverywhere ? Appearance.zzz.roundNormal
                    : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                    : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
                source: root.displayedArtFilePath
                transitionKey: root.mediaTransitionKey
                downloaded: root.downloaded
                slideDirection: root.slideDirection
                placeholderColor: Appearance.zzzEverywhere ? Appearance.zzz.bg2
                    : Appearance.inirEverywhere ? root.inirLayer2
                    : (blendedColors?.colLayer1 ?? Appearance.colors.colLayer1)
                iconColor: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
                    : Appearance.inirEverywhere ? root.inirTextSecondary
                    : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
                iconSize: 32
            }

            // Info & controls
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                // Title
                StyledText {
                    Layout.fillWidth: true
                    text: StringUtils.cleanMusicTitle(root.isYtMusicPlayer ? YtMusic.currentTitle : root.player?.trackTitle) || "—"
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Appearance.zzzEverywhere ? Font.Black : Font.Medium
                    font.italic: Appearance.zzzEverywhere
                    color: Appearance.zzzEverywhere ? Appearance.zzz.ink
                        : Appearance.inirEverywhere ? root.inirText : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    elide: Text.ElideRight
                    animateChange: true
                    animationDistanceX: root.slideDirection * 8
                    animationDistanceY: 0
                }

                // Artist
                StyledText {
                    Layout.fillWidth: true
                    text: root.isYtMusicPlayer ? YtMusic.currentArtist : (root.player?.trackArtist || "")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
                        : Appearance.inirEverywhere ? root.inirTextSecondary : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    elide: Text.ElideRight
                    visible: text !== ""
                    animateChange: true
                    animationDistanceX: root.slideDirection * 8
                    animationDistanceY: 0
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
                            highlightColor: Appearance.zzzEverywhere ? Appearance.zzz.metricFill
                                : Appearance.inirEverywhere ? root.inirPrimary
                                : Appearance.auroraEverywhere ? Appearance.colors.colPrimary
                                : (blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
                            trackColor: Appearance.zzzEverywhere ? Appearance.zzz.metricTrack
                                : Appearance.inirEverywhere ? root.inirLayer2
                                : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                                : (blendedColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer)
                            handleColor: Appearance.zzzEverywhere ? Appearance.zzz.metricFill
                                : Appearance.inirEverywhere ? root.inirPrimary
                                : Appearance.auroraEverywhere ? Appearance.colors.colPrimary
                                : (blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
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
                            highlightColor: Appearance.zzzEverywhere ? Appearance.zzz.metricFill
                                : Appearance.inirEverywhere ? root.inirPrimary
                                : Appearance.auroraEverywhere ? Appearance.colors.colPrimary
                                : (blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
                            trackColor: Appearance.zzzEverywhere ? Appearance.zzz.metricTrack
                                : Appearance.inirEverywhere ? root.inirLayer2
                                : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                                : (blendedColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer)
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
                        color: Appearance.zzzEverywhere ? Appearance.zzz.ink
                            : Appearance.inirEverywhere ? root.inirText : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RippleButton {
                        implicitWidth: 32; implicitHeight: 32
                        enabled: root.effectiveCanGoPrevious
                        buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
                            : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.zzzEverywhere ? Appearance.zzz.paperAlt
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                            : ColorUtils.transparentize(blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5)
                        colRipple: Appearance.zzzEverywhere ? ColorUtils.applyAlpha(Appearance.zzz.accent, 0.28)
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
                            : (blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active)
                        onClicked: root.doPrevious()
                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_previous"; iconSize: 22; fill: 1
                                color: Appearance.zzzEverywhere ? Appearance.zzz.ink
                                    : Appearance.inirEverywhere ? root.inirText
                                    : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer0
                                    : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                                Behavior on color {
                                    enabled: Appearance.animationsEnabled
                                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                }
                            }
                        }
                        StyledToolTip { text: Translation.tr("Previous") }
                    }

                    RippleButton {
                        id: playPauseButton
                        implicitWidth: 40; implicitHeight: 40
                        buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
                            : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.zzzEverywhere ? Appearance.zzz.paperAlt
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                            : Appearance.colors.colLayer1Hover
                        colRipple: Appearance.zzzEverywhere ? ColorUtils.applyAlpha(Appearance.zzz.accent, 0.28)
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
                            : Appearance.colors.colLayer1Active
                        onClicked: root.doTogglePlaying()

                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: root.player?.isPlaying ? "pause" : "play_arrow"
                                iconSize: 24; fill: 1
                                color: Appearance.zzzEverywhere ? Appearance.zzz.accent
                                    : Appearance.inirEverywhere ? root.inirPrimary
                                    : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer0
                                    : Appearance.colors.colOnLayer1
                                Behavior on color {
                                    enabled: Appearance.animationsEnabled
                                    animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                }
                            }
                        }
                        StyledToolTip { text: root.player?.isPlaying ? Translation.tr("Pause") : Translation.tr("Play") }
                    }

                    RippleButton {
                        implicitWidth: 32; implicitHeight: 32
                        enabled: root.effectiveCanGoNext
                        buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
                            : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.zzzEverywhere ? Appearance.zzz.paperAlt
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                            : ColorUtils.transparentize(blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5)
                        colRipple: Appearance.zzzEverywhere ? ColorUtils.applyAlpha(Appearance.zzz.accent, 0.28)
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
                            : (blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active)
                        onClicked: root.doNext()
                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_next"; iconSize: 22; fill: 1
                                color: Appearance.zzzEverywhere ? Appearance.zzz.ink
                                    : Appearance.inirEverywhere ? root.inirText
                                    : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer0
                                    : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                                Behavior on color {
                                    enabled: Appearance.animationsEnabled
                                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                }
                            }
                        }
                        StyledToolTip { text: Translation.tr("Next") }
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(root.player?.length ?? 0)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: Appearance.zzzEverywhere ? Appearance.zzz.ink
                            : Appearance.inirEverywhere ? root.inirText : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }
                }
            }
        }
    }
}
